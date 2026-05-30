# PLAN — Phase D: Engine human-in-the-loop + event stream (#3)

> Sau toàn bộ Phase D: engine **biết dừng chờ người** (gate duyệt plan / cấp quyền / duyệt diff) và **phát event có cấu trúc đầy đủ output** mỗi lượt — tiền đề kỹ thuật cho app "điều khiển + duyệt" (D-2). Cụ thể: node type `approval` mới + state `awaiting` (tái dùng resume) + `Resume-Workflow` nhận quyết định; `<run>/events.ndjson` ghi đủ chuỗi event + nội dung output từng node (đóng #3 "log trống N chars"); engine **verify diff-scope builder** (CC-b — chặn lỗi chặn real-E2E tự động từ Phase C). **Chạy không-gate vẫn y như cũ** — mock-path + regression bất biến.

---

## Context

- **Vì sao chia nhiều session**: Phase D là **thay đổi kiến trúc lớn nhất đợt improve** (D-2: "engine PHẢI có pause-for-human + phát event"). Đụng **engine executor THẬT** (`workflow.ps1` — `Invoke-Workflow`/`Invoke-WalkLoop`/`Resume-Workflow`/`Save-RunState`/`Invoke-Node`), `validate.ps1` (node type mới), `graph.ps1`/`viz.ps1` (render gate), `run.ps1` (surface duyệt/resume-kèm-quyết-định), `e2e.ps1` (diff-scope guard), `test-runner.ps1` (demo fixture). Gom 1 chat sẽ ẩu + rủi ro hồi quy mock-path cao. Chia theo **lớp xây tăng dần**: event stream (quan sát, additive) → node type author-time → executor pause/resume → headless+surface → diff-scope guard → demo+docs.
- **Quyết định đã chốt (default "Recommended" — user skip câu hỏi 2026-05-30, đi theo đề xuất bám ROADMAP §Phase D "Cần làm rõ" + §Bàn-giao-C→D/E/F):**
  - **D-D1. Pause = TÁI DÙNG resume.** Pause = state đặc biệt `awaiting` ghi vào `state.json` + dừng walk; "duyệt" = `Resume-Workflow` bơm kèm **quyết định** (approve / reject / nhãn router / grant). Tận dụng resume sẵn có → ít chạm executor nhất, giữ mock-path bất biến. KHÔNG xây vòng chờ blocking mới.
  - **D-D2. Gate = NODE TYPE `approval` mới** (tường minh trên graph, giống `router` là 1 node-type). validate kiểm được, viz/Mermaid render được, app (E/F) vẽ được. Giữ bất biến #2 (chỉ ngữ nghĩa — KHÔNG toạ độ). KHÔNG dùng cờ ẩn trên node thường.
  - **D-D3. CC-b = engine-side diff-scope verify + gate Ở PHASE D.** Engine kiểm builder CHỈ đụng path khai báo (whitelist `projects/<name>` + `spec.json`), chặn xoá ngoài → vi phạm → pause `awaiting` (gate duyệt diff). Đóng **phần engine** của CC-b; **phần UI-duyệt** để Phase F. Verify bằng mock (giả diff vi phạm) — KHÔNG cần real-run để chứng minh logic engine.
  - **D-D4. Headless = cờ điều khiển, mặc định fail-rõ.** Gặp gate không-người → dừng + exit code/`status` = `awaiting` RÕ RÀNG (không treo vô hạn). Cờ `-AutoApprove` tự duyệt happy-path (cho selftest/CI mock offline). KHÔNG mặc định auto-resume (giữ ý nghĩa "duyệt"); KHÔNG treo cứng.
  - **D-D5. Event schema = `events.ndjson` đầy đủ output.** Mỗi lượt ghi 1 dòng JSON: `{seq, ts, type, node, agent, ...payload}` với `type ∈ {run_start, node_start, node_output (full content), node_done, awaiting, resumed, diff_violation, run_end}`. Đóng #3: live log có **nội dung output thật**, không chỉ "(N chars)". `run.log` cũ GIỮ (additive, không bỏ).
- **De-risk đã xác nhận (Phase C + ROADMAP)**:
  - **Test gọi hàm trực tiếp**: `examples/*-tests.ps1` + 7 `stamp.ps1` gọi `Invoke-Workflow`/`Resume-Workflow`/`Test-StructuralGate`/`Invoke-E2E`… KHÔNG qua command-string. `run.ps1 selftest` (Phase B, `engine/test-runner.ps1`) = **runner regression chuẩn** mọi session. Thêm khả năng additive (event/awaiting/approval-node) **không vỡ test cũ** miễn giữ signature + đường-không-gate y nguyên.
  - **resume đã tồn tại**: `Resume-Workflow` + `state.json` trong `.runs/<id>/` là nền sẵn — D-D1 chỉ **mở rộng** state có `awaiting` + decision-payload, không phát minh lại.
  - **CC-b vật chứng (C.10)**: builder real (có Bash, non-det) đã xoá `sandbox/<id>/.runs/` giữa run → tester/record fail. Builder BẮT BUỘC cần Bash (gọi `pwsh ENGINE_RUN build`) → không gỡ Bash. Fix đúng = engine verify diff-scope (đề xuất whitelist path) — KHÔNG gỡ tool. (Nguồn: `phase-c/CHECKPOINT.md` C.10 §Tồn-đọng.)
- **Ràng buộc bất biến (6 quy ước `company/CLAUDE.md`)** — Phase D đụng executor nên SIẾT:
  - **#1 engine code cố định**: sửa ở **hàm thuần testable** (`Invoke-WalkLoop`/`Invoke-Node`/`Resume-Workflow`/`Test-Workflow`/`Get-Graph`), KHÔNG nhồi logic vào nhánh direct-run.
  - **#2 workflow.json chỉ ngữ nghĩa**: node `approval` là ngữ nghĩa thuần — KHÔNG toạ độ, KHÔNG trạng-thái-runtime nhét vào workflow.json (state đi `.runs/<id>/state.json`).
  - **#3 mock bất biến**: `-Mock` + `ENGINE_MOCK_ROUTER` cú pháp + hành vi quan-sát-được y nguyên; **graph KHÔNG gate chạy y hệt trước** (event stream additive; pause chỉ kích hoạt khi có node `approval` hoặc diff-violation). Kỳ vọng test cũ KHÔNG sửa.
  - **#4 một surface lệnh**: duyệt/resume-kèm-quyết-định là command CỦA `run.ps1` (mở rộng `resume`), KHÔNG entry point mới.
  - **#5 dot-source-safe**: module mới (nếu tách `engine/events.ps1`) giữ guard `InvocationName`/`Line`.
  - **StrictMode -Version Latest**: guard `$null`/`.Count` (`@()`→`$null`).
- **Out of scope (bàn giao — xem §"Bàn giao sang E/F")**: App web (viewer E / live-log+duyệt F / edit G). UI duyệt diff/plan (F — D chỉ cung cấp engine pause + event + inject-decision surface). Stream SSE qua server (F). A-15 stream-trực-tiếp-lúc-chạy phía app (E). Phase D **chỉ engine + CLI surface + demo mock** — không động web.

---

## Pipeline 3 sub-phase / 7 session

```
[D-I — Event stream (additive, observability — đóng #3 phần engine)]
[D.1] events.ndjson emitter + full output capture ──► <run>/events.ndjson 7 loại event + wire walk/node (run.log GIỮ)
                                                          │
[D-II — Pause / HITL core (tái dùng resume)]
[D.2] node type `approval`: schema + validate + render ──► validate rule + graph/viz/Mermaid vẽ gate (author-time, chưa pause)
                                                          │
[D.3] executor pause→awaiting + Resume-kèm-quyết-định ──► Invoke-WalkLoop dừng ở approval → state awaiting → Resume-Workflow(decision) tiếp
                                                          │
[D.4] headless fallback + surface duyệt/resume ─────────► -AutoApprove + default fail-rõ awaiting-exit + run.ps1 resume <decision>
                                                          │
[D-III — CC-b diff-scope guard + demo + docs]
[D.5] diff-scope verify builder (whitelist path) ──────► engine kiểm builder chỉ đụng projects/<name>+spec; mock-simulate vi phạm
                                                          │
[D.6] diff-violation → awaiting gate + demo fixture ───► wire vi phạm→pause; examples/approval-demo + auto-verify trong selftest
                                                          │
[D.7] docs + ROADMAP handoff D→E/F + phase gate ───────► README/CLAUDE.md + §Bàn-giao-D→E/F + (tuỳ) real-run user-gated + USER GATE
```

---

## Phase D — Engine HITL + event stream

**Mục tiêu**: engine dừng-chờ-người (node `approval` + diff-violation) + phát event đầy đủ output; tái dùng resume; CC-b engine-part đóng; **chạy không-gate bất biến**. Mỗi session = 1 lớp; STOP gate gồm **regression chuẩn** + assertion riêng + **`git diff` không đụng vùng ngoài scope session**.

> **Regression chuẩn (mọi session)**: `./run.ps1 validate hello`=exit 0 · `./run.ps1 run hello "x" -Mock`=done · `./run.ps1 selftest`=PASS (exit 0). Dọn `.runs/` + `examples/mem-demo/memory/` + sandbox + fixture tạm sau verify. pwsh = `/snap/bin/pwsh` (xem CHECKPOINT §Hạ-tầng-pwsh: đọc nội dung output, KHÔNG tin exit code khi core-dump teardown).
> **Bất biến cốt lõi Phase D**: graph KHÔNG có node `approval` + KHÔNG diff-violation → walk chạy **y hệt trước** (event stream chỉ THÊM file, không đổi path/terminal/status). Mọi test cũ kỳ vọng KHÔNG đổi.

### Sub-phase D-I — Event stream

#### Session D.1 — events.ndjson emitter + full output capture
- **Scope** (`engine/workflow.ps1`, tuỳ chọn tách `engine/events.ps1` dot-source-safe):
  - Hàm `Write-Event $RunDir $Event` append 1 dòng JSON vào `<RunDir>/events.ndjson` (UTF8-no-BOM, đồng kiểu `Write-Json`). Schema: `{seq:int, ts, type, node, agent, payload}`.
  - Wire vào `Invoke-Workflow`/`Invoke-WalkLoop`/`Invoke-Node`: phát `run_start` (entry+request) · `node_start` (node+agent) · `node_output` (**nội dung output ĐẦY ĐỦ**, không cắt N chars) · `node_done` · `run_end` (status+terminal). Mock cũng phát (offline).
  - `run.log` cũ (char-count) **GIỮ NGUYÊN** — event là kênh THÊM, không thay.
- **STOP gate** (đo được):
  - `run hello "x" -Mock` → `.runs/<id>/events.ndjson` tồn tại; mỗi dòng JSON hợp lệ (`ConvertFrom-Json` từng dòng không lỗi); có đủ `run_start` + 2×(`node_start`+`node_output`+`node_done`) + `run_end`; `node_output` chứa **full output** "A: x"/"B: …" (so khớp `1-a.out.txt`).
  - Regression chuẩn xanh (`run.log` vẫn in như cũ; selftest PASS).
- **Output artifact**: `events.ndjson` emitter + wire (run.log bất biến).

### Sub-phase D-II — Pause / HITL core

#### Session D.2 — node type `approval`: schema + validate + render
- **Scope** (`engine/validate.ps1` + `engine/graph.ps1` + `engine/viz.ps1`) — **author-time, CHƯA pause executor**:
  - `graph.ps1`: nhận `type: "approval"` như node hợp lệ (cạnh tiếp như node thường — 1 cạnh-ra "tiếp tục" sau khi duyệt; có thể có cạnh "reject" nếu khai). KHÔNG cần agent/output_key bắt buộc (gate không gọi model).
  - `validate.ps1`: rule cho `approval` — không yêu cầu `agent`; có ≥1 cạnh-ra reachable tới terminal; (tuỳ) field mô tả `prompt`/`message` cho người duyệt. Reachability/router-when cũ không false-positive.
  - `viz.ps1`: render `approval` rõ (vd ký hiệu `⏸`/`[approval]`) trong ASCII + Mermaid (node-shape riêng, không nhầm router-diamond).
- **STOP gate**:
  - Fixture tạm graph có 1 node `approval` (entry→approval→worker→terminal) → `validate` exit 0 (không báo "approval thiếu agent" giả); `graph`/Mermaid render node gate đúng ký hiệu.
  - Negative fixture: `approval` không có cạnh-ra → `validate` báo lỗi reachable/dangling đúng.
  - Regression chuẩn xanh (validate hello/loopy/branchy/hq=0). Fixture tạm dọn.
- **Output artifact**: `approval` node-type hợp lệ + validate rule + render.

#### Session D.3 — executor pause→awaiting + Resume-kèm-quyết-định
- **Scope** (`engine/workflow.ps1` — `Invoke-WalkLoop`/`Resume-Workflow`/`Save-RunState`):
  - `Invoke-WalkLoop`: cursor chạm node `approval` → **dừng walk**, `Save-RunState` với `status: "awaiting"` + ghi `awaiting: {node, prompt, choices}` vào state.json + phát event `awaiting`. KHÔNG gọi model, KHÔNG đi tiếp.
  - `Resume-Workflow`: nhận tham số **quyết định** (`-Decision approve|reject|<router-label>` — additive, mặc định cũ không truyền vẫn resume-bình-thường cho run dở-dang non-gate). Decision `approve` → chọn cạnh "tiếp tục"; `reject`/nhãn → chọn cạnh tương ứng (nếu khai) → tiếp tục walk tới terminal/awaiting kế. Phát event `resumed`.
  - State machine: `running → awaiting → (resume) → running → … → done/failed`. `awaiting` persist đủ để 1 phiên khác resume (đồng tinh thần resume cũ).
- **STOP gate** (mock, free):
  - Fixture demo (entry→approval→worker→terminal): `run -Mock` → dừng ở `awaiting` (status=awaiting, KHÔNG tới terminal); `events.ndjson` có `awaiting`. `Resume-Workflow -Decision approve` → tiếp tới terminal (status=done), event `resumed`+`run_end`.
  - 2-cạnh fixture (approve→worker / reject→escalate): resume `approve` đi worker; resume lại từ baseline `reject` đi escalate (nhánh đúng theo decision).
  - Regression chuẩn xanh — **graph KHÔNG gate (hello/loopy/branchy/hq mock) chạy y hệt** (selftest PASS, hq-graph-tests 8 path không đổi).
- **Output artifact**: executor pause-at-approval + Resume-kèm-decision (tái dùng resume).

#### Session D.4 — headless fallback + surface duyệt/resume
- **Scope** (`engine/workflow.ps1` + `engine/run.ps1`):
  - **D-D4 headless**: cờ `-AutoApprove` (Invoke-Workflow + run.ps1) → gặp `approval` tự chọn cạnh happy-path ("tiếp tục") thay vì dừng — cho selftest/CI mock offline. Mặc định KHÔNG cờ → dừng `awaiting` + in hướng dẫn ("dùng `run.ps1 resume <proj> -Decision approve`") + exit-code phản ánh awaiting (không treo).
  - **Surface** (#4 một surface): mở rộng `run.ps1 resume <proj> [-Decision …]` gọi `Resume-Workflow` kèm quyết định; `status <proj>` hiển thị state `awaiting` + prompt cần duyệt. KHÔNG entry point mới.
- **STOP gate**:
  - `run <approval-demo> -Mock` (KHÔNG -AutoApprove) → dừng awaiting + in hướng dẫn resume + exit≠0-nhưng-rõ (không treo/hang).
  - `run <approval-demo> -Mock -AutoApprove` → tới terminal done (1 lệnh).
  - `run.ps1 resume <approval-demo> -Decision approve` (sau lần dừng awaiting) → tiếp tới terminal; `status` hiện awaiting trước khi resume.
  - Regression chuẩn xanh (resume cũ không-decision cho run non-gate dở-dang vẫn chạy).
- **Output artifact**: `-AutoApprove` + `run.ps1 resume -Decision` + `status` hiển awaiting.

### Sub-phase D-III — CC-b diff-scope guard + demo + docs

#### Session D.5 — diff-scope verify builder (whitelist path)
- **Scope** (`engine/e2e.ps1` + tuỳ `engine/lib/path.ps1` tái dùng `Test-PathInside`):
  - Hàm `Test-DiffScope $SandboxDir $AllowedPaths` (thuần, `{ok; violations[]}`): so danh sách path builder ĐỤNG (tạo/sửa/xoá) với whitelist khai báo (mặc định `projects/<name>` + `spec.json` trong sandbox) → liệt kê vi phạm (đụng/xoá ngoài whitelist, đặc biệt **xoá `.runs/`** — vật chứng C.10). Dùng `Test-PathInside` (C.4) cho so ranh-giới.
  - Cách lấy "path builder đụng": chốt trong session — đề xuất snapshot trước/sau (so cây file sandbox) hoặc đọc Bash-log builder. Ưu tiên snapshot diff (không phụ thuộc tool builder).
- **STOP gate** (mock-simulate, free — KHÔNG đốt token):
  - Unit `Test-DiffScope`: giả sandbox có file ngoài whitelist (vd xoá `.runs/`, ghi `../evil`) → trả `ok=False` + liệt kê đúng vi phạm; sandbox sạch (chỉ đụng `projects/<name>`) → `ok=True`.
  - Regression chuẩn xanh (e2e-harness-tests không hồi quy).
- **Output artifact**: `Test-DiffScope` engine-side (mock-test-được).

#### Session D.6 — diff-violation → awaiting gate + demo fixture
- **Scope** (`engine/e2e.ps1`/`engine/workflow.ps1` wire + `examples/approval-demo/` + `engine/test-runner.ps1`):
  - Wire `Test-DiffScope` vào luồng build (sau builder, trước promote): vi phạm → **pause `awaiting`** (gate duyệt diff, tái dùng D.3) + event `diff_violation` thay vì promote mù. (UI duyệt diff = Phase F; D chỉ dừng + ghi + cho resume-decision.)
  - Fixture `examples/approval-demo/` (mock, offline): graph có node `approval` giữa plan→build → done-gate verify pause→resume (giống mem-demo 2-tầng): chạy KHÔNG -AutoApprove dừng awaiting; resume approve → terminal.
  - `test-runner.ps1`: thêm 1 mục selftest cho approval-demo (auto-verify "dừng awaiting → resume approve → done"); cập nhật đếm tổng (11→12 mục).
- **STOP gate**:
  - `selftest` chạy thêm mục approval-demo PASS (pause→resume→done); cố tình bỏ resume → mục FAIL (assert thật).
  - Mock-simulate diff-violation trong build-path → pause awaiting + event `diff_violation` (KHÔNG promote).
  - Regression chuẩn xanh (selftest tổng PASS, exit 0).
- **Output artifact**: diff-violation→awaiting gate + `examples/approval-demo/` + selftest mục mới.

#### Session D.7 — docs + ROADMAP handoff + phase gate
- **Scope** (docs + `company/CLAUDE.md` + `plan/hq-improve/ROADMAP.md`; tuỳ chọn 1 real-run USER-GATED):
  - **README**: mục mới "Human-in-the-loop" — node `approval`, `-AutoApprove`, `run.ps1 resume -Decision`, `events.ndjson` (xem live output) + diff-scope guard builder. Cập nhật bảng lệnh (`resume` có `-Decision`).
  - **CLAUDE.md** bảng "Bản đồ file": hàng `plan/hq-improve/phase-d/` + cập nhật mô tả `workflow.ps1` (pause/awaiting/event) · `validate.ps1`/`viz.ps1` (approval) · `e2e.ps1` (Test-DiffScope) · `test-runner.ps1` (+approval-demo) · `examples/approval-demo/` mới · (nếu tách) `engine/events.ps1`.
  - **ROADMAP**: bảng tiến độ D ✅ + **§"Bàn giao D→E/F"** (event schema cho SSE F; awaiting+inject-decision surface cho UI duyệt F; render approval node cho viewer E; diff duyệt UI F).
  - **(Tuỳ chọn) 1 real-run xác nhận CC-b** (D-C-style, **ĐỐT TOKEN — USER GATE**): chạy lại `autobuild hq -Real -KeepSandbox` để xác nhận diff-scope guard BẮT được builder xoá sandbox (giữ -KeepSandbox + KHÔNG dọn để soi — bài học C.10). Chỉ chạy khi user bật đèn xanh; nếu không → đóng D dựa mock-simulate (logic engine đã chứng minh).
- **STOP gate**: README có mục HITL + events; CLAUDE.md + ROADMAP cập nhật (D ✅ + §Bàn-giao-D→E/F); regression cuối xanh (validate hello=0 · run hello -Mock=done · selftest PASS incl approval-demo); **user duyệt** đóng phase (ghi CHECKPOINT). Engine không-gate path `git diff` không đổi hành vi.
- **Output artifact**: docs + CLAUDE.md/ROADMAP cập nhật → Phase D đóng.

**Phase D gate** (sau D.7): node `approval` + state `awaiting` + Resume-kèm-decision (tái dùng resume); `events.ndjson` đủ chuỗi event + full output; `-AutoApprove` + default fail-rõ headless; `Test-DiffScope` engine-part CC-b + diff-violation→awaiting; `examples/approval-demo` + selftest mục mới; chạy không-gate bất biến (mọi test cũ xanh, kỳ vọng không đổi); ROADMAP §Bàn-giao-D→E/F ghi đủ; user duyệt. → cập nhật ROADMAP (D ✅).

---

## Bàn giao sang E / F (ghi vào ROADMAP cuối D.7)

> D *cung cấp engine* cho HITL/observability; **app web** (vẽ/stream/duyệt UI) thuộc E/F.

| Cross-cut | D làm gì | Phase sau phải làm tiếp |
| --- | --- | --- |
| **#3 live log** | `events.ndjson` đầy đủ output mỗi node (engine phát) | **Server stream SSE** + app hiển live output + highlight node → **Phase F** |
| **#3 HITL duyệt** | Engine pause `awaiting` + `Resume-Workflow -Decision` + surface CLI | **UI duyệt plan / cấp quyền** (post decision về server→engine) → **Phase F** |
| **CC-b diff** | Engine `Test-DiffScope` + diff-violation→awaiting (chặn promote mù) | **UI duyệt diff** (hiện diff builder, approve/reject) → **Phase F** |
| **#4 viewer** | Node `approval` render (ASCII/Mermaid) — app đọc workflow.json vẽ được | **App vẽ graph** + ký hiệu gate + zoom/pan/drag → **Phase E** |

---

## Outcome cuối

- Engine HITL: node type `approval` (tường minh, coordinate-free) + state `awaiting` (tái dùng resume) + `Resume-Workflow -Decision` (approve/reject/nhãn); headless `-AutoApprove` + default fail-rõ (không treo).
- `events.ndjson` 7 loại event với **nội dung output đầy đủ** mỗi node — đóng #3 phần engine ("(N chars)" → full); `run.log` cũ giữ.
- CC-b engine-part: `Test-DiffScope` (whitelist `projects/<name>`+spec, bắt xoá `.runs/`) + diff-violation→awaiting gate (chặn promote mù) — đóng lỗi-chặn-real-E2E từ C.
- `examples/approval-demo/` + selftest mục mới (pause→resume→done auto-verify); selftest 11→12 mục.
- **0 thay đổi hành vi đường không-gate** — graph không-`approval`+không-vi-phạm chạy y hệt; mock-path bất biến; mọi test cũ xanh, kỳ vọng không sửa.
- `ROADMAP.md` §Bàn-giao-D→E/F đầy đủ; gate đo lường: event-schema + pause/resume demo + diff-scope unit + selftest + user duyệt.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-05-30 | Initial | Soạn long-plan Phase D từ `ROADMAP.md` §Phase D ("Cần làm rõ" 5 mục) + §Bàn-giao-C→D/E/F (CC-b) + `phase-c/CHECKPOINT.md` C.10 (vật chứng builder xoá sandbox). Default D-D1..D-D5 (user skip câu hỏi 2026-05-30 → đi theo "Recommended"). 3 sub-phase / 7 session |
