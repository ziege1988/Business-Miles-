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
    @Published private(set) var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @Published private(set) var loginItemMessage: String?

    private enum Keys {
        static let enabled = "desktopWidget.enabled"
        static let size = "desktopWidget.size"
        static let origin = "desktopWidget.origin"
    }

    private var panel: NSPanel?
    private weak var store: TripStore?
    private weak var router: AppRouter?
    private static let margin: CGFloat = 14

    private init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        size = TileSize(rawValue: defaults.string(forKey: Keys.size) ?? "") ?? .medium
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

        let view = DesktopWidgetView(size: size,
                                     onDrag: { [weak self] phase in self?.drag(phase) },
                                     onOpen: { Self.openApp() },
                                     onNewTrip: { [weak router] in
                                         Self.openApp()
                                         router?.newTripRequested = true
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

    private static func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        if let main = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain }) {
            main.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: Autostart

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginItemMessage = nil
        } catch {
            loginItemMessage = "Autostart konnte nicht geändert werden: \(error.localizedDescription). Alternativ: Systemeinstellungen → Allgemein → Anmeldeobjekte."
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval {
            loginItemMessage = "Bitte in Systemeinstellungen → Allgemein → Anmeldeobjekte „Business Miles“ erlauben."
            SMAppService.openSystemSettingsLoginItems()
        }
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
                               onNewTrip: size == .medium ? onNewTrip : nil)
                .padding(16)
                .frame(width: size.contentSize.width, height: size.contentSize.height)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white)
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
                }
                .padding(14)
                .preferredColorScheme(.light)
        }
    }
}

/// Einstellungen → „Schreibtisch-Widget“
struct DesktopWidgetSection: View {
    @ObservedObject var controller = DesktopWidgetController.shared

    var body: some View {
        Section {
            Toggle("Widget auf dem Schreibtisch anzeigen", isOn: $controller.isEnabled)
            Picker("Größe", selection: $controller.size) {
                ForEach(TileSize.allCases) { Text($0.label).tag($0) }
            }
            .disabled(!controller.isEnabled)
            Toggle("Beim Anmelden automatisch starten", isOn: Binding(
                get: { controller.launchAtLogin },
                set: { controller.setLaunchAtLogin($0) }
            ))
            if let message = controller.loginItemMessage {
                Text(message).font(.footnote).foregroundStyle(Theme.warning)
            }
        } header: {
            Text("Schreibtisch-Widget")
        } footer: {
            Text("Die Kachel lässt sich mit der Maus an jede Stelle ziehen. Klick öffnet die App, Rechtsklick zeigt weitere Aktionen. Sie ist sichtbar, solange Business Miles läuft – daher Autostart empfohlen.")
        }
    }
}
