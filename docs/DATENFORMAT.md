# Datenformat `business-miles.json`

Die Datei liegt in OneDrive im Ordner **`Business-Miles`**. Mac-App und Web-App lesen und schreiben
dieselbe Datei. Damit gleichzeitige Änderungen nicht verloren gehen, wird **nie die ganze Datei
überschrieben**, sondern immer zusammengeführt:

- **Fahrten:** pro `id` gewinnt der Eintrag mit dem jüngeren `updatedAt`.
- **Gelöschte Fahrten** bleiben als `"deleted": true` erhalten, damit das Löschen auf andere Geräte übertragen wird.
- **Einstellungen:** der Block mit dem jüngeren `settings.updatedAt` gewinnt.
- Zeitstempel: ISO 8601 in UTC mit Millisekunden, z. B. `2026-11-18T09:15:00.000Z`.
- Fahrtdatum: reines Kalenderdatum `YYYY-MM-DD` (keine Zeitzonenverschiebung).
- `id`: UUID als Zeichenkette; Groß-/Kleinschreibung wird unverändert übernommen.
- Unbekannte Felder werden beim Lesen ignoriert. Fehlende Felder bekommen Standardwerte.

```json
{
  "format": "business-miles",
  "version": 1,
  "updatedAt": "2026-11-18T09:15:00.000Z",
  "settings": {
    "fullName": "", "company": "", "taxNumber": "",
    "home": { "street": "Musterstraße 1", "postalCode": "80331", "city": "München", "lat": 48.137, "lon": 11.575 },
    "vehicleName": "", "licensePlate": "",
    "vehicleType": "car",
    "ratePerKm": 0.30,
    "updatedAt": "2026-11-18T09:15:00.000Z"
  },
  "trips": [
    {
      "id": "6f1c…",
      "date": "2026-11-18",
      "customer": "Familie Berger",
      "purpose": "Hochzeitsreportage",
      "note": "",
      "destination": { "street": "…", "postalCode": "…", "city": "…", "lat": null, "lon": null },
      "startUsesHome": true,
      "start": { "street": "…", "postalCode": "…", "city": "…" },
      "returnEnabled": true,
      "returnUsesHome": true,
      "returnTo": { "street": "…", "postalCode": "…", "city": "…" },
      "outboundKm": 42.1,
      "returnKm": 41.9,
      "ratePerKm": 0.30,
      "departureTime": "08:30",
      "returnTime": "17:45",
      "kmPending": false,
      "source": "web",
      "createdAt": "…",
      "updatedAt": "…",
      "deleted": false
    }
  ]
}
```

`kmPending: true` bedeutet: Die Fahrt wurde offline erfasst und die Kilometer werden berechnet,
sobald ein Gerät wieder online ist (Mac oder iPhone, je nachdem, welches zuerst).

`ratePerKm` je Fahrt: der beim Speichern gültige Kilometersatz. Ändert sich der Satz in den
Einstellungen, behalten bereits erfasste Fahrten ihren Satz. Fehlt das Feld (`null`), gilt der Satz
aus den Einstellungen.

`departureTime` / `returnTime`: optionale Uhrzeiten `HH:MM` (leer = nicht angegeben).

`vehicleType`: `car`, `motorcycle` oder `custom` – nur eine Schnellwahl für `settings.ratePerKm`,
der Satz selbst ist frei einstellbar.
