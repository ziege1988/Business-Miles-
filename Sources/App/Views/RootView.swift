import SwiftUI

/// Was der Fahrt-Editor öffnen soll.
enum EditorRequest: Identifiable {
    case new
    case edit(Trip)
    case duplicate(Trip)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let t): "edit-\(t.id)"
        case .duplicate(let t): "dup-\(t.id)"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var router: AppRouter

    @State private var selectedYear = Fmt.calendar.component(.year, from: .now)
    @State private var editorRequest: EditorRequest? = nil
    @State private var showExport = false

    private var years: [YearSummary] { TripStatistics.years(from: store.trips) }

    private var selectedSummary: YearSummary {
        years.first(where: { $0.year == selectedYear })
            ?? YearSummary(year: selectedYear,
                           months: (1...12).map { MonthSummary(year: selectedYear, month: $0, trips: []) })
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                UpdateBanner()
                if store.folderURL == nil { folderBanner }
                YearDetailView(summary: selectedSummary,
                               rate: store.settings.ratePerKm,
                               onNew: { editorRequest = .new },
                               onSelect: { editorRequest = .edit($0) },
                               onDuplicate: { editorRequest = .duplicate($0) },
                               onDelete: { store.delete(id: $0.id) })
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            YearTilesView(years: years, selection: $selectedYear, axis: .vertical)
                .frame(width: 210)
                .background(Theme.background)
        }
        .background(Theme.background)
        .navigationTitle("Business Miles")
        .toolbar {
            ToolbarItem(placement: .status) { SyncBadge() }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showExport = true } label: {
                    Label("Exportieren", systemImage: "square.and.arrow.up")
                }
                .help("Liste als Excel oder PDF exportieren")

                SettingsLink {
                    Label("Einstellungen", systemImage: "gearshape")
                }
                .help("Einstellungen")

                Button { editorRequest = .new } label: {
                    Label("Neue Fahrt", systemImage: "plus")
                }
                .help("Neue Fahrt erfassen (⌘N)")
            }
        }
        .sheet(item: $editorRequest) { request in
            TripEditorView(request: request)
        }
        .sheet(isPresented: $showExport) {
            ExportSheet(summary: selectedSummary, settings: store.settings)
        }
        .task {
            if !ScreenshotMode.isActive {
                UpdateService.shared.checkIfDue()
                DesktopWidgetController.shared.start(store: store, router: router)
            }
        }
        .onChange(of: router.newTripRequested) { _, requested in
            if requested {
                editorRequest = .new
                router.newTripRequested = false
            }
        }
    }

    private var folderBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.title2)
                .foregroundStyle(Theme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("OneDrive-Ordner noch nicht verbunden")
                    .font(.headline)
                Text("Wähle einmalig deinen OneDrive-Ordner „Business-Miles“ – dann sind Mac und iPhone abgeglichen.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Button("Ordner wählen …") { store.chooseFolder() }
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(Color(red: 1, green: 0.97, blue: 0.93))
        .overlay(alignment: .bottom) { Divider() }
    }
}

/// Kleine Statusanzeige für den OneDrive-Abgleich in der Symbolleiste.
struct SyncBadge: View {
    @EnvironmentObject private var store: TripStore

    var body: some View {
        Button { store.sync() } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(text).font(.caption)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.secondaryText)
        .help(help)
    }

    private var color: Color {
        switch store.status {
        case .synced: Color(red: 0.18, green: 0.62, blue: 0.42)
        case .syncing: Theme.accent
        case .noFolder: Theme.warning
        case .failed: .red
        }
    }

    private var text: String {
        switch store.status {
        case .synced: "OneDrive synchronisiert"
        case .syncing: "Synchronisiere …"
        case .noFolder: "Kein OneDrive-Ordner"
        case .failed: "Sync-Fehler"
        }
    }

    private var help: String {
        switch store.status {
        case .synced(let date): "Zuletzt abgeglichen: \(date.formatted(date: .omitted, time: .shortened)) – klicken zum Abgleichen"
        case .failed(let message): message
        default: "Klicken zum Abgleichen"
        }
    }
}
