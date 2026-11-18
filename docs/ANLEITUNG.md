# Einrichtung Schritt für Schritt

Du brauchst: deinen GitHub-Zugang, dein Microsoft-365-Konto (Info@…) und etwa 20 Minuten.
Programmierkenntnisse sind nicht nötig. Alles ist kostenlos.

| Teil | Was | Dauer |
|---|---|---|
| 1 | Web-App fürs iPhone auf GitHub veröffentlichen | ca. 5 Min. |
| 2 | Web-App bei Microsoft anmelden (Zugriff auf OneDrive) | ca. 5 Min. |
| 3 | Mac-App installieren | ca. 5 Min. |
| 4 | iPhone einrichten | ca. 3 Min. |

> GitHub ist nur auf Englisch verfügbar – die Knöpfe heißen deshalb so, wie sie hier in
> **Fettschrift** stehen.

---

## Teil 1 – Web-App auf GitHub veröffentlichen

### 1.1 Repository öffentlich machen

GitHub stellt Webseiten im kostenlosen Tarif nur aus **öffentlichen** Repositories bereit.
Öffentlich ist dabei **nur der Programmcode** – deine Fahrten, Adressen und Einstellungen
liegen ausschließlich in deinem OneDrive und sind nie auf GitHub.

1. Im Browser **https://github.com/ziege1988/Business-Miles-** öffnen und anmelden.
2. In der Leiste unter dem Repository-Namen ganz rechts auf **⚙ Settings** klicken.
   *(Bei schmalem Fenster steckt „Settings“ im Menü **···**.)*
3. Es öffnet sich die Seite **General**. Ganz nach **unten** scrollen bis zum rot umrandeten
   Bereich **Danger Zone**.
4. Bei **Change repository visibility** auf **Change visibility** klicken und **Change to public** wählen.
5. Es erscheinen nacheinander Bestätigungsfenster. Jeweils klicken:
   **I want to make this repository public** → **I have read and understand these effects** →
   **Make this repository public**.
   Eventuell fragt GitHub nach deinem Passwort oder einem Bestätigungscode – eingeben.
6. ✅ Kontrolle: Oben neben dem Namen „Business-Miles-“ steht jetzt **Public**.

### 1.2 GitHub Pages einschalten

1. Du bist noch in **Settings**. Im Menü links unter „Code and automation“ auf **Pages** klicken.
2. Im Abschnitt **Build and deployment** gibt es das Feld **Source**.
   Dort im Auswahlfeld **GitHub Actions** wählen. *(Ein Speichern-Knopf ist nicht nötig.)*

### 1.3 Neuen Stand übernehmen („Merge“)

Der fertige Code liegt in einem Arbeitszweig. Er muss einmal in den Hauptzweig `main`
übernommen werden. Das geht über einen sogenannten *Pull Request*:

1. Oben auf den Reiter **Pull requests** klicken.
2. Den Eintrag **Business Miles: Mac-App + iPhone-Web-App** öffnen.
   *(Falls noch keiner da ist: Claude kurz Bescheid geben – Claude legt ihn an.)*
3. Ganz unten auf den grünen Knopf **Merge pull request** klicken, dann **Confirm merge**.

### 1.4 Prüfen

1. Oben auf den Reiter **Actions** klicken.
2. Dort laufen jetzt zwei Vorgänge: **Web-App veröffentlichen** und **Mac-App bauen**.
   Nach 1–5 Minuten erscheint je ein **grüner Haken ✓**.
3. Im Browser **https://ziege1988.github.io/Business-Miles-/** öffnen.
   Die App erscheint mit dem Hinweis „OneDrive noch nicht eingerichtet“ – **das ist richtig**,
   das erledigt Teil 2.

---

## Teil 2 – Web-App bei Microsoft anmelden

Damit die Web-App auf **deinen** OneDrive-Ordner zugreifen darf, wird sie einmal in deinem
Microsoft-365-Konto registriert. Dafür brauchst du Administrator-Rechte – als Inhaber
deines Microsoft-365-Kontos hast du die in der Regel.

### 2.1 App registrieren

1. Im Browser **https://entra.microsoft.com** öffnen und mit deinem Microsoft-365-Konto anmelden.
2. Oben in das **Suchfeld** `App-Registrierungen` eintippen und den Treffer anklicken.
   *(Alternativ im Menü links: **Entra ID** → **App-Registrierungen**.)*
3. Oben auf **+ Neue Registrierung** klicken.
4. Das Formular so ausfüllen:

   | Feld | Eingabe |
   |---|---|
   | **Name** | `Business Miles` |
   | **Unterstützte Kontotypen** | **Nur Konten in diesem Organisationsverzeichnis** (einzelner Mandant) – meist schon ausgewählt |
   | **Umleitungs-URI** – linkes Auswahlfeld | **Single-Page-Webanwendung (SPA)** |
   | **Umleitungs-URI** – rechtes Textfeld | `https://ziege1988.github.io/Business-Miles-/` |

   ⚠️ Die Adresse genau so übernehmen – mit **Bindestrich** nach „Miles“ und **Schrägstrich `/` am Ende**.
5. Unten auf **Registrieren** klicken.

### 2.2 Zwei Kennungen notieren

Es öffnet sich die **Übersicht** der neuen App. Dort stehen unter „Zusammenfassung“:

- **Anwendungs-ID (Client)** – z. B. `1a2b3c4d-…`
- **Verzeichnis-ID (Mandant)** – z. B. `9f8e7d6c-…`

Neben jedem Wert ist ein kleines **Kopier-Symbol** 📋. Beide Werte kopieren und z. B. in eine
Notiz einfügen. *(Diese Werte sind nicht geheim – sie dürfen im Code stehen.)*

### 2.3 Zugriff auf OneDrive erlauben

1. Im Menü links auf **API-Berechtigungen** klicken.
2. Auf **+ Berechtigung hinzufügen** klicken.
3. Die große Kachel **Microsoft Graph** anklicken.
4. **Delegierte Berechtigungen** wählen.
5. Im Suchfeld `Files` eintippen, den Bereich **Files** aufklappen und den Haken bei
   **Files.ReadWrite** setzen.
6. Unten auf **Berechtigungen hinzufügen** klicken.
7. In der Liste stehen jetzt **User.Read** und **Files.ReadWrite**.
   Oberhalb der Liste auf **Administratorzustimmung für „…“ erteilen** klicken und mit **Ja** bestätigen.
8. ✅ Kontrolle: In der Spalte „Status“ stehen grüne Haken.

### 2.4 Kennungen an Claude geben

Die beiden Werte aus 2.2 an Claude schicken – Claude trägt sie in die Web-App ein
(Datei `web/js/config.js`). Nach 1–2 Minuten ist die Web-App bereit.

### Wenn etwas nicht klappt

| Meldung | Lösung |
|---|---|
| „Sie haben keinen Zugriff“ / Menüpunkt fehlt | Das Konto hat keine Administrator-Rechte. Mit dem Administrator-Konto anmelden. |
| Beim Anmelden am iPhone: **AADSTS50011** (redirect URI mismatch) | In der App-Registrierung unter **Authentifizierung** die Adresse prüfen – inkl. `/` am Ende und Plattform **Single-Page-Anwendung**. |
| **AADSTS65001** / „Genehmigung erforderlich“ | Schritt 2.3 Punkt 7 (Administratorzustimmung) nachholen. |

---

## Teil 3 – Mac-App installieren

Deine anderen Mac-Programme stammen von Firmen, die bei Apple einen kostenpflichtigen
Entwickler-Account haben – deshalb öffnen sie sich ohne Rückfrage. Business Miles hat diesen
Account bewusst nicht. Die App wird deshalb **einmalig** bestätigt, danach startet sie ganz normal.

1. **https://github.com/ziege1988/Business-Miles-/releases** öffnen.
2. Beim obersten Eintrag „Business Miles für Mac – Build …“ unter **Assets** auf
   **Business-Miles-Mac.zip** klicken. Die Datei landet in „Downloads“.
3. Im Finder in **Downloads** doppelt auf die ZIP-Datei klicken – es entsteht **Business Miles**.
4. **Business Miles** in den Ordner **Programme** ziehen (wie bei deinen anderen Apps).
5. Business Miles per Doppelklick starten. macOS meldet: *„Business Miles“ kann nicht geöffnet werden*
   bzw. *Apple konnte nicht überprüfen …* → auf **Fertig** klicken.
6. **Apfel-Menü  → Systemeinstellungen → Datenschutz & Sicherheit** öffnen und ganz nach unten scrollen.
   Dort steht *„Business Miles“ wurde blockiert …* → auf **Dennoch öffnen** klicken, Mac-Passwort
   eingeben, nochmals **Dennoch öffnen**.
   *(macOS 14 Sonoma: alternativ im Finder **Rechtsklick** auf die App → **Öffnen** → **Öffnen**.)*
7. Beim ersten Start fragt macOS eventuell, ob Business Miles auf Dateien von **OneDrive**
   zugreifen darf → **Erlauben**.
8. Die App findet den Ordner `OneDrive › Business-Miles` automatisch. Falls nicht: oben auf
   **Ordner wählen …** klicken und ihn auswählen.
9. Widget: Auf dem Schreibtisch mit Rechtsklick → **Widgets bearbeiten** → **Business Miles** suchen und hinzufügen.

**Plan B**, falls macOS meldet, die App sei *„beschädigt“*: Programm **Terminal** öffnen, diese
Zeile hineinkopieren und Enter drücken – danach lässt sich die App normal öffnen:

```
xattr -dr com.apple.quarantine "/Applications/Business Miles.app"
```

**Updates:** Neue Versionen erscheinen ebenfalls unter *Releases*. ZIP laden, alte App in
*Programme* ersetzen. Die Daten bleiben erhalten (sie liegen in OneDrive).

---

## Teil 4 – iPhone einrichten

1. Auf dem iPhone in **Safari** (nicht Chrome) **https://ziege1988.github.io/Business-Miles-/** öffnen.
2. Unten auf das **Teilen-Symbol** (Quadrat mit Pfeil nach oben) tippen.
3. Nach unten wischen → **Zum Home-Bildschirm** → **Hinzufügen**.
4. Business Miles über das neue Symbol auf dem Home-Bildschirm öffnen.
5. Auf **Anmelden** tippen und mit dem Microsoft-365-Konto anmelden.
6. ✅ Oben steht **„Mit OneDrive synchronisiert“** mit grünem Punkt.

> Microsoft verlangt bei Web-Apps etwa einmal täglich eine kurze Bestätigung der Anmeldung.
> Die App leitet dann automatisch kurz zur Microsoft-Seite weiter – Fahrten gehen dabei nicht verloren.
