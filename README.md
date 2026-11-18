<p align="center"><img src="docs/icon.png" width="128" alt="Business Miles"></p>

# Business Miles

Fahrten zum Kunden erfassen – mit automatischer Kilometerberechnung, Monats- und Jahressummen
und einem steuertauglichen Export.

- **Mac:** native App mit Widget
- **iPhone:** Web-App auf dem Home-Bildschirm (funktioniert auch offline)
- **Daten:** eine Datei in deinem **OneDrive-Ordner `Business-Miles`** – Mac und iPhone lesen und schreiben dieselbe Datei
- **Kosten:** 0 € – kein Apple-Developer-Account, kein Server, keine API-Schlüssel

```
   Mac-App ──(OneDrive-Client)──┐
                                ├──►  OneDrive › Business-Miles › business-miles.json
   iPhone-Web-App ──(Microsoft Graph)──┘
```

---

## Funktionen

| Bereich | Mac | iPhone |
|---|---|---|
| Start-Popup mit Logo | ✓ | ✓ |
| Neue Fahrt: Datum, Kunde, Anlass, Ziel, Start, Rückfahrt, Notiz | ✓ | ✓ |
| PLZ → Ort automatisch (offline, mit Auswahl bei mehreren Orten) | ✓ | ✓ |
| Straßenvorschläge beim Tippen | Apple Karten | OpenStreetMap (Photon) |
| km automatisch, Hin- und Rückfahrt getrennt, überschreibbar | Apple Karten | OpenStreetMap (OSRM) |
| Startadresse vorausgewählt, „Andere Adresse“ per Klick | ✓ | ✓ |
| Jahres-Kacheln | senkrecht rechts | waagerecht oben |
| Monats- und Jahressummen, Diagramm, Pauschale | ✓ | ✓ |
| Export Excel (.xlsx) und PDF | in Zielordner | Teilen / In Dateien sichern |
| Export als Bild für die Galerie | – | ✓ (in Fotos sichern) |
| Widget | ✓ (klein + mittel) | – |
| Offline erfassen, später automatisch abgleichen | ✓ | ✓ (Zwischenspeicher) |

**Abgleich:** Es wird nie die ganze Datei überschrieben. Jede Fahrt wird einzeln zusammengeführt
(die jüngere Änderung gewinnt), Löschungen werden übertragen. Offline erfasste Fahrten
ohne Kilometer werden nachberechnet, sobald ein Gerät wieder online ist („km folgen“).
Details: [`docs/DATENFORMAT.md`](docs/DATENFORMAT.md).

---

## Einrichtung

### 1 · Mac-App (ca. 10 Minuten)

Voraussetzungen: Mac mit **macOS 14** oder neuer, **Xcode** (kostenlos im App Store), OneDrive-App angemeldet.

```bash
brew install xcodegen            # einmalig (https://brew.sh)
git clone https://github.com/ziege1988/Business-Miles-.git
cd Business-Miles-
```

1. Xcode öffnen → *Settings → Accounts* → mit deiner **normalen Apple-ID** anmelden (kostenlos).
   Dort steht unter „Team“ dein *Personal Team* – die 10-stellige Team-ID findest du z. B. im
   Schlüsselbund unter „Apple Development: …“ (Feld „Organisationseinheit“).
2. In **`project.yml`** oben eintragen:
   ```yaml
   BUNDLE_ID_PREFIX: de.czfotografie     # beliebige eigene Kennung
   DEVELOPMENT_TEAM: ABCDE12345          # deine Team-ID
   ```
3. Projekt erzeugen und starten:
   ```bash
   xcodegen generate
   open BusinessMiles.xcodeproj         # dann ⌘R
   ```
   Falls Xcode beim Signieren meckert: bei beiden Targets (*BusinessMiles*, *BusinessMilesWidget*)
   unter *Signing & Capabilities* als Team dein *Personal Team* auswählen.
4. Beim ersten Start oben **„Ordner wählen …“** → in der Seitenleiste *OneDrive* → Ordner **`Business-Miles`** auswählen.
5. Empfehlung: Im Finder Rechtsklick auf `Business-Miles` → **„Immer auf diesem Gerät behalten“**.
6. Damit die App dauerhaft im Programme-Ordner liegt: *Product → Archive → Distribute App → Copy App*
   und `Business Miles.app` nach *Programme* ziehen.
7. Widget: Mitteilungszentrale öffnen → „Widgets bearbeiten“ → *Business Miles*.

### 2 · Web-App veröffentlichen (GitHub Pages, einmalig)

1. **Repository öffentlich machen:** GitHub → *Settings → General → Danger Zone → Change visibility → Public*.
   Öffentlich ist nur der Programmcode – deine Fahrten liegen ausschließlich in deinem OneDrive.
   (GitHub Pages ist im kostenlosen Tarif nur für öffentliche Repositories verfügbar.)
2. *Settings → Pages → Build and deployment → Source:* **GitHub Actions**.
3. Den Stand auf den Branch `main` bringen (Pull Request zusammenführen). Der Workflow
   „Web-App veröffentlichen“ läuft dann automatisch.
4. Adresse der Web-App: **https://ziege1988.github.io/Business-Miles-/**

### 3 · Microsoft-Anmeldung einrichten (ca. 5 Minuten, kostenlos)

Damit die Web-App auf dein OneDrive zugreifen darf, wird sie einmal in deinem Microsoft-365-Konto registriert:

1. [entra.microsoft.com](https://entra.microsoft.com) mit deinem Microsoft-365-Konto öffnen.
2. *Identität → Anwendungen → App-Registrierungen →* **Neue Registrierung**
   - Name: `Business Miles`
   - Unterstützte Kontotypen: **Nur Konten in diesem Organisationsverzeichnis (Einzelner Mandant)**
   - Umleitungs-URI: Plattform **Single-Page-Anwendung (SPA)**, Adresse
     `https://ziege1988.github.io/Business-Miles-/` (genau so, mit `/` am Ende)
   - → **Registrieren**
3. Auf der Übersichtsseite zwei Werte notieren:
   **Anwendungs-ID (Client)** und **Verzeichnis-ID (Mandant)**.
4. *API-Berechtigungen → Berechtigung hinzufügen → Microsoft Graph → Delegierte Berechtigungen →*
   **Files.ReadWrite** hinzufügen. Danach **„Administratorzustimmung für … erteilen“** klicken.
5. Die beiden Werte in [`web/js/config.js`](web/js/config.js) bei `clientId` und `tenantId` eintragen
   (oder Claude schicken). Beide Werte sind nicht geheim.

### 4 · Auf dem iPhone

1. In **Safari** `https://ziege1988.github.io/Business-Miles-/` öffnen.
2. *Teilen* → **„Zum Home-Bildschirm“**.
3. App vom Home-Bildschirm starten → **Anmelden** → mit dem Microsoft-365-Konto anmelden.
4. Fertig – der grüne Punkt oben zeigt „Mit OneDrive synchronisiert“.

> Microsoft verlangt bei Web-Apps etwa einmal täglich eine kurze Bestätigung der Anmeldung;
> die App leitet dann automatisch kurz zur Microsoft-Seite weiter. Fahrten bleiben dabei erhalten.

---

## Hinweise zur Steuer

- Der Export enthält je Fahrt: **Datum, Kunde/Geschäftspartner, Anlass, Start-, Ziel- und Rückfahrtadresse,
  Hin-/Rück-/Gesamt-km und Betrag**, dazu Monats- und Gesamtsummen, Name, Anschrift, Steuernummer,
  Fahrzeug, Kennzeichen, km-Satz sowie Felder für Ort, Datum und Unterschrift.
- Voreingestellt: **0,30 €/km (Pkw)** bzw. **0,20 €/km (Motorrad/Motorroller)** für betrieblich
  veranlasste Fahrten mit dem Privatfahrzeug. Der Satz ist änderbar.
- Die Startadresse wird beim Speichern **in jede Fahrt kopiert** – ein späterer Umzug verändert alte Einträge nicht.
- Kilometer stammen aus der Routenberechnung (Mac: Apple Karten, iPhone: OpenStreetMap) und können
  sich zwischen den Geräten leicht unterscheiden. Bei Umwegen bitte manuell anpassen.
- Im Zweifel mit der Steuerberatung abstimmen.

---

## Aufbau

```
project.yml                 XcodeGen-Projekt: Mac-App + Widget
Sources/Core/               Gemeinsam für App und Widget: Farben, Logo, Formatierung, Widget-Daten
Sources/App/
  Models/                   Trip, AppSettings, DataFile (Dateiformat + Zusammenführung)
  Persistence/TripStore     OneDrive-Datei lesen/zusammenführen/schreiben, Offline-Kopie, Konfliktkopien
  Services/                 Adressvorschläge, Routen-km (MapKit), PLZ-Tabelle
  Views/                    Hauptansicht, Jahres-Kacheln, Editor, Einstellungen, Export
  Export/                   XLSX-Writer (inkl. ZIP), PDF-Seiten
Sources/Widget/             WidgetKit-Erweiterung
Resources/plz.json          PLZ → Ort (8.168 Postleitzahlen)
web/                        iPhone-Web-App (ohne Build-Schritt)
  js/model.js               Dateiformat + Zusammenführung (identisch zur Mac-App)
  js/store.js               Zwischenspeicher + Abgleich mit OneDrive
  js/graph.js               Microsoft-Anmeldung + OneDrive-Zugriff
  js/geo.js                 PLZ, Straßenvorschläge, Routen
  js/exports.js             Excel, PDF, Bilder
  sw.js                     Offline-Betrieb
tests/                      Tests (node --test tests/model.test.mjs)
tools/                      Icons und PLZ-Tabelle neu erzeugen
```

**Drittanbieter:** MSAL.js (MIT), jsPDF + AutoTable (MIT) liegen unter `web/vendor/`.
PLZ-Daten © OpenStreetMap-Mitwirkende (ODbL), aufbereitet von suche-postleitzahl.org.
Adressen/Routen auf dem iPhone: Photon (komoot), Nominatim, OSRM/FOSSGIS – kostenlose
OpenStreetMap-Dienste für moderate private Nutzung.
