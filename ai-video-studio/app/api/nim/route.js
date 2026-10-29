export const maxDuration = 60;

const ALLOWED_MODEL = /^[a-z0-9._\-]+\/[a-zA-Z0-9._\-]+$/;

export async function POST(req) {
  const key = req.headers.get("x-nim-key");
  if (!key) return Response.json({ error: { message: "Add your NVIDIA NIM API key in Settings." } }, { status: 401 });
  let body;
  try { body = await req.json(); } catch { return Response.json({ error: { message: "Bad JSON" } }, { status: 400 }); }
  const { model, messages, temperature = 0.7, max_tokens = 4096 } = body || {};
  if (!ALLOWED_MODEL.test(String(model || "")) || !Array.isArray(messages) || messages.length > 20) {
    return Response.json({ error: { message: "Invalid request" } }, { status: 400 });
  }
  try {
    const r = await fetch("https://integrate.api.nvidia.com/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ model, messages, temperature, max_tokens: Math.min(Number(max_tokens) || 4096, 8192), stream: false }),
    });
    const text = await r.text();
    return new Response(text, { status: r.status, headers: { "Content-Type": r.headers.get("content-type") || "application/json", "Cache-Control": "no-store" } });
  } catch (e) {
    return Response.json({ error: { message: `NVIDIA NIM unreachable: ${e.message}` } }, { status: 502 });
  }
}
