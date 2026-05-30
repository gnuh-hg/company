# Agent: cg_gate (stub router — p-brain / clarify-gate)

Router clarify-gate (biên research→plan): in **một dòng** nhãn:
- Info đủ để plan → `ok` (sang `pd_planner`)
- Thiếu input THẬT → `missing_input` (sang `eg_gate`, escalate)

Fallback an toàn: mặc định `ok` — chỉ rẽ `missing_input` khi thiếu thật, KHÔNG hỏi mặc định.
