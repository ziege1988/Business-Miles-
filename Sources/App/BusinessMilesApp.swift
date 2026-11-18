import SwiftUI

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
    @StateObject private var store = TripStore()
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
            .environmentObject(store)
            .environmentObject(router)
            .preferredColorScheme(.light)
            .tint(Theme.accent)
            .onOpenURL { router.handle($0) }
            .task {
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(.easeOut(duration: 0.45)) { showSplash = false }
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
