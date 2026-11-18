import Foundation
import AppKit

/// Hält alle Fahrten und Einstellungen und gleicht sie mit `business-miles.json`
/// im OneDrive-Ordner „Business-Miles“ ab (der OneDrive-Client synchronisiert den Ordner).
///
/// - Eine lokale Kopie (Application Support) sorgt dafür, dass die App auch ohne Ordner/Netz läuft.
/// - Beim Abgleich wird immer zusammengeführt (pro Fahrt gewinnt die jüngere Änderung),
///   nie blind überschrieben – identisch zur Web-App auf dem iPhone.
@MainActor
final class TripStore: ObservableObject {
    enum Status: Equatable {
        case noFolder
        case syncing
        case synced(Date)
        case failed(String)
    }

    nonisolated static let fileName = "business-miles.json"

    @Published private(set) var doc = DataFile()
    @Published private(set) var folderURL: URL?
    @Published private(set) var status: Status = .noFolder

    var trips: [Trip] { doc.trips.filter { !$0.deleted } }
    var settings: AppSettings { doc.settings }

    private var syncTask: Task<Void, Never>?
    private var syncAgain = false
    private var writeDebounce: Task<Void, Never>?
    private var timer: Timer?
    private var resolvingDistances = false

    private static let folderKey = "oneDriveFolderPath"

    init() {
        doc = Self.loadCache() ?? DataFile()
        folderURL = Self.savedFolder() ?? Self.detectOneDriveFolder()
        if let folderURL { UserDefaults.standard.set(folderURL.path, forKey: Self.folderKey) }
        if folderURL == nil { status = .noFolder }

        // Regelmäßig nach Änderungen vom iPhone schauen + beim Aktivieren der App
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sync() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sync() }
        }
        sync()
    }

    // MARK: Ändern

    func upsert(_ trip: Trip) {
        var t = trip
        t.updatedAt = ISOTime.now
        if let i = doc.trips.firstIndex(where: { $0.id == t.id }) {
            doc.trips[i] = t
        } else {
            doc.trips.append(t)
        }
        didChange()
    }

    func delete(id: String) {
        guard let i = doc.trips.firstIndex(where: { $0.id == id }) else { return }
        doc.trips[i].deleted = true
        doc.trips[i].updatedAt = ISOTime.now
        didChange()
    }

    func updateSettings(_ settings: AppSettings) {
        guard !settings.sameContent(as: doc.settings) else { return }
        var s = settings
        s.updatedAt = ISOTime.now
        doc.settings = s
        didChange()
    }

    private func didChange() {
        Self.saveCache(doc)
        writeDebounce?.cancel()
        writeDebounce = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            self?.sync()
        }
    }

    // MARK: Ordner

    /// Lässt den OneDrive-Ordner „Business-Miles“ auswählen (einmalig).
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Ordner verwenden"
        panel.message = "Bitte den OneDrive-Ordner „Business-Miles“ auswählen."
        let cloud = AppConfig.realHomeDirectory.appendingPathComponent("Library/CloudStorage")
        if FileManager.default.fileExists(atPath: cloud.path) { panel.directoryURL = cloud }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        UserDefaults.standard.set(url.path, forKey: Self.folderKey)
        folderURL = url
        sync()
    }

    var folderLooksRight: Bool {
        folderURL?.lastPathComponent.lowercased().contains("business-miles") ?? false
    }

    private static func savedFolder() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: folderKey),
              FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// Sucht ~/Library/CloudStorage/OneDrive…/Business-Miles (Groß-/Kleinschreibung egal).
    static func detectOneDriveFolder() -> URL? {
        let fm = FileManager.default
        let cloud = AppConfig.realHomeDirectory.appendingPathComponent("Library/CloudStorage")
        let drives = ((try? fm.contentsOfDirectory(atPath: cloud.path)) ?? [])
            .filter { $0.lowercased().hasPrefix("onedrive") }
            .sorted()
        for drive in drives {
            let base = cloud.appendingPathComponent(drive)
            let entries = (try? fm.contentsOfDirectory(atPath: base.path)) ?? []
            if let match = entries.first(where: { $0.lowercased() == "business-miles" }) {
                return base.appendingPathComponent(match, isDirectory: true)
            }
        }
        return nil
    }

    // MARK: Abgleich

    func sync() {
        guard let folder = folderURL else {
            status = .noFolder
            return
        }
        if syncTask != nil {
            syncAgain = true
            return
        }
        status = .syncing
        let local = doc
        syncTask = Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                Result { try FileSync.synchronize(folder: folder, local: local) }
            }.value
            guard let self else { return }
            switch result {
            case .success(let merged):
                // Änderungen, die während des Abgleichs entstanden sind, behalten
                self.doc = DataFile.merge(merged, self.doc)
                Self.saveCache(self.doc)
                self.status = .synced(Date())
            case .failure(let error):
                self.status = .failed(error.localizedDescription)
            }
            self.syncTask = nil
            if self.syncAgain {
                self.syncAgain = false
                self.sync()
            } else {
                await self.resolvePendingDistances()
            }
        }
    }

    /// Offline (z. B. am iPhone) erfasste Fahrten ohne km nachberechnen.
    private func resolvePendingDistances() async {
        guard !resolvingDistances else { return }
        let pending = doc.trips.filter { $0.kmPending && !$0.deleted }
        guard !pending.isEmpty else { return }
        resolvingDistances = true
        defer { resolvingDistances = false }

        let home = settings.home
        var changed = false
        for var t in pending {
            let start = t.startUsesHome ? home : t.start
            let back = t.returnUsesHome ? home : t.returnTarget
            guard start.isUsable, t.destination.isUsable else { continue }
            do {
                t.outboundKm = try await RouteService.drivingDistanceKm(from: start, to: t.destination)
                if t.returnEnabled, back.isUsable {
                    t.returnKm = try await RouteService.drivingDistanceKm(from: t.destination, to: back)
                }
                if t.startUsesHome { t.start = home }
                if t.returnUsesHome { t.returnTarget = home }
                t.kmPending = t.totalKm <= 0
                t.updatedAt = ISOTime.now
                if let i = doc.trips.firstIndex(where: { $0.id == t.id }) {
                    doc.trips[i] = t
                    changed = true
                }
            } catch {
                continue
            }
        }
        if changed { didChange() }
    }

    // MARK: Lokale Kopie

    private static var cacheURL: URL {
        let dir = AppConfig.supportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("cache.json")
    }

    private static func loadCache() -> DataFile? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(DataFile.self, from: data)
    }

    private static func saveCache(_ doc: DataFile) {
        if let data = try? doc.fileData() { try? data.write(to: cacheURL, options: .atomic) }
    }
}

/// Dateizugriff im OneDrive-Ordner (koordiniert, damit der OneDrive-Client nicht dazwischenfunkt).
enum FileSync {
    enum SyncError: LocalizedError {
        case unreadable(String)
        var errorDescription: String? {
            switch self {
            case .unreadable(let name): "„\(name)“ ist beschädigt und wurde nicht überschrieben. Bitte prüfen."
            }
        }
    }

    static func synchronize(folder: URL, local: DataFile) throws -> DataFile {
        let main = folder.appendingPathComponent(TripStore.fileName)
        let remote = try read(main)
        var merged = DataFile.merge(remote ?? DataFile(), local)

        // Konfliktkopien des OneDrive-Clients (z. B. „business-miles-MacBook.json“) einsammeln
        let copies = conflictCopies(in: folder)
        for copy in copies {
            if let other = try? read(copy) { merged = DataFile.merge(merged, other) }
        }

        if remote == nil || merged.canonicalData() != remote!.canonicalData() {
            try write(merged, to: main)
        }
        for copy in copies { remove(copy) }
        return merged
    }

    private static func conflictCopies(in folder: URL) -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names
            .filter { $0 != TripStore.fileName && $0.lowercased().hasPrefix("business-miles") && $0.lowercased().hasSuffix(".json") }
            .map { folder.appendingPathComponent($0) }
    }

    /// nil = Datei existiert (noch) nicht.
    private static func read(_ url: URL) throws -> DataFile? {
        var coordError: NSError?
        var data: Data?
        var readError: Error?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { u in
            do { data = try Data(contentsOf: u) } catch { readError = error }
        }
        if let readError {
            let ns = readError as NSError
            if ns.domain == NSCocoaErrorDomain && (ns.code == NSFileReadNoSuchFileError || ns.code == NSFileNoSuchFileError) {
                return nil
            }
            throw readError
        }
        if let coordError { throw coordError }
        guard let data, !data.isEmpty else { return nil }
        do {
            return try JSONDecoder().decode(DataFile.self, from: data)
        } catch {
            throw SyncError.unreadable(url.lastPathComponent)
        }
    }

    private static func write(_ doc: DataFile, to url: URL) throws {
        let data = try doc.fileData()
        var coordError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { u in
            do { try data.write(to: u, options: .atomic) } catch { writeError = error }
        }
        if let writeError { throw writeError }
        if let coordError { throw coordError }
    }

    private static func remove(_ url: URL) {
        var coordError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordError) { u in
            try? FileManager.default.removeItem(at: u)
        }
    }
}
