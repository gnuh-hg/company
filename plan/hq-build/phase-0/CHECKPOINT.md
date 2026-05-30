# CHECKPOINT — Phase 0: pattern robustness

> Sổ tay tiến độ. Bất kỳ phiên Claude mới nào cũng đọc file này TRƯỚC để biết đang ở đâu.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu").
- **STOP NGAY** khi đạt STOP gate session đó — không tham làm session kế dù còn quota.
- **Engine runtime KHÔNG load fragment** — `patterns/*.json` là author-time; `Expand-Pattern` stamp ra `workflow.json` explicit (C-1, quy ước #2). Không thêm cơ chế include/expand ẩn lúc chạy.
- **Không sửa engine runtime.** Chỉ thêm `engine/pattern.ps1` (author-time helper). Ngoại lệ duy nhất: hook mock đa-router ở C.1 (testing-only, additive — nếu chốt phương án đó).
- Mọi `.ps1` mới: hàm thuần testable + wrapper direct-run, guard `InvocationName`/`Line` (dot-source-safe, #5) + StrictMode guard `$null`/`.Count` (#).
- Mỗi router có **fallback an toàn**; mỗi cycle có `max_steps`.
- Sau verify: **dọn `.runs/` test** (quy ước engine).
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log".

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 5 | 5 | 100% |
| Fragment `patterns/*.json` | 6 | 6 | 100% |
| Demo wrapper `examples/p-*` | 7 (6 + p-brain) | 7 | 100% |
| `engine/pattern.ps1` (Expand-Pattern) | 1 | 1 | 100% |
| Done-gate tick | 6 | 6 | 100% |

---

## Đang ở đâu

- **Phase**: ✅ **PHASE 0 DONE** (0-A + 0-B + 0-C). Tất cả 5 session + done-gate 6/6 đạt.
- **Session kế tiếp**: — (hết Phase 0). Phase kế theo ROADMAP = **Phase 1 (Catalog vai)** hoặc 2/M (độc lập tương đối sau R). Soạn long-plan riêng khi user trỏ vào.
- **Blocker**: —
- **Reference**: Outcome cuối (done-gate 6/6 tick). Engine mở rộng: `ENGINE_MOCK_ROUTER` đa-spec `;`. p-brain = integration §D. ROADMAP + CLAUDE.md đã cập nhật Phase 0 → ✅.
- **Notes (chốt A.1)**:
  - `Expand-Pattern` stamp `__P__<x>`→`<prefix>_<x>` CHỈ ở `node.id`+`edge.from/to`; mọi field khác clone verbatim.
  - Fragment KHÔNG mang `agent`/`name`/`entry`/`max_steps`. Host `stamp.ps1` bind `agent=agents/<stamped-id>.md` (basename agent = node id → khớp `ENGINE_MOCK_ROUTER`).
  - Data key (`input`/`output_key`) là tên thật, KHÔNG stamp — đụng namespace nhiều-pattern là việc của host (lưu cho C.1).
  - Trong `stamp.ps1`: dot-source `pattern.ps1` ghi đè `$here` → dùng tên biến riêng (`$projDir`) cho path project.

---

## Per-session log

### C.1 — p-brain integration + multi-router mock (2026-05-27) ✅
- **Chốt đầu session (đa-router mock)**: chọn phương án **recommended** — mở rộng hook mock trong `engine/lib/claude.ps1`: `ENGINE_MOCK_ROUTER` nhận nhiều spec ngăn bởi `;` (`"a:l1,l2;b:l3"`), mỗi router steer độc lập. Testing-only, additive; 1 spec (không `;`) chạy y cũ (đã verify backward-compat qua loopy `verdict-router:fail,pass` exit 0).
- **Quyết định wiring (deviation có lý do)**: §D vẽ **MỘT** verdict router gộp do-verify (`pass`/`fail`) + re-plan (`fail`/`clarify`→planner) + trigger `escalate`. Stamp `re-plan-loop` thành subgraph riêng sẽ tạo planner/verdict **trùng → UNREACHABLE** (fail reachability-validate). → p-brain stamp **5 fragment owner** (`rg`/`cg`/`pd`/`dv`/`eg`) + 1 node host `record` (memory/done); topology re-plan hiện thực TRÊN `dv_verdict` (`fail`/`clarify`→`pd_planner`). re-plan-loop độc lập đã proven ở p-re-plan-loop (B.2). 11 node / 16 edge.
- **Giao**: `engine/lib/claude.ps1` (patch đa-spec mock), `examples/p-brain/stamp.ps1` + 11 agent stub + `workflow.json` stamped.
- **STOP gate 4/4 pass**:
  - Stamp 5 fragment → `grep __P__` workflow.json = 0 (11 node / 16 edge); `validate p-brain` exit 0.
  - 3 path mock đúng (xác nhận `status`): **(a) happy** `enough;long;pass`→`researcher→gate→planner→classify→builder→tester→verdict→record`; **(b) clarify-escalate** `need_clarify;missing_input;escalate`→`researcher→gate→cg_gate→eg_gate→eg_user` (thoát graceful); **(c) re-plan** `enough;long;fail,pass`→verdict `fail`→quay `pd_planner`→vòng 2→`pass`→`record` (KHÔNG chạm max_steps).
  - `viz p-brain` exit 0 → ASCII + `workflow.mmd` sinh ra.
  - Regression `validate hello` + `run hello -Mock` exit 0; single-spec mock (loopy) exit 0 — engine SEMANTICS không đổi.
- **Done-gate 6/6 tick**: 6 fragment đúng format ✓; Expand-Pattern stamp cả 6 không còn `__P__` ✓; 6 demo + p-brain validate exit 0 ✓; mock đúng vòng đời (thuận/re-plan/escalate) ✓; mọi cycle có `max_steps` + router có fallback ✓; viz p-brain đọc được + ROADMAP/CLAUDE.md cập nhật ✓.
- **Dọn**: `.runs/` test (p-brain/hello/loopy) đã xoá. → **PHASE 0 DONE.**

### B.3 — escalate-gate (2026-05-27) ✅
- **Giao**: `patterns/escalate-gate.json` (3 node: `__P__gate` router làm entry `resolved`/`escalate`; `resolved`→`__P__out` tiếp, `escalate`→`__P__user` thoát báo graceful; không cycle, fallback default `resolved`); `examples/p-escalate-gate/` (stamp prefix `eg` + 3 agent stub). **Lưu ý số node**: PLAN/CHECKPOINT note ghi "4 agent stub" nhưng topology mô tả tường minh chỉ 3 node (gate/out/user, y hệt `clarify-gate`) → theo topology = 3 stub; "4" là số lạc.
- **STOP gate 4/4 pass** (gồm regression):
  - Stamp → `grep __P__` workflow.json = 0 (3 node / 2 edge).
  - `validate p-escalate-gate` exit 0.
  - 2 mock run đúng nhánh (xác nhận qua `status`): `resolved`→`eg_gate→eg_out` (done 2/2); `escalate`→`eg_gate→eg_user` (done 2/2).
  - Regression `validate hello` + `run hello -Mock` exit 0; engine runtime KHÔNG sửa.
- **Notes**: escalate-gate cấu trúc y hệt clarify-gate (gate router-as-entry, 2 exit, no cycle) → copy template thẳng. Tài liệu hoá trong `meta.note` + `eg_user.md`: escalate = thoát **graceful** (router chủ động in nhãn khi đo `revision≥max`/`open_questions[]` từ plan-as-data), KHÁC `max_steps` throw cứng (backstop). → **6/6 fragment xong, Phase 0-B done.**
- **Dọn**: `.runs/` test đã xoá.

### B.2 — plan-decompose + re-plan-loop (2026-05-27) ✅
- **Giao**: `patterns/plan-decompose.json` (4 node: `__P__planner`→`__P__classify` router `long`/`short`; `long`→`__P__long`, `short`→`__P__short`; không cycle, fallback default `short`); `patterns/re-plan-loop.json` (3 node: `__P__planner`→`__P__verdict` router `fail`/`clarify`/`proceed`; `fail`+`clarify` HAI back-edge VỀ `__P__planner` (không về researcher — §Tension), `proceed`→`__P__proceed`; có cycle → `max_steps` cầu dao); `examples/p-plan-decompose/` (stamp prefix `pd` + 4 stub); `examples/p-re-plan-loop/` (stamp prefix `rp` + 3 stub).
- **STOP gate 3/3 pass**:
  - Stamp 2 fragment → `grep __P__` cả 2 workflow.json = 0 (pd 4 node/3 edge, rp 3 node/4 edge).
  - `validate p-plan-decompose` + `validate p-re-plan-loop` exit 0.
  - Mock đúng nhánh (xác nhận qua `status`): pd `long`→`pd_planner→pd_classify→pd_long`; pd `short`→`…→pd_short`; rp `clarify,fail,proceed`→`planner→verdict→planner→verdict→planner→verdict→proceed` (planner iter đạt 3, thoát proceed, KHÔNG chạm max_steps), done 7/7.
  - Regression `validate hello` + `run hello -Mock` exit 0; engine runtime KHÔNG sửa.
- **Notes**: engine xử lý 2 cạnh ra từ 1 router về CÙNG 1 node (fail+clarify→planner) với `when` phân biệt — validate OK, edge-select khớp đúng. Cycle với 2 back-edge cùng đích chạy ngon, max_steps=10 đủ cho kịch bản 2 vòng.
- **Dọn**: `.runs/` test đã xoá.

### B.1 — research-gather + clarify-gate (2026-05-27) ✅
- **Giao**: `patterns/research-gather.json` (4 node: `__P__researcher`→`__P__gate` router `enough`/`need_clarify`; `enough`→`__P__out` sang plan, `need_clarify`→`__P__clarify` biên); `patterns/clarify-gate.json` (3 node: `__P__gate` router làm entry `ok`/`missing_input`; `ok`→`__P__out`, `missing_input`→`__P__escalate`); `examples/p-research-gather/` (stamp.ps1 prefix `rg` + 4 agent stub); `examples/p-clarify-gate/` (stamp.ps1 prefix `cg` + 3 agent stub). Cả 2 pattern không có cycle — fallback an toàn = nhãn default (`enough` / `ok`), `max_steps` host là cầu dao chung.
- **STOP gate 3/3 pass**:
  - Stamp 2 fragment → `grep __P__` cả 2 workflow.json = 0 (rg 4 node/3 edge, cg 3 node/2 edge).
  - `validate p-research-gather` + `validate p-clarify-gate` exit 0.
  - 4 mock run đúng nhánh (xác nhận qua `status`): rg `enough`→`rg_researcher→rg_gate→rg_out`; rg `need_clarify`→`…→rg_clarify`; cg `ok`→`cg_gate→cg_out`; cg `missing_input`→`cg_gate→cg_escalate`. Tất cả done 100%.
  - Regression `validate hello` + `run hello -Mock` exit 0; engine runtime KHÔNG sửa.
- **Notes**: router làm node entry chạy ngon (precedent `branchy`) → `clarify-gate` entry = `cg_gate`. Gate không-cycle: validate chỉ đòi router ≥2 cạnh ra + mỗi cạnh có `when`; KHÔNG đòi `else` → 2 nhãn explicit là đủ, fallback chỉ là quy ước default trong agent stub.
- **Dọn**: `.runs/` test đã xoá.

### A.1 — Expand-Pattern + format + do-verify-loop (2026-05-27) ✅
- **Giao**: `engine/pattern.ps1` (`Expand-Pattern` hàm thuần + wrapper direct-run, dot-source-safe, StrictMode-guard); `patterns/README.md` (convention fragment + bind agent + bảng nhãn router); `patterns/do-verify-loop.json` (4 node, router `__P__verdict` pass/fail back-edge); `examples/p-do-verify-loop/` (`stamp.ps1` + 4 agent stub + `workflow.json` stamped).
- **STOP gate 4/4 pass**:
  - `Expand-Pattern` prefix `dv` → 4 node / 4 edge, `grep __P__` = 0.
  - `validate p-do-verify-loop` exit 0.
  - `ENGINE_MOCK_ROUTER="dv_verdict:fail,pass" run -Mock` → path `dv_builder→dv_tester→dv_verdict(fail)→dv_builder→dv_tester→dv_verdict(pass)→dv_done`, status done 7/7 (xác nhận qua `status`).
  - Regression `validate hello` + `run hello -Mock` exit 0; engine runtime KHÔNG sửa.
- **Dọn**: `.runs/` test đã xoá.

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-26 | Created from `PLAN.md` | planner |
| 2026-05-27 | Session A.1 done (Phase 0-A gate đạt); next = B.1 | claude |
| 2026-05-27 | Session B.1 done (2/6 fragment, research stage); next = B.2 | claude |
| 2026-05-27 | Session B.2 done (5/6 fragment, plan stage); next = B.3 | claude |
| 2026-05-27 | Session B.3 done (6/6 fragment, Phase 0-B gate đạt); next = C.1 | claude |
| 2026-05-27 | Session C.1 done (p-brain integration, done-gate 6/6); **PHASE 0 DONE** | claude |
