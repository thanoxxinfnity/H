const BASE = "https://generativelanguage.googleapis.com/v1beta";
const NOT_CHAT = /embed|aqa|imagen|veo|tts|image|live|audio|robotics|learnlm|computer-use|native-audio|gemma-3n/i;

/** Live list of Gemini models that can generate text (called straight from the browser; Google allows CORS). */
export async function fetchGeminiModels(key) {
  if (!key) throw new Error("Add your Gemini API key to see Gemini models");
  const out = [];
  let token = "";
  for (let i = 0; i < 5; i++) {
    const r = await fetch(`${BASE}/models?pageSize=200${token ? `&pageToken=${token}` : ""}`, { headers: { "x-goog-api-key": key }, cache: "no-store" });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(j?.error?.message || `Gemini model list failed (${r.status})`);
    for (const m of j.models || []) if ((m.supportedGenerationMethods || []).includes("generateContent")) out.push(m.name.replace(/^models\//, ""));
    token = j.nextPageToken || "";
    if (!token) break;
  }
  const ids = [...new Set(out)].filter((id) => !NOT_CHAT.test(id));
  if (!ids.length) throw new Error("Gemini returned no chat models");
  const rank = (id) => (/flash/.test(id) ? 0 : /pro/.test(id) ? 1 : 2) + (/latest|preview|exp/.test(id) ? 3 : 0);
  return ids.sort((a, b) => rank(a) - rank(b) || b.localeCompare(a));
}
export const pickGeminiFallback = (models) => models.find((m) => /^gemini-2\.5-flash$/.test(m)) || models[0];

export async function geminiChat({ key, model, system, messages, temperature = 0.7, max_tokens = 8192 }) {
  const contents = messages.map((m) => ({ role: m.role === "assistant" ? "model" : "user", parts: [{ text: m.content }] }));
  const r = await fetch(`${BASE}/models/${encodeURIComponent(model)}:generateContent`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": key },
    body: JSON.stringify({ ...(system ? { systemInstruction: { parts: [{ text: system }] } } : {}), contents, generationConfig: { temperature, maxOutputTokens: max_tokens } }),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(j?.error?.message || `Gemini error ${r.status}`);
  const text = (j.candidates?.[0]?.content?.parts || []).map((p) => p.text || "").join("");
  if (!text) throw new Error(j.promptFeedback?.blockReason ? `Gemini blocked the request (${j.promptFeedback.blockReason})` : "Gemini returned an empty answer");
  return text;
}
