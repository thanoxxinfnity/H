const SETTINGS_KEY = "avs.settings.v1";
export const DEFAULT_SETTINGS = {
  revanaKey: "",
  nimKey: "",
  nimModel: "meta/llama-3.3-70b-instruct",
  provider: "nim",
  geminiKey: "",
  geminiModel: "gemini-2.5-flash",
  defaultModel: "minimax-h3-free",
};

export function loadSettings() {
  if (typeof window === "undefined") return DEFAULT_SETTINGS;
  try { return { ...DEFAULT_SETTINGS, ...JSON.parse(localStorage.getItem(SETTINGS_KEY) || "{}") }; }
  catch { return DEFAULT_SETTINGS; }
}
export function saveSettings(s) {
  try { localStorage.setItem(SETTINGS_KEY, JSON.stringify(s)); } catch {}
}

/* ---- video history in IndexedDB (blobs stay on this device) ---- */
let dbp;
function db() {
  if (!dbp) dbp = new Promise((res, rej) => {
    const q = indexedDB.open("avs-history", 1);
    q.onupgradeneeded = () => q.result.createObjectStore("videos", { keyPath: "id" });
    q.onsuccess = () => res(q.result);
    q.onerror = () => rej(q.error);
  });
  return dbp;
}
async function tx(mode, fn) {
  const d = await db();
  return new Promise((res, rej) => {
    const t = d.transaction("videos", mode);
    const r = fn(t.objectStore("videos"));
    t.oncomplete = () => res(r && r.result);
    t.onerror = () => rej(t.error);
  });
}
export const addVideo = (rec) => tx("readwrite", (s) => s.put(rec));
export const listVideos = async () => ((await tx("readonly", (s) => s.getAll())) || []).sort((a, b) => b.createdAt - a.createdAt);
export const deleteVideo = (id) => tx("readwrite", (s) => s.delete(id));
export const clearVideos = () => tx("readwrite", (s) => s.clear());
