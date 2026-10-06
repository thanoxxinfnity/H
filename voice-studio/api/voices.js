const { resolveKeys, fail } = require('./_lib');
// GET /api/voices?provider=elevenlabs|fish        list voices
// DELETE /api/voices?provider=...&id=...          delete a cloned voice
module.exports = async (req, res) => {
  const keys = resolveKeys(req);
  const provider = req.query?.provider === 'fish' ? 'fish' : 'elevenlabs';
  const key = keys[provider];
  if (!key) return fail(res, 401, `${provider === 'fish' ? 'Fish Audio' : 'ElevenLabs'} key missing`);
  const h = provider === 'fish' ? { Authorization: `Bearer ${key}` } : { 'xi-api-key': key };
  const base = provider === 'fish' ? 'https://api.fish.audio/model' : 'https://api.elevenlabs.io/v1/voices';
  const json = (o) => { res.setHeader('Content-Type', 'application/json'); res.end(JSON.stringify(o)); };
  try {
    if (req.method === 'DELETE') {
      const id = req.query?.id;
      if (!id) return fail(res, 400, 'id required');
      const r = await fetch(`${base}/${encodeURIComponent(id)}`, { method: 'DELETE', headers: h });
      if (!r.ok) return fail(res, r.status, (await r.text()).slice(0, 300));
      return json({ ok: true });
    }
    if (provider === 'fish') {
      const r = await fetch(`${base}?self=true&page_size=100&page_number=1`, { headers: h });
      if (!r.ok) return fail(res, r.status, (await r.text()).slice(0, 300));
      const j = await r.json();
      return json({ voices: (j.items || []).map(v => ({ id: v._id, name: v.title, category: 'cloned', preview: null })) });
    }
    const r = await fetch(base, { headers: h });
    if (!r.ok) return fail(res, r.status, (await r.text()).slice(0, 300));
    const j = await r.json();
    json({ voices: (j.voices || []).map(v => ({ id: v.voice_id, name: v.name, category: v.category, preview: v.preview_url || null })) });
  } catch (e) { fail(res, 502, String(e.message || e)); }
};
