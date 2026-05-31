// F.5 — Approval gate UI.
//
// Rendered when the run is paused at an `awaiting` event. Shows the gate prompt,
// any pending diff_violation paths (CC-b), and one button per `when` label in
// `choices[]`. Clicking a choice POSTs it to /api/decision → engine resumes on
// the SAME run dir → the already-open SSE streams the continuation.
//
// Choosing a non-happy-path label (e.g. reject) is just another choice button —
// the engine follows whichever edge matches the label.

export default function ApprovalPanel({ awaiting, violations, pending, onDecide }) {
  if (!awaiting) return null;
  const choices = Array.isArray(awaiting.choices) && awaiting.choices.length > 0
    ? awaiting.choices
    : ['approve'];

  // First choice is treated as the happy-path (primary/filled); the rest are
  // secondary (outlined) — covers reject / alternate-branch labels.
  return (
    <div style={{
      border: '1px solid #d8b4fe',
      background: '#faf5ff',
      borderRadius: 8,
      padding: '12px 14px',
      margin: '8px 14px 4px',
      boxShadow: '0 1px 3px rgba(147,51,234,0.12)',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
        <span style={{ color: '#9333ea', fontWeight: 700, fontSize: 13 }}>⏸ Approval needed</span>
        {awaiting.node && (
          <span style={{ fontFamily: 'monospace', fontSize: 12, color: '#581c87' }}>{awaiting.node}</span>
        )}
      </div>

      {awaiting.prompt && (
        <div style={{ fontSize: 13, color: '#3b0764', marginBottom: 10, lineHeight: 1.5 }}>
          {awaiting.prompt}
        </div>
      )}

      {violations?.length > 0 && (
        <div style={{
          marginBottom: 10, padding: '6px 10px',
          background: '#fff7ed', border: '1px solid #fed7aa', borderRadius: 6,
        }}>
          <div style={{ color: '#c2410c', fontWeight: 700, fontSize: 12, marginBottom: 3 }}>
            ⚠ Diff outside whitelist
          </div>
          <ul style={{ margin: 0, paddingLeft: 18, listStyle: 'disc' }}>
            {violations.map((v, i) => (
              <li key={i} style={{ fontFamily: 'monospace', fontSize: 11, color: '#9a3412' }}>{v}</li>
            ))}
          </ul>
        </div>
      )}

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {choices.map((label, i) => {
          const primary = i === 0;
          return (
            <button
              key={label}
              onClick={() => onDecide(label)}
              disabled={pending}
              title={`Resume with decision: ${label}`}
              style={{
                padding: '5px 16px',
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: 700,
                borderRadius: 6,
                cursor: pending ? 'wait' : 'pointer',
                border: primary ? 'none' : '1px solid #c4b5fd',
                background: pending ? '#e9d5ff' : (primary ? '#9333ea' : '#fff'),
                color: primary ? '#fff' : '#7e22ce',
                transition: 'background 0.15s',
              }}
            >
              {label}
            </button>
          );
        })}
        {pending && (
          <span style={{ alignSelf: 'center', fontSize: 11, color: '#9333ea' }}>resuming…</span>
        )}
      </div>
    </div>
  );
}
