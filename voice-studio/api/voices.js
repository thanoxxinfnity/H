const { resolveKeys, fail } = require('./_lib');
module.exports = async (req, res) => {
  const keys = resolveKeys(req);
  if (!keys.elevenlabs) return fail(res, 401, 'ElevenLabs key missing');
  const h = { 'xi-api-key': keys.elevenlabs };
  try {
    if (req.method === 'DELETE') {
      const id = req.query?.id;
      if (!id) return fail(res, 400, 'id required');
      const r = await fetch(`https://api.elevenlabs.io/v1/voices/${encodeURIComponent(id)}`, { method: 'DELETE', headers: h });
      if (!r.ok) return fail(res, r.status, (await r.text()).slice(0, 300));
      res.setHeader('Content-Type', 'application/json'); return res.end('{"ok":true}');
    }
    const r = await fetch('https://api.elevenlabs.io/v1/voices', { headers: h });
    if (!r.ok) return fail(res, r.status, (await r.text()).slice(0, 300));
    const j = await r.json();
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ voices: (j.voices || []).map(v => ({
      id: v.voice_id, name: v.name, category: v.category, preview: v.preview_url || null })) }));
  } catch (e) { fail(res, 502, String(e.message || e)); }
};
