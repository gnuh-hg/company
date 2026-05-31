import { useEffect, useMemo, useRef, useState } from 'react';
import { ReactFlowProvider } from '@xyflow/react';
import GraphView from './GraphView.jsx';
import RunLog from './RunLog.jsx';
import ApprovalPanel from './ApprovalPanel.jsx';
import RealConfirmDialog from './RealConfirmDialog.jsx';

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

  // Real-run guard + decision state
  const [realMode, setRealMode] = useState(false);
  const [showRealConfirm, setShowRealConfirm] = useState(false);
  const [decisionPending, setDecisionPending] = useState(false);

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

  // Run button: Real mode opens the confirm dialog first; Mock runs immediately.
  function handleRunClick() {
    if (!selected || runStatus === 'running') return;
    if (realMode) { setShowRealConfirm(true); return; }
    handleRun(true);
  }

  function handleRun(mock) {
    if (!selected) return;

    // Close any existing stream
    esRef.current?.close();
    esRef.current = null;

    setEvents([]);
    setRunStatus('running');
    setRunErr(null);
    setRunId(null);
    setDecisionPending(false);

    fetch('/api/run', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ project: selected, mock }),
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
    setDecisionPending(false);
  }

  // Approval gate: POST the chosen `when` label → engine resumes on the SAME run
  // dir; the open EventSource picks up the appended events. We just flip status
  // back to running so the panel hides and the log keeps streaming.
  function handleDecision(label) {
    if (!runId || decisionPending) return;
    setDecisionPending(true);
    fetch('/api/decision', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ project: selected, run: runId, decision: label }),
    })
      .then(r => r.ok ? r.json() : r.json().then(b => Promise.reject(b.error ?? r.statusText)))
      .then(() => {
        setRunStatus('running');
        setDecisionPending(false);
      })
      .catch(err => {
        setDecisionPending(false);
        setRunErr(`decision failed: ${String(err)}`);
      });
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

  // The active awaiting event (last one wins) + any diff_violation paths that
  // arrived after the most recent resume — surfaced in the approval panel.
  const { awaitingEvt, pendingViolations } = useMemo(() => {
    let aw = null;
    const viols = [];
    for (const evt of events) {
      if (evt.type === 'awaiting') aw = evt;
      else if (evt.type === 'resumed') { aw = null; viols.length = 0; }
      else if (evt.type === 'diff_violation' && Array.isArray(evt.violations)) {
        viols.push(...evt.violations);
      }
    }
    return { awaitingEvt: aw, pendingViolations: viols };
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
          onClick={handleRunClick}
          disabled={!selected || runStatus === 'running'}
          title={realMode
            ? 'Run selected project for REAL (burns tokens — confirms first)'
            : 'Run selected project in mock mode (no token burn)'}
          style={{
            marginLeft: 8,
            padding: '5px 14px',
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: 700,
            background: runStatus === 'running' ? '#e2e8f0' : (realMode ? '#dc2626' : '#3b82f6'),
            color: runStatus === 'running' ? '#94a3b8' : '#fff',
            border: 'none',
            borderRadius: 6,
            cursor: runStatus === 'running' ? 'not-allowed' : 'pointer',
            transition: 'background 0.15s',
          }}
        >
          {runStatus === 'running' ? '⏳ Running…' : (realMode ? '▶ Run (Real)' : '▶ Run (Mock)')}
        </button>

        {/* Real toggle */}
        <label
          title="Real runs invoke the model and burn tokens"
          style={{
            display: 'flex', alignItems: 'center', gap: 4,
            fontSize: 11, fontFamily: 'monospace',
            color: realMode ? '#dc2626' : '#94a3b8',
            cursor: runStatus === 'running' ? 'not-allowed' : 'pointer',
            userSelect: 'none',
          }}
        >
          <input
            type="checkbox"
            checked={realMode}
            disabled={runStatus === 'running'}
            onChange={e => setRealMode(e.target.checked)}
            style={{ cursor: 'inherit' }}
          />
          Real
        </label>

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
          <div style={{ display: 'flex', flexDirection: 'column', flexShrink: 0, maxHeight: '55vh' }}>
            {runStatus === 'awaiting' && awaitingEvt && (
              <ApprovalPanel
                awaiting={awaitingEvt}
                violations={pendingViolations}
                pending={decisionPending}
                onDecide={handleDecision}
              />
            )}
            <div style={{ height: LOG_HEIGHT, flexShrink: 0 }}>
              <RunLog
                events={events}
                runStatus={runStatus}
                error={runErr}
                onClear={handleClear}
              />
            </div>
          </div>
        )}
      </main>

      {showRealConfirm && (
        <RealConfirmDialog
          project={selected}
          onCancel={() => setShowRealConfirm(false)}
          onConfirm={() => { setShowRealConfirm(false); handleRun(false); }}
        />
      )}
    </div>
  );
}
