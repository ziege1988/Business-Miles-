// Deutsche Formatierung – identisch zur Mac-App.

const nf1 = new Intl.NumberFormat("de-DE", { minimumFractionDigits: 1, maximumFractionDigits: 1 });
const nfEuro = new Intl.NumberFormat("de-DE", { style: "currency", currency: "EUR" });

export const MONTHS = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli",
  "August", "September", "Oktober", "November", "Dezember"];
export const MONTHS_SHORT = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"];
const WEEKDAYS = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"];

export const num = (v) => nf1.format(Number(v) || 0);
export const km = (v) => `${num(v)} km`;
export const euro = (v) => nfEuro.format(Number(v) || 0);
export const tripCount = (n) => (n === 1 ? "1 Fahrt" : `${n} Fahrten`);

/** "2026-11-18" → { y, m, d } */
export function parseDay(s) {
  const [y, m, d] = String(s || "").split("-").map(Number);
  return { y: y || 1970, m: m || 1, d: d || 1 };
}

export function todayString() {
  const t = new Date();
  return `${t.getFullYear()}-${String(t.getMonth() + 1).padStart(2, "0")}-${String(t.getDate()).padStart(2, "0")}`;
}

/** "18.11.2026" */
export function date(s) {
  const { y, m, d } = parseDay(s);
  return `${String(d).padStart(2, "0")}.${String(m).padStart(2, "0")}.${y}`;
}

export function weekday(s) {
  const { y, m, d } = parseDay(s);
  return WEEKDAYS[new Date(y, m - 1, d).getDay()];
}

/**
 * Liest eine Zahl so, wie Menschen sie eintippen: "12,5", "12.5", "1.264,8", "1,264.8", "0.42", "45 km".
 * allowThousands=false (z. B. €/km): ein einzelner Punkt ist immer Dezimalzeichen.
 * Ergebnis: Zahl oder null (leer/ungültig).
 */
export function parseDecimal(input, { allowThousands = true } = {}) {
  let s = String(input ?? "").replace(/[^\d.,-]/g, "");
  if (!s || s === "-" ) return null;
  const lastDot = s.lastIndexOf("."), lastComma = s.lastIndexOf(",");
  if (lastDot >= 0 && lastComma >= 0) {
    // Beide vorhanden: das letzte Zeichen ist der Dezimaltrenner
    const dec = lastDot > lastComma ? "." : ",";
    const grp = dec === "." ? "," : ".";
    s = s.split(grp).join("").replace(dec, ".");
  } else if (lastComma >= 0) {
    s = s.split(".").join("").replace(/,(?=.*,)/g, "").replace(",", ".");
  } else if (lastDot >= 0) {
    // Nur Punkte: "1.264" bzw. "12.345.678" = Tausender (nur bei km), sonst Dezimalpunkt
    if (allowThousands && /^\d{1,3}(\.\d{3})+$/.test(s)) s = s.split(".").join("");
    else s = s.replace(/\.(?=.*\.)/g, "");
  }
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

export function escapeHtml(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}
