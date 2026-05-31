import { useEffect, useState } from 'react';

// E.1 scaffold placeholder. The interactive graph (React Flow + dagre) lands in
// E.3; for now this just confirms the front-end ↔ server data-layer wiring by
// pinging /api/health.
export default function App() {
  const [health, setHealth] = useState('checking…');

  useEffect(() => {
    fetch('/api/health')
      .then((r) => r.json())
      .then((d) => setHealth(d.ok ? 'ok' : 'unexpected'))
      .catch(() => setHealth('unreachable'));
  }, []);

  return (
    <div className="flex h-full flex-col items-center justify-center gap-3 bg-slate-50 text-slate-800">
      <h1 className="text-2xl font-semibold">Workflow Viewer</h1>
      <p className="text-sm text-slate-500">company/ engine — Phase E scaffold</p>
      <p className="text-sm">
        server: <span className="font-mono">{health}</span>
      </p>
    </div>
  );
}
