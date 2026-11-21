import SwiftUI
import AppKit

/// Erzeugt Vorschaubilder der App mit Beispieldaten (für Doku und Kontrolle).
/// Aufruf: `"Business Miles.app/Contents/MacOS/Business Miles" --screenshots <Ordner>`
/// Wird nur vom GitHub-Workflow genutzt – im normalen Betrieb ohne Wirkung.
enum ScreenshotMode {
    static var outputDirectory: URL? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--screenshots"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1], isDirectory: true)
    }

    static var isActive: Bool { outputDirectory != nil }

    // MARK: Ablauf

    @MainActor
    static func run(store: TripStore, router: AppRouter) async {
        guard let dir = outputDirectory else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        try? await Task.sleep(for: .milliseconds(700))
        captureMainWindow(to: dir, name: "mac-0-start")

        try? await Task.sleep(for: .seconds(2.5))
        captureMainWindow(to: dir, name: "mac-1-uebersicht")

        // Einstellungen (eigenes Fenster) – vor dem Editor, damit kein Sheet offen ist
        let before = Set(NSApp.windows.map { ObjectIdentifier($0) })
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        try? await Task.sleep(for: .seconds(2))
        if let settings = NSApp.windows.first(where: { $0.isVisible && !before.contains(ObjectIdentifier($0)) })
            ?? NSApp.windows.first(where: { $0.isVisible && $0.title.contains("Einstellungen") }) {
            capture(settings, to: dir.appendingPathComponent("mac-3-einstellungen.png"))
            settings.close()
        }
        try? await Task.sleep(for: .seconds(1))

        // Neue Fahrt (Sheet am Hauptfenster)
        mainWindow?.makeKeyAndOrderFront(nil)
        router.newTripRequested = true
        try? await Task.sleep(for: .seconds(2))
        if let sheet = mainWindow?.attachedSheet {
            capture(sheet, to: dir.appendingPathComponent("mac-2-neue-fahrt.png"))
        }

        // Widget (klein + mittel)
        let snapshot = WidgetSync.snapshot(for: store.trips)
        renderWidget(snapshot, family: .small, size: CGSize(width: 170, height: 170), to: dir.appendingPathComponent("widget-klein.png"))
        renderWidget(snapshot, family: .medium, size: CGSize(width: 364, height: 170), to: dir.appendingPathComponent("widget-mittel.png"))

        // Exporte
        let years = TripStatistics.years(from: store.trips)
        if let year = years.first(where: { $0.year == 2026 }) {
            let report = ReportData.make(summary: year, month: nil, settings: store.settings)
            try? ExportService.makePDF(report).write(to: dir.appendingPathComponent("mac-Fahrtenaufstellung_2026.pdf"))
            var portrait = report
            portrait.portrait = true
            try? ExportService.makePDF(portrait).write(to: dir.appendingPathComponent("mac-Fahrtenaufstellung_2026_hoch.pdf"))
            try? XLSXExporter.make(report).write(to: dir.appendingPathComponent("mac-Fahrtenaufstellung_2026.xlsx"))
        }

        try? await Task.sleep(for: .milliseconds(500))
        NSApp.terminate(nil)
    }

    @MainActor
    private static var mainWindow: NSWindow? {
        NSApp.windows.first { $0.isVisible && $0.title == "Business Miles" } ?? NSApp.mainWindow ?? NSApp.windows.first
    }

    @MainActor
    private static func captureMainWindow(to dir: URL, name: String) {
        guard let window = mainWindow else { return }
        capture(window, to: dir.appendingPathComponent("\(name).png"))
    }

    /// Zeichnet ein eigenes Fenster in eine PNG-Datei (keine Bildschirmaufnahme-Berechtigung nötig).
    @MainActor
    private static func capture(_ window: NSWindow, to url: URL) {
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    @MainActor
    private static func renderWidget(_ snapshot: WidgetSnapshot, family: TileSize, size: CGSize, to url: URL) {
        let content = MilesWidgetContent(entry: MilesEntry(date: .now, snapshot: snapshot), family: family)
            .padding(16)
            .frame(width: size.width, height: size.height)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white))
            .padding(24)
            .background(Color(red: 0.86, green: 0.89, blue: 0.93))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return }
        let rep = NSBitmapImageRep(cgImage: cg)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    // MARK: Beispieldaten (fiktiv)

    static func sampleData() -> DataFile {
        let home = AddressValue(street: "Musterstraße 1", postalCode: "80331", city: "München")
        func trip(_ day: String, _ customer: String, _ purpose: String,
                  _ street: String, _ plz: String, _ city: String,
                  _ out: Double, _ back: Double, times: (String, String)? = nil) -> Trip {
            var t = Trip()
            t.id = "demo-\(day)-\(customer)"
            t.day = day
            t.customer = customer
            t.purpose = purpose
            t.destination = AddressValue(street: street, postalCode: plz, city: city)
            t.start = home
            t.returnTarget = home
            t.outboundKm = out
            t.returnKm = back
            t.ratePerKm = 0.42
            if let times { t.departureTime = times.0; t.returnTime = times.1 }
            return t
        }
        var doc = DataFile()
        doc.settings.fullName = "Max Mustermann"
        doc.settings.company = "Mustermann Fotografie"
        doc.settings.taxNumber = "143/123/45678"
        doc.settings.home = home
        doc.settings.vehicleName = "VW Golf"
        doc.settings.licensePlate = "M-MM 1234"
        doc.settings.ratePerKm = 0.42
        doc.trips = [
            trip("2026-11-14", "Familie Berger", "Hochzeitsreportage", "Schlossallee 5", "83209", "Prien am Chiemsee", 87.4, 88.1, times: ("09:15", "22:40")),
            trip("2026-11-06", "Autohaus Kramer", "Produktfotos Neuwagen", "Industriestraße 12", "85221", "Dachau", 21.3, 20.8),
            trip("2026-11-03", "Kita Sonnenschein", "Gruppenfotos", "Lindenweg 3", "82110", "Germering", 18.9, 19.2),
            trip("2026-10-24", "Hotel Seeblick", "Imagefotos", "Seestraße 40", "82319", "Starnberg", 27.6, 27.6, times: ("07:30", "16:15")),
            trip("2026-10-17", "Familie Özdemir", "Familienshooting", "Am Anger 8", "85354", "Freising", 38.2, 37.9),
            trip("2026-10-09", "Steuerbüro Lang", "Business-Porträts", "Bahnhofplatz 2", "86150", "Augsburg", 71.5, 72.0),
            trip("2026-09-26", "Familie Huber", "Hochzeit", "Kirchplatz 1", "84028", "Landshut", 74.8, 75.1, times: ("10:00", "23:30")),
            trip("2026-09-12", "Bäckerei Maier", "Werbefotos", "Hauptstraße 22", "85570", "Markt Schwaben", 24.1, 24.3),
            trip("2026-07-04", "Familie Schmid", "Hochzeit", "Seeweg 9", "87645", "Schwangau", 118.6, 119.2),
            trip("2026-05-16", "Messe München", "Eventfotos", "Messegelände", "81823", "München", 14.2, 14.5),
            trip("2026-03-21", "Familie Wagner", "Babybauch-Shooting", "Gartenstraße 4", "85521", "Ottobrunn", 15.7, 15.9),
            trip("2025-12-13", "Weihnachtsmarkt Tölz", "Reportage", "Marktstraße 1", "83646", "Bad Tölz", 52.3, 52.0),
            trip("2025-08-30", "Familie Koch", "Hochzeit", "Schlossweg 2", "86899", "Landsberg am Lech", 58.4, 58.9),
        ]
        return doc
    }
}
