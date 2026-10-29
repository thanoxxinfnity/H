/** Story planning through NVIDIA NIM (via our /api/nim proxy, because NIM has no CORS). */
export async function nimChat({ key, model, messages, temperature = 0.7, max_tokens = 4096 }) {
  const r = await fetch("/api/nim", {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-nim-key": key },
    body: JSON.stringify({ model, messages, temperature, max_tokens }),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(j?.error?.message || j?.detail || j?.error || `NVIDIA NIM error ${r.status}`);
  return j.choices?.[0]?.message?.content || "";
}

export function extractJson(text) {
  const t = String(text).replace(/```(?:json)?/gi, "");
  const a = t.indexOf("{"), b = t.lastIndexOf("}");
  if (a < 0 || b <= a) throw new Error("The model did not return JSON. Try again.");
  return JSON.parse(t.slice(a, b + 1));
}

export function normalizeScenes(obj, minD = 5, maxD = 15) {
  const arr = Array.isArray(obj?.scenes) ? obj.scenes : [];
  const scenes = arr
    .map((s, i) => ({
      id: `s${Date.now()}-${i}-${Math.random().toString(16).slice(2, 6)}`,
      prompt: String(s?.prompt || s?.description || "").trim(),
      duration: Math.min(maxD, Math.max(minD, Math.round(Number(s?.duration) || minD))),
    }))
    .filter((s) => s.prompt);
  if (!scenes.length) throw new Error("No scenes came back. Try a more detailed idea.");
  return { title: String(obj?.title || "Untitled story"), characters: String(obj?.characters || ""), scenes };
}

export async function planStory({ key, model, idea, count, styleText }) {
  const system =
    `You are a film director's assistant. Break the user's idea into exactly ${count} consecutive video scenes. ` +
    `Reply with ONLY valid JSON: {"title": string, "characters": string, "scenes": [{"prompt": string, "duration": number}]}. ` +
    `"characters" is a short visual description of each main character. Every scene prompt is 1-3 concrete sentences ` +
    `(setting, action, camera move) and repeats the key character description so the look stays consistent across clips. ` +
    `duration is an integer from 5 to 15 seconds. Use ORIGINAL characters and settings only; never use existing copyrighted ` +
    `characters, brands or franchises. ` + (styleText ? `Overall visual style: ${styleText}.` : "");
  const text = await nimChat({ key, model, messages: [{ role: "system", content: system }, { role: "user", content: idea }] });
  return normalizeScenes(extractJson(text));
}

export async function rewriteScene({ key, model, prompt, characters, styleText }) {
  const system = "You improve text-to-video scene prompts. Rewrite the user's scene prompt to be vivid, concrete and cinematic " +
    "(setting, action, lighting, one camera move) in at most 70 words. Keep the same characters and story beat" +
    (characters ? `; character look to keep consistent: ${characters}` : "") + (styleText ? `; visual style: ${styleText}` : "") +
    ". Use original characters only. Reply with the rewritten prompt text only, no quotes, no preamble.";
  const text = await nimChat({ key, model, messages: [{ role: "system", content: system }, { role: "user", content: prompt }], temperature: 0.8, max_tokens: 400 });
  const out = text.trim().replace(/^["'`]+|["'`]+$/g, "");
  if (!out) throw new Error("The model returned an empty rewrite");
  return out;
}
