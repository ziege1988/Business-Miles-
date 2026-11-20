// Export: Excel (.xlsx), PDF (A4 quer) und Bilder (PNG je Seite) – gleicher Aufbau wie in der Mac-App.
import * as fmt from "./format.js";
import { singleLine, placeLine, totalKm, amount, tripRate, timeRange, VEHICLE_TYPES } from "./model.js";

// --- Berichtsdaten ---------------------------------------------------------

export function buildReport(summary, month, settings) {
  const rate = settings.ratePerKm;
  const groups = summary.months
    .filter((m) => m.trips.length && (!month || m.month === month))
    .map((m) => {
      const key = (t) => `${t.date} ${t.departureTime || ""}`;
      const rows = [...m.trips].sort((a, b) => (key(a) < key(b) ? -1 : key(a) > key(b) ? 1 : 0)).map((t) => ({
        date: t.date,
        customer: t.customer,
        purpose: t.purpose,
        start: singleLine(t.start),
        destination: placeLine(t.destination),
        returnEnabled: t.returnEnabled,
        returnTo: t.returnEnabled ? singleLine(t.returnTo) : "",
        outboundKm: t.outboundKm,
        returnKm: t.returnEnabled ? t.returnKm : 0,
        totalKm: totalKm(t),
        rate: tripRate(t, rate),
        amount: amount(t, rate),
        note: t.note,
        departureTime: t.departureTime,
        returnTime: t.returnTime,
        timeRange: timeRange(t),
        kmPending: t.kmPending,
      }));
      const sum = (k) => rows.reduce((s, r) => s + r[k], 0);
      return { month: m.month, rows, outboundKm: sum("outboundKm"), returnKm: sum("returnKm"), totalKm: sum("totalKm"), amount: sum("amount") };
    });
  const sum = (k) => groups.reduce((s, g) => s + g[k], 0);
  const periodLabel = month ? `${fmt.MONTHS[month - 1]} ${summary.year}` : `Jahr ${summary.year}`;
  const vehicleType = (VEHICLE_TYPES[settings.vehicleType] || VEHICLE_TYPES.custom).exportLabel;
  const vehicle = [vehicleType, settings.vehicleName, settings.licensePlate].filter(Boolean).join(" · ");
  const allRows = groups.flatMap((g) => g.rows);
  const mixedRates = new Set(allRows.map((r) => r.rate)).size > 1;
  const rateLabel = mixedRates
    ? `je Fahrt angegeben (Standard ${fmt.euro(rate)} je km)`
    : `${fmt.euro(allRows[0]?.rate ?? rate)} je km`;
  return {
    mixedRates, rateLabel, hasPendingKm: allRows.some((r) => r.kmPending),
    year: summary.year, month, periodLabel,
    title: `Fahrtenaufstellung ${periodLabel}`,
    header: {
      name: settings.fullName, company: settings.company, address: singleLine(settings.home),
      taxNumber: settings.taxNumber, vehicle, rate,
    },
    groups,
    tripCount: groups.reduce((s, g) => s + g.rows.length, 0),
    outboundKm: sum("outboundKm"), returnKm: sum("returnKm"), totalKm: sum("totalKm"), amount: sum("amount"),
    createdAt: fmt.todayString(),
    fileBase: month
      ? `Business-Miles_Fahrten_${summary.year}-${String(month).padStart(2, "0")}`
      : `Business-Miles_Fahrten_${summary.year}`,
  };
}

// --- ZIP (unkomprimiert) + XLSX ---------------------------------------------

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[i] = c >>> 0;
  }
  return t;
})();

function crc32(bytes) {
  let c = 0xffffffff;
  for (let i = 0; i < bytes.length; i++) c = CRC_TABLE[(c ^ bytes[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function zip(files) {
  const enc = new TextEncoder();
  const chunks = [];
  const central = [];
  let offset = 0;
  const now = new Date();
  const dosTime = (now.getHours() << 11) | (now.getMinutes() << 5) | (now.getSeconds() >> 1);
  const dosDate = ((now.getFullYear() - 1980) << 9) | ((now.getMonth() + 1) << 5) | now.getDate();

  for (const [name, content] of files) {
    const nameBytes = enc.encode(name);
    const data = typeof content === "string" ? enc.encode(content) : content;
    const crc = crc32(data);
    const local = new DataView(new ArrayBuffer(30));
    local.setUint32(0, 0x04034b50, true);
    local.setUint16(4, 20, true);
    local.setUint16(6, 0x0800, true);
    local.setUint16(8, 0, true);
    local.setUint16(10, dosTime, true);
    local.setUint16(12, dosDate, true);
    local.setUint32(14, crc, true);
    local.setUint32(18, data.length, true);
    local.setUint32(22, data.length, true);
    local.setUint16(26, nameBytes.length, true);
    local.setUint16(28, 0, true);
    chunks.push(new Uint8Array(local.buffer), nameBytes, data);

    const cd = new DataView(new ArrayBuffer(46));
    cd.setUint32(0, 0x02014b50, true);
    cd.setUint16(4, 20, true);
    cd.setUint16(6, 20, true);
    cd.setUint16(8, 0x0800, true);
    cd.setUint16(10, 0, true);
    cd.setUint16(12, dosTime, true);
    cd.setUint16(14, dosDate, true);
    cd.setUint32(16, crc, true);
    cd.setUint32(20, data.length, true);
    cd.setUint32(24, data.length, true);
    cd.setUint16(28, nameBytes.length, true);
    cd.setUint32(42, offset, true);
    central.push(new Uint8Array(cd.buffer), nameBytes);
    offset += 30 + nameBytes.length + data.length;
  }
  const cdSize = central.reduce((s, c) => s + c.length, 0);
  const end = new DataView(new ArrayBuffer(22));
  end.setUint32(0, 0x06054b50, true);
  end.setUint16(8, files.length, true);
  end.setUint16(10, files.length, true);
  end.setUint32(12, cdSize, true);
  end.setUint32(16, offset, true);
  return new Blob([...chunks, ...central, new Uint8Array(end.buffer)],
    { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" });
}

const x = (s) => String(s ?? "")
  .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, "")
  .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&apos;");
const n4 = (v) => (Number(v) || 0).toFixed(4);

function excelSerial(day) {
  const { y, m, d } = fmt.parseDay(day);
  return Math.round((Date.UTC(y, m - 1, d) - Date.UTC(1899, 11, 30)) / 86400000);
}

const S = { normal: 0, title: 2, header: 3, date: 4, km: 5, euro: 6, totalKm: 7, totalEuro: 8, wrap: 9,
  totalLabel: 10, monthHeader: 11, grandKm: 12, grandEuro: 13, grandLabel: 14, muted: 15 };
// A Datum · B Abfahrt · C Rückkehr · D Kunde · E Anlass · F Start · G Ziel · H Rückfahrt nach
// I Hin km · J Rück km · K Gesamt km · L €/km · M Betrag · N Bemerkung   (identisch zur Mac-App)
const COLS = "ABCDEFGHIJKLMN".split("");
const WIDTHS = [11, 8, 9, 22, 22, 28, 28, 28, 10, 11, 10, 9, 12, 24];
const HEADERS = ["Datum", "Abfahrt", "Rückkehr", "Kunde / Geschäftspartner", "Anlass / Zweck", "Startadresse", "Zieladresse",
  "Rückfahrt nach", "Hinfahrt km", "Rückfahrt km", "Gesamt km", "€ / km", "Betrag €", "Bemerkung"];

const STYLES = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="3"><numFmt numFmtId="164" formatCode="#,##0.0"/><numFmt numFmtId="165" formatCode="#,##0.00\\ &quot;€&quot;"/><numFmt numFmtId="166" formatCode="dd\\.mm\\.yyyy"/></numFmts><fonts count="5"><font><sz val="11"/><color rgb="FF1C2B3A"/><name val="Calibri"/><family val="2"/></font><font><b/><sz val="11"/><color rgb="FF1C2B3A"/><name val="Calibri"/><family val="2"/></font><font><b/><sz val="16"/><color rgb="FF165F8A"/><name val="Calibri"/><family val="2"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/><family val="2"/></font><font><i/><sz val="9"/><color rgb="FF5B6B7A"/><name val="Calibri"/><family val="2"/></font></fonts><fills count="5"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF0F8B8D"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFE3F3F3"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFD2EAEA"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="3"><border><left/><right/><top/><bottom/><diagonal/></border><border><left/><right/><top/><bottom style="thin"><color rgb="FFE2E7EC"/></bottom><diagonal/></border><border><left/><right/><top style="thin"><color rgb="FF1C2B3A"/></top><bottom style="double"><color rgb="FF1C2B3A"/></bottom><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="16"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/><xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/><xf numFmtId="0" fontId="3" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf><xf numFmtId="166" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="top"/></xf><xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment vertical="top"/></xf><xf numFmtId="165" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment vertical="top"/></xf><xf numFmtId="164" fontId="1" fillId="3" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1"/><xf numFmtId="165" fontId="1" fillId="3" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1"/><xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf><xf numFmtId="0" fontId="1" fillId="3" borderId="0" xfId="0" applyFont="1" applyFill="1"/><xf numFmtId="0" fontId="1" fillId="4" borderId="0" xfId="0" applyFont="1" applyFill="1"/><xf numFmtId="164" fontId="1" fillId="0" borderId="2" xfId="0" applyNumberFormat="1" applyFont="1" applyBorder="1"/><xf numFmtId="165" fontId="1" fillId="0" borderId="2" xfId="0" applyNumberFormat="1" applyFont="1" applyBorder="1"/><xf numFmtId="0" fontId="1" fillId="0" borderId="2" xfId="0" applyFont="1" applyBorder="1"/><xf numFmtId="0" fontId="4" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>`;

export function makeXlsx(report) {
  const rows = [];
  let r = 0;
  const ref = (c) => `${COLS[c]}${r + 1}`;
  const text = (c, v, s) => `<c r="${ref(c)}" s="${s}" t="inlineStr"><is><t xml:space="preserve">${x(v)}</t></is></c>`;
  const number = (c, v, s) => `<c r="${ref(c)}" s="${s}"><v>${n4(v)}</v></c>`;
  const formula = (c, f, v, s) => `<c r="${ref(c)}" s="${s}"><f>${x(f)}</f><v>${n4(v)}</v></c>`;
  const empty = (c, s) => `<c r="${ref(c)}" s="${s}"/>`;
  const addRow = (cells, height) => {
    r += 1;
    const ht = height ? ` ht="${height}" customHeight="1"` : "";
    rows.push(`<row r="${r}"${ht}>${cells.join("")}</row>`);
  };

  const h = report.header;
  addRow([text(0, report.title, S.title)], 24);
  const info = [];
  if (h.name) info.push(`Name: ${h.name}`);
  if (h.company) info.push(`Firma: ${h.company}`);
  if (h.address) info.push(`Anschrift / Startadresse: ${h.address}`);
  if (h.taxNumber) info.push(`Steuernummer: ${h.taxNumber}`);
  info.push(`Fahrzeug: ${h.vehicle}`);
  info.push("Art der Fahrten: betrieblich veranlasste Fahrten (Kundentermine)");
  info.push(`Kilometersatz: ${report.rateLabel}`);
  info.push(`Zeitraum: ${report.periodLabel}`);
  for (const line of info) addRow([text(0, line, S.normal)]);
  addRow([]);
  addRow(HEADERS.map((v, i) => text(i, v, S.header)), 30);
  const headerRow = r;

  const subtotalRows = [];
  for (const g of report.groups) {
    addRow(COLS.map((_, c) => (c === 0 ? text(0, `${fmt.MONTHS[g.month - 1]} ${report.year}`, S.monthHeader) : empty(c, S.monthHeader))));
    const first = r + 1;
    for (const row of g.rows) {
      const n = r + 1;
      const remark = row.kmPending ? ["km noch nicht berechnet", row.note].filter(Boolean).join(" · ") : row.note;
      addRow([
        number(0, excelSerial(row.date), S.date),
        text(1, row.departureTime, S.wrap),
        text(2, row.returnTime, S.wrap),
        text(3, row.customer, S.wrap),
        text(4, row.purpose, S.wrap),
        text(5, row.start, S.wrap),
        text(6, row.destination, S.wrap),
        text(7, row.returnEnabled ? row.returnTo : "– (einfache Fahrt)", S.wrap),
        number(8, row.outboundKm, S.km),
        number(9, row.returnKm, S.km),
        formula(10, `I${n}+J${n}`, row.totalKm, S.km),
        number(11, row.rate, S.euro),
        formula(12, `ROUND(K${n}*L${n},2)`, row.amount, S.euro),
        text(13, remark, S.wrap),
      ]);
    }
    const last = r;
    const label = `Summe ${fmt.MONTHS[g.month - 1]}`;
    addRow([
      text(0, label, S.totalLabel), ...[1, 2, 3, 4, 5, 6, 7].map((c) => empty(c, S.totalLabel)),
      formula(8, `SUM(I${first}:I${last})`, g.outboundKm, S.totalKm),
      formula(9, `SUM(J${first}:J${last})`, g.returnKm, S.totalKm),
      formula(10, `SUM(K${first}:K${last})`, g.totalKm, S.totalKm),
      empty(11, S.totalLabel),
      formula(12, `SUM(M${first}:M${last})`, g.amount, S.totalEuro),
      empty(13, S.totalLabel),
    ]);
    subtotalRows.push(r);
    addRow([]);
  }
  const sumOf = (c) => (subtotalRows.length ? subtotalRows.map((n) => `${c}${n}`).join("+") : "0");
  addRow([
    text(0, `Gesamt ${report.periodLabel} (${fmt.tripCount(report.tripCount)})`, S.grandLabel),
    ...[1, 2, 3, 4, 5, 6, 7].map((c) => empty(c, S.grandLabel)),
    formula(8, sumOf("I"), report.outboundKm, S.grandKm),
    formula(9, sumOf("J"), report.returnKm, S.grandKm),
    formula(10, sumOf("K"), report.totalKm, S.grandKm),
    empty(11, S.grandLabel),
    formula(12, sumOf("M"), report.amount, S.grandEuro),
    empty(13, S.grandLabel),
  ], 22);
  addRow([]);
  if (report.hasPendingKm) addRow([text(0, "Hinweis: Einige Fahrten enthalten noch keine berechneten Kilometer (Spalte „Bemerkung“).", S.muted)]);
  addRow([text(0, `Erstellt am ${fmt.date(report.createdAt)} mit Business Miles. Kilometer laut Routenberechnung bzw. manueller Angabe; Startadresse je Fahrt wie zum Zeitpunkt der Erfassung.`, S.muted)]);
  addRow([]);
  addRow([text(0, "Ort, Datum: ______________________________        Unterschrift: ______________________________", S.normal)]);

  const cols = WIDTHS.map((w, i) => `<col min="${i + 1}" max="${i + 1}" width="${w}" customWidth="1"/>`).join("");
  const sheet = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheetPr><pageSetUpPr fitToPage="1"/></sheetPr><dimension ref="A1:N${Math.max(r, 1)}"/><sheetViews><sheetView workbookViewId="0"><pane ySplit="${headerRow}" topLeftCell="A${headerRow + 1}" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><sheetFormatPr defaultRowHeight="15"/><cols>${cols}</cols><sheetData>${rows.join("")}</sheetData><pageMargins left="0.3" right="0.3" top="0.5" bottom="0.5" header="0.3" footer="0.3"/><pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/><headerFooter><oddFooter>&amp;L${x(report.title)}&amp;RSeite &amp;P von &amp;N</oddFooter></headerFooter></worksheet>`;

  const sheetName = (report.month ? `${fmt.MONTHS[report.month - 1]} ${report.year}` : `Fahrten ${report.year}`).slice(0, 31);
  return zip([
    ["[Content_Types].xml", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>`],
    ["_rels/.rels", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`],
    ["xl/workbook.xml", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="${x(sheetName)}" sheetId="1" r:id="rId1"/></sheets></workbook>`],
    ["xl/_rels/workbook.xml.rels", `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>`],
    ["xl/styles.xml", STYLES],
    ["xl/worksheets/sheet1.xml", sheet],
  ]);
}

// --- PDF (jsPDF + AutoTable) ------------------------------------------------

const TEAL = [15, 139, 141];
const DEEP = [22, 95, 138];
const INK = [28, 43, 58];
const MUTED = [91, 107, 122];
const SOFT = [227, 243, 243];

export function makePdf(report) {
  const { jsPDF } = window.jspdf;
  const doc = new jsPDF({ orientation: "landscape", unit: "pt", format: "a4" });
  const W = doc.internal.pageSize.getWidth();
  const H = doc.internal.pageSize.getHeight();
  const M = 32;
  const h = report.header;

  // Kopf
  doc.setTextColor(...MUTED); doc.setFont("helvetica", "bold"); doc.setFontSize(9);
  doc.text("Business Miles", M, M + 6);
  doc.setTextColor(...DEEP); doc.setFontSize(18);
  doc.text(report.title, M, M + 28);
  doc.setTextColor(...MUTED); doc.setFont("helvetica", "normal"); doc.setFontSize(8.5);
  doc.text(`Nachweis betrieblich veranlasster Fahrten · Kilometersatz ${report.rateLabel}`, M, M + 42);
  const info = [["Name", h.name], ["Firma", h.company], ["Anschrift", h.address], ["Steuernummer", h.taxNumber], ["Fahrzeug", h.vehicle]]
    .filter(([, v]) => v);
  let iy = M + 4;
  for (const [label, value] of info) {
    doc.setTextColor(...MUTED); doc.setFontSize(8); doc.text(label, W - M - 300, iy);
    doc.setTextColor(...INK); doc.setFontSize(8.5); doc.text(doc.splitTextToSize(value, 225)[0], W - M - 225, iy);
    iy += 12;
  }

  const body = [];
  for (const g of report.groups) {
    body.push([{ content: `${fmt.MONTHS[g.month - 1]} ${report.year}`, colSpan: 9,
      styles: { fillColor: SOFT, fontStyle: "bold", textColor: INK } }]);
    for (const r of g.rows) {
      const dest = r.returnEnabled && r.returnTo && r.returnTo !== r.start ? `${r.destination}\nzurück: ${r.returnTo}` : r.destination;
      body.push([
        r.timeRange ? `${fmt.date(r.date)}\n${r.timeRange}` : fmt.date(r.date),
        r.customer,
        [r.purpose, r.note].filter(Boolean).join("\n"),
        r.start, dest,
        fmt.num(r.outboundKm), r.returnEnabled ? fmt.num(r.returnKm) : "–",
        r.kmPending ? "folgt" : fmt.num(r.totalKm),
        report.mixedRates ? `${fmt.euro(r.amount)}\n${fmt.euro(r.rate)}/km` : fmt.euro(r.amount),
      ]);
    }
    const tot = { fillColor: [210, 234, 234], fontStyle: "bold" };
    body.push([{ content: `Summe ${fmt.MONTHS[g.month - 1]}`, colSpan: 5, styles: tot },
      { content: fmt.num(g.outboundKm), styles: tot }, { content: fmt.num(g.returnKm), styles: tot },
      { content: fmt.num(g.totalKm), styles: tot }, { content: fmt.euro(g.amount), styles: tot }]);
  }

  window.autoTable(doc, {
    startY: M + 70,
    margin: { left: M, right: M, top: M + 22, bottom: M + 14 },
    head: [["Datum", "Kunde / Partner", "Anlass / Zweck", "Start", "Ziel", "Hin km", "Rück km", "Gesamt", "Betrag"]],
    body,
    theme: "plain",
    styles: { font: "helvetica", fontSize: 7.8, textColor: INK, cellPadding: 3.5, overflow: "linebreak", valign: "top",
      lineColor: [226, 231, 236], lineWidth: { bottom: 0.4 } },
    headStyles: { fillColor: TEAL, textColor: [255, 255, 255], fontStyle: "bold", fontSize: 8 },
    columnStyles: {
      0: { cellWidth: 56 }, 1: { cellWidth: 112 }, 2: { cellWidth: 100 }, 3: { cellWidth: 146 }, 4: { cellWidth: 156 },
      5: { cellWidth: 48, halign: "right" }, 6: { cellWidth: 48, halign: "right" },
      7: { cellWidth: 52, halign: "right", fontStyle: "bold" }, 8: { cellWidth: 60, halign: "right" },
    },
    didParseCell: (d) => {
      if (d.section === "head" && d.column.index >= 5) d.cell.styles.halign = "right";
    },
    didDrawPage: (d) => {
      if (d.pageNumber > 1) {
        doc.setFont("helvetica", "bold"); doc.setFontSize(10); doc.setTextColor(...DEEP);
        doc.text(report.title, M, M + 8);
        doc.setFont("helvetica", "normal"); doc.setFontSize(8); doc.setTextColor(...MUTED);
        if (h.name) doc.text(h.name, W - M, M + 8, { align: "right" });
      }
    },
  });

  // Summen + Unterschrift
  let y = doc.lastAutoTable.finalY + 26;
  if (y > H - M - 80) { doc.addPage(); y = M + 30; }
  const block = [["Fahrten", String(report.tripCount)], ["Kilometer gesamt", fmt.km(report.totalKm)], ["Kilometerpauschale", fmt.euro(report.amount)]];
  let bx = M;
  for (const [label, value] of block) {
    doc.setFont("helvetica", "normal"); doc.setFontSize(8); doc.setTextColor(...MUTED); doc.text(label, bx, y);
    doc.setFont("helvetica", "bold"); doc.setFontSize(13); doc.setTextColor(...DEEP); doc.text(value, bx, y + 16);
    bx += 150;
  }
  y += 52;
  doc.setDrawColor(...INK); doc.setLineWidth(0.6);
  doc.line(M, y, M + 220, y); doc.line(M + 270, y, M + 490, y);
  doc.setFont("helvetica", "normal"); doc.setFontSize(7.5); doc.setTextColor(...MUTED);
  doc.text("Ort, Datum", M, y + 10); doc.text("Unterschrift", M + 270, y + 10);

  // Fußzeilen
  const pages = doc.getNumberOfPages();
  for (let i = 1; i <= pages; i++) {
    doc.setPage(i);
    doc.setFont("helvetica", "normal"); doc.setFontSize(7.5); doc.setTextColor(...MUTED);
    doc.text(`Erstellt am ${fmt.date(report.createdAt)} mit Business Miles`, M, H - M + 6);
    doc.text(`Seite ${i} von ${pages}`, W - M, H - M + 6, { align: "right" });
  }
  return doc.output("blob");
}

// --- Bilder (Canvas, eine PNG je Seite) --------------------------------------

const IMG = { w: 1240, h: 1754, m: 64 };  // A4 hoch, ca. 150 dpi – gut lesbar auf dem Handy

export async function makeImages(report) {
  const items = [];
  for (const g of report.groups) {
    items.push({ type: "month", label: `${fmt.MONTHS[g.month - 1]} ${report.year}` });
    for (const r of g.rows) items.push({ type: "row", r });
    items.push({ type: "total", label: `Summe ${fmt.MONTHS[g.month - 1]}`, km: g.totalKm, amount: g.amount });
  }
  const H_ROW = 78, H_MONTH = 50, H_TOTAL = 50, H_SUMMARY = 230;
  const heightOf = (it) => (it.type === "row" ? H_ROW : it.type === "month" ? H_MONTH : H_TOTAL);
  const pages = [];
  let cur = [], used = 0, cap = IMG.h - 2 * IMG.m - 300 - 60;
  for (const it of items) {
    const need = it.type === "month" ? H_MONTH + H_ROW : heightOf(it);
    if (used + need > cap && cur.length) { pages.push(cur); cur = []; used = 0; cap = IMG.h - 2 * IMG.m - 110 - 60; }
    cur.push(it); used += heightOf(it);
  }
  if (used + H_SUMMARY > cap && cur.length) { pages.push(cur); cur = []; }
  pages.push(cur);

  const blobs = [];
  for (let p = 0; p < pages.length; p++) {
    blobs.push(await drawImagePage(report, pages[p], p, pages.length, p === pages.length - 1));
  }
  return blobs;
}

function drawImagePage(report, items, index, count, last) {
  const c = document.createElement("canvas");
  c.width = IMG.w; c.height = IMG.h;
  const g = c.getContext("2d");
  const M = IMG.m, W = IMG.w;
  const font = (size, weight = 400) => `${weight} ${size}px -apple-system, "SF Pro Text", "Helvetica Neue", Arial, sans-serif`;
  const rgb = (a) => `rgb(${a.join(",")})`;
  const clip = (text, maxW) => {
    text = String(text || "");
    if (g.measureText(text).width <= maxW) return text;
    while (text.length > 1 && g.measureText(`${text}…`).width > maxW) text = text.slice(0, -1);
    return `${text}…`;
  };
  g.fillStyle = "#fff"; g.fillRect(0, 0, W, IMG.h);
  g.textBaseline = "alphabetic";

  let y = M;
  if (index === 0) {
    g.fillStyle = rgb(MUTED); g.font = font(24, 600); g.fillText("Business Miles", M, y + 20);
    g.fillStyle = rgb(DEEP); g.font = font(46, 700); g.fillText(clip(report.title, W - 2 * M), M, y + 80);
    g.fillStyle = rgb(MUTED); g.font = font(22); g.fillText(`Kilometersatz ${fmt.euro(report.header.rate)} je km`, M, y + 116);
    const h = report.header;
    const lines = [h.name, h.company, h.address, h.taxNumber && `Steuernummer: ${h.taxNumber}`, h.vehicle && `Fahrzeug: ${h.vehicle}`].filter(Boolean);
    g.fillStyle = rgb(INK); g.font = font(22);
    lines.slice(0, 5).forEach((l, i) => g.fillText(clip(l, W - 2 * M), M, y + 156 + i * 28));
    y += 300;
  } else {
    g.fillStyle = rgb(DEEP); g.font = font(28, 700); g.fillText(clip(report.title, W - 2 * M), M, y + 30);
    y += 110;
  }

  for (const it of items) {
    if (it.type === "month") {
      g.fillStyle = rgb(SOFT); g.fillRect(M, y, W - 2 * M, 42);
      g.fillStyle = rgb(INK); g.font = font(24, 700); g.fillText(it.label, M + 14, y + 29);
      y += 50;
    } else if (it.type === "total") {
      g.fillStyle = "rgb(210,234,234)"; g.fillRect(M, y, W - 2 * M, 42);
      g.fillStyle = rgb(INK); g.font = font(23, 700); g.fillText(it.label, M + 14, y + 29);
      g.textAlign = "right"; g.fillText(`${fmt.km(it.km)}   ${fmt.euro(it.amount)}`, W - M - 14, y + 29); g.textAlign = "left";
      y += 50;
    } else {
      const r = it.r;
      g.fillStyle = rgb(INK); g.font = font(23, 600);
      g.fillText(fmt.date(r.date), M + 14, y + 30);
      g.fillText(clip(r.customer || r.destination, W - 2 * M - 460), M + 190, y + 30);
      g.textAlign = "right"; g.fillText(fmt.km(r.totalKm), W - M - 150, y + 30);
      g.font = font(21); g.fillStyle = rgb(MUTED); g.fillText(fmt.euro(r.amount), W - M - 14, y + 30); g.textAlign = "left";
      g.font = font(20); g.fillStyle = rgb(MUTED);
      const sub = [r.purpose, r.destination].filter(Boolean).join(" · ");
      g.fillText(clip(sub, W - 2 * M - 400), M + 190, y + 60);
      g.textAlign = "right";
      g.fillText(r.returnEnabled ? `hin ${fmt.num(r.outboundKm)} · zurück ${fmt.num(r.returnKm)}` : "einfache Fahrt", W - M - 14, y + 60);
      g.textAlign = "left";
      g.fillStyle = "rgb(226,231,236)"; g.fillRect(M, y + H_ROW_LINE, W - 2 * M, 1.5);
      y += 78;
    }
  }

  if (last) {
    y += 30;
    const block = [["Fahrten", String(report.tripCount)], ["Kilometer gesamt", fmt.km(report.totalKm)], ["Pauschale", fmt.euro(report.amount)]];
    block.forEach(([l, v], i) => {
      const x0 = M + i * 370;
      g.fillStyle = rgb(MUTED); g.font = font(20); g.fillText(l, x0, y + 20);
      g.fillStyle = rgb(DEEP); g.font = font(36, 700); g.fillText(v, x0, y + 62);
    });
    y += 150;
    g.fillStyle = rgb(INK);
    g.fillRect(M, y, 480, 2); g.fillRect(M + 560, y, 480, 2);
    g.fillStyle = rgb(MUTED); g.font = font(18);
    g.fillText("Ort, Datum", M, y + 26); g.fillText("Unterschrift", M + 560, y + 26);
  }

  g.fillStyle = rgb(MUTED); g.font = font(18);
  g.fillText(`Erstellt am ${fmt.date(report.createdAt)} mit Business Miles`, M, IMG.h - M + 20);
  g.textAlign = "right"; g.fillText(`Seite ${index + 1} von ${count}`, W - M, IMG.h - M + 20); g.textAlign = "left";

  return new Promise((resolve) => c.toBlob(resolve, "image/png"));
}
const H_ROW_LINE = 76;

// --- Teilen / Herunterladen ---------------------------------------------------

/** Öffnet das iOS-Teilen-Menü (Sichern in Fotos/Dateien, Mail …); sonst Download. */
export async function shareFiles(files, title) {
  if (navigator.canShare && navigator.canShare({ files })) {
    try {
      await navigator.share({ files, title });
      return "shared";
    } catch (e) {
      if (e?.name === "AbortError") return "aborted";
    }
  }
  for (const f of files) {
    const url = URL.createObjectURL(f);
    const a = document.createElement("a");
    a.href = url; a.download = f.name;
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 10000);
  }
  return "downloaded";
}
