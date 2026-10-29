"use client";
import { useEffect, useState } from "react";
import { Sparkles, Loader2, AlertTriangle, CheckCircle2 } from "lucide-react";
import ConfigFields from "./ConfigFields";
import ImagePicker from "./ImagePicker";
import ConfirmModal from "./ConfirmModal";
import VideoCard from "./VideoCard";
import { buildPrompt, STYLES, CAMERAS } from "@/lib/prompt";
import { estimate, fmtUsd, runVideo, newId, modelCaps } from "@/lib/revana";
import { addVideo } from "@/lib/storage";

function Elapsed({ t0 }) {
  const [n, setN] = useState(0);
  useEffect(() => { const i = setInterval(() => setN(Math.round((Date.now() - t0) / 1000)), 1000); return () => clearInterval(i); }, [t0]);
  return <span>{n}s</span>;
}

export default function Create({ settings, models, cfg, setCfg, prompt, setPrompt, onNeedKey, onSaved }) {
  const [images, setImages] = useState([]);
  const [imgMode, setImgMode] = useState("start"); // start frame | references
  const [confirm, setConfirm] = useState(false);
  const [jobs, setJobs] = useState([]);
  const model = models.find((m) => m.id === cfg.model);
  const full = buildPrompt(prompt, cfg.style, cfg.camera);
  const est = estimate(model, cfg.resolution, cfg.duration);
  const caps = modelCaps(model);
  const mode = imgMode === "refs" && caps.refs ? "refs" : caps.start ? "start" : caps.refs ? "refs" : "none";
  const maxImgs = mode === "refs" ? caps.maxRefs : 1;
  const used = mode === "none" ? [] : images.slice(0, maxImgs);
  const patch = (uid, p) => setJobs((js) => js.map((j) => (j.uid === uid ? { ...j, ...p } : j)));

  function ask() {
    if (!settings.revanaKey) return onNeedKey();
    if (!prompt.trim()) return;
    setConfirm(true);
  }

  async function start() {
    setConfirm(false);
    const uid = newId();
    const c = { ...cfg, used, mode };
    setJobs((js) => [{ uid, prompt: full, status: "queued", t0: Date.now(), cfg: c }, ...js]);
    try {
      const input = { prompt: full, duration: c.duration, resolution: c.resolution, aspect_ratio: c.ratio };
      if (c.used.length) { if (c.mode === "refs") input.image_urls = c.used.map((i) => i.url); else input.image_url = c.used[0].url; }
      const { blob, gen } = await runVideo({ key: settings.revanaKey, model: c.model, input, onStatus: (g) => patch(uid, { status: g.status }) });
      const rec = { id: gen.id, kind: "video", prompt: full, model: c.model, duration: c.duration, resolution: c.resolution, ratio: c.ratio,
        cost: gen.cost_usd ?? est.usd, free: est.free, createdAt: Date.now(), blob };
      await addVideo(rec);
      patch(uid, { status: "done", rec });
      onSaved?.();
    } catch (e) {
      patch(uid, { status: "error", error: e.message });
    }
  }

  return (
    <div className="grid gap-4 lg:grid-cols-[minmax(0,420px)_1fr]">
      <div className="card">
        <label className="lbl !mt-0">Prompt</label>
        <textarea className="inp min-h-[130px] resize-y" value={prompt} onChange={(e) => setPrompt(e.target.value)}
          placeholder="Describe the scene, subject, action and mood…" />
        <div className="mt-3 rounded-xl border border-line bg-panel2/60 p-3">
          <div className="mb-1 flex items-center gap-2 text-[11px] text-white/50">
            <span className={`chip !py-1 ${mode === "start" ? "border-neon bg-neon/15 text-neon" : "border-line text-white/50"}`} onClick={() => caps.start && setImgMode("start")}>Image → Video</span>
            <span className={`chip !py-1 ${mode === "refs" ? "border-pink bg-pink/15 text-pink" : "border-line text-white/50"} ${caps.refs ? "cursor-pointer" : "opacity-40"}`} onClick={() => caps.refs && setImgMode("refs")}>Character refs</span>
            <span className="ml-auto">{used.length ? "" : "Text → Video"}</span>
          </div>
          {mode === "none" ? <p className="text-[11px] text-white/40">This model is text-to-video only.</p> : (
            <ImagePicker label={mode === "refs" ? "Character / reference images" : "Start frame photo"} value={images} onChange={setImages} max={maxImgs} apiKey={settings.revanaKey} onNeedKey={onNeedKey}
              hint={mode === "refs" ? "These people/objects will appear in the video." : "Your photo becomes the first frame and gets animated. Leave empty for pure text-to-video."} />
          )}
        </div>
        <ConfigFields models={models} cfg={cfg} setCfg={setCfg} />
        <button className="btn-neon mt-5 w-full py-3 text-base" onClick={ask} disabled={!prompt.trim()}>
          <Sparkles size={18} /> Generate <span className="opacity-70">· {est.free ? "FREE" : fmtUsd(est.usd)}</span>
        </button>
      </div>

      <div className="space-y-3">
        {jobs.length === 0 && (
          <div className="card flex min-h-[260px] flex-col items-center justify-center text-center text-white/40">
            <Sparkles className="mb-2 text-neon/60" size={34} />
            <p className="text-sm">Your videos appear here while they render.</p>
            <p className="mt-1 text-xs">Everything you make is also saved in the History tab.</p>
          </div>
        )}
        {jobs.map((j) => (
          <div key={j.uid}>
            {j.status === "done" ? (
              <VideoCard rec={j.rec} />
            ) : (
              <div className={`card flex items-center gap-3 ${j.status === "error" ? "border-pink/60" : ""}`}>
                {j.status === "error" ? <AlertTriangle className="shrink-0 text-pink" /> : <Loader2 className="shrink-0 animate-spin text-neon" />}
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm text-white">{j.status === "error" ? "Generation failed" : j.status === "queued" ? "Queued…" : "Rendering…"}{j.status !== "error" && <span className="ml-2 text-xs text-white/40"><Elapsed t0={j.t0} /></span>}</p>
                  <p className="truncate text-xs text-white/50">{j.status === "error" ? j.error : j.prompt}</p>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>

      <ConfirmModal open={confirm} onCancel={() => setConfirm(false)} onConfirm={start}
        rows={[["Model", model?.name || cfg.model], ["Duration", `${cfg.duration}s`], ["Resolution", `${cfg.resolution} · ${cfg.ratio}`], ["Style / camera", `${STYLES[cfg.style].label} / ${CAMERAS[cfg.camera].label}`], ["Mode", used.length ? (mode === "refs" ? `${used.length} reference image(s)` : "Image → Video (your photo)") : "Text → Video"]]}
        items={[full]} usd={est.usd} credits={est.credits} free={est.free} />
    </div>
  );
}
