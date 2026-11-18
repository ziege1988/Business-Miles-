import SwiftUI
import SwiftData

/// Neue Fahrt anlegen bzw. bestehende bearbeiten.
struct TripEditorView: View {
    let request: EditorRequest
    let profile: UserProfile?
    let allTrips: [Trip]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var customer: String
    @State private var purpose: String
    @State private var note: String
    @State private var destination: AddressValue
    @State private var startUsesHome: Bool
    @State private var otherStart: AddressValue
    @State private var returnEnabled: Bool
    @State private var returnUsesHome: Bool
    @State private var otherReturn: AddressValue
    @State private var outboundKm: Double
    @State private var returnKm: Double

    @State private var initialRouteKey: String? = nil
    @State private var isCalculating = false
    @State private var routeError: String? = nil
    @State private var confirmDelete = false
    @State private var showSettings = false

    init(request: EditorRequest, profile: UserProfile?, allTrips: [Trip]) {
        self.request = request
        self.profile = profile
        self.allTrips = allTrips

        let source: Trip?
        switch request {
        case .new: source = nil
        case .edit(let t), .duplicate(let t): source = t
        }
        let isEdit: Bool
        switch request {
        case .edit: isEdit = true
        case .new, .duplicate: isEdit = false
        }

        _date = State(initialValue: isEdit ? (source?.date ?? .now) : .now)
        _customer = State(initialValue: source?.customer ?? "")
        _purpose = State(initialValue: source?.purpose ?? "")
        _note = State(initialValue: isEdit ? (source?.note ?? "") : "")
        _destination = State(initialValue: source?.destination ?? AddressValue())
        _startUsesHome = State(initialValue: source?.startUsesHome ?? true)
        _otherStart = State(initialValue: (source?.startUsesHome ?? true) ? AddressValue() : (source?.start ?? AddressValue()))
        _returnEnabled = State(initialValue: source?.returnEnabled ?? true)
        _returnUsesHome = State(initialValue: source?.returnUsesHome ?? true)
        _otherReturn = State(initialValue: (source?.returnUsesHome ?? true) ? AddressValue() : (source?.returnTarget ?? AddressValue()))
        _outboundKm = State(initialValue: source?.outboundKm ?? 0)
        _returnKm = State(initialValue: source?.returnKm ?? 0)

        if let source {
            let home = profile?.homeAddress ?? AddressValue()
            let start = source.startUsesHome ? home : source.start
            let ret = source.returnUsesHome ? home : source.returnTarget
            _initialRouteKey = State(initialValue: Self.routeKey(start: start, destination: source.destination,
                                                                 returnEnabled: source.returnEnabled, returnTo: ret))
        }
    }

    // MARK: Abgeleitete Werte

    private var isEditing: Bool {
        switch request {
        case .edit: return true
        case .new, .duplicate: return false
        }
    }
    private var home: AddressValue { profile?.homeAddress ?? AddressValue() }
    private var effectiveStart: AddressValue { startUsesHome ? home : otherStart }
    private var effectiveReturn: AddressValue { returnUsesHome ? home : otherReturn }
    private var totalKm: Double { outboundKm + (returnEnabled ? returnKm : 0) }
    private var needsHome: Bool { startUsesHome || (returnEnabled && returnUsesHome) }
    private var canSave: Bool { destination.isUsable }

    private var currentRouteKey: String {
        Self.routeKey(start: effectiveStart, destination: destination,
                      returnEnabled: returnEnabled, returnTo: effectiveReturn)
    }

    private static func routeKey(start: AddressValue, destination: AddressValue,
                                 returnEnabled: Bool, returnTo: AddressValue) -> String {
        [start.singleLine, destination.singleLine, returnEnabled ? returnTo.singleLine : "-"]
            .joined(separator: " | ")
    }

    /// Zuletzt angefahrene Ziele für die Schnellauswahl.
    private var recentDestinations: [Trip] {
        var seen = Set<String>()
        var result: [Trip] = []
        for t in allTrips {
            let key = t.destination.singleLine.lowercased()
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(t)
            if result.count == 8 { break }
        }
        return result
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Datum") {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Fmt.locale)
                }

                Section("Kunde & Anlass") {
                    TextField("Kunde / Geschäftspartner", text: $customer)
                    TextField("Anlass (z. B. Fotoshooting, Besprechung)", text: $purpose)
                }

                Section {
                    if !isEditing, destination.isEmpty, !recentDestinations.isEmpty {
                        recentDestinationChips
                    }
                    AddressInputView(address: $destination)
                } header: {
                    Text("Zieladresse")
                } footer: {
                    Text("PLZ eingeben – der Ort wird ergänzt. Beim Tippen der Straße erscheinen Vorschläge.")
                }

                Section("Start") {
                    Picker("Start", selection: $startUsesHome) {
                        Text("Startadresse").tag(true)
                        Text("Andere Adresse").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if startUsesHome {
                        homeAddressRow
                    } else {
                        AddressInputView(address: $otherStart)
                    }
                }

                Section("Rückfahrt") {
                    Toggle("Hin- und Rückfahrt", isOn: $returnEnabled)
                    if returnEnabled {
                        Picker("Zurück nach", selection: $returnUsesHome) {
                            Text("Startadresse").tag(true)
                            Text("Andere Adresse").tag(false)
                        }
                        .pickerStyle(.segmented)
                        if !returnUsesHome {
                            AddressInputView(address: $otherReturn)
                        }
                    }
                }

                distanceSection

                Section("Notiz (optional)") {
                    TextField("Notiz", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if isEditing {
                    Section {
                        Button("Fahrt löschen", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Fahrt bearbeiten" : "Neue Fahrt")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(!canSave)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .task(id: currentRouteKey) {
                guard currentRouteKey != initialRouteKey else { return }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                await recalculate()
            }
            .confirmationDialog("Fahrt löschen?", isPresented: $confirmDelete) {
                Button("Löschen", role: .destructive) { deleteTrip() }
            }
            #if os(iOS)
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 580, idealWidth: 620, minHeight: 720, idealHeight: 820)
        #endif
    }

    // MARK: Abschnitte

    @ViewBuilder
    private var homeAddressRow: some View {
        if home.isUsable {
            Label(home.singleLine, systemImage: "house")
                .foregroundStyle(Theme.secondaryText)
        } else {
            missingHomeHint
        }
    }

    @ViewBuilder
    private var missingHomeHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Noch keine Startadresse hinterlegt", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warning)
            #if os(macOS)
            SettingsLink { Text("In den Einstellungen hinterlegen …") }
            #else
            Button("In den Einstellungen hinterlegen …") { showSettings = true }
            #endif
        }
    }

    private var recentDestinationChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Letzte Ziele")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentDestinations) { trip in
                        Button {
                            destination = trip.destination
                            if customer.isEmpty { customer = trip.customer }
                            if purpose.isEmpty { purpose = trip.purpose }
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(trip.title).font(.caption.weight(.semibold)).lineLimit(1)
                                Text(trip.destCity).font(.caption2).foregroundStyle(Theme.secondaryText).lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.accentSoft))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.ink)
                    }
                }
            }
        }
    }

    private var distanceSection: some View {
        Section {
            kmRow("Hinfahrt", value: $outboundKm)
            if returnEnabled {
                kmRow("Rückfahrt", value: $returnKm)
            }
            HStack {
                Text("Gesamt").font(.headline)
                Spacer()
                Text(Fmt.km(totalKm))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.accentDeep)
            }
            if let rate = profile?.ratePerKm {
                HStack {
                    Text("Pauschale (\(Fmt.rate(rate))/km)")
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text(Fmt.euro(totalKm * rate))
                        .foregroundStyle(Theme.secondaryText)
                        .monospacedDigit()
                }
                .font(.subheadline)
            }

            HStack(spacing: 8) {
                if isCalculating {
                    ProgressView().controlSize(.small)
                    Text("Route wird berechnet …")
                        .foregroundStyle(Theme.secondaryText)
                } else {
                    Button {
                        Task { await recalculate() }
                    } label: {
                        Label("Kilometer neu berechnen", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!destination.isUsable)
                }
            }
            .font(.subheadline)

            if let routeError {
                Label(routeError, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
            }
            if needsHome && !home.isUsable {
                missingHomeHint
            }
        } header: {
            Text("Strecke")
        } footer: {
            Text("Die Kilometer werden per Apple Maps (Auto, empfohlene Route) berechnet und können überschrieben werden.")
        }
    }

    private func kmRow(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value,
                      format: .number.precision(.fractionLength(0...1)).locale(Fmt.locale))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            Text("km").foregroundStyle(Theme.secondaryText)
        }
    }

    // MARK: Aktionen

    @MainActor
    private func recalculate() async {
        let start = effectiveStart
        let dest = destination
        let ret = effectiveReturn
        let withReturn = returnEnabled

        guard dest.isUsable else { return }
        guard start.isUsable else {
            routeError = "Bitte eine Startadresse angeben."
            return
        }
        guard !withReturn || ret.isUsable else {
            routeError = "Bitte eine Adresse für die Rückfahrt angeben."
            return
        }

        isCalculating = true
        routeError = nil
        defer { isCalculating = false }

        do {
            let outbound = try await RouteService.drivingDistanceKm(from: start, to: dest)
            var back: Double = 0
            if withReturn {
                back = try await RouteService.drivingDistanceKm(from: dest, to: ret)
            }
            guard !Task.isCancelled else { return }
            outboundKm = outbound
            if withReturn { returnKm = back }
        } catch is CancellationError {
            // Neue Eingabe – Berechnung wird erneut gestartet.
        } catch {
            routeError = error.localizedDescription
        }
    }

    @MainActor
    private func save() {
        let trip: Trip
        if case .edit(let existing) = request {
            trip = existing
        } else {
            trip = Trip()
            context.insert(trip)
        }
        trip.date = date
        trip.customer = customer.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.purpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.destination = destination
        trip.startUsesHome = startUsesHome
        trip.start = effectiveStart
        trip.returnEnabled = returnEnabled
        trip.returnUsesHome = returnUsesHome
        trip.returnTarget = returnEnabled ? effectiveReturn : AddressValue()
        trip.outboundKm = max(0, outboundKm)
        trip.returnKm = returnEnabled ? max(0, returnKm) : 0
        trip.updatedAt = .now
        try? context.save()
        dismiss()
    }

    private func deleteTrip() {
        if case .edit(let existing) = request {
            context.delete(existing)
            try? context.save()
        }
        dismiss()
    }
}
