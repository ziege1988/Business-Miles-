import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
import Photos
#endif

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

    // MARK: Bilder

    static func pageImages(_ report: ReportData, scale: CGFloat = 2) -> [CGImage] {
        ReportLayout.paginate(report).compactMap { page in
            let renderer = ImageRenderer(content: ReportPageView(report: report, page: page))
            renderer.proposedSize = ProposedViewSize(ReportLayout.pageSize)
            renderer.scale = scale
            return renderer.cgImage
        }
    }

    // MARK: Speichern

    /// Schreibt die Datei in ein temporäres Verzeichnis (zum Teilen).
    static func writeTemporary(_ data: Data, fileName: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    #if os(macOS)
    /// Speichert im Standard-Exportordner. Gibt `nil` zurück, wenn keiner hinterlegt ist.
    static func saveToExportFolder(_ data: Data, fileName: String) throws -> URL? {
        guard let folder = ExportFolderStore.folderURL() else { return nil }
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
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
    #else
    enum PhotoError: LocalizedError {
        case denied
        var errorDescription: String? {
            "Kein Zugriff auf Fotos. Bitte in den Einstellungen → Datenschutz → Fotos erlauben."
        }
    }

    /// Speichert jede Berichtsseite als Bild in der Fotos-Mediathek.
    static func saveImagesToPhotos(_ report: ReportData) async throws -> Int {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw PhotoError.denied }

        let images = pageImages(report, scale: 2)
        let pngs = images.compactMap { UIImage(cgImage: $0).pngData() }
        try await PHPhotoLibrary.shared().performChanges {
            for png in pngs {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: png, options: nil)
            }
        }
        return pngs.count
    }
    #endif
}

#if os(macOS)
/// Merkt sich den Exportordner (Security-Scoped Bookmark, nur auf diesem Mac).
enum ExportFolderStore {
    private static let key = "exportFolderBookmark"

    static func folderURL() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                                 relativeTo: nil, bookmarkDataIsStale: &stale)
        else { return nil }
        if stale { store(url) }
        return url
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
        store(url)
        return url
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func store(_ url: URL) {
        if let data = try? url.bookmarkData(options: .withSecurityScope,
                                            includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
#endif

/// Hülle für `.fileExporter`.
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf, .spreadsheet, .data] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
