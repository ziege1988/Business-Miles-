import SwiftUI

/// Einstellungen → „Version & Updates“
struct UpdateSection: View {
    @ObservedObject var updates = UpdateService.shared

    var body: some View {
        Section {
            LabeledContent("Installiert") {
                Text("Version \(updates.installedVersion) · Build \(String(updates.installedBuild))")
                    .foregroundStyle(Theme.secondaryText)
            }

            switch updates.state {
            case .idle:
                checkButton
            case .checking:
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Suche nach Updates …") }
            case .upToDate:
                Label("Du hast die neueste Version.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accentDeep)
                checkButton
            case .available(let release):
                VStack(alignment: .leading, spacing: 6) {
                    Label("Neue Version verfügbar: Build \(String(release.build))", systemImage: "arrow.down.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.accentDeep)
                    if let date = release.publishedAt {
                        Text("Veröffentlicht am \(Fmt.date(date))")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    if !release.notes.isEmpty {
                        Text(release.notes)
                            .font(.callout)
                            .foregroundStyle(Theme.ink)
                            .textSelection(.enabled)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accentSoft.opacity(0.6)))
                    }
                    HStack {
                        Button("Update installieren") { Task { await updates.install(release) } }
                            .buttonStyle(.borderedProminent)
                        Link("Auf GitHub ansehen", destination: release.pageURL)
                    }
                }
            case .downloading:
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Update wird geladen …") }
            case .installing:
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Update wird installiert – die App startet gleich neu …") }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Theme.warning)
                checkButton
            }

            if let last = updates.lastCheck {
                Text("Zuletzt geprüft: \(Fmt.date(last)), \(last.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        } header: {
            Text("Version & Updates")
        } footer: {
            Text("Updates werden von GitHub geladen. Deine Fahrten bleiben dabei erhalten – sie liegen in OneDrive.")
        }
    }

    private var checkButton: some View {
        Button("Nach Updates suchen") { Task { await updates.check() } }
    }
}

/// Hinweisleiste im Hauptfenster, wenn ein Update bereitliegt.
struct UpdateBanner: View {
    @ObservedObject var updates = UpdateService.shared

    var body: some View {
        if let release = updates.availableRelease {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Neue Version verfügbar (Build \(String(release.build)))")
                        .font(.headline)
                    Text(release.notes.split(separator: "\n").first.map(String.init) ?? "Verbesserungen und Fehlerbehebungen")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Button("Jetzt aktualisieren") { Task { await updates.install(release) } }
                    .buttonStyle(.borderedProminent)
            }
            .padding(14)
            .background(Theme.accentSoft)
            .overlay(alignment: .bottom) { Divider() }
        }
    }
}
