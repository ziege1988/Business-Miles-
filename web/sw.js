// Service Worker: hält die App offline verfügbar.
// Bei jeder Änderung an den Dateien VERSION erhöhen, damit iPhones die neue Fassung laden.
const VERSION = "bm-v7";
const SHELL = [
  "./", "index.html", "manifest.webmanifest", "css/app.css",
  "js/app.js", "js/config.js", "js/exports.js", "js/format.js", "js/geo.js", "js/graph.js", "js/model.js", "js/store.js",
  "vendor/msal-browser.min.js", "vendor/jspdf.umd.min.js", "vendor/jspdf.plugin.autotable.min.js",
  "data/plz.json", "icons/logo.svg", "icons/icon-192.png", "icons/icon-512.png", "icons/apple-touch-icon.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(VERSION).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  const url = new URL(req.url);
  // Nur eigene Dateien cachen – Microsoft, Karten- und Routendienste immer live
  if (req.method !== "GET" || url.origin !== self.location.origin) return;

  // Seite selbst: erst Netz (Updates), sonst Cache. Anmelde-Rückkehr (?code=/#code=) nie aus dem Cache.
  if (req.mode === "navigate") {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(VERSION).then((c) => c.put("index.html", copy));
          return res;
        })
        .catch(() => caches.match("index.html")),
    );
    return;
  }

  // Übrige Dateien: Cache zuerst, im Hintergrund aktualisieren
  event.respondWith(
    caches.match(req).then((cached) => {
      const network = fetch(req)
        .then((res) => {
          if (res.ok) {
            const copy = res.clone();
            caches.open(VERSION).then((c) => c.put(req, copy));
          }
          return res;
        })
        .catch(() => cached);
      return cached || network;
    }),
  );
});
