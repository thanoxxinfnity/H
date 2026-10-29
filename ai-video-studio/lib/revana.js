export const REVANA_BASE = "https://api.revana.si/v1";

export async function listVideoModels() {
  const r = await fetch(`${REVANA_BASE}/models`);
  if (!r.ok) throw new Error(`Could not load models (${r.status})`);
  const j = await r.json();
  return (j.data || []).filter(
    (m) => m.kind === "video" && (m.tasks || []).some((t) => t === "text_to_video" || t === "image_to_video"),
  );
}

/** USD per second for a model at a resolution (free models return 0). */
export function unitPrice(model, resolution) {
  const u = model?.price?.usd;
  if (u == null) return 0;
  if (typeof u === "number") return u;
  if (u[resolution] != null) return Number(u[resolution]);
  const vals = Object.values(u).map(Number).filter((n) => !Number.isNaN(n));
  return vals.length ? Math.max(...vals) : 0;
}
export function estimate(model, resolution, duration) {
  const usd = unitPrice(model, resolution) * duration;
  return { usd, credits: Math.round(usd * 100), free: !!model?.price?.free || usd === 0 };
}
export const fmtUsd = (n) => (n === 0 ? "$0.00" : `$${n.toFixed(n < 1 ? 3 : 2)}`);

async function api(path, key, init = {}) {
  const r = await fetch(`${REVANA_BASE}${path}`, {
    ...init,
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json", ...(init.headers || {}) },
  });
  if (!r.ok) {
    let msg = `${r.status}`;
    try { const j = await r.json(); msg = j?.error?.message || JSON.stringify(j); } catch {}
    const e = new Error(msg); e.status = r.status; throw e;
  }
  return r;
}

export async function getBalance(key) {
  return (await api("/balance", key)).json();
}

export async function createGeneration({ key, model, input, idem }) {
  const r = await api("/generations", key, {
    method: "POST",
    headers: { "Idempotency-Key": idem },
    body: JSON.stringify({ model, input }),
  });
  return r.json();
}

/** Polls until succeeded/failed. onUpdate gets each status object. */
export async function waitForGeneration({ key, id, onUpdate, signal, everyMs = 5000, maxMs = 25 * 60 * 1000 }) {
  const t0 = Date.now();
  for (;;) {
    if (signal?.aborted) throw new Error("Cancelled");
    const g = await (await api(`/generations/${id}`, key)).json();
    onUpdate?.(g);
    if (g.status === "succeeded") return g;
    if (g.status === "failed" || g.status === "cancelled") throw new Error(g.error?.message || `Generation ${g.status}`);
    if (Date.now() - t0 > maxMs) throw new Error("Timed out waiting for the video");
    await new Promise((r) => setTimeout(r, everyMs));
  }
}

export async function downloadContent({ key, id }) {
  const r = await api(`/generations/${id}/content`, key);
  return r.blob();
}

export const newId = () => (crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(16).slice(2)}`);

/** Create + wait + download. Returns { blob, gen }. */
export async function runVideo({ key, model, input, onStatus, signal }) {
  const idem = `avs-${newId()}`;
  const g0 = await createGeneration({ key, model, input, idem });
  onStatus?.(g0);
  const g = await waitForGeneration({ key, id: g0.id, onUpdate: onStatus, signal });
  const blob = await downloadContent({ key, id: g.id });
  return { blob, gen: g };
}

/** Uploads a file/blob to Revana (presigned PUT) and returns a public https link good for 14 days. */
export async function uploadBlob({ key, blob, filename }) {
  const r = await api("/uploads", key, {
    method: "POST",
    body: JSON.stringify({ content_type: blob.type || "image/jpeg", bytes: blob.size, filename: filename || "image.jpg" }),
  });
  const u = await r.json();
  const put = await fetch(u.upload_url, { method: u.upload_method || "PUT", headers: u.upload_headers || {}, body: blob });
  if (!put.ok) throw new Error(`Image upload failed (${put.status})`);
  return u.url;
}

export function modelCaps(model) {
  const tasks = model?.tasks || [];
  const max = model?.options?.max_input_images || 0;
  return { start: tasks.includes("image_to_video"), refs: tasks.includes("reference_to_video") && max > 0, maxRefs: max };
}
