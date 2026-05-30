# CHECKPOINT — Phase 5: Build-test-fix chạy thật end-to-end

> Sổ tay tiến độ dài hạn. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu. Thiết kế bất biến ở `PLAN.md`.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu"). **STOP NGAY** khi đạt STOP gate session đó — không tham làm session kế.
- **Token discipline**: Phase 5-A (5.1+5.2) **mock-only, gần free** — KHÔNG đốt real. Chỉ 5-B (5.3+5.4) chạy real, và **luôn dry-run `-Mock` trước** mỗi real run. Nếu real run lệch/fail → sửa **chỉ `hq/agents/*.md`** (prompt), KHÔNG engine; vượt budget 1 chat → STOP, retry chat sau.
- **Engine sửa có giới hạn**: Phase 5 ĐƯỢC sửa `engine/workflow.ps1` (+ có thể thêm `engine/e2e.ps1`) — nhưng **chỉ ở hàm thuần testable**, additive, dot-source-safe, StrictMode guard. **Mock-path PHẢI bất biến** (regression hello+hq mock sau mỗi sửa). KHÔNG đụng module khác trừ khi cần.
- **Chạy HQ bằng path form**: từ `engine/` gọi `./run.ps1 <cmd> ../hq ...` (project `hq` ở `company/hq/`).
- **Real run trong sandbox**: HQ real chạy qua harness Copy-ToSandbox → `company/sandbox/<runid>/`; branch promote sang `projects/`. Gốc `hq/` phải sạch sau mỗi session.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log". Dọn `.runs/`+`sandbox/`+`memory/` test sau verify.

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Session hoàn thành | 4 | 4 | 100% |
| Sub-phase | 2 (5-A plumbing / 5-B real) | ✅ 5-A done · ✅ 5-B done | 100% |
| Engine wiring (frontmatter→CLI) | done + mock bất biến | ✅ 5.1 done | 100% |
| Real-run harness (sandbox+promote+dry-run) | done + mock round-trip | ✅ 5.2 done | 100% |
| Branch real sinh + validate exit 0 | 1 (web-subset) | ✅ `landing-email` | 100% |
| Fix-loop real (Builder patch file thật) | 1 | ✅ `broken-web` | 100% |
| Done-gate criteria pass | 5 | ✅ 5 (gate 1·2·3·4·5) | 100% |

---

## Đang ở đâu

- **Phase**: 5 — **✅ HOÀN THÀNH (4/4 session, done-gate 5/5)**. Build-test-fix E2E thật chạy headless, không can thiệp giữa chừng.
- **5.4 kết quả**: `run.ps1 e2efix ../hq "fix: branch projects/broken-web …" -Seed ../examples/broken-web -Branch broken-web -Router "coo:fix;tester:pass" -Real` → HQ real đi `coo:fix→planner→cto→builder→tester:pass→record` (6 node, done) → Builder **patch tại chỗ** `workflow.json` (sửa typo edge target) → harness verify `validate` **3 lỗi → 0** + `file_changed=true` → **promote `company/projects/broken-web`**. **Tốn 2 real-attempt** (attempt 1 lộ planner/tester confusion → hardening prompt → attempt 2 pass clean).
- **5.3 kết quả**: happy-path build — branch `landing-email` (pm→ux→frontend-developer→qa-functional) promote, validate+check exit 0.
- **Blocker**: —
- **Reference**: Phase 5 done. Kế tiếp = Phase 6 (app GUI) — chưa có plan.

## ⚠ Watch-item còn treo (cho phase sau)
- **Builder non-determinism**: builder từng leak path ra hq gốc (5.3 run#3) + attempt-1 5.4 planner tự chẩn đoán/đòi sed thay vì plan-as-data. Đã hardening prompt (planner/tester/builder) nhưng KHÔNG guard cứng bằng engine (đúng triết lý "engine cố định, agent là prompt"). Theo dõi khi tăng độ phức tạp branch.
- **do-verify loop chưa chứng minh real**: 5.4 attempt-2 builder fix đúng iter 1 → tester pass ngay, KHÔNG kích `tester:fail_fix→builder` loop. Loop này đã test mock (Phase 4) nhưng chưa burn real. Optional, không thuộc done-gate.

---

## Quyết định đã chốt (input Phase 5 — không lật lại)

- **Q1 (branch target)**: web-demo subset — HQ tự sinh branch web nhỏ (pm→ba→frontend-developer→qa-functional + pattern do-verify) từ catalog.
- **Q2 (engine gap)**: Wire executor (additive) — `workflow.ps1` đọc frontmatter → truyền `--allowedTools`/`--permission-mode`/`--model` cho `claude` CLI. Ngoại lệ có chủ đích với bất biến #1 (Phase 5 cần real file-write).
- **Q3 (isolation)**: sandbox copy → promote — real HQ chạy trong `company/sandbox/<runid>/`, branch đạt promote sang `projects/`. Gốc luôn sạch.
- **Q4 (token/model)**: mock dry-run gate + model phân tầng (router/gate=haiku, cto/builder=sonnet qua frontmatter `model:`); `max_steps=40` backstop.
- **Phát hiện gốc (khảo code)**: (a) HQ sinh *pipeline chi nhánh* (workflow.json+agents), không phải app → Tester verify branch bằng validate/check (deterministic dù LLM thật); (b) `workflow.ps1:295` chưa truyền frontmatter flags → real Builder chưa ghi được file (việc plumbing 5.1).

---

## Per-session log

### Session 5.1 — Wire frontmatter → executor → claude CLI flags (2026-05-28) ✅
- **Làm gì**:
  - Thêm hàm thuần `Get-AgentFrontmatter $AgentPath` vào `engine/workflow.ps1` (trước `Invoke-Workflow`): parse YAML frontmatter → hashtable `@{ allowedTools; permission_mode; model }`. `allowedTools` inline list `[Write, Edit, Read]` → string space-joined `"Write Edit Read"` (định dạng `--allowedTools`). Field vắng = `$null` (giữ hành vi cũ). Dot-source-safe, StrictMode-safe.
  - Nối dây tại call site (workflow.ps1, chỗ gọi `Invoke-Claude`): đọc frontmatter node-agent → `model:` frontmatter override `-Model` global (fallback) → truyền `-Model`/`-AllowedTools`/`-PermissionMode`. `Invoke-Claude` đã sẵn 3 param này (`lib/claude.ps1`) → chỉ nối. **Additive**: mock-path không dùng các cờ này.
  - Thêm `model:` cho **cả 11** `hq/agents/*.md`: haiku (`claude-haiku-4-5-20251001`) cho router/gate (`coo`,`rg_gate`,`clarify_gate`,`escalate_gate`,`tester`); sonnet (`claude-sonnet-4-6`) cho `researcher`,`planner`,`cto`,`builder`,`escalate_report`,`record`.
- **STOP gate (đo được, mock-only)**:
  1. ✅ `Get-AgentFrontmatter builder.md` → `allowedTools="Write Edit Read Bash"` + `permission_mode="acceptEdits"` + `model="claude-sonnet-4-6"`.
  2. ⚠️→✅ `coo.md` → `model="claude-haiku-4-5-20251001"` + **`allowedTools="Read"`** (KHÔNG `$null` như PLAN ghi — agent đã được author với `[Read]` từ Phase 3). Tinh thần "non-builder không có Write/Edit" vẫn đúng. PLAN dùng `$null` là giả định cũ trước khi catalog có `[Read]`.
  3. ✅ Regression mock bất biến: `validate hello` exit 0; `run hello "x" -Mock` done (a→b); `validate ../hq` exit 0 (1 warning data-cycle có sẵn); hq happy-path mock (`ENGINE_MOCK_ROUTER="coo:build;rg_gate:enough;tester:pass"`) done, terminal=`record`, path 8-node y hệt trước — flags bị mock bỏ qua, output không đổi.
- **Cleanup**: xoá `hq/.runs`, `examples/hello/.runs`, `hq/memory/context.md` (artifact test) → `hq/` gốc sạch (chỉ `agents/`,`build-spec.md`,`skills.md`,`workflow.json`,`workflow.mmd`).
- **Token real tiêu**: 0.

### Session 5.2 — Real-run harness: sandbox-copy + promote + dry-run gate (2026-05-28) ✅
- **Làm gì**:
  - Thêm `engine/e2e.ps1` (module mới, hàm thuần dot-source-safe + StrictMode guard):
    - `Get-ProjectsRoot` → `company/projects` tuyệt đối.
    - `Test-DryRunGate $ProjectDir $Request [-RouterSpec] [-SuccessTerminal record]` → set/clear `ENGINE_MOCK_ROUTER` cục bộ (finally restore), chạy `Invoke-Workflow -Mock`, đọc `state.path[-1]` = terminal → `{ pass; status; terminal; reason; runDir }`. pass = done + terminal khớp. Mock-only, 0 token.
    - `Find-GeneratedBranch $SearchRoot [-Name]` → tìm `<root>/projects/<name>` có `workflow.json`.
    - `Promote-Branch $BranchDir $Name [-Force]` → copy branch → `projects/<Name>`, guard chống rò (đích phải StartsWith projects root) + chống đè (trừ -Force).
    - `Invoke-E2E $ProjectDir $Request [-RouterSpec] [-Real] [-BranchName]` → orchestrator: dry-run gate luôn chạy trước; **không -Real → DỪNG, báo sẵn-sàng-real (0 token)**; -Real → `Copy-ToSandbox` → run THẬT → locate → `validate`+`Test-StructuralGate` → `Promote-Branch` → `Remove-Sandbox` (finally).
    - `Write-E2EResult` → report + exit 0/1.
  - Wire `run.ps1`: dot-source `e2e.ps1`; thêm command `e2e` (allowlist + help); `Split-DispatchArgs` thêm `-Real`/`-Router` (additive, các command cũ bỏ qua field mới).
  - `.gitignore`: thêm `projects/*/` (branch promote regen-được, không commit; giữ thư mục `projects/`).
- **STOP gate (đo được, mock-only)**:
  1. ✅ Dry-run gate: happy (`coo:build;rg_gate:enough;tester:pass`) → pass + terminal=record; escalate (`coo:unclear;escalate_gate:escalate`, SuccessTerminal=escalate_report) → pass; happy + kỳ vọng terminal sai → fail (chặn real). `Invoke-E2E` không -Real → stage=dry-run, pass=true.
  2. ✅ Round-trip `Copy-ToSandbox`/`Remove-Sandbox` trên `../hq`: sandbox có `workflow.json`+`agents/`; teardown sạch; gốc `hq/` file count không đổi (15).
  3. ✅ `Promote-Branch` (branch giả trong sandbox/projects) → `Find-GeneratedBranch` tìm đúng → promote `projects/<name>` có workflow.json → dọn được.
  - Test: `examples/e2e-harness-tests.ps1` (15/15 assertion pass). Regression: `validate hello` exit 0, `run hello "x" -Mock` exit 0, `validate ../hq` exit 0, `run.ps1 e2e` dry-run exit 0 — mock-path bất biến (không đụng `workflow.ps1`).
- **Cleanup**: xoá `hq/.runs`, `hq/memory`, `examples/hello/.runs`; `projects/`+`sandbox/` rỗng; `hq/` gốc sạch.
- **Token real tiêu**: 0.

### Session 5.3-prep — Gap fix Builder-ghi-sandbox (wire cwd) + mock-verify (2026-05-28) ✅ (plumbing only)
- **Bối cảnh**: user chốt (chat #2) làm phần fix + mock-verify rồi **DỪNG trước real burn** (token=0 phiên này). Real happy-path (đốt token) để chat kế.
- **Gap xác nhận root-cause**: `run.ps1:147` resolve `Join-Path $here '../projects'` với `$here`=`company/engine` cố định → `build <name>` (không slash) ghi `company/projects` THẬT; `lib/claude.ps1` spawn claude **không set cwd** → subprocess kế thừa cwd pwsh (=engine) → Builder không ghi vào sandbox → `Find-GeneratedBranch <sandbox>/projects/` không thấy.
- **Fix (additive, mock-invariant, đúng allowance Phase 5)** — user chọn "wire cwd vào Invoke-Claude":
  - `lib/claude.ps1`: thêm param `-WorkingDir`; real-branch `Push-Location`/`Pop-Location` (finally) quanh `& claude` → cwd subprocess = project dir. **Mock branch return TRƯỚC** code này → mock bất biến.
  - `workflow.ps1` (call-site ~349): `$projAbs = (Resolve-Path $ProjectDir).Path` → truyền `-WorkingDir $projAbs`. Khi harness real chạy `Invoke-Workflow $sandboxDir` → cwd=sandbox → Builder dùng outName cwd-relative `projects/<name>` rơi đúng `<sandbox>/projects/`.
  - `hq/agents/builder.md` + `hq/skills.md`: chốt convention Builder gọi `run.ps1 build spec.json projects/<name>` (outName có `/` → engine ghi verbatim relative cwd, không rò ra gốc).
- **STOP gate (đo được, mock-only)**:
  1. ✅ `validate hello` exit 0; `run hello "x" -Mock` done (a→b); `validate ../hq` exit 0 (1 warning data-cycle có sẵn).
  2. ✅ hq dry-run gate (`coo:build;rg_gate:enough;tester:pass`) → done, terminal `record`, path 8-node y hệt.
  3. ✅ `examples/e2e-harness-tests.ps1` 15/15 pass — mock-path bất biến sau wire cwd.
- **Còn treo (cho real-run, xem "Đang ở đâu")**: Builder locating `run.ps1` từ cwd=sandbox (đường dẫn engine khác depth giữa real-E2E sandbox vs run hq trực tiếp).
- **Cleanup**: `hq/.runs`+`hq/memory` (test tự dọn), `examples/hello/.runs` xoá; `projects/`+`sandbox/` rỗng; `hq/` gốc sạch (5 item).
- **Token real tiêu**: 0.

### Session 5.3 — Happy-path real E2E (web-subset) (2026-05-28) ✅ REAL BURN
- **Plumbing trước burn**:
  - Reserved key `{{engine_run}}`: `Initialize-Context` (workflow.ps1) set `engine_run` = `Join-Path $PSScriptRoot 'run.ps1'` (tuyệt đối). Builder node input nối `ENGINE_RUN={{engine_run}}`. `validate.ps1 $ReservedKeys` += `engine_run`. `builder.md`/`skills.md` chốt convention `pwsh "<ENGINE_RUN>" build spec.json projects/<name>`.
- **Real burn — 5 attempt, mỗi lần lộ 1 lỗi thật rồi fix (chỉ `hq/agents/*.md` + hardening engine hàm thuần)**:
  1. **`permission_mode: read-only` invalid** — claude CLI chỉ chấp `acceptEdits/auto/bypassPermissions/default/dontAsk/plan`. Fix: 10 agent non-builder `read-only`→`default` (builder giữ `acceptEdits`).
  2. **Router in nhãn bọc markdown** (`` `enough` ``) → không khớp `when`. Fix engine (hàm thuần `ConvertTo-RouterLabel`, additive mock-invariant): strip ký tự bao non-`[A-Za-z0-9_]` ở 2 đầu dòng nhãn. Chặn tái phát cho cả 5 router.
  3. **COO quá thận trọng** → trả `unclear` (đòi chi tiết tech) → vào `escalate_gate` → rambling fail. Fix `coo.md`: `build` là **mặc định** cho mọi request nêu được sản phẩm; `unclear` chỉ khi rỗng/mâu thuẫn (researcher/clarify_gate lo chi tiết, không phải COO). Cũng hardening `tester.md` (4 nhãn đúng `pass/fail_fix/fail_replan/escalate` + bias `pass` khi builder báo validate OK — trước đó prompt ghi nhầm `pass/fail`) + `rg_gate.md` (bias `enough`).
  4. **locate fail** (run #3): full graph done→record nhưng không thấy branch trong sandbox. Root cause: Builder ghi spec vào `hq/specs/landing-email.json` (REAL hq, leak!) rồi build với Bash cwd=sandbox → build tìm `sandbox/specs/...` không có → branch không sinh. Test xác nhận Write tool **tôn trọng cwd** → leak là do Builder tự dựng path lệch (non-determinism). Fix `builder.md`: **cô lập cwd bắt buộc** — spec.json trần trong cwd, KHÔNG subdir/tuyệt đối/`cd`, đường tuyệt đối duy nhất = ENGINE_RUN. Thêm `-KeepSandbox` (debug switch, additive) vào `Invoke-E2E`+dispatch.
  5. **✅ SUCCESS**: branch `landing-email` (pm→ux→frontend-developer→qa-functional) → validate+check exit 0 → promote `projects/landing-email`.
- **STOP gate 5.3 (đo được, real)**:
  1. ✅ HQ `state.status=done`, terminal `record`, path 8-node.
  2. ✅ Branch: `workflow.json`+4 `agents/*.md`; `validate` exit 0; `check` exit 0.
  3. ✅ HQ `trial[]`: `build` (974 chars) + `record_result` (1420 chars) non-empty.
  4. ✅ Promote `projects/landing-email` + validate exit 0; sandbox teardown; `hq/` sạch (5 item).
- **Cleanup**: xoá `hq/specs` (run#3 leak) + `hq/.runs`+`hq/memory`+sandbox; `projects/landing-email` GIỮ (deliverable, gitignored). Mock regression cuối toàn xanh (hello+hq validate/run, harness 15/15, dry-run pass).
- **Engine đụng (đều hàm thuần, additive, mock-invariant)**: `workflow.ps1` (engine_run + ConvertTo-RouterLabel strip), `validate.ps1` (reserved key), `e2e.ps1`+`run.ps1` (-KeepSandbox).
- **Token real tiêu**: 5 real-attempt (1 happy-path 8-node ~4min/attempt; 4 fail sớm rẻ hơn).
- **Watch-item cho 5.4**: builder non-determinism từng leak ra hq (đã hardening prompt nhưng không guard cứng bằng engine — đúng triết lý "engine cố định, agent là prompt"); theo dõi ở fix-loop.

### Session 5.4 — Fix-loop real + done-gate + doc (2026-05-28) ✅ REAL BURN
- **Plumbing trước burn (mock-only, 0 token)**:
  - **Bơm `{{user_request}}` vào builder input node** (`hq/workflow.json`): `"{{user_request}}\n{{spec}}\n{{verdict}}\nENGINE_RUN={{engine_run}}"`. Lý do: graph fix route `coo→planner→cto→builder` không cho builder thấy branch nào cần patch. Additive, mock-invariant. (User chốt: "bơm context vào builder".)
  - `hq/agents/builder.md`: thêm mục "Khi `fix`" — KHÔNG rebuild, **patch tại chỗ** bằng Read+validate+Edit branch nêu trong request.
  - **Harness fix-loop** `engine/e2e.ps1` `Invoke-E2EFix` (hàm thuần): dry-run gate → `Copy-ToSandbox` → **seed branch hỏng** vào `sandbox/projects/<name>` → assert pre-fix `validate` FAIL + chụp SHA256 → run HQ real → assert post-fix `validate` exit 0 + `file_changed` (hash đổi → chứng minh Builder ghi thật) → `Promote-Branch`. Wire `run.ps1` command `e2efix` (+ `-Seed`/`-Branch` vào `Split-DispatchArgs`).
  - **Fixture** `examples/broken-web/` (committed, không gitignore): copy `landing-email` + gài typo edge `"to": "frontend-develper"` → `validate` 3 lỗi deterministic (dangling edge + 2 unreachable). Fix = sửa 1 ký tự.
- **STOP gate plumbing (mock)**: ✅ validate hello/hq exit 0; run hello -Mock done; `e2efix` dry-run (`coo:fix;tester:pass`) → done→record; harness 15/15.
- **Real burn — 2 attempt**:
  1. **planner + tester confusion** — planner KHÔNG xuất plan-as-data mà dump markdown chẩn đoán bug + recipe `sed` + than "read-only không ghi được"; tester thấy `{{build}}` (validate exit 0) vs `{{plan}}` (còn tả typo) → tưởng mâu thuẫn → **hỏi lại user** (headless, vô nghĩa) → dòng cuối "Đợi input bạn." → router strip → nhãn rác "i input bạn" throw. Builder **đã fix đúng** (validate exit 0) — chỉ tester labeling hỏng + loop 3× lãng phí. Fix prompt: `tester.md` (quy tắc cứng: `{{build}}`=hiện tại / `{{plan}}`=lịch sử; KHÔNG hỏi lại; dòng cuối luôn 1 nhãn trần) + `planner.md` (fix-context VẪN chỉ plan-as-data, không tự sửa/sed/than quyền).
  2. **✅ SUCCESS**: `coo:fix→planner→cto→builder→tester:pass→record` (6 node clean) → Builder patch `workflow.json` → `validate` 3→0, `file_changed=true` → promote `projects/broken-web`. Tester dòng cuối = `pass` trần.
- **STOP gate 5.4 (đo được, real)**:
  1. ✅ Fix run `state.status=done`, terminal `record`; builder chạy (patch) → tester `pass`.
  2. ✅ Branch sau fix `validate` exit 0 (trước fix = 3 lỗi) — harness assert pre=3/post=0.
  3. ✅ Builder ghi file THẬT (`file_changed=true`, SHA256 đổi) — chứng minh `allowedTools`/`permission_mode` wiring real.
  4. ✅ Doc cập nhật (ROADMAP/CLAUDE/CHECKPOINT); `.runs`+`sandbox`+`memory` dọn sạch; `hq/` gốc sạch (5 item).
- **Engine đụng (đều hàm thuần, additive, mock-invariant)**: `hq/workflow.json` (builder input + user_request), `e2e.ps1` (`Invoke-E2EFix` + Write-E2EResult fix fields), `run.ps1` (command `e2efix` + `-Seed`/`-Branch`). Prompt: `builder.md`/`tester.md`/`planner.md`.
- **Token real tiêu**: 2 real-attempt (attempt 1 loop 3× tốn hơn; attempt 2 clean 6-node).

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-28 | Created from `PLAN.md` | @planner |
| 2026-05-28 | Session 5.1 done — frontmatter wired + 11 agents có `model:` + mock regression xanh | @claude |
| 2026-05-28 | Session 5.2 done — `engine/e2e.ps1` (dry-run gate + sandbox + promote) + `run.ps1 e2e` + `.gitignore` + 15/15 mock test xanh; 5-A ✅ | @claude |
| 2026-05-28 | 5.3-prep — gap Builder-ghi-sandbox fix (wire `-WorkingDir` cwd vào Invoke-Claude + builder convention `projects/<name>`) + mock-verify xanh (hello+hq+harness 15/15); DỪNG trước real burn (user chốt). Token=0 | @claude |
| 2026-05-28 | 5.3 DONE — real burn thành công sau 5 attempt (fix: permission_mode→default, router label strip, coo bias build, tester 4-nhãn, builder cwd-isolation, engine_run key, -KeepSandbox). Branch `landing-email` promote `projects/`, validate+check exit 0. Gate 1·2·3 đạt | @claude |
| 2026-05-28 | 5.4 DONE — fix-loop real thành công sau 2 attempt. Plumbing: bơm `{{user_request}}` vào builder + `Invoke-E2EFix` (seed branch hỏng→verify fail→pass) + `run.ps1 e2efix` + fixture `examples/broken-web`. Fix prompt planner/tester (attempt 1 confusion). Branch `broken-web` validate 3→0, Builder ghi thật, promote. **Phase 5 ✅ — done-gate 5/5** | @claude |
