import { llmChat } from "@/lib/llm";

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

export async function planStory({ settings, idea, count, styleText }) {
  const system =
    `You are a film director's assistant. Break the user's idea into exactly ${count} consecutive video scenes. ` +
    `Reply with ONLY valid JSON: {"title": string, "characters": string, "scenes": [{"prompt": string, "duration": number}]}. ` +
    `"characters" is a short visual description of each main character. Every scene prompt is 1-3 concrete sentences ` +
    `(setting, action, camera move) and repeats the key character description so the look stays consistent across clips. ` +
    `duration is an integer from 5 to 15 seconds. Use ORIGINAL characters and settings only; never use existing copyrighted ` +
    `characters, brands or franchises. ` + (styleText ? `Overall visual style: ${styleText}.` : "");
  const text = await llmChat({ settings, system, messages: [{ role: "user", content: idea }] });
  return normalizeScenes(extractJson(text));
}

export async function rewriteScene({ settings, prompt, characters, styleText }) {
  const system = "You improve text-to-video scene prompts. Rewrite the user's scene prompt to be vivid, concrete and cinematic " +
    "(setting, action, lighting, one camera move) in at most 70 words. Keep the same characters and story beat" +
    (characters ? `; character look to keep consistent: ${characters}` : "") + (styleText ? `; visual style: ${styleText}` : "") +
    ". Use original characters only. Reply with the rewritten prompt text only, no quotes, no preamble.";
  const text = await llmChat({ settings, system, messages: [{ role: "user", content: prompt }], temperature: 0.8, max_tokens: 1200 });
  const out = text.trim().replace(/^["'`]+|["'`]+$/g, "");
  if (!out) throw new Error("The model returned an empty rewrite");
  return out;
}

const DIRECTOR =
  "You are DIRECTOR, a friendly AI film director inside a video studio, chatting with the user (reply in the user's own language; Hinglish is fine). " +
  "Understand what they want: story, characters, mood, style, how long. If something important is missing, ask at most ONE or TWO short questions; " +
  "if you already have enough, go ahead and propose a storyboard right away. Reply with ONLY valid JSON: " +
  '{"reply": string, "story": null | {"title": string, "characters": string, "scenes": [{"prompt": string, "duration": number}]}, "generate": boolean, "total_seconds": number|null}. ' +
  '"reply" is your short chat message. "story" is the FULL updated storyboard whenever you create or change it, otherwise null. ' +
  "Default 4-6 scenes unless the user asks otherwise; each scene prompt is 1-3 concrete sentences (setting, action, camera move) that repeat the character look; duration is an integer 5-15. " +
  '"total_seconds": if the user states a total length (e.g. "2 minute movie", "10 min film") put it in SECONDS, else null. If the user wants a movie/film/long video but gave no length, ask how long it should be. ' +
  "For long movies write only the OPENING scenes (up to 6) with a clear story arc - the app writes the remaining scenes automatically and continues each scene from the previous one's last frame. " +
  '"generate" is true ONLY when a storyboard already exists and the user clearly tells you to start/generate/shoot/make it now. ' +
  "Use ORIGINAL characters and settings only; never existing copyrighted characters, brands or franchises - if asked, offer an original lookalike concept instead.";

export async function directorChat({ settings, history, story, styleText }) {
  const system = DIRECTOR + (styleText ? ` Visual style chosen in the app: ${styleText}.` : "") +
    (story ? ` CURRENT STORYBOARD (edit this when asked): ${JSON.stringify({ title: story.title, characters: story.characters, scenes: story.scenes.map((s) => ({ prompt: s.prompt, duration: s.duration })) })}` : " No storyboard yet.");
  const msgs = history.filter((m, i) => !(i === 0 && m.role === "assistant"));
  const text = await llmChat({ settings, system, messages: msgs, temperature: 0.8 });
  let obj;
  try { obj = extractJson(text); } catch { return { reply: text.trim(), story: null, generate: false }; }
  let st = null;
  if (obj.story && Array.isArray(obj.story.scenes) && obj.story.scenes.length) { try { st = normalizeScenes(obj.story); } catch {} }
  const ts = Number(obj.total_seconds);
  return { reply: String(obj.reply || "").trim() || (st ? "Storyboard ready." : "..."), story: st, generate: !!obj.generate && !!(st || story), totalSeconds: ts > 0 ? Math.min(ts, 1800) : null };
}

/** Writes the remaining scenes of a long movie in batches until the storyboard reaches totalSeconds. */
export async function expandStory({ settings, story, totalSeconds, styleText, onProgress, signal }) {
  let scenes = [...story.scenes];
  const sum = () => scenes.reduce((a, x) => a + x.duration, 0);
  for (let guard = 0; guard < 40 && sum() < totalSeconds - 4; guard++) {
    if (signal?.aborted) break;
    const remaining = totalSeconds - sum();
    const batch = Math.min(8, Math.ceil(remaining / 10));
    onProgress?.(sum(), totalSeconds);
    const system = "You are a film director's assistant writing the NEXT scenes of a long movie. Reply with ONLY valid JSON: " +
      `{"scenes": [{"prompt": string, "duration": number}]} with exactly ${batch} scenes. Each prompt is 1-3 concrete sentences (setting, action, camera move) that repeat the key character looks, and continues directly from the previous scene (same place/time unless the story moves on). duration is an integer 5-15 (prefer 10). ` +
      `The movie is ${Math.round(totalSeconds)}s long, ${Math.round(sum())}s are written, ${Math.round(remaining)}s remain: ` +
      (remaining <= batch * 10 + 10 ? "bring the story to a satisfying ending in these scenes. " : "keep developing the plot, do not end yet. ") +
      "Original characters only. " + (styleText ? `Visual style: ${styleText}.` : "");
    const user = `Title: ${story.title}\nCharacters: ${story.characters}\nPrevious scenes:\n` + scenes.slice(-5).map((x, i) => `${scenes.length - Math.min(5, scenes.length) + i + 1}. ${x.prompt}`).join("\n");
    const text = await llmChat({ settings, system, messages: [{ role: "user", content: user }], temperature: 0.8 });
    const more = normalizeScenes(extractJson(text)).scenes;
    scenes = [...scenes, ...more];
  }
  onProgress?.(sum(), totalSeconds);
  return { ...story, scenes };
}
