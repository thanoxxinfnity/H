"use client";
import { Zap, Gift } from "lucide-react";
import Modal from "./Modal";
import { fmtUsd } from "@/lib/revana";

/** Shown before every generation: prompt(s), duration and credit cost. */
export default function ConfirmModal({ open, onCancel, onConfirm, title = "Confirm & generate", rows, items, usd, credits, free }) {
  return (
    <Modal open={open} onClose={onCancel} title={title} wide>
      <div className="grid grid-cols-2 gap-2 text-sm">
        {rows?.map(([k, v]) => (
          <div key={k} className="rounded-xl border border-line bg-panel2 px-3 py-2">
            <div className="text-[10px] uppercase tracking-widest text-white/40">{k}</div>
            <div className="font-semibold text-white">{v}</div>
          </div>
        ))}
      </div>
      <label className="lbl">{items?.length > 1 ? `Prompts (${items.length} scenes)` : "Prompt"}</label>
      <div className="max-h-56 space-y-2 overflow-y-auto rounded-xl border border-line bg-panel2 p-3 text-xs leading-relaxed text-white/80">
        {items?.map((t, i) => (
          <p key={i}>{items.length > 1 && <b className="text-neon">{i + 1}. </b>}{t}</p>
        ))}
      </div>
      <div className={`mt-4 flex items-center justify-between rounded-2xl border p-4 ${free ? "border-lime/50 bg-lime/10" : "border-pink/50 bg-pink/10"}`}>
        <div className="flex items-center gap-2 text-sm text-white/80">{free ? <Gift size={18} className="text-lime" /> : <Zap size={18} className="text-pink" />} Cost</div>
        <div className="text-right">
          <div className="text-xl font-extrabold text-white">{free ? "FREE" : fmtUsd(usd)}</div>
          <div className="text-xs text-white/50">{free ? "0 credits" : `${credits} credits`}</div>
        </div>
      </div>
      <div className="mt-4 flex gap-2">
        <button className="btn-ghost flex-1" onClick={onCancel}>Cancel</button>
        <button className="btn-neon flex-[2]" onClick={onConfirm}>Confirm &amp; Generate</button>
      </div>
    </Modal>
  );
}
