import SwiftUI
import AppKit
import ServiceManagement

/// Business-Miles-Kachel direkt auf dem Schreibtisch – ein eigenes, rahmenloses Fenster auf
/// Schreibtisch-Ebene (unter allen Programmfenstern, auf allen Spaces). Funktioniert ohne
/// Apple-Entwicklerkonto, anders als ein WidgetKit-Widget.
@MainActor
final class DesktopWidgetController: ObservableObject {
    static let shared = DesktopWidgetController()

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.enabled); apply() }
    }
    @Published var size: TileSize {
        didSet { UserDefaults.standard.set(size.rawValue, forKey: Keys.size); rebuild() }
    }
    @Published private(set) var launchAtLogin: Bool = LoginLauncher.isEnabled
    @Published private(set) var loginItemMessage: String?
    @Published var appearance: TileAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance)
            panel?.appearance = appearance.nsAppearance
        }
    }

    private enum Keys {
        static let enabled = "desktopWidget.enabled"
        static let size = "desktopWidget.size"
        static let origin = "desktopWidget.origin"
        static let appearance = "desktopWidget.appearance"
    }

    private var panel: NSPanel?
    private weak var store: TripStore?
    private weak var router: AppRouter?
    private static let margin: CGFloat = 14

    private init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        size = TileSize(rawValue: defaults.string(forKey: Keys.size) ?? "") ?? .medium
        appearance = TileAppearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .light
    }

    func start(store: TripStore, router: AppRouter) {
        self.store = store
        self.router = router
        apply()
    }

    // MARK: Fenster

    private func apply() {
        if isEnabled { show() } else { hide() }
    }

    private func rebuild() {
        hide()
        apply()
    }

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func show() {
        guard panel == nil, let store, let router else { return }
        let content = size.contentSize
        let frameSize = CGSize(width: content.width + 2 * Self.margin, height: content.height + 2 * Self.margin)

        let panel = NSPanel(contentRect: CGRect(origin: origin(for: frameSize), size: frameSize),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        panel.isMovableByWindowBackground = false   // Verschieben übernimmt die Kachel selbst (siehe drag…)
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.appearance = appearance.nsAppearance

        let view = DesktopWidgetView(size: size,
                                     onDrag: { [weak self] phase in self?.drag(phase) },
                                     onOpen: { [weak self] in self?.openApp() },
                                     onNewTrip: { [weak self, weak router] in
                                         router?.newTripRequested = true
                                         self?.openApp()
                                     })
            .environmentObject(store)
        panel.contentView = FirstClickHostingView(rootView: view)
        panel.orderFrontRegardless()

        self.panel = panel
    }

    // MARK: Verschieben (in Bildschirmkoordinaten – kein Ruckeln, während sich das Fenster bewegt)

    enum DragPhase { case changed, ended }
    private var dragStartOrigin: CGPoint?
    private var dragStartMouse: CGPoint = .zero

    func drag(_ phase: DragPhase) {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        if dragStartOrigin == nil {
            dragStartOrigin = panel.frame.origin
            dragStartMouse = mouse
        }
        guard let start = dragStartOrigin else { return }
        panel.setFrameOrigin(CGPoint(x: start.x + mouse.x - dragStartMouse.x, y: start.y + mouse.y - dragStartMouse.y))
        if phase == .ended {
            dragStartOrigin = nil
            UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: Keys.origin)
        }
    }

    /// Gespeicherte Position – sonst oben links unter der Menüleiste.
    private func origin(for size: CGSize) -> CGPoint {
        if let saved = UserDefaults.standard.string(forKey: Keys.origin) {
            let p = NSPointFromString(saved)
            if NSScreen.screens.contains(where: { $0.frame.contains(CGPoint(x: p.x + 20, y: p.y + 20)) }) { return p }
        }
        let visible = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        return CGPoint(x: visible.minX + 16, y: visible.maxY - size.height - 16)
    }

    /// Programmfenster zeigen – öffnet es neu, falls es geschlossen war, und holt das Dock-Symbol zurück.
    func openApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let main = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain && $0.title == "Business Miles" })
            ?? NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain && $0.isVisible }) {
            main.makeKeyAndOrderFront(nil)
        } else if let open = router?.openMainWindow {
            open()
        } else {
            // Noch nie ein Fenster gehabt (Start nur mit Kachel): wie ein Klick aufs Dock-Symbol
            NSWorkspace.shared.open(Bundle.main.bundleURL)
        }
    }

    // MARK: Autostart

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try LoginLauncher.enable() } else { LoginLauncher.disable() }
            loginItemMessage = enabled
                ? "Aktiv. Falls macOS meldet „Hintergrundobjekt hinzugefügt“, bitte erlauben (Systemeinstellungen → Allgemein → Anmeldeobjekte)."
                : nil
        } catch {
            loginItemMessage = "Autostart konnte nicht eingerichtet werden: \(error.localizedDescription)"
        }
        launchAtLogin = LoginLauncher.isEnabled
    }
}

/// Erlaubt Klicks, ohne dass das Fenster vorher aktiviert werden muss.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Die Kachel selbst (gleicher Inhalt wie das frühere Widget).
struct DesktopWidgetView: View {
    @EnvironmentObject private var store: TripStore
    let size: TileSize
    let onDrag: (DesktopWidgetController.DragPhase) -> Void
    let onOpen: () -> Void
    let onNewTrip: () -> Void

    var body: some View {
        // Alle 5 Minuten neu zeichnen (Monatswechsel um Mitternacht)
        TimelineView(.periodic(from: .now, by: 300)) { context in
            MilesWidgetContent(entry: MilesEntry(date: context.date, snapshot: WidgetSync.snapshot(for: store.trips)),
                               family: size,
                               onNewTrip: size == .medium ? onNewTrip : nil,
                               dark: isDark)
                .padding(16)
                .frame(width: size.contentSize.width, height: size.contentSize.height)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(isDark ? TileAppearance.darkBackground : Color.white)
                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 3)
                )
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .onTapGesture(count: 1, perform: onOpen)
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { _ in onDrag(.changed) }
                        .onEnded { _ in onDrag(.ended) }
                )
                .contextMenu {
                    Button("Business Miles öffnen", action: onOpen)
                    Button("Neue Fahrt", action: onNewTrip)
                    Divider()
                    Button("Kachel ausblenden") { DesktopWidgetController.shared.isEnabled = false }
                    Button("Business Miles beenden") { NSApp.terminate(nil) }
                }
                .padding(14)
        }
    }

    /// Folgt der Einstellung (über die Darstellung des Kachel-Fensters)
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
}

/// Einstellungen → „Schreibtisch-Widget“
struct DesktopWidgetSection: View {
    @ObservedObject var controller = DesktopWidgetController.shared
    @AppStorage(AppDelegate.openWindowOnLaunchKey) private var openWindowOnLaunch = true

    var body: some View {
        Section {
            Toggle("Widget auf dem Schreibtisch anzeigen", isOn: $controller.isEnabled)
            Picker("Größe", selection: $controller.size) {
                ForEach(TileSize.allCases) { Text($0.label).tag($0) }
            }
            .disabled(!controller.isEnabled)
            Picker("Darstellung", selection: $controller.appearance) {
                ForEach(TileAppearance.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(!controller.isEnabled)
            Toggle("Beim Anmelden automatisch starten", isOn: Binding(
                get: { controller.launchAtLogin },
                set: { controller.setLaunchAtLogin($0) }
            ))
            if let message = controller.loginItemMessage {
                Text(message).font(.footnote).foregroundStyle(Theme.warning)
            }
            Toggle("Programmfenster beim Start öffnen", isOn: $openWindowOnLaunch)
        } header: {
            Text("Schreibtisch-Widget")
        } footer: {
            Text("Beim automatischen Start nach der Anmeldung erscheint nur die Kachel – ohne Fenster und Dock-Symbol. Schließt du das Fenster, läuft Business Miles unsichtbar weiter. Klick auf die Kachel öffnet die App, Rechtsklick → „Business Miles beenden“ beendet sie ganz. Die Kachel lässt sich mit der Maus verschieben.")
        }
    }
}

/// Darstellung der Schreibtisch-Kachel (unabhängig von der App)
enum TileAppearance: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
    var label: String {
        switch self {
        case .light: "Hell"
        case .dark: "Dunkel"
        case .system: "Wie System"
        }
    }
    var nsAppearance: NSAppearance? {
        switch self {
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        case .system: nil
        }
    }
    /// Dunkelgrau für den Hintergrund im Dunkelmodus (#2C2F33)
    static let darkBackground = Color(red: 0.173, green: 0.184, blue: 0.200)
}

/// Autostart über einen eigenen LaunchAgent (~/Library/LaunchAgents) – zuverlässiger als
/// Anmeldeobjekte für Apps ohne Apple-Entwicklerkonto und unabhängig von Updates.
/// Übergibt „--login“, damit die App nur mit der Kachel (ohne Fenster) startet.
@MainActor
enum LoginLauncher {
    static let label = "app.businessmiles.autostart"

    static var plistURL: URL {
        AppConfig.realHomeDirectory.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

    static func enable() throws {
        let dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-a", Bundle.main.bundlePath, "--args", "--login"],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
        ]
        try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
        // Alte Anmeldeobjekt-Registrierung entfernen (sonst doppelter Start)
        if SMAppService.mainApp.status == .enabled { try? SMAppService.mainApp.unregister() }
    }

    static func disable() {
        try? FileManager.default.removeItem(at: plistURL)
        if SMAppService.mainApp.status == .enabled { try? SMAppService.mainApp.unregister() }
    }

    /// Beim Start: auf neuen Weg umstellen (früher SMAppService) und Pfad aktuell halten.
    static func refresh() {
        if SMAppService.mainApp.status == .enabled, !isEnabled {
            try? enable()   // war per Anmeldeobjekt aktiv → umziehen
            return
        }
        guard isEnabled,
              let data = try? Data(contentsOf: plistURL),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let args = dict["ProgramArguments"] as? [String]
        else { return }
        if !args.contains(Bundle.main.bundlePath) { try? enable() }
    }
}
