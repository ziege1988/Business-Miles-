// Tests für Zusammenführung und Excel-Export der Web-App.  Aufruf: node --test tests/
import { test } from "node:test";
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import { mergeDocs, emptyDoc, newTrip, yearSummaries, sameContent, totalKm, normalizeDoc, placeLine, tripTitle, normalizeTrip } from "../web/js/model.js";
import { buildReport, makeXlsx } from "../web/js/exports.js";
import { parseDecimal } from "../web/js/format.js";

const trip = (over) => ({ ...newTrip(), date: "2026-11-18", outboundKm: 10, returnKm: 12, ...over });

test("neuere Änderung gewinnt pro Fahrt", () => {
  const a = emptyDoc(), b = emptyDoc();
  const t = trip({ id: "1", customer: "alt", updatedAt: "2026-11-18T10:00:00.000Z" });
  a.trips.push(t);
  b.trips.push({ ...t, customer: "neu", updatedAt: "2026-11-18T11:00:00.000Z" });
  b.trips.push(trip({ id: "2", customer: "nur b" }));
  const m = mergeDocs(a, b);
  assert.equal(m.trips.length, 2);
  assert.equal(m.trips.find((x) => x.id === "1").customer, "neu");
  assert.equal(mergeDocs(b, a).trips.find((x) => x.id === "1").customer, "neu");
});

test("Löschen wird übertragen (Tombstone)", () => {
  const t = trip({ id: "x", updatedAt: "2026-11-18T10:00:00.000Z" });
  const local = { ...emptyDoc(), trips: [{ ...t, deleted: true, updatedAt: "2026-11-18T12:00:00.000Z" }] };
  const remote = { ...emptyDoc(), trips: [t] };
  const m = mergeDocs(remote, local);
  assert.equal(m.trips[0].deleted, true);
  assert.equal(yearSummaries(m.trips).find((y) => y.year === 2026).tripCount, 0);
});

test("Einstellungen: jüngerer Stand gewinnt", () => {
  const a = emptyDoc(), b = emptyDoc();
  a.settings = { ...a.settings, fullName: "A", updatedAt: "2026-01-01T00:00:00.000Z" };
  b.settings = { ...b.settings, fullName: "B", updatedAt: "2026-02-01T00:00:00.000Z" };
  assert.equal(mergeDocs(a, b).settings.fullName, "B");
  assert.equal(mergeDocs(b, a).settings.fullName, "B");
});

test("Mac-IDs in Großbuchstaben bleiben erhalten, unbekannte Felder schaden nicht", () => {
  const d = normalizeDoc({ trips: [{ id: "ABC-DEF", date: "2026-03-01", foo: 1 }], extra: true });
  assert.equal(d.trips[0].id, "ABC-DEF");
  assert.ok(sameContent(d, normalizeDoc(JSON.parse(JSON.stringify(d)))));
});

test("Summen: einfache Fahrt zählt keine Rückfahrt", () => {
  assert.equal(totalKm(trip({ returnEnabled: false })), 10);
  assert.equal(totalKm(trip()), 22);
});

test("Excel-Datei wird erzeugt", async () => {
  const trips = [
    trip({ customer: "Familie Berger & Co <Test>", purpose: "Hochzeit", date: "2026-11-18" }),
    trip({ customer: "Studio", date: "2026-11-02", returnEnabled: false }),
    trip({ customer: "Kunde Mai", date: "2026-05-07", outboundKm: 100.5, returnKm: 99.5 }),
  ];
  const summary = yearSummaries(trips).find((y) => y.year === 2026);
  const settings = { ...emptyDoc().settings, fullName: "Max Muster", taxNumber: "123/456/789", ratePerKm: 0.3,
    home: { street: "Marienplatz 1", postalCode: "80331", city: "München" } };
  const report = buildReport(summary, null, settings);
  assert.equal(report.tripCount, 3);
  assert.equal(Math.round(report.totalKm * 10) / 10, 232);
  const blob = makeXlsx(report);
  const buf = Buffer.from(await blob.arrayBuffer());
  writeFileSync(process.env.XLSX_OUT || "/tmp/bm-test.xlsx", buf);
  assert.equal(buf.readUInt32LE(0), 0x04034b50);
});

test("Lokalität: Name wird gespeichert und angezeigt", () => {
  const t = normalizeTrip({ id: "p", date: "2026-11-20", destination: { name: "Café Sek Sol", street: "Friedrichstraße 7", postalCode: "36037", city: "Fulda" } });
  assert.equal(placeLine(t.destination), "Café Sek Sol, Friedrichstraße 7, 36037 Fulda");
  assert.equal(tripTitle(t), "Café Sek Sol");
  // Mac-Datei ohne name-Feld bleibt lesbar
  assert.equal(normalizeTrip({ destination: { city: "Fulda" } }).destination.name, "");
});

test("Zahleneingabe: Komma und Punkt", () => {
  assert.equal(parseDecimal("12,5"), 12.5);
  assert.equal(parseDecimal("12.5"), 12.5);
  assert.equal(parseDecimal("1.264,8"), 1264.8);
  assert.equal(parseDecimal("0.42", { allowThousands: false }), 0.42);
  assert.equal(parseDecimal("0.425", { allowThousands: false }), 0.425);
  assert.equal(parseDecimal(""), null);
});

test("Manuelle km: nie offen, Hinweis im Export", () => {
  const t = normalizeTrip({ id: "m", date: "2026-11-20", kmManual: true, kmPending: true, outboundKm: 50, returnKm: 50, note: "Umleitung A7" });
  assert.equal(t.kmPending, false);
  const summary = yearSummaries([t]).find((y) => y.year === 2026);
  const r = buildReport(summary, null, { ...emptyDoc().settings, ratePerKm: 0.3 });
  assert.equal(r.groups[0].rows[0].note, "km manuell angepasst – Umleitung A7");
});
