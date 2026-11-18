// PLZ → Ort (offline), Straßenvorschläge, Geocoding und Routen-Kilometer.
// Dienste: Photon (komoot) und Nominatim für Adressen, OSRM (FOSSGIS) für Routen –
// alle auf Basis von OpenStreetMap, kostenlos und ohne Schlüssel.
import { singleLine } from "./model.js";

const GERMANY_BBOX = "5.8,47.2,15.1,55.1";
let plzTable = null;

async function plzData() {
  if (!plzTable) {
    const res = await fetch("data/plz.json");
    plzTable = await res.json();
  }
  return plzTable;
}

/** Orte zu einer fünfstelligen PLZ (meist einer, manchmal mehrere). */
export async function citiesFor(plz) {
  plz = String(plz || "").trim();
  if (!/^\d{5}$/.test(plz)) return [];
  try {
    return (await plzData())[plz] || [];
  } catch {
    return [];
  }
}

function placeCity(p) {
  return p.city || p.town || p.village || p.locality || p.district || "";
}

/** Straßenvorschläge passend zu PLZ/Ort. */
export async function suggestStreets(street, postalCode, city, signal) {
  const q = [street, postalCode, city].map((s) => String(s || "").trim()).filter(Boolean).join(" ");
  if (String(street || "").trim().length < 3) return [];
  const url = `https://photon.komoot.io/api/?q=${encodeURIComponent(q)}&lang=de&limit=10&bbox=${GERMANY_BBOX}`;
  const res = await fetch(url, { signal });
  if (!res.ok) return [];
  const data = await res.json();
  const seen = new Set();
  const out = [];
  for (const f of data.features || []) {
    const p = f.properties || {};
    if (p.countrycode && p.countrycode !== "DE") continue;
    let s = "";
    if (p.type === "street") s = p.name || "";
    else if (p.street) s = p.street + (p.housenumber ? ` ${p.housenumber}` : "");
    if (!s) continue;
    const addr = {
      street: s,
      postalCode: p.postcode || "",
      city: placeCity(p),
      lat: f.geometry?.coordinates?.[1] ?? null,
      lon: f.geometry?.coordinates?.[0] ?? null,
    };
    const key = `${addr.street}|${addr.postalCode}|${addr.city}`.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(addr);
  }
  // Treffer mit passender PLZ zuerst
  const plz = String(postalCode || "").trim();
  if (plz) out.sort((a, b) => (b.postalCode === plz) - (a.postalCode === plz));
  return out.slice(0, 6);
}

/** Koordinaten zu einer Adresse ({lat, lon}). */
export async function geocode(addr) {
  if (typeof addr.lat === "number" && typeof addr.lon === "number") return { lat: addr.lat, lon: addr.lon };
  const q = singleLine(addr);
  if (!q) throw new Error("Adresse fehlt");
  try {
    const r = await fetch(`https://photon.komoot.io/api/?q=${encodeURIComponent(q)}&lang=de&limit=1&bbox=${GERMANY_BBOX}`);
    if (r.ok) {
      const f = (await r.json()).features?.[0];
      if (f?.geometry?.coordinates) return { lat: f.geometry.coordinates[1], lon: f.geometry.coordinates[0] };
    }
  } catch { /* weiter mit Nominatim */ }
  const r = await fetch(`https://nominatim.openstreetmap.org/search?format=jsonv2&countrycodes=de&limit=1&q=${encodeURIComponent(q)}`);
  if (r.ok) {
    const hit = (await r.json())[0];
    if (hit) return { lat: Number(hit.lat), lon: Number(hit.lon) };
  }
  throw new Error(`Adresse nicht gefunden: ${q}`);
}

const ROUTERS = [
  "https://routing.openstreetmap.de/routed-car/route/v1/driving",
  "https://router.project-osrm.org/route/v1/driving",
];

/** Straßen-Kilometer (Auto), auf 0,1 km gerundet. */
export async function drivingKm(from, to) {
  const a = await geocode(from);
  const b = await geocode(to);
  let lastError = null;
  for (const base of ROUTERS) {
    try {
      const res = await fetch(`${base}/${a.lon},${a.lat};${b.lon},${b.lat}?overview=false&alternatives=false`);
      if (!res.ok) throw new Error(`Routing ${res.status}`);
      const data = await res.json();
      if (data.code === "Ok" && data.routes?.[0]) return Math.round(data.routes[0].distance / 100) / 10;
      throw new Error("Keine Route gefunden");
    } catch (e) {
      lastError = e;
    }
  }
  throw lastError || new Error("Keine Route gefunden");
}
