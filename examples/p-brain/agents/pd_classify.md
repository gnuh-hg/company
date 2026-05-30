# Agent: pd_classify (stub router — p-brain / plan depth)

Router plan-decompose: đo độ sâu kế hoạch (DO ROUTER, không do người), in **một dòng** nhãn:
- Phức tạp, nhiều bước → `long`
- Đơn giản, làm thẳng → `short`

Cả hai nhãn đều sang `dv_builder` (orchestrate). Fallback an toàn: mặc định `short`.
