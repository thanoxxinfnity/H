"use client";
import { RefreshCw, Cpu } from "lucide-react";

/** Dropdown of every chat model NVIDIA NIM currently serves (auto-refreshing). */
export default function NimSelect({ nim, value, onChange, label = "NVIDIA", placeholder = "meta/llama-3.3-70b-instruct" }) {
  const groups = {};
  for (const id of nim.models) (groups[id.split("/")[0]] ||= []).push(id);
  const missing = value && nim.models.length > 0 && !nim.models.includes(value);
  return (
    <div>
      <div className="flex gap-2">
        {nim.models.length ? (
          <select className="inp" value={value} onChange={(e) => onChange(e.target.value)}>
            {missing && <option value={value}>{value} (not available)</option>}
            {Object.entries(groups).map(([owner, ids]) => (
              <optgroup key={owner} label={owner}>
                {ids.map((id) => <option key={id} value={id}>{id.split("/").slice(1).join("/")}</option>)}
              </optgroup>
            ))}
          </select>
        ) : (
          <input className="inp" value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} spellCheck={false} />
        )}
        <button type="button" className="btn-ghost px-3" onClick={nim.refresh} aria-label="Refresh models" title="Refresh model list"><RefreshCw size={16} className={nim.loading ? "animate-spin" : ""} /></button>
      </div>
      <p className="mt-1 flex items-center gap-1.5 text-[11px] text-white/40">
        <Cpu size={11} />
        {nim.error ? <span className="text-pink">{nim.error}</span> : nim.models.length ? `${nim.models.length} live ${label} models · updated ${nim.updatedAt ? new Date(nim.updatedAt).toLocaleTimeString() : "…"}` : `Loading ${label} models…`}
      </p>
    </div>
  );
}
