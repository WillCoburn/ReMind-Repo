// ============================
// File: Services/ExportService.swift
// ============================
import Foundation
import PDFKit
import FirebaseAuth
import FirebaseFunctions
import UIKit

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
        guard let uid = Auth.auth().currentUser?.uid else { throw ExportError.notSignedIn }
        guard !entries.isEmpty else { throw ExportError.noEntries }
        
        let pdfData = try Self.makePDF(entries: entries)
        
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmm"
        df.locale = Locale(identifier: "en_US_POSIX")
        let filename = "affirmations-\(df.string(from: Date())).pdf"
        let path = "users/\(uid)/exports/\(filename)"
        
        let functions = Functions.functions(region: "us-central1")
        let callable = functions.httpsCallable("getExportUploadUrl")
        let response = try await callable.call([
            "path": path,
            "contentType": "application/pdf"
        ])
        
        guard
            let data = response.data as? [String: Any],
            let uploadURLString = data["uploadUrl"] as? String,
            let uploadURL = URL(string: uploadURLString)
        else { throw ExportError.backend("Invalid upload URL response.") }
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        
        let (_, resp) = try await URLSession.shared.upload(for: request, from: pdfData)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode)
        else { throw ExportError.uploadFailed((resp as? HTTPURLResponse)?.statusCode ?? -1) }
        
        let sendFn = functions.httpsCallable("sendExportLink")
        let sendResp = try await sendFn.call(["path": path])
        
        guard
            let sendData = sendResp.data as? [String: Any],
            let linkString = sendData["link"] as? String,
            let link = URL(string: linkString)
        else { throw ExportError.backend("Invalid link response.") }
        
        return link
    }
    
    // MARK: - PDF generation
    
    static func makePDF(entries: [Entry]) throws -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 48
        let headerHeight: CGFloat = 56
        let footerHeight: CGFloat = 28
        
        let figmaBlue = UIColor(red: 59/255, green: 70/255, blue: 173/255, alpha: 1)
        
        let bodyFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
        let dateFont = UIFont.systemFont(ofSize: 11, weight: .regular)
        let footerFont = UIFont.systemFont(ofSize: 11, weight: .regular)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        return renderer.pdfData { ctx in
            var page = 0
            let sorted = entries.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            
            func startPage() {
                ctx.beginPage()
                page += 1
                
                // ✅ Logo ONLY on first page
                if page == 1,
                   let logo = UIImage(
                    named: "pdfFullLogo",
                    in: Bundle.main,
                    with: nil
                   ) {
                    
                    let logoHeight: CGFloat = 40
                    let aspect = logo.size.width / logo.size.height
                    let logoWidth = logoHeight * aspect
                    let logoRect = CGRect(
                        x: margin,
                        y: margin,
                        width: logoWidth,
                        height: logoHeight
                    )
                    logo.draw(in: logoRect)
                }
                
                // Footer
                let footer = "Page \(page)"
                let footerSize = (footer as NSString).size(withAttributes: [.font: footerFont])
                footer.draw(
                    at: CGPoint(
                        x: pageRect.width - margin - footerSize.width,
                        y: pageRect.height - margin - footerHeight + 6
                    ),
                    withAttributes: [
                        .font: footerFont,
                        .foregroundColor: figmaBlue
                    ]
                )
            }
            
            startPage()
            var y = margin + headerHeight + 12
            
            for entry in sorted {
                let dateText = entry.createdAt.map { df.string(from: $0) } ?? "Unknown date"
                (dateText as NSString).draw(
                    in: CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: 16),
                    withAttributes: [
                        .font: dateFont,
                        .foregroundColor: figmaBlue.withAlphaComponent(0.55)
                    ]
                )
                y += 16
                
                let bodyText = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .paragraphStyle: paragraph,
                    .foregroundColor: figmaBlue
                ]
                
                let box = (bodyText as NSString).boundingRect(
                    with: CGSize(width: pageRect.width - 2 * margin, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: attrs,
                    context: nil
                )
                
                if y + box.height + 20 > pageRect.height - margin - footerHeight {
                    startPage()
                    y = margin + headerHeight + 12
                }
                
                (bodyText as NSString).draw(
                    in: CGRect(
                        x: margin,
                        y: y,
                        width: pageRect.width - 2 * margin,
                        height: ceil(box.height)
                    ),
                    withAttributes: attrs
                )
                
                y += box.height + 18
            }
        }
    }
}

// Default no-op
public struct NoopExporter: ExportService {
    public init() {}
    public func exportAndSend(entries: [Entry]) async throws -> URL {
        throw ExportError.unknown
    }
}
