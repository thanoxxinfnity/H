// Forwards the multipart upload straight to ElevenLabs instant voice cloning.
const { resolveKeys, fail, readBody } = require('./_lib');
module.exports = async (req, res) => {
  if (req.method !== 'POST') return fail(res, 405, 'POST only');
  const keys = resolveKeys(req);
  if (!keys.elevenlabs) return fail(res, 401, 'ElevenLabs key missing (voice cloning needs ElevenLabs)');
  try {
    const body = await readBody(req);
    const r = await fetch('https://api.elevenlabs.io/v1/voices/add', {
      method: 'POST',
      headers: { 'xi-api-key': keys.elevenlabs, 'Content-Type': req.headers['content-type'] },
      body });
    const t = await r.text();
    if (!r.ok) return fail(res, r.status, `ElevenLabs: ${t.slice(0, 300)}`);
    res.setHeader('Content-Type', 'application/json'); res.end(t);
  } catch (e) { fail(res, 502, String(e.message || e)); }
};
module.exports.config = { api: { bodyParser: false } };
