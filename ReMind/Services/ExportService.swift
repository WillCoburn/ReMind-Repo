// ============================
// File: Services/ExportService.swift
// ============================
import Foundation
import PDFKit
import FirebaseAuth
import FirebaseFunctions

public protocol ExportService {
    /// Generates a PDF from the given entries, uploads to Cloud Storage via a signed upload URL,
    /// then asks the backend to text a signed download link to the user.
    /// - Returns: The final public link (signed URL if available; otherwise token URL) to show "Copy link".
    func exportAndSend(entries: [Entry]) async throws -> URL
}

public enum ExportError: Error, LocalizedError {
    case notSignedIn
    case noEntries
    case backend(String)
    case uploadFailed
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You must be signed in."
        case .noEntries: return "No entries to export."
        case .backend(let msg): return msg
        case .uploadFailed: return "Upload failed."
        case .unknown: return "Unknown error."
        }
    }
}

public struct FirebaseExportService: ExportService {
    public init() {}
    
    public func exportAndSend(entries: [Entry]) async throws -> URL {
        guard let uid = Auth.auth().currentUser?.uid else { throw ExportError.notSignedIn }
        guard !entries.isEmpty else { throw ExportError.noEntries }
        
        // 1) Build PDF data (US Letter) with header/footer
        let pdfData = try Self.makePDF(entries: entries)
        
        // 2) Ask backend for a signed upload URL & target path
        let now = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmm"
        df.locale = Locale(identifier: "en_US_POSIX")
        let filename = "affirmations-\(df.string(from: now)).pdf"
        let path = "users/\(uid)/exports/\(filename)"
        
        let getUrl = Functions.functions().httpsCallable("getExportUploadUrl")
        let getRespAny = try await getUrl.call(["path": path, "contentType": "application/pdf"]).data
        guard let getResp = getRespAny as? [String: Any],
              let uploadURLString = getResp["uploadUrl"] as? String,
              let uploadURL = URL(string: uploadURLString)
        else { throw ExportError.backend("Bad upload URL response") }
        
        // 3) PUT the PDF to the signed URL
        var req = URLRequest(url: uploadURL)
        req.httpMethod = "PUT"
        req.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        req.httpBody = pdfData
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ExportError.uploadFailed
        }
        
        // 4) Ask backend to generate a link (signed if possible) and text it to the user's phone
        let send = Functions.functions().httpsCallable("sendExportLink")
        let sendRespAny = try await send.call(["path": path]).data
        guard let sendResp = sendRespAny as? [String: Any],
              let linkString = sendResp["link"] as? String,
              let link = URL(string: linkString)
        else { throw ExportError.backend("Bad link response") }
        
        return link
    }
    
    // MARK: - PDF
    static func makePDF(entries: [Entry]) throws -> Data {
        // US Letter 8.5x11 in points
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 48
        let headerHeight: CGFloat = 32
        let footerHeight: CGFloat = 28
        
        // Typography
        let headerFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        let bodyFont = UIFont.systemFont(ofSize: 13, weight: .regular)
        let dateFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        let footerFont = UIFont.systemFont(ofSize: 11, weight: .regular)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: UIGraphicsPDFRendererFormat())
        let data = renderer.pdfData { ctx in
            var page = 0
            
            // Sort entries oldest -> newest for a narrative
            let sorted = entries.sorted { (a, b) in
                (a.createdAt ?? .distantPast) < (b.createdAt ?? .distantPast)
            }
            
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.alignment = .left
            
            // Date formatter
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            
            // Drawing loop with pagination
            var cursorY: CGFloat = margin + headerHeight + 12
            
            func startPage() {
                ctx.beginPage()
                page += 1
                // Header
                let header = "ReMind — My Affirmations"
                let headerAttrs: [NSAttributedString.Key: Any] = [
                    .font: headerFont
                ]
                let headerSize = (header as NSString).size(withAttributes: headerAttrs)
                let headerOrigin = CGPoint(x: margin, y: margin)
                header.draw(at: headerOrigin, withAttributes: headerAttrs)
                
                // Footer (page numbers)
                let footer = "Page \(page)"
                let footerAttrs: [NSAttributedString.Key: Any] = [.font: footerFont]
                let footerSize = (footer as NSString).size(withAttributes: footerAttrs)
                let footerOrigin = CGPoint(x: pageRect.width - margin - footerSize.width,
                                           y: pageRect.height - margin - footerHeight + 6)
                footer.draw(at: footerOrigin, withAttributes: footerAttrs)
                
                cursorY = margin + headerHeight + 12
            }
            
            startPage()
            
            for entry in sorted {
                // Date
                let dateText: String = {
                    if let d = entry.createdAt { return df.string(from: d) }
                    return "Unknown date"
                }()
                let dateAttrs: [NSAttributedString.Key: Any] = [
                    .font: dateFont,
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let dateRect = CGRect(x: margin, y: cursorY, width: pageRect.width - 2*margin, height: 16)
                (dateText as NSString).draw(in: dateRect, withAttributes: dateAttrs)
                cursorY += 16
                
                // Body
                let bodyAttrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .paragraphStyle: paragraph
                ]
                let bodyText = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let maxWidth = pageRect.width - 2*margin
                let bounding = (bodyText as NSString).boundingRect(
                    with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: bodyAttrs,
                    context: nil
                )
                
                if cursorY + bounding.height + 20 > pageRect.height - margin - footerHeight {
                    startPage()
                }
                
                let bodyRect = CGRect(x: margin, y: cursorY, width: maxWidth, height: ceil(bounding.height))
                (bodyText as NSString).draw(in: bodyRect, withAttributes: bodyAttrs)
                cursorY = bodyRect.maxY + 16
            }
        }
        return data
    }
}

// Default no-op (unused now, kept for compile safety in previews/tests)
public struct NoopExporter: ExportService {
    public init() {}
    public func exportAndSend(entries: [Entry]) async throws -> URL { throw ExportError.unknown }
}
