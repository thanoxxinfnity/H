// Forwards the multipart upload straight to the provider's voice-cloning endpoint.
// POST /api/clone?provider=elevenlabs|fish
const { resolveKeys, fail, readBody } = require('./_lib');
module.exports = async (req, res) => {
  if (req.method !== 'POST') return fail(res, 405, 'POST only');
  const keys = resolveKeys(req);
  const fish = req.query?.provider === 'fish';
  const key = fish ? keys.fish : keys.elevenlabs;
  if (!key) return fail(res, 401, `${fish ? 'Fish Audio' : 'ElevenLabs'} key missing`);
  try {
    const body = await readBody(req);
    const r = await fetch(fish ? 'https://api.fish.audio/model' : 'https://api.elevenlabs.io/v1/voices/add', {
      method: 'POST',
      headers: { ...(fish ? { Authorization: `Bearer ${key}` } : { 'xi-api-key': key }), 'Content-Type': req.headers['content-type'] },
      body });
    const t = await r.text();
    if (!r.ok) return fail(res, r.status, `${fish ? 'Fish Audio' : 'ElevenLabs'}: ${t.slice(0, 300)}`);
    let j = {}; try { j = JSON.parse(t); } catch {}
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ voice_id: j.voice_id || j._id || null, raw: j }));
  } catch (e) { fail(res, 502, String(e.message || e)); }
};
module.exports.config = { api: { bodyParser: false } };
