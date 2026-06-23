// POST /api/auth — Login (Supabase invisível no frontend)
const { sbAuthLogin, sbGet } = require('./_supabase');
const { assinarToken } = require('./_auth');

const CORS = {
  'Access-Control-Allow-Origin': process.env.APP_ORIGIN || '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
};

// Rate limiting simples em memória (por IP)
const tentativas = new Map();
function rateLimitar(ip) {
  const agora = Date.now();
  const reg = tentativas.get(ip) || { count: 0, reset: agora + 60000 };
  if (agora > reg.reset) { reg.count = 0; reg.reset = agora + 60000; }
  reg.count++;
  tentativas.set(ip, reg);
  return reg.count > 10; // max 10 tentativas por minuto por IP
}

module.exports = async (req, res) => {
  Object.entries(CORS).forEach(([k, v]) => res.setHeader(k, v));

  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ erro: 'Método não permitido' });

  const ip = req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown';
  if (rateLimitar(ip)) {
    return res.status(429).json({ erro: 'Muitas tentativas. Aguarde 1 minuto.' });
  }

  let body = req.body;
  if (typeof body === 'string') body = JSON.parse(body);
  const { email, senha } = body || {};

  if (!email || !senha || typeof email !== 'string' || typeof senha !== 'string') {
    return res.status(400).json({ erro: 'E-mail e senha são obrigatórios' });
  }

  // Sanitiza input
  const emailLimpo = email.toLowerCase().trim().slice(0, 100);
  const senhaLimpa = senha.slice(0, 128);

  try {
    const sbData = await sbAuthLogin(emailLimpo, senhaLimpa);
    if (!sbData || !sbData.user) {
      return res.status(401).json({ erro: 'Credenciais inválidas' });
    }

    // Carrega perfil do banco
    const [perfil] = await sbGet('perfis', `id=eq.${sbData.user.id}&select=*`);
    if (!perfil) {
      return res.status(401).json({ erro: 'Perfil não encontrado. Contate o administrador.' });
    }

    // Cria token de sessão próprio (Supabase JWT fica no servidor)
    const token = assinarToken({
      uid: sbData.user.id,
      email: emailLimpo,
      perfil: perfil.perfil,
      condominio_id: perfil.condominio_id,
      empresa_id: perfil.empresa_id,
      nome: perfil.nome,
      cargo: perfil.cargo,
    });

    return res.status(200).json({
      token,
      perfil: {
        nome: perfil.nome,
        cargo: perfil.cargo,
        perfil: perfil.perfil,
        foto_url: perfil.foto_url,
        condominio_id: perfil.condominio_id,
      }
    });

  } catch (err) {
    console.error('[auth]', err.message);
    return res.status(500).json({ erro: 'Erro interno. Tente novamente.' });
  }
};
