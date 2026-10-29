"use client";
import { STYLES, CAMERAS } from "@/lib/prompt";

const RATIOS = ["16:9", "9:16", "1:1"];

export function modelLimits(model) {
  const o = model?.options || {};
  const dMin = Math.max(5, o.durations?.min ?? 5);
  const dMax = Math.min(15, o.durations?.max ?? 15);
  const resolutions = o.resolutions?.length ? o.resolutions : ["720p"];
  const ratios = (o.aspect_ratios || RATIOS).filter((r) => RATIOS.includes(r));
  return { dMin, dMax: Math.max(dMin, dMax), resolutions, ratios: ratios.length ? ratios : RATIOS };
}

/** Clamp a config to what the chosen model supports. */
export function fitConfig(cfg, model) {
  const { dMin, dMax, resolutions, ratios } = modelLimits(model);
  return {
    ...cfg,
    duration: Math.min(dMax, Math.max(dMin, cfg.duration)),
    resolution: resolutions.includes(cfg.resolution) ? cfg.resolution : resolutions.includes("480p") ? "480p" : resolutions[0],
    ratio: ratios.includes(cfg.ratio) ? cfg.ratio : ratios[0],
  };
}

function Chips({ options, value, onChange }) {
  return (
    <div className="flex flex-wrap gap-2">
      {options.map(([v, l]) => (
        <button key={v} type="button" onClick={() => onChange(v)}
          className={`chip ${value === v ? "border-neon bg-neon/15 text-neon shadow-neon" : "border-line bg-panel2 text-white/70 hover:border-neon/60"}`}>{l}</button>
      ))}
    </div>
  );
}

export default function ConfigFields({ models, cfg, setCfg, showDuration = true }) {
  const model = models.find((m) => m.id === cfg.model);
  const { dMin, dMax, resolutions, ratios } = modelLimits(model);
  const upd = (patch) => setCfg((c) => fitConfig({ ...c, ...patch }, models.find((m) => m.id === (patch.model ?? c.model))));
  return (
    <div>
      <label className="lbl">Model</label>
      <select className="inp" value={cfg.model} onChange={(e) => upd({ model: e.target.value })}>
        {[...models].sort((a, b) => (b.price?.free ? 1 : 0) - (a.price?.free ? 1 : 0)).map((m) => (
          <option key={m.id} value={m.id}>{m.name || m.id}{m.price?.free ? "  (FREE)" : ""}</option>
        ))}
        {!model && <option value={cfg.model}>{cfg.model}</option>}
      </select>
      {showDuration && (
        <>
          <label className="lbl">Duration: <span className="text-white">{cfg.duration}s</span></label>
          <input type="range" min={dMin} max={dMax} step={1} value={cfg.duration} disabled={dMin === dMax}
            onChange={(e) => upd({ duration: Number(e.target.value) })} className="w-full" />
          <div className="flex justify-between text-[10px] text-white/40"><span>{dMin}s</span><span>{dMax}s</span></div>
        </>
      )}
      <label className="lbl">Aspect ratio</label>
      <Chips options={ratios.map((r) => [r, r])} value={cfg.ratio} onChange={(v) => upd({ ratio: v })} />
      <label className="lbl">Resolution</label>
      <Chips options={resolutions.map((r) => [r, r])} value={cfg.resolution} onChange={(v) => upd({ resolution: v })} />
      <label className="lbl">Style</label>
      <Chips options={Object.entries(STYLES).map(([k, v]) => [k, v.label])} value={cfg.style} onChange={(v) => upd({ style: v })} />
      <label className="lbl">Camera movement</label>
      <Chips options={Object.entries(CAMERAS).map(([k, v]) => [k, v.label])} value={cfg.camera} onChange={(v) => upd({ camera: v })} />
    </div>
  );
}
