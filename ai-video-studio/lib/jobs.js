import { waitForGeneration, downloadContent } from "@/lib/revana";
import { addVideo } from "@/lib/storage";

/* Jobs keep running on Revana's servers even when the tab is closed. We remember their ids here so the
   next visit can pick the finished videos up (or keep waiting for them). */
const K = "avs.jobs.v1";
const active = new Set();
const read = () => { try { return JSON.parse(localStorage.getItem(K) || "{}"); } catch { return {}; } };
const write = (o) => { try { localStorage.setItem(K, JSON.stringify(o)); } catch {} };

export const markActive = (id) => active.add(id);
export const savePending = (id, meta) => { const o = read(); o[id] = { ...meta, createdAt: Date.now() }; write(o); };
export const dropPending = (id) => { const o = read(); delete o[id]; write(o); active.delete(id); };
export const pendingJobs = () => Object.entries(read()).map(([id, m]) => ({ id, ...m }));

/** Waits for a job started in an earlier visit, stores the video in History and returns the record. */
export async function resumeJob({ key, id, onStatus }) {
  if (active.has(id)) return null;
  active.add(id);
  try {
    const meta = read()[id] || {};
    const g = await waitForGeneration({ key, id, onUpdate: onStatus });
    const blob = await downloadContent({ key, id });
    const rec = { ...meta, id, createdAt: meta.createdAt || Date.now(), cost: g.cost_usd ?? meta.cost ?? 0, blob };
    await addVideo(rec);
    dropPending(id);
    return rec;
  } catch (e) {
    active.delete(id);
    if (/failed|cancelled|not.?found|404/i.test(e.message)) dropPending(id);
    throw e;
  }
}
