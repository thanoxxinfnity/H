"use client";
import { useRef, useState } from "react";
import { Paperclip, Loader2, X, Library, AlertTriangle, Film, Music } from "lucide-react";
import { uploadBlob, newId } from "@/lib/revana";
import { prepareImage, makeThumb } from "@/lib/frames";
import { loadLibrary, addToLibrary, removeFromLibrary } from "@/lib/library";

const LIMIT = { image: 30, video: 50, audio: 15 }; // MB, Revana upload limits
const kindOf = (t) => (t.startsWith("image/") ? "image" : t.startsWith("video/") ? "video" : t.startsWith("audio/") ? "audio" : null);

/** Upload photos, video or audio (or pick from "My files"). value = [{id,url,thumb,name,kind}] */
export default function ImagePicker({ value, onChange, max = 4, apiKey, onNeedKey, label = "Images", hint, kinds = ["image"] }) {
  const inputRef = useRef(null);
  const [busy, setBusy] = useState(0);
  const [err, setErr] = useState("");
  const [lib, setLib] = useState(null);
  const full = value.length >= max;
  const accept = kinds.map((k) => `${k}/*`).join(",");

  async function onFiles(files) {
    if (!apiKey) return onNeedKey?.();
    setErr("");
    const picked = [...files].slice(0, Math.max(0, max - value.length));
    const list = [];
    for (const f of picked) {
      const k = kindOf(f.type);
      if (!k || !kinds.includes(k)) { setErr(`${f.name}: this model accepts ${kinds.join(", ")} files only (Revana can't take other file types).`); continue; }
      if (f.size > LIMIT[k] * 1024 * 1024) { setErr(`${f.name} is too big (${k} limit ${LIMIT[k]} MB).`); continue; }
      list.push([f, k]);
    }
    if (!list.length) return;
    setBusy((b) => b + list.length);
    const added = [];
    for (const [f, k] of list) {
      try {
        const blob = k === "image" ? (await prepareImage(f)).blob : f;
        const url = await uploadBlob({ key: apiKey, blob, filename: f.name });
        const item = { id: newId(), url, name: f.name, kind: k, thumb: k === "image" ? await makeThumb(blob) : "", createdAt: Date.now() };
        addToLibrary(item); added.push(item);
      } catch (e) { setErr(e.message); }
      setBusy((b) => b - 1);
    }
    if (added.length) onChange([...value, ...added].slice(0, max));
  }

  const pick = (it) => { if (!full && !value.some((v) => v.url === it.url) && kinds.includes(it.kind || "image")) onChange([...value, it]); };
  const Icon = ({ k }) => (k === "video" ? <Film size={22} /> : <Music size={22} />);

  return (
    <div>
      <label className="lbl !mb-1">{label} <span className="normal-case tracking-normal text-white/30">({value.length}/{max})</span></label>
      <div className="flex flex-wrap gap-2">
        {value.map((it) => (
          <div key={it.id} className="relative h-16 w-16 overflow-hidden rounded-xl border border-neon/40 bg-panel2" title={it.name}>
            {(it.kind || "image") === "image"
              // eslint-disable-next-line @next/next/no-img-element
              ? <img src={it.thumb || it.url} alt={it.name} className="h-full w-full object-cover" />
              : <div className="grid h-full w-full place-items-center text-pink"><Icon k={it.kind} /></div>}
            <button className="absolute right-0.5 top-0.5 rounded-full bg-black/70 p-0.5 text-white" onClick={() => onChange(value.filter((v) => v.id !== it.id))} aria-label="Remove"><X size={12} /></button>
          </div>
        ))}
        {busy > 0 && <div className="grid h-16 w-16 place-items-center rounded-xl border border-line bg-panel2"><Loader2 className="animate-spin text-neon" size={18} /></div>}
        {!full && (
          <button type="button" className="grid h-16 w-16 place-items-center rounded-xl border border-dashed border-neon/50 text-neon/80 hover:bg-neon/10" onClick={() => (apiKey ? inputRef.current?.click() : onNeedKey?.())} aria-label="Upload file">
            <Paperclip size={22} />
          </button>
        )}
        <button type="button" className="grid h-16 w-16 place-items-center rounded-xl border border-line text-white/50 hover:text-white" onClick={() => setLib(lib ? null : loadLibrary())} aria-label="My files"><Library size={20} /></button>
      </div>
      <input ref={inputRef} type="file" accept={accept} multiple className="hidden" onChange={(e) => { onFiles(e.target.files); e.target.value = ""; }} />
      <p className="mt-1.5 text-[11px] text-white/40">{kinds.join(" / ")} files · {hint}</p>
      {err && <p className="mt-1.5 flex items-start gap-1.5 text-[11px] text-pink"><AlertTriangle size={12} className="mt-0.5 shrink-0" />{err}</p>}
      {lib && (
        <div className="mt-2 rounded-xl border border-line bg-panel2 p-2">
          {lib.length === 0 ? <p className="p-2 text-xs text-white/40">Nothing yet. Files you upload are kept here for 2 weeks.</p> : (
            <div className="flex flex-wrap gap-2">
              {lib.filter((it) => kinds.includes(it.kind || "image")).map((it) => (
                <div key={it.url} className="relative h-14 w-14 overflow-hidden rounded-lg border border-line">
                  <button className="grid h-full w-full place-items-center" onClick={() => pick(it)} title={it.name}>
                    {(it.kind || "image") === "image"
                      // eslint-disable-next-line @next/next/no-img-element
                      ? <img src={it.thumb || it.url} alt={it.name} className="h-full w-full object-cover" />
                      : <span className="text-pink"><Icon k={it.kind} /></span>}
                  </button>
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
