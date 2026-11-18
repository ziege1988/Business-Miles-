import SwiftUI
import SwiftData

/// Steuert app-weite Aktionen (Menübefehl, Widget-Link).
@MainActor
final class AppRouter: ObservableObject {
    @Published var newTripRequested = false

    func handle(_ url: URL) {
        guard url.scheme == AppConfig.urlScheme else { return }
        if url.host == "new" { newTripRequested = true }
    }
}

@main
struct BusinessMilesApp: App {
    private let container = Persistence.makeContainer()
    @StateObject private var router = AppRouter()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .environmentObject(router)
            .preferredColorScheme(.light)
            .tint(Theme.accent)
            .onOpenURL { router.handle($0) }
            .task {
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(.easeOut(duration: 0.45)) { showSplash = false }
            }
            #if os(macOS)
            .frame(minWidth: 920, minHeight: 620)
            #endif
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1200, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Neue Fahrt") { router.newTripRequested = true }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .frame(width: 560, height: 680)
                .preferredColorScheme(.light)
                .tint(Theme.accent)
        }
        .modelContainer(container)
        #endif
    }
}
