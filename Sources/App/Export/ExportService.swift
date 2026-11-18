import SwiftUI
import UniformTypeIdentifiers
import AppKit

enum ExportFormat: String, CaseIterable, Identifiable {
    case excel, pdf
    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .excel: "xlsx"
        case .pdf: "pdf"
        }
    }

    var contentType: UTType {
        switch self {
        case .excel: UTType(filenameExtension: "xlsx") ?? .spreadsheet
        case .pdf: .pdf
        }
    }

    var label: String {
        switch self {
        case .excel: "Excel"
        case .pdf: "PDF"
        }
    }
}

@MainActor
enum ExportService {

    static func data(for report: ReportData, format: ExportFormat) -> Data {
        switch format {
        case .excel: XLSXExporter.make(report)
        case .pdf: makePDF(report)
        }
    }

    static func fileName(for report: ReportData, format: ExportFormat) -> String {
        "\(report.fileBaseName).\(format.fileExtension)"
    }

    // MARK: PDF

    static func makePDF(_ report: ReportData) -> Data {
        let pages = ReportLayout.paginate(report)
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: ReportLayout.pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return Data() }

        for page in pages {
            let renderer = ImageRenderer(content: ReportPageView(report: report, page: page))
            renderer.proposedSize = ProposedViewSize(ReportLayout.pageSize)
            renderer.render { _, draw in
                pdf.beginPDFPage(nil)
                draw(pdf)
                pdf.endPDFPage()
            }
        }
        pdf.closePDF()
        return data as Data
    }

    // MARK: Speichern

    /// Speichert im Standard-Exportordner. Gibt `nil` zurück, wenn keiner hinterlegt ist.
    static func saveToExportFolder(_ data: Data, fileName: String) throws -> URL? {
        guard let folder = ExportFolderStore.folderURL() else { return nil }
        let target = uniqueURL(in: folder, fileName: fileName)
        try data.write(to: target, options: .atomic)
        return target
    }

    /// Fragt per Sichern-Dialog nach dem Speicherort.
    static func saveWithPanel(_ data: Data, fileName: String, type: UTType) throws -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.allowedContentTypes = [type]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try data.write(to: url, options: .atomic)
        return url
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private static func uniqueURL(in folder: URL, fileName: String) -> URL {
        var url = folder.appendingPathComponent(fileName)
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base) (\(n)).\(ext)")
            n += 1
        }
        return url
    }
}

/// Merkt sich den Exportordner (nur auf diesem Mac).
enum ExportFolderStore {
    private static let key = "exportFolderPath"

    static func folderURL() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: key),
              FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    @discardableResult
    static func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Als Exportordner wählen"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        UserDefaults.standard.set(url.path, forKey: key)
        return url
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
