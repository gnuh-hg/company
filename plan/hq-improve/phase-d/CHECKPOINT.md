# CHECKPOINT — Phase D: Engine HITL + event stream

> Sổ tay tiến độ. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu. Đọc kèm `plan/hq-improve/phase-d/PLAN.md` + `plan/hq-improve/ROADMAP.md` §Phase D + §Bàn-giao-C→D/E/F + `plan/hq-improve/phase-c/CHECKPOINT.md` C.10 (vật chứng CC-b).

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu"). **STOP NGAY** khi đạt STOP gate — không tham làm session kế tiếp.
- **Sửa ở hàm thuần testable** (quy ước #1: `Invoke-WalkLoop`/`Invoke-Node`/`Resume-Workflow`/`Test-Workflow`/`Get-Graph`/`Test-DiffScope`), KHÔNG nhồi logic vào nhánh direct-run. `StrictMode` → guard `$null`/`.Count`.
- **Bất biến cốt lõi Phase D**: graph KHÔNG có node `approval` + KHÔNG diff-violation → walk chạy **y hệt trước**. Event stream + pause chỉ là khả năng THÊM (additive). Mock-path quan-sát-được bất biến (quy ước #3) — **kỳ vọng test cũ KHÔNG sửa**.
- **workflow.json chỉ ngữ nghĩa (quy ước #2)** — node `approval` KHÔNG toạ độ, KHÔNG nhét trạng-thái-runtime; state đi `.runs/<id>/state.json`, event đi `<run>/events.ndjson`.
- **Một surface lệnh (quy ước #4)** — duyệt/resume-kèm-decision là mở rộng `run.ps1 resume`, KHÔNG entry point mới.
- **Regression chuẩn (CUỐI mọi session)**: `./run.ps1 validate hello`=0 · `./run.ps1 run hello "x" -Mock`=done · `./run.ps1 selftest`=PASS (exit 0). Dọn `.runs/` + `examples/mem-demo/memory/` + sandbox + fixture tạm sau verify. **Fixture tạm để test → KHÔNG commit, dọn sau** (trừ `examples/approval-demo/` ở D.6 = fixture tái dùng, COMMIT như mem-demo).
- **D.7 tuỳ chọn đốt token**: chỉ session D.7 có thể có 1 real-run xác nhận CC-b — **PHẢI xin user duyệt** trước khi chạy. 6 session còn lại mock-only/free.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log".

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 7 | 5 | 71% |
| Khả năng HITL (approval node · awaiting · resume-decision) | 3 | 3 | 100% |
| Event stream (events.ndjson full output) | 1 | 1 | 100% |
| CC-b engine-part (Test-DiffScope + violation→awaiting) | 1 | ½ | 50% |
| Demo + selftest mục mới (approval-demo) | 1 | 0 | 0% |
| User gate (đóng phase; D.7 token nếu chạy) | 1–2 | 0 | — |

---

## Đang ở đâu

- **Phase**: D — engine human-in-the-loop + event stream (#3). **D.1 ✅ DONE · D.2 ✅ DONE · D.3 ✅ DONE · D.4 ✅ DONE · D.5 ✅ DONE.**
- **Session kế tiếp**: **D.6 — diff-violation → awaiting gate + demo fixture** (`engine/e2e.ps1`/`workflow.ps1` wire + `examples/approval-demo/` + `engine/test-runner.ps1`). Wire `Test-DiffScope` vào build-path `Invoke-E2E` (sau builder, trước promote): vi phạm → pause `awaiting` + event `diff_violation` thay vì promote mù. Fixture `examples/approval-demo/` (mock, offline): graph có node `approval` giữa plan→build → done-gate pause→resume. `test-runner.ps1` thêm 1 mục selftest approval-demo (11→12 mục).
- **Blocker**: — (không).
- **Reference**: `PLAN.md` §Session D.6.
- **⚠️ Hạ tầng pwsh (carry từ Phase C)**: `/snap/bin/pwsh` (7.6.2) CÓ sẵn nhưng hay core-dump RC=134 lúc teardown. **Cách chạy được**: `pwsh -NoProfile -Command '<inline>' 2>&1 | cat` + **`dangerouslyDisableSandbox: true`** → đọc NỘI DUNG output, KHÔNG tin exit code. Tránh `-File` mode (crash trước khi in) + stdin-pipe (bracketed-paste rác). Để drive TUI/`Read-Host`: file redirect `pwsh "..." < input.txt`.
- **⚠️ Encoding**: file `engine/*.ps1` là **UTF-16** (Windows-authored) → `grep`/`awk`/`cat`/`head` của Linux trả RỖNG/nhiễu. Dùng `pwsh` để đọc/sửa, hoặc `iconv -f UTF-16 -t UTF-8` khi cần soi bằng tool text. (Phát hiện 2026-05-30 lúc soạn plan.)

---

## Per-session log

### 2026-05-30 — Session D.5
- **Done**: `Get-SandboxSnapshot` + `Test-DiffScope` thuần testable thêm vào `engine/e2e.ps1`; test [5] thêm vào `examples/e2e-harness-tests.ps1`:
  - `Get-SandboxSnapshot $Dir`: snapshot `{relPath → LastWriteTimeUtc.Ticks}` toàn bộ file trong dir.
  - `Test-DiffScope $SandboxDir $AllowedPaths -Before $ht -After $ht`: so snapshot → liệt vi phạm (added/modified/deleted ngoài whitelist); dùng `Test-PathInside`; default whitelist = `projects/` + `spec.json`.
  - Test [5] mock-simulate 3 case: xoá `.runs/` → ok=False+violation, thêm ngoài whitelist → ok=False+violation, chỉ projects/ touch → ok=True.
- **Output**: `engine/e2e.ps1` (+2 hàm thuần, additive). `examples/e2e-harness-tests.ps1` (+test [5]).
- **Gate**: **PASS**. Test [5] 7/7 assertion xanh (3 case violation/clean). Regression chuẩn: validate hello=0 · run hello -Mock=done · selftest 11/11 PASS.
- **Next**: Session D.6 (diff-violation→awaiting gate wire + approval-demo fixture + selftest 11→12).
- **Notes**: `$AllowedPaths` cần `[Parameter(Position=1)]` để positional binding hoạt động với `@(array)`. Snapshot dùng `LastWriteTimeUtc.Ticks` — có thể miss nếu builder copy file giữ mtime; chấp nhận minor miss, ưu tiên đơn giản (D.6 wire vào Invoke-E2E snapshot trước/sau builder).

### 2026-05-30 — Session D.4
- **Done**: Headless `-AutoApprove` + exit-code awaiting + `status` hiển gate. 3 file sửa, đều additive:
  - `engine/workflow.ps1`: thêm `[switch]$AutoApprove` vào `Invoke-Workflow`; trong approval gate block: nếu `$AutoApprove` → chọn cạnh happy-path (ưu tiên `when='approve'` / 1 cạnh / fallback cạnh đầu) → `visit.status='done'`, cập nhật `state.path`, phát `node_done` với `auto_approved=$true`, advance cursor + `continue` (không return sớm).
  - `engine/run.ps1`: thêm `-AutoApprove` vào `Split-DispatchArgs`; cập nhật help text; trong `run` case: pass `-AutoApprove`, sau return kiểm `Get-RunState` → nếu `status='awaiting'` in prompt/hướng dẫn + return 3 (thay vì print "✓ Run xong"); trong `resume` case: tương tự.
  - `engine/status.ps1`: thêm `'awaiting'→Yellow` vào `Get-StatusColor` + `'awaiting'→'⏸'` vào `Get-VisitMark`; trong `Show-Status`: khi `status='awaiting'` in gate node, prompt, choices, resume hint.
- **Output**: 3 file engine (workflow/run/status) — đều additive, không đổi đường không-gate.
- **Gate**: **PASS**. `run -Mock` (no -AutoApprove) → exit 3 + in gate/prompt/hướng dẫn; `run -Mock -AutoApprove` → terminal done exit 0 (auto-approve → finish); `status` hiện awaiting+gate+choices+⏸; `resume -Decision approve` → tiếp tới terminal exit 0. Regression: validate hello=0 · run hello -Mock=done · selftest 11/11 PASS. Dọn fixture tạm `examples/_d4test/` + `.runs/`.
- **Next**: Session D.5 (diff-scope verify builder — `engine/e2e.ps1`, hàm thuần `Test-DiffScope`).
- **Notes**: `state.path` trong auto-approve bao gồm cả approval node (khác với awaiting-dừng không add vào path) — thiết kế đúng vì auto-approve coi node là "done". Fixture tạm `_d4test` dùng `"from": "finish", "to": null` → validate fail; fix: bỏ cạnh đó (terminal = không có cạnh ra).

### 2026-05-30 — Session D.3
- **Done**: Executor pause→awaiting + Resume-kèm-quyết-định. 2 file sửa, đều additive:
  - `engine/workflow.ps1`: thêm `-Decision` param cho `Invoke-Workflow`; trong resume path: xử lý `state.status='awaiting'` → convert visit awaiting→done + resolve decision (1 cạnh→approve, ≥2 cạnh→match `when`) → phát event `resumed`; trong walk loop: sau `node_start` event, check `$node.type -eq 'approval'` → dừng walk (visit.status='awaiting', ghi field `awaiting:{node,prompt,choices}` vào state.json, phát event `awaiting`, cập nhật latest.json) → return runDir sớm (không gọi model).
  - `engine/run.ps1`: thêm `-Decision` flag vào `Split-DispatchArgs`; pass `-Decision` tới `Invoke-Workflow` ở `resume` case; cập nhật help text `resume`.
- **Output**: 2 file engine (workflow/run) — đều additive, không đổi đường không-gate.
- **Gate**: **PASS**. Fixture 1-cạnh (entry→gate→worker): `run -Mock` dừng awaiting (status=awaiting, awaiting.node=gate, events=...awaiting) + `resume -Decision approve` → terminal done (events=...resumed,run_end). Fixture 2-cạnh (approve/reject): resume approve → worker; resume reject → escalate (rẽ đúng nhánh). Regression: validate hello=0 · run hello -Mock=done · selftest 11/11 PASS. Dọn 2 fixture tạm + .runs.
- **Next**: Session D.4 (headless `-AutoApprove` + exit-code awaiting + status hiển awaiting — `workflow.ps1` + `run.ps1`).
- **Notes**: Executor vẫn monolithic `Invoke-Workflow` (KHÔNG tách WalkLoop). `state['awaiting']` xử lý cả ordered hashtable (new run) lẫn PSCustomObject (resume path) bằng IDictionary check + `Add-Member -Force`. Path state không thêm approval node vào `$state.path` (approval dừng trước dòng `$state.path = ...`) — design đúng, path chỉ ghi node gọi model xong.

### 2026-05-30 — Session D.2
- **Done**: Thêm node type `approval` (gate người-duyệt, author-time — CHƯA pause executor). 3 file, đều additive:
  - `engine/graph.ps1`: `ConvertTo-NormNode` carry field `prompt` (alias `message`) cho node approval; direct-run summary thêm tag `(approval)`. `type` vốn đã pass-through generic nên approval load được sẵn — không cần nới loader.
  - `engine/validate.ps1`: approval CHỈ bắt buộc field `id` (không `agent`/`input`/`output_key` — gate không gọi model); luật cạnh approval = ≥1 cạnh-ra (gate phải tiếp tục), nếu ≥2 cạnh thì mỗi cạnh cần nhãn `when` (quyết định approve/reject), 1 cạnh thì `when` tuỳ chọn.
  - `engine/viz.ps1`: ASCII đánh dấu `⏸ <id> (approval)`; Mermaid render hexagon `id{{"⏸ label"}}` — KHÁC router-diamond `id{"label"}`.
- **Output**: 3 file engine (graph/validate/viz) — đều thêm-khả-năng, không sửa path cũ.
- **Gate**: **PASS**. Fixture tạm positive (start→gate(approval)→worker) validate **exit 0** (KHÔNG false "approval thiếu agent"); negative no-out-edge → "approval 'gate' cần ≥1 cạnh ra" (exit 1); 2-cạnh thiếu `when` → "cạnh 'gate→esc' cần nhãn 'when'" (exit 1); 2-cạnh đủ `when` → exit 0. Render: ASCII `⏸ gate (approval)` + Mermaid hexagon. Regression chuẩn: validate hello/loopy/branchy=0 · hq=0 (cảnh báo cũ data-cycle planner không đổi) · run hello -Mock=done · selftest 11/11 PASS. Dọn fixture tạm + `.runs/`+mem-demo memory+sandbox.
- **Next**: Session D.3 (executor pause→awaiting + Resume-kèm-quyết-định — `engine/workflow.ps1`).
- **Notes**: STOP gate đạt KHÔNG cần fixture commit (D.2 chưa có demo tái dùng — approval-demo để D.6). Field `prompt`/`message` thêm vào normNode sẵn cho D.3 dùng (executor hiện hiển thị prompt cho người duyệt). pwsh `/snap/bin/pwsh` + `dangerouslyDisableSandbox` chạy ổn, không core-dump session này. File engine UTF-8 (Read/Edit trực tiếp được).

### 2026-05-30 — Session D.1
- **Done**: Tạo module mới `engine/events.ps1` (dot-source-safe) với `Write-Event $RunDir $Type [$Payload]` — append 1 dòng NDJSON gọn (`ConvertTo-Json -Compress`, UTF8-no-BOM) vào `<run>/events.ndjson`, seq tự tăng theo số dòng (stateless → resume nối tiếp đúng), payload trộn top-level, lỗi ghi bị nuốt (event=quan sát, không phá run). Wire 5 loại event vào `Invoke-Workflow` (`workflow.ps1`): `run_start` (trước walk, cả new+resume), `node_start` (sau log running), `node_output` (full output, đóng #3), `node_done` (output_key+chars), `run_end` (success + cả 2 path fail max_steps/node-fail). `run.log` cũ GIỮ NGUYÊN (additive).
- **Output**: `engine/events.ps1` (mới) + 6 wire-point trong `engine/workflow.ps1` (dot-source + run_start + node_start + node_output + node_done + 3×run_end).
- **Gate**: **PASS**. `run hello -Mock` → `events.ndjson` 8 dòng JSON hợp lệ, đúng chuỗi `run_start`+2×(`node_start`+`node_output`+`node_done`)+`run_end`; `node_output` chứa FULL output khớp byte `1-a.out.txt`/`2-b.out.txt`; `run.log` còn nguyên. Regression chuẩn: validate hello=0 · run hello -Mock=done · selftest 11/11 PASS (exit 0). Dọn `.runs/`+mem-demo memory+sandbox.
- **Next**: Session D.2 (node type `approval`: schema + validate + render — author-time).
- **Notes**: Executor là monolithic `Invoke-Workflow` (KHÔNG có `Invoke-WalkLoop`/`Invoke-Node` riêng như PLAN giả định) → wire trực tiếp inline tại các điểm tự nhiên, không refactor (giữ #1 tối thiểu chạm). Bug nhỏ lúc đầu: `$Payload` thiếu `Position=2` → positional-binding fail "cannot find positional parameter for Hashtable"; fix = thêm `Position=2`. `file` báo `workflow.ps1` là UTF-8 (KHÔNG phải UTF-16 như CHECKPOINT cảnh báo) → Read/Edit tool xài trực tiếp được. pwsh `/snap/bin/pwsh` + `dangerouslyDisableSandbox` chạy ổn, không core-dump session này.

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-30 | Created from `PLAN.md` (3 sub-phase / 7 session). Default D-D1 reuse-resume · D-D2 node `approval` · D-D3 CC-b engine diff-scope ở D · D-D4 headless fail-rõ+`-AutoApprove` · D-D5 events.ndjson full-output (user skip câu hỏi 2026-05-30 → "Recommended") | @claude |
| 2026-05-30 | Session D.1 DONE — `engine/events.ps1` + wire 5 event vào `Invoke-Workflow`; gate PASS (8 events hợp lệ, node_output full, regression 11/11) | @claude |
| 2026-05-30 | Session D.2 DONE — node type `approval` (graph carry prompt + validate exempt-fields/edge-rule + viz hexagon/⏸); gate PASS (pos exit0, neg no-edge + missing-when bắt đúng, render đúng, regression 11/11) | @claude |
| 2026-05-30 | Session D.3 DONE — executor pause→awaiting + Resume-kèm-decision (`workflow.ps1` + `run.ps1`); gate PASS (1-cạnh approve→terminal, 2-cạnh approve/reject rẽ đúng, events awaiting+resumed, regression 11/11) | @claude |
| 2026-05-30 | Session D.4 DONE — headless `-AutoApprove` + exit-3 awaiting + `status` hiển gate (`workflow.ps1` + `run.ps1` + `status.ps1`); gate PASS (no-flag exit 3+hint, -AutoApprove terminal, status ⏸+prompt, resume→terminal, regression 11/11) | @claude |
