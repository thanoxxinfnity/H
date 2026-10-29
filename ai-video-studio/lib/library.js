const KEY = "avs.library.v1";
const TTL = 13 * 24 * 3600 * 1000; // Revana links last 14 days
export function loadLibrary() {
  try {
    const all = JSON.parse(localStorage.getItem(KEY) || "[]");
    return all.filter((i) => Date.now() - i.createdAt < TTL);
  } catch { return []; }
}
export function addToLibrary(item) {
  try {
    const next = [item, ...loadLibrary().filter((i) => i.url !== item.url)].slice(0, 24);
    localStorage.setItem(KEY, JSON.stringify(next));
  } catch {}
}
export function removeFromLibrary(url) {
  try { localStorage.setItem(KEY, JSON.stringify(loadLibrary().filter((i) => i.url !== url))); } catch {}
}
