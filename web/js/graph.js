// Microsoft-Anmeldung (MSAL) und Zugriff auf die Datei in OneDrive (Microsoft Graph).
import { CONFIG } from "./config.js";

const SCOPES = ["Files.ReadWrite", "User.Read"];
const GRAPH = "https://graph.microsoft.com/v1.0";

let pca = null;
let account = null;

export class LoginRequiredError extends Error {
  constructor() { super("Anmeldung erforderlich"); this.name = "LoginRequiredError"; }
}
export class ConflictError extends Error {
  constructor() { super("Datei wurde zwischenzeitlich geändert"); this.name = "ConflictError"; }
}

export const isConfigured = () => Boolean(CONFIG.clientId && CONFIG.tenantId && window.msal);
export const getAccount = () => account;

/** Initialisiert MSAL und verarbeitet eine eventuelle Rückkehr von der Anmeldeseite. */
export async function init() {
  if (!isConfigured()) return null;
  pca = new window.msal.PublicClientApplication({
    auth: {
      clientId: CONFIG.clientId,
      authority: `https://login.microsoftonline.com/${CONFIG.tenantId}`,
      redirectUri: CONFIG.redirectUri,
      postLogoutRedirectUri: CONFIG.redirectUri,
      navigateToLoginRequestUrl: false,
    },
    cache: { cacheLocation: "localStorage" },
  });
  await pca.initialize();
  try {
    const result = await pca.handleRedirectPromise();
    if (result?.account) account = result.account;
  } catch (e) {
    console.warn("Anmeldung abgebrochen oder fehlgeschlagen", e);
  }
  account = account || pca.getActiveAccount() || pca.getAllAccounts()[0] || null;
  if (account) pca.setActiveAccount(account);
  return account;
}

export async function login() {
  if (!pca) throw new Error("Microsoft-Anmeldung ist nicht eingerichtet.");
  await pca.loginRedirect({ scopes: SCOPES, prompt: "select_account" });
}

export async function logout() {
  if (!pca || !account) return;
  await pca.logoutRedirect({ account });
}

async function accessToken(interactive) {
  if (!pca) throw new LoginRequiredError();
  if (!account) {
    if (interactive) await login();
    throw new LoginRequiredError();
  }
  try {
    const r = await pca.acquireTokenSilent({ scopes: SCOPES, account });
    return r.accessToken;
  } catch (e) {
    if (e instanceof window.msal.InteractionRequiredAuthError || e?.name === "InteractionRequiredAuthError") {
      if (interactive) await pca.acquireTokenRedirect({ scopes: SCOPES, account });
      throw new LoginRequiredError();
    }
    throw e;
  }
}

const itemPath = () =>
  `${GRAPH}/me/drive/root:/${encodeURIComponent(CONFIG.folder)}/${encodeURIComponent(CONFIG.fileName)}`;

/** Lädt die Datei. Ergebnis: { doc, etag } – doc ist null, wenn es die Datei noch nicht gibt. */
export async function download({ interactive = false } = {}) {
  const token = await accessToken(interactive);
  const meta = await fetch(itemPath(), { headers: { Authorization: `Bearer ${token}` }, cache: "no-store" });
  if (meta.status === 404) return { doc: null, etag: null };
  if (meta.status === 401) throw new LoginRequiredError();
  if (!meta.ok) throw new Error(`OneDrive antwortet mit Fehler ${meta.status}`);
  const item = await meta.json();
  const url = item["@microsoft.graph.downloadUrl"];
  const res = url
    ? await fetch(url, { cache: "no-store" })
    : await fetch(`${itemPath()}:/content`, { headers: { Authorization: `Bearer ${token}` }, cache: "no-store" });
  if (!res.ok) throw new Error(`Download fehlgeschlagen (${res.status})`);
  const text = await res.text();
  let doc = null;
  try {
    doc = text.trim() ? JSON.parse(text) : null;
  } catch {
    throw new Error("Die Datei in OneDrive ist beschädigt (kein gültiges JSON).");
  }
  return { doc, etag: item.eTag || null };
}

/** Schreibt die Datei. Mit etag nur, wenn sie seitdem nicht verändert wurde (sonst ConflictError). */
export async function upload(doc, etag, { interactive = false } = {}) {
  const token = await accessToken(interactive);
  const headers = { Authorization: `Bearer ${token}`, "Content-Type": "application/json" };
  let url = `${itemPath()}:/content`;
  if (etag) headers["If-Match"] = etag;
  else url += "?@microsoft.graph.conflictBehavior=fail";
  const res = await fetch(url, { method: "PUT", headers, body: JSON.stringify(doc, null, 2) });
  if (res.status === 412 || res.status === 409) throw new ConflictError();
  if (res.status === 401) throw new LoginRequiredError();
  if (!res.ok) throw new Error(`Speichern in OneDrive fehlgeschlagen (${res.status})`);
  const item = await res.json();
  return item.eTag || null;
}
