"use client";
import { X } from "lucide-react";

export default function Modal({ open, title, onClose, children, wide }) {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/70 p-0 backdrop-blur-sm sm:items-center sm:p-4" onClick={onClose}>
      <div
        className={`max-h-[92dvh] w-full overflow-y-auto rounded-t-3xl border border-neon/40 bg-panel p-5 shadow-neon sm:rounded-3xl ${wide ? "sm:max-w-2xl" : "sm:max-w-md"}`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-lg font-bold text-white">{title}</h2>
          <button className="rounded-lg p-1.5 text-white/60 hover:bg-white/10 hover:text-white" onClick={onClose} aria-label="Close"><X size={20} /></button>
        </div>
        {children}
      </div>
    </div>
  );
}
