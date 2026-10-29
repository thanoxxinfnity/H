"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import { Clapperboard, Wand2, History as HistoryIcon, Settings, Zap } from "lucide-react";
import Create from "@/components/Create";
import Agent from "@/components/Agent";
import History from "@/components/History";
import SettingsModal from "@/components/SettingsModal";
import { fitConfig } from "@/components/ConfigFields";
import { loadSettings, saveSettings, DEFAULT_SETTINGS } from "@/lib/storage";
import { listVideoModels, getBalance } from "@/lib/revana";
import { fetchNimModels, pickFallback } from "@/lib/nimModels";
import { fetchGeminiModels, pickGeminiFallback } from "@/lib/gemini";
import { pendingJobs, resumeJob } from "@/lib/jobs";
import { useLiveModels } from "@/lib/useLiveModels";

const TABS = [["create", "Create", Clapperboard], ["agent", "Agent", Wand2], ["history", "History", HistoryIcon]];

export default function Page() {
  const [tab, setTab] = useState("create");
  const [visited, setVisited] = useState({});
  const [settings, setSettings] = useState(DEFAULT_SETTINGS);
  const [ready, setReady] = useState(false);
  const [showSettings, setShowSettings] = useState(false);
  const [notice, setNotice] = useState("");
  const [models, setModels] = useState([]);
  const [modelErr, setModelErr] = useState("");
  const [cfg, setCfg] = useState({ model: "minimax-h3-free", duration: 5, resolution: "480p", ratio: "16:9", style: "anime", camera: "none" });
  const [prompt, setPrompt] = useState("");
  const [hKey, setHKey] = useState(0);
  const [bal, setBal] = useState(null);

  useEffect(() => { const s = loadSettings(); setSettings(s); setCfg((c) => ({ ...c, model: s.defaultModel || c.model })); setReady(true); }, []);
  useEffect(() => {
    listVideoModels().then((m) => {
      setModels(m);
      setCfg((c) => { const pick = m.find((x) => x.id === c.model) || m.find((x) => x.price?.free) || m[0]; return pick ? fitConfig({ ...c, model: pick.id }, pick) : c; });
    }).catch((e) => setModelErr(e.message));
  }, []);
  const [nimNotice, setNimNotice] = useState("");
  const settingsRef = useRef(settings);
  settingsRef.current = settings;
  const patchSettings = useCallback((p) => { const n = { ...settingsRef.current, ...p }; settingsRef.current = n; setSettings(n); saveSettings(n); }, []);
  const nim = useLiveModels({ id: "nim", enabled: ready, fetcher: () => fetchNimModels(settings.nimKey), fallback: pickFallback, current: settings.nimModel, setCurrent: (v) => patchSettings({ nimModel: v }), onNotice: (m) => setNimNotice(`Model list updated - NVIDIA: ${m}`) });
  const gemini = useLiveModels({ id: "gemini", enabled: ready && !!settings.geminiKey, fetcher: () => fetchGeminiModels(settings.geminiKey), fallback: pickGeminiFallback, current: settings.geminiModel, setCurrent: (v) => patchSettings({ geminiModel: v }), onNotice: (m) => setNimNotice(`Model list updated - Gemini: ${m}`) });
  const live = { nim, gemini };

  const refreshBal = useCallback(() => {
    if (!settings.revanaKey) return setBal(null);
    getBalance(settings.revanaKey).then((b) => setBal(b.available_usd ?? b.balance_usd ?? null)).catch(() => setBal(null));
  }, [settings.revanaKey]);
  useEffect(() => { if (ready) refreshBal(); }, [ready, refreshBal]);

  useEffect(() => {
    if (!ready || !settings.revanaKey) return;
    const jobs = pendingJobs().filter((j) => j.kind !== "scene");
    if (!jobs.length) return;
    setNimNotice(`Picking up ${jobs.length} video(s) that were generating while the site was closed...`);
    jobs.forEach((j) => resumeJob({ key: settings.revanaKey, id: j.id }).then((r) => { if (r) { onSaved(); setNimNotice("Finished video saved to History."); } }).catch(() => {}));
  }, [ready, settings.revanaKey]); // eslint-disable-line react-hooks/exhaustive-deps

  const needKey = (msg) => { setNotice(msg || "Add your Revana API key in Settings to generate videos."); setShowSettings(true); };
  const onSaved = () => { setHKey((k) => k + 1); refreshBal(); };
  const reuse = (rec) => { setPrompt(rec.prompt); setTab("create"); window.scrollTo({ top: 0, behavior: "smooth" }); };

  return (
    <div className="mx-auto min-h-dvh max-w-6xl px-3 pb-24 pt-3 sm:px-6 sm:pb-10">
      <header className="mb-4 flex items-center gap-3">
        <div className="grid h-10 w-10 place-items-center rounded-xl bg-gradient-to-br from-neon to-pink shadow-neon"><Clapperboard size={20} className="text-black" /></div>
        <div className="min-w-0">
          <h1 className="truncate text-lg font-extrabold leading-tight tracking-tight text-white">AI VIDEO <span className="text-neon">STUDIO</span></h1>
          <p className="truncate text-[11px] text-white/40">prompt → video · agent → full story</p>
        </div>
        <div className="ml-auto flex items-center gap-2">
          {bal != null && <span className="hidden items-center gap-1 rounded-full border border-lime/40 bg-lime/10 px-3 py-1.5 text-xs font-semibold text-lime sm:flex"><Zap size={13} />{bal}</span>}
          <button className="btn-ghost !p-2.5" onClick={() => { setNotice(""); setShowSettings(true); }} aria-label="Settings"><Settings size={18} /></button>
        </div>
      </header>

      <nav className="mb-4 hidden gap-2 sm:flex">
        {TABS.map(([k, l, I]) => (
          <button key={k} onClick={() => { setTab(k); setVisited((v) => ({ ...v, [k]: true })); }} className={`btn ${tab === k ? "bg-neon/15 text-neon shadow-neon ring-1 ring-neon" : "border border-line bg-panel2 text-white/60 hover:text-white"}`}><I size={16} />{l}</button>
        ))}
      </nav>

      {ready && !settings.revanaKey && (
        <button onClick={() => needKey()} className="mb-4 w-full rounded-xl border border-pink/50 bg-pink/10 px-4 py-3 text-left text-sm text-pink">
          Add your <b>Revana API key</b> in Settings to start generating. Free model <code>minimax-h3-free</code> costs $0.
        </button>
      )}
      {nimNotice && <p className="mb-3 flex items-start gap-2 rounded-xl border border-lime/40 bg-lime/10 px-3 py-2 text-xs text-lime"><span className="flex-1 break-words">{nimNotice}</span><button onClick={() => setNimNotice("")} aria-label="Dismiss">x</button></p>}
      {modelErr && <p className="mb-3 text-xs text-pink">Could not load models: {modelErr}</p>}

      {ready && tab === "create" && <Create settings={settings} models={models} cfg={cfg} setCfg={setCfg} prompt={prompt} setPrompt={setPrompt} onNeedKey={needKey} onSaved={onSaved} />}
      {ready && (tab === "agent" || visited.agent) && <div className={tab === "agent" ? "" : "hidden"}><Agent live={live} patchSettings={patchSettings} settings={settings} models={models} cfg={cfg} setCfg={setCfg} onNeedKey={needKey} onSaved={onSaved} /></div>}
      {ready && tab === "history" && <History refreshKey={hKey} onReuse={reuse} />}

      <nav className="fixed inset-x-0 bottom-0 z-40 grid grid-cols-3 border-t border-line bg-ink/95 px-2 pb-[env(safe-area-inset-bottom)] backdrop-blur sm:hidden">
        {TABS.map(([k, l, I]) => (
          <button key={k} onClick={() => { setTab(k); setVisited((v) => ({ ...v, [k]: true })); }} className={`flex flex-col items-center gap-0.5 py-2.5 text-[11px] font-semibold ${tab === k ? "text-neon" : "text-white/50"}`}><I size={20} />{l}</button>
        ))}
      </nav>

      {showSettings && (
        <SettingsModal live={live} open onClose={() => setShowSettings(false)} settings={settings} notice={notice}
          onSave={(s) => { setSettings(s); saveSettings(s); }} />
      )}
    </div>
  );
}
