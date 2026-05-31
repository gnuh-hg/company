// Phase E+F data-layer server.
//
// Serves the built front-end (app/dist/) as static files and exposes a tiny
// JSON API. Dependency-free (Node http/fs/child_process only). Binds localhost.
//
// Phase E endpoints: GET /api/health · /api/projects · /api/graph · GET/POST /api/layout
// Phase F endpoints (F.1): POST /api/run (spawn run.ps1, race-safe discovery)
//                  (F.2): GET /api/events (SSE tail) · POST /api/decision (resume)

import { createServer } from 'node:http';
import { readFile, stat, readdir, writeFile, open } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, extname, normalize, resolve, basename } from 'node:path';
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

// Run registry: Map<runId → {child, project, runDir, mockMode, status, startedAt}>
const runRegistry = new Map();

// Read the current run pointer from <projectDir>/.runs/latest.json (null if absent).
async function snapshotLatestRun(projectDir) {
  try {
    const raw = await readFile(join(projectDir, '.runs', 'latest.json'), 'utf-8');
    return JSON.parse(raw).run || null;
  } catch { return null; }
}

// Poll latest.json until its `run` field differs from prevRun (new run appeared).
// Returns the new run-id string, or null on timeout.
async function pollForNewRunDir(projectDir, prevRun, timeoutMs = 10000, intervalMs = 200) {
  const deadline = Date.now() + timeoutMs;
  return new Promise((resolve) => {
    const timer = setInterval(async () => {
      try {
        const raw = await readFile(join(projectDir, '.runs', 'latest.json'), 'utf-8');
        const latest = JSON.parse(raw);
        if (latest.run && latest.run !== prevRun) {
          clearInterval(timer);
          resolve(latest.run);
          return;
        }
      } catch {}
      if (Date.now() >= deadline) {
        clearInterval(timer);
        resolve(null);
      }
    }, intervalMs);
  });
}

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

// Resolve the on-disk directory of a named project (precedence: projects > examples > hq).
// Returns the absolute path, or null if the project doesn't exist / name is unsafe.
async function resolveProjectDir(name) {
  if (!SAFE_PROJECT.test(name)) return null;
  if (name === 'hq') {
    try { await stat(join(COMPANY, 'hq', 'workflow.json')); return join(COMPANY, 'hq'); } catch { return null; }
  }
  for (const base of ['projects', 'examples']) {
    const dir = join(COMPANY, base, name);
    try { await stat(join(dir, 'workflow.json')); return dir; } catch {}
  }
  return null;
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

  if (pathname === '/api/layout' && req.method === 'GET') {
    const project = url.searchParams.get('project');
    if (!project) return sendJson(res, 400, { error: 'missing project param' });
    const dir = await resolveProjectDir(project);
    if (!dir) return sendJson(res, 404, { error: 'project not found' });
    try {
      const content = await readFile(join(dir, '.layout.json'), 'utf-8');
      return sendJson(res, 200, JSON.parse(content));
    } catch {
      return sendJson(res, 200, {}); // no layout yet
    }
  }

  if (pathname === '/api/layout' && req.method === 'POST') {
    const project = url.searchParams.get('project');
    if (!project) return sendJson(res, 400, { error: 'missing project param' });
    const dir = await resolveProjectDir(project);
    if (!dir) return sendJson(res, 404, { error: 'project not found' });
    let body = '';
    try {
      for await (const chunk of req) body += chunk;
    } catch { return sendJson(res, 400, { error: 'failed reading body' }); }
    let data;
    try { data = JSON.parse(body); } catch { return sendJson(res, 400, { error: 'invalid JSON body' }); }
    if (!data.positions || typeof data.positions !== 'object') {
      return sendJson(res, 400, { error: 'body must have .positions object' });
    }
    const layout = { positions: data.positions, version: 1 };
    await writeFile(join(dir, '.layout.json'), JSON.stringify(layout, null, 2), 'utf-8');
    return sendJson(res, 200, { ok: true });
  }

  // POST /api/run — spawn run.ps1 run <project> [request] [-Mock] [-AutoApprove]
  // Body: {project, request?, mock?:true, autoApprove?:false}
  // Returns: {runId, runDir, project}
  if (pathname === '/api/run' && req.method === 'POST') {
    let body = '';
    try { for await (const chunk of req) body += chunk; }
    catch { return sendJson(res, 400, { error: 'failed reading body' }); }
    let data;
    try { data = JSON.parse(body); } catch { return sendJson(res, 400, { error: 'invalid JSON body' }); }

    const { project, request, mock = true, autoApprove = false } = data;
    if (!project) return sendJson(res, 400, { error: 'missing project' });
    if (!SAFE_PROJECT.test(project)) return sendJson(res, 400, { error: 'invalid project name' });
    const projectDir = await resolveProjectDir(project);
    if (!projectDir) return sendJson(res, 404, { error: 'project not found' });

    const prevRun = await snapshotLatestRun(projectDir);

    // Engine requires a non-empty request string; default to "run" when omitted.
    const reqStr = (request && String(request).trim()) || 'run';
    const args = ['-NoProfile', '-File', ENGINE_RUN, 'run', project, reqStr];
    if (mock !== false) args.push('-Mock');
    if (autoApprove) args.push('-AutoApprove');

    let child;
    try { child = spawn(PWSH, args, { cwd: COMPANY }); }
    catch (e) { return sendJson(res, 500, { error: `cannot spawn pwsh: ${e.message}` }); }
    // Drain stdout/stderr so the child never blocks on a full pipe.
    child.stdout.resume();
    child.stderr.resume();

    const newRunId = await pollForNewRunDir(projectDir, prevRun);
    if (!newRunId) {
      try { child.kill(); } catch {}
      return sendJson(res, 504, { error: 'run dir not detected within timeout' });
    }

    const runDir = join(projectDir, '.runs', newRunId);
    runRegistry.set(newRunId, {
      child, project, runDir,
      mockMode: mock !== false,
      status: 'running',
      startedAt: new Date().toISOString(),
    });
    child.on('close', () => {
      const entry = runRegistry.get(newRunId);
      if (entry) entry.status = 'closed';
    });

    return sendJson(res, 200, { runId: newRunId, runDir, project });
  }

  // GET /api/events?project=<p>&run=<runId> — SSE tail of <run>/events.ndjson.
  // Streams every NDJSON line as a `data:` frame from the start of the run.
  // Stays open across an `awaiting` pause (resume appends to the SAME file) and
  // closes only after a `run_end` event. Heartbeat keeps the connection alive.
  if (pathname === '/api/events' && req.method === 'GET') {
    const project = url.searchParams.get('project');
    const run = url.searchParams.get('run');
    if (!project || !run) return sendJson(res, 400, { error: 'missing project or run param' });
    if (!SAFE_PROJECT.test(project) || !SAFE_PROJECT.test(run)) {
      return sendJson(res, 400, { error: 'invalid project or run name' });
    }
    const projectDir = await resolveProjectDir(project);
    if (!projectDir) return sendJson(res, 404, { error: 'project not found' });
    const eventsPath = join(projectDir, '.runs', run, 'events.ndjson');

    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no',
    });
    res.write('retry: 2000\n\n');

    let offset = 0;
    let pending = Buffer.alloc(0);
    let ended = false;

    const finish = () => {
      if (ended) return;
      ended = true;
      clearInterval(tailTimer);
      clearInterval(beatTimer);
      try { res.write('event: end\ndata: {}\n\n'); res.end(); } catch {}
    };

    // Read new bytes since `offset`, emit complete lines only. Decoding stops at
    // the last newline so multi-byte UTF-8 never splits across a tick.
    const tick = async () => {
      if (ended) return;
      let size;
      try { size = (await stat(eventsPath)).size; }
      catch { return; } // file not created yet
      if (size <= offset) return;
      let fh;
      try {
        fh = await open(eventsPath, 'r');
        const len = size - offset;
        const buf = Buffer.alloc(len);
        await fh.read(buf, 0, len, offset);
        offset = size;
        pending = Buffer.concat([pending, buf]);
      } catch { return; }
      finally { if (fh) await fh.close(); }

      const lastNl = pending.lastIndexOf(0x0a);
      if (lastNl === -1) return;
      const complete = pending.subarray(0, lastNl + 1).toString('utf-8');
      pending = pending.subarray(lastNl + 1);
      for (const raw of complete.split('\n')) {
        const line = raw.trim();
        if (!line) continue;
        res.write('data: ' + line + '\n\n');
        let evt;
        try { evt = JSON.parse(line); } catch { continue; }
        if (evt.type === 'run_end') { finish(); return; }
      }
    };

    const tailTimer = setInterval(tick, 300);
    const beatTimer = setInterval(() => {
      if (!ended) { try { res.write(': ping\n\n'); } catch {} }
    }, 15000);
    req.on('close', () => {
      if (ended) return;
      ended = true;
      clearInterval(tailTimer);
      clearInterval(beatTimer);
    });
    tick();
    return;
  }

  // POST /api/decision — resume an awaiting run on the SAME run dir.
  // Body: {project, run, decision}. Spawns `run.ps1 resume … -Decision <label>`;
  // the open SSE picks up the newly-appended events (resume continues the same
  // events.ndjson, seq self-sequencing). Reuses the run's original mock mode.
  if (pathname === '/api/decision' && req.method === 'POST') {
    let body = '';
    try { for await (const chunk of req) body += chunk; }
    catch { return sendJson(res, 400, { error: 'failed reading body' }); }
    let data;
    try { data = JSON.parse(body); } catch { return sendJson(res, 400, { error: 'invalid JSON body' }); }

    const { project, run, decision } = data;
    if (!project || !run || !decision) return sendJson(res, 400, { error: 'missing project, run, or decision' });
    if (!SAFE_PROJECT.test(project) || !SAFE_PROJECT.test(run)) {
      return sendJson(res, 400, { error: 'invalid project or run name' });
    }
    if (!/^[A-Za-z0-9_-]+$/.test(decision)) return sendJson(res, 400, { error: 'invalid decision label' });
    const projectDir = await resolveProjectDir(project);
    if (!projectDir) return sendJson(res, 404, { error: 'project not found' });

    const entry = runRegistry.get(run);
    const mockMode = entry ? entry.mockMode : true; // default mock = safe (no token burn)
    const args = ['-NoProfile', '-File', ENGINE_RUN, 'resume', project, '-Decision', decision];
    if (mockMode) args.push('-Mock');

    let child;
    try { child = spawn(PWSH, args, { cwd: COMPANY }); }
    catch (e) { return sendJson(res, 500, { error: `cannot spawn pwsh: ${e.message}` }); }
    child.stdout.resume();
    child.stderr.resume();
    if (entry) {
      entry.child = child;
      entry.status = 'running';
      child.on('close', () => { entry.status = 'closed'; });
    }

    return sendJson(res, 200, { ok: true });
  }

  if (pathname.startsWith('/api/')) {
    return sendJson(res, 404, { error: 'unknown endpoint', path: pathname });
  }

  return serveStatic(req, res, pathname);
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`[workflow-viewer] serving on http://127.0.0.1:${PORT}`);
});
