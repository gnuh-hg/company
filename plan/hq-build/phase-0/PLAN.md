# PLAN — Phase 0: Thư viện pattern robustness

> Sau toàn bộ pipeline: có `patterns/` chứa **6 fragment robustness** (node+edge+`when`, id placeholder `__P__x`) + helper `engine/pattern.ps1::Expand-Pattern` đóng dấu fragment, + 6 demo wrapper `examples/p-<name>/` chạy mock đúng từng pattern, + 1 demo tích hợp `examples/p-brain/` nối 6 pattern theo sơ đồ vòng đời §D (`research → plan → do/verify → re-plan → escalate`). Đây là nền chất lượng (đầu-não từ Phase R) để CTO/Builder lắp vào mọi workflow chi nhánh ở Phase 3/4.

---

## Context

- **Vì sao chia nhiều session:** Phase 0 = code engine (helper) + sản xuất 6 fragment, mỗi fragment kèm 1 demo wrapper (workflow.json stamped + agent stub + validate + mock-run) + 1 demo tích hợp nối cả 6. Mỗi pattern cần chốt ranh giới + nhãn router + kịch bản mock riêng → vượt 1 chat nếu làm gộp. Foundation (format fragment + helper) phải de-risk TRƯỚC khi nhân bản 6 pattern.
- **Đầu vào đã chốt (không thiết kế lại):**
  - `brain-model.md` §Mô hình B = bảng 6 pattern + **nhãn router dự kiến** (Phase 0 chốt làm chuẩn). §D = sơ đồ vòng đời node/edge cho demo tích hợp.
  - **C-1 (copy-convention + helper stamp):** fragment lưu `patterns/<name>.json` (fragment node+edge, id placeholder `__P__x`); runtime `workflow.json` luôn explicit (engine KHÔNG include/expand ẩn lúc chạy — giữ "thấy gì chạy nấy"). `Expand-Pattern $fragment $prefix` là helper **author/build-time** (Builder dùng ở P3), engine runtime không bao giờ load fragment.
  - **C-2:** engine không validate shape output agent. Pattern chỉ lo *topology* (node/edge/when) + nhãn router — không lo nội dung agent.
  - Engine v2 đã đủ diễn đạt mọi pattern (router + cycle + `max_steps`) — **không sửa engine runtime**. Chỉ thêm `engine/pattern.ps1` (author-time helper) + có thể mở rộng *hook mock* (testing-only, additive) cho demo tích hợp đa-router (xem Session C.1).
- **Quyết định đóng gói (user chốt 2026-05-26):**
  - **Demo = wrapper project mỗi pattern + 1 integration demo.** Fragment thuần không chạy được (thiếu entry/agent/max_steps) → mỗi pattern có `examples/p-<name>/workflow.json` = kết quả `Expand-Pattern fragment <prefix>` + bổ sung `entry`/`max_steps`/agent stub, để `run -Mock` chứng minh fragment đúng. Cuối phase 1 demo `examples/p-brain/` nối 6 pattern theo §D.
  - **Expand-Pattern làm trong Phase 0** (`engine/pattern.ps1`, hàm thuần + wrapper direct-run, dot-source-safe theo quy ước bất biến #5). Chính nó stamp fragment vào demo → vừa giao helper vừa test fragment stamp-được-bằng-máy.
- **Định dạng fragment (chốt ở Session A.1, áp cho cả 6):**
  - File `patterns/<name>.json`: `{ "meta": {...}, "nodes": [...], "edges": [...] }`. **Không** có `name`/`entry`/`max_steps` (host workflow cấp).
  - `nodes[].id` + `edges[].from/to` dùng placeholder `__P__<x>` (vd `__P__research`, `__P__route`). `Expand-Pattern` đổi `__P__<x>` → `<prefix>_<x>` ở **mọi** id trong nodes + from/to trong edges; KHÔNG đụng field khác (`agent`, `input`, `when`, `type`, `output_key`).
  - `meta`: `{ entry: "__P__x", exits: [{label, node}], routers: ["__P__x"] }` — tài liệu cho Builder biết điểm vào/ra + router nào; engine không đọc.
  - `edges[].when` = nhãn router **chuẩn của pattern** (bảng dưới). Agent của node là stub demo (echo/router) ở wrapper; Builder thay bằng vai catalog ở P3.
- **Nhãn router chuẩn (chốt từ brain-model §B — Phase 0 hiện thực):**

  | Pattern | Router node | Nhãn `when` chuẩn | Bước vòng đời |
  |---|---|---|---|
  | `research-gather` | `researcher`→router | `need_clarify` / `enough` | research |
  | `clarify-gate` | gate router | `missing_input` / `ok` | research→plan (biên) |
  | `plan-decompose` | classify router | `long` / `short` | plan (dài→ngắn) |
  | `re-plan-loop` | `verdict` router (back-edge → `planner`) | `fail` / `clarify` (→planner) / `proceed` | re-plan |
  | `do-verify-loop` | `verdict` router | `pass` / `fail` (→builder) | orchestrate(làm/kiểm) |
  | `escalate-gate` | gate router | `escalate` / `resolved` | escalate khi bí |

  Mỗi router **phải có 1 nhánh fallback an toàn** (`else` hoặc nhãn mặc định) — phòng khi mock không steer (xem rủi ro đa-router C.1) + theo precedent `branchy` (`else`).
- **Mock-driving (precedent từ `loopy`/`branchy`):** router agent mock không thực thi — chỉ `ENGINE_MOCK_ROUTER="<agentName>:l1,l2,..."` điều khiển nhãn theo lượt (agentName = basename .md của node router). **Giới hạn engine đã xác minh:** env var chỉ khớp **1 agent** → demo 1-router (mọi p-<name>) chạy ngon; demo tích hợp p-brain có nhiều router trên cùng path → cần xử lý ở C.1.
- **Out of scope:** viết catalog vai thật (P1 — demo dùng stub echo/router); Tester/sandbox (P2); memory store (PM); agent HQ + wiring graph HQ thật (P3/P4). Phase 0 chỉ giao *fragment topology + helper + demo mock*, không nội dung agent thật.

---

## Pipeline 3 sub-phase / 5 session

```
[0-A] Foundation: helper + format + pattern tham chiếu
      └─ engine/pattern.ps1 (Expand-Pattern) + patterns/README.md (convention)
         + patterns/do-verify-loop.json + examples/p-do-verify-loop/  (run -Mock pass)
                                    │
[0-B] 5 pattern còn lại (fragment + demo wrapper mỗi cái, run -Mock đúng)
      B.1 research-gather + clarify-gate     (research stage)
      B.2 plan-decompose + re-plan-loop      (plan stage)
      B.3 escalate-gate                      (orchestrate exit)
                                    │
[0-C] Integration: examples/p-brain/ nối 6 pattern theo §D
      └─ multi-router mock + traverse ≥3 path (pass / need_clarify→escalate / fail→re-plan)
         + done-gate + cập nhật ROADMAP/CLAUDE.md
                                    │
                                Phase 0 done
```

Vòng đời cần hiện thực: `research → plan(dài→ngắn) → orchestrate(làm/kiểm) → re-plan khi mơ hồ/fail → escalate khi bí`.

---

## Phase 0-A — Foundation: helper + format fragment + pattern tham chiếu

**Mục tiêu**: chốt **một lần** định dạng fragment + helper `Expand-Pattern`, chứng minh trọn pipeline `fragment → stamp → workflow.json → validate + run -Mock` trên 1 pattern tham chiếu (chọn `do-verify-loop` vì gần `loopy` đã proven). Sau session này, 5 pattern còn lại chỉ copy template.

### Session A.1 — Expand-Pattern + format + do-verify-loop
- **Scope**:
  1. Viết `engine/pattern.ps1`: hàm thuần `Expand-Pattern $fragment $prefix` (nhận object fragment + string prefix → trả `{nodes,edges}` đã đổi `__P__x`→`<prefix>_x` ở id + from/to; KHÔNG đụng field khác; guard `$null`/`.Count` theo StrictMode) + wrapper direct-run dot-source-safe (guard `InvocationName`/`Line` theo quy ước #5). Tái dùng `lib/json.ps1` để đọc/ghi.
  2. Viết `patterns/README.md`: convention fragment (shape `{meta,nodes,edges}`, placeholder `__P__x`, danh sách nhãn router chuẩn bảng trên, cách Expand-Pattern stamp, "engine runtime KHÔNG load fragment").
  3. Tạo `patterns/do-verify-loop.json`: `builder`→`tester`→`verdict`(router); `verdict --pass--> __P__done`, `verdict --fail--> __P__builder` (back-edge), fallback. `meta.routers=["__P__verdict"]`.
  4. Tạo `examples/p-do-verify-loop/`: `workflow.json` = output `Expand-Pattern` (prefix `dv`) + thêm `name`/`entry`/`max_steps` + agent stub (`agents/*.md` echo + 1 router stub); chạy stamp bằng script ngắn gọi `engine/pattern.ps1`.
- **STOP gate** (tất cả đo được):
  - [ ] `engine/pattern.ps1` tồn tại; chạy thử `Expand-Pattern` trên fragment do-verify → output **không còn chuỗi `__P__`** + số node/edge giữ nguyên (in đếm để xác nhận).
  - [ ] `patterns/do-verify-loop.json` + `patterns/README.md` tồn tại.
  - [ ] `./run.ps1 validate p-do-verify-loop` → exit 0.
  - [ ] `ENGINE_MOCK_ROUTER="dv_verdict:fail,pass" ./run.ps1 run p-do-verify-loop "x" -Mock` → status done, đi `builder→tester→verdict(fail)→builder→tester→verdict(pass)→done` (xác nhận qua `./run.ps1 status p-do-verify-loop`).
- **Output artifact**: `engine/pattern.ps1`, `patterns/README.md`, `patterns/do-verify-loop.json`, `examples/p-do-verify-loop/` (workflow.json + agents).

**Phase 0-A gate**: format fragment + Expand-Pattern chốt và chứng minh chạy được end-to-end trên 1 pattern; template demo wrapper sẵn sàng copy cho B.

---

## Phase 0-B — 5 pattern còn lại (fragment + demo wrapper)

**Mục tiêu**: hiện thực 5 pattern còn lại theo template A.1. Mỗi pattern = `patterns/<name>.json` + `examples/p-<name>/` (stamped workflow.json + stub) chạy `run -Mock` đúng nhãn chuẩn.

> **Định nghĩa "done" mỗi pattern (áp cho cả 3 session B):** fragment tồn tại + Expand-Pattern stamp ra workflow.json không còn `__P__` + `validate p-<name>` exit 0 + `run -Mock` (mock router theo kịch bản) đi đúng nhánh kỳ vọng, xác nhận qua `status`. Mọi router có fallback an toàn.

### Session B.1 — research-gather + clarify-gate (research stage)
- **Scope**:
  - `research-gather`: node `researcher` → router `need_clarify`/`enough`; `enough`→`__P__out` (sang plan), `need_clarify`→`__P__clarify` (biên sang clarify-gate). Demo p-research-gather chạy cả 2 nhánh (2 lần run khác mock label).
  - `clarify-gate`: router gate `missing_input`/`ok`; `ok`→`__P__out`, `missing_input`→`__P__escalate`. Chỉ escalate khi info thiếu THẬT (tài liệu hoá trong agent stub + README, không hỏi mặc định).
- **STOP gate**:
  - [ ] `patterns/research-gather.json` + `patterns/clarify-gate.json` tồn tại; Expand-Pattern stamp 2 cái → không còn `__P__`.
  - [ ] `validate p-research-gather` + `validate p-clarify-gate` đều exit 0.
  - [ ] `p-research-gather`: run mock `enough` → đi nhánh plan; run mock `need_clarify` → đi nhánh clarify. `p-clarify-gate`: run `ok`→out, `missing_input`→escalate. 4 run đúng nhánh (xác nhận qua `status`).
- **Output artifact**: 2 fragment + `examples/p-research-gather/`, `examples/p-clarify-gate/`.

### Session B.2 — plan-decompose + re-plan-loop (plan stage)
- **Scope**:
  - `plan-decompose`: node `planner` xuất plan-as-data → router classify `long`/`short` (theo brain-model: độ sâu do router, không do người). `long`→nhánh kế hoạch dài, `short`→nhánh ngắn.
  - `re-plan-loop`: `verdict` router với back-edge `fail`/`clarify` **về `__P__planner`** (KHÔNG về researcher — §Tension brain-model), `proceed`→tiến. Đây là pattern loop cốt lõi; mock kịch bản `clarify,fail,proceed` để chứng minh 2 vòng re-plan rồi thoát. `max_steps` cầu dao.
- **STOP gate**:
  - [ ] `patterns/plan-decompose.json` + `patterns/re-plan-loop.json` tồn tại; stamp không còn `__P__`.
  - [ ] `validate` cả 2 demo exit 0.
  - [ ] `p-plan-decompose`: run mock `long`→nhánh dài, `short`→nhánh ngắn. `p-re-plan-loop`: run mock `fail,clarify,proceed` → quay `planner` 2 lần rồi tiến (xác nhận `status` thấy `planner` iter≥2 + thoát đúng, không chạm `max_steps`).
- **Output artifact**: 2 fragment + `examples/p-plan-decompose/`, `examples/p-re-plan-loop/`.

### Session B.3 — escalate-gate (orchestrate exit)
- **Scope**:
  - `escalate-gate`: router gate `escalate`/`resolved`. Cầu dao thoát ra user khi bí thật (mô phỏng `revision ≥ max` hoặc `open_questions[]` không giải được — theo brain-model §Ranh giới). `escalate`→`__P__user` (thoát báo), `resolved`→`__P__out` (tiếp). Tài liệu hoá: escalate là nhánh thoát **graceful**, khác `max_steps` throw cứng.
- **STOP gate**:
  - [ ] `patterns/escalate-gate.json` tồn tại; stamp không còn `__P__`.
  - [ ] `validate p-escalate-gate` exit 0.
  - [ ] run mock `escalate`→nhánh user (thoát báo, done), `resolved`→nhánh tiếp. 2 run đúng nhánh.
- **Output artifact**: 1 fragment + `examples/p-escalate-gate/`. → **6/6 fragment xong.**

**Phase 0-B gate**: 6/6 `patterns/<name>.json` tồn tại; cả 6 demo wrapper `validate` exit 0 + `run -Mock` đi đúng mọi nhánh nhãn chuẩn; mọi cycle có `max_steps`; mọi router có fallback.

---

## Phase 0-C — Integration demo + done-gate

**Mục tiêu**: chứng minh 6 pattern **nối liền** thành vòng đời đầu-não §D (không chỉ chạy rời) — đúng done-gate ROADMAP: "research→plan→do/verify chạy thuận, mơ hồ → re-plan loop, bí → escalate thoát".

### Session C.1 — examples/p-brain/ (wiring 6 pattern) + multi-router mock
- **Scope**:
  1. **Xử lý đa-router mock (cần làm rõ — chốt đầu session):** p-brain có nhiều router trên cùng path (vd `research-gather` + `clarify-gate` cùng nằm nhánh need_clarify→escalate), nhưng `ENGINE_MOCK_ROUTER` chỉ khớp 1 agent. **Đề xuất (recommended):** mở rộng *hook mock* trong `engine/lib/claude.ps1` cho phép nhiều spec ngăn bởi `;` (`"a:l1,l2;b:l3"`) — thay đổi **testing-only, additive**, không đụng semantics runtime, vẫn hợp quy ước "Mock được offline". *Phương án dự phòng nếu muốn không-đụng-engine:* mỗi router có fallback `else` dẫn theo path mặc định + chạy nhiều lần, mỗi lần steer 1 router. Chốt 1 cách rồi ghi vào CHECKPOINT Notes.
  2. Tạo `examples/p-brain/workflow.json`: stamp 6 fragment bằng `Expand-Pattern` (prefix riêng mỗi pattern, vd `rg`/`cg`/`pd`/`rp`/`dv`/`eg`) + nối theo §D: `entry→researcher`; `enough→planner`, `need_clarify→clarify-gate`; `clarify-gate ok→planner`, `missing_input→escalate`; `planner long/short→builder`; `builder→tester→verdict`; `verdict pass→record/done`, `fail/clarify→planner` (re-plan), `escalate→escalate-gate→user`. `max_steps` cầu dao toàn graph. Agent stub echo/router.
  3. Chạy **≥3 path** bằng mock: (a) **happy:** `enough`+`long`+`pass` → research→plan→do/verify→done; (b) **clarify-escalate:** `need_clarify`+`missing_input` → research→clarify-gate→escalate thoát; (c) **re-plan:** `enough`+`long`+`fail,proceed`/`pass` → do/verify fail → quay planner → vòng 2 pass → done.
  4. `./run.ps1 viz p-brain` đọc được (ASCII + .mmd sinh ra).
  5. Verify done-gate checklist (xem Outcome cuối). Cập nhật `ROADMAP.md` bảng tiến độ (Phase 0 → ✅, cột Long-plan trỏ `plan/hq-build/phase-0/`) + `company/CLAUDE.md` bảng "Bản đồ file" (thêm `patterns/`, `engine/pattern.ps1`, `examples/p-*`, `plan/hq-build/phase-0/`).
- **STOP gate**:
  - [ ] `examples/p-brain/workflow.json` stamp từ 6 fragment, không còn `__P__`; `validate p-brain` exit 0.
  - [ ] 3 path mock (a/b/c) chạy `run -Mock` đi đúng nhánh kỳ vọng (xác nhận từng cái qua `status`): happy→done; clarify→escalate thoát; fail→re-plan loop về planner rồi pass→done.
  - [ ] `viz p-brain` sinh ASCII + `.mmd` không lỗi.
  - [ ] Done-gate checklist (Outcome cuối) **6/6 tick**; ROADMAP + CLAUDE.md cập nhật.
- **Output artifact**: `examples/p-brain/` (+ agents); (nếu chọn) patch `engine/lib/claude.ps1` multi-router mock; ROADMAP + CLAUDE.md cập nhật.

**Phase 0-C gate** = Outcome cuối.

---

## Outcome cuối

- `patterns/` có **6 fragment** (`research-gather`, `clarify-gate`, `plan-decompose`, `re-plan-loop`, `do-verify-loop`, `escalate-gate`) + `README.md` convention.
- `engine/pattern.ps1::Expand-Pattern` — stamp fragment được bằng máy (hàm thuần + wrapper, dot-source-safe).
- 6 demo wrapper `examples/p-<name>/` + 1 integration `examples/p-brain/` — tất cả `validate` exit 0 + `run -Mock` đúng.
- **Done-gate (checklist đo được):**
  - [ ] 6/6 `patterns/<name>.json` tồn tại, đúng format (`meta/nodes/edges`, placeholder `__P__x`, nhãn router chuẩn bảng).
  - [ ] `Expand-Pattern` stamp cả 6 → workflow.json không còn `__P__`, giữ nguyên số node/edge.
  - [ ] 6 demo wrapper + p-brain: `validate` đều exit 0.
  - [ ] Chạy mock đúng vòng đời: research→plan→do/verify **thuận**; mơ hồ → **re-plan loop** (quay planner) đúng; bí → **escalate thoát** đúng.
  - [ ] Mọi cycle có `max_steps`; mọi router có fallback an toàn.
  - [ ] `viz p-brain` đọc được; ROADMAP bảng tiến độ Phase 0 → ✅; CLAUDE.md bản đồ file cập nhật.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-05-26 | Initial | Tạo từ ROADMAP Phase 0 + brain-model §B/§D; chốt (user) demo = wrapper mỗi pattern + 1 integration, Expand-Pattern trong Phase 0; flag giới hạn ENGINE_MOCK_ROUTER 1-agent → C.1 |
