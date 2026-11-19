// Konfiguration der Web-App.
// clientId und tenantId stammen aus der App-Registrierung in Microsoft Entra
// (siehe README → „Microsoft-Anmeldung einrichten“). Beide Werte sind nicht geheim.

export const CONFIG = {
  clientId: "ca010a2f-9c00-4e37-81cc-2bc8047e65a0",   // „Anwendungs-ID (Client)“
  tenantId: "d7fe19d9-83ca-404f-be8a-93a3ae5bbcf2",   // „Verzeichnis-ID (Mandant)“

  // Ordner und Datei in OneDrive (Ordner existiert bereits)
  folder: "Business-Miles",
  fileName: "business-miles.json",

  // Muss exakt der in Entra eingetragenen Umleitungs-URI entsprechen
  redirectUri: new URL("./", location.href).href,
};
