// Datenmodell + Zusammenführung (siehe docs/DATENFORMAT.md). Muss zur Mac-App passen.

export const VEHICLE_TYPES = {
  car: { label: "Pkw", exportLabel: "Privat-Pkw" },
  motorcycle: { label: "Motorrad / Motorroller", exportLabel: "Privates Motorrad / Motorroller" },
  custom: { label: "Sonstiges", exportLabel: "Privatfahrzeug" },
};

export const nowISO = () => new Date().toISOString();

export function emptyAddress() {
  return { name: "", street: "", postalCode: "", city: "", lat: null, lon: null };
}

export function normalizeAddress(a) {
  a = a || {};
  return {
    name: String(a.name || ""),
    street: String(a.street || ""),
    postalCode: String(a.postalCode || ""),
    city: String(a.city || ""),
    lat: typeof a.lat === "number" ? a.lat : null,
    lon: typeof a.lon === "number" ? a.lon : null,
  };
}

export function cityLine(a) {
  return [a?.postalCode, a?.city].map((s) => String(s || "").trim()).filter(Boolean).join(" ");
}

/** "Musterstraße 1, 80331 München" */
export function singleLine(a) {
  return [String(a?.street || "").trim(), cityLine(a)].filter(Boolean).join(", ");
}

/** Mit Name der Lokalität: "Café Sek Sol, Bahnhofstraße 5, 36037 Fulda" */
export function placeLine(a) {
  return [String(a?.name || "").trim(), singleLine(a)].filter(Boolean).join(", ");
}

export function isUsable(a) {
  return !!String(a?.city || "").trim() || /^\d{5}$/.test(String(a?.postalCode || "").trim());
}

export function emptySettings() {
  return {
    fullName: "", company: "", taxNumber: "",
    home: emptyAddress(),
    vehicleName: "", licensePlate: "",
    vehicleType: "car", ratePerKm: 0.30,
    updatedAt: "1970-01-01T00:00:00.000Z",
  };
}

export function normalizeSettings(s) {
  const d = emptySettings();
  s = s || {};
  return {
    fullName: String(s.fullName ?? d.fullName),
    company: String(s.company ?? d.company),
    taxNumber: String(s.taxNumber ?? d.taxNumber),
    home: normalizeAddress(s.home),
    vehicleName: String(s.vehicleName ?? ""),
    licensePlate: String(s.licensePlate ?? ""),
    vehicleType: VEHICLE_TYPES[s.vehicleType] ? s.vehicleType : "car",
    ratePerKm: typeof s.ratePerKm === "number" ? s.ratePerKm : 0.30,
    updatedAt: String(s.updatedAt || d.updatedAt),
  };
}

export function newTrip() {
  const t = nowISO();
  return {
    id: (crypto.randomUUID ? crypto.randomUUID() : fallbackUUID()),
    date: "", customer: "", purpose: "", note: "",
    destination: emptyAddress(),
    startUsesHome: true, start: emptyAddress(),
    returnEnabled: true, returnUsesHome: true, returnTo: emptyAddress(),
    outboundKm: 0, returnKm: 0, ratePerKm: null, departureTime: "", returnTime: "", kmPending: false, kmManual: false,
    source: "web", createdAt: t, updatedAt: t, deleted: false,
  };
}

function fallbackUUID() {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
  });
}

export function normalizeTrip(t) {
  const n = newTrip();
  t = t || {};
  return {
    ...n,
    id: String(t.id || n.id),
    date: /^\d{4}-\d{2}-\d{2}$/.test(t.date) ? t.date : n.date,
    customer: String(t.customer || ""),
    purpose: String(t.purpose || ""),
    note: String(t.note || ""),
    destination: normalizeAddress(t.destination),
    startUsesHome: t.startUsesHome !== false,
    start: normalizeAddress(t.start),
    returnEnabled: t.returnEnabled !== false,
    returnUsesHome: t.returnUsesHome !== false,
    returnTo: normalizeAddress(t.returnTo),
    outboundKm: Number(t.outboundKm) || 0,
    returnKm: Number(t.returnKm) || 0,
    ratePerKm: typeof t.ratePerKm === "number" && t.ratePerKm >= 0 ? t.ratePerKm : null,
    departureTime: /^\d{2}:\d{2}$/.test(t.departureTime || "") ? t.departureTime : "",
    returnTime: /^\d{2}:\d{2}$/.test(t.returnTime || "") ? t.returnTime : "",
    kmPending: t.kmPending === true && t.kmManual !== true,
    kmManual: t.kmManual === true,
    source: String(t.source || ""),
    createdAt: String(t.createdAt || n.createdAt),
    updatedAt: String(t.updatedAt || n.updatedAt),
    deleted: t.deleted === true,
  };
}

export function emptyDoc() {
  return { format: "business-miles", version: 1, updatedAt: nowISO(), settings: emptySettings(), trips: [] };
}

export function normalizeDoc(d) {
  d = d || {};
  return {
    format: "business-miles",
    version: 1,
    updatedAt: String(d.updatedAt || nowISO()),
    settings: normalizeSettings(d.settings),
    trips: Array.isArray(d.trips) ? d.trips.map(normalizeTrip) : [],
  };
}

const ts = (s) => { const v = Date.parse(s); return Number.isNaN(v) ? 0 : v; };

/** Führt zwei Stände zusammen – pro Fahrt gewinnt das jüngere updatedAt. */
export function mergeDocs(a, b) {
  a = normalizeDoc(a);
  b = normalizeDoc(b);
  const byId = new Map();
  for (const t of [...a.trips, ...b.trips]) {
    const prev = byId.get(t.id);
    if (!prev || ts(t.updatedAt) > ts(prev.updatedAt)) byId.set(t.id, t);
  }
  const settings = ts(b.settings.updatedAt) > ts(a.settings.updatedAt) ? b.settings : a.settings;
  // Feste Reihenfolge (identisch zur Mac-App): Datum → Erstellzeit → ID
  const cmp = (p, q) => (p < q ? -1 : p > q ? 1 : 0);
  const trips = [...byId.values()].sort((x, y) => cmp(x.date, y.date) || cmp(x.createdAt, y.createdAt) || cmp(x.id, y.id));
  return { format: "business-miles", version: 1, updatedAt: nowISO(), settings, trips };
}

/** Inhaltlicher Vergleich ohne den Datei-Zeitstempel. */
export function sameContent(a, b) {
  const strip = (d) => JSON.stringify({ ...normalizeDoc(d), updatedAt: "" });
  return strip(a) === strip(b);
}

// --- Berechnungen ---------------------------------------------------------

export const totalKm = (t) => (Number(t.outboundKm) || 0) + (t.returnEnabled ? Number(t.returnKm) || 0 : 0);
/** Wirksamer km-Satz: eigener Satz der Fahrt, sonst der aus den Einstellungen. */
export const tripRate = (t, defaultRate) => (typeof t.ratePerKm === "number" ? t.ratePerKm : defaultRate);
export const amount = (t, defaultRate) => Math.round(totalKm(t) * tripRate(t, defaultRate) * 100) / 100;
export const timeRange = (t) =>
  t.departureTime && t.returnTime ? `${t.departureTime}–${t.returnTime}`
    : t.departureTime ? `ab ${t.departureTime}` : t.returnTime ? `bis ${t.returnTime}` : "";
export const tripTitle = (t) =>
  t.customer.trim() || t.destination.name || t.destination.city || singleLine(t.destination) || "Fahrt";

/** Gruppiert sichtbare Fahrten nach Jahr → Monat. Das aktuelle Jahr ist immer enthalten. */
export function yearSummaries(trips) {
  const years = new Map();
  const current = new Date().getFullYear();
  years.set(current, null);
  for (const t of trips) {
    if (t.deleted || !t.date) continue;
    years.set(Number(t.date.slice(0, 4)), null);
  }
  return [...years.keys()].sort((a, b) => b - a).map((year) => {
    const months = Array.from({ length: 12 }, (_, i) => ({ month: i + 1, trips: [] }));
    for (const t of trips) {
      if (t.deleted || !t.date || Number(t.date.slice(0, 4)) !== year) continue;
      months[Number(t.date.slice(5, 7)) - 1].trips.push(t);
    }
    for (const m of months) {
      m.trips.sort((x, y) => (x.date < y.date ? 1 : x.date > y.date ? -1 : y.createdAt.localeCompare(x.createdAt)));
      m.totalKm = m.trips.reduce((s, t) => s + totalKm(t), 0);
    }
    const total = months.reduce((s, m) => s + m.totalKm, 0);
    const count = months.reduce((s, m) => s + m.trips.length, 0);
    return { year, months, totalKm: total, tripCount: count };
  });
}
