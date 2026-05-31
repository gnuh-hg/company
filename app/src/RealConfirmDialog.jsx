// F.5 — Real-run confirm dialog.
//
// The Run toggle defaults to Mock (no token burn). When the user flips it to
// Real and presses Run, this modal warns about token cost before anything is
// spawned. Cancel → nothing runs. Confirm → run with mock:false.

export default function RealConfirmDialog({ project, onCancel, onConfirm }) {
  return (
    <div
      onClick={onCancel}
      style={{
        position: 'fixed', inset: 0, zIndex: 100,
        background: 'rgba(15,23,42,0.45)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}
    >
      <div
        onClick={e => e.stopPropagation()}
        style={{
          background: '#fff', borderRadius: 10, padding: '20px 22px',
          width: 420, maxWidth: '90vw',
          boxShadow: '0 10px 40px rgba(0,0,0,0.25)',
        }}
      >
        <div style={{ fontSize: 15, fontWeight: 700, color: '#b45309', marginBottom: 8 }}>
          ⚠ Real run — burns tokens
        </div>
        <div style={{ fontSize: 13, color: '#334155', lineHeight: 1.6, marginBottom: 16 }}>
          You are about to run <strong style={{ fontFamily: 'monospace' }}>{project}</strong> for
          real (not mock). This invokes the model on every node and{' '}
          <strong>consumes API tokens</strong>. It may also take a while to finish.
          <br /><br />
          Run in mock mode instead if you just want to exercise the graph.
        </div>
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
          <button
            onClick={onCancel}
            style={{
              padding: '6px 16px', fontSize: 12, fontFamily: 'monospace', fontWeight: 700,
              borderRadius: 6, border: '1px solid #cbd5e1', background: '#fff',
              color: '#475569', cursor: 'pointer',
            }}
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            style={{
              padding: '6px 16px', fontSize: 12, fontFamily: 'monospace', fontWeight: 700,
              borderRadius: 6, border: 'none', background: '#dc2626', color: '#fff',
              cursor: 'pointer',
            }}
          >
            Run for real
          </button>
        </div>
      </div>
    </div>
  );
}
