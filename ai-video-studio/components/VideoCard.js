"use client";
import { useEffect, useMemo } from "react";
import { Download, Trash2, RotateCcw } from "lucide-react";

export function downloadBlob(blob, name) {
  const u = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = u; a.download = name; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(u), 4000);
}

export default function VideoCard({ rec, onDelete, onReuse }) {
  const url = useMemo(() => URL.createObjectURL(rec.blob), [rec.blob]);
  useEffect(() => () => URL.revokeObjectURL(url), [url]);
  const when = new Date(rec.createdAt).toLocaleString();
  return (
    <div className="card p-3">
      <video src={url} controls playsInline preload="metadata" className="w-full rounded-xl bg-black" style={{ aspectRatio: (rec.ratio || "16:9").replace(":", "/") }} />
      <div className="mt-2 flex flex-wrap items-center gap-1.5 text-[10px] text-white/50">
        <span className="rounded bg-neon/10 px-1.5 py-0.5 text-neon">{rec.kind || "video"}</span>
        <span>{rec.model}</span><span>· {rec.duration}s</span><span>· {rec.resolution}</span>
        <span>· {rec.free ? "free" : `$${Number(rec.cost || 0).toFixed(2)}`}</span><span className="ml-auto">{when}</span>
      </div>
      <p className="mt-1 line-clamp-3 text-xs text-white/70">{rec.prompt}</p>
      <div className="mt-2 flex gap-2">
        <button className="btn-neon flex-1 py-2 text-xs" onClick={() => downloadBlob(rec.blob, `${(rec.kind || "video")}-${rec.id}.mp4`)}><Download size={14} /> Download</button>
        {onReuse && <button className="btn-ghost py-2 text-xs" onClick={() => onReuse(rec)} title="Reuse prompt"><RotateCcw size={14} /></button>}
        {onDelete && <button className="btn-danger py-2 text-xs" onClick={() => onDelete(rec.id)} title="Delete"><Trash2 size={14} /></button>}
      </div>
    </div>
  );
}
