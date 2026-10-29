"use client";
import { useRef, useState } from "react";
import { Wand2, Loader2, ArrowUp, ArrowDown, Trash2, Plus, Film, Play, AlertTriangle, CheckCircle2, RefreshCw } from "lucide-react";
import ConfigFields from "./ConfigFields";
import ImagePicker from "./ImagePicker";
import ConfirmModal from "./ConfirmModal";
import VideoCard from "./VideoCard";
import { STYLES, CAMERAS, buildPrompt } from "@/lib/prompt";
import { estimate, fmtUsd, runVideo, newId, modelCaps, uploadBlob } from "@/lib/revana";
import { extractLastFrame } from "@/lib/frames";
import { planStory } from "@/lib/agent";
import { mergeVideos } from "@/lib/merge";
import { addVideo } from "@/lib/storage";

const CONCURRENCY = 2;

export default function Agent({ settings, models, cfg, setCfg, onNeedKey, onSaved }) {
  const [idea, setIdea] = useState("");
  const [count, setCount] = useState(5);
  const [planning, setPlanning] = useState(false);
  const [err, setErr] = useState("");
  const [story, setStory] = useState(null); // {title, characters, scenes:[{id,prompt,duration}]}
  const [st, setSt] = useState({}); // sceneId -> {status, blob, msg}
  const [confirm, setConfirm] = useState(false);
  const [running, setRunning] = useState(false);
  const [merging, setMerging] = useState(false);
  const [mergeP, setMergeP] = useState(0);
  const [final, setFinal] = useState(null);
  const blobs = useRef({});
  const frames = useRef({}); // sceneId -> url of its last frame (for chaining)
  const [refs, setRefs] = useState([]);
  const [chain, setChain] = useState(false);

  const model = models.find((m) => m.id === cfg.model);
  const scenes = story?.scenes || [];
  const caps = modelCaps(model);
  const canChain = caps.start;
  const useRefs = refs.length > 0 && caps.refs;
  const setScenes = (fn) => setStory((s) => ({ ...s, scenes: fn(s.scenes) }));
  const patchSt = (id, p) => setSt((s) => ({ ...s, [id]: { ...(s[id] || {}), ...p } }));
  const todo = scenes.filter((s) => st[s.id]?.status !== "done");
  const totalSec = todo.reduce((a, s) => a + s.duration, 0);
  const total = todo.reduce((a, s) => { const e = estimate(model, cfg.resolution, s.duration); return { usd: a.usd + e.usd, credits: a.credits + e.credits }; }, { usd: 0, credits: 0 });
  const free = estimate(model, cfg.resolution, 5).free;
  const allDone = scenes.length > 0 && scenes.every((s) => st[s.id]?.status === "done");

  async function plan() {
    if (!settings.nimKey) return onNeedKey("Add your NVIDIA NIM API key to use Agent mode.");
    setErr(""); setPlanning(true); setFinal(null); setSt({}); blobs.current = {}; frames.current = {};
    try {
      const out = await planStory({ key: settings.nimKey, model: settings.nimModel, idea, count, styleText: STYLES[cfg.style].text });
      setStory({ ...out, scenes: out.scenes.map((x) => ({ ...x, start: "auto" })) });
    } catch (e) { setErr(e.message); } finally { setPlanning(false); }
  }

  const edit = (id, p) => setScenes((ss) => ss.map((s) => (s.id === id ? { ...s, ...p } : s)));
  const move = (i, d) => setScenes((ss) => { const a = [...ss]; const j = i + d; if (j < 0 || j >= a.length) return a; [a[i], a[j]] = [a[j], a[i]]; return a; });
  const del = (id) => { setScenes((ss) => ss.filter((s) => s.id !== id)); delete blobs.current[id]; setFinal(null); };
  const add = () => setScenes((ss) => [...ss, { id: `s${Date.now()}`, prompt: "", duration: 5, start: "auto" }]);

  function ask() {
    if (!settings.revanaKey) return onNeedKey();
    if (!todo.length || todo.some((s) => !s.prompt.trim())) return;
    setConfirm(true);
  }

  async function genScene(s) {
    patchSt(s.id, { status: "running", msg: "" });
    try {
      const prompt = buildPrompt(s.prompt, cfg.style, cfg.camera);
      const input = { prompt, duration: s.duration, resolution: cfg.resolution, aspect_ratio: cfg.ratio };
      const idx = scenes.findIndex((x) => x.id === s.id);
      const prevFrame = chain && canChain && idx > 0 ? frames.current[scenes[idx - 1].id] : null;
      const picked = s.start && s.start !== "auto" && s.start !== "none" ? refs.find((r) => r.id === s.start) : null;
      if (s.start === "none") { /* text only */ }
      else if (picked && caps.start) input.image_url = picked.url;
      else if (prevFrame) input.image_url = prevFrame;
      else if (useRefs) input.image_urls = refs.slice(0, caps.maxRefs).map((r) => r.url);
      const { blob, gen } = await runVideo({ key: settings.revanaKey, model: cfg.model, input, onStatus: (g) => patchSt(s.id, { msg: g.status }) });
      blobs.current[s.id] = blob;
      if (chain && canChain) { try { frames.current[s.id] = await uploadBlob({ key: settings.revanaKey, blob: await extractLastFrame(blob), filename: "lastframe.jpg" }); } catch {} }
      const e = estimate(model, cfg.resolution, s.duration);
      await addVideo({ id: gen.id, kind: "scene", prompt, model: cfg.model, duration: s.duration, resolution: cfg.resolution, ratio: cfg.ratio, cost: gen.cost_usd ?? e.usd, free: e.free, createdAt: Date.now(), blob });
      patchSt(s.id, { status: "done", blob });
      onSaved?.();
    } catch (e) { patchSt(s.id, { status: "error", msg: e.message }); }
  }

  async function generateAll() {
    setConfirm(false); setRunning(true); setFinal(null);
    const queue = [...todo];
    const worker = async () => { while (queue.length) await genScene(queue.shift()); };
    await Promise.all(Array.from({ length: chain && canChain ? 1 : Math.min(CONCURRENCY, queue.length) }, worker));
    setRunning(false);
  }

  async function merge() {
    setMerging(true); setMergeP(0); setErr("");
    try {
      const ordered = scenes.map((s) => blobs.current[s.id]).filter(Boolean);
      const blob = await mergeVideos(ordered, { onProgress: setMergeP });
      const dur = scenes.reduce((a, s) => a + s.duration, 0);
      const rec = { id: `merged-${Date.now()}`, kind: "merged", prompt: story.title + " — " + scenes.map((s) => s.prompt).join(" | ").slice(0, 400), model: cfg.model, duration: dur, resolution: cfg.resolution, ratio: cfg.ratio, cost: 0, free, createdAt: Date.now(), blob };
      await addVideo(rec); setFinal(rec); onSaved?.();
    } catch (e) { setErr(`Merge failed: ${e.message}`); } finally { setMerging(false); }
  }

  return (
    <div className="grid gap-4 lg:grid-cols-[minmax(0,420px)_1fr]">
      <div className="card">
        <label className="lbl !mt-0">Your idea</label>
        <textarea className="inp min-h-[110px] resize-y" value={idea} onChange={(e) => setIdea(e.target.value)} placeholder="e.g. A lone swordsman crosses a ruined city to face a masked sorcerer at dawn…" />
        <label className="lbl">Scenes: <span className="text-white">{count}</span></label>
        <input type="range" min={2} max={12} value={count} onChange={(e) => setCount(Number(e.target.value))} className="w-full" />
        <ConfigFields models={models} cfg={cfg} setCfg={setCfg} showDuration={false} />
        <div className="mt-3 rounded-xl border border-line bg-panel2/60 p-3">
          <ImagePicker label="Characters / reference images" value={refs} onChange={setRefs} max={Math.max(caps.maxRefs, 4)} apiKey={settings.revanaKey} onNeedKey={onNeedKey}
            hint={caps.refs ? "Used in every scene so your characters stay consistent. You can also choose one as a scene's start frame." : "This model has no reference mode, but you can still use a photo as a scene's start frame."} />
          <label className={`mt-3 flex items-start gap-2 text-xs ${canChain ? "text-white/70" : "text-white/30"}`}>
            <input type="checkbox" className="mt-0.5" checked={chain && canChain} disabled={!canChain} onChange={(e) => setChain(e.target.checked)} />
            <span><b>Chain scenes</b>: last frame of each scene becomes the next scene&apos;s start frame (smoother story, but scenes render one after another).</span>
          </label>
        </div>
        <button className="btn-neon mt-5 w-full py-3" onClick={plan} disabled={planning || idea.trim().length < 5}>
          {planning ? <Loader2 className="animate-spin" size={18} /> : <Wand2 size={18} />} {planning ? "Planning the story…" : "Plan story with AI Agent"}
        </button>
        {err && <p className="mt-3 flex items-start gap-2 text-xs text-pink"><AlertTriangle size={14} className="mt-0.5 shrink-0" />{err}</p>}
      </div>

      <div className="space-y-3">
        {!story && (
          <div className="card flex min-h-[260px] flex-col items-center justify-center text-center text-white/40">
            <Wand2 className="mb-2 text-pink/70" size={34} />
            <p className="text-sm">The Agent turns one idea into a full story, scene by scene.</p>
            <p className="mt-1 text-xs">Then edit, reorder or delete scenes, generate them, and merge into one video.</p>
          </div>
        )}

        {story && (
          <>
            <div className="card">
              <input className="inp text-base font-bold" value={story.title} onChange={(e) => setStory((s) => ({ ...s, title: e.target.value }))} />
              {story.characters && <p className="mt-2 text-xs text-white/50"><b className="text-neon">Characters:</b> {story.characters}</p>}
              <p className="mt-1 text-xs text-white/40">{scenes.length} scenes · {scenes.reduce((a, s) => a + s.duration, 0)}s total</p>
            </div>

            {scenes.map((s, i) => {
              const x = st[s.id] || {};
              return (
                <div key={s.id} className={`card ${x.status === "error" ? "border-pink/60" : x.status === "done" ? "border-lime/40" : ""}`}>
                  <div className="mb-2 flex items-center gap-2">
                    <span className="grid h-7 w-7 place-items-center rounded-lg bg-neon/15 text-xs font-bold text-neon">{i + 1}</span>
                    <select className="inp !w-auto !py-1.5" value={s.duration} onChange={(e) => edit(s.id, { duration: Number(e.target.value) })} disabled={x.status === "running"}>
                      {Array.from({ length: 11 }, (_, k) => k + 5).map((d) => <option key={d} value={d}>{d}s</option>)}
                    </select>
                    <select className="inp !w-auto max-w-[44%] !py-1.5 text-xs" value={s.start || "auto"} onChange={(e) => edit(s.id, { start: e.target.value })} disabled={x.status === "running"} title="Start frame for this scene">
                      <option value="auto">Start: auto</option>
                      <option value="none">Start: text only</option>
                      {refs.map((r, k) => <option key={r.id} value={r.id}>Start: image {k + 1}</option>)}
                    </select>
                    <div className="ml-auto flex gap-1">
                      <button className="btn-ghost !p-2" onClick={() => move(i, -1)} disabled={i === 0 || running} aria-label="Move up"><ArrowUp size={14} /></button>
                      <button className="btn-ghost !p-2" onClick={() => move(i, 1)} disabled={i === scenes.length - 1 || running} aria-label="Move down"><ArrowDown size={14} /></button>
                      <button className="btn-danger !p-2" onClick={() => del(s.id)} disabled={running} aria-label="Delete"><Trash2 size={14} /></button>
                    </div>
                  </div>
                  <textarea className="inp min-h-[84px] resize-y text-xs" value={s.prompt} onChange={(e) => { edit(s.id, { prompt: e.target.value }); if (x.status === "done") { patchSt(s.id, { status: "idle" }); delete blobs.current[s.id]; setFinal(null); } }} disabled={x.status === "running"} />
                  <div className="mt-2 flex items-center gap-2 text-xs">
                    {x.status === "running" && <span className="flex items-center gap-1.5 text-neon"><Loader2 className="animate-spin" size={14} />{x.msg || "starting"}…</span>}
                    {x.status === "done" && <span className="flex items-center gap-1.5 text-lime"><CheckCircle2 size={14} />Ready</span>}
                    {x.status === "error" && <span className="flex items-center gap-1.5 text-pink"><AlertTriangle size={14} />{x.msg}</span>}
                    {(x.status === "error" || x.status === "done") && !running && (
                      <button className="btn-ghost ml-auto !px-2.5 !py-1.5 text-xs" onClick={() => genScene(s)}><RefreshCw size={12} /> Redo</button>
                    )}
                  </div>
                  {x.status === "done" && x.blob && <ScenePreview blob={x.blob} ratio={cfg.ratio} />}
                </div>
              );
            })}

            <button className="btn-ghost w-full" onClick={add} disabled={running}><Plus size={16} /> Add scene</button>

            <div className="card space-y-2">
              <button className="btn-neon w-full py-3" onClick={ask} disabled={running || !todo.length}>
                {running ? <Loader2 className="animate-spin" size={18} /> : <Play size={18} />}
                {running ? "Generating scenes…" : todo.length === scenes.length ? `Generate all ${scenes.length} scenes` : `Generate remaining ${todo.length}`}
                {!running && <span className="opacity-70">· {free ? "FREE" : fmtUsd(total.usd)}</span>}
              </button>
              <button className="btn-ghost w-full py-3" onClick={merge} disabled={!allDone || merging || running}>
                {merging ? <Loader2 className="animate-spin" size={18} /> : <Film size={18} />}
                {merging ? `Merging… ${Math.round(mergeP * 100)}%` : "Merge into one final video"}
              </button>
              {!allDone && <p className="text-center text-[11px] text-white/40">Merge unlocks when every scene is ready.</p>}
            </div>
            {final && <VideoCard rec={final} />}
          </>
        )}
      </div>

      <ConfirmModal open={confirm} onCancel={() => setConfirm(false)} onConfirm={generateAll} title="Confirm & generate all scenes"
        rows={[["Scenes", `${todo.length} · ${totalSec}s`], ["Model", model?.name || cfg.model], ["Resolution", `${cfg.resolution} · ${cfg.ratio}`], ["Style / camera", `${STYLES[cfg.style].label} / ${CAMERAS[cfg.camera].label}`], ["Images", useRefs ? `${refs.length} character ref(s)` : refs.length ? "start frames" : "none (text → video)"], ["Mode", chain && canChain ? "Chained, one by one" : `Up to ${CONCURRENCY} at a time`]]}
        items={todo.map((s) => buildPrompt(s.prompt, cfg.style, cfg.camera))} usd={total.usd} credits={total.credits} free={free} />
    </div>
  );
}

function ScenePreview({ blob, ratio }) {
  const [url] = useState(() => URL.createObjectURL(blob));
  return <video src={url} controls playsInline preload="metadata" className="mt-2 w-full rounded-xl bg-black" style={{ aspectRatio: ratio.replace(":", "/"), maxHeight: 280 }} />;
}
