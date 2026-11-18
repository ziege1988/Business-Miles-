import SwiftUI

/// Export der Jahres- oder Monatsliste als Excel oder PDF.
struct ExportSheet: View {
    let summary: YearSummary
    let settings: AppSettings

    @Environment(\.dismiss) private var dismiss
    /// 0 = ganzes Jahr, 1…12 = Monat
    @State private var scope = 0
    @State private var status: String? = nil
    @State private var isError = false

    private var report: ReportData {
        ReportData.make(summary: summary, month: scope == 0 ? nil : scope, settings: settings)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Zeitraum") {
                    Picker("Zeitraum", selection: $scope) {
                        Text("Gesamtes Jahr \(String(summary.year))").tag(0)
                        ForEach(summary.months.filter { !$0.trips.isEmpty }) { m in
                            Text("\(m.name) \(String(summary.year))").tag(m.month)
                        }
                    }
                    let r = report
                    LabeledContent("Umfang") {
                        Text("\(Fmt.tripCount(r.tripCount)) · \(Fmt.km(r.totalKm)) · \(Fmt.euro(r.amount))")
                            .foregroundStyle(Theme.secondaryText)
                    }
                    if summary.trips.contains(where: \.kmPending) {
                        Label("Einige Fahrten warten noch auf die km-Berechnung.", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(Theme.warning)
                    }
                }

                Section {
                    exportButton(.excel, icon: "tablecells", subtitle: "Bearbeitbare Tabelle (.xlsx) mit Monatssummen")
                    exportButton(.pdf, icon: "doc.richtext", subtitle: "Druckfertige Aufstellung (A4 quer)")
                } header: {
                    Text("Format")
                } footer: {
                    if let folder = ExportFolderStore.folderURL() {
                        Text("Wird gespeichert in: \(folder.path)")
                    } else {
                        Text("Tipp: In den Einstellungen kann ein fester Exportordner hinterlegt werden.")
                    }
                }

                if let status {
                    Section {
                        Label(status, systemImage: isError ? "exclamationmark.triangle" : "checkmark.circle")
                            .foregroundStyle(isError ? Theme.warning : Theme.accentDeep)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Exportieren")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .onChange(of: scope) { _, _ in status = nil }
        }
        .frame(minWidth: 480, minHeight: 440)
    }

    private func exportButton(_ format: ExportFormat, icon: String, subtitle: String) -> some View {
        Button {
            export(format)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.accentGradient))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(format.label) exportieren").font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(subtitle).font(.caption).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .disabled(report.tripCount == 0)
    }

    @MainActor
    private func export(_ format: ExportFormat) {
        let r = report
        guard r.tripCount > 0 else { return }
        let data = ExportService.data(for: r, format: format)
        let name = ExportService.fileName(for: r, format: format)
        do {
            if let url = try ExportService.saveToExportFolder(data, fileName: name)
                ?? ExportService.saveWithPanel(data, fileName: name, type: format.contentType) {
                status = "Gespeichert: \(url.lastPathComponent)"
                isError = false
                ExportService.reveal(url)
            }
        } catch {
            status = "Speichern fehlgeschlagen: \(error.localizedDescription)"
            isError = true
        }
    }
}
