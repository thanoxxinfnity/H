export const dynamic = "force-dynamic";

/** Live list of models NVIDIA NIM currently serves (public endpoint; a key is optional). */
export async function GET(req) {
  const key = req.headers.get("x-nim-key");
  try {
    const r = await fetch("https://integrate.api.nvidia.com/v1/models", {
      headers: { Accept: "application/json", ...(key ? { Authorization: `Bearer ${key}` } : {}) },
      cache: "no-store",
    });
    const text = await r.text();
    return new Response(text, { status: r.status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" } });
  } catch (e) {
    return Response.json({ error: { message: `NVIDIA NIM unreachable: ${e.message}` } }, { status: 502 });
  }
}
