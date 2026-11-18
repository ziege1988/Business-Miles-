import Foundation

/// Zentrale Konfiguration (App und Widget).
enum AppConfig {
    static let urlScheme = "businessmiles"
    static let newTripURL = URL(string: "businessmiles://new")!
    static let openURL = URL(string: "businessmiles://open")!

    /// Echtes Benutzerverzeichnis – auch aus dem (sandboxed) Widget heraus.
    static var realHomeDirectory: URL {
        if let dir = getpwuid(getuid())?.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    /// ~/Library/Application Support/BusinessMiles – hier liegen lokale Kopie und Widget-Daten.
    /// Das Widget darf diesen Ordner lesen (Entitlement „home-relative-path.read-only“).
    static var supportDirectory: URL {
        realHomeDirectory.appendingPathComponent("Library/Application Support/BusinessMiles", isDirectory: true)
    }
}
