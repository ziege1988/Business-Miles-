// Business Miles – Web-App fürs iPhone.
import * as fmt from "./format.js";
import {
  newTrip, emptyAddress, normalizeAddress, singleLine, placeLine, isUsable, totalKm, amount, tripTitle,
  yearSummaries, VEHICLE_TYPES, tripRate, timeRange,
} from "./model.js";
import { store } from "./store.js";
import * as graph from "./graph.js";
import * as geo from "./geo.js";
import * as exporter from "./exports.js";

const $ = (sel, el = document) => el.querySelector(sel);
const esc = fmt.escapeHtml;
const ICON = {
  plus: '<svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>',
  house: '<svg viewBox="0 0 24 24" style="width:18px;height:18px"><path d="M3 11 12 4l9 7"/><path d="M5 10v10h14V10"/></svg>',
  map: '<svg viewBox="0 0 24 24"><path d="M9 4 3 6v14l6-2 6 2 6-2V4l-6 2-6-2Z"/><path d="M9 4v14M15 6v14"/></svg>',
  table: '<svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 10h18M9 4v16"/></svg>',
  doc: '<svg viewBox="0 0 24 24"><path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9Z"/><path d="M14 3v6h6M8 13h8M8 17h5"/></svg>',
  search: '<svg viewBox="0 0 24 24" style="width:18px;height:18px;color:var(--muted)"><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></svg>',
  photo: '<svg viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="10" r="2"/><path d="m21 16-5-5-8 8"/></svg>',
};

let selectedYear = new Date().getFullYear();

// ===========================================================================
// Hauptansicht
// ===========================================================================

function currentSummary() {
  const years = yearSummaries(store.trips);
  return years.find((y) => y.year === selectedYear) || years[0];
}

function render() {
  renderYears();
  renderMain();
  renderSyncPill();
}

function renderYears() {
  const years = yearSummaries(store.trips);
  $("#years").innerHTML = years.map((y) => `
    <button class="year-tile ${y.year === selectedYear ? "active" : ""}" data-year="${y.year}">
      <div class="y">${y.year}</div>
      <div class="k">${fmt.km(y.totalKm)}</div>
      <div class="n">${fmt.tripCount(y.tripCount)}</div>
    </button>`).join("");
}

function banners() {
  const out = [];
  if (!graph.isConfigured()) {
    out.push(`<div class="banner">OneDrive-Abgleich ist noch nicht eingerichtet. Fahrten werden vorerst nur auf diesem Gerät gespeichert.</div>`);
  } else if (!graph.getAccount()) {
    out.push(`<div class="banner">Mit Microsoft anmelden, um mit OneDrive zu synchronisieren.<button class="btn primary" data-action="login">Anmelden</button></div>`);
  }
  if (!isUsable(store.settings.home)) {
    out.push(`<div class="banner">Noch keine Startadresse hinterlegt.<button class="btn" data-action="settings">Einstellungen</button></div>`);
  }
  return out.join("");
}

function renderMain() {
  const s = currentSummary();
  const rate = store.settings.ratePerKm;
  const max = Math.max(1, ...s.months.map((m) => m.totalKm));
  const sumAmount = (list) => list.reduce((x, t) => x + amount(t, rate), 0);
  const yearAmount = s.months.reduce((x, m) => x + sumAmount(m.trips), 0);
  const active = s.months.filter((m) => m.trips.length).reverse();

  let html = banners();
  html += `<h1>Fahrten ${s.year}</h1><p class="subtitle">Kundenfahrten mit Monats- und Jahressummen</p>
    <div class="stats">
      <div class="stat hl"><div class="l">Kilometer gesamt</div><div class="v">${fmt.km(s.totalKm)}</div></div>
      <div class="stat"><div class="l">Fahrten</div><div class="v">${s.tripCount}</div></div>
      <div class="stat"><div class="l">Ø pro Fahrt</div><div class="v">${s.tripCount ? fmt.km(s.totalKm / s.tripCount) : "–"}</div></div>
      <div class="stat"><div class="l">Fahrtkosten</div><div class="v">${fmt.euro(yearAmount)}</div></div>
    </div>`;

  if (!s.tripCount) {
    html += `<div class="card empty">${ICON.map}<h3>Noch keine Fahrten in ${s.year}</h3>
      <p>Lege deine erste Kundenfahrt an – die Kilometer werden automatisch berechnet.</p>
      <button class="btn primary" data-action="new">${ICON.plus} Neue Fahrt</button></div>`;
  } else {
    html += `<div class="card chart"><h3>Kilometer pro Monat</h3><div class="bars">${s.months.map((m) => `
      <div class="bar" title="${fmt.MONTHS[m.month - 1]}: ${fmt.km(m.totalKm)}"><i style="height:${Math.round((m.totalKm / max) * 100)}%"></i><span>${fmt.MONTHS_SHORT[m.month - 1].slice(0, 1)}</span></div>`).join("")}
    </div></div>`;
    for (const m of active) {
      html += `<section class="card month">
        <div class="month-head"><h2>${fmt.MONTHS[m.month - 1]}</h2><span class="c">${fmt.tripCount(m.trips.length)}</span><span class="k">${fmt.km(m.totalKm)}</span></div>
        ${m.trips.map((t) => tripRow(t, rate)).join("")}
        <div class="month-foot"><span>Summe ${fmt.MONTHS[m.month - 1]}</span><span>${fmt.km(m.totalKm)}</span><span class="e">${fmt.euro(sumAmount(m.trips))}</span></div>
      </section>`;
    }
  }
  $("#main").innerHTML = html;
}

function tripRow(t, rate) {
  const { d } = fmt.parseDay(t.date);
  const purpose = [timeRange(t), t.purpose, !t.startUsesHome && t.start.city ? `Start: ${t.start.city}` : ""].filter(Boolean).join(" · ");
  const kmCell = t.kmPending
    ? `<span class="badge">km folgen</span>`
    : `<b>${fmt.km(totalKm(t))}</b>`;
  return `<button class="trip" data-trip="${esc(t.id)}">
    <div class="day"><small>${fmt.weekday(t.date)}</small><b>${d}</b></div>
    <div class="info"><div class="t">${esc(tripTitle(t))}</div>
      <div class="s">${esc(placeLine(t.destination))}</div>
      ${purpose ? `<div class="p">${esc(purpose)}</div>` : ""}</div>
    <div class="km">${kmCell}<small>${t.returnEnabled ? "Hin- und Rückfahrt" : "einfache Fahrt"}</small><small>${fmt.euro(amount(t, rate))}</small></div>
  </button>`;
}

function renderSyncPill() {
  const pill = $("#sync-pill");
  const n = store.pending;
  const waiting = n ? ` – ${n === 1 ? "1 Änderung wartet" : `${n} Änderungen warten`}` : "";
  const texts = {
    unconfigured: "OneDrive noch nicht eingerichtet",
    login: `Anmelden für OneDrive${waiting}`,
    offline: `Offline${waiting}`,
    syncing: "Synchronisiere …",
    ok: n ? `Wird gesichert …` : "Mit OneDrive synchronisiert",
    error: `Sync-Fehler – tippen zum Wiederholen${waiting}`,
    idle: n ? `Nicht synchronisiert${waiting}` : "OneDrive",
  };
  pill.className = `sync-pill ${store.status}`;
  pill.textContent = texts[store.status] || "OneDrive";
  pill.title = store.statusDetail || "";
}

// ===========================================================================
// Hilfen: Toast, Sheets
// ===========================================================================

let toastTimer = null;
function toast(msg, ms = 2600) {
  const el = $("#toast");
  el.textContent = msg;
  el.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove("show"), ms);
}

/** Öffnet ein Sheet mit frischem Inhalt. Rückgabe ist ein neuer Container – Event-Handler
 *  hängen daran und verschwinden beim Schließen mit ihm (keine doppelten Handler). */
function openSheet(id, html) {
  const host = $(id);
  const el = document.createElement("div");
  el.innerHTML = html;
  host.replaceChildren(el);
  host.hidden = false;
  host.scrollTop = 0;
  document.body.classList.add("locked");
  return el;
}

function closeSheet(id) {
  $(id).hidden = true;
  $(id).replaceChildren();
  if (![...document.querySelectorAll(".sheet")].some((s) => !s.hidden)) document.body.classList.remove("locked");
}

const parseKm = (v) => {
  const n = fmt.parseDecimal(v, { allowThousands: true });
  return n !== null && n > 0 ? Math.round(n * 10) / 10 : 0;
};
const kmInput = (v) => (v ? fmt.num(v) : "");
const fmtRate = (v) => (Number(v) || 0).toFixed(2).replace(".", ",");
/** "0,35" → 0.35; leer/ungültig → Standard */
const parseRate = (v, fallback) => {
  const n = fmt.parseDecimal(v, { allowThousands: false });
  return n !== null && n >= 0 ? Math.round(n * 1000) / 1000 : fallback;
};

// ===========================================================================
// Adressfeld mit PLZ → Ort und Straßenvorschlägen
// ===========================================================================

function addressField(host, initial, onChange, opts = {}) {
  let addr = normalizeAddress(initial);
  let cityAuto = false;
  let abort = null;
  let timer = null;
  const withPlaces = Boolean(opts.placeSearch);

  host.innerHTML = `
    ${withPlaces ? `
    <div class="fields place-search"><div class="field">${ICON.search}
      <input class="a-search" type="search" enterkeyhint="search" autocomplete="off"
        placeholder="Lokalität oder Adresse suchen, z. B. Café Fulda"></div></div>
    <ul class="suggestions a-psugg" hidden></ul>` : ""}
    <div class="fields">
      ${withPlaces ? `<div class="field"><input class="a-name" placeholder="Lokalität / Firma (optional)" autocomplete="off"></div>` : ""}
      <div class="row-split">
        <div class="field plz"><input class="a-plz" inputmode="numeric" maxlength="5" placeholder="PLZ" autocomplete="postal-code"></div>
        <div class="field"><input class="a-city" placeholder="Ort" autocomplete="address-level2"></div>
      </div>
      <div class="field"><input class="a-street" placeholder="Straße und Hausnummer" autocomplete="address-line1"></div>
    </div>
    <div class="chips a-cities" hidden></div>
    <ul class="suggestions a-sugg" hidden></ul>`;
  const plz = $(".a-plz", host), city = $(".a-city", host), street = $(".a-street", host);
  const cities = $(".a-cities", host), sugg = $(".a-sugg", host);

  const nameInput = $(".a-name", host);
  const fill = () => {
    plz.value = addr.postalCode; city.value = addr.city; street.value = addr.street;
    if (nameInput) nameInput.value = addr.name || "";
  };
  fill();
  const changed = () => onChange && onChange();
  const clearCoords = () => { addr.lat = null; addr.lon = null; };

  // --- Freie Suche nach Lokalitäten („Café Sek Sol Fulda“) ---
  if (withPlaces) {
    const search = $(".a-search", host), psugg = $(".a-psugg", host);
    let pAbort = null, pTimer = null;
    search.addEventListener("input", () => {
      clearTimeout(pTimer);
      const query = search.value.trim();
      if (query.length < 3) { psugg.hidden = true; return; }
      pTimer = setTimeout(async () => {
        if (pAbort) pAbort.abort();
        pAbort = new AbortController();
        try {
          const list = await geo.searchPlaces(query, store.settings.home, pAbort.signal);
          if (document.activeElement !== search) return;
          psugg.innerHTML = list.length
            ? list.map((p, i) => `<li><button type="button" data-p="${i}"><b>${esc(p.name || p.street || p.city)}</b>
                <small>${esc([p.category, p.name ? p.street : "", [p.postalCode, p.city].filter(Boolean).join(" ")].filter(Boolean).join(" · "))}</small></button></li>`).join("")
            : `<li><button type="button" disabled><small>Nichts gefunden – Adresse unten von Hand eingeben.</small></button></li>`;
          psugg.hidden = false;
          psugg._list = list;
        } catch {
          if (!navigator.onLine) {
            psugg.innerHTML = `<li><button type="button" disabled><small>Offline – Suche nicht möglich.</small></button></li>`;
            psugg.hidden = false;
          }
        }
      }, 350);
    });
    psugg.addEventListener("pointerdown", (e) => {
      const b = e.target.closest("[data-p]");
      if (!b) return;
      e.preventDefault();
      const p = psugg._list[Number(b.dataset.p)];
      addr = normalizeAddress({ name: p.name, street: p.street, postalCode: p.postalCode, city: p.city, lat: p.lat, lon: p.lon });
      cityAuto = false;
      fill();
      search.value = "";
      psugg.hidden = true;
      search.blur();
      changed();
    });
    search.addEventListener("blur", () => setTimeout(() => { psugg.hidden = true; }, 150));
    nameInput.addEventListener("input", () => { addr.name = nameInput.value; changed(); });
  }

  plz.addEventListener("input", async () => {
    plz.value = plz.value.replace(/\D/g, "").slice(0, 5);
    addr.postalCode = plz.value;
    clearCoords();
    cities.hidden = true;
    if (plz.value.length === 5) {
      const list = await geo.citiesFor(plz.value);
      if (list.length && (!addr.city || cityAuto)) {
        addr.city = list[0];
        city.value = list[0];
        cityAuto = true;
      }
      if (list.length > 1) {
        cities.innerHTML = list.map((c) => `<button type="button" class="chip" data-city="${esc(c)}"><b>${esc(c)}</b></button>`).join("");
        cities.hidden = false;
      }
    }
    changed();
  });
  cities.addEventListener("click", (e) => {
    const b = e.target.closest("[data-city]");
    if (!b) return;
    addr.city = b.dataset.city; city.value = addr.city; cityAuto = true; clearCoords();
    cities.hidden = true;
    changed();
  });
  city.addEventListener("input", () => { addr.city = city.value; cityAuto = false; clearCoords(); changed(); });

  street.addEventListener("input", () => {
    addr.street = street.value;
    clearCoords();
    changed();
    clearTimeout(timer);
    timer = setTimeout(async () => {
      if (abort) abort.abort();
      abort = new AbortController();
      try {
        const list = await geo.suggestStreets(addr.street, addr.postalCode, addr.city, abort.signal);
        if (document.activeElement !== street) return;
        sugg.innerHTML = list.map((s, i) => `<li><button type="button" data-i="${i}"><b>${esc(s.street)}</b><small>${esc([s.postalCode, s.city].filter(Boolean).join(" "))}</small></button></li>`).join("");
        sugg.hidden = !list.length;
        sugg._list = list;
      } catch { /* offline oder abgebrochen */ }
    }, 300);
  });
  // pointerdown statt click, damit die Auswahl vor dem blur des Eingabefelds greift
  sugg.addEventListener("pointerdown", (e) => {
    const b = e.target.closest("[data-i]");
    if (!b) return;
    e.preventDefault();
    const s = sugg._list[Number(b.dataset.i)];
    addr = { ...addr, ...s, postalCode: s.postalCode || addr.postalCode, city: s.city || addr.city };
    cityAuto = false;
    fill();
    sugg.hidden = true;
    cities.hidden = true;
    street.blur();
    changed();
  });
  street.addEventListener("blur", () => setTimeout(() => { sugg.hidden = true; }, 150));

  return {
    get: () => ({ ...addr, name: nameInput ? nameInput.value.trim() : addr.name, street: street.value.trim(), postalCode: plz.value.trim(), city: city.value.trim() }),
    set: (value) => { addr = normalizeAddress(value); cityAuto = false; fill(); cities.hidden = true; sugg.hidden = true; changed(); },
  };
}

// ===========================================================================
// Fahrt-Editor
// ===========================================================================

function openEditor(mode, source) {
  const home = () => store.settings.home;
  const t = mode === "new" ? newTrip() : JSON.parse(JSON.stringify(source));
  if (mode === "new") t.date = fmt.todayString();
  if (mode === "duplicate") {
    const fresh = newTrip();
    Object.assign(t, { id: fresh.id, createdAt: fresh.createdAt, date: fmt.todayString(), note: "", deleted: false });
  }
  const editing = mode === "edit";

  const recent = [];
  const seen = new Set();
  for (const r of [...store.trips].sort((a, b) => (a.date < b.date ? 1 : -1))) {
    const k = singleLine(r.destination).toLowerCase();
    if (!k || seen.has(k)) continue;
    seen.add(k); recent.push(r);
    if (recent.length === 8) break;
  }

  const el = openSheet("#sheet-editor", `
    <div class="sheet-head"><button class="link" data-x="cancel">Abbrechen</button><h2>${editing ? "Fahrt bearbeiten" : "Neue Fahrt"}</h2><button class="link" data-x="save">Sichern</button></div>
    <div class="sheet-body">
      <div class="group"><label>Datum</label><div class="fields">
        <div class="field"><input type="date" class="e-date" required></div>
        <div class="field"><span>Uhrzeiten angeben</span><label class="switch"><input type="checkbox" class="e-times"><i></i></label></div>
        <div class="field e-time-row"><span>Abfahrt</span><input type="time" class="e-dep" style="text-align:right"></div>
        <div class="field e-time-row"><span>Rückkehr</span><input type="time" class="e-ret-time" style="text-align:right"></div>
      </div><p class="hint">Uhrzeiten sind optional – sinnvoll z. B. für den Verpflegungsmehraufwand (Abwesenheit über 8 Stunden).</p></div>
      <div class="group"><label>Kunde &amp; Anlass</label><div class="fields">
        <div class="field"><input class="e-customer" placeholder="Kunde / Geschäftspartner" autocomplete="off"></div>
        <div class="field"><input class="e-purpose" placeholder="Anlass (z. B. Fotoshooting, Besprechung)" autocomplete="off"></div>
      </div></div>
      <div class="group"><label>Zieladresse</label>
        ${!editing && recent.length ? `<div class="chips e-recent">${recent.map((r) => `<button type="button" class="chip" data-recent="${esc(r.id)}"><b>${esc(tripTitle(r))}</b><small>${esc(r.destination.city)}</small></button>`).join("")}</div>` : ""}
        <div class="e-dest"></div>
        <p class="hint">Lokalität suchen (z. B. „Café Sek Sol Fulda“) – Name und Adresse werden komplett übernommen. Oder PLZ eingeben, der Ort wird ergänzt.</p>
      </div>
      <div class="group"><label>Start</label>
        <div class="segmented e-startseg"><button type="button" data-v="home">Startadresse</button><button type="button" data-v="other">Andere Adresse</button></div>
        <div class="e-start-home"></div><div class="e-start"></div>
      </div>
      <div class="group"><label>Rückfahrt</label>
        <div class="fields"><div class="field"><span>Hin- und Rückfahrt</span><label class="switch"><input type="checkbox" class="e-return"><i></i></label></div></div>
        <div class="e-return-box">
          <div class="segmented e-retseg"><button type="button" data-v="home">Zur Startadresse</button><button type="button" data-v="other">Andere Adresse</button></div>
          <div class="e-ret"></div>
        </div>
      </div>
      <div class="group"><label>Strecke</label><div class="fields">
        <div class="field"><span>Kilometer manuell anpassen<br><small class="unit">z. B. Umleitung wegen Unfall</small></span><label class="switch"><input type="checkbox" class="e-manual"><i></i></label></div>
        <div class="field"><span>Hinfahrt</span><input class="num e-out" inputmode="decimal" placeholder="0,0" style="margin-left:auto"><span class="unit">km</span></div>
        <div class="field e-back-row"><span>Rückfahrt</span><input class="num e-back" inputmode="decimal" placeholder="0,0" style="margin-left:auto"><span class="unit">km</span></div>
        <div class="total-line"><span>Gesamt</span><span class="e-total"></span></div>
        <div class="field e-total-row"><span><b>Gesamt</b></span><input class="num e-total-in" inputmode="decimal" placeholder="0,0" style="margin-left:auto;font-weight:700"><span class="unit">km</span></div>
        <div class="muted-line e-ref" hidden></div>
        <div class="field"><span>Kilometersatz</span><input class="num e-rate-in" inputmode="decimal" style="margin-left:auto"><span class="unit">€/km</span></div>
        <div class="total-line"><span>Fahrtkosten</span><span class="e-amount"></span></div>
        <div class="calc e-calc"></div>
      </div>
      <p class="hint">Die Kilometer werden automatisch berechnet (OpenStreetMap, Auto) und können überschrieben werden. Offline erfasste Fahrten werden nachberechnet, sobald wieder Internet da ist.</p></div>
      <div class="group"><label>Notiz (optional)</label><div class="fields"><div class="field"><textarea class="e-note" rows="2"></textarea></div></div></div>
      ${editing ? `<div class="group"><button class="btn danger" data-x="delete">Fahrt löschen</button></div>` : ""}
    </div>`);

  const q = (s) => $(s, el);
  q(".e-date").value = t.date;
  q(".e-customer").value = t.customer;
  q(".e-purpose").value = t.purpose;
  q(".e-note").value = t.note;
  q(".e-return").checked = t.returnEnabled;
  q(".e-manual").checked = t.kmManual;
  let lastCalc = null; // { out, back } laut Routenberechnung
  q(".e-out").value = kmInput(t.outboundKm);
  q(".e-back").value = kmInput(t.returnKm);
  q(".e-rate-in").value = fmtRate(tripRate(t, store.settings.ratePerKm));
  q(".e-times").checked = Boolean(t.departureTime || t.returnTime);
  q(".e-dep").value = t.departureTime || "08:00";
  q(".e-ret-time").value = t.returnTime || "17:00";

  let startHome = t.startUsesHome;
  let returnHome = t.returnUsesHome;
  let calcSeq = 0;
  let calcTimer = null;

  const dest = addressField(q(".e-dest"), t.destination, () => scheduleCalc(), { placeSearch: true });
  const startField = addressField(q(".e-start"), t.startUsesHome ? emptyAddress() : t.start, () => scheduleCalc());
  const retField = addressField(q(".e-ret"), t.returnUsesHome ? emptyAddress() : t.returnTo, () => scheduleCalc());

  const effStart = () => (startHome ? home() : startField.get());
  const effReturn = () => (returnHome ? home() : retField.get());
  const routeKey = () => JSON.stringify([singleLine(effStart()), singleLine(dest.get()), q(".e-return").checked, singleLine(effReturn())]);
  const initialKey = mode === "new" ? null : routeKey();

  function updateUI() {
    if (!el.isConnected) return;
    for (const b of q(".e-startseg").children) b.classList.toggle("on", (b.dataset.v === "home") === startHome);
    for (const b of q(".e-retseg").children) b.classList.toggle("on", (b.dataset.v === "home") === returnHome);
    q(".e-start").hidden = startHome;
    q(".e-ret").hidden = returnHome;
    const h = home();
    q(".e-start-home").innerHTML = !startHome ? "" : isUsable(h)
      ? `<div class="home-line">${ICON.house} ${esc(singleLine(h))}</div>`
      : `<div class="warn">Noch keine Startadresse hinterlegt. <button class="link" data-x="settings">In den Einstellungen hinterlegen …</button></div>`;
    const ret = q(".e-return").checked;
    q(".e-return-box").hidden = !ret;
    q(".e-back-row").hidden = !ret;
    const total = parseKm(q(".e-out").value) + (ret ? parseKm(q(".e-back").value) : 0);
    const rate = parseRate(q(".e-rate-in").value, store.settings.ratePerKm);
    const manual = q(".e-manual").checked;
    q(".e-total").textContent = fmt.km(total);
    q(".e-total").parentElement.hidden = manual;
    q(".e-total-row").hidden = !manual;
    if (manual && document.activeElement !== q(".e-total-in")) q(".e-total-in").value = kmInput(total);
    const ref = q(".e-ref");
    if (manual && lastCalc) {
      const calcTotal = lastCalc.out + (ret ? lastCalc.back : 0);
      ref.innerHTML = `<span>Laut Routenberechnung</span><span>${fmt.km(calcTotal)}</span>`;
      ref.hidden = false;
    } else ref.hidden = true;
    q(".e-amount").textContent = fmt.euro(Math.round(total * rate * 100) / 100);
    for (const row of el.querySelectorAll(".e-time-row")) row.hidden = !q(".e-times").checked;
  }

  function setCalc(state, msg = "") {
    const box = q(".e-calc");
    if (state === "busy") box.innerHTML = `<span class="spinner"></span> Route wird berechnet …`;
    else if (state === "error") box.innerHTML = `<span class="warn">${esc(msg)}</span>`;
    else if (state === "offline") box.innerHTML = `<span class="warn">Offline – die Kilometer werden nachberechnet, sobald wieder Internet da ist.</span>`;
    else box.innerHTML = `<button class="link" data-x="recalc">↻ Kilometer neu berechnen</button>`;
  }

  function scheduleCalc() {
    updateUI();
    clearTimeout(calcTimer);
    calcTimer = setTimeout(() => { if (el.isConnected) recalc(false); }, 800);
  }

  async function recalc(force) {
    if (!el.isConnected) return;
    const key = routeKey();
    if (!force && key === initialKey) return;
    const d = dest.get(), s = effStart(), r = effReturn(), withReturn = q(".e-return").checked;
    if (!isUsable(d)) return setCalc("idle");
    if (!isUsable(s)) return setCalc("error", "Bitte eine Startadresse angeben.");
    if (withReturn && !isUsable(r)) return setCalc("error", "Bitte eine Adresse für die Rückfahrt angeben.");
    if (!navigator.onLine) return setCalc("offline");
    const seq = ++calcSeq;
    setCalc("busy");
    try {
      const out = await geo.drivingKm(s, d);
      const back = withReturn ? await geo.drivingKm(d, r) : 0;
      if (seq !== calcSeq || !el.isConnected) return;
      lastCalc = { out, back };
      // Manuell angepasste km nur auf ausdrücklichen Wunsch („neu berechnen“) überschreiben
      if (!q(".e-manual").checked) {
        q(".e-out").value = kmInput(out);
        if (withReturn) q(".e-back").value = kmInput(back);
      }
      setCalc("idle");
      updateUI();
    } catch (e) {
      if (seq !== calcSeq) return;
      setCalc(navigator.onLine ? "error" : "offline", `${e.message || e}. Bitte km manuell eintragen.`);
    }
  }

  function save() {
    const d = dest.get();
    if (!isUsable(d)) { toast("Bitte eine Zieladresse (mindestens PLZ oder Ort) angeben."); return; }
    const ret = q(".e-return").checked;
    t.date = q(".e-date").value || fmt.todayString();
    t.customer = q(".e-customer").value.trim();
    t.purpose = q(".e-purpose").value.trim();
    t.note = q(".e-note").value.trim();
    t.destination = d;
    t.startUsesHome = startHome;
    t.start = startHome ? { ...home() } : startField.get();
    t.returnEnabled = ret;
    t.returnUsesHome = returnHome;
    t.returnTo = ret ? (returnHome ? { ...home() } : retField.get()) : emptyAddress();
    t.outboundKm = parseKm(q(".e-out").value);
    t.returnKm = ret ? parseKm(q(".e-back").value) : 0;
    t.kmManual = q(".e-manual").checked;
    t.kmPending = !t.kmManual && totalKm(t) <= 0;
    t.ratePerKm = parseRate(q(".e-rate-in").value, store.settings.ratePerKm);
    const times = q(".e-times").checked;
    t.departureTime = times ? q(".e-dep").value : "";
    t.returnTime = times ? q(".e-ret-time").value : "";
    t.source = "web";
    store.upsertTrip(t);
    selectedYear = Number(t.date.slice(0, 4));
    closeSheet("#sheet-editor");
    render();
    toast(t.kmPending ? "Gespeichert – km werden nachberechnet." : "Fahrt gespeichert.");
  }

  el.addEventListener("click", (e) => {
    const x = e.target.closest("[data-x]")?.dataset.x;
    if (x === "cancel") closeSheet("#sheet-editor");
    else if (x === "save") save();
    else if (x === "recalc") {
      q(".e-manual").checked = false;  // „neu berechnen“ = wieder automatisch
      updateUI();
      recalc(true);
    }
    else if (x === "settings") openSettings();
    else if (x === "delete") {
      if (confirm(`Fahrt „${tripTitle(t)}“ vom ${fmt.date(t.date)} löschen?`)) {
        store.deleteTrip(t.id);
        closeSheet("#sheet-editor");
        render();
        toast("Fahrt gelöscht.");
      }
    }
    const seg = e.target.closest(".segmented button");
    if (seg) {
      if (seg.parentElement.classList.contains("e-startseg")) startHome = seg.dataset.v === "home";
      else returnHome = seg.dataset.v === "home";
      scheduleCalc();
    }
    const rec = e.target.closest("[data-recent]");
    if (rec) {
      const r = store.tripById(rec.dataset.recent);
      if (r) {
        dest.set(r.destination);
        if (!q(".e-customer").value) q(".e-customer").value = r.customer;
        if (!q(".e-purpose").value) q(".e-purpose").value = r.purpose;
        q(".e-recent").hidden = true;
        scheduleCalc();
      }
    }
  });
  q(".e-return").addEventListener("change", scheduleCalc);
  // Wer km von Hand ändert, schaltet automatisch auf „manuell“ – die Automatik überschreibt dann nichts mehr
  const markManual = () => { if (!q(".e-manual").checked) q(".e-manual").checked = true; updateUI(); };
  q(".e-out").addEventListener("input", markManual);
  q(".e-back").addEventListener("input", markManual);
  q(".e-manual").addEventListener("change", () => {
    updateUI();
    if (!q(".e-manual").checked) recalc(true);
  });
  // Gesamt-km eingeben → auf Hin- und Rückfahrt aufteilen
  q(".e-total-in").addEventListener("input", () => {
    const total = parseKm(q(".e-total-in").value);
    if (q(".e-return").checked) {
      const out = Math.round((total / 2) * 10) / 10;
      q(".e-out").value = kmInput(out);
      q(".e-back").value = kmInput(Math.round((total - out) * 10) / 10);
    } else {
      q(".e-out").value = kmInput(total);
    }
    updateUI();
  });
  q(".e-total-in").addEventListener("blur", () => { q(".e-total-in").value = kmInput(parseKm(q(".e-total-in").value)); });
  q(".e-rate-in").addEventListener("input", updateUI);
  q(".e-rate-in").addEventListener("blur", () => { q(".e-rate-in").value = fmtRate(parseRate(q(".e-rate-in").value, store.settings.ratePerKm)); });
  q(".e-times").addEventListener("change", updateUI);
  q(".e-out").addEventListener("blur", () => { q(".e-out").value = kmInput(parseKm(q(".e-out").value)); });
  q(".e-back").addEventListener("blur", () => { q(".e-back").value = kmInput(parseKm(q(".e-back").value)); });

  updateUI();
  setCalc("idle");
  if (!editing) setTimeout(() => q(".e-customer").focus(), 300);
}

// ===========================================================================
// Einstellungen
// ===========================================================================

function openSettings() {
  const s = JSON.parse(JSON.stringify(store.settings));
  const account = graph.getAccount();
  const el = openSheet("#sheet-settings", `
    <div class="sheet-head"><button class="link" data-x="cancel">Abbrechen</button><h2>Einstellungen</h2><button class="link" data-x="save">Fertig</button></div>
    <div class="sheet-body">
      <div class="group"><label>Startadresse</label><div class="s-home"></div>
        <p class="hint">Wird bei jeder neuen Fahrt als Start und Ziel der Rückfahrt vorausgewählt und erscheint als Anschrift im Export.</p></div>
      <div class="group"><label>Angaben für die Steuer</label><div class="fields">
        <div class="field"><input class="s-name" placeholder="Name" autocomplete="name"></div>
        <div class="field"><input class="s-company" placeholder="Firma (optional)" autocomplete="organization"></div>
        <div class="field"><input class="s-tax" placeholder="Steuernummer"></div>
      </div><p class="hint">Diese Angaben stehen im Kopf der exportierten Liste.</p></div>
      <div class="group"><label>Fahrzeug &amp; Kilometerpauschale</label><div class="fields">
        <div class="field"><input class="s-vehicle" placeholder="Fahrzeug (z. B. VW Golf)"></div>
        <div class="field"><input class="s-plate" placeholder="Kennzeichen" autocapitalize="characters"></div>
        <div class="field"><span>Fahrzeugart</span><select class="s-type" style="text-align:right">${Object.entries(VEHICLE_TYPES).map(([k, v]) => `<option value="${k}">${v.label}</option>`).join("")}</select></div>
        <div class="field"><span>Kilometersatz</span><input class="num s-rate" inputmode="decimal" style="margin-left:auto"><span class="unit">€/km</span></div>
      </div><p class="hint">Dein Kilometersatz wird bei jeder neuen Fahrt verwendet – unabhängig von der Fahrzeugart. Bereits erfasste Fahrten behalten ihren Satz (in der jeweiligen Fahrt änderbar). Zum Vergleich: Die gesetzliche Pauschale beträgt 0,30 € (Pkw) bzw. 0,20 € (Motorrad).</p></div>
      <div class="group"><label>OneDrive</label><div class="fields">
        <div class="field"><span>Datei</span><span class="unit" style="margin-left:auto">Business-Miles › business-miles.json</span></div>
        <div class="field"><span>Konto</span><span class="unit" style="margin-left:auto">${graph.isConfigured() ? esc(account?.username || "nicht angemeldet") : "nicht eingerichtet"}</span></div>
        <div class="field"><span>Letzter Abgleich</span><span class="unit" style="margin-left:auto">${store.lastSyncAt ? new Date(store.lastSyncAt).toLocaleString("de-DE", { dateStyle: "short", timeStyle: "short" }) : "–"}</span></div>
        <div class="field">${graph.isConfigured()
          ? (account
            ? `<button class="link" data-x="sync">Jetzt synchronisieren</button><button class="link" data-x="logout" style="margin-left:auto;color:var(--danger)">Abmelden</button>`
            : `<button class="link" data-x="login">Mit Microsoft anmelden</button>`)
          : `<span class="unit">Siehe Anleitung (README) zur Einrichtung.</span>`}</div>
      </div></div>
      <div class="group"><label>Kilometersatz auf Fahrten übernehmen</label><div class="fields">
        <div class="field"><span>Jahr</span><select class="s-apply-year" style="margin-left:auto;text-align:right">${yearSummaries(store.trips).filter((y) => y.tripCount).map((y) => `<option value="${y.year}">${y.year} (${fmt.tripCount(y.tripCount)})</option>`).join("") || `<option value="">keine Fahrten</option>`}</select></div>
        <div class="field"><button class="link" data-x="apply-rate">Aktuellen Satz auf alle Fahrten dieses Jahres übernehmen</button></div>
      </div><p class="hint">Korrigiert z. B. einen falsch eingetragenen Satz. Verwendet wird der oben eingetragene Kilometersatz; die Beträge aller Fahrten des Jahres werden neu berechnet.</p></div>
      <div class="group"><label>Version &amp; Updates</label><div class="fields">
        <div class="field"><span>Installiert</span><span class="unit" style="margin-left:auto">Version ${esc(window.BM_VERSION ?? "?")} · ${esc(fmt.date(window.BM_RELEASED || ""))}</span></div>
        <div class="field"><button class="link" data-x="update">Nach Updates suchen</button><span class="unit s-update-state" style="margin-left:auto"></span></div>
      </div>
      ${(window.BM_CHANGES || []).length ? `<p class="hint"><b>Neu in dieser Version:</b><br>${window.BM_CHANGES.map((c) => `• ${esc(c)}`).join("<br>")}</p>` : ""}
      </div>
      <p class="hint" style="text-align:center">PLZ-Daten © OpenStreetMap-Mitwirkende (ODbL) · Routen: OSRM / FOSSGIS · Adressen: Photon / Nominatim</p>
    </div>`);
  const q = (sel) => $(sel, el);
  const homeField = addressField(q(".s-home"), s.home, null);
  q(".s-name").value = s.fullName;
  q(".s-company").value = s.company;
  q(".s-tax").value = s.taxNumber;
  q(".s-vehicle").value = s.vehicleName;
  q(".s-plate").value = s.licensePlate;
  q(".s-type").value = s.vehicleType;
  q(".s-rate").value = fmtRate(s.ratePerKm);
  q(".s-rate").addEventListener("blur", () => { q(".s-rate").value = fmtRate(parseRate(q(".s-rate").value, s.ratePerKm)); });

  el.addEventListener("click", async (e) => {
    const x = e.target.closest("[data-x]")?.dataset.x;
    if (x === "cancel") closeSheet("#sheet-settings");
    if (x === "save") {
      const rate = parseRate(q(".s-rate").value, NaN);
      store.updateSettings({
        ...s,
        home: homeField.get(),
        fullName: q(".s-name").value.trim(),
        company: q(".s-company").value.trim(),
        taxNumber: q(".s-tax").value.trim(),
        vehicleName: q(".s-vehicle").value.trim(),
        licensePlate: q(".s-plate").value.trim(),
        vehicleType: q(".s-type").value,
        ratePerKm: Number.isFinite(rate) ? rate : s.ratePerKm,
      });
      closeSheet("#sheet-settings");
      render();
      // Falls der Editor offen ist: Startadresse dort aktualisieren
      if (!$("#sheet-editor").hidden) $("#sheet-editor .e-startseg button.on")?.click();
      toast("Einstellungen gespeichert.");
    }
    if (x === "login") graph.login();
    if (x === "logout") graph.logout();
    if (x === "sync") { closeSheet("#sheet-settings"); store.sync({ interactive: true }); }
    if (x === "update") checkForUpdate(q(".s-update-state"));
    if (x === "apply-rate") {
      const year = Number(q(".s-apply-year").value);
      const rate = parseRate(q(".s-rate").value, NaN);
      if (!year || !Number.isFinite(rate)) return toast("Bitte Jahr und Kilometersatz prüfen.");
      if (!confirm(`Kilometersatz ${fmt.euro(rate)} je km auf alle Fahrten ${year} übernehmen?`)) return;
      // Satz zuerst als Standard speichern, dann auf das Jahr anwenden
      store.updateSettings({ ...store.settings, ratePerKm: rate });
      const n = store.applyRateToYear(year, rate);
      render();
      toast(n ? `${fmt.tripCount(n)} ${year} aktualisiert.` : `Alle Fahrten ${year} hatten bereits diesen Satz.`);
    }
  });
}

/** Lädt eine neue Fassung der Web-App, falls vorhanden, und startet neu. */
async function checkForUpdate(label) {
  const say = (t) => { if (label) label.textContent = t; };
  if (!navigator.onLine) return say("Offline");
  say("Suche …");
  try {
    const res = await fetch(`version.js?t=${Date.now()}`, { cache: "no-store" });
    const text = await res.text();
    const latest = Number((text.match(/BM_VERSION\s*=\s*(\d+)/) || [])[1] || 0);
    if (latest > Number(window.BM_VERSION || 0)) {
      say(`Version ${latest} wird geladen …`);
      const reg = await navigator.serviceWorker?.getRegistration();
      if (reg) {
        await reg.update();
        const sw = reg.installing || reg.waiting;
        if (sw && sw.state !== "activated") {
          await new Promise((resolve) => {
            sw.addEventListener("statechange", () => sw.state === "activated" && resolve());
            setTimeout(resolve, 8000);
          });
        }
      }
      location.reload();
    } else {
      say("Neueste Version ✓");
    }
  } catch {
    say("Nicht erreichbar");
  }
}

// ===========================================================================
// Export
// ===========================================================================

function openExport() {
  const s = currentSummary();
  const months = s.months.filter((m) => m.trips.length);
  const el = openSheet("#sheet-export", `
    <div class="sheet-head"><span></span><h2>Exportieren</h2><button class="link" data-x="close">Fertig</button></div>
    <div class="sheet-body">
      <div class="group"><label>Zeitraum</label><div class="fields">
        <div class="field"><select class="x-scope"><option value="0">Gesamtes Jahr ${s.year}</option>
          ${months.map((m) => `<option value="${m.month}">${fmt.MONTHS[m.month - 1]} ${s.year}</option>`).join("")}</select></div>
        <div class="field"><span class="unit x-info"></span></div>
      </div></div>
      <div class="group"><label>Seitenformat (PDF &amp; Excel)</label>
        <div class="segmented x-orient"><button type="button" data-v="landscape">Querformat</button><button type="button" data-v="portrait">Hochformat</button></div>
      </div>
      <div class="group"><label>Format</label><div class="fields">
        <button class="export-btn" data-x="xlsx"><span class="ic">${ICON.table}</span><span><b>Excel</b><small>Bearbeitbare Tabelle (.xlsx) mit Monatssummen</small></span></button>
        <button class="export-btn" data-x="pdf"><span class="ic">${ICON.doc}</span><span><b>PDF</b><small class="x-pdf-sub">Druckfertige Aufstellung (A4 quer)</small></span></button>
        <button class="export-btn" data-x="png"><span class="ic">${ICON.photo}</span><span><b>Bild für die Galerie</b><small>Jede Seite als Bild – in Fotos sichern</small></span></button>
      </div><p class="hint">Nach dem Erstellen öffnet „Teilen / Sichern“ das iPhone-Menü: „In Dateien sichern“, „Bilder sichern“ oder z. B. per Mail an die Steuerberatung.</p></div>
      <div class="group x-ready" hidden></div>
    </div>`);
  const q = (sel) => $(sel, el);
  let files = null;

  let portrait = false;
  try { portrait = localStorage.getItem("bm.exportPortrait") === "1"; } catch { /* egal */ }
  const report = () => {
    const r = exporter.buildReport(s, Number(q(".x-scope").value) || null, store.settings);
    r.portrait = portrait;
    return r;
  };
  const updateOrientation = () => {
    for (const b of q(".x-orient").children) b.classList.toggle("on", (b.dataset.v === "portrait") === portrait);
    q(".x-pdf-sub").textContent = portrait ? "Druckfertige Aufstellung (A4 hoch)" : "Druckfertige Aufstellung (A4 quer)";
  };
  const info = () => {
    const r = report();
    q(".x-info").textContent = `${fmt.tripCount(r.tripCount)} · ${fmt.km(r.totalKm)} · ${fmt.euro(r.amount)}`;
    for (const b of el.querySelectorAll(".export-btn")) b.disabled = !r.tripCount;
    q(".x-ready").hidden = true;
    files = null;
    const pending = r.groups.some((g) => g.rows.some((row) => row.kmPending));
    if (pending) q(".x-info").textContent += " · Achtung: km noch nicht vollständig";
  };
  q(".x-scope").addEventListener("change", info);
  q(".x-orient").addEventListener("click", (e) => {
    const b = e.target.closest("button");
    if (!b) return;
    portrait = b.dataset.v === "portrait";
    try { localStorage.setItem("bm.exportPortrait", portrait ? "1" : "0"); } catch { /* egal */ }
    updateOrientation();
    q(".x-ready").hidden = true;
  });
  updateOrientation();
  info();

  el.addEventListener("click", async (e) => {
    const x = e.target.closest("[data-x]")?.dataset.x;
    if (x === "close") return closeSheet("#sheet-export");
    if (x === "share" && files) {
      const res = await exporter.shareFiles(files, report().title);
      if (res === "downloaded") toast("Datei heruntergeladen.");
      return;
    }
    if (!["xlsx", "pdf", "png"].includes(x)) return;
    const r = report();
    const ready = q(".x-ready");
    ready.hidden = false;
    ready.innerHTML = `<div class="calc"><span class="spinner"></span> Wird erstellt …</div>`;
    try {
      if (x === "xlsx") {
        files = [new File([exporter.makeXlsx(r)], `${r.fileBase}.xlsx`, { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" })];
      } else if (x === "pdf") {
        files = [new File([exporter.makePdf(r)], `${r.fileBase}.pdf`, { type: "application/pdf" })];
      } else {
        const blobs = await exporter.makeImages(r);
        files = blobs.map((b, i) => new File([b], `${r.fileBase}${blobs.length > 1 ? `_Seite-${i + 1}` : ""}.png`, { type: "image/png" }));
      }
      const label = x === "png" ? (files.length === 1 ? "1 Bild bereit" : `${files.length} Bilder bereit`) : `${files[0].name} bereit`;
      ready.innerHTML = `<label>Bereit</label><div class="fields"><div class="field"><span>${esc(label)}</span></div></div>
        <div style="margin-top:12px"><button class="btn primary large" data-x="share">${x === "png" ? "In Fotos sichern / Teilen" : "Teilen / Sichern"}</button></div>`;
    } catch (err) {
      console.error(err);
      ready.innerHTML = `<div class="warn">Erstellen fehlgeschlagen: ${esc(err.message || err)}</div>`;
    }
  });
}

// ===========================================================================
// Start
// ===========================================================================

document.addEventListener("click", (e) => {
  const year = e.target.closest("[data-year]");
  if (year) { selectedYear = Number(year.dataset.year); render(); return; }
  const trip = e.target.closest("[data-trip]");
  if (trip) { const t = store.tripById(trip.dataset.trip); if (t) openEditor("edit", t); return; }
  const a = e.target.closest("[data-action]")?.dataset.action;
  if (a === "new") openEditor("new");
  if (a === "settings") openSettings();
  if (a === "login") graph.login();
});

// Lange drücken auf eine Fahrt → duplizieren
let pressTimer = null;
document.addEventListener("pointerdown", (e) => {
  const trip = e.target.closest("[data-trip]");
  if (!trip) return;
  pressTimer = setTimeout(() => {
    const t = store.tripById(trip.dataset.trip);
    if (t && confirm(`„${tripTitle(t)}“ als neue Fahrt mit heutigem Datum duplizieren?`)) openEditor("duplicate", t);
  }, 650);
});
["pointerup", "pointercancel", "pointermove"].forEach((ev) => document.addEventListener(ev, () => clearTimeout(pressTimer)));

$("#btn-new").addEventListener("click", () => openEditor("new"));
$("#btn-settings").addEventListener("click", openSettings);
$("#btn-export").addEventListener("click", openExport);
$("#sync-pill").addEventListener("click", () => {
  if (store.status === "unconfigured") return toast("OneDrive-Abgleich ist noch nicht eingerichtet – siehe Anleitung.");
  if (!graph.getAccount()) return graph.login();
  store.sync({ interactive: true });
});

store.subscribe(() => {
  renderSyncPill();
  // Liste nur neu aufbauen, wenn kein Sheet offen ist (Eingaben nicht stören)
  if (![...document.querySelectorAll(".sheet")].some((s) => !s.hidden)) { renderYears(); renderMain(); }
});

async function start() {
  render();
  setTimeout(() => $("#splash").classList.add("hide"), 1400);
  setTimeout(() => $("#splash").remove(), 2000);

  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("sw.js").catch((e) => console.warn("Service Worker", e));
  }

  try {
    await graph.init();
  } catch (e) {
    console.warn("MSAL", e);
  }
  render();
  await store.sync();

  // Anmeldung abgelaufen, Konto aber bekannt: automatisch kurz zu Microsoft und zurück
  // (ohne Tippen). Schutz vor Endlosschleife: höchstens alle 2 Minuten.
  if (store.status === "login" && navigator.onLine && (graph.getAccount() || graph.rememberedUser())) {
    let last = 0;
    try { last = Number(localStorage.getItem("bm.autoLogin") || 0); } catch { /* egal */ }
    if (Date.now() - last > 120000) {
      try { localStorage.setItem("bm.autoLogin", String(Date.now())); } catch { /* egal */ }
      showReauthHint();
      graph.reauthenticate().catch((e) => console.warn("Automatische Anmeldung", e));
    }
  }
}

/** Kurzer Hinweis, falls die automatische Weiterleitung einen Moment dauert. */
function showReauthHint() {
  toast("Anmeldung wird erneuert …", 4000);
}

start();
