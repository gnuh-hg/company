import { Handle, Position } from '@xyflow/react';

// ── WorkerNode ─────────────────────────────────────────────────────────────
// Standard worker node: white rect with blue left border.
export function WorkerNode({ data }) {
  return (
    <div
      className="rounded border border-blue-300 bg-white shadow-sm"
      style={{ width: 164, minHeight: 52, borderLeft: '4px solid #3b82f6', display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '6px 10px' }}
    >
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
export function RouterNode({ data }) {
  return (
    <div style={{ width: 90, height: 90, position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <Handle type="target" position={Position.Top} style={{ top: 0 }} />
      {/* Diamond background */}
      <div style={{
        position: 'absolute', inset: 0,
        clipPath: 'polygon(50% 0%, 100% 50%, 50% 100%, 0% 50%)',
        background: '#fef9c3',
        border: '1px solid #ca8a04',
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
    <div style={{ width: 108, height: 90, position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <Handle type="target" position={Position.Top} style={{ top: 0 }} />
      {/* Hexagon background */}
      <div style={{
        position: 'absolute', inset: 0,
        clipPath: 'polygon(25% 0%, 75% 0%, 100% 50%, 75% 100%, 25% 100%, 0% 50%)',
        background: '#f3e8ff',
        border: '1px solid #9333ea',
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
        padding: '6px 10px',
      }}
    >
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
