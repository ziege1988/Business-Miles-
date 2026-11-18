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

export function escapeHtml(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}
