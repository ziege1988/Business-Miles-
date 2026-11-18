import SwiftUI

/// Teilt den Bericht auf A4-Querformat-Seiten auf.
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

        var height: CGFloat {
            switch self {
            case .monthHeader: ReportLayout.monthHeaderHeight
            case .row: ReportLayout.rowHeight
            case .monthTotal: ReportLayout.totalHeight
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

enum ReportLayout {
    static let pageSize = CGSize(width: 841.89, height: 595.28)   // A4 quer in pt
    static let margin: CGFloat = 32
    static let firstPageHeader: CGFloat = 112
    static let otherPageHeader: CGFloat = 30
    static let tableHeader: CGFloat = 24
    static let footer: CGFloat = 22
    static let summaryBlock: CGFloat = 92
    static let monthHeaderHeight: CGFloat = 22
    static let rowHeight: CGFloat = 30
    static let totalHeight: CGFloat = 22

    // Spaltenbreiten – Summe = Seitenbreite − 2 × Rand (≈ 778 pt)
    static let colDate: CGFloat = 58
    static let colCustomer: CGFloat = 118
    static let colPurpose: CGFloat = 104
    static let colStart: CGFloat = 146
    static let colDestination: CGFloat = 145
    static let colKm: CGFloat = 50
    static let colTotal: CGFloat = 54
    static let colAmount: CGFloat = 52

    static func paginate(_ report: ReportData) -> [ReportPage] {
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
            if case .monthHeader = item { needed = item.height + rowHeight } else { needed = item.height }
            if used + needed > capacity, !current.isEmpty {
                pages.append(ReportPage(index: pages.count, count: 0, items: current, showsSummary: false))
                current = []
                used = 0
                capacity = body - otherPageHeader
            }
            current.append(item)
            used += item.height
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

    private typealias L = ReportLayout

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

    private var firstHeader: some View {
        HStack(alignment: .top, spacing: 16) {
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
            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                infoLine("Name", report.header.name)
                infoLine("Firma", report.header.company)
                infoLine("Anschrift", report.header.address)
                infoLine("Steuernummer", report.header.taxNumber)
                infoLine("Fahrzeug", [report.header.vehicleType, report.header.vehicle].filter { !$0.isEmpty }.joined(separator: " · "))
            }
            .frame(width: 300, alignment: .leading)
        }
        .frame(height: L.firstPageHeader - 12, alignment: .top)
        .padding(.bottom, 12)
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
            cell("Datum", L.colDate)
            cell("Kunde / Partner", L.colCustomer)
            cell("Anlass / Zweck", L.colPurpose)
            cell("Start", L.colStart)
            cell("Ziel", L.colDestination)
            cell("Hin km", L.colKm, trailing: true)
            cell("Rück km", L.colKm, trailing: true)
            cell("Gesamt", L.colTotal, trailing: true)
            cell("Betrag", L.colAmount, trailing: true)
        }
        .font(.system(size: 8.5, weight: .semibold))
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
            cell(row.timeRange.isEmpty ? Fmt.date(row.date) : "\(Fmt.date(row.date))\n\(row.timeRange)", L.colDate, lines: 2)
            cell(row.customer, L.colCustomer, lines: 2)
            cell([row.purpose, row.note].filter { !$0.isEmpty }.joined(separator: "\n"), L.colPurpose, lines: 2)
            cell(row.start, L.colStart, lines: 2)
            cell(row.returnEnabled && row.returnTo != row.start && !row.returnTo.isEmpty
                    ? "\(row.destination)\n↩ \(row.returnTo)"
                    : row.destination,
                 L.colDestination, lines: 2)
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
                .frame(width: L.colDate + L.colCustomer + L.colPurpose + L.colStart + L.colDestination, alignment: .leading)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 24) {
                summaryValue("Fahrten", String(report.tripCount))
                summaryValue("Kilometer gesamt", Fmt.km(report.totalKm))
                summaryValue("Kilometerpauschale", Fmt.euro(report.amount))
                Spacer()
            }
            HStack(spacing: 40) {
                signatureLine("Ort, Datum")
                signatureLine("Unterschrift")
            }
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

    private func signatureLine(_ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Rectangle().fill(Theme.ink.opacity(0.6)).frame(width: 220, height: 0.6)
            Text(label).font(.system(size: 7.5)).foregroundStyle(Theme.secondaryText)
        }
        .padding(.top, 16)
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
