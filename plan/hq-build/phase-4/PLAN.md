# PLAN — Phase 4: HQ workflow graph (nối 5 agent thành graph có robustness)

> Sau toàn bộ pipeline: `hq/workflow.json` nối **6 node agent** (`coo` router → `researcher` → `planner` → `cto` → `builder` → `tester` router) + **node phụ trợ** (`clarify-gate`, `escalate-gate`, `escalate_report`, `record` memory-write) thành **một graph HQ hoàn chỉnh** có robustness: research-gather đầu vòng, clarify/escalate khi thiếu input, do-verify-loop (`fail_fix`→builder), re-plan-loop (`fail_replan`→planner), escalate mềm khi `revision ≥ max`, `max_steps` cầu dao. `validate ../hq` exit 0, `viz` đọc được, và **mock-drive đi đúng ≥5 nhánh** (build-happy / fix / re-plan / do-verify-fix / unclear-escalate). **Chưa chạy thật** (no -Mock, ghi branch thật lên disk) — đó là Phase 5.

---

## Context

- **Vì sao chia nhiều session:** Phase 4 = (1) dựng topology graph + agent thứ 6 (`researcher` HQ-level) + viết `hq/workflow.json` chạy được happy-path, rồi (2) wiring đủ mọi nhãn router robustness, rồi (3) script mock-drive từng nhánh độc lập, rồi (4) chốt done-gate + loop-bounding + regression + cập nhật doc. Mỗi nhóm cần STOP gate `validate`/`run -Mock` đo được riêng → vượt 1 chat nếu dồn.
- **Quyết định đã chốt (user duyệt — input cho Phase 4):**
  - **Q1 — Thêm `researcher` + `research-gather` front.** Graph mở đầu bằng research-gather (node `researcher` HQ-level + router `rg_gate`). ⇒ **deliverable mới**: `hq/agents/researcher.md` (agent thứ 6, HQ-level — phân biệt với `catalog/researcher.md` của chi nhánh). Bám brain-model §Mô hình A (vai `researcher` tư duy) + §D (sơ đồ vòng đời đầy đủ).
  - **Q2 — Tester LÀ router.** Node `tester` khai `type: "router"`, tự in nhãn dòng cuối (`pass`/`fail_fix`/`fail_replan`/`escalate`). KHÔNG tách node `verdict` riêng (khác `loopy`/`p-brain`). Đúng `hq/agents/tester.md` ("in nhãn ở dòng cuối để router đọc"). Tester vẫn read-only (chạy `check`/`trial`, không sửa).
  - **Q3 — Tách 2 nhãn fail: `fail_fix`→builder, `fail_replan`→planner.** Lỗi nhỏ (patch) → do-verify-loop về `builder`; plan sai → re-plan-loop về `planner` (bump `revision`). Đúng cả `builder.md` + `tester.md` handoff; dùng **cả** do-verify-loop **và** re-plan-loop.
  - **Q4 — COO `fix` → planner (luôn re-plan trước).** `coo --build--> researcher` (mở vòng đời mới); `coo --fix--> planner` (vào re-plan rồi cto→builder→tester); `coo --unclear--> escalate-gate`. Cả build lẫn fix hội tụ ở planner path; COO vẫn gắn nhãn để planner/cto đọc ngữ cảnh.
- **Quyết định thiết kế của Phase 4 (planner chốt, revisable qua Revision log — KHÔNG hỏi lại user):**
  - **HQ graph hand-authored, KHÔNG `Expand-Pattern` stamp.** `hq/workflow.json` viết tay tham chiếu `hq/agents/*.md`, dùng `patterns/*.json` làm **blueprint** (mượn cấu trúc node/edge + nhãn `when` chuẩn của từng pattern). Lý do: nhất quán với `examples/web-demo` (lắp tay từ catalog) + giữ "thấy gì chạy nấy" (runtime explicit, không expand ẩn — bất biến C-1). `Expand-Pattern` là việc *runtime của Builder* khi sinh **chi nhánh**, không phải cho graph HQ.
  - **Bỏ `plan-decompose` (long/short classify) khỏi graph HQ.** `planner --> cto` trực tiếp. Lý do: ở tầng orchestrate HQ, long/short đều dẫn `cto→builder` — phân loại độ sâu không đổi đường đi. plan-decompose là pattern Phase 0 (đã demo riêng); HQ wiring lean. 5/6 pattern được nối (research-gather, clarify-gate, do-verify-loop, re-plan-loop, escalate-gate); plan-decompose để dành chi nhánh phức tạp.
  - **Escalate mềm dựa `revision`.** `tester` in `escalate` khi đọc `{{plan}}.revision ≥ max` (max=3, brain-model §Ranh giới đk 3) TRƯỚC khi đụng trần. `max_steps` (đề xuất **40**) chỉ là backstop cứng. Hai lối thoát: thành-công (`pass`→`record`→DONE), bí (`escalate`→`escalate-gate`→`escalate_report`→DONE).
  - **`trial[]` real DEFER sang Phase 5.** `hq/workflow.json` khai `trial[]` tối thiểu (cấu trúc), nhưng **trial real** (chạy `run.ps1 trial ../hq` no-Mock, build branch thật) là việc Phase 5 (E2E thật). Done-gate Phase 4 = **tầng cấu trúc mock** (`validate` + `run -Mock` done + path-coverage), không chạy trial real.
- **Bám nền đã có:** 5 agent `hq/agents/{coo,planner,cto,builder,tester}.md` (P3); 6 pattern `patterns/*.json` + README nhãn router (P0); `examples/p-brain/workflow.json` = **prior-art shape** (cùng vòng đời, agent stub — Phase 4 thay bằng agent HQ thật); `examples/hq-tests.ps1` + `ENGINE_MOCK_ROUTER` đa-spec `;` (P3/P0-C) = khuôn mock-drive đa router; `engine/memory.ps1` node `record` `memory_write` (PM); `engine/viz.ps1` (router diamond + nhãn when + back-edge).
- **Bất biến engine (KHÔNG vi phạm):** engine là code cố định — Phase 4 **KHÔNG sửa `engine/*.ps1`** (chỉ viết `hq/workflow.json` + `hq/agents/researcher.md` + script test trong `examples/`); `workflow.json` chỉ ngữ nghĩa (nodes/edges/entry/max_steps + `when`); một surface lệnh `run.ps1`; mock offline cho mọi test (`-Mock` + `ENGINE_MOCK_ROUTER`); chỉ thao tác trong `company/`.
- **Resolve project HQ:** `hq/` ở `company/hq/` — KHÔNG nằm trong `projects/`/`examples/`. `Resolve-ProjectDir` (run.ps1:69) thử path nguyên trạng trước ⇒ chạy bằng **path form**: từ `engine/` gọi `./run.ps1 <cmd> ../hq ...`. Agent path trong `workflow.json` (`agents/coo.md`) resolve tương đối project-dir = `hq/` ⇒ `hq/agents/coo.md`. Xác nhận cơ chế này ở Session 4.1.
- **Out of scope (Phase 5+):** chạy thật no-Mock (HQ sinh chi nhánh thật lên disk + Tester chạy `check`/`trial` real + vòng fix thật) = **Phase 5**; app GUI = Phase 6. Phase 4 CHỈ giao **graph + agent researcher + mock path-coverage**.

---

## Pipeline 2 sub-phase / 4 session

```
[4-A] Topology + agent researcher ──► hq/agents/researcher.md (agent thứ 6 HQ-level)
                                      + hq/workflow.json (6 node agent + 4 node phụ trợ
                                        + edges robustness + entry=coo + max_steps=40 + trial[])
                                      + viz ../hq (.mmd render được)
                                         │
[4-B] Mock path-coverage + done-gate ─► examples/hq-graph-tests.ps1
                                        (mock-drive ≥5 nhánh qua ENGINE_MOCK_ROUTER đa-spec)
                                      + loop-bounding (re-plan revision≥max, max_steps backstop)
                                      + regression + ROADMAP/CLAUDE.md cập nhật
                                         │
                                      Phase 4 done
```

Lý do thứ tự: topology (4-A) phải tồn tại + `validate` sạch trước thì mock-drive từng nhánh (4-B) mới có graph để đi. 4-A khoá *hình dạng* graph (bất biến sau approve); 4-B *chứng minh* mọi nhánh đi đúng + loop dừng đúng.

---

## Phase 4-A — Topology graph + agent `researcher`

**Mục tiêu**: dựng `hq/workflow.json` = graph HQ hoàn chỉnh (node + edge + nhãn router) chạy được happy-path bằng mock, + agent `researcher` HQ-level còn thiếu. Khoá topology bất biến.

### Session 4.1 — Agent `researcher` + node/edge map + happy-path runnable
- **Scope**:
  - `hq/agents/researcher.md` — agent thứ 6, HQ-level, theo template 5 mục (Một việc/Input/Trả ra/Không làm/Handoff), `allowedTools: [Read]` + `permission_mode: read-only`. **Một việc**: gom hiểu biết về `{{user_request}}` từ memory `{{mem_*}}` + ngữ cảnh, xuất tóm tắt + `open_questions[]`; in nhãn dòng cuối cho `rg_gate` (`enough`/`need_clarify`). Phân biệt rõ với `catalog/researcher.md` (chi nhánh) trong dòng `>` cuối.
  - `hq/workflow.json` — viết tay, **happy-path chạy được** đã đủ ở session này:
    - Nodes (10): `coo`(router) · `researcher`(work) · `rg_gate`(router) · `clarify_gate`(router) · `planner`(work) · `cto`(work) · `builder`(work) · `tester`(router) · `escalate_gate`(router) · `escalate_report`(work) · `record`(work, `memory_write`). Mỗi node khai `agent` (`agents/<x>.md`), `input` (`{{key}}` template — vd `planner.input = "{{user_request}}\n{{research}}\n{{plan}}\n{{verdict}}\n{{mem_patterns}}"`), `output_key`.
    - `entry: "coo"`, `max_steps: 40`.
    - Edges happy-path tối thiểu để `run -Mock` done: `coo --build--> researcher`, `researcher --> rg_gate`, `rg_gate --enough--> planner`, `planner --> cto`, `cto --> builder`, `builder --> tester`, `tester --pass--> record`. (Các nhánh robustness còn lại bổ sung Session 4.2.)
    - `trial[]` tối thiểu (1-2 assertion cấu trúc trên `record_result`/`build` — real defer P5).
  - Xác nhận resolve: `./run.ps1 validate ../hq` (path form) load đúng `hq/agents/*.md`.
- **STOP gate**: `./run.ps1 validate ../hq` exit 0 (schema/agent-exist/router-when/reachability/max_steps đều pass — mọi node `agent` trỏ file tồn tại, mọi edge router có `when`); `./run.ps1 run ../hq "test request" -Mock` (mặc định mock router chọn nhánh đầu) đi `coo→researcher→rg_gate→planner→cto→builder→tester→record` và kết thúc **done**; regression `validate hello` exit 0 + `run hello "x" -Mock` done.
- **Output artifact**: `hq/agents/researcher.md` + `hq/workflow.json` (happy-path) + `.runs/` dọn sau verify.

### Session 4.2 — Wiring robustness đầy đủ + viz
- **Scope**:
  - Bổ sung **toàn bộ** edge robustness vào `hq/workflow.json` (topology cuối, bất biến sau session này):
    - COO 3 nhánh: `coo --build--> researcher` · `coo --fix--> planner` · `coo --unclear--> escalate_gate`.
    - research-gather: `researcher --> rg_gate` · `rg_gate --enough--> planner` · `rg_gate --need_clarify--> clarify_gate`.
    - clarify-gate: `clarify_gate --ok--> planner` · `clarify_gate --missing_input--> escalate_gate`.
    - planner→cto→builder→tester (chuỗi work).
    - tester (router) 4 nhãn: `tester --pass--> record` · `tester --fail_fix--> builder` (do-verify-loop) · `tester --fail_replan--> planner` (re-plan-loop) · `tester --escalate--> escalate_gate`.
    - escalate-gate: `escalate_gate --resolved--> planner` (user làm rõ → quay lại plan) · `escalate_gate --escalate--> escalate_report` (báo user, terminal).
    - Terminal: `record` (thành công) + `escalate_report` (bí) — không edge ra → run done.
  - Kiểm `input` bridge: `builder.input` đọc `{{spec}}`/`{{verdict}}`, `planner.input` đọc `{{plan}}`+`{{verdict}}` (re-plan đọc lý do), `tester.input` đọc `{{build}}`+`{{plan}}` — đúng latest-wins để loop tái sinh data (brain-model §Tension).
  - `./run.ps1 viz ../hq` → ASCII + `hq/workflow.mmd` (diamond router cho `coo`/`rg_gate`/`clarify_gate`/`tester`/`escalate_gate` + nhãn `when` + back-edge `tester→builder`/`tester→planner`).
- **STOP gate**: `validate ../hq` exit 0 (reachability: **mọi** node tới được từ `coo`; mọi router edge có `when`; không node nào output_key trùng gây mờ); `viz ../hq` chạy không lỗi + `.mmd` chứa back-edge; mỗi router có ≥2 edge `when` phân biệt; regression `validate hello`+`run hello -Mock` done.
- **Output artifact**: `hq/workflow.json` (topology cuối) + `hq/workflow.mmd`.

**Phase 4-A gate**: `validate ../hq` exit 0 + `viz` render được + happy-path `run -Mock` done + 6 agent (`coo/researcher/planner/cto/builder/tester`) + 4 node phụ trợ đều reachable.

---

## Phase 4-B — Mock path-coverage + done-gate

**Mục tiêu**: chứng minh graph đi **đúng từng nhánh** + loop **dừng đúng**, bằng mock-drive (`ENGINE_MOCK_ROUTER` đa-spec) — không LLM, không token. Chốt done-gate + regression + doc.

### Session 4.3 — Script mock-drive ≥5 nhánh
- **Scope**:
  - `examples/hq-graph-tests.ps1` (mẫu theo `examples/hq-tests.ps1`): mỗi test set `ENGINE_MOCK_ROUTER` đa-spec (`"coo:build;rg_gate:enough;tester:pass"` …) rồi `./run.ps1 run ../hq "<req>" -Mock`, assert **node terminal đạt** + path đi qua đúng node (đọc `.runs/.../state` hoặc `status`). ≥5 path:
    1. **build-happy**: `coo:build; rg_gate:enough; tester:pass` → kết `record` (DONE thành công).
    2. **fix**: `coo:fix; tester:pass` → vào `planner` thẳng (bỏ researcher) → `record`.
    3. **re-plan-loop**: `coo:build; rg_gate:enough; tester:fail_replan,pass` → `tester→planner→cto→builder→tester→record` (1 vòng re-plan rồi pass).
    4. **do-verify-fix**: `coo:build; rg_gate:enough; tester:fail_fix,pass` → `tester→builder→tester→record` (1 vòng patch rồi pass).
    5. **unclear-escalate**: `coo:unclear; escalate_gate:escalate` → `escalate_gate→escalate_report` (DONE bí).
    6. (tuỳ chọn) **clarify-escalate**: `coo:build; rg_gate:need_clarify; clarify_gate:missing_input; escalate_gate:escalate` → `escalate_report`.
  - Script dọn `.runs/` + `memory/` sau mỗi test; exit = số path fail.
- **STOP gate**: `pwsh examples/hq-graph-tests.ps1` exit 0 — cả ≥5 path đạt terminal đúng (build/fix → `record`; unclear/escalate → `escalate_report`); re-plan & do-verify path xác nhận **quay lại đúng node** (`planner` vs `builder`) rồi pass; mỗi test in path đi qua (máy-đọc-được).
- **Output artifact**: `examples/hq-graph-tests.ps1`.

### Session 4.4 — Loop-bounding + done-gate + doc
- **Scope**:
  - **Loop-bounding** (thêm 1-2 test vào script 4.3 hoặc kiểm tay):
    - re-plan dừng đúng: `tester:fail_replan` lặp cho tới khi `planner` (mock đọc `{{plan}}.revision`) hoặc `tester` in `escalate` (revision≥max=3) → thoát `escalate_report`, KHÔNG loop vô hạn.
    - `max_steps=40` backstop: path cố tình loop quá trần → engine throw `failed` (cầu dao cứng) — xác nhận thông điệp.
  - **Regression**: `validate hello`+`run hello -Mock` done; `pwsh examples/hq-tests.ps1` (Phase 3) vẫn exit 0 (không vỡ agent HQ); `validate ../hq` exit 0.
  - **Doc**: cập nhật `plan/hq-build/ROADMAP.md` bảng tiến độ (Phase 4 → ✅ DONE + deliverable) + Phase 4 block đánh dấu done; `company/CLAUDE.md` bảng "Bản đồ file" thêm hàng `hq/workflow.json` + `hq/agents/researcher.md` + `examples/hq-graph-tests.ps1` + `plan/hq-build/phase-4/`.
- **STOP gate**: re-plan loop chứng minh dừng (escalate khi revision≥max) + `max_steps` backstop fire đúng; toàn bộ regression pass; ROADMAP + CLAUDE.md cập nhật (grep thấy hàng mới); `examples/hq-graph-tests.ps1` exit 0 lần cuối.
- **Output artifact**: script loop-bounding hoàn chỉnh + ROADMAP/CLAUDE.md updated.

**Phase 4-B gate** = Done-gate Phase 4 (xem dưới).

---

## Outcome cuối

- `hq/workflow.json` = graph HQ hoàn chỉnh (10 node, robustness đủ tầng) `validate` exit 0 + `viz` render.
- 6 agent HQ đầy đủ (thêm `hq/agents/researcher.md`).
- `examples/hq-graph-tests.ps1` mock-drive ≥5 nhánh đi đúng + loop dừng đúng, exit 0.
- **Done-gate (từ ROADMAP §Phase 4):**
  1. `validate ../hq` exit 0. ✅ đo: exit code.
  2. Mock đi **đúng nhánh** build/fix/unclear. ✅ đo: 3 path đạt terminal đúng trong `hq-graph-tests.ps1`.
  3. Loop fix lặp rồi **dừng đúng**. ✅ đo: do-verify-fix path pass sau N vòng; re-plan escalate khi revision≥max.
  4. Re-plan loop + escalate **thoát đúng**. ✅ đo: re-plan path quay `planner`; escalate path → `escalate_report`.
  5. `viz ../hq` đọc được. ✅ đo: `.mmd` sinh + chứa back-edge.
- **Bàn giao cho Phase 5**: graph sẵn sàng chạy thật (thay mock-router bằng LLM thật) + `trial[]` real assert + vòng fix thật trên branch sinh ra disk.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-05-27 | Initial | Soạn từ ROADMAP §Phase 4 + brain-model §D + 4 quyết định user chốt (Q1 researcher front / Q2 tester-là-router / Q3 fail tách fix·replan / Q4 fix→planner) |
