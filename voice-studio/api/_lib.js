// Shared auth: the site password unlocks server-side env keys; keys typed in Settings
// (sent as headers from the user's own browser) always work and are never stored on the server.
const crypto = require('crypto');

function same(a, b) {
  const x = Buffer.from(String(a || '')), y = Buffer.from(String(b || ''));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

function resolveKeys(req) {
  const pw = req.headers['x-app-password'];
  const unlocked = !!process.env.APP_PASSWORD && same(pw, process.env.APP_PASSWORD);
  return {
    unlocked,
    openrouter: req.headers['x-openrouter-key'] || (unlocked ? process.env.OPENROUTER_API_KEY : ''),
    elevenlabs: req.headers['x-elevenlabs-key'] || (unlocked ? process.env.ELEVENLABS_API_KEY : ''),
  };
}

function fail(res, code, msg) {
  res.statusCode = code;
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify({ error: msg }));
}

async function readBody(req) {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  return Buffer.concat(chunks);
}

module.exports = { resolveKeys, fail, readBody };
