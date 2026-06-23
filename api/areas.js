// GET /api/areas, POST /api/areas — Áreas dinâmicas por condomínio
const { sbGet, sbInsert, sbUpdate } = require('./_supabase');
const { verificarToken } = require('./_auth');

const CORS = {
  'Access-Control-Allow-Origin': process.env.APP_ORIGIN || '*',
  'Access-Control-Allow-Methods': 'GET, POST, PATCH, OPTIONS',
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

  if (req.method === 'GET') {
    const cat = req.query.categoria;
    let query = `condominio_id=eq.${sessao.condominio_id}&ativo=eq.true&order=ordem.asc`;
    if (cat) query += `&categoria=eq.${cat}`;
    const areas = await sbGet('areas', query + '&select=id,categoria,nome,ordem');
    return res.json(areas);
  }

  if (req.method === 'POST') {
    let body = req.body;
    if (typeof body === 'string') body = JSON.parse(body);
    const { categoria, nome } = body || {};
    const CATS_VALIDAS = ['corredores','estacionamento','lojas','limpeza'];
    if (!categoria || !CATS_VALIDAS.includes(categoria) || !nome) {
      return res.status(400).json({ erro: 'Categoria e nome são obrigatórios' });
    }
    const resultado = await sbInsert('areas', {
      condominio_id: sessao.condominio_id,
      categoria,
      nome: String(nome).slice(0, 80),
    });
    return res.status(201).json(resultado?.[0]);
  }

  if (req.method === 'PATCH') {
    let body = req.body;
    if (typeof body === 'string') body = JSON.parse(body);
    const { id, ativo } = body || {};
    if (!id) return res.status(400).json({ erro: 'ID obrigatório' });
    await sbUpdate('areas', `id=eq.${id}&condominio_id=eq.${sessao.condominio_id}`, { ativo });
    return res.json({ ok: true });
  }

  return res.status(405).json({ erro: 'Método não permitido' });
};
