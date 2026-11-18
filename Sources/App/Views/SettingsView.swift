import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = ProfileStore.current(profiles) {
                SettingsForm(profile: profile)
            } else {
                ProgressView()
                    .onAppear { ProfileStore.ensure(in: context, profiles: profiles) }
            }
        }
    }
}

private struct SettingsForm: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    #if os(macOS)
    @State private var exportFolderPath: String? = ExportFolderStore.folderURL()?.path
    #endif

    private var homeBinding: Binding<AddressValue> {
        Binding(
            get: { profile.homeAddress },
            set: { profile.homeAddress = $0 }
        )
    }

    var body: some View {
        Form {
            Section {
                AddressInputView(address: homeBinding)
            } header: {
                Text("Startadresse")
            } footer: {
                Text("Wird bei jeder neuen Fahrt als Start und Ziel der Rückfahrt vorausgewählt und erscheint als Anschrift im Export.")
            }

            Section {
                TextField("Name", text: $profile.fullName)
                TextField("Firma (optional)", text: $profile.company)
                TextField("Steuernummer", text: $profile.taxNumber)
            } header: {
                Text("Angaben für die Steuer")
            } footer: {
                Text("Diese Angaben stehen im Kopf der exportierten Liste (Excel, PDF, Bild).")
            }

            Section {
                TextField("Fahrzeug (z. B. VW Golf)", text: $profile.vehicleName)
                TextField("Kennzeichen", text: $profile.licensePlate)
                Picker("Fahrzeugart", selection: Binding(
                    get: { profile.vehicleType },
                    set: { newValue in
                        profile.vehicleType = newValue
                        if let rate = newValue.defaultRate { profile.ratePerKm = rate }
                    }
                )) {
                    ForEach(VehicleType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                HStack {
                    Text("Kilometersatz")
                    Spacer()
                    TextField("Satz", value: $profile.ratePerKm,
                              format: .number.precision(.fractionLength(2)).locale(Fmt.locale))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .disabled(profile.vehicleType != .custom)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Text("€ / km").foregroundStyle(Theme.secondaryText)
                }
            } header: {
                Text("Fahrzeug & Kilometerpauschale")
            } footer: {
                Text("Für betrieblich veranlasste Fahrten mit einem privaten Fahrzeug können pauschal 0,30 € (Pkw) bzw. 0,20 € (Motorrad/Motorroller) je gefahrenem Kilometer angesetzt werden. Bitte im Zweifel mit der Steuerberatung abstimmen.")
            }

            #if os(macOS)
            Section {
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(Theme.accent)
                    Text(exportFolderPath ?? "Kein Ordner gewählt – beim Export wird nachgefragt")
                        .foregroundStyle(exportFolderPath == nil ? Theme.secondaryText : Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                HStack {
                    Button("Ordner wählen …") {
                        if let url = ExportFolderStore.chooseFolder() {
                            exportFolderPath = url.path
                        }
                    }
                    if exportFolderPath != nil {
                        Button("Zurücksetzen") {
                            ExportFolderStore.clear()
                            exportFolderPath = nil
                        }
                    }
                }
            } header: {
                Text("Export")
            } footer: {
                Text("Excel- und PDF-Dateien werden direkt in diesem Ordner gespeichert.")
            }
            #endif

            Section("Synchronisation") {
                Label(Persistence.syncMode.rawValue,
                      systemImage: Persistence.syncMode == .iCloud ? "icloud" : "icloud.slash")
                    .foregroundStyle(Persistence.syncMode == .iCloud ? Theme.accentDeep : Theme.warning)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Einstellungen")
        .onChange(of: profile.homeAddress) { _, _ in try? context.save() }
        .onDisappear { try? context.save() }
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") {
                    try? context.save()
                    dismiss()
                }
            }
        }
        #endif
    }
}
