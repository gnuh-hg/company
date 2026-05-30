# CHECKPOINT — Phase 4: HQ workflow graph

> Sổ tay tiến độ dài hạn. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu. Thiết kế bất biến ở `PLAN.md`.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu"). **STOP NGAY** khi đạt STOP gate session đó — không tham làm session kế.
- **KHÔNG sửa `engine/*.ps1`** — Phase 4 chỉ viết `hq/workflow.json` + `hq/agents/researcher.md` + `examples/hq-graph-tests.ps1` (bất biến #1: engine cố định).
- **Chạy HQ bằng path form**: từ `engine/` gọi `./run.ps1 <cmd> ../hq ...` (project `hq` nằm ở `company/hq/`, KHÔNG trong `projects/`/`examples/`).
- **Mọi test bằng mock** (`-Mock` + `ENGINE_MOCK_ROUTER` đa-spec `;`) — không đốt token. Trial real defer Phase 5.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log". Dọn `.runs/` + `memory/` test sau verify.

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Session hoàn thành | 4 | 4 (4.1+4.2 gộp, 4.3, 4.4) | ✅ 100% |
| Agent HQ (thêm researcher) | 6 | 6 | 100% |
| Node graph `hq/workflow.json` | 10 | 11 (full topology) | ✅ |
| Nhánh mock-drive pass | ≥5 | 8 (6 coverage + 2 loop-bounding) | ✅ |
| Done-gate criteria pass | 5 | 5 (validate/viz/build·fix·unclear/loop dừng·re-plan escalate·max_steps) | ✅ 100% |

---

## Đang ở đâu

- **Phase**: 4-A ✅ DONE → 4-B ✅ DONE (4.3 + 4.4) → **PHASE 4 ✅ DONE**
- **Session kế tiếp**: — (Phase 4 hoàn tất). Bàn giao Phase 5 (E2E thật): thay mock-router bằng LLM thật + `trial[]` real assert + vòng fix thật trên branch sinh ra disk.
- **Blocker**: —
- **Reference**: `PLAN.md` §Outcome cuối / `plan/hq-build/phase-5/` (chưa soạn)
- **⚠ Deviation (chat này)**: 4.1 và 4.2 **gộp làm 1** vì engine rules khiến split bất khả thi — (a) `validate` bắt **mọi** node có agent file tồn tại → phải tạo luôn 5 agent phụ trợ (`rg_gate`/`clarify_gate`/`escalate_gate`/`escalate_report`/`record`), ngoài `researcher.md` mà PLAN liệt kê; (b) router cần ≥2 cạnh `when` + reachability mọi node → "edges happy-path tối thiểu" của 4.1 không thể `validate` exit 0 khi đã khai router `coo`/`tester`. Nên dựng **full topology 4-A** ngay. Cũng phát hiện: default `-Mock` **không** "chọn nhánh đầu" như PLAN ghi — router strict-match (Session 1.3) → happy-path phải set `ENGINE_MOCK_ROUTER="coo:build;rg_gate:enough;tester:pass"`.

---

## Quyết định đã chốt (input Phase 4 — không lật lại)

- **Q1**: thêm `researcher` + research-gather front (agent thứ 6 HQ-level).
- **Q2**: `tester` LÀ router (`type:router`, in pass/fail_fix/fail_replan/escalate).
- **Q3**: tách 2 nhãn fail — `fail_fix`→builder (do-verify), `fail_replan`→planner (re-plan).
- **Q4**: `coo --fix--> planner` (luôn re-plan trước); `build`→researcher; `unclear`→escalate-gate.
- **Planner-chốt (revisable)**: HQ graph hand-authored (KHÔNG Expand-Pattern stamp); bỏ plan-decompose long/short khỏi HQ; escalate mềm dựa `revision` (max=3), `max_steps=40` backstop; `trial[]` real defer P5.

---

## Per-session log

### 2026-05-28 — Session 4.1+4.2 (Phase 4-A, gộp) ✅
- **Làm**: `hq/agents/researcher.md` (agent thứ 6 HQ-level, template 5 mục, read-only, nhãn `enough`/`need_clarify`) + 5 agent phụ trợ (`rg_gate`/`clarify_gate`/`escalate_gate`/`escalate_report`/`record`) + `hq/workflow.json` full topology (11 node, 17 cạnh, entry=coo, max_steps=40, trial[] 2 assertion) + `hq/workflow.mmd`.
- **Edges**: COO 3 nhãn (build→researcher / fix→planner / unclear→escalate_gate); research-gather (researcher→rg_gate; enough→planner / need_clarify→clarify_gate); clarify (ok→planner / missing_input→escalate_gate); chuỗi planner→cto→builder→tester; tester 4 nhãn (pass→record / fail_fix→builder / fail_replan→planner / escalate→escalate_gate); escalate (resolved→planner / escalate→escalate_report). Terminal: record (memory_write context) + escalate_report.
- **Verify**: `validate ../hq` exit 0 (1 warning data-cycle `{{plan}}` — đúng kỳ vọng re-plan loop-feedback); happy-path mock (`ENGINE_MOCK_ROUTER="coo:build;rg_gate:enough;tester:pass"`) đi `coo→researcher→rg_gate→planner→cto→builder→tester→record` done; `viz ../hq` exit 0, `.mmd` chứa back-edge `tester→builder`/`tester→planner`; regression `hello` validate+run done. Dọn `.runs/`+`hq/memory/`.
- **Còn lại Phase 4-B**: 4.3 mock-drive ≥5 nhánh, 4.4 loop-bounding (re-plan escalate revision≥max + max_steps backstop) + regression `hq-tests.ps1` + cập nhật ROADMAP/CLAUDE.md.

### 2026-05-28 — Session 4.3 (Phase 4-B) ✅
- **Làm**: `examples/hq-graph-tests.ps1` — mock-drive 6 path qua `ENGINE_MOCK_ROUTER` đa-spec `;`, assert status=done + node terminal + shape path đầy đủ (so khớp chuỗi `→`).
- **6 path**: (1) build-happy `coo:build;rg_gate:enough;tester:pass`→record; (2) fix `coo:fix;tester:pass`→record (bỏ researcher); (3) re-plan-loop `tester:fail_replan,pass`→planner×2→record; (4) do-verify-fix `tester:fail_fix,pass`→builder×2→record; (5) unclear-escalate `coo:unclear;escalate_gate:escalate`→escalate_report; (6) clarify-escalate `rg_gate:need_clarify;clarify_gate:missing_input;escalate_gate:escalate`→escalate_report.
- **Phát hiện engine**: `$script:MockAgentCalls` (lib/claude.ps1) persist trong 1 process → helper `Invoke-Path` **reset `@{}` trước mỗi test** để spec đa-nhãn (`fail_fix,pass`) đếm lại từ 0. Test chạy 1 process (dot-source) khác run.ps1 (process/lệnh). `finally` dọn `.runs/`+`hq/memory/`.
- **Verify**: `pwsh examples/hq-graph-tests.ps1` exit 0 — 6/6 path đạt terminal đúng + shape khớp; re-plan quay `planner`, do-verify quay `builder` (đúng nhãn tách Q3). `hq/.runs`+`hq/memory` đã sạch sau chạy.
- **Còn lại Phase 4-B**: 4.4 loop-bounding (escalate revision≥max + max_steps backstop) + regression `hq-tests.ps1` + doc.

---

### 2026-05-28 — Session 4.4 (Phase 4-B, session cuối) ✅
- **Làm**: thêm 2 test loop-bounding vào `examples/hq-graph-tests.ps1` (giờ 8 path) + regression + cập nhật doc (ROADMAP + CLAUDE.md).
- **Test 7 (re-plan escalate, soft-exit)**: `tester:fail_replan,fail_replan,escalate;escalate_gate:escalate` → re-plan 2 vòng (mô phỏng revision bump tới max=3) rồi tester in `escalate` → `escalate_gate→escalate_report`. Assert: status=done, terminal=escalate_report, tester×3, planner×3, KHÔNG vào record. Chứng minh loop thoát MỀM trước trần.
- **Test 8 (max_steps backstop, hard-fire)**: `tester:fail_replan` (1 nhãn = luôn fail → loop không hội tụ) → engine throw `vượt max_steps (40)` + `state.status=failed` tại node thứ 40 (cursor='cto'). Cầu dao CỨNG fire đúng.
- **Verify**: `pwsh examples/hq-graph-tests.ps1` exit 0 (8/8 path). Regression: `validate hello`+`run hello -Mock` exit 0; `validate ../hq` exit 0; `pwsh examples/hq-tests.ps1` (Phase 3) exit 0 (không vỡ agent HQ). Dọn `.runs/`+`memory/` (hq+hello) sau verify — sạch.
- **Done-gate Phase 4 (5/5 ✅)**: (1) validate exit 0; (2) build/fix/unclear đúng nhánh; (3) do-verify-fix loop dừng + re-plan escalate revision≥max; (4) re-plan quay planner / escalate→escalate_report; (5) viz `.mmd` có back-edge. **PHASE 4 HOÀN TẤT.**

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-27 | Created from `PLAN.md` | @planner |
| 2026-05-28 | Phase 4-A done (4.1+4.2 gộp; lý do: engine rules ⇒ split bất khả thi) | Claude |
| 2026-05-28 | Session 4.3 done — `hq-graph-tests.ps1` 6 path mock-drive exit 0 | Claude |
| 2026-05-28 | Session 4.4 done — loop-bounding (re-plan escalate + max_steps backstop) + regression + doc; **PHASE 4 DONE** (done-gate 5/5) | Claude |
