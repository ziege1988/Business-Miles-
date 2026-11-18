import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TripStore
    @State private var draft = AppSettings()
    @State private var loaded = false
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
                    TextField("Satz", value: Binding(
                        get: { draft.ratePerKm },
                        set: { draft.ratePerKm = max(0, $0) }),
                              format: .number.precision(.fractionLength(2)).locale(Fmt.locale))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
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
}
