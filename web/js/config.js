// Konfiguration der Web-App.
// clientId und tenantId stammen aus der App-Registrierung in Microsoft Entra
// (siehe README → „Microsoft-Anmeldung einrichten“). Beide Werte sind nicht geheim.

export const CONFIG = {
  clientId: "",   // „Anwendungs-ID (Client)“
  tenantId: "",   // „Verzeichnis-ID (Mandant)“

  // Ordner und Datei in OneDrive (Ordner existiert bereits)
  folder: "Business-Miles",
  fileName: "business-miles.json",

  // Muss exakt der in Entra eingetragenen Umleitungs-URI entsprechen
  redirectUri: new URL("./", location.href).href,
};
