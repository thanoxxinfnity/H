"use client";
import { useEffect, useRef, useState } from "react";
import { Sparkles, Wand2, Loader2, ArrowUp, ArrowDown, Trash2, Plus, Film, Play, AlertTriangle, CheckCircle2, RefreshCw, Send, Bot, User } from "lucide-react";
import ConfigFields from "./ConfigFields";
import ImagePicker from "./ImagePicker";
import ConfirmModal from "./ConfirmModal";
import VideoCard from "./VideoCard";
import { STYLES, CAMERAS, buildPrompt } from "@/lib/prompt";
import { estimate, fmtUsd, runVideo, newId, modelCaps, uploadBlob, mediaSupport, mediaInput } from "@/lib/revana";
import NimSelect from "./NimSelect";
import { extractLastFrame } from "@/lib/frames";
import { directorChat, expandStory, rewriteScene } from "@/lib/agent";
import { PROVIDERS, activeProvider, llmReady } from "@/lib/llm";
import { mergeVideos } from "@/lib/merge";
import { addVideo, getVideo } from "@/lib/storage";
import { dropPending, pendingJobs, resumeJob } from "@/lib/jobs";

const SAVE_KEY = "avs.agent.v1";

const CONCURRENCY = 2;

export default function Agent({ settings, models, cfg, setCfg, onNeedKey, onSaved, live, patchSettings }) {
  const [msgs, setMsgs] = useState([{ role: "assistant", content: "Hi! Main tumhara AI Director hoon \ud83c\udfac Bata kya video/story banani hai - characters, mood, style. Main puchh puchh ke accha prompt bana dunga, aur tum bologe \"bana do\" to generation start kar dunga." }]);
  const [draft, setDraft] = useState("");
  const [thinking, setThinking] = useState(false);
  const [wantGen, setWantGen] = useState(false);
  const chatEnd = useRef(null);
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
  const [chain, setChain] = useState(true);
  const [thinkMsg, setThinkMsg] = useState("");
  const stopRef = useRef(false);
  const genIds = useRef({}); // sceneId -> Revana generation id
  const [restored, setRestored] = useState(false);
  const autoResume = useRef(false);

  const model = models.find((m) => m.id === cfg.model);
  const scenes = story?.scenes || [];
  const caps = modelCaps(model);
  const canChain = caps.start;
  const sup = mediaSupport(model);
  const kinds = ["image", ...(sup.video ? ["video"] : []), ...(sup.audio ? ["audio"] : [])];
  const refImgs = refs.filter((r) => (r.kind || "image") === "image");
  const useRefs = refImgs.length > 0 && caps.refs;
  const doneCount = scenes.filter((s) => st[s.id]?.status === "done").length;
  const [rewriting, setRewriting] = useState("");
  const setScenes = (fn) => setStory((s) => ({ ...s, scenes: fn(s.scenes) }));
  const patchSt = (id, p) => setSt((s) => ({ ...s, [id]: { ...(s[id] || {}), ...p } }));
  const todo = scenes.filter((s) => st[s.id]?.status !== "done");
  const totalSec = todo.reduce((a, s) => a + s.duration, 0);
  const total = todo.reduce((a, s) => { const e = estimate(model, cfg.resolution, s.duration); return { usd: a.usd + e.usd, credits: a.credits + e.credits }; }, { usd: 0, credits: 0 });
  const free = estimate(model, cfg.resolution, 5).free;
  const allDone = scenes.length > 0 && scenes.every((s) => st[s.id]?.status === "done");

  useEffect(() => {
    if (!running) return;
    const h = (e) => { e.preventDefault(); e.returnValue = ""; };
    window.addEventListener("beforeunload", h);
    return () => window.removeEventListener("beforeunload", h);
  }, [running]);
  const prov = activeProvider(settings);
  const providerKey = `${settings.provider === "gemini" ? "gemini" : "nim"}`;
  useEffect(() => { chatEnd.current?.scrollIntoView({ block: "nearest", behavior: "smooth" }); }, [msgs, thinking]);

  async function send(text) {
    text = (text ?? draft).trim();
    if (!text || thinking) return;
    if (!llmReady(settings)) return onNeedKey(`Add your ${prov.label} API key in Settings to chat with the Director.`);
    setErr(""); setDraft("");
    const history = [...msgs, { role: "user", content: text }];
    setMsgs(history); setThinking(true);
    try {
      const out = await directorChat({ settings, history, story, styleText: STYLES[cfg.style].text });
      setMsgs([...history, { role: "assistant", content: out.reply }]);
      let next = story;
      if (out.story) {
        const old = story?.scenes || [];
        next = { ...out.story, scenes: out.story.scenes.map((x, i) => (old[i] && old[i].prompt.trim() === x.prompt.trim() && old[i].duration === x.duration ? old[i] : { ...x, start: "auto" })) };
        setStory(next); setFinal(null);
      }
      if (next && out.totalSeconds && next.scenes.reduce((a, x) => a + x.duration, 0) < out.totalSeconds - 4) {
        setThinkMsg("Poori movie ke scenes likh raha hoon…");
        const full = await expandStory({ settings, story: next, totalSeconds: out.totalSeconds, styleText: STYLES[cfg.style].text, onProgress: (d, t) => setThinkMsg(`Movie ke scenes likh raha hoon… ${Math.round(d)}s / ${Math.round(t)}s`) });
        full.scenes = full.scenes.map((x) => ({ start: "auto", ...x }));
        setStory(full); setFinal(null); next = full;
        setMsgs((m) => [...m, { role: "assistant", content: `Poori movie ka storyboard ready: ${full.scenes.length} scenes, ${full.scenes.reduce((a, x) => a + x.duration, 0)}s. Har scene pichle scene ke last frame se continue hoga. "bana do" bolo to generation shuru kar dunga (background me chalta rahega).` }]);
      }
      if (out.generate) setWantGen(true);
    } catch (e) { setErr(e.message); setMsgs(history); } finally { setThinking(false); setThinkMsg(""); }
  }
  useEffect(() => {
    if (!wantGen || thinking) return;
    setWantGen(false);
    if (story && todo.length) ask();
  }, [wantGen, story, thinking]); // eslint-disable-line react-hooks/exhaustive-deps

  async function aiRewrite(s) {
    if (!llmReady(settings)) return onNeedKey(`Add your ${prov.label} API key to use AI rewrite.`);
    setRewriting(s.id);
    try { edit(s.id, { prompt: await rewriteScene({ settings, prompt: s.prompt, characters: story?.characters, styleText: STYLES[cfg.style].text }) }); }
    catch (e) { setErr(e.message); } finally { setRewriting(""); }
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

  const runningRef = useRef(false);
  function save(extra = {}) {
    if (extra.running !== undefined) runningRef.current = extra.running;
    try { if (story) localStorage.setItem(SAVE_KEY, JSON.stringify({ story, msgs: msgs.slice(-40), gen: genIds.current, running: runningRef.current, chain })); } catch {}
  }
  useEffect(() => { save(); }, [story, msgs, chain]); // eslint-disable-line react-hooks/exhaustive-deps

  // Bring back the story and collect scenes that finished while the tab was closed.
  useEffect(() => {
    let saved = null;
    try { saved = JSON.parse(localStorage.getItem(SAVE_KEY) || "null"); } catch {}
    if (!saved?.story?.scenes?.length) return setRestored(true);
    setStory(saved.story); if (saved.msgs?.length) setMsgs(saved.msgs); setChain(saved.chain !== false);
    genIds.current = saved.gen || {};
    runningRef.current = !!saved.running;
    (async () => {
      const pend = Object.fromEntries(pendingJobs().map((j) => [j.id, j]));
      await Promise.all(saved.story.scenes.map(async (sc) => {
        const gid = saved.gen?.[sc.id]; if (!gid) return;
        try {
          const rec = await getVideo(gid);
          if (rec?.blob) { blobs.current[sc.id] = rec.blob; return patchSt(sc.id, { status: "done", blob: rec.blob }); }
          if (pend[gid] && settings.revanaKey) {
            patchSt(sc.id, { status: "running", msg: "resuming" });
            const r = await resumeJob({ key: settings.revanaKey, id: gid, onStatus: (g) => patchSt(sc.id, { msg: g.status }) });
            if (r?.blob) { blobs.current[sc.id] = r.blob; patchSt(sc.id, { status: "done", blob: r.blob }); onSaved?.(); }
          }
        } catch (e) { patchSt(sc.id, { status: "error", msg: e.message }); }
      }));
      if (saved.running) autoResume.current = true;
      setRestored(true);
    })();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (!restored || !autoResume.current || !settings.revanaKey) return;
    autoResume.current = false;
    if (story && todo.length && !running) generateAll();
  }, [restored]); // eslint-disable-line react-hooks/exhaustive-deps

  async function lastFrameUrl(id) {
    if (frames.current[id]) return frames.current[id];
    const blob = blobs.current[id];
    if (!blob) return null;
    let lastErr;
    for (let t = 0; t < 2; t++) {
      try { return (frames.current[id] = await uploadBlob({ key: settings.revanaKey, blob: await extractLastFrame(blob), filename: "lastframe.jpg" })); }
      catch (e) { lastErr = e; }
    }
    throw lastErr;
  }

  async function genScene(s, attempt = 0) {
    patchSt(s.id, { status: "running", msg: attempt ? `retry ${attempt}` : "" });
    try {
      const prompt = buildPrompt(s.prompt, cfg.style, cfg.camera);
      const input = { prompt, duration: s.duration, resolution: cfg.resolution, aspect_ratio: cfg.ratio };
      const idx = scenes.findIndex((x) => x.id === s.id);
      const prevFrame = chain && canChain && idx > 0 && (!s.start || s.start === "auto") ? await lastFrameUrl(scenes[idx - 1].id).catch(() => null) : null;
      const picked = s.start && s.start !== "auto" && s.start !== "none" ? refImgs.find((r) => r.id === s.start) : null;
      const others = refs.filter((r) => r.kind && r.kind !== "image");
      if (s.start === "none") Object.assign(input, mediaInput(model, others));
      else if (picked) Object.assign(input, mediaInput(model, [...others, ...refImgs], { startOverride: picked.url }));
      else if (prevFrame) Object.assign(input, mediaInput(model, others, { startOverride: prevFrame }));
      else Object.assign(input, mediaInput(model, refs, { mode: "refs" }));
      const { blob, gen } = await runVideo({ key: settings.revanaKey, model: cfg.model, input, onStatus: (g) => patchSt(s.id, { msg: g.status }), onCreated: (id) => { genIds.current[s.id] = id; save(); },
        meta: { kind: "scene", prompt, model: cfg.model, duration: s.duration, resolution: cfg.resolution, ratio: cfg.ratio, cost: estimate(model, cfg.resolution, s.duration).usd, free: estimate(model, cfg.resolution, s.duration).free } });
      blobs.current[s.id] = blob;
      const e = estimate(model, cfg.resolution, s.duration);
      await addVideo({ id: gen.id, kind: "scene", prompt, model: cfg.model, duration: s.duration, resolution: cfg.resolution, ratio: cfg.ratio, cost: gen.cost_usd ?? e.usd, free: e.free, createdAt: Date.now(), blob });
      dropPending(gen.id);
      patchSt(s.id, { status: "done", blob });
      onSaved?.();
    } catch (e) {
      if (attempt < 2 && !stopRef.current) { await new Promise((r) => setTimeout(r, 3000)); return genScene(s, attempt + 1); }
      patchSt(s.id, { status: "error", msg: e.message });
    }
  }

  async function generateAll() {
    setConfirm(false); setRunning(true); setFinal(null); stopRef.current = false; save({ running: true });
    const queue = [...todo];
    const worker = async () => { while (queue.length && !stopRef.current) await genScene(queue.shift()); };
    await Promise.all(Array.from({ length: chain && canChain ? 1 : Math.min(CONCURRENCY, queue.length) }, worker));
    setRunning(false); save({ running: false });
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
    <div className="space-y-4">
      <div className="card">
        <div className="mb-2 flex items-center gap-2 text-sm font-bold text-white"><Bot size={16} className="text-pink" /> Chat with your Director <span className="ml-auto text-[10px] font-normal text-white/40">{prov.label} · {settings[prov.modelField]}</span></div>
        <div className="max-h-[360px] min-h-[140px] space-y-2 overflow-y-auto rounded-xl border border-line bg-ink/60 p-3">
          {msgs.map((m, i) => (
            <div key={i} className={`flex gap-2 ${m.role === "user" ? "flex-row-reverse" : ""}`}>
              <span className={`mt-0.5 grid h-6 w-6 shrink-0 place-items-center rounded-full ${m.role === "user" ? "bg-neon/20 text-neon" : "bg-pink/20 text-pink"}`}>{m.role === "user" ? <User size={13} /> : <Bot size={13} />}</span>
              <p className={`max-w-[85%] whitespace-pre-wrap break-words rounded-2xl px-3 py-2 text-[13px] leading-snug ${m.role === "user" ? "bg-neon/10 text-white" : "bg-panel2 text-white/85"}`}>{m.content}</p>
            </div>
          ))}
          {thinking && <p className="flex items-center gap-2 text-xs text-white/50"><Loader2 className="animate-spin" size={13} /> {thinkMsg || "Director soch raha hai…"}</p>}
          <div ref={chatEnd} />
        </div>
        {story && !thinking && (
          <div className="mt-2 flex flex-wrap gap-1.5">
            {["Bana do, generate karo", "Aur dramatic banao", "Ek scene aur add karo"].map((q) => <button key={q} className="chip" onClick={() => send(q)}>{q}</button>)}
          </div>
        )}
        <form className="mt-2 flex gap-2" onSubmit={(e) => { e.preventDefault(); send(); }}>
          <input className="inp" value={draft} onChange={(e) => setDraft(e.target.value)} placeholder="Apna idea likho… (e.g. ek lone swordsman, ruined city, dawn)" />
          <button className="btn-neon px-4" type="submit" disabled={thinking || !draft.trim()} aria-label="Send">{thinking ? <Loader2 className="animate-spin" size={16} /> : <Send size={16} />}</button>
        </form>
        {err && <p className="mt-2 flex items-start gap-2 text-xs text-pink"><AlertTriangle size={14} className="mt-0.5 shrink-0" />{err}</p>}
      </div>
    <div className="grid gap-4 lg:grid-cols-[minmax(0,420px)_1fr]">
      <div className="card">
        <label className="lbl !mt-0">Director AI</label>
        <div className="mb-2 flex gap-2">
          {Object.entries(PROVIDERS).map(([k, p]) => (
            <button key={k} type="button" onClick={() => patchSettings({ provider: k })} className={`btn flex-1 !py-2 text-xs ${settings.provider === k ? "bg-neon/15 text-neon ring-1 ring-neon" : "border border-line bg-panel2 text-white/60"}`}>{p.label}</button>
          ))}
        </div>
        <NimSelect nim={live[providerKey]} label={prov.label} value={settings[prov.modelField]} onChange={(v) => patchSettings({ [prov.modelField]: v })} placeholder={providerKey === "gemini" ? "gemini-2.5-flash" : "meta/llama-3.3-70b-instruct"} />
        <ConfigFields models={models} cfg={cfg} setCfg={setCfg} showDuration={false} />
        <div className="mt-3 rounded-xl border border-line bg-panel2/60 p-3">
          <ImagePicker kinds={kinds} label="Characters / reference files" value={refs} onChange={setRefs} max={Math.max(caps.maxRefs, 4) + 4} apiKey={settings.revanaKey} onNeedKey={onNeedKey}
            hint={caps.refs ? "Used in every scene so characters stay consistent. You can also pick one as a scene's start frame." : "This model has no reference mode, but a photo can still be a scene's start frame."} />
          <label className={`mt-3 flex items-start gap-2 text-xs ${canChain ? "text-white/70" : "text-white/30"}`}>
            <input type="checkbox" className="mt-0.5" checked={chain && canChain} disabled={!canChain} onChange={(e) => setChain(e.target.checked)} />
            <span><b>Chain scenes</b>: last frame of each scene becomes the next scene&apos;s start frame (smoother story, but scenes render one after another).</span>
          </label>
        </div>
      </div>

      <div className="space-y-3">
        {!story && (
          <div className="card flex min-h-[260px] flex-col items-center justify-center text-center text-white/40">
            <Wand2 className="mb-2 text-pink/70" size={34} />
            <p className="text-sm">Chat with the Director above - your storyboard appears here.</p>
            <p className="mt-1 text-xs">Edit, reorder or delete scenes, generate them, and merge into one video.</p>
          </div>
        )}

        {story && (
          <>
            <div className="card">
              <input className="inp text-base font-bold" value={story.title} onChange={(e) => setStory((s) => ({ ...s, title: e.target.value }))} />
              {story.characters && <p className="mt-2 text-xs text-white/50"><b className="text-neon">Characters:</b> {story.characters}</p>}
              <p className="mt-1 text-xs text-white/40">{scenes.length} scenes · {scenes.reduce((a, s) => a + s.duration, 0)}s total · {doneCount}/{scenes.length} ready</p>
              <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-panel2"><div className="h-full bg-gradient-to-r from-neon to-pink transition-all" style={{ width: `${scenes.length ? (doneCount / scenes.length) * 100 : 0}%` }} /></div>
              <div className="mt-3 flex gap-1.5 text-[10px] font-semibold uppercase tracking-wider">
                {[["1 Plan", true], ["2 Edit", true], ["3 Generate", running || doneCount > 0], ["4 Merge", !!final || merging]].map(([l, on]) => <span key={l} className={`rounded-full border px-2.5 py-1 ${on ? "border-neon/60 bg-neon/10 text-neon" : "border-line text-white/30"}`}>{l}</span>)}
              </div>
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
                      {refImgs.map((r, k) => <option key={r.id} value={r.id}>Start: image {k + 1}</option>)}
                    </select>
                    <div className="ml-auto flex gap-1">
                      <button className="btn-ghost !p-2" onClick={() => move(i, -1)} disabled={i === 0 || running} aria-label="Move up"><ArrowUp size={14} /></button>
                      <button className="btn-ghost !p-2" onClick={() => move(i, 1)} disabled={i === scenes.length - 1 || running} aria-label="Move down"><ArrowDown size={14} /></button>
                      <button className="btn-danger !p-2" onClick={() => del(s.id)} disabled={running} aria-label="Delete"><Trash2 size={14} /></button>
                    </div>
                  </div>
                  <textarea className="inp min-h-[84px] resize-y text-xs" value={s.prompt} onChange={(e) => { edit(s.id, { prompt: e.target.value }); if (x.status === "done") { patchSt(s.id, { status: "idle" }); delete blobs.current[s.id]; setFinal(null); } }} disabled={x.status === "running"} />
                  <div className="mt-2 flex items-center gap-2 text-xs">
                    <button className="btn-ghost !px-2.5 !py-1.5 text-xs" onClick={() => aiRewrite(s)} disabled={running || x.status === "running" || rewriting === s.id}>{rewriting === s.id ? <Loader2 size={12} className="animate-spin" /> : <Sparkles size={12} />} AI rewrite</button>
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
              {running && <button className="btn-danger w-full py-2.5" onClick={() => { stopRef.current = true; }}>Stop after current scene</button>}
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
    </div>
  );
}

function ScenePreview({ blob, ratio }) {
  const [url] = useState(() => URL.createObjectURL(blob));
  return <video src={url} controls playsInline preload="metadata" className="mt-2 w-full rounded-xl bg-black" style={{ aspectRatio: ratio.replace(":", "/"), maxHeight: 280 }} />;
}
