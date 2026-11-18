import Foundation

/// Zentrale Konfiguration. Die IDs werden beim Build aus `project.yml`
/// (Variable `BUNDLE_ID_PREFIX`) in die Info.plist geschrieben.
enum AppConfig {
    static let appGroupID: String =
        (Bundle.main.object(forInfoDictionaryKey: "BMAppGroupID") as? String)
        ?? "group.de.example.businessmiles"

    static let cloudKitContainerID: String? =
        Bundle.main.object(forInfoDictionaryKey: "BMCloudKitContainerID") as? String

    static let urlScheme = "businessmiles"
    static let newTripURL = URL(string: "businessmiles://new")!
    static let openURL = URL(string: "businessmiles://open")!

    /// Gemeinsame UserDefaults für App und Widget.
    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}
