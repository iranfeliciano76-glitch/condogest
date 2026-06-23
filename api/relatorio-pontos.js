// GET /api/relatorio-pontos — Relatório completo de ponto para admins
const { sbGet } = require('./_supabase');
const { verificarToken } = require('./_auth');

const CORS = {
  'Access-Control-Allow-Origin': process.env.APP_ORIGIN || '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Content-Type': 'application/json',
};

module.exports = async (req, res) => {
  Object.entries(CORS).forEach(([k, v]) => res.setHeader(k, v));
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'GET') return res.status(405).json({ erro: 'Método não permitido' });

  const rawToken = (req.headers.authorization || '').replace('Bearer ', '').trim();
  let sessao;
  try { sessao = verificarToken(rawToken); }
  catch { return res.status(401).json({ erro: 'Sessão inválida' }); }

  if (!['admin','superadmin'].includes(sessao.perfil)) {
    return res.status(403).json({ erro: 'Acesso restrito a administradores' });
  }

  const { de, ate, fiscal_id, pagina = 0, limite = 50 } = req.query;
  const offset = Number(pagina) * Number(limite);

  let query = `condominio_id=eq.${sessao.condominio_id}&order=registrado_em.desc`;
  query += `&limit=${Math.min(Number(limite), 200)}&offset=${offset}`;

  if (de)        query += `&registrado_em=gte.${de}T00:00:00`;
  if (ate)       query += `&registrado_em=lte.${ate}T23:59:59`;
  if (fiscal_id) query += `&fiscal_id=eq.${fiscal_id}`;

  try {
    // Pontos com join no perfil
    const pontos = await sbGet(
      'pontos',
      query + '&select=id,tipo,selfie_url,lat,lng,endereco,link_mapa,registrado_em,perfis(nome,cargo,foto_url)'
    );

    // Fiscais do condomínio (para o filtro)
    const fiscais = await sbGet(
      'perfis',
      `condominio_id=eq.${sessao.condominio_id}&perfil=eq.fiscal&select=id,nome,cargo,foto_url`
    );

    return res.json({ pontos, fiscais });
  } catch (err) {
    console.error('[relatorio-pontos]', err.message);
    return res.status(500).json({ erro: 'Erro ao buscar relatório' });
  }
};
