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

    private static let columns = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
    private static let widths: [Double] = [12, 24, 24, 32, 32, 32, 11, 11, 11, 13]
    private static let headers = ["Datum", "Kunde / Geschäftspartner", "Anlass / Zweck",
                                  "Startadresse", "Zieladresse", "Rückfahrt nach",
                                  "Hinfahrt km", "Rückfahrt km", "Gesamt km", "Betrag €"]

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

        // Kopfbereich
        addRow([text(ref(0), report.title, S.title)], height: 24)
        let h = report.header
        var info: [String] = []
        if !h.name.isEmpty { info.append("Name: \(h.name)") }
        if !h.company.isEmpty { info.append("Firma: \(h.company)") }
        if !h.address.isEmpty { info.append("Anschrift / Startadresse: \(h.address)") }
        if !h.taxNumber.isEmpty { info.append("Steuernummer: \(h.taxNumber)") }
        if !h.vehicle.isEmpty { info.append("Fahrzeug: \(h.vehicle)") }
        info.append("Kilometersatz: \(Fmt.rate(h.rate)) je km")
        info.append("Zeitraum: \(report.periodLabel)")
        for line in info { addRow([text(ref(0), line, S.normal)]) }
        addRow([])

        // Tabellenkopf
        addRow(headers.enumerated().map { text(ref($0.offset), $0.element, S.header) }, height: 30)
        let headerRow = r

        var subtotalRows: [Int] = []

        for group in report.groups {
            let monthLabel = "\(Fmt.monthName(group.month)) \(report.year)"
            addRow((0..<columns.count).map { col in
                col == 0 ? text(ref(0), monthLabel, S.monthHeader) : empty(ref(col), S.monthHeader)
            })

            let first = r + 1
            for row in group.rows {
                addRow([
                    number(ref(0), excelDate(row.date), S.date),
                    text(ref(1), row.customer, S.wrap),
                    text(ref(2), row.purpose, S.wrap),
                    text(ref(3), row.start, S.wrap),
                    text(ref(4), row.destination, S.wrap),
                    text(ref(5), row.returnEnabled ? row.returnTo : "– (einfache Fahrt)", S.wrap),
                    number(ref(6), row.outboundKm, S.km),
                    number(ref(7), row.returnKm, S.km),
                    formula(ref(8), "G\(r + 1)+H\(r + 1)", row.totalKm, S.km),
                    formula(ref(9), "ROUND(I\(r + 1)*\(xmlNumber(h.rate)),2)", row.amount, S.euro)
                ])
            }
            let last = r

            addRow([
                text(ref(0), "Summe \(Fmt.monthName(group.month))", S.totalLabel),
                empty(ref(1), S.totalLabel), empty(ref(2), S.totalLabel), empty(ref(3), S.totalLabel),
                empty(ref(4), S.totalLabel), empty(ref(5), S.totalLabel),
                formula(ref(6), "SUM(G\(first):G\(last))", group.outboundKm, S.totalKm),
                formula(ref(7), "SUM(H\(first):H\(last))", group.returnKm, S.totalKm),
                formula(ref(8), "SUM(I\(first):I\(last))", group.totalKm, S.totalKm),
                formula(ref(9), "SUM(J\(first):J\(last))", group.amount, S.totalEuro)
            ])
            subtotalRows.append(r)
            addRow([])
        }

        // Gesamtsumme
        func sumOf(_ col: String) -> String {
            subtotalRows.isEmpty ? "0" : subtotalRows.map { "\(col)\($0)" }.joined(separator: "+")
        }
        addRow([
            text(ref(0), "Gesamt \(report.periodLabel) (\(Fmt.tripCount(report.tripCount)))", S.grandLabel),
            empty(ref(1), S.grandLabel), empty(ref(2), S.grandLabel), empty(ref(3), S.grandLabel),
            empty(ref(4), S.grandLabel), empty(ref(5), S.grandLabel),
            formula(ref(6), sumOf("G"), report.outboundKm, S.grandKm),
            formula(ref(7), sumOf("H"), report.returnKm, S.grandKm),
            formula(ref(8), sumOf("I"), report.totalKm, S.grandKm),
            formula(ref(9), sumOf("J"), report.amount, S.grandEuro)
        ], height: 22)

        addRow([])
        addRow([text(ref(0), "Erstellt am \(Fmt.date(report.createdAt)) mit Business Miles. Kilometer laut Routenberechnung (Apple Maps) bzw. manueller Angabe.", S.muted)])
        addRow([])
        addRow([text(ref(0), "Ort, Datum: ______________________________        Unterschrift: ______________________________", S.normal)])

        let cols = widths.enumerated().map { i, w in
            "<col min=\"\(i + 1)\" max=\"\(i + 1)\" width=\"\(w)\" customWidth=\"1\"/>"
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>\
        <dimension ref="A1:J\(max(r, 1))"/>\
        <sheetViews><sheetView workbookViewId="0"><pane ySplit="\(headerRow)" topLeftCell="A\(headerRow + 1)" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>\
        <sheetFormatPr defaultRowHeight="15"/>\
        <cols>\(cols)</cols>\
        <sheetData>\(rows.joined())</sheetData>\
        <pageMargins left="0.4" right="0.4" top="0.6" bottom="0.6" header="0.3" footer="0.3"/>\
        <pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/>\
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
