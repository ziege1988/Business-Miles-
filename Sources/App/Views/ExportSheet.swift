import SwiftUI

/// Export der Jahres- oder Monatsliste als Excel, PDF oder (iPhone) Bild.
struct ExportSheet: View {
    let summary: YearSummary
    let profile: UserProfile?

    @Environment(\.dismiss) private var dismiss
    /// 0 = ganzes Jahr, 1…12 = Monat
    @State private var scope = 0
    @State private var status: String? = nil
    @State private var isError = false
    @State private var isWorking = false

    #if os(iOS)
    @State private var shareURL: URL? = nil
    @State private var exportDocument: ExportDocument? = nil
    @State private var exportFormat: ExportFormat = .pdf
    @State private var showFileExporter = false
    #endif

    private var report: ReportData {
        ReportData.make(summary: summary, month: scope == 0 ? nil : scope, profile: profile)
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
                }

                Section {
                    exportButton(.excel, icon: "tablecells", subtitle: "Bearbeitbare Tabelle (.xlsx) mit Monatssummen")
                    exportButton(.pdf, icon: "doc.richtext", subtitle: "Druckfertige Aufstellung (A4 quer)")
                    #if os(iOS)
                    Button {
                        Task { await saveToPhotos() }
                    } label: {
                        exportLabel(title: "Als Bild in Fotos sichern", icon: "photo.on.rectangle",
                                    subtitle: "Jede Seite als Bild in der Galerie")
                    }
                    #endif
                } header: {
                    Text("Format")
                } footer: {
                    #if os(macOS)
                    if let folder = ExportFolderStore.folderURL() {
                        Text("Wird gespeichert in: \(folder.path)")
                    } else {
                        Text("Tipp: In den Einstellungen kann ein fester Exportordner hinterlegt werden.")
                    }
                    #else
                    Text("Excel und PDF können in „Dateien“ gesichert oder direkt geteilt werden (z. B. per Mail an die Steuerberatung).")
                    #endif
                }

                #if os(iOS)
                if let shareURL {
                    Section("Bereit") {
                        Label(shareURL.lastPathComponent, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accentDeep)
                        ShareLink(item: shareURL) {
                            Label("Teilen …", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            showFileExporter = true
                        } label: {
                            Label("In „Dateien“ sichern …", systemImage: "folder")
                        }
                    }
                }
                #endif

                if isWorking || status != nil {
                    Section {
                        if isWorking {
                            HStack { ProgressView(); Text("Wird erstellt …") }
                        } else if let status {
                            Label(status, systemImage: isError ? "exclamationmark.triangle" : "checkmark.circle")
                                .foregroundStyle(isError ? Theme.warning : Theme.accentDeep)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Exportieren")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .fileExporter(isPresented: $showFileExporter,
                          document: exportDocument,
                          contentType: exportFormat.contentType,
                          defaultFilename: shareURL?.deletingPathExtension().lastPathComponent) { result in
                switch result {
                case .success: setStatus("In „Dateien“ gesichert.")
                case .failure(let error): setStatus(error.localizedDescription, error: true)
                }
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .onChange(of: scope) { _, _ in
                status = nil
                #if os(iOS)
                shareURL = nil
                #endif
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 460)
        #endif
    }

    // MARK: Bausteine

    private func exportButton(_ format: ExportFormat, icon: String, subtitle: String) -> some View {
        Button {
            export(format)
        } label: {
            exportLabel(title: "\(format.label) exportieren", icon: icon, subtitle: subtitle)
        }
        .disabled(report.tripCount == 0 || isWorking)
    }

    private func exportLabel(title: String, icon: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.white)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.accentGradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(subtitle).font(.caption).foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondaryText)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    private func setStatus(_ text: String, error: Bool = false) {
        status = text
        isError = error
    }

    // MARK: Aktionen

    @MainActor
    private func export(_ format: ExportFormat) {
        let r = report
        guard r.tripCount > 0 else { return }
        isWorking = true
        status = nil
        defer { isWorking = false }

        let data = ExportService.data(for: r, format: format)
        let name = ExportService.fileName(for: r, format: format)

        #if os(macOS)
        do {
            if let url = try ExportService.saveToExportFolder(data, fileName: name)
                ?? ExportService.saveWithPanel(data, fileName: name, type: format.contentType) {
                setStatus("Gespeichert: \(url.lastPathComponent)")
                ExportService.reveal(url)
            }
        } catch {
            setStatus("Speichern fehlgeschlagen: \(error.localizedDescription)", error: true)
        }
        #else
        do {
            shareURL = try ExportService.writeTemporary(data, fileName: name)
            exportDocument = ExportDocument(data: data)
            exportFormat = format
            setStatus("\(format.label)-Datei erstellt.")
        } catch {
            setStatus("Erstellen fehlgeschlagen: \(error.localizedDescription)", error: true)
        }
        #endif
    }

    #if os(iOS)
    @MainActor
    private func saveToPhotos() async {
        let r = report
        guard r.tripCount > 0 else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let count = try await ExportService.saveImagesToPhotos(r)
            setStatus(count == 1 ? "1 Bild in Fotos gesichert." : "\(count) Bilder in Fotos gesichert.")
        } catch {
            setStatus(error.localizedDescription, error: true)
        }
    }
    #endif
}
