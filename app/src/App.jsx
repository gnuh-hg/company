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
  const [request, setRequest] = useState(''); // the task/prompt fed to the run (esp. HQ)
  const esRef = useRef(null);

  // Real-run guard + decision state
  const [realMode, setRealMode] = useState(false);
  const [showRealConfirm, setShowRealConfirm] = useState(false);
  const [decisionPending, setDecisionPending] = useState(false);

  // Edit mode state
  const [editMode, setEditMode] = useState(false);
  const [graphDirty, setGraphDirty] = useState(false);
  // null = unknown (loading), 'graph' = editable, 'pipeline-v1' = view-only (CLI edit only)
  const [graphFormat, setGraphFormat] = useState(null);

  useEffect(() => {
    fetch('/api/projects')
      .then(r => r.json())
      .then(list => {
        setProjects(list);
        const def = list[0];
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
      body: JSON.stringify({ project: selected, mock, request: request.trim() || undefined }),
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
          // run_end sets the final status; if the stream ended while still
          // 'running' the run stopped without completing → treat as failed.
          setRunStatus(prev => prev === 'running' ? 'failed' : prev);
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
            onChange={e => {
              if (graphDirty && !window.confirm('You have unsaved graph changes. Discard and switch project?')) return;
              setSelected(e.target.value);
              setGraphDirty(false);
              setEditMode(false);
              setGraphFormat(null);
              handleClear();
            }}
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
                {p.source ? ` (${p.source})` : ''}
              </option>
            ))}
          </select>
        )}

        {/* Request input — the task/context fed to the run. HQ needs this to route
            sensibly; mock runs ignore it. Enter triggers the run. */}
        <input
          type="text"
          value={request}
          onChange={e => setRequest(e.target.value)}
          onKeyDown={e => { if (e.key === 'Enter') handleRunClick(); }}
          disabled={runStatus === 'running'}
          placeholder="request / task (e.g. build a landing page with email signup)"
          title="The task description sent to the run. Required for HQ to route meaningfully; ignored by mock runs."
          style={{
            flex: 1, minWidth: 160, maxWidth: 520,
            marginLeft: 8, padding: '4px 10px',
            fontSize: 13, fontFamily: 'monospace',
            border: '1px solid #cbd5e1', borderRadius: 6,
            background: runStatus === 'running' ? '#f1f5f9' : '#fff',
            color: '#334155',
          }}
        />

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

        {/* Edit mode toggle — disabled for pipeline-v1 (use CLI `edit`) */}
        <button
          onClick={() => { if (graphFormat !== 'pipeline-v1') setEditMode(m => !m); }}
          disabled={runStatus === 'running' || graphFormat === 'pipeline-v1'}
          title={
            graphFormat === 'pipeline-v1'
              ? 'pipeline-v1 format: use CLI `./run.ps1 edit <proj>` to edit'
              : editMode
                ? 'Exit edit mode (view only)'
                : 'Enter edit mode — add/delete nodes, connect/delete edges, edit fields, Save graph'
          }
          style={{
            marginLeft: 8,
            padding: '4px 12px', fontSize: 11, fontFamily: 'monospace', fontWeight: 700,
            background: graphFormat === 'pipeline-v1'
              ? '#f1f5f9'
              : editMode ? (graphDirty ? '#fef3c7' : '#fffbeb') : 'rgba(255,255,255,0.9)',
            color: graphFormat === 'pipeline-v1'
              ? '#94a3b8'
              : editMode ? '#92400e' : '#64748b',
            border: graphFormat === 'pipeline-v1'
              ? '1px solid #e2e8f0'
              : editMode ? '1px solid #f59e0b' : '1px solid #cbd5e1',
            borderRadius: 6,
            cursor: (runStatus === 'running' || graphFormat === 'pipeline-v1') ? 'not-allowed' : 'pointer',
            boxShadow: '0 1px 3px rgba(0,0,0,.06)',
            transition: 'all 0.15s',
          }}
        >
          {graphFormat === 'pipeline-v1' ? '✎ Edit (v1)' : editMode ? '✎ Editing' : '✎ Edit'}
        </button>

      </header>

      {/* ── Graph + Log ── */}
      <main style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        {/* Graph area: grows to fill remaining space */}
        <div style={{ flex: 1, position: 'relative', overflow: 'hidden', minHeight: 0 }}>
          <ReactFlowProvider>
            <GraphView
              project={selected}
              nodeStatuses={nodeStatuses}
              editMode={editMode}
              onDirtyChange={setGraphDirty}
              onFormatDetected={setGraphFormat}
            />
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
