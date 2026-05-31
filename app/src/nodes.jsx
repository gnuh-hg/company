import { Handle, Position } from '@xyflow/react';

// ── Live run highlight (Phase F.4) ──────────────────────────────────────────
// runStatus is injected into node.data by GraphView from the live event stream.
const RUN_RING = {
  running:  { boxShadow: '0 0 0 3px #3b82f6, 0 0 14px 3px rgba(59,130,246,.45)', animation: 'rfPulse 1.3s ease-in-out infinite' },
  done:     { boxShadow: '0 0 0 2.5px #22c55e' },
  awaiting: { boxShadow: '0 0 0 3px #9333ea, 0 0 14px 3px rgba(147,51,234,.45)', animation: 'rfPulse 1.3s ease-in-out infinite' },
};
function runRing(rs) { return rs ? (RUN_RING[rs] ?? {}) : {}; }

const BADGE = {
  running:  { bg: '#3b82f6', glyph: '●' },
  done:     { bg: '#22c55e', glyph: '✓' },
  awaiting: { bg: '#9333ea', glyph: '⏸' },
};
function StatusBadge({ status }) {
  const b = status && BADGE[status];
  if (!b) return null;
  return (
    <div style={{
      position: 'absolute', top: -7, right: -7, zIndex: 3,
      width: 16, height: 16, borderRadius: '50%',
      background: b.bg, color: '#fff', fontSize: 9, fontWeight: 700,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      boxShadow: '0 1px 2px rgba(0,0,0,.3)', border: '1.5px solid #fff',
    }}>
      {b.glyph}
    </div>
  );
}

// ── WorkerNode ─────────────────────────────────────────────────────────────
// Standard worker node: white rect with blue left border.
export function WorkerNode({ data }) {
  return (
    <div
      className="rounded border border-blue-300 bg-white shadow-sm"
      style={{ width: 164, minHeight: 52, borderLeft: '4px solid #3b82f6', display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '6px 10px', position: 'relative', ...runRing(data.runStatus) }}
    >
      <StatusBadge status={data.runStatus} />
      <Handle type="target" position={Position.Top} />
      <div style={{ fontFamily: 'monospace', fontSize: 11, fontWeight: 700, color: '#1e293b' }}>{data.label}</div>
      {data.agent && (
        <div style={{ fontFamily: 'monospace', fontSize: 10, color: '#94a3b8', marginTop: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {data.agent}
        </div>
      )}
      <Handle type="source" position={Position.Bottom} />
    </div>
  );
}

// ── RouterNode ─────────────────────────────────────────────────────────────
// Router node: diamond shape via clip-path. Handles sit at visual tips.
// Two-layer technique: outer layer = border color, inner layer = fill color.
// border on a clip-path element is clipped off, so this two-layer approach
// gives a proper polygon outline.
export function RouterNode({ data }) {
  return (
    <div style={{ width: 90, height: 90, position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 4, ...runRing(data.runStatus) }}>
      <StatusBadge status={data.runStatus} />
      <Handle type="target" position={Position.Top} style={{ top: 0 }} />
      {/* Border layer */}
      <div style={{
        position: 'absolute', inset: 0,
        clipPath: 'polygon(50% 0%, 100% 50%, 50% 100%, 0% 50%)',
        background: '#ca8a04',
      }} />
      {/* Fill layer (inset 2px reveals border color around edges) */}
      <div style={{
        position: 'absolute', inset: 2,
        clipPath: 'polygon(50% 0%, 100% 50%, 50% 100%, 0% 50%)',
        background: '#fef9c3',
      }} />
      <span style={{
        position: 'relative', zIndex: 1,
        fontFamily: 'monospace', fontSize: 11, fontWeight: 700,
        color: '#713f12', textAlign: 'center', padding: '0 12px',
        wordBreak: 'break-all', lineHeight: 1.2,
      }}>
        {data.label}
      </span>
      <Handle type="source" position={Position.Bottom} style={{ bottom: 0 }} />
    </div>
  );
}

// ── ApprovalNode ───────────────────────────────────────────────────────────
// Approval (HITL gate) node: flat-top hexagon with ⏸ glyph.
export function ApprovalNode({ data }) {
  return (
    <div style={{ width: 108, height: 90, position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 4, ...runRing(data.runStatus) }}>
      <StatusBadge status={data.runStatus} />
      <Handle type="target" position={Position.Top} style={{ top: 0 }} />
      {/* Border layer */}
      <div style={{
        position: 'absolute', inset: 0,
        clipPath: 'polygon(25% 0%, 75% 0%, 100% 50%, 75% 100%, 25% 100%, 0% 50%)',
        background: '#9333ea',
      }} />
      {/* Fill layer */}
      <div style={{
        position: 'absolute', inset: 2,
        clipPath: 'polygon(25% 0%, 75% 0%, 100% 50%, 75% 100%, 25% 100%, 0% 50%)',
        background: '#f3e8ff',
      }} />
      <span style={{
        position: 'relative', zIndex: 1,
        fontFamily: 'monospace', fontSize: 11, fontWeight: 700,
        color: '#581c87', textAlign: 'center', padding: '0 14px',
        wordBreak: 'break-all', lineHeight: 1.3,
      }}>
        ⏸{' '}{data.label}
      </span>
      <Handle type="source" position={Position.Bottom} style={{ bottom: 0 }} />
    </div>
  );
}

// ── TerminalNode ───────────────────────────────────────────────────────────
// Terminal node: no outgoing edges. Green for success paths, red for escalate.
export function TerminalNode({ data }) {
  const isError = /escalat/.test(data.label);
  return (
    <div
      style={{
        width: 164, minHeight: 52,
        borderRadius: 6,
        borderWidth: 2, borderStyle: 'solid',
        borderColor: isError ? '#f87171' : '#4ade80',
        background: isError ? '#fff1f2' : '#f0fdf4',
        display: 'flex', flexDirection: 'column', justifyContent: 'center',
        padding: '6px 10px', position: 'relative',
        ...runRing(data.runStatus),
      }}
    >
      <StatusBadge status={data.runStatus} />
      <Handle type="target" position={Position.Top} />
      <div style={{ fontFamily: 'monospace', fontSize: 11, fontWeight: 700, color: isError ? '#9f1239' : '#166534' }}>
        ⏹{' '}{data.label}
      </div>
      {data.agent && (
        <div style={{ fontFamily: 'monospace', fontSize: 10, color: '#94a3b8', marginTop: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {data.agent}
        </div>
      )}
    </div>
  );
}

// nodeTypes map for ReactFlow
export const nodeTypes = {
  worker:   WorkerNode,
  router:   RouterNode,
  approval: ApprovalNode,
  terminal: TerminalNode,
};
