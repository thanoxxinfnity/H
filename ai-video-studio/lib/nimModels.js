const CACHE = "avs.nimlist.v1";
const NOT_CHAT = /embed|rerank|retriev|guard|safety|reward|clip|parse|bge|e5-|riva|tts|asr|whisper|flux|stable|sdxl|cosmos|vila|paligemma|fuyu|kosmos|deplot|neva|usdcode|molmim|diffdock|alphafold|esm|genmol|corrector|speech|translate|jailbreak|ocr|table|chart|page-elements|graphic|starcoder|codellama|codegemma|code-instruct|coder/i;
const PREFERRED = ["meta/llama-3.3-70b-instruct", "meta/llama-3.1-70b-instruct", "meta/llama-3.1-405b-instruct", "deepseek-ai/deepseek-v4.1-flash", "mistralai/mistral-large-2-instruct", "qwen/qwen2.5-72b-instruct", "google/gemma-3-27b-it"];

export const isChatModel = (id) => !NOT_CHAT.test(id);

/** Fetches the live list through our proxy (NIM has no CORS). Returns sorted chat model ids. */
export async function fetchNimModels(key) {
  const r = await fetch("/api/nim/models", { headers: key ? { "x-nim-key": key } : {}, cache: "no-store" });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(j?.error?.message || `NVIDIA model list failed (${r.status})`);
  const ids = (j.data || []).map((m) => m.id).filter((id) => id && isChatModel(id));
  if (!ids.length) throw new Error("NVIDIA returned no chat models");
  return [...new Set(ids)].sort((a, b) => {
    const pa = PREFERRED.indexOf(a), pb = PREFERRED.indexOf(b);
    if (pa >= 0 || pb >= 0) return (pa < 0 ? 99 : pa) - (pb < 0 ? 99 : pb);
    return a.localeCompare(b);
  });
}

export function pickFallback(models) {
  return PREFERRED.find((p) => models.includes(p)) || models[0];
}

/** Compare against the last list we saw on this device. */
export function diffAgainstCache(models) {
  let prev = null;
  try { prev = JSON.parse(localStorage.getItem(CACHE) || "null"); } catch {}
  try { localStorage.setItem(CACHE, JSON.stringify(models)); } catch {}
  if (!prev) return { added: [], removed: [] };
  return { added: models.filter((m) => !prev.includes(m)), removed: prev.filter((m) => !models.includes(m)) };
}
