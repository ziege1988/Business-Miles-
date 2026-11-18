import SwiftUI

/// Neue Fahrt anlegen bzw. bestehende bearbeiten.
struct TripEditorView: View {
    let request: EditorRequest

    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss

    @State private var trip: Trip
    @State private var otherStart: AddressValue
    @State private var otherReturn: AddressValue

    @State private var initialRouteKey: String? = nil
    @State private var isCalculating = false
    @State private var routeError: String? = nil
    @State private var confirmDelete = false

    init(request: EditorRequest) {
        self.request = request
        var t: Trip
        switch request {
        case .new:
            t = Trip()
        case .edit(let existing):
            t = existing
        case .duplicate(let existing):
            t = existing
            t.id = UUID().uuidString
            t.day = DayString.string(Date())
            t.note = ""
            t.createdAt = ISOTime.now
            t.deleted = false
        }
        _trip = State(initialValue: t)
        _otherStart = State(initialValue: t.startUsesHome ? AddressValue() : t.start)
        _otherReturn = State(initialValue: t.returnUsesHome ? AddressValue() : t.returnTarget)
        if case .new = request {} else {
            // Gespeicherte Route nicht beim Öffnen neu berechnen
            _initialRouteKey = State(initialValue: Self.routeKey(
                start: t.start, destination: t.destination,
                returnEnabled: t.returnEnabled, returnTo: t.returnTarget))
        }
    }

    // MARK: Abgeleitete Werte

    private var isEditing: Bool {
        switch request {
        case .edit: return true
        case .new, .duplicate: return false
        }
    }

    private var home: AddressValue { store.settings.home }
    private var effectiveStart: AddressValue { trip.startUsesHome ? home : otherStart }
    private var effectiveReturn: AddressValue { trip.returnUsesHome ? home : otherReturn }
    private var needsHome: Bool { trip.startUsesHome || (trip.returnEnabled && trip.returnUsesHome) }

    private var currentRouteKey: String {
        Self.routeKey(start: effectiveStart, destination: trip.destination,
                      returnEnabled: trip.returnEnabled, returnTo: effectiveReturn)
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
        for t in store.trips.sorted(by: { $0.day > $1.day }) {
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
                    DatePicker("Datum", selection: $trip.date, displayedComponents: .date)
                        .environment(\.locale, Fmt.locale)
                }

                Section("Kunde & Anlass") {
                    TextField("Kunde / Geschäftspartner", text: $trip.customer)
                    TextField("Anlass (z. B. Fotoshooting, Besprechung)", text: $trip.purpose)
                }

                Section {
                    if !isEditing, trip.destination.isEmpty, !recentDestinations.isEmpty {
                        recentDestinationChips
                    }
                    AddressInputView(address: $trip.destination)
                } header: {
                    Text("Zieladresse")
                } footer: {
                    Text("PLZ eingeben – der Ort wird ergänzt. Beim Tippen der Straße erscheinen Vorschläge.")
                }

                Section("Start") {
                    Picker("Start", selection: $trip.startUsesHome) {
                        Text("Startadresse").tag(true)
                        Text("Andere Adresse").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if trip.startUsesHome {
                        homeAddressRow
                    } else {
                        AddressInputView(address: $otherStart)
                    }
                }

                Section("Rückfahrt") {
                    Toggle("Hin- und Rückfahrt", isOn: $trip.returnEnabled)
                    if trip.returnEnabled {
                        Picker("Zurück nach", selection: $trip.returnUsesHome) {
                            Text("Startadresse").tag(true)
                            Text("Andere Adresse").tag(false)
                        }
                        .pickerStyle(.segmented)
                        if !trip.returnUsesHome {
                            AddressInputView(address: $otherReturn)
                        }
                    }
                }

                distanceSection

                Section("Notiz (optional)") {
                    TextField("Notiz", text: $trip.note, axis: .vertical)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(!trip.destination.isUsable)
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
                Button("Löschen", role: .destructive) {
                    store.delete(id: trip.id)
                    dismiss()
                }
            }
        }
        .frame(minWidth: 580, idealWidth: 620, minHeight: 720, idealHeight: 820)
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

    private var missingHomeHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Noch keine Startadresse hinterlegt", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warning)
            SettingsLink { Text("In den Einstellungen hinterlegen …") }
        }
    }

    private var recentDestinationChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Letzte Ziele")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentDestinations) { recent in
                        Button {
                            trip.destination = recent.destination
                            if trip.customer.isEmpty { trip.customer = recent.customer }
                            if trip.purpose.isEmpty { trip.purpose = recent.purpose }
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(recent.title).font(.caption.weight(.semibold)).lineLimit(1)
                                Text(recent.destination.city).font(.caption2)
                                    .foregroundStyle(Theme.secondaryText).lineLimit(1)
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
            kmRow("Hinfahrt", value: $trip.outboundKm)
            if trip.returnEnabled {
                kmRow("Rückfahrt", value: $trip.returnKm)
            }
            HStack {
                Text("Gesamt").font(.headline)
                Spacer()
                Text(Fmt.km(trip.totalKm))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.accentDeep)
            }
            HStack {
                Text("Pauschale (\(Fmt.rate(store.settings.ratePerKm))/km)")
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(Fmt.euro(trip.amount(rate: store.settings.ratePerKm)))
                    .foregroundStyle(Theme.secondaryText)
                    .monospacedDigit()
            }
            .font(.subheadline)

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
                    .disabled(!trip.destination.isUsable)
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
            Text("Die Kilometer werden per Apple Karten (Auto, empfohlene Route) berechnet und können überschrieben werden.")
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
            Text("km").foregroundStyle(Theme.secondaryText)
        }
    }

    // MARK: Aktionen

    @MainActor
    private func recalculate() async {
        let start = effectiveStart
        let dest = trip.destination
        let ret = effectiveReturn
        let withReturn = trip.returnEnabled

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
            trip.outboundKm = outbound
            if withReturn { trip.returnKm = back }
        } catch is CancellationError {
            // Neue Eingabe – Berechnung startet erneut.
        } catch {
            routeError = error.localizedDescription
        }
    }

    @MainActor
    private func save() {
        var t = trip
        t.customer = t.customer.trimmingCharacters(in: .whitespacesAndNewlines)
        t.purpose = t.purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        t.note = t.note.trimmingCharacters(in: .whitespacesAndNewlines)
        t.start = effectiveStart
        t.returnTarget = t.returnEnabled ? effectiveReturn : AddressValue()
        t.outboundKm = max(0, t.outboundKm)
        t.returnKm = t.returnEnabled ? max(0, t.returnKm) : 0
        t.kmPending = t.totalKm <= 0
        t.source = "mac"
        store.upsert(t)
        dismiss()
    }
}
