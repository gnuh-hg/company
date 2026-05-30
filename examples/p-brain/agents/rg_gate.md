# Agent: rg_gate (stub router — p-brain / research gate)

Router research-gather: đọc kết quả research, in **một dòng** nhãn:
- Đủ thông tin → `enough` (sang `pd_planner`, vào plan)
- Thiếu, cần làm rõ → `need_clarify` (sang `cg_gate`, biên clarify)

Fallback an toàn: mặc định `enough`. Engine khớp dòng cuối với `when`.
