// Lokaler Speicher (offline-fähig) + Abgleich mit OneDrive.
import {
  emptyDoc, normalizeDoc, mergeDocs, sameContent, normalizeTrip, normalizeSettings, nowISO,
  isUsable, totalKm,
} from "./model.js";
import * as graph from "./graph.js";
import * as geo from "./geo.js";

const KEY = "bm.state.v1";

function readState() {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) {
      const s = JSON.parse(raw);
      return { doc: normalizeDoc(s.doc), pending: Number(s.pending) || 0, lastSyncAt: s.lastSyncAt || null };
    }
  } catch { /* leer starten */ }
  return { doc: emptyDoc(), pending: 0, lastSyncAt: null };
}

const state = readState();
const listeners = new Set();
let status = "idle";      // idle | syncing | ok | offline | login | unconfigured | error
let statusDetail = "";
let syncTimer = null;
let syncing = null;

function persist() {
  try {
    localStorage.setItem(KEY, JSON.stringify(state));
  } catch (e) {
    console.error("Lokales Speichern fehlgeschlagen", e);
  }
}

function notify() {
  for (const fn of listeners) fn();
}

function setStatus(s, detail = "") {
  status = s;
  statusDetail = detail;
  notify();
}

export const store = {
  subscribe(fn) { listeners.add(fn); return () => listeners.delete(fn); },

  get doc() { return state.doc; },
  get trips() { return state.doc.trips.filter((t) => !t.deleted); },
  get settings() { return state.doc.settings; },
  get pending() { return state.pending; },
  get lastSyncAt() { return state.lastSyncAt; },
  get status() { return status; },
  get statusDetail() { return statusDetail; },

  tripById(id) { return state.doc.trips.find((t) => t.id === id) || null; },

  upsertTrip(trip) {
    const t = normalizeTrip({ ...trip, updatedAt: nowISO() });
    const i = state.doc.trips.findIndex((x) => x.id === t.id);
    if (i >= 0) state.doc.trips[i] = t; else state.doc.trips.push(t);
    changed();
  },

  deleteTrip(id) {
    const t = this.tripById(id);
    if (!t) return;
    t.deleted = true;
    t.updatedAt = nowISO();
    changed();
  },

  /** Setzt den km-Satz für alle Fahrten eines Jahres. Ergebnis: Anzahl geänderter Fahrten. */
  applyRateToYear(year, rate) {
    let count = 0;
    const now = nowISO();
    for (const t of state.doc.trips) {
      if (t.deleted || !t.date.startsWith(`${year}-`) || t.ratePerKm === rate) continue;
      t.ratePerKm = rate;
      t.updatedAt = now;
      count++;
    }
    if (count) changed();
    return count;
  },

  updateSettings(settings) {
    state.doc.settings = normalizeSettings({ ...settings, updatedAt: nowISO() });
    changed();
  },

  /** Abgleich mit OneDrive. interactive=true darf zur Microsoft-Anmeldung weiterleiten. */
  sync(opts = {}) {
    if (!syncing) syncing = runSync(opts).finally(() => { syncing = null; });
    return syncing;
  },

  scheduleSync(delay = 1500) {
    clearTimeout(syncTimer);
    syncTimer = setTimeout(() => this.sync(), delay);
  },
};

function changed() {
  state.doc.updatedAt = nowISO();
  state.pending += 1;
  persist();
  notify();
  store.scheduleSync();
}

/** Offline erfasste Fahrten ohne km nachberechnen. */
async function resolvePendingKm(doc) {
  const home = doc.settings.home;
  let changedAny = false;
  for (const t of doc.trips) {
    if (!t.kmPending || t.deleted || t.kmManual) continue;
    const start = t.startUsesHome ? home : t.start;
    const back = t.returnUsesHome ? home : t.returnTo;
    if (!isUsable(start) || !isUsable(t.destination)) continue;
    try {
      t.outboundKm = await geo.drivingKm(start, t.destination);
      if (t.returnEnabled && isUsable(back)) t.returnKm = await geo.drivingKm(t.destination, back);
      if (t.startUsesHome) t.start = { ...home };
      if (t.returnUsesHome) t.returnTo = { ...home };
      t.kmPending = totalKm(t) <= 0;
      t.updatedAt = nowISO();
      changedAny = true;
    } catch (e) {
      console.warn("km-Nachberechnung fehlgeschlagen", e);
    }
  }
  return changedAny;
}

async function runSync({ interactive = false } = {}) {
  if (!graph.isConfigured()) return setStatus("unconfigured");
  if (!navigator.onLine) return setStatus("offline");
  if (!graph.getAccount()) return setStatus("login");

  setStatus("syncing");
  try {
    for (let attempt = 0; attempt < 4; attempt++) {
      const pendingAtStart = state.pending;
      const remote = await graph.download({ interactive });
      const merged = mergeDocs(remote.doc || emptyDoc(), state.doc);
      const resolved = await resolvePendingKm(merged);

      if (!remote.doc || resolved || !sameContent(merged, remote.doc)) {
        try {
          await graph.upload(merged, remote.etag, { interactive });
        } catch (e) {
          if (e instanceof graph.ConflictError) continue; // jemand anderes hat gerade gespeichert → neu zusammenführen
          throw e;
        }
      }
      // Änderungen, die während des Abgleichs lokal entstanden sind, nicht verlieren
      state.doc = mergeDocs(merged, state.doc);
      state.pending = Math.max(0, state.pending - pendingAtStart);
      state.lastSyncAt = nowISO();
      persist();
      setStatus("ok");
      if (state.pending > 0) store.scheduleSync(500);
      return;
    }
    throw new Error("Datei wird gerade von einem anderen Gerät bearbeitet – bitte gleich noch einmal versuchen.");
  } catch (e) {
    if (e instanceof graph.LoginRequiredError) return setStatus("login");
    if (!navigator.onLine) return setStatus("offline");
    console.error(e);
    setStatus("error", e.message || String(e));
  }
}

window.addEventListener("online", () => store.sync());
window.addEventListener("offline", () => setStatus("offline"));
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") store.sync();
});
// Solange die App offen ist: jede Minute Änderungen anderer Geräte holen
setInterval(() => {
  if (document.visibilityState === "visible" && navigator.onLine && graph.getAccount()) store.sync();
}, 60000);
