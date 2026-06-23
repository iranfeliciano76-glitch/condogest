// Helper: chama a Supabase REST API com service role (server-side only)
const SB_URL  = process.env.SUPABASE_URL;
const SB_ANON = process.env.SUPABASE_ANON_KEY;
const SB_SVC  = process.env.SUPABASE_SERVICE_ROLE;

function headers(useServiceRole = false) {
  const key = useServiceRole ? SB_SVC : SB_ANON;
  return {
    'Content-Type': 'application/json',
    'apikey': key,
    'Authorization': `Bearer ${key}`,
    'Prefer': 'return=representation',
  };
}

async function sbGet(tabela, query = '', useServiceRole = true) {
  const r = await fetch(`${SB_URL}/rest/v1/${tabela}?${query}&limit=1000`, {
    headers: headers(useServiceRole),
  });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}

async function sbInsert(tabela, dados, useServiceRole = true) {
  const r = await fetch(`${SB_URL}/rest/v1/${tabela}`, {
    method: 'POST',
    headers: headers(useServiceRole),
    body: JSON.stringify(dados),
  });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}

async function sbUpdate(tabela, query, dados, useServiceRole = true) {
  const r = await fetch(`${SB_URL}/rest/v1/${tabela}?${query}`, {
    method: 'PATCH',
    headers: headers(useServiceRole),
    body: JSON.stringify(dados),
  });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}

async function sbAuthLogin(email, password) {
  const r = await fetch(`${SB_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'apikey': SB_ANON },
    body: JSON.stringify({ email, password }),
  });
  if (!r.ok) return null;
  return r.json();
}

module.exports = { sbGet, sbInsert, sbUpdate, sbAuthLogin };
