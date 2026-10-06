const { resolveKeys } = require('./_lib');
module.exports = (req, res) => {
  const k = resolveKeys(req);
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify({
    passwordRequired: !!process.env.APP_PASSWORD,
    unlocked: k.unlocked,
    openrouter: !!k.openrouter,
    elevenlabs: !!k.elevenlabs,
  }));
};
