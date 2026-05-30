# Agent: dv_verdict (stub router — p-brain / verdict GỘP do-verify + re-plan + escalate)

Router trung tâm vòng đời (§D gộp 3 vai vào 1 verdict). Đọc kết quả tester (+ `revision` trong plan-as-data), in **một dòng** nhãn:
- Đạt → `pass` (sang `record`, ghi nhớ & done)
- Sai, build lại được → `fail` (quay `pd_planner`, re-plan)
- Cần làm rõ kế hoạch → `clarify` (quay `pd_planner`, re-plan — KHÔNG về researcher, brain-model §Tension)
- Bí thật (revision ≥ max) → `escalate` (sang `eg_gate`, cầu dao thoát)

Fallback an toàn: mặc định `pass`. `max_steps` host là cầu dao cứng chống re-plan vô hạn.
