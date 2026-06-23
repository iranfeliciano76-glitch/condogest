// POST /api/registro — Salva checklist (Supabase invisível)
const { sbInsert } = require('./_supabase');
const { verificarToken } = require('./_auth');

const CORS = {
  'Access-Control-Allow-Origin': process.env.APP_ORIGIN || '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Content-Type': 'application/json',
};

module.exports = async (req, res) => {
  Object.entries(CORS).forEach(([k, v]) => res.setHeader(k, v));
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ erro: 'Método não permitido' });

  const rawToken = (req.headers.authorization || '').replace('Bearer ', '').trim();
  let sessao;
  try { sessao = verificarToken(rawToken); }
  catch { return res.status(401).json({ erro: 'Sessão inválida' }); }

  let body = req.body;
  if (typeof body === 'string') body = JSON.parse(body);

  const {
    ronda_id, categoria, area_id, item_id, item_label,
    status, foto_url, audio_url, lat, lng, precisao,
    endereco, link_mapa, token: tkn, observacao
  } = body || {};

  if (!item_id || !status || !['ok','nok'].includes(status)) {
    return res.status(400).json({ erro: 'Dados inválidos' });
  }

  try {
    const row = {
      ronda_id: ronda_id || null,
      condominio_id: sessao.condominio_id,
      fiscal_id: sessao.uid,
      categoria: String(categoria || '').slice(0, 50),
      area_id: area_id || null,
      item_id: String(item_id).slice(0, 80),
      item_label: String(item_label || '').slice(0, 120),
      status,
      foto_url: foto_url || null,
      audio_url: audio_url || null,
      lat: lat ? Number(lat) : null,
      lng: lng ? Number(lng) : null,
      precisao: precisao ? Number(precisao) : null,
      endereco: endereco ? String(endereco).slice(0, 200) : null,
      link_mapa: link_mapa || null,
      token: tkn || null,
      observacao: observacao ? String(observacao).slice(0, 500) : null,
    };

    const resultado = await sbInsert('registros', row);
    return res.status(201).json({ ok: true, id: resultado?.[0]?.id });
  } catch (err) {
    console.error('[registro]', err.message);
    return res.status(500).json({ erro: 'Falha ao salvar. Tente novamente.' });
  }
};
