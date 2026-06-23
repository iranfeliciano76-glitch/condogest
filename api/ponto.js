// POST /api/ponto — Registra ponto eletrônico (Supabase invisível)
const { sbInsert, sbGet } = require('./_supabase');
const { verificarToken } = require('./_auth');

const CORS = {
  'Access-Control-Allow-Origin': process.env.APP_ORIGIN || '*',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Content-Type': 'application/json',
};

module.exports = async (req, res) => {
  Object.entries(CORS).forEach(([k, v]) => res.setHeader(k, v));
  if (req.method === 'OPTIONS') return res.status(204).end();

  const rawToken = (req.headers.authorization || '').replace('Bearer ', '').trim();
  let sessao;
  try { sessao = verificarToken(rawToken); }
  catch { return res.status(401).json({ erro: 'Sessão inválida' }); }

  // GET — relatório de pontos (apenas admin/superadmin)
  if (req.method === 'GET') {
    if (!['admin','superadmin'].includes(sessao.perfil)) {
      return res.status(403).json({ erro: 'Acesso restrito a administradores' });
    }
    const { de, ate, fiscal_id } = req.query;
    let query = `condominio_id=eq.${sessao.condominio_id}&order=registrado_em.desc`;
    if (de)  query += `&registrado_em=gte.${de}`;
    if (ate) query += `&registrado_em=lte.${ate}`;
    if (fiscal_id) query += `&fiscal_id=eq.${fiscal_id}`;
    const dados = await sbGet('pontos', query + '&select=*,perfis(nome,cargo)');
    return res.json(dados);
  }

  // POST — registrar ponto
  if (req.method !== 'POST') return res.status(405).json({ erro: 'Método não permitido' });

  let body = req.body;
  if (typeof body === 'string') body = JSON.parse(body);

  const { tipo, selfie_url, lat, lng, precisao, endereco, link_mapa } = body || {};

  const TIPOS_VALIDOS = ['ENTRADA','SAIDA','INICIO_INTERVALO','FIM_INTERVALO'];
  if (!tipo || !TIPOS_VALIDOS.includes(tipo)) {
    return res.status(400).json({ erro: 'Tipo de ponto inválido' });
  }

  try {
    const row = {
      condominio_id: sessao.condominio_id,
      fiscal_id: sessao.uid,
      tipo,
      selfie_url: selfie_url || null,
      lat: lat ? Number(lat) : null,
      lng: lng ? Number(lng) : null,
      precisao: precisao ? Number(precisao) : null,
      endereco: endereco ? String(endereco).slice(0, 200) : null,
      link_mapa: link_mapa || null,
    };

    const resultado = await sbInsert('pontos', row);
    return res.status(201).json({ ok: true, id: resultado?.[0]?.id });
  } catch (err) {
    console.error('[ponto]', err.message);
    return res.status(500).json({ erro: 'Falha ao registrar ponto.' });
  }
};
