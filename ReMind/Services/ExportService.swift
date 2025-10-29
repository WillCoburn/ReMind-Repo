// ============================
// File: Services/ExportService.swift
// ============================
import Foundation
import PDFKit
import FirebaseAuth
import FirebaseFunctions

public protocol ExportService {
    func exportAndSend(entries: [Entry]) async throws -> URL
}

public enum ExportError: Error, LocalizedError {
    case notSignedIn
    case noEntries
    case backend(String)
    case uploadFailed(Int)
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You must be signed in."
        case .noEntries: return "No entries to export."
        case .backend(let msg): return msg
        case .uploadFailed(let code): return "Upload failed (HTTP \(code))."
        case .unknown: return "Unknown error."
        }
    }
}

public struct FirebaseExportService: ExportService {
    public init() {}
    
    public func exportAndSend(entries: [Entry]) async throws -> URL {
        // --- Auth + entries check ---
        guard let uid = Auth.auth().currentUser?.uid else { throw ExportError.notSignedIn }
        guard !entries.isEmpty else { throw ExportError.noEntries }
        
        print("Step 1 build pdf")
        // --- Build PDF ---
        let pdfData = try Self.makePDF(entries: entries)
        
        print("Step 2 requesting upload URL")
        // --- Generate filename & path ---
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmm"
        df.locale = Locale(identifier: "en_US_POSIX")
        let filename = "affirmations-\(df.string(from: Date())).pdf"
        let path = "users/\(uid)/exports/\(filename)"
        
        print("Step 3 get signed upload URL")
        print("UID:", Auth.auth().currentUser?.uid ?? "nil")
        print("Path:", path) // should be users/<uid>/exports/<file>.pdf
        
        // --- Get signed upload URL (with real callable error details) ---
        let functions = Functions.functions(region: "us-central1")
        let callable = functions.httpsCallable("getExportUploadUrl")
        var response: HTTPSCallableResult?
        do {
            response = try await callable.call([
                "path": path,
                "contentType": "application/pdf"
            ])
        } catch let err as NSError {
            print("❌ getExportUploadUrl failed")
            print("domain:", err.domain)                 // e.g. FIRFunctionsErrorDomain
            print("code:", err.code)                     // numeric code
            print("localizedDescription:", err.localizedDescription)
            if let details = err.userInfo[FunctionsErrorDetailsKey] {
                print("details:", details)               // HttpsError message like 'unauthenticated', 'invalid-argument'
            }
            throw ExportError.backend(err.localizedDescription)
        }
        
        print("Step 4 uploading to storage")
        
        guard
            let data = response?.data as? [String: Any],
            let uploadURLString = data["uploadUrl"] as? String,
            let uploadURL = URL(string: uploadURLString)
        else { throw ExportError.backend("Invalid upload URL response.") }
        
        print("📤 Upload URL:", uploadURL)
        
        print("Step 5 uploading the pdf")
        // --- Upload the PDF (PUT) ---
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        
        let (respData, resp) = try await URLSession.shared.upload(for: request, from: pdfData)
        guard let http = resp as? HTTPURLResponse else { throw ExportError.uploadFailed(-1) }
        
        print("📡 Upload status:", http.statusCode)
        if !(200...299).contains(http.statusCode) {
            let errBody = String(data: respData, encoding: .utf8) ?? ""
            print("Upload error:", errBody)
            throw ExportError.uploadFailed(http.statusCode)
        }
        
        // --- Ask backend to send link ---
        print("Step 6 requesting send export link")
        let sendFn = functions.httpsCallable("sendExportLink")
        let sendResp = try await sendFn.call(["path": path])
        
        guard
            let sendData = sendResp.data as? [String: Any],
            let linkString = sendData["link"] as? String,
            let link = URL(string: linkString)
        else { throw ExportError.backend("Invalid link response.") }
        
        print("✅ Export link:", link)
        return link
    }
    
    // MARK: - PDF generation
    static func makePDF(entries: [Entry]) throws -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // 8.5x11"
        let margin: CGFloat = 48
        let headerHeight: CGFloat = 32
        let footerHeight: CGFloat = 28
        
        let headerFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        let bodyFont = UIFont.systemFont(ofSize: 13, weight: .regular)
        let dateFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        let footerFont = UIFont.systemFont(ofSize: 11, weight: .regular)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: UIGraphicsPDFRendererFormat())
        let data = renderer.pdfData { ctx in
            var page = 0
            let sorted = entries.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            let df = DateFormatter()
            df.dateStyle = .medium; df.timeStyle = .short
            let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byWordWrapping
            
            func startPage() {
                ctx.beginPage()
                page += 1
                let header = "ReMind — My Affirmations"
                header.draw(at: CGPoint(x: margin, y: margin),
                            withAttributes: [.font: headerFont])
                let footer = "Page \(page)"
                let fSize = (footer as NSString).size(withAttributes: [.font: footerFont])
                footer.draw(at: CGPoint(x: pageRect.width - margin - fSize.width,
                                        y: pageRect.height - margin - footerHeight + 6),
                            withAttributes: [.font: footerFont])
            }
            
            startPage()
            var y = margin + headerHeight + 12
            
            for entry in sorted {
                // Date
                let dateText = entry.createdAt.map { df.string(from: $0) } ?? "Unknown date"
                (dateText as NSString).draw(in: CGRect(x: margin, y: y, width: pageRect.width - 2*margin, height: 16),
                                            withAttributes: [.font: dateFont, .foregroundColor: UIColor.secondaryLabel])
                y += 16
                
                // Body
                let bodyText = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let attrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .paragraphStyle: paragraph]
                let box = (bodyText as NSString).boundingRect(
                    with: CGSize(width: pageRect.width - 2*margin, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
                
                if y + box.height + 20 > pageRect.height - margin - footerHeight {
                    startPage(); y = margin + headerHeight + 12
                }
                (bodyText as NSString).draw(in: CGRect(x: margin, y: y, width: pageRect.width - 2*margin, height: ceil(box.height)),
                                            withAttributes: attrs)
                y += box.height + 16
            }
        }
        return data
    }
}

// Default no-op
public struct NoopExporter: ExportService {
    public init() {}
    public func exportAndSend(entries: [Entry]) async throws -> URL {
        throw ExportError.unknown
    }
}
