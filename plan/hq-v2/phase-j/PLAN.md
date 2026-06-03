# PLAN — Phase J: Rẽ nhánh chủ động (engine bơm choices + validate, CD-2)

> Sau khi xong Phase J: engine tự bơm tập nhãn hợp lệ vào prompt router lúc chạy; agent chọn nhãn mà không cần hardcode trong `.md`; nhãn sai → ghi issue-queue deterministic + fail rõ; route và payload tách thành 2 phần trong output router; mock-path bất biến; regression selftest 9/9 pass.

---

## Context

- **Vì sao chia nhiều session:** Phase J đụng engine executor (`workflow.ps1`, `bridge.ps1`, `lib/claude.ps1`) — mỗi session phải chạy regression gate đủ (validate + run -Mock + selftest) trước khi kết thúc. Có 4 thay đổi độc lập cần gate chất lượng riêng: (1) bơm choices vào prompt, (2) validate nhãn + ghi issue-queue, (3) tách route/payload, (4) update docs + fixture demo.
- **Ràng buộc external:** `ENGINE_MOCK_ROUTER` mock-path bất biến — session nào cũng verify mock không bị ảnh hưởng. Issue-queue file `company/issues/route-issues.ndjson` được gitignore (`issues/*.ndjson`) nên không ảnh hưởng git-tracked files.
- **Quyết định đảo ROADMAP (user chốt — ghi nhận ở đây):**
  - ROADMAP Phase J mô tả "re-ask 1 lần rồi mới fail". **User đảo (2026-06-03):** KHÔNG retry — **fail ngay**, NHƯNG trước khi fail phải ghi 1 entry kiểu cố-định-non-AI (deterministic, không gọi model) vào issue-queue file. Entry gồm: run id, node id, output thô của agent, tập nhãn hợp lệ kỳ vọng. Ghi vào file issue tập trung `company/issues/route-issues.ndjson` (xem J.2 §Vị-trí-issue-queue).
  - CD-2 (ROADMAP) ghi "sai → re-ask 1 lần". Quyết định thực thi: bỏ re-ask hoàn toàn, thay bằng ghi-queue rồi throw ngay. Behavior cuối (`throw`) giống như cũ — chỉ thêm bước ghi-queue trước khi throw.
- **Scope ngoài plan này:**
  - Retry cơ chế dùng forced tool-use (`--tool`) — defer làm fallback Phase I nếu cần.
  - Tối ưu token handoff-output (Phase I) — J chỉ đặt nền tách route/payload trong J.3.
  - App UX phản ánh nhãn bơm (Phase L).
  - HITL pause-policy (Phase K).

---

## Pipeline 3 phase / 5 session

```
[Phase 1] Bơm choices vào prompt ──────────► engine/workflow.ps1 (Get-RouterChoices + suffix)
                                                    │
[Phase 2] Validate nhãn + issue-queue ─────► engine/workflow.ps1 (validate tập nhãn bơm + Write-RouteIssue)
                                                    │
[Phase 3] Tách route/payload + docs ───────► giao thức output router 2-phần + fixture demo + docs
```

---

## Phase 1 — Bơm tập nhãn hợp lệ vào prompt router

**Mục tiêu**: Engine tự đọc cạnh ra của node router → tạo suffix "chọn đúng MỘT: { … }" → ghép vào prompt lúc chạy. Agent `.md` KHÔNG hardcode nhãn — nguồn sự thật duy nhất là `edges`/`when` từ graph. Mock-path (`ENGINE_MOCK_ROUTER`) bỏ qua bước bơm (bất biến).

### Session J.1 — Hàm Get-RouterChoices + wire vào Invoke-Workflow

- **Scope**:
  1. Thêm hàm thuần `Get-RouterChoices` vào `engine/workflow.ps1` (hoặc `bridge.ps1` — xem §Thiết kế): nhận `$Graph` + `$NodeId` → trả `[string[]]` tập nhãn `when` của cạnh ra (loại bỏ blank, lowercase, sort).
  2. Trong `Select-NextNode` (hoặc caller `Invoke-Workflow`): nếu node type `router` AND `-not $Mock` → gọi `Get-RouterChoices` → tạo suffix engine-side (hằng cố định, không cấu hình per-node): `"\n\n---\nChọn đúng MỘT nhãn sau (in nhãn ở dòng cuối):\n{ <choice1> | <choice2> | ... }"` → ghép vào `$Prompt` trước khi gọi `Invoke-Claude`.
  3. Khi `-Mock`: KHÔNG ghép suffix (mock trả nhãn qua `ENGINE_MOCK_ROUTER`, bỏ qua bơm). Guard: `if (-not $Mock)`.
  4. Module dot-source-safe: hàm mới phải không tự exec khi dot-source.
  5. Regression: `./run.ps1 validate hello` exit 0 + `./run.ps1 run hello "x" -Mock` done + `./run.ps1 selftest` 9/9 pass.

- **Thiết kế chỗ đặt suffix**: suffix ghép trong `Invoke-Workflow` tại vị trí gọi `Invoke-Claude` cho router node (tách khỏi `Select-NextNode` vì Select không nhận prompt). Hàm `Get-RouterChoices` đặt trong `workflow.ps1` (cùng file với `Select-NextNode`, dùng chung `$Graph`).

- **STOP gate**: `./run.ps1 selftest` trả `9/9 PASS` + `./run.ps1 run branchy "test" -Mock` done (mock router vẫn chạy đúng) + manual verify: khi chạy real mode (nếu user cho chạy), suffix xuất hiện trong prompt được build (có thể verify qua log run dir `<output_key>.txt` hoặc thêm `-Verbose` — chưa yêu cầu real run).

- **Output artifact**: `engine/workflow.ps1` (sửa: thêm `Get-RouterChoices` + wire suffix khi !Mock).

**Phase 1 gate**: `./run.ps1 selftest` 9/9 PASS + `./run.ps1 run branchy "x" -Mock` done (mock path bất biến) + `./run.ps1 validate loopy` exit 0.

---

## Phase 2 — Validate nhãn trả về + ghi issue-queue

**Mục tiêu**: Sau khi agent real-mode trả output, `Select-NextNode` validate nhãn nằm trong tập nhãn đã bơm; nếu sai → ghi 1 entry deterministic vào issue-queue per-run → `throw` (fail ngay, không retry). Mock-path bất biến (mock trả nhãn trực tiếp, không qua validate tập bơm).

### Session J.2 — Write-RouteIssue + validate tập nhãn trong Select-NextNode

- **Scope**:
  1. **Vị trí issue-queue**: file issue **tập trung** `company/issues/route-issues.ndjson` (gom cùng các loại issue khác trong `company/issues/` — xem `company/issues/README.md`). Append 1 dòng / entry qua mọi run; gitignored (`issues/*.ndjson`). Đường dẫn resolve relative engine module root (vd `$PSScriptRoot/../issues/route-issues.ndjson`) + tạo thư mục nếu chưa có. Không ghi vào `company/issues/team-issues-queue.md` (cái đó cho HQ-team behave, không phải engine chi nhánh).
  2. Thêm hàm `Write-RouteIssue` vào `engine/workflow.ps1`: nhận `$RunDir` (để lấy run id cho entry), `$NodeId`, `$RawOutput`, `$ValidChoices[string[]]` → append 1 dòng JSON (fields: `ts`, `run_id`, `node`, `raw_output`, `valid_choices[]`, `label_extracted`) vào `company/issues/route-issues.ndjson`. Hàm **không gọi model**, thuần deterministic.
  3. Trong `Select-NextNode` (hoặc caller sau khi có nhãn real-mode): validate `$label` có trong tập `Get-RouterChoices` — nếu sai → `Write-RouteIssue` → `throw` thông báo cũ (giữ nguyên text throw hiện tại để không break app/tester đang parse). `$RunDir` truyền qua param mới hoặc qua caller (để derive run id ghi vào entry).
  4. Khi `-Mock`: KHÔNG validate tập bơm (mock đã trả nhãn đúng qua `ENGINE_MOCK_ROUTER`; validate sẽ pass trivially vì nhãn mock khớp `when` — nhưng để tránh coupling, skip toàn bộ `Write-RouteIssue` khi Mock).
  5. **Tương thích ngược**: router với nhãn đúng → không ghi issue, throw không đổi. Router trong cả `branchy`/`loopy`/`approval-demo` vẫn validate exit 0.
  6. Regression: selftest 9/9 + validate hello exit 0 + run hello -Mock done.

- **Demo mock sai nhãn**: script demo nhỏ (không vào selftest — optional): set `ENGINE_MOCK_ROUTER` trả nhãn không tồn tại, chạy `run branchy "x" -Mock` → phải FAIL với throw + file `route-issues.ndjson` có 1 entry. Kiểm tra bằng `Test-Path` + `Get-Content` + `ConvertFrom-Json`.

  _Lưu ý_: Mock-path hiện tại trả nhãn hợp lệ từ `ENGINE_MOCK_ROUTER` (nhãn khớp `when`) → demo cần nhãn sai → dùng `ENGINE_MOCK_ROUTER` với nhãn không-trong-graph (vd `"verdict_router:nonexistent"`). Đây là test case manual, không thêm vào selftest (selftest phải 9 mục pass).

- **STOP gate**: `./run.ps1 selftest` 9/9 PASS + `./run.ps1 validate branchy` exit 0 + `./run.ps1 run branchy "x" -Mock` done + file `engine/workflow.ps1` có hàm `Write-RouteIssue` (grep confirm) + manual demo sai nhãn tạo `route-issues.ndjson` (verify bằng pwsh one-liner).

- **Output artifact**: `engine/workflow.ps1` (sửa: thêm `Write-RouteIssue` + validate tập nhãn real-mode + truyền `$RunDir` vào `Select-NextNode` hoặc caller).

**Phase 2 gate**: selftest 9/9 + `Write-RouteIssue` tồn tại + `route-issues.ndjson` được tạo khi nhãn sai (manual verify) + mock-path bất biến.

---

## Phase 3 — Tách route/payload + fixture demo + docs

**Mục tiêu**: Router output có cấu trúc 2 phần (1 dòng route + phần còn lại là payload); engine tách và lưu payload riêng để node successor đọc được; fixture demo `examples/branchy` cập nhật agent stub để dùng cú pháp 2-phần; docs + CLAUDE.md cập nhật.

### Session J.3 — Giao thức 2-phần: parse + store payload

- **Scope**:
  1. **Giao thức**: router output gồm 2 phần ngăn bởi dấu `---` (hoặc blank line + nhãn cuối). Cú pháp chuẩn: phần trước = payload tự do; dòng cuối = nhãn route. `ConvertTo-RouterLabel` giữ nguyên (lấy dòng cuối) → nhãn không đổi. Payload = toàn bộ output TRỪ dòng nhãn cuối.
  2. Thêm hàm `Get-RouterPayload` vào `engine/workflow.ps1`: nhận `$Output` → trả phần payload (string, có thể rỗng nếu chỉ có 1 dòng nhãn). Hàm thuần, deterministic.
  3. Engine lưu payload vào context dưới key `<output_key>_payload` (tự động, không cần khai báo trong workflow.json). Node successor có thể dùng `{{<output_key>_payload}}` trong `input` template.
  4. **Tương thích ngược**: router chỉ in nhãn đơn (không có payload) → `Get-RouterPayload` trả `""` → `_payload` key = `""` trong context → `Resolve-Prompt` resolve bình thường (pre-seed behavior). KHÔNG break bất kỳ workflow hiện có.
  5. `validate.ps1`: KHÔNG cần sửa (key `_payload` là dynamic, không cần khai báo `output_key`). Nếu tác giả dùng `{{<router>_payload}}` trong input mà router không có payload → resolve `""` (không throw vì pre-seed).
  6. Mock-path: mock router chỉ in nhãn → `_payload` = `""` → bất biến.
  7. Regression: selftest 9/9 + validate hello + run hello -Mock + validate branchy + run branchy -Mock done.

- **STOP gate**: `./run.ps1 selftest` 9/9 PASS + `./run.ps1 run branchy "x" -Mock` done + `Get-RouterPayload` tồn tại trong `workflow.ps1` (grep) + manual verify: workflow có node dùng `{{verdict_router_payload}}` → resolve đúng (test bằng script inline pwsh).

- **Output artifact**: `engine/workflow.ps1` (thêm `Get-RouterPayload` + wire lưu `_payload` vào context sau mỗi router node).

### Session J.4 — Fixture branchy agent stub + validate.ps1 cập nhật + selftest entry mới

- **Scope**:
  1. **Fixture demo**: cập nhật agent stub của `examples/branchy/` (nếu chưa có `agents/` → tạo stub `.md` minimal; nếu đã có → chỉnh) để stub router in payload + nhãn 2-phần. Fixture phải `validate exit 0` + `run -Mock` done sau khi sửa.
  2. **Selftest entry mới (tùy chọn)**: nếu đủ phức tạp để justify → thêm mục thứ 10 vào `engine/test-runner.ps1` kiểm tra giao thức 2-phần trên `examples/branchy` (mock: router in `"payload text\nbranch_a"` → verify payload key có "payload text"). Nếu quá phức tạp → skip (giữ selftest 9 mục, chỉ manual verify).
  3. **validate.ps1**: thêm check `_payload` key không cần khai báo (nếu detect `{{<key>_payload}}` trong input mà không có `output_key` = `<key>` trên bất kỳ node router nào → warn, không error). Đây là additive.
  4. Regression cuối: selftest ≥9 PASS (nếu thêm mục → 10) + validate hello/branchy/loopy exit 0 + run hello/branchy -Mock done.

- **STOP gate**: `./run.ps1 selftest` ≥9 PASS (số mục rõ trong CHECKPOINT) + `./run.ps1 validate branchy` exit 0 + `./run.ps1 run branchy "x" -Mock` done + `./run.ps1 validate loopy` exit 0 + `./run.ps1 run loopy "x" -Mock` done.

- **Output artifact**: `examples/branchy/agents/` (tạo/sửa stub) + `engine/test-runner.ps1` (nếu thêm mục) + `engine/validate.ps1` (nếu thêm warn _payload).

### Session J.5 — Docs + CLAUDE.md + ROADMAP cập nhật

- **Scope**:
  1. Cập nhật `README.md`: thêm ghi chú về "Router choices auto-inject" (1 đoạn ngắn trong §workflow.json doc hoặc §engine behavior) + format output 2-phần (route nhãn cuối / payload phần trước).
  2. Cập nhật `CLAUDE.md` "Bản đồ file": sửa hàng `engine/workflow.ps1` thêm ghi chú Phase J (Get-RouterChoices, Write-RouteIssue, Get-RouterPayload) + thêm hàng `plan/hq-v2/phase-j/PLAN.md` + `CHECKPOINT.md` (nếu chưa có từ bước planner tạo plan này).
  3. Cập nhật `plan/hq-v2/ROADMAP.md` bảng tiến độ: Phase J → ✅ DONE + ngày.
  4. Cập nhật `CHECKPOINT.md` Phase J: đánh dấu tất cả session done + thêm per-session log.
  5. Regression cuối đợt J: `./run.ps1 selftest` ≥9 PASS + `./run.ps1 validate hello` exit 0 + `./run.ps1 run hello "x" -Mock` done + `./run.ps1 validate branchy` exit 0 + `./run.ps1 run branchy "x" -Mock` done.

- **STOP gate**: Tất cả file docs đã sửa + selftest ≥9 PASS + `grep -r 'Get-RouterChoices\|Write-RouteIssue\|Get-RouterPayload' /home/gnuh/Documents/company/engine/workflow.ps1` trả 3 hàm + ROADMAP table Phase J = ✅ DONE.

- **Output artifact**: `README.md` + `CLAUDE.md` + `plan/hq-v2/ROADMAP.md` + `plan/hq-v2/phase-j/CHECKPOINT.md`.

**Phase 3 gate**: selftest ≥9 PASS + validate/run -Mock trên hello/branchy/loopy đều PASS + docs phản ánh surface mới + ROADMAP Phase J = ✅ DONE.

---

## Outcome cuối

- **Engine bơm choices**: mọi node router real-mode nhận suffix "chọn đúng MỘT: { … }" — agent không cần hardcode nhãn trong `.md`, nguồn sự thật duy nhất là graph `edges`/`when`.
- **Validate + issue-queue**: nhãn sai → `company/issues/route-issues.ndjson` có entry deterministic → throw rõ. Mock-path bất biến.
- **Tách route/payload**: router in payload + nhãn; engine lưu `_payload` key tự động; successor đọc `{{<key>_payload}}`; tương thích ngược (router chỉ in nhãn đơn = payload rỗng).
- **Gate đo được**: selftest ≥9 PASS + validate hello/branchy/loopy exit 0 + run -Mock done + `Write-RouteIssue`/`Get-RouterChoices`/`Get-RouterPayload` tồn tại trong `workflow.ps1`.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-06-03 | Initial | Phase J CD-2, user chốt 4 quyết định (bơm/không-retry+queue/ConvertTo-RouterLabel giữ/tách-route-payload) |
| 2026-06-03 | Ghi rõ đảo ROADMAP: bỏ re-ask, thêm Write-RouteIssue + fail ngay | User chốt 2026-06-03 — khác mô tả ROADMAP CD-2 "re-ask 1 lần" |
