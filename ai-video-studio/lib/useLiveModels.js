"use client";
import { useCallback, useEffect, useRef, useState } from "react";

/** Keeps a provider's model list live: refreshes on load, every 10 min, on tab focus and on demand.
 *  If the selected model vanished it switches to a fallback; reports added/removed models. */
export function useLiveModels({ id, enabled, fetcher, fallback, current, setCurrent, onNotice }) {
  const [st, setSt] = useState({ models: [], loading: false, error: "", updatedAt: null });
  const ref = useRef({});
  ref.current = { fetcher, fallback, current, setCurrent, onNotice };
  const refresh = useCallback(async () => {
    setSt((s) => ({ ...s, loading: true, error: "" }));
    try {
      const list = await ref.current.fetcher();
      let prev = null; const ck = `avs.list.${id}.v1`;
      try { prev = JSON.parse(localStorage.getItem(ck) || "null"); localStorage.setItem(ck, JSON.stringify(list)); } catch {}
      setSt({ models: list, loading: false, error: "", updatedAt: Date.now() });
      const cur = ref.current.current; let msg = "";
      if (cur && !list.includes(cur)) { const fb = ref.current.fallback(list); ref.current.setCurrent(fb); msg = `"${cur}" was removed - switched to ${fb}. `; }
      if (prev) {
        const removed = prev.filter((m) => !list.includes(m)), added = list.filter((m) => !prev.includes(m));
        if (removed.length) msg += `Removed: ${removed.join(", ")}. `;
        if (added.length) msg += `New: ${added.join(", ")}.`;
      }
      if (msg) ref.current.onNotice?.(msg.trim());
    } catch (e) { setSt((s) => ({ ...s, loading: false, error: e.message, models: [] })); }
  }, [id]);
  useEffect(() => {
    if (!enabled) return;
    refresh();
    const t = setInterval(refresh, 10 * 60 * 1000);
    const vis = () => { if (document.visibilityState === "visible") refresh(); };
    document.addEventListener("visibilitychange", vis);
    return () => { clearInterval(t); document.removeEventListener("visibilitychange", vis); };
  }, [enabled, refresh]);
  return { ...st, refresh };
}
