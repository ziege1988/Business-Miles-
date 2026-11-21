import SwiftUI

/// Teilt den Bericht auf A4-Seiten auf (quer oder hoch).
struct ReportPage: Identifiable {
    enum Item: Identifiable {
        case monthHeader(String)
        case row(ReportData.Row)
        case monthTotal(label: String, outbound: Double, back: Double, total: Double, amount: Double)

        var id: String {
            switch self {
            case .monthHeader(let s): "h-\(s)"
            case .row(let r): "r-\(r.id)"
            case .monthTotal(let label, _, _, _, _): "t-\(label)"
            }
        }

    }

    let index: Int
    var count: Int
    var items: [Item]
    var showsSummary: Bool
    var id: Int { index }
    var isFirst: Bool { index == 0 }
}

/// Seitenmaße und Spalten – Querformat (viele Spalten) oder Hochformat (zusammengefasste Spalten).
struct ReportLayout {
    let portrait: Bool

    init(portrait: Bool) { self.portrait = portrait }
    init(for report: ReportData) { self.portrait = report.portrait }

    var pageSize: CGSize { portrait ? CGSize(width: 595.28, height: 841.89) : CGSize(width: 841.89, height: 595.28) }
    let margin: CGFloat = 32
    var firstPageHeader: CGFloat { portrait ? 150 : 112 }
    let otherPageHeader: CGFloat = 30
    let tableHeader: CGFloat = 30
    let footer: CGFloat = 22
    let summaryBlock: CGFloat = 54
    let monthHeaderHeight: CGFloat = 22
    var rowHeight: CGFloat { portrait ? 40 : 30 }
    let totalHeight: CGFloat = 22

    // Querformat – Summe ≈ 778 pt
    let colDate: CGFloat = 66
    let colCustomer: CGFloat = 118
    let colPurpose: CGFloat = 104
    let colStart: CGFloat = 138
    let colDestination: CGFloat = 137
    // Hochformat – Summe ≈ 531 pt (Kunde+Anlass und Start→Ziel zusammengefasst)
    let colCustomerPurpose: CGFloat = 112
    let colRoute: CGFloat = 160

    var colDateEffective: CGFloat { portrait ? 62 : colDate }
    var colKm: CGFloat { portrait ? 48 : 54 }
    var colTotal: CGFloat { portrait ? 48 : 54 }
    var colAmount: CGFloat { portrait ? 53 : 52 }
    /// Breite der Textspalten vor den Zahlen (für Summenzeilen)
    var textColumnsWidth: CGFloat {
        portrait ? colDateEffective + colCustomerPurpose + colRoute
                 : colDate + colCustomer + colPurpose + colStart + colDestination
    }

    func height(of item: ReportPage.Item) -> CGFloat {
        switch item {
        case .monthHeader: monthHeaderHeight
        case .row: rowHeight
        case .monthTotal: totalHeight
        }
    }

    func paginate(_ report: ReportData) -> [ReportPage] {
        var items: [ReportPage.Item] = []
        for g in report.groups {
            let name = "\(Fmt.monthName(g.month)) \(report.year)"
            items.append(.monthHeader(name))
            items.append(contentsOf: g.rows.map { .row($0) })
            items.append(.monthTotal(label: "Summe \(Fmt.monthName(g.month))",
                                     outbound: g.outboundKm, back: g.returnKm,
                                     total: g.totalKm, amount: g.amount))
        }

        let body = pageSize.height - 2 * margin - tableHeader - footer
        var pages: [ReportPage] = []
        var current: [ReportPage.Item] = []
        var used: CGFloat = 0
        var capacity = body - firstPageHeader

        for item in items {
            // Monatsüberschrift nicht allein am Seitenende stehen lassen
            let needed: CGFloat
            if case .monthHeader = item { needed = height(of: item) + rowHeight } else { needed = height(of: item) }
            if used + needed > capacity, !current.isEmpty {
                pages.append(ReportPage(index: pages.count, count: 0, items: current, showsSummary: false))
                current = []
                used = 0
                capacity = body - otherPageHeader
            }
            current.append(item)
            used += height(of: item)
        }

        if used + summaryBlock <= capacity || current.isEmpty {
            pages.append(ReportPage(index: pages.count, count: 0, items: current, showsSummary: true))
        } else {
            pages.append(ReportPage(index: pages.count, count: 0, items: current, showsSummary: false))
            pages.append(ReportPage(index: pages.count, count: 0, items: [], showsSummary: true))
        }

        let total = pages.count
        return pages.map { var p = $0; p.count = total; return p }
    }
}

/// Eine druckfertige Seite (für PDF und Bild-Export).
struct ReportPageView: View {
    let report: ReportData
    let page: ReportPage

    private var L: ReportLayout { ReportLayout(for: report) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if page.isFirst { firstHeader } else { shortHeader }
            tableHeader
            ForEach(page.items) { item in
                switch item {
                case .monthHeader(let name):
                    monthHeader(name)
                case .row(let row):
                    rowView(row)
                case .monthTotal(let label, let outbound, let back, let total, let amount):
                    totalRow(label: label, outbound: outbound, back: back, total: total, amount: amount)
                }
            }
            if page.showsSummary { summary }
            Spacer(minLength: 0)
            footer
        }
        .padding(L.margin)
        .frame(width: L.pageSize.width, height: L.pageSize.height, alignment: .topLeading)
        .background(Color.white)
        .foregroundStyle(Theme.ink)
        .environment(\.locale, Fmt.locale)
    }

    // MARK: Kopf

    @ViewBuilder
    private var firstHeader: some View {
        if L.portrait {
            VStack(alignment: .leading, spacing: 10) {
                titleBlock
                infoBlock.frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: L.firstPageHeader - 12, alignment: .top)
            .padding(.bottom, 12)
        } else {
            HStack(alignment: .top, spacing: 16) {
                titleBlock
                Spacer()
                infoBlock.frame(width: 300, alignment: .leading)
            }
            .frame(height: L.firstPageHeader - 12, alignment: .top)
            .padding(.bottom, 12)
        }
    }

    private var titleBlock: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    LogoMark(size: 22)
                    Text("Business Miles")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
                Text(report.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.accentDeep)
                Text("Nachweis betrieblich veranlasster Fahrten · Kilometersatz \(report.rateLabel)")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.secondaryText)
            }
    }

    private var infoBlock: some View {
            VStack(alignment: .leading, spacing: 2) {
                infoLine("Name", report.header.name)
                infoLine("Firma", report.header.company)
                infoLine("Anschrift", report.header.address)
                infoLine("Steuernummer", report.header.taxNumber)
                infoLine("Fahrzeug", [report.header.vehicleType, report.header.vehicle].filter { !$0.isEmpty }.joined(separator: " · "))
            }
    }

    @ViewBuilder
    private func infoLine(_ label: String, _ value: String) -> some View {
        if !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(label)
                    .font(.system(size: 8.5))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 70, alignment: .leading)
                Text(value)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
            }
        }
    }

    private var shortHeader: some View {
        HStack {
            Text(report.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.accentDeep)
            Spacer()
            Text(report.header.name).font(.system(size: 9)).foregroundStyle(Theme.secondaryText)
        }
        .frame(height: L.otherPageHeader - 8, alignment: .top)
        .padding(.bottom, 8)
    }

    // MARK: Tabelle

    private var tableHeader: some View {
        HStack(spacing: 0) {
            if L.portrait {
                cell("Datum", L.colDateEffective)
                cell("Kunde / Anlass", L.colCustomerPurpose)
                cell("Strecke (Start → Ziel)", L.colRoute)
            } else {
                cell("Datum", L.colDate)
                cell("Kunde / Partner", L.colCustomer)
                cell("Anlass / Zweck", L.colPurpose)
                cell("Start", L.colStart)
                cell("Ziel", L.colDestination)
            }
            cell("Hinfahrt\nkm", L.colKm, trailing: true, lines: 2)
            cell("Rückfahrt\nkm", L.colKm, trailing: true, lines: 2)
            cell("Gesamt\nkm", L.colTotal, trailing: true, lines: 2)
            cell("Betrag", L.colAmount, trailing: true)
        }
        .font(.system(size: 8.5, weight: .semibold))
        .minimumScaleFactor(0.8)   // lieber minimal kleiner als abgeschnitten
        .foregroundStyle(Color.white)
        .frame(height: L.tableHeader)
        .background(Theme.accent)
    }

    private func monthHeader(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 9.5, weight: .bold))
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: L.monthHeaderHeight, maxHeight: L.monthHeaderHeight, alignment: .leading)
            .background(Theme.accentSoft)
    }

    private func rowView(_ row: ReportData.Row) -> some View {
        HStack(alignment: .top, spacing: 0) {
            let dateText = row.timeRange.isEmpty ? Fmt.date(row.date) : "\(Fmt.date(row.date))\n\(row.timeRange)"
            let returnText = row.returnEnabled && row.returnTo != row.start && !row.returnTo.isEmpty ? row.returnTo : ""
            if L.portrait {
                cell(dateText, L.colDateEffective, lines: 2)
                cell([row.customer, row.purpose, row.note].filter { !$0.isEmpty }.joined(separator: "\n"),
                     L.colCustomerPurpose, lines: 3)
                cell("\(row.start)\n→ \(row.destination)" + (returnText.isEmpty ? "" : "\n↩ \(returnText)"),
                     L.colRoute, lines: 3)
            } else {
                cell(dateText, L.colDate, lines: 2)
                cell(row.customer, L.colCustomer, lines: 2)
                cell([row.purpose, row.note].filter { !$0.isEmpty }.joined(separator: "\n"), L.colPurpose, lines: 2)
                cell(row.start, L.colStart, lines: 2)
                cell(returnText.isEmpty ? row.destination : "\(row.destination)\n↩ \(returnText)",
                     L.colDestination, lines: 2)
            }
            cell(Fmt.number(row.outboundKm), L.colKm, trailing: true)
            cell(row.returnEnabled ? Fmt.number(row.returnKm) : "–", L.colKm, trailing: true)
            cell(row.kmPending ? "folgt" : Fmt.number(row.totalKm), L.colTotal, trailing: true, bold: true)
            cell(report.hasMixedRates ? "\(Fmt.euro(row.amount))\n\(Fmt.rate(row.rate))/km" : Fmt.euro(row.amount),
                 L.colAmount, trailing: true, lines: 2)
        }
        .font(.system(size: 8))
        .padding(.top, 4)
        .frame(height: L.rowHeight, alignment: .top)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 0.5) }
    }

    private func totalRow(label: String, outbound: Double, back: Double, total: Double, amount: Double) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .padding(.horizontal, 4)
                .frame(width: L.textColumnsWidth, alignment: .leading)
            cell(Fmt.number(outbound), L.colKm, trailing: true)
            cell(Fmt.number(back), L.colKm, trailing: true)
            cell(Fmt.number(total), L.colTotal, trailing: true)
            cell(Fmt.euro(amount), L.colAmount, trailing: true)
        }
        .font(.system(size: 8.5, weight: .semibold))
        .frame(height: L.totalHeight)
        .background(Theme.accentSoft.opacity(0.6))
    }

    private func cell(_ text: String, _ width: CGFloat, trailing: Bool = false,
                      lines: Int = 1, bold: Bool = false) -> some View {
        Text(text)
            .fontWeight(bold ? .semibold : nil)
            .lineLimit(lines)
            .multilineTextAlignment(trailing ? .trailing : .leading)
            .padding(.horizontal, 4)
            .frame(width: width, alignment: trailing ? .trailing : .leading)
    }

    // MARK: Summe & Fuß

    private var summary: some View {
        HStack(spacing: 24) {
            summaryValue("Fahrten", String(report.tripCount))
            summaryValue("Kilometer gesamt", Fmt.km(report.totalKm))
            summaryValue("Fahrtkosten", Fmt.euro(report.amount))
            Spacer()
        }
        .padding(.top, 14)
        .frame(height: L.summaryBlock, alignment: .top)
    }

    private func summaryValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 8)).foregroundStyle(Theme.secondaryText)
            Text(value).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.accentDeep)
        }
    }

    private var footer: some View {
        HStack {
            Text("Erstellt am \(Fmt.date(report.createdAt)) mit Business Miles")
            Spacer()
            Text("Seite \(page.index + 1) von \(page.count)")
        }
        .font(.system(size: 7.5))
        .foregroundStyle(Theme.secondaryText)
        .frame(height: L.footer, alignment: .bottom)
    }
}
