import { useEffect, useRef } from 'react';

// Status pill colors
const STATUS_COLOR = {
  running:  '#3b82f6',
  done:     '#22c55e',
  awaiting: '#9333ea',
  failed:   '#ef4444',
};

// ── Individual event row renderers ─────────────────────────────────────────

function Ts({ ts }) {
  if (!ts) return null;
  const t = new Date(ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  return <span style={{ color: '#94a3b8', marginRight: 8, fontSize: 10, flexShrink: 0 }}>{t}</span>;
}

function Row({ children, style }) {
  return (
    <div style={{ display: 'flex', alignItems: 'flex-start', padding: '3px 0', lineHeight: 1.5, ...style }}>
      {children}
    </div>
  );
}

function EventRow({ evt }) {
  const { type, ts, node, agent, output, status, terminal } = evt;

  if (type === 'run_start') {
    return (
      <Row>
        <Ts ts={ts} />
        <span style={{ fontWeight: 700, color: '#0f172a', fontSize: 12 }}>
          ▶ Run started
          {evt.resume && <span style={{ marginLeft: 6, color: '#9333ea', fontSize: 11 }}>(resumed)</span>}
        </span>
      </Row>
    );
  }

  if (type === 'node_start') {
    return (
      <Row>
        <Ts ts={ts} />
        <span style={{ color: '#3b82f6', fontSize: 12 }}>→ </span>
        <span style={{ fontFamily: 'monospace', fontWeight: 700, fontSize: 12, color: '#1e293b', marginLeft: 2 }}>{node}</span>
        {agent && <span style={{ color: '#64748b', fontSize: 11, marginLeft: 5 }}>({agent})</span>}
      </Row>
    );
  }

  if (type === 'node_output') {
    return (
      <div style={{ padding: '4px 0' }}>
        <Row>
          <Ts ts={ts} />
          <span style={{ fontFamily: 'monospace', fontWeight: 700, fontSize: 12, color: '#1e293b' }}>{node}</span>
          <span style={{ color: '#94a3b8', fontSize: 11, marginLeft: 5 }}>output:</span>
        </Row>
        <pre style={{
          margin: '2px 0 4px 20px',
          padding: '6px 10px',
          background: '#f1f5f9',
          borderLeft: '3px solid #cbd5e1',
          borderRadius: 4,
          fontSize: 11,
          fontFamily: 'monospace',
          whiteSpace: 'pre-wrap',
          wordBreak: 'break-word',
          color: '#1e293b',
          maxHeight: 220,
          overflowY: 'auto',
          lineHeight: 1.6,
        }}>
          {output}
        </pre>
      </div>
    );
  }

  if (type === 'node_done') {
    return (
      <Row>
        <Ts ts={ts} />
        <span style={{ color: '#22c55e', fontSize: 12 }}>✓ </span>
        <span style={{ fontFamily: 'monospace', fontSize: 12, color: '#475569', marginLeft: 2 }}>{node}</span>
        <span style={{ color: '#94a3b8', fontSize: 11, marginLeft: 4 }}>done</span>
      </Row>
    );
  }

  if (type === 'awaiting') {
    return (
      <Row style={{ background: '#faf5ff', borderRadius: 4, padding: '5px 8px', marginTop: 2 }}>
        <Ts ts={ts} />
        <span style={{ color: '#9333ea', fontWeight: 700, fontSize: 12 }}>⏸ awaiting</span>
        {node && <span style={{ fontFamily: 'monospace', fontSize: 12, color: '#581c87', marginLeft: 6 }}>{node}</span>}
        {evt.prompt && <span style={{ color: '#6b21a8', fontSize: 11, marginLeft: 8 }}>— {evt.prompt}</span>}
      </Row>
    );
  }

  if (type === 'resumed') {
    return (
      <Row>
        <Ts ts={ts} />
        <span style={{ color: '#9333ea', fontSize: 12 }}>▶ resumed</span>
        {evt.decision && (
          <span style={{ fontFamily: 'monospace', fontSize: 11, color: '#64748b', marginLeft: 6 }}>
            decision=<strong>{evt.decision}</strong>
          </span>
        )}
      </Row>
    );
  }

  if (type === 'run_end') {
    const col = STATUS_COLOR[status] ?? '#64748b';
    return (
      <div style={{ marginTop: 2, borderTop: '1px solid #f1f5f9', paddingTop: 6 }}>
        <Row>
          <Ts ts={ts} />
          <span style={{ fontWeight: 700, fontSize: 12, color: col }}>■ {status}</span>
          {terminal && (
            <span style={{ fontFamily: 'monospace', fontSize: 11, color: '#94a3b8', marginLeft: 8 }}>
              terminal={terminal}
            </span>
          )}
        </Row>
        {evt.error && (
          <pre style={{
            margin: '4px 0 0 20px', padding: '6px 10px',
            background: '#fff1f2', borderLeft: '3px solid #fecaca', borderRadius: 4,
            fontSize: 11, fontFamily: 'monospace', whiteSpace: 'pre-wrap',
            wordBreak: 'break-word', color: '#b91c1c', lineHeight: 1.5,
            maxHeight: 200, overflowY: 'auto',
          }}>
            {evt.error}
          </pre>
        )}
      </div>
    );
  }

  if (type === 'diff_violation') {
    return (
      <div style={{ padding: '4px 0' }}>
        <Row>
          <Ts ts={ts} />
          <span style={{ color: '#f97316', fontWeight: 700, fontSize: 12 }}>⚠ diff_violation</span>
        </Row>
        {evt.violations?.length > 0 && (
          <ul style={{ margin: '2px 0 0 20px', padding: 0, listStyle: 'disc' }}>
            {evt.violations.map((v, i) => (
              <li key={i} style={{ fontFamily: 'monospace', fontSize: 11, color: '#dc2626' }}>{v}</li>
            ))}
          </ul>
        )}
      </div>
    );
  }

  // Fallback: raw JSON for unknown types
  return (
    <Row>
      <Ts ts={ts} />
      <span style={{ fontFamily: 'monospace', fontSize: 10, color: '#94a3b8' }}>
        [{type}] {JSON.stringify(evt)}
      </span>
    </Row>
  );
}

// ── RunLog panel ────────────────────────────────────────────────────────────

const HINT_STYLE = { color: '#94a3b8', fontSize: 12, marginTop: 8 };

export default function RunLog({ events, runStatus, error, onClear }) {
  const bottomRef = useRef(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [events.length]);

  const statusColor = STATUS_COLOR[runStatus] ?? '#64748b';

  return (
    <div style={{
      display: 'flex', flexDirection: 'column',
      height: '100%',
      background: '#ffffff',
      borderTop: '2px solid #e2e8f0',
    }}>
      {/* Panel header */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        padding: '0 12px',
        background: '#f8fafc',
        borderBottom: '1px solid #e2e8f0',
        flexShrink: 0,
        height: 30,
      }}>
        <span style={{ fontSize: 10, fontWeight: 700, color: '#475569', textTransform: 'uppercase', letterSpacing: '0.08em' }}>
          Run Log
        </span>

        {runStatus && runStatus !== 'idle' && (
          <span style={{
            fontSize: 9, padding: '1px 7px', borderRadius: 10,
            background: statusColor + '22', color: statusColor,
            fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.05em',
          }}>
            {runStatus}
          </span>
        )}

        <div style={{ flex: 1 }} />

        {events.length > 0 && (
          <button
            onClick={onClear}
            title="Clear log"
            style={{
              fontSize: 10, padding: '1px 8px', borderRadius: 4,
              background: 'transparent', border: '1px solid #e2e8f0',
              color: '#94a3b8', cursor: 'pointer',
            }}
          >
            Clear
          </button>
        )}
      </div>

      {/* Events list */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '6px 14px 10px' }}>
        {events.length === 0 && runStatus === 'failed' ? (
          <div style={{
            marginTop: 8, padding: '8px 12px',
            background: '#fff1f2', border: '1px solid #fecaca',
            borderRadius: 6, fontSize: 12, color: '#b91c1c',
          }}>
            <strong>Run failed.</strong>{' '}
            {error ? error : 'No events received — the engine may have exited before writing the run directory.'}
          </div>
        ) : events.length === 0 && runStatus === 'running' ? (
          <div style={HINT_STYLE}>⏳ Starting run…</div>
        ) : events.length === 0 ? (
          <div style={HINT_STYLE}>No events yet — press <strong>▶ Run (Mock)</strong> to start.</div>
        ) : (
          events.map(evt => <EventRow key={evt.seq} evt={evt} />)
        )}
        <div ref={bottomRef} />
      </div>
    </div>
  );
}
