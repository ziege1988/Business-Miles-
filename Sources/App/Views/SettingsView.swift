import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TripStore
    @State private var draft = AppSettings()
    @State private var loaded = false
    @State private var applyYear = Fmt.calendar.component(.year, from: .now)
    @State private var confirmApply = false
    @State private var applyResult: String? = nil
    @State private var exportFolderPath: String? = ExportFolderStore.folderURL()?.path

    var body: some View {
        Form {
            Section {
                AddressInputView(address: $draft.home)
            } header: {
                Text("Startadresse")
            } footer: {
                Text("Wird bei jeder neuen Fahrt als Start und Ziel der Rückfahrt vorausgewählt und erscheint als Anschrift im Export. Gilt auch auf dem iPhone.")
            }

            Section {
                TextField("Name", text: $draft.fullName)
                TextField("Firma (optional)", text: $draft.company)
                TextField("Steuernummer", text: $draft.taxNumber)
            } header: {
                Text("Angaben für die Steuer")
            } footer: {
                Text("Diese Angaben stehen im Kopf der exportierten Liste (Excel, PDF, Bild).")
            }

            Section {
                TextField("Fahrzeug (z. B. VW Golf)", text: $draft.vehicleName)
                TextField("Kennzeichen", text: $draft.licensePlate)
                Picker("Fahrzeugart", selection: $draft.vehicleType) {
                    ForEach(VehicleType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                HStack {
                    Text("Kilometersatz")
                    Spacer()
                    DecimalField(title: "Satz", value: $draft.ratePerKm, fractionDigits: 2, allowsThousands: false)
                        .labelsHidden()
                        .frame(width: 80)
                    Text("€ / km").foregroundStyle(Theme.secondaryText)
                }
            } header: {
                Text("Fahrzeug & Kilometerpauschale")
            } footer: {
                Text("Dein Kilometersatz wird bei jeder neuen Fahrt verwendet – unabhängig von der Fahrzeugart. Bereits erfasste Fahrten behalten ihren Satz (in der jeweiligen Fahrt änderbar). Zum Vergleich: Die gesetzliche Pauschale beträgt 0,30 € (Pkw) bzw. 0,20 € (Motorrad).")
            }

            Section {
                HStack {
                    Image(systemName: "cloud")
                        .foregroundStyle(Theme.accent)
                    Text(store.folderURL?.path ?? "Noch kein Ordner gewählt")
                        .foregroundStyle(store.folderURL == nil ? Theme.secondaryText : Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                    Button(store.folderURL == nil ? "Ordner wählen …" : "Ändern …") { store.chooseFolder() }
                }
                if store.folderURL != nil && !store.folderLooksRight {
                    Label("Der gewählte Ordner heißt nicht „Business-Miles“. Das iPhone liest aus OneDrive › Business-Miles.",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                }
                SyncBadge()
            } header: {
                Text("Datenablage (OneDrive)")
            } footer: {
                Text("Fahrten und Einstellungen liegen in „Business-Miles/business-miles.json“. Tipp: Im Finder per Rechtsklick auf den Ordner „Immer auf diesem Gerät behalten“ wählen.")
            }

            applyRateSection

            DesktopWidgetSection()

            UpdateSection()

            Section {
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(Theme.accent)
                    Text(exportFolderPath ?? "Kein Ordner gewählt – beim Export wird nachgefragt")
                        .foregroundStyle(exportFolderPath == nil ? Theme.secondaryText : Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                }
                HStack {
                    Button("Ordner wählen …") {
                        if let url = ExportFolderStore.chooseFolder() { exportFolderPath = url.path }
                    }
                    if exportFolderPath != nil {
                        Button("Zurücksetzen") {
                            ExportFolderStore.clear()
                            exportFolderPath = nil
                        }
                    }
                }
            } header: {
                Text("Exportordner")
            } footer: {
                Text("Excel- und PDF-Dateien werden direkt in diesem Ordner gespeichert.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Einstellungen")
        .onAppear {
            draft = store.settings
            loaded = true
        }
        // Änderungen aus der Datei (z. B. vom iPhone) übernehmen, solange hier nichts abweicht
        .onChange(of: store.settings) { _, newValue in
            if !newValue.sameContent(as: draft) { draft = newValue }
        }
        .onChange(of: draft) { _, newValue in
            guard loaded else { return }
            store.updateSettings(newValue)
        }
    }

    // MARK: Kilometersatz auf ein Jahr übernehmen

    private var yearsWithTrips: [YearSummary] {
        TripStatistics.years(from: store.trips).filter { $0.tripCount > 0 }
    }

    private var applyRateSection: some View {
        Section {
            if yearsWithTrips.isEmpty {
                Text("Noch keine Fahrten vorhanden.").foregroundStyle(Theme.secondaryText)
            } else {
                Picker("Jahr", selection: $applyYear) {
                    ForEach(yearsWithTrips) { y in
                        Text("\(String(y.year)) (\(Fmt.tripCount(y.tripCount)))").tag(y.year)
                    }
                }
                Button("Satz \(Fmt.rate(draft.ratePerKm)) auf alle Fahrten \(String(applyYear)) übernehmen") {
                    confirmApply = true
                }
                .confirmationDialog("Kilometersatz übernehmen?", isPresented: $confirmApply) {
                    Button("\(Fmt.rate(draft.ratePerKm)) je km auf alle Fahrten \(String(applyYear)) übernehmen") {
                        store.updateSettings(draft)
                        let n = store.applyRate(draft.ratePerKm, toYear: applyYear)
                        applyResult = n > 0
                            ? "\(Fmt.tripCount(n)) \(String(applyYear)) aktualisiert."
                            : "Alle Fahrten \(String(applyYear)) hatten bereits diesen Satz."
                    }
                } message: {
                    Text("Die Beträge aller Fahrten dieses Jahres werden mit dem neuen Satz berechnet.")
                }
                if let applyResult {
                    Label(applyResult, systemImage: "checkmark.circle")
                        .foregroundStyle(Theme.accentDeep)
                }
            }
        } header: {
            Text("Kilometersatz auf Fahrten übernehmen")
        } footer: {
            Text("Korrigiert z. B. einen falsch eingetragenen Satz. Verwendet wird der oben eingetragene Kilometersatz.")
        }
        .onAppear {
            if let latest = yearsWithTrips.first, !yearsWithTrips.contains(where: { $0.year == applyYear }) {
                applyYear = latest.year
            }
        }
    }
}
