import Foundation
import SwiftData

enum SyncMode: String {
    case iCloud = "iCloud-Sync aktiv"
    case localOnly = "Nur lokal gespeichert (kein iCloud)"
    case inMemory = "Temporär (Speicher nicht verfügbar)"
}

/// Erstellt den SwiftData-Container. Bevorzugt iCloud (CloudKit, private Datenbank),
/// fällt bei fehlender Berechtigung/Anmeldung auf lokale Speicherung zurück.
enum Persistence {
    private(set) static var syncMode: SyncMode = .localOnly

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Trip.self, UserProfile.self])
        let groupID = AppConfig.appGroupID
        let hasGroup = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID) != nil

        if let cloudID = AppConfig.cloudKitContainerID, !cloudID.isEmpty {
            do {
                let config = ModelConfiguration(
                    "BusinessMiles",
                    schema: schema,
                    groupContainer: hasGroup ? .identifier(groupID) : .none,
                    cloudKitDatabase: .private(cloudID)
                )
                let container = try ModelContainer(for: schema, configurations: [config])
                syncMode = .iCloud
                return container
            } catch {
                print("⚠️ iCloud-Container nicht verfügbar, nutze lokale Speicherung: \(error)")
            }
        }

        do {
            let config = ModelConfiguration(
                "BusinessMiles",
                schema: schema,
                groupContainer: hasGroup ? .identifier(groupID) : .none,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [config])
            syncMode = .localOnly
            return container
        } catch {
            print("⚠️ Lokaler Speicher nicht verfügbar: \(error)")
        }

        syncMode = .inMemory
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema,
                                   configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }
}
