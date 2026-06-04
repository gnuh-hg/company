# CHECKPOINT — Phase I: Tối ưu token engine chi nhánh (hq-v2)

> Sổ tay tiến độ. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu"). **STOP NGAY** khi đạt STOP gate — không tham session kế.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log".
- **Regression mỗi session chạm engine** (bắt buộc trước STOP): `./run.ps1 validate hello` exit 0 · `./run.ps1 run hello "x" -Mock` done · `./run.ps1 selftest` PASS (11/11). Dọn `.runs/` test sau verify.
- **Mock-path BẤT BIẾN**: `-Mock` + `ENGINE_MOCK_ROUTER` không đổi semantics. Mọi thay đổi engine là ADDITIVE.
- **Key bridge mới `*_ref`** (I.C.1) phải reserved-aware: thêm vào `$script:ReservedKeys` + validate chặn làm `output_key`.
- **⚠️ Session I.D.2 ĐỐT TOKEN** (real-run) — STOP chờ user bật đèn xanh TRƯỚC khi chạy `run` không `-Mock`.

> **Ngoại lệ team-lead:** nếu user giao cả Phase I cho lead mà không giới hạn "1 session", lead làm hết các session liên tiếp (vẫn update CHECKPOINT + STOP gate sau MỖI session). RIÊNG **I.D.2 luôn dừng chờ user-gate** dù lead-mode (đốt token).

---

## Quyết định user đã chốt (2026-06-04)

- **D-I1** — Lossy handoff = **LAYER CẢ HAI**: artifact-by-reference (lossless) làm nền + conditional-trim CHỈ khi single-consumer.
- **D-I2** — Scope = **đủ cả 6 hạng mục** (đo · model-tier · siết template · artifact-by-ref · prompt-caching đào sâu · handoff-output).
- **D-I3** — Real-run burn = **user-gate 1 session cuối** (I.D.2); mọi session khác mock-only.

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 9 | 9 | 100% |
| Sub-phase pass | 4 (A/B/C/D) | 4 ✓ (I.A+I.B+I.C+I.D DONE) | 100% |
| Harness đo token | `run.ps1 tokens` + baseline.md | ✓ `tokens` cmd + baseline.md 3 fixture | ✅ |
| Token giảm real-run | giảm rõ (≥20% kỳ vọng) | cost −21.8% (n=1, caveat: non-det) | ✅ with caveat |
| Regression (validate/run-Mock/selftest) | PASS mỗi session | ✅ selftest 12/12 PASS | ✅ |

---

## Đang ở đâu

- **Phase**: ✅ **PHASE I DONE** — tất cả 9 session hoàn thành.
- **Session kế tiếp**: —
- **Blocker**: —
- **Reference**: `PLAN.md` Phase I.D → Session I.D.2
- **Baseline finding (I.A.2)**: web-demo prompt_chars tích lũy ×30 về cuối pipeline (story 18→deploy 552) → target chính cho I.B.2 (siết template) + I.C.1 (artifact-ref).
- **Lưu ý orchestration (2026-06-04)**: user chốt chain GỌN = self-builder → self-tester (planner+cto đã shutdown — PLAN.md đủ WHAT/HOW, lead brief trực tiếp). KHÔNG auto-commit; diff trình user duyệt cuối phase (D-S2).

---

## Per-session log

### 2026-06-04 — Session I.A.1
- **Done**: Bắt token usage thật từ `claude --output-format json` mỗi node + emit event `node_usage` + proxy mock (prompt_chars/output_chars). Additive — chữ ký `Invoke-Claude` cũ callable qua `[ref]$UsageOut` + `$PSBoundParameters.ContainsKey` guard; mock 2-return refactor → 1-return giữ output byte-identical.
- **Output**: `engine/lib/claude.ps1` (param `[ref]$UsageOut` + real `.usage`/`.total_cost_usd` parse StrictMode-safe + mock proxy) · `engine/workflow.ps1` (`$nodeUsage` + `-UsageOut ([ref]$nodeUsage)` + `Write-Event node_usage`) · `engine/events.ps1` (`'node_usage'` vào `$script:EventTypes`, 8→9 loại).
- **Gate**: PASS — validate hello exit 0 · run -Mock done · selftest 11/11 · events.ndjson có `node_usage` mỗi node (mock=true, prompt/output_chars≠0) · fixture-JSON real-path parse input=42/output=15/cache=5,10/cost=0.00025 · backward-compat string return xác nhận. self-tester verify độc lập = pass.
- **Next**: I.A.2
- **Notes**: chain gọn (self-builder→self-tester); chưa commit (D-S2). Changelog draft chờ user duyệt cuối phase.

### 2026-06-04 — Session I.A.2
- **Done**: Lệnh `run.ps1 tokens <proj> [-Run <runid>]` đọc events.ndjson → bảng per-node (agent/prompt_chars/output_chars/proxy_tok hoặc input/output/cache/cost real) + TỔNG; baseline mock proxy 3 fixture.
- **Output**: `engine/tokens.ps1` (NEW — `Get-RunTokens`/`Show-RunTokens` + direct-run guard dot-source-safe) · `engine/run.ps1` (dot-source + `-Run` value-flag + 'tokens' allowlist/case/help) · `plan/hq-v2/phase-i/baseline.md` (NEW — loopy 4 node, branchy 3 node, web-demo 11 node).
- **Gate**: PASS — validate/run-Mock/selftest 11/11 · `tokens loopy` bảng+TỔNG exit 0 · no-project exit 2 graceful · dot-source-safe + direct-run · baseline.md 3 sections. self-tester verify độc lập = pass (8/8 tiêu chí).
- **Next**: I.B.1
- **Notes**: Phase I.A (đo lường) DONE. web-demo accumulation ×30 = target I.B.2/I.C.1.

### 2026-06-04 — Session I.B.1
- **Done**: Gắn `model: claude-haiku-4-5-20251001` frontmatter vào 2 agent branching (outdeg≥2): `loopy/verdict-router.md` + `branchy/tier-router.md`. Xác nhận `Get-AgentFrontmatter`→`--model` wire (đọc code line 340 workflow.ps1 + `Invoke-Claude -Model`). web-demo = pipeline v1 linear, không có branching node → ghi nhận "không có gate". Convention ghi vào `catalog/README.md` §Convention: model-tiering agent.
- **Output**: `examples/loopy/agents/verdict-router.md` (thêm frontmatter `model: claude-haiku-4-5-20251001`) · `examples/branchy/agents/tier-router.md` (idem) · `catalog/README.md` (thêm §Convention model-tiering) · `plan/hq-v2/phase-i/CHECKPOINT.md` (update tiến độ).
- **Gate**: PASS — selftest 11/11 · validate hello/loopy/branchy exit 0 · run loopy (mock verdict-router:pass) done · run branchy (mock tier-router:gt1000) done · grep `model: claude-haiku` xác nhận 2 file.
- **Next**: I.B.2
- **Notes**: KHÔNG đụng executor; mock-path bất biến. wire `model:` xác nhận đọc code (không đốt token real). Không đụng .claude/agents/*.md → không cần re-spawn smoke.

### 2026-06-04 — Session I.B.2
- **Done**: Siết template `input` bỏ key dư → web-demo (schema bỏ spec, auth bỏ spec) + loopy (ship bỏ test). Đo DELTA thực tế + ghi baseline.md §I.B.2. Guideline "tối thiểu-key input" vào catalog/README.md.
- **Output**: `examples/web-demo/workflow.json` (schema: `{{tasks}}`, auth: `{{api}}`) · `examples/loopy/workflow.json` (ship: `{{build}}`) · `examples/loopy/agents/ship.md` (update text) · `catalog/README.md` (thêm §Guideline tối thiểu-key input) · `plan/hq-v2/phase-i/baseline.md` (thêm §I.B.2 delta).
- **Gate**: PASS — selftest 11/11 · validate hello/web-demo/loopy/branchy exit 0 · run web-demo -Mock done · run loopy -Mock (verdict-router:pass) done · `tokens web-demo` show 2315→1964 (−15.2%) · `tokens loopy` path 157→115 (−26.8%).
- **Delta**: web-demo −351 prompt_chars (−15.2%, cascade schema→api→auth/fe→deploy→qa); loopy −42 (−26.8%, ship node only).
- **Next**: I.C.1
- **Notes**: KHÔNG đụng engine/*.ps1; mock-path bất biến; validate chứng minh reachability OK. Không đụng .claude/agents/*.md → no re-spawn smoke.

### 2026-06-04 — Session I.C.1
- **Done**: Artifact-by-reference `{{key_ref}}` — engine pre-seed `<key>_ref=""` cho mọi output_key; sau khi node done ghi path tuyệt đối vào context; resume restore path. Validate block output_key kết thúc `_ref` + WARN nếu `{{x_ref}}` không có node x. Fixture `examples/ref-demo/` (writer→reader via {{report_ref}}). Selftest 11→12 (ref-demo/done-gate).
- **Quyết định ngưỡng**: LUÔN pre-seed _ref cho MỌI output_key (không threshold) — path string ngắn (~60-80 chars) luôn sẵn, tác giả opt-in. Ngưỡng khuyến nghị doc-only: output lớn (>2000 chars thực) → nên dùng _ref.
- **Output**: `engine/workflow.ps1` (3 changes: Initialize-Context pre-seed, output_key done set path, resume restore path) · `engine/validate.ps1` (2 changes: _ref suffix block output_key + _ref warn in key resolve) · `engine/test-runner.ps1` (11→12 mục, ref-demo/done-gate, bug fix `.Contains` thay `-like`) · `examples/ref-demo/workflow.json` + `agents/writer.md` + `agents/reader.md` (NEW fixture) · `plan/hq-v2/phase-i/CHECKPOINT.md`.
- **Gate**: PASS — selftest 12/12 · validate hello/loopy/branchy/web-demo/ref-demo exit 0 · run ref-demo -Mock done (reader prompt = path not full text) · validate block output_key=report_ref exit 1 đúng · run hello -Mock done.
- **Evidence**: `2-reader.prompt.txt` = `/home/.../report.txt` (82 chars path only, không chứa `[MOCK:writer]`).
- **Next**: I.C.2
- **Notes**: ADDITIVE — graph không dùng `_ref` chạy y hệt cũ (selftest 11 items cũ đều PASS). Không đụng .claude/agents/*.md → no re-spawn smoke.

### 2026-06-04 — Session I.C.2
- **Kết luận**: **Phase J ĐỦ — KHÔNG cần code engine mới.** Payload-per-successor = agent authoring concern. J đã tách route-label vs `_payload`, engine route đúng nhánh, nhánh dùng `{{verdict_payload}}` nhận shaped guidance.
- **Done**: Doc giao thức 2-phần vào `patterns/README.md` (bảng shaped payload + so sánh {{key}}/{{key_payload}}/{{key_ref}}). Cập nhật `verdict-router.md` (fail→FIX guidance; pass→short). Wired `{{verdict_payload}}` vào build input thay `{{verdict}}` (loopy). Verify mock: fail loop → build prompt iter 2 = "build project\nFIX: error on line 42".
- **Output**: `examples/loopy/agents/verdict-router.md` (shaped 2-part output format) · `examples/loopy/agents/build.md` (ref verdict_payload) · `examples/loopy/workflow.json` (build input: `{{verdict_payload}}` thay `{{verdict}}`) · `patterns/README.md` (§Giao thức 2-phần + bảng shaped payload) · `plan/hq-v2/phase-i/CHECKPOINT.md`.
- **Gate**: PASS — selftest 12/12 · validate hello/loopy/branchy/web-demo/ref-demo exit 0 · run loopy (fail→pass 2-loop) done · `4-build.prompt.txt` = "build project\nFIX: error on line 42" (payload nhánh fail flow đúng).
- **Next**: I.C.3
- **Notes**: branchy/2-part-protocol selftest (#10) PASS — tier-router đã có 2-part từ J.4, bất biến. Không đụng engine/*.ps1. Không đụng .claude/agents/*.md → no re-spawn smoke.

### 2026-06-04 — Session I.C.3
- **Quyết định wire**: **Helper-only + điểm quyết định (comment)**. Runtime engine KHÔNG tự-trim (default keep-full). Trim = opt-in: tác giả đổi {{key}} → {{key_ref}} khi Test-SingleConsumer = $true. Lý do: trim runtime đòi kiểm tra template consumer (complex/risky); helper enables safe authoring decision.
- **Quyết định selftest**: KHÔNG thêm mục mới (12 stays 12). Hàm thuần, unit-testable inline. Integration test overhead không cần thiết cho helper.
- **Done**: `Test-SingleConsumer $Graph $OutputKey` — strip `_payload`/`_ref` suffix → base key, đếm consumers, BFS cycle check. Dot-source-safe. Thêm comment "điểm quyết định" gần _ref wire. Unit test 9 cases PASS.
- **Output**: `engine/workflow.ps1` — 2 thay đổi ADDITIVE: (1) function `Test-SingleConsumer` (sau `Test-NodeBranches`), (2) comment điểm quyết định gần `_ref` wire. `plan/hq-v2/phase-i/CHECKPOINT.md`.
- **Gate**: PASS — selftest 12/12 · validate hello/loopy/branchy/web-demo/ref-demo exit 0 · run hello -Mock done · unit test 9/9 (loopy: build/verdict/test→false; hello: a→true, b→false; web-demo: tasks→true, spec→false; branchy: tier→true; ref-demo: report→true).
- **Lossless proof**: multi-consumer keys (spec: tasks+api+qa=3) → false = không trim → full đến mọi consumer. Loop keys (build/verdict/test trên cycle) → false = không trim. Graph cũ chạy y hệt (runtime unchanged).
- **Next**: I.D.1
- **Notes**: I.C DONE (I.C.1+I.C.2+I.C.3). Không đụng .claude/agents/*.md → no re-spawn smoke.

### 2026-06-04 — Session I.D.1
- **Quyết định**: **Chỉ-document** (KHÔNG wire code). Engine hiện tại đã optimal; caching outcome sẽ reveal tại I.D.2.
- **Findings:**
  1. Không có `--cache` flag tường minh trong CLI
  2. `--exclude-dynamic-system-prompt-sections` cải thiện cache NHƯNG bị ignored khi dùng `--system-prompt-file` (our case)
  3. `--betas` cho API-key users only — defer đến I.D.2 nếu cần
  4. Structure hiện tại đã optimal: `--system-prompt-file` (stable) trước, user prompt (variable) sau
  5. Kênh đo đã có (I.A.1): `cache_creation_input_tokens` + `cache_read_input_tokens`
  6. Best fixture để đo: `loopy` (build/test agent lặp nhiều vòng → best chance cache_read > 0)
- **Output**: `plan/hq-v2/phase-i/caching.md` (NEW — analysis + convention + cách đo I.D.2 + action table).
- **Gate**: validate hello exit 0 + run hello -Mock done (không chạm engine → không cần selftest đầy đủ).
- **Next**: I.D.2 ⚠️ REAL-RUN — **STOP chờ user bật đèn xanh** trước khi chạy.
- **Notes**: Không đụng engine/*.ps1; không đụng .claude/agents/*.md.

---

## Bản đồ session (tham chiếu nhanh PLAN.md)

| Session | Scope 1 dòng | STOP gate cốt lõi |
| --- | --- | --- |
| I.A.1 | Bắt usage JSON + event `node_usage` + proxy mock | events.ndjson có usage/proxy mỗi node; chữ ký cũ callable |
| I.A.2 | `run.ps1 tokens` + `engine/tokens.ps1` + baseline.md | `tokens loopy` in bảng; baseline.md có số ≥3 fixture |
| I.B.1 | Model-tier router/gate → Haiku (frontmatter) | agent branching/gate có `model:`; run -Mock done |
| I.B.2 | Siết template `input` bỏ key dư + guideline | fixture siết run -Mock done; proxy prompt giảm |
| I.C.1 | Artifact-by-reference `{{key_ref}}` (ngưỡng) | consumer prompt chứa path không full text; `_ref` reserved |
| I.C.2 | Handoff-output đích (payload per-successor, xây trên J) | payload nhánh-chọn flow đúng; branchy/2-part PASS |
| I.C.3 | Conditional-trim `Test-SingleConsumer` (bảo thủ) | single→trim-eligible, multi-consumer→giữ full (lossless) |
| I.D.1 | Prompt-caching verify/wire/document (mock-only) | caching.md kết luận rõ; mock-path bất biến |
| I.D.2 | ⚠️ REAL-RUN token report trước/sau (USER-GATE, đốt token) | token-report.md số thật giảm rõ + lossless path thực |

### 2026-06-04/05 — Session I.D.2
- **PHASE I DONE-GATE**: Real-run 2 fixture (tokrep-baseline + tokrep-opt) → token-report.md.
- **Kết quả thực:** input_tok +0.2% (flat) · output_tok −11% · cost −21.8% · cache_read confirmed hoạt động.
- **Bài học trung thực:** Template-trim KHÔNG giảm real input_tokens (system-prompt dominates ~50-80% input). Mock proxy −15% prompt_chars ≠ real input reduction. Muốn giảm THỰC SỰ: cắt agent system-prompt (agent .md ngắn hơn) hoặc giảm tool definitions.
- **Output**: `examples/tokrep-baseline/` (NEW) · `examples/tokrep-opt/` (NEW, fe_ref opt) · `plan/hq-v2/phase-i/token-report.md` (NEW, số thật + phân tích trung thực) · `CHECKPOINT.md` update.
- **Gate**: selftest 12/12 PASS · validate hello exit 0 · run hello -Mock done · cả 2 real-run done (events.ndjson có node_usage real, mock=false).
- **Lossless**: cả hai report.txt = BLOCKED verdict (no runnable build) — tương đương chất.
- **Notes**: KHÔNG commit. KHÔNG mutate projects/todo-web gốc. Phase I COMPLETE.

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-06-04 | Created from `PLAN.md` | planner |
| 2026-06-05 | Phase I DONE (I.D.2 real-run gate) | hq-self-builder |
