// Phase E data-layer server (skeleton — E.1).
//
// Serves the built front-end (app/dist/) as static files and exposes a tiny
// JSON API. E.1 ships only `GET /api/health`; E.2 adds `/api/projects` and
// `/api/graph` (shelling out to `run.ps1 graph <proj> -Json`), E.5 adds
// `GET/POST /api/layout`. Kept dependency-free (Node http only) — full-local,
// no cloud, no run-control/SSE (those belong to Phase F).

import { createServer } from 'node:http';
import { readFile, stat, readdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, extname, normalize, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { dirname } from 'node:path';
import { spawn } from 'node:child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DIST_DIR = join(__dirname, 'dist');
const COMPANY = resolve(__dirname, '..');
const ENGINE_RUN = join(COMPANY, 'engine', 'run.ps1');
const PWSH = process.env.PWSH || 'pwsh';
const PORT = Number(process.env.PORT) || 5179;
const SAFE_PROJECT = /^[A-Za-z0-9._-]+$/;

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

// List drawable projects (those with a workflow.json). Resolve precedence
// matches the engine: projects/ > examples/ > hq (earlier source wins on name).
async function listProjects() {
  const seen = new Map(); // name -> source
  const scan = async (source, dir) => {
    if (!existsSync(dir)) return;
    let entries = [];
    try { entries = await readdir(dir, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      if (!e.isDirectory()) continue;
      if (existsSync(join(dir, e.name, 'workflow.json')) && !seen.has(e.name)) {
        seen.set(e.name, source);
      }
    }
  };
  await scan('projects', join(COMPANY, 'projects'));
  await scan('examples', join(COMPANY, 'examples'));
  if (existsSync(join(COMPANY, 'hq', 'workflow.json')) && !seen.has('hq')) seen.set('hq', 'hq');
  return [...seen.entries()]
    .map(([name, source]) => ({ name, source }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

// Shell `run.ps1 graph <proj> -Json` → normalized graph. The engine reads the
// UTF-16 workflow.json itself (Get-Graph), so we never parse it in JS. Trust the
// stdout CONTENT, not the exit code (pwsh can core-dump on teardown).
function getGraphJson(project) {
  return new Promise((res) => {
    if (!SAFE_PROJECT.test(project)) {
      return res({ ok: false, status: 400, error: 'invalid project name' });
    }
    let child;
    try {
      child = spawn(PWSH, ['-NoProfile', '-File', ENGINE_RUN, 'graph', project, '-Json'], { cwd: COMPANY });
    } catch (e) {
      return res({ ok: false, status: 500, error: `cannot spawn ${PWSH}: ${e.message}` });
    }
    let out = '', err = '';
    child.stdout.on('data', (d) => { out += d; });
    child.stderr.on('data', (d) => { err += d; });
    child.on('error', (e) => res({ ok: false, status: 500, error: e.message }));
    child.on('close', () => {
      const start = out.indexOf('{'), end = out.lastIndexOf('}');
      if (start === -1 || end < start) {
        return res({ ok: false, status: 502, error: 'engine produced no JSON', stderr: err.trim() });
      }
      try { res({ ok: true, graph: JSON.parse(out.slice(start, end + 1)) }); }
      catch (e) { res({ ok: false, status: 502, error: `bad JSON from engine: ${e.message}` }); }
    });
  });
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

  if (pathname === '/api/projects') {
    try { return sendJson(res, 200, await listProjects()); }
    catch (e) { return sendJson(res, 500, { error: e.message }); }
  }

  if (pathname === '/api/graph') {
    const project = url.searchParams.get('project');
    if (!project) return sendJson(res, 400, { error: 'missing project param' });
    const r = await getGraphJson(project);
    if (r.ok) return sendJson(res, 200, r.graph);
    return sendJson(res, r.status || 500, { error: r.error, stderr: r.stderr });
  }

  if (pathname.startsWith('/api/')) {
    return sendJson(res, 404, { error: 'unknown endpoint', path: pathname });
  }

  return serveStatic(req, res, pathname);
});

server.listen(PORT, () => {
  console.log(`[workflow-viewer] serving on http://localhost:${PORT}`);
});
