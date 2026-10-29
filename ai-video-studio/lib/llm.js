import { geminiChat } from "@/lib/gemini";

export const PROVIDERS = {
  nim: { label: "NVIDIA NIM", keyField: "nimKey", modelField: "nimModel" },
  gemini: { label: "Google Gemini", keyField: "geminiKey", modelField: "geminiModel" },
};
export const activeProvider = (s) => PROVIDERS[s.provider] || PROVIDERS.nim;
export const llmReady = (s) => !!s[activeProvider(s).keyField];

/** One entry point for both providers. messages: [{role:"user"|"assistant", content}] */
export async function llmChat({ settings, system, messages, temperature, max_tokens }) {
  const p = activeProvider(settings);
  const key = settings[p.keyField], model = settings[p.modelField];
  if (settings.provider === "gemini") return geminiChat({ key, model, system, messages, temperature, max_tokens });
  const msgs = system ? [{ role: "system", content: system }, ...messages] : messages;
  return nimChat({ key, model, messages: msgs, temperature, max_tokens });
}

async function nimChat({ key, model, messages, temperature = 0.7, max_tokens = 4096 }) {
  const r = await fetch("/api/nim", {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-nim-key": key },
    body: JSON.stringify({ model, messages, temperature, max_tokens }),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(j?.error?.message || j?.detail || j?.error || `NVIDIA NIM error ${r.status}`);
  return j.choices?.[0]?.message?.content || "";
}

