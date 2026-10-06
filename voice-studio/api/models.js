// Lists OpenRouter text-to-speech models (public endpoint, no key needed).
module.exports = async (req, res) => {
  try {
    const r = await fetch('https://openrouter.ai/api/v1/models?output_modalities=speech');
    if (!r.ok) throw new Error('models ' + r.status);
    const j = await r.json();
    const models = (j.data || []).map(m => ({
      id: m.id, name: m.name, free: Number(m.pricing?.prompt) === 0 && Number(m.pricing?.completion || 0) === 0,
      voices: m.supported_voices || null }));
    models.sort((a, b) => (b.free - a.free) || a.name.localeCompare(b.name));
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Cache-Control', 'public, max-age=600');
    res.end(JSON.stringify({ models }));
  } catch (e) {
    res.statusCode = 502; res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ error: String(e.message || e) }));
  }
};
