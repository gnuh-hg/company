// Phase E data-layer server (skeleton — E.1).
//
// Serves the built front-end (app/dist/) as static files and exposes a tiny
// JSON API. E.1 ships only `GET /api/health`; E.2 adds `/api/projects` and
// `/api/graph` (shelling out to `run.ps1 graph <proj> -Json`), E.5 adds
// `GET/POST /api/layout`. Kept dependency-free (Node http only) — full-local,
// no cloud, no run-control/SSE (those belong to Phase F).

import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { join, extname, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';
import { dirname } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DIST_DIR = join(__dirname, 'dist');
const PORT = Number(process.env.PORT) || 5179;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.png': 'image/png',
  '.map': 'application/json; charset=utf-8',
};

function sendJson(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

async function serveStatic(req, res, pathname) {
  // Resolve within DIST_DIR only (no path traversal). SPA fallback → index.html.
  const rel = normalize(pathname).replace(/^(\.\.[/\\])+/, '');
  let filePath = join(DIST_DIR, rel === '/' || rel === '' ? 'index.html' : rel);

  try {
    const info = await stat(filePath);
    if (info.isDirectory()) filePath = join(filePath, 'index.html');
  } catch {
    // Unknown path → SPA index fallback (front-end router handles it).
    filePath = join(DIST_DIR, 'index.html');
  }

  try {
    const data = await readFile(filePath);
    const type = MIME[extname(filePath)] || 'application/octet-stream';
    res.writeHead(200, { 'Content-Type': type });
    res.end(data);
  } catch {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not found. Run `npm run build` first to populate app/dist/.');
  }
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const { pathname } = url;

  if (pathname === '/api/health') {
    return sendJson(res, 200, { ok: true });
  }

  if (pathname.startsWith('/api/')) {
    return sendJson(res, 404, { error: 'unknown endpoint', path: pathname });
  }

  return serveStatic(req, res, pathname);
});

server.listen(PORT, () => {
  console.log(`[workflow-viewer] serving on http://localhost:${PORT}`);
});
