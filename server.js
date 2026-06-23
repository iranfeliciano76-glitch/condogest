// CondoGest — Servidor de desenvolvimento local
// Acesse: http://localhost:3000

const http = require('http');
const fs   = require('fs');
const path = require('path');

const PORT    = 3000;
const ROOT    = __dirname;
const MIMES   = {
  '.html':'.html', '.css':'text/css', '.js':'application/javascript',
  '.json':'application/json', '.png':'image/png', '.jpg':'image/jpeg',
  '.svg':'image/svg+xml', '.ico':'image/x-icon', '.webm':'audio/webm',
  '.mp3':'audio/mpeg', '.ogg':'audio/ogg',
};

http.createServer((req, res) => {
  // CORS para desenvolvimento
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }

  let urlPath = req.url.split('?')[0];
  if (urlPath === '/' || urlPath === '') urlPath = '/index.html';

  let filePath = path.join(ROOT, urlPath);

  // Se é diretório, tenta index.html dentro
  if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
    filePath = path.join(filePath, 'index.html');
  }

  const ext  = path.extname(filePath).toLowerCase();
  const mime = MIMES[ext] || 'text/plain';

  fs.readFile(filePath, (err, data) => {
    if (err) {
      // Retorna índice de navegação
      const dirs = ['/', '/mobile/', '/admin/', '/sql/'];
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      return res.end(`<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
        <title>CondoGest — Dev Server</title>
        <style>body{font-family:system-ui;max-width:500px;margin:60px auto;padding:20px;background:#0f172a;color:#f1f5f9}
        h1{color:#60a5fa;font-size:22px}a{display:block;background:#1e293b;color:#93c5fd;padding:14px 20px;
        border-radius:10px;margin:10px 0;text-decoration:none;font-size:16px;font-weight:600}
        a:hover{background:#334155}p{color:#64748b;font-size:13px}</style></head>
        <body><h1>🏢 CondoGest — Servidor Local</h1><p>ronda.prointegraserv.com.br (produção)</p>
        <a href="/mobile/">📱 App Mobile — Fiscais de Piso</a>
        <a href="/admin/">🖥️ Painel Administrativo</a>
        <a href="/sql/schema.sql">🗄️ Schema SQL</a>
        </body></html>`);
    }
    res.writeHead(200, { 'Content-Type': mime + '; charset=utf-8' });
    res.end(data);
  });
}).listen(PORT, () => {
  console.log('');
  console.log('  ✅ CondoGest rodando em http://localhost:' + PORT);
  console.log('');
  console.log('  📱 App Mobile   → http://localhost:' + PORT + '/mobile/');
  console.log('  🖥️  Admin Panel  → http://localhost:' + PORT + '/admin/');
  console.log('');
  console.log('  Produção: https://ronda.prointegraserv.com.br');
  console.log('');
});
