// Streams raw PCM16 mono 24 kHz so the browser can play it while it is still being generated.
const { resolveKeys, fail } = require('./_lib');

module.exports = async (req, res) => {
  if (req.method !== 'POST') return fail(res, 405, 'POST only');
  const keys = resolveKeys(req);
  const { provider, text, voice, model } = req.body || {};
  if (!text || !String(text).trim()) return fail(res, 400, 'Text is empty');
  if (String(text).length > 5000) return fail(res, 400, 'Text too long (max 5000 chars)');

  try {
    if (provider === 'elevenlabs') {
      if (!keys.elevenlabs) return fail(res, 401, 'ElevenLabs key missing (add it in Settings, or unlock with the site password)');
      if (!voice) return fail(res, 400, 'Pick a voice first');
      const r = await fetch(
        `https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voice)}/stream?output_format=pcm_24000`,
        { method: 'POST',
          headers: { 'xi-api-key': keys.elevenlabs, 'Content-Type': 'application/json' },
          body: JSON.stringify({ text, model_id: model || 'eleven_multilingual_v2' }) });
      if (!r.ok) return fail(res, r.status, `ElevenLabs: ${(await r.text()).slice(0, 300)}`);
      res.statusCode = 200;
      res.setHeader('Content-Type', 'application/octet-stream');
      res.setHeader('Cache-Control', 'no-store, no-transform');
      res.setHeader('X-Accel-Buffering', 'no');
      const reader = r.body.getReader();
      for (;;) { const { done, value } = await reader.read(); if (done) break; res.write(Buffer.from(value)); }
      return res.end();
    }

    if (provider === 'fish') {
      if (!keys.fish) return fail(res, 401, 'Fish Audio key missing (add it in Settings, or unlock with the site password)');
      const body = { text, format: 'pcm', sample_rate: 24000, latency: 'balanced', chunk_length: 200, normalize: true };
      if (voice) body.reference_id = voice;
      const r = await fetch('https://api.fish.audio/v1/tts', {
        method: 'POST',
        headers: { Authorization: `Bearer ${keys.fish}`, 'Content-Type': 'application/json', model: model || 's1' },
        body: JSON.stringify(body) });
      if (!r.ok) return fail(res, r.status, `Fish Audio: ${(await r.text()).slice(0, 300)}`);
      res.statusCode = 200;
      res.setHeader('Content-Type', 'application/octet-stream');
      res.setHeader('Cache-Control', 'no-store, no-transform');
      res.setHeader('X-Accel-Buffering', 'no');
      const reader = r.body.getReader();
      for (;;) { const { done, value } = await reader.read(); if (done) break; res.write(Buffer.from(value)); }
      return res.end();
    }

    // default: OpenRouter audio-output chat model (preset voices, no cloning)
    if (!keys.openrouter) return fail(res, 401, 'OpenRouter key missing (add it in Settings, or unlock with the site password)');
    const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${keys.openrouter}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: model || 'openai/gpt-audio-mini',
        modalities: ['text', 'audio'],
        audio: { voice: voice || 'alloy', format: 'pcm16' },
        stream: true,
        messages: [
          { role: 'system', content: 'You are a text-to-speech engine. Read the user message aloud exactly as written, with natural expression. Never add, answer, or comment.' },
          { role: 'user', content: text },
        ],
      }),
    });
    if (!r.ok) return fail(res, r.status, `OpenRouter: ${(await r.text()).slice(0, 300)}`);
    res.statusCode = 200;
    res.setHeader('Content-Type', 'application/octet-stream');
    res.setHeader('Cache-Control', 'no-store, no-transform');
    res.setHeader('X-Accel-Buffering', 'no');
    const reader = r.body.getReader(), dec = new TextDecoder();
    let buf = '';
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buf += dec.decode(value, { stream: true });
      let i;
      while ((i = buf.indexOf('\n')) >= 0) {
        const line = buf.slice(0, i).trim(); buf = buf.slice(i + 1);
        if (!line.startsWith('data:')) continue;
        const data = line.slice(5).trim();
        if (!data || data === '[DONE]') continue;
        try {
          const a = JSON.parse(data).choices?.[0]?.delta?.audio;
          if (a?.data) res.write(Buffer.from(a.data, 'base64'));
        } catch { /* ignore keep-alive / partial lines */ }
      }
    }
    res.end();
  } catch (e) {
    if (!res.headersSent) fail(res, 502, String(e.message || e));
    else res.end();
  }
};
