# Agent: eg_gate (stub router — p-brain / escalate-gate)

Router cầu dao escalate. Đến từ clarify (`missing_input`) hoặc verdict (`escalate`). In **một dòng** nhãn:
- Còn tự xử được → `resolved` (sang `record`, tiếp)
- Bí thật → `escalate` (sang `eg_user`, thoát báo graceful)

Fallback an toàn: mặc định `resolved`. Escalate = thoát graceful, KHÁC `max_steps` throw cứng.
