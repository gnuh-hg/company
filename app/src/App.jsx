import { useEffect, useMemo, useRef, useState } from 'react';
import { ReactFlowProvider } from '@xyflow/react';
import GraphView from './GraphView.jsx';
import RunLog from './RunLog.jsx';

const LOG_HEIGHT = 280;

export default function App() {
  const [projects, setProjects] = useState([]);
  const [selected, setSelected] = useState('');
  const [loadErr, setLoadErr] = useState(null);

  // Run state
  const [runId, setRunId] = useState(null);
  const [events, setEvents] = useState([]);
  const [runStatus, setRunStatus] = useState('idle'); // idle|running|done|awaiting|failed
  const [runErr, setRunErr] = useState(null);
  const esRef = useRef(null);

  useEffect(() => {
    fetch('/api/projects')
      .then(r => r.json())
      .then(list => {
        setProjects(list);
        const def = list.find(p => p.name === 'hq') ?? list[0];
        if (def) setSelected(def.name);
      })
      .catch(() => setLoadErr('Could not load project list.'));
  }, []);

  // Clean up EventSource on unmount
  useEffect(() => () => { esRef.current?.close(); }, []);

  function handleRun() {
    if (!selected || runStatus === 'running') return;

    // Close any existing stream
    esRef.current?.close();
    esRef.current = null;

    setEvents([]);
    setRunStatus('running');
    setRunErr(null);
    setRunId(null);

    fetch('/api/run', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ project: selected, mock: true }),
    })
      .then(r => r.ok ? r.json() : r.json().then(b => Promise.reject(b.error ?? r.statusText)))
      .then(({ runId: rid }) => {
        setRunId(rid);

        const es = new EventSource(
          `/api/events?project=${encodeURIComponent(selected)}&run=${encodeURIComponent(rid)}`
        );
        esRef.current = es;

        es.onmessage = (e) => {
          try {
            const evt = JSON.parse(e.data);
            setEvents(prev => {
              if (prev.some(p => p.seq === evt.seq)) return prev;
              return [...prev, evt].sort((a, b) => a.seq - b.seq);
            });
            if (evt.type === 'run_end') {
              setRunStatus(evt.status === 'done' ? 'done' : 'failed');
            } else if (evt.type === 'awaiting') {
              setRunStatus('awaiting');
            }
          } catch {}
        };

        es.addEventListener('end', () => {
          es.close();
          esRef.current = null;
          // run_end should have set status; guard against edge case
          setRunStatus(prev => prev === 'running' ? 'done' : prev);
        });

        es.onerror = () => {
          es.close();
          esRef.current = null;
          setRunStatus(prev => (prev === 'running' || prev === 'idle') ? 'failed' : prev);
        };
      })
      .catch(err => {
        setRunStatus('failed');
        setRunErr(String(err));
      });
  }

  function handleClear() {
    esRef.current?.close();
    esRef.current = null;
    setEvents([]);
    setRunStatus('idle');
    setRunErr(null);
    setRunId(null);
  }

  // Derive per-node run status from the live event stream (seq-ordered).
  // Last event for a node wins (handles loops re-visiting a node).
  const nodeStatuses = useMemo(() => {
    const m = {};
    for (const evt of events) {
      if (!evt.node) continue;
      switch (evt.type) {
        case 'node_start':
        case 'node_output': m[evt.node] = 'running'; break;
        case 'node_done':   m[evt.node] = 'done'; break;
        case 'awaiting':    m[evt.node] = 'awaiting'; break;
        default: break;
      }
    }
    return m;
  }, [events]);

  const showLog = events.length > 0 || runStatus !== 'idle';

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
            onChange={e => { setSelected(e.target.value); handleClear(); }}
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

        {/* Run button */}
        <button
          onClick={handleRun}
          disabled={!selected || runStatus === 'running'}
          title="Run selected project in mock mode (no token burn)"
          style={{
            marginLeft: 8,
            padding: '5px 14px',
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: 700,
            background: runStatus === 'running' ? '#e2e8f0' : '#3b82f6',
            color: runStatus === 'running' ? '#94a3b8' : '#fff',
            border: 'none',
            borderRadius: 6,
            cursor: runStatus === 'running' ? 'not-allowed' : 'pointer',
            transition: 'background 0.15s',
          }}
        >
          {runStatus === 'running' ? '⏳ Running…' : '▶ Run (Mock)'}
        </button>

      </header>

      {/* ── Graph + Log ── */}
      <main style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        {/* Graph area: grows to fill remaining space */}
        <div style={{ flex: 1, position: 'relative', overflow: 'hidden', minHeight: 0 }}>
          <ReactFlowProvider>
            <GraphView project={selected} nodeStatuses={nodeStatuses} />
          </ReactFlowProvider>
        </div>

        {/* Log panel: fixed height, slides in when run is active */}
        {showLog && (
          <div style={{ height: LOG_HEIGHT, flexShrink: 0 }}>
            <RunLog
              events={events}
              runStatus={runStatus}
              error={runErr}
              onClear={handleClear}
            />
          </div>
        )}
      </main>
    </div>
  );
}
