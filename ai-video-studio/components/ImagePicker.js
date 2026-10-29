"use client";
import { useRef, useState } from "react";
import { ImagePlus, Loader2, X, Library, AlertTriangle } from "lucide-react";
import { uploadBlob, newId } from "@/lib/revana";
import { prepareImage, makeThumb } from "@/lib/frames";
import { loadLibrary, addToLibrary, removeFromLibrary } from "@/lib/library";

/** Upload photos (or pick from "My images"). value = [{id,url,thumb,name}] */
export default function ImagePicker({ value, onChange, max = 4, apiKey, onNeedKey, label = "Images", hint }) {
  const inputRef = useRef(null);
  const [busy, setBusy] = useState(0);
  const [err, setErr] = useState("");
  const [lib, setLib] = useState(null);
  const full = value.length >= max;

  async function onFiles(files) {
    if (!apiKey) return onNeedKey?.();
    setErr("");
    const list = [...files].filter((f) => f.type.startsWith("image/")).slice(0, Math.max(0, max - value.length));
    if (!list.length) return;
    setBusy((b) => b + list.length);
    const added = [];
    for (const f of list) {
      try {
        const { blob } = await prepareImage(f);
        const url = await uploadBlob({ key: apiKey, blob, filename: f.name.replace(/\.[^.]+$/, "") + (blob.type === "image/jpeg" ? ".jpg" : "") });
        const item = { id: newId(), url, name: f.name, thumb: await makeThumb(blob), createdAt: Date.now() };
        addToLibrary(item); added.push(item);
      } catch (e) { setErr(e.message); }
      setBusy((b) => b - 1);
    }
    if (added.length) onChange([...value, ...added].slice(0, max));
  }

  function toggleLib() { setLib(lib ? null : loadLibrary()); }
  const pick = (it) => { if (!full && !value.some((v) => v.url === it.url)) onChange([...value, it]); };

  return (
    <div>
      <div className="flex items-center justify-between">
        <label className="lbl !mb-1">{label} <span className="normal-case tracking-normal text-white/30">({value.length}/{max})</span></label>
      </div>
      <div className="flex flex-wrap gap-2">
        {value.map((it) => (
          <div key={it.id} className="group relative h-16 w-16 overflow-hidden rounded-xl border border-neon/40 bg-panel2">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={it.thumb || it.url} alt={it.name} className="h-full w-full object-cover" />
            <button className="absolute right-0.5 top-0.5 rounded-full bg-black/70 p-0.5 text-white" onClick={() => onChange(value.filter((v) => v.id !== it.id))} aria-label="Remove"><X size={12} /></button>
          </div>
        ))}
        {busy > 0 && <div className="grid h-16 w-16 place-items-center rounded-xl border border-line bg-panel2"><Loader2 className="animate-spin text-neon" size={18} /></div>}
        {!full && (
          <button type="button" className="grid h-16 w-16 place-items-center rounded-xl border border-dashed border-neon/50 text-neon/80 hover:bg-neon/10" onClick={() => (apiKey ? inputRef.current?.click() : onNeedKey?.())} aria-label="Upload image">
            <ImagePlus size={22} />
          </button>
        )}
        <button type="button" className="grid h-16 w-16 place-items-center rounded-xl border border-line text-white/50 hover:text-white" onClick={toggleLib} aria-label="My images"><Library size={20} /></button>
      </div>
      <input ref={inputRef} type="file" accept="image/*" multiple className="hidden" onChange={(e) => { onFiles(e.target.files); e.target.value = ""; }} />
      {hint && <p className="mt-1.5 text-[11px] text-white/40">{hint}</p>}
      {err && <p className="mt-1.5 flex items-start gap-1.5 text-[11px] text-pink"><AlertTriangle size={12} className="mt-0.5 shrink-0" />{err}</p>}
      {lib && (
        <div className="mt-2 rounded-xl border border-line bg-panel2 p-2">
          {lib.length === 0 ? <p className="p-2 text-xs text-white/40">Nothing yet. Images you upload are saved here for 2 weeks.</p> : (
            <div className="flex flex-wrap gap-2">
              {lib.map((it) => (
                <div key={it.url} className="relative h-14 w-14 overflow-hidden rounded-lg border border-line">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <button className="h-full w-full" onClick={() => pick(it)} title={it.name}><img src={it.thumb || it.url} alt={it.name} className="h-full w-full object-cover" /></button>
                  <button className="absolute right-0 top-0 rounded-bl bg-black/70 p-0.5 text-pink" onClick={() => { removeFromLibrary(it.url); setLib(loadLibrary()); }} aria-label="Delete from library"><X size={10} /></button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
