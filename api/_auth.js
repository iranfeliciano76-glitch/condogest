// Helper: assina/verifica tokens de sessão sem dependências externas
const crypto = require('crypto');

const SECRET = process.env.SESSION_SECRET || 'fallback_dev_secret';

function assinarToken(payload) {
  const data = Buffer.from(JSON.stringify({
    ...payload,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 86400 // 24h
  })).toString('base64url');
  const sig = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  return `${data}.${sig}`;
}

function verificarToken(token) {
  if (!token) throw new Error('Token ausente');
  const [data, sig] = token.split('.');
  if (!data || !sig) throw new Error('Token malformado');
  const esperado = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
  if (!crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(esperado)))
    throw new Error('Token inválido');
  const payload = JSON.parse(Buffer.from(data, 'base64url').toString());
  if (payload.exp < Math.floor(Date.now() / 1000)) throw new Error('Token expirado');
  return payload;
}

module.exports = { assinarToken, verificarToken };
