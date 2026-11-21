import Foundation

/// Erzeugt eine echte Excel-Datei (.xlsx, Office Open XML) inkl. Formatierung,
/// Monats-Zwischensummen (als Formeln) und Jahressumme.
enum XLSXExporter {

    // Stil-Indizes (siehe styles.xml unten)
    private enum S {
        static let normal = 0
        static let bold = 1
        static let title = 2
        static let header = 3
        static let date = 4
        static let km = 5
        static let euro = 6
        static let totalKm = 7
        static let totalEuro = 8
        static let wrap = 9
        static let totalLabel = 10
        static let monthHeader = 11
        static let grandKm = 12
        static let grandEuro = 13
        static let grandLabel = 14
        static let muted = 15
    }

    // Spalten: A Datum · B Abfahrt · C Rückkehr · D Kunde · E Anlass · F Start · G Ziel · H Rückfahrt nach
    //          I Hin km · J Rück km · K Gesamt km · L €/km · M Betrag · N Bemerkung
    private static let columns = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N"]
    private static let widths: [Double] = [11, 8, 9, 22, 22, 28, 28, 28, 10, 11, 10, 9, 12, 24]
    private static let headers = ["Datum", "Abfahrt", "Rückkehr", "Kunde / Geschäftspartner", "Anlass / Zweck",
                                  "Startadresse", "Zieladresse", "Rückfahrt nach",
                                  "Hinfahrt km", "Rückfahrt km", "Gesamt km", "€ / km", "Betrag €", "Bemerkung"]

    static func make(_ report: ReportData) -> Data {
        var zip = ZipArchive(date: report.createdAt)
        zip.addFile("[Content_Types].xml", data: Data(contentTypes.utf8))
        zip.addFile("_rels/.rels", data: Data(rootRels.utf8))
        zip.addFile("docProps/core.xml", data: Data(coreProps(report).utf8))
        zip.addFile("xl/workbook.xml", data: Data(workbook(report).utf8))
        zip.addFile("xl/_rels/workbook.xml.rels", data: Data(workbookRels.utf8))
        zip.addFile("xl/styles.xml", data: Data(styles.utf8))
        zip.addFile("xl/worksheets/sheet1.xml", data: Data(sheet(report).utf8))
        return zip.finalize()
    }

    // MARK: Arbeitsblatt

    private static func sheet(_ report: ReportData) -> String {
        var rows: [String] = []
        var r = 0

        func addRow(_ cells: [String], height: Double? = nil) {
            r += 1
            let ht = height.map { " ht=\"\($0)\" customHeight=\"1\"" } ?? ""
            rows.append("<row r=\"\(r)\"\(ht)>" + cells.joined() + "</row>")
        }
        func ref(_ col: Int) -> String { "\(columns[col])\(r + 1)" } // Zelle der nächsten Zeile
        func filled(_ style: Int, from: Int, to: Int) -> [String] { (from...to).map { empty(ref($0), style) } }

        // Kopfbereich
        addRow([text(ref(0), report.title, S.title)], height: 24)
        let h = report.header
        var info: [String] = []
        if !h.name.isEmpty { info.append("Name: \(h.name)") }
        if !h.company.isEmpty { info.append("Firma: \(h.company)") }
        if !h.address.isEmpty { info.append("Anschrift / Startadresse: \(h.address)") }
        if !h.taxNumber.isEmpty { info.append("Steuernummer: \(h.taxNumber)") }
        info.append("Fahrzeug: " + ([h.vehicleType, h.vehicle].filter { !$0.isEmpty }.joined(separator: " · ")))
        info.append("Art der Fahrten: betrieblich veranlasste Fahrten (Kundentermine)")
        info.append("Kilometersatz: \(report.rateLabel)")
        info.append("Zeitraum: \(report.periodLabel)")
        for line in info { addRow([text(ref(0), line, S.normal)]) }
        addRow([])

        // Tabellenkopf
        addRow(headers.enumerated().map { text(ref($0.offset), $0.element, S.header) }, height: 30)
        let headerRow = r

        var subtotalRows: [Int] = []

        for group in report.groups {
            let monthLabel = "\(Fmt.monthName(group.month)) \(report.year)"
            addRow([text(ref(0), monthLabel, S.monthHeader)] + filled(S.monthHeader, from: 1, to: columns.count - 1))

            let first = r + 1
            for row in group.rows {
                let n = r + 1
                var remark = row.note
                if row.kmPending { remark = remark.isEmpty ? "km noch nicht berechnet" : "km noch nicht berechnet · " + remark }
                addRow([
                    number(ref(0), excelDate(row.date), S.date),
                    text(ref(1), row.departureTime, S.wrap),
                    text(ref(2), row.returnTime, S.wrap),
                    text(ref(3), row.customer, S.wrap),
                    text(ref(4), row.purpose, S.wrap),
                    text(ref(5), row.start, S.wrap),
                    text(ref(6), row.destination, S.wrap),
                    text(ref(7), row.returnEnabled ? row.returnTo : "– (einfache Fahrt)", S.wrap),
                    number(ref(8), row.outboundKm, S.km),
                    number(ref(9), row.returnKm, S.km),
                    formula(ref(10), "I\(n)+J\(n)", row.totalKm, S.km),
                    number(ref(11), row.rate, S.euro),
                    formula(ref(12), "ROUND(K\(n)*L\(n),2)", row.amount, S.euro),
                    text(ref(13), remark, S.wrap)
                ])
            }
            let last = r

            addRow([text(ref(0), "Summe \(Fmt.monthName(group.month))", S.totalLabel)]
                + filled(S.totalLabel, from: 1, to: 7)
                + [
                    formula(ref(8), "SUM(I\(first):I\(last))", group.outboundKm, S.totalKm),
                    formula(ref(9), "SUM(J\(first):J\(last))", group.returnKm, S.totalKm),
                    formula(ref(10), "SUM(K\(first):K\(last))", group.totalKm, S.totalKm),
                    empty(ref(11), S.totalLabel),
                    formula(ref(12), "SUM(M\(first):M\(last))", group.amount, S.totalEuro),
                    empty(ref(13), S.totalLabel)
                ])
            subtotalRows.append(r)
            addRow([])
        }

        // Gesamtsumme
        func sumOf(_ col: String) -> String {
            subtotalRows.isEmpty ? "0" : subtotalRows.map { "\(col)\($0)" }.joined(separator: "+")
        }
        addRow([text(ref(0), "Gesamt \(report.periodLabel) (\(Fmt.tripCount(report.tripCount)))", S.grandLabel)]
            + filled(S.grandLabel, from: 1, to: 7)
            + [
                formula(ref(8), sumOf("I"), report.outboundKm, S.grandKm),
                formula(ref(9), sumOf("J"), report.returnKm, S.grandKm),
                formula(ref(10), sumOf("K"), report.totalKm, S.grandKm),
                empty(ref(11), S.grandLabel),
                formula(ref(12), sumOf("M"), report.amount, S.grandEuro),
                empty(ref(13), S.grandLabel)
            ], height: 22)

        addRow([])
        if report.hasPendingKm {
            addRow([text(ref(0), "Hinweis: Einige Fahrten enthalten noch keine berechneten Kilometer (Spalte „Bemerkung“).", S.muted)])
        }
        addRow([text(ref(0), "Erstellt am \(Fmt.date(report.createdAt)) mit Business Miles. Kilometer laut Routenberechnung bzw. manueller Angabe; Startadresse je Fahrt wie zum Zeitpunkt der Erfassung.", S.muted)])

        let cols = widths.enumerated().map { i, w in
            "<col min=\"\(i + 1)\" max=\"\(i + 1)\" width=\"\(w)\" customWidth=\"1\"/>"
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>\
        <dimension ref="A1:N\(max(r, 1))"/>\
        <sheetViews><sheetView workbookViewId="0"><pane ySplit="\(headerRow)" topLeftCell="A\(headerRow + 1)" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>\
        <sheetFormatPr defaultRowHeight="15"/>\
        <cols>\(cols)</cols>\
        <sheetData>\(rows.joined())</sheetData>\
        <pageMargins left="0.3" right="0.3" top="0.5" bottom="0.5" header="0.3" footer="0.3"/>\
        <pageSetup paperSize="9" orientation="\(report.portrait ? "portrait" : "landscape")" fitToWidth="1" fitToHeight="0"/>\
        <headerFooter><oddFooter>&amp;L\(xmlEscape(report.title))&amp;RSeite &amp;P von &amp;N</oddFooter></headerFooter>\
        </worksheet>
        """
    }

    // MARK: Zellen

    private static func text(_ ref: String, _ value: String, _ style: Int) -> String {
        "<c r=\"\(ref)\" s=\"\(style)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xmlEscape(value))</t></is></c>"
    }

    private static func number(_ ref: String, _ value: Double, _ style: Int) -> String {
        "<c r=\"\(ref)\" s=\"\(style)\"><v>\(xmlNumber(value))</v></c>"
    }

    private static func formula(_ ref: String, _ f: String, _ cached: Double, _ style: Int) -> String {
        "<c r=\"\(ref)\" s=\"\(style)\"><f>\(xmlEscape(f))</f><v>\(xmlNumber(cached))</v></c>"
    }

    private static func empty(_ ref: String, _ style: Int) -> String {
        "<c r=\"\(ref)\" s=\"\(style)\"/>"
    }

    private static func xmlNumber(_ value: Double) -> String {
        // Punkt als Dezimaltrenner, keine Exponentialschreibweise
        String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    /// Excel-Seriennummer (Tage seit 30.12.1899).
    private static func excelDate(_ date: Date) -> Double {
        let cal = Fmt.calendar
        guard let base = cal.date(from: DateComponents(year: 1899, month: 12, day: 30)) else { return 0 }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: base), to: cal.startOfDay(for: date)).day ?? 0
        return Double(days)
    }

    static func xmlEscape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default:
                // Steuerzeichen (außer Tab/Zeilenumbruch) sind in XML 1.0 nicht erlaubt
                if let scalar = ch.unicodeScalars.first, ch.unicodeScalars.count == 1,
                   scalar.value < 0x20, scalar != "\t", scalar != "\n", scalar != "\r" {
                    continue
                }
                out.append(ch)
            }
        }
        return out
    }

    // MARK: Paket-Dateien

    private static let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
    <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
    <Default Extension="xml" ContentType="application/xml"/>\
    <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
    <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
    <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>\
    <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>\
    </Types>
    """

    private static let rootRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\
    <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>\
    </Relationships>
    """

    private static let workbookRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\
    <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>\
    </Relationships>
    """

    private static func workbook(_ report: ReportData) -> String {
        // Blattnamen: max. 31 Zeichen, keine Sonderzeichen wie : \ / ? * [ ]
        let name = report.month.map { "\(Fmt.monthName($0)) \(report.year)" } ?? "Fahrten \(report.year)"
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <sheets><sheet name="\(xmlEscape(String(name.prefix(31))))" sheetId="1" r:id="rId1"/></sheets>\
        </workbook>
        """
    }

    private static func coreProps(_ report: ReportData) -> String {
        let iso = ISO8601DateFormatter().string(from: report.createdAt)
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\
        <dc:title>\(xmlEscape(report.title))</dc:title>\
        <dc:creator>Business Miles</dc:creator>\
        <dcterms:created xsi:type="dcterms:W3CDTF">\(iso)</dcterms:created>\
        </cp:coreProperties>
        """
    }

    /// Stile: 0 normal · 1 fett · 2 Titel · 3 Tabellenkopf · 4 Datum · 5 km · 6 Euro ·
    /// 7 Summe km · 8 Summe € · 9 Umbruch · 10 Summe Text · 11 Monatskopf ·
    /// 12 Gesamt km · 13 Gesamt € · 14 Gesamt Text · 15 grau
    private static let styles = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
    <numFmts count="3">\
    <numFmt numFmtId="164" formatCode="#,##0.0"/>\
    <numFmt numFmtId="165" formatCode="#,##0.00\\ &quot;€&quot;"/>\
    <numFmt numFmtId="166" formatCode="dd\\.mm\\.yyyy"/>\
    </numFmts>\
    <fonts count="5">\
    <font><sz val="11"/><color rgb="FF1C2B3A"/><name val="Calibri"/><family val="2"/></font>\
    <font><b/><sz val="11"/><color rgb="FF1C2B3A"/><name val="Calibri"/><family val="2"/></font>\
    <font><b/><sz val="16"/><color rgb="FF165F8A"/><name val="Calibri"/><family val="2"/></font>\
    <font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/><family val="2"/></font>\
    <font><i/><sz val="9"/><color rgb="FF5B6B7A"/><name val="Calibri"/><family val="2"/></font>\
    </fonts>\
    <fills count="5">\
    <fill><patternFill patternType="none"/></fill>\
    <fill><patternFill patternType="gray125"/></fill>\
    <fill><patternFill patternType="solid"><fgColor rgb="FF0F8B8D"/><bgColor indexed="64"/></patternFill></fill>\
    <fill><patternFill patternType="solid"><fgColor rgb="FFE3F3F3"/><bgColor indexed="64"/></patternFill></fill>\
    <fill><patternFill patternType="solid"><fgColor rgb="FFD2EAEA"/><bgColor indexed="64"/></patternFill></fill>\
    </fills>\
    <borders count="3">\
    <border><left/><right/><top/><bottom/><diagonal/></border>\
    <border><left/><right/><top/><bottom style="thin"><color rgb="FFE2E7EC"/></bottom><diagonal/></border>\
    <border><left/><right/><top style="thin"><color rgb="FF1C2B3A"/></top><bottom style="double"><color rgb="FF1C2B3A"/></bottom><diagonal/></border>\
    </borders>\
    <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>\
    <cellXfs count="16">\
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>\
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>\
    <xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>\
    <xf numFmtId="0" fontId="3" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf>\
    <xf numFmtId="166" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="top"/></xf>\
    <xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment vertical="top"/></xf>\
    <xf numFmtId="165" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment vertical="top"/></xf>\
    <xf numFmtId="164" fontId="1" fillId="3" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1"/>\
    <xf numFmtId="165" fontId="1" fillId="3" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1"/>\
    <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>\
    <xf numFmtId="0" fontId="1" fillId="3" borderId="0" xfId="0" applyFont="1" applyFill="1"/>\
    <xf numFmtId="0" fontId="1" fillId="4" borderId="0" xfId="0" applyFont="1" applyFill="1"/>\
    <xf numFmtId="164" fontId="1" fillId="0" borderId="2" xfId="0" applyNumberFormat="1" applyFont="1" applyBorder="1"/>\
    <xf numFmtId="165" fontId="1" fillId="0" borderId="2" xfId="0" applyNumberFormat="1" applyFont="1" applyBorder="1"/>\
    <xf numFmtId="0" fontId="1" fillId="0" borderId="2" xfId="0" applyFont="1" applyBorder="1"/>\
    <xf numFmtId="0" fontId="4" fillId="0" borderId="0" xfId="0" applyFont="1"/>\
    </cellXfs>\
    <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>\
    </styleSheet>
    """
}
