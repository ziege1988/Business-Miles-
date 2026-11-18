import SwiftUI
import SwiftData

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
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var router: AppRouter

    @Query(sort: \Trip.date, order: .reverse) private var trips: [Trip]
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    @State private var selectedYear = Fmt.calendar.component(.year, from: .now)
    @State private var editorRequest: EditorRequest? = nil
    @State private var showExport = false
    @State private var showSettings = false

    private var years: [YearSummary] { TripStatistics.years(from: trips) }
    private var profile: UserProfile? { ProfileStore.current(profiles) }

    private var selectedSummary: YearSummary {
        years.first(where: { $0.year == selectedYear })
            ?? YearSummary(year: selectedYear,
                           months: (1...12).map { MonthSummary(year: selectedYear, month: $0, trips: []) })
    }

    var body: some View {
        content
            .sheet(item: $editorRequest) { request in
                TripEditorView(request: request, profile: profile, allTrips: trips)
            }
            .sheet(isPresented: $showExport) {
                ExportSheet(summary: selectedSummary, profile: profile)
            }
            #if os(iOS)
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            #endif
            .onAppear { ProfileStore.ensure(in: context, profiles: profiles) }
            .onChange(of: profiles.count) { _, _ in
                ProfileStore.removeEmptyDuplicates(in: context, profiles: profiles)
            }
            .onChange(of: WidgetSync.signature(of: trips), initial: true) {
                WidgetSync.update(with: trips)
            }
            .onChange(of: router.newTripRequested) { _, requested in
                if requested {
                    editorRequest = .new
                    router.newTripRequested = false
                }
            }
    }

    // MARK: Layout

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            YearDetailView(summary: selectedSummary,
                           rate: profile?.ratePerKm ?? 0.30,
                           onNew: { editorRequest = .new },
                           onSelect: { editorRequest = .edit($0) },
                           onDuplicate: { editorRequest = .duplicate($0) },
                           onDelete: delete)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            YearTilesView(years: years, selection: $selectedYear, axis: .vertical)
                .frame(width: 210)
                .background(Theme.background)
        }
        .background(Theme.background)
        .navigationTitle("Business Miles")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showExport = true
                } label: {
                    Label("Exportieren", systemImage: "square.and.arrow.up")
                }
                .help("Liste als Excel oder PDF exportieren")

                SettingsLink {
                    Label("Einstellungen", systemImage: "gearshape")
                }
                .help("Einstellungen")

                Button {
                    editorRequest = .new
                } label: {
                    Label("Neue Fahrt", systemImage: "plus")
                }
                .help("Neue Fahrt erfassen (⌘N)")
            }
        }
        #else
        NavigationStack {
            VStack(spacing: 0) {
                YearTilesView(years: years, selection: $selectedYear, axis: .horizontal)
                Divider()
                YearDetailView(summary: selectedSummary,
                               rate: profile?.ratePerKm ?? 0.30,
                               onNew: { editorRequest = .new },
                               onSelect: { editorRequest = .edit($0) },
                               onDuplicate: { editorRequest = .duplicate($0) },
                               onDelete: delete)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    LogoLockup(markSize: 24, textSize: 17)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Einstellungen")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showExport = true } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Exportieren")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    editorRequest = .new
                } label: {
                    Label("Neue Fahrt", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        #endif
    }

    private func delete(_ trip: Trip) {
        context.delete(trip)
        try? context.save()
    }
}
