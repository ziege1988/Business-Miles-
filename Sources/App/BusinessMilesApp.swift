import SwiftUI
import AppKit
import CoreServices

/// Steuert app-weite Aktionen (Menübefehl, Widget-Link).
@MainActor
final class AppRouter: ObservableObject {
    @Published var newTripRequested = false
    /// Öffnet das Programmfenster (wird vom Fenster selbst gesetzt, funktioniert auch nachdem es geschlossen wurde)
    var openMainWindow: (() -> Void)?

    func handle(_ url: URL) {
        guard url.scheme == AppConfig.urlScheme else { return }
        if url.host == "new" { newTripRequested = true }
    }
}

/// Startverhalten und Dock-Symbol: Ohne offenes Fenster läuft die App unsichtbar weiter
/// (nur die Schreibtisch-Kachel ist sichtbar), wie bei typischen Schreibtisch-Widgets.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let openWindowOnLaunchKey = "openWindowOnLaunch"
    /// Wurde die App als Anmeldeobjekt (Autostart) gestartet?
    private(set) static var launchedAsLoginItem = false

    /// Soll das Programmfenster beim Start geschlossen bleiben?
    static var startHidden: Bool {
        if ScreenshotMode.isActive { return false }
        let openOnLaunch = UserDefaults.standard.object(forKey: openWindowOnLaunchKey) as? Bool ?? true
        return launchedAsLoginItem || !openOnLaunch
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           event.eventID == AEEventID(kAEOpenApplication),
           event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem) {
            Self.launchedAsLoginItem = true
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
            // Kurz warten, bis das Fenster wirklich weg ist
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                MainActor.assumeIsolated { Self.updateDockIcon() }
            }
        }
    }

    /// Kein sichtbares Programmfenster → kein Dock-Symbol (Kachel bleibt)
    static func updateDockIcon() {
        let hasWindow = NSApp.windows.contains { $0.isVisible && !($0 is NSPanel) && $0.canBecomeMain }
        let wanted: NSApplication.ActivationPolicy = hasWindow ? .regular : .accessory
        if NSApp.activationPolicy() != wanted { NSApp.setActivationPolicy(wanted) }
    }

    /// Fenster schließen beendet die App nicht – die Kachel bleibt stehen.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct BusinessMilesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ScreenshotMode.isActive
        ? TripStore(preview: ScreenshotMode.sampleData())
        : TripStore()
    @StateObject private var router = AppRouter()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup(id: "main") {
            ZStack {
                RootView()
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .environmentObject(store)
            .environmentObject(router)
            .preferredColorScheme(.light)
            .tint(Theme.accent)
            .onOpenURL { router.handle($0) }
            .task {
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(.easeOut(duration: 0.45)) { showSplash = false }
            }
            .task {
                if ScreenshotMode.isActive { await ScreenshotMode.run(store: store, router: router) }
            }
            .frame(minWidth: 920, minHeight: 620)
        }
        .defaultSize(width: 1200, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Neue Fahrt") { router.newTripRequested = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Mit OneDrive abgleichen") { store.sync() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .frame(width: 560, height: 720)
                .preferredColorScheme(.light)
                .tint(Theme.accent)
        }
    }
}
