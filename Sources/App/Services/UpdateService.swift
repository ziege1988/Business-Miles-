import Foundation
import AppKit

/// Prüft GitHub-Releases auf neue Versionen und installiert sie (ZIP laden, App ersetzen, neu starten).
@MainActor
final class UpdateService: ObservableObject {
    static let shared = UpdateService()

    struct Release: Equatable {
        let build: Int
        let title: String
        let notes: String
        let publishedAt: Date?
        let zipURL: URL
        let pageURL: URL
    }

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case downloading
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastCheck: Date?

    static let repo = "ziege1988/Business-Miles-"
    static let releasesPage = URL(string: "https://github.com/\(repo)/releases")!
    private static let latestAPI = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
    private static let lastCheckKey = "updateLastCheck"

    /// Build-Nummer dieser App (wird beim Bauen auf GitHub gesetzt).
    let installedBuild: Int = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    let installedVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"

    var availableRelease: Release? {
        if case .available(let r) = state { return r }
        return nil
    }

    private init() {
        lastCheck = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
    }

    // MARK: Prüfen

    /// Beim Start: höchstens einmal am Tag automatisch prüfen.
    func checkIfDue() {
        if let lastCheck, Date().timeIntervalSince(lastCheck) < 20 * 3600 { return }
        Task { await check() }
    }

    func check() async {
        state = .checking
        do {
            var request = URLRequest(url: Self.latestAPI)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw UpdateError.message("GitHub ist gerade nicht erreichbar.")
            }
            let release = try Self.parse(data)
            lastCheck = Date()
            UserDefaults.standard.set(lastCheck, forKey: Self.lastCheckKey)
            state = release.build > installedBuild ? .available(release) : .upToDate
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private static func parse(_ data: Data) throws -> Release {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let build = Int(tag.filter(\.isNumber)),
              let assets = json["assets"] as? [[String: Any]],
              let zip = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".zip") == true }),
              let zipString = zip["browser_download_url"] as? String,
              let zipURL = URL(string: zipString)
        else { throw UpdateError.message("Die Release-Informationen sind unvollständig.") }
        let page = (json["html_url"] as? String).flatMap(URL.init(string:)) ?? releasesPage
        return Release(
            build: build,
            title: json["name"] as? String ?? tag,
            notes: (json["body"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            publishedAt: ISOTime.date(json["published_at"] as? String),
            zipURL: zipURL,
            pageURL: page
        )
    }

    // MARK: Installieren

    func install(_ release: Release) async {
        let appURL = Bundle.main.bundleURL
        if appURL.path.contains("/AppTranslocation/") {
            state = .failed("Bitte „Business Miles“ zuerst in den Ordner „Programme“ ziehen und von dort starten.")
            return
        }
        guard FileManager.default.isWritableFile(atPath: appURL.deletingLastPathComponent().path) else {
            state = .failed("Keine Schreibrechte im Ordner „\(appURL.deletingLastPathComponent().lastPathComponent)“.")
            return
        }

        state = .downloading
        do {
            let work = FileManager.default.temporaryDirectory
                .appendingPathComponent("BusinessMilesUpdate-\(release.build)", isDirectory: true)
            try? FileManager.default.removeItem(at: work)
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

            let (tmpZip, response) = try await URLSession.shared.download(from: release.zipURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw UpdateError.message("Download fehlgeschlagen.")
            }
            let zip = work.appendingPathComponent("update.zip")
            try FileManager.default.moveItem(at: tmpZip, to: zip)

            state = .installing
            let unpacked = work.appendingPathComponent("app", isDirectory: true)
            try run("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path])
            guard let newApp = (try FileManager.default.contentsOfDirectory(at: unpacked, includingPropertiesForKeys: nil))
                .first(where: { $0.pathExtension == "app" }) else {
                throw UpdateError.message("Im Download wurde keine App gefunden.")
            }
            try run("/usr/bin/codesign", ["--verify", "--deep", newApp.path])

            // Austausch erst, wenn diese App beendet ist – danach neu starten
            let script = work.appendingPathComponent("install.sh")
            let pid = ProcessInfo.processInfo.processIdentifier
            let content = """
            #!/bin/sh
            while kill -0 \(pid) 2>/dev/null; do sleep 0.3; done
            rm -rf \(shellQuote(appURL.path))
            mv \(shellQuote(newApp.path)) \(shellQuote(appURL.path))
            xattr -dr com.apple.quarantine \(shellQuote(appURL.path)) 2>/dev/null
            open \(shellQuote(appURL.path))
            """
            try content.write(to: script, atomically: true, encoding: .utf8)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [script.path]
            try process.run()

            NSApp.terminate(nil)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw UpdateError.message("Das Update konnte nicht entpackt bzw. geprüft werden (\(URL(fileURLWithPath: tool).lastPathComponent)).")
        }
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    enum UpdateError: LocalizedError {
        case message(String)
        var errorDescription: String? {
            switch self {
            case .message(let m): m
            }
        }
    }
}
