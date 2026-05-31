import { useEffect, useState } from 'react';
import { ReactFlowProvider } from '@xyflow/react';
import GraphView from './GraphView.jsx';

export default function App() {
  const [projects, setProjects] = useState([]);
  const [selected, setSelected] = useState('');
  const [loadErr, setLoadErr] = useState(null);

  useEffect(() => {
    fetch('/api/projects')
      .then(r => r.json())
      .then(list => {
        setProjects(list);
        // Default to 'hq' if present, else first entry
        const def = list.find(p => p.name === 'hq') ?? list[0];
        if (def) setSelected(def.name);
      })
      .catch(() => setLoadErr('Could not load project list.'));
  }, []);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh', background: '#f8fafc' }}>
      {/* ── Header ── */}
      <header style={{
        display: 'flex', alignItems: 'center', gap: 12,
        padding: '0 16px', height: 48,
        background: '#fff', borderBottom: '1px solid #e2e8f0',
        flexShrink: 0,
      }}>
        <span style={{ fontWeight: 700, fontSize: 14, color: '#0f172a', fontFamily: 'monospace' }}>
          Workflow Viewer
        </span>
        <span style={{ color: '#cbd5e1', fontSize: 12 }}>company/</span>

        {loadErr ? (
          <span style={{ fontSize: 12, color: '#ef4444' }}>{loadErr}</span>
        ) : (
          <select
            value={selected}
            onChange={e => setSelected(e.target.value)}
            style={{
              marginLeft: 8,
              padding: '4px 8px',
              fontSize: 13,
              fontFamily: 'monospace',
              border: '1px solid #cbd5e1',
              borderRadius: 6,
              background: '#f8fafc',
              color: '#334155',
              cursor: 'pointer',
            }}
          >
            {projects.length === 0 && <option value="">Loading…</option>}
            {projects.map(p => (
              <option key={p.name} value={p.name}>
                {p.name}
                {p.source !== 'hq' ? ` (${p.source})` : ''}
              </option>
            ))}
          </select>
        )}
      </header>

      {/* ── Graph area ── */}
      <main style={{ flex: 1, position: 'relative', overflow: 'hidden' }}>
        <ReactFlowProvider>
          <GraphView project={selected} />
        </ReactFlowProvider>
      </main>
    </div>
  );
}
