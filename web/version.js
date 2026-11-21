// Version der Web-App – wird von App und Service Worker gelesen.
// Bei jeder Änderung: BM_VERSION erhöhen und Neuigkeiten oben ergänzen.
self.BM_VERSION = 11;
self.BM_RELEASED = "2026-11-21";
self.BM_CHANGES = [
  "Export: Spalten „Hinfahrt km“ und „Rückfahrt km“ ausgeschrieben",
  "Export wahlweise im Hochformat oder Querformat",
  "Unterschrift und Datum im Export entfernt",
  "Kilometer manuell anpassen (z. B. Umleitung) – auch Gesamt-km, mit Vergleich zur Routenberechnung",
  "Einstellungen: aktuellen Kilometersatz auf alle Fahrten eines Jahres übernehmen",
  "Zahleneingabe repariert: „12.5“ und „12,5“ werden beide richtig gelesen",
  "Lokalitätssuche (z. B. „Café del Sol Fulda“)",
];
