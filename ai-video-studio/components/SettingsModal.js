"use client";
import { useState } from "react";
import { Eye, EyeOff, Wallet, Save } from "lucide-react";
import Modal from "./Modal";
import { getBalance } from "@/lib/revana";

function KeyField({ label, value, onChange, placeholder, hint }) {
  const [show, setShow] = useState(false);
  return (
    <div>
      <label className="lbl">{label}</label>
      <div className="flex gap-2">
        <input className="inp" type={show ? "text" : "password"} value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} autoComplete="off" spellCheck={false} />
        <button type="button" className="btn-ghost px-3" onClick={() => setShow(!show)} aria-label="Show or hide">{show ? <EyeOff size={16} /> : <Eye size={16} />}</button>
      </div>
      {hint && <p className="mt-1 text-[11px] text-white/40">{hint}</p>}
    </div>
  );
}

export default function SettingsModal({ open, onClose, settings, onSave, notice }) {
  const [s, setS] = useState(settings);
  const [bal, setBal] = useState(null);
  const [err, setErr] = useState("");
  const set = (k) => (v) => setS((p) => ({ ...p, [k]: v }));

  async function check() {
    setErr(""); setBal(null);
    try { setBal(await getBalance(s.revanaKey.trim())); } catch (e) { setErr(e.message); }
  }
  function save() { onSave({ ...s, revanaKey: s.revanaKey.trim(), nimKey: s.nimKey.trim() }); onClose(); }

  return (
    <Modal open={open} onClose={onClose} title="Settings">
      {notice && <p className="mb-3 rounded-xl border border-pink/50 bg-pink/10 px-3 py-2 text-xs text-pink">{notice}</p>}
      <p className="text-xs text-white/50">Keys are saved only in this browser (localStorage). Video calls go straight from your browser to Revana; Agent planning goes through this site&apos;s small proxy to NVIDIA NIM and is never logged or stored.</p>
      <KeyField label="Revana API key" value={s.revanaKey} onChange={set("revanaKey")} placeholder="sr_live_..." hint="Used for video generation at api.revana.si" />
      <div className="mt-2 flex items-center gap-2">
        <button className="btn-ghost" onClick={check} disabled={!s.revanaKey.trim()}><Wallet size={16} /> Check balance</button>
        {bal && <span className="text-xs text-lime">Balance: {JSON.stringify(bal.available_usd ?? bal.balance_usd ?? bal.balance ?? bal).replace(/"/g, "")}</span>}
        {err && <span className="text-xs text-pink">{err}</span>}
      </div>
      <KeyField label="NVIDIA NIM API key (Agent mode)" value={s.nimKey} onChange={set("nimKey")} placeholder="nvapi-..." hint="Used to plan the story and split it into scenes" />
      <label className="lbl">NIM model</label>
      <input className="inp" value={s.nimModel} onChange={(e) => set("nimModel")(e.target.value)} placeholder="meta/llama-3.3-70b-instruct" spellCheck={false} />
      <label className="lbl">Default video model</label>
      <input className="inp" value={s.defaultModel} onChange={(e) => set("defaultModel")(e.target.value)} placeholder="minimax-h3-free" spellCheck={false} />
      <button className="btn-neon mt-5 w-full" onClick={save}><Save size={16} /> Save settings</button>
    </Modal>
  );
}
