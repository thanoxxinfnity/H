"use client";
import { useEffect, useState } from "react";
import { Trash2, History as Hist } from "lucide-react";
import VideoCard from "./VideoCard";
import { listVideos, deleteVideo, clearVideos } from "@/lib/storage";

export default function History({ refreshKey, onReuse }) {
  const [items, setItems] = useState(null);
  const [filter, setFilter] = useState("all");
  const load = async () => { try { setItems(await listVideos()); } catch { setItems([]); } };
  useEffect(() => { load(); }, [refreshKey]);
  const shown = (items || []).filter((r) => filter === "all" || r.kind === filter);

  return (
    <div>
      <div className="mb-3 flex flex-wrap items-center gap-2">
        {["all", "video", "scene", "merged"].map((f) => (
          <button key={f} onClick={() => setFilter(f)} className={`chip ${filter === f ? "border-neon bg-neon/15 text-neon" : "border-line bg-panel2 text-white/60"}`}>{f}</button>
        ))}
        <span className="text-xs text-white/40">{shown.length} item{shown.length === 1 ? "" : "s"} · stored on this device</span>
        {items?.length > 0 && (
          <button className="btn-danger ml-auto !px-3 !py-1.5 text-xs" onClick={async () => { if (confirm("Delete all saved videos on this device?")) { await clearVideos(); load(); } }}><Trash2 size={13} /> Clear all</button>
        )}
      </div>
      {items === null && <p className="text-sm text-white/40">Loading…</p>}
      {items && shown.length === 0 && (
        <div className="card flex min-h-[220px] flex-col items-center justify-center text-center text-white/40"><Hist className="mb-2 text-neon/60" size={32} /><p className="text-sm">No videos yet. Generate one and it will be saved here.</p></div>
      )}
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {shown.map((r) => <VideoCard key={r.id} rec={r} onDelete={async (id) => { await deleteVideo(id); load(); }} onReuse={onReuse} />)}
      </div>
    </div>
  );
}
