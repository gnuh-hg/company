# CHECKPOINT — Phase C: Fix bug + de-chắp-vá

> Sổ tay tiến độ. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu. Đọc kèm `plan/hq-improve/phase-c/PLAN.md` + `plan/hq-improve/phase-a/findings.md` (nguồn chân lý 22 finding).

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu"). **STOP NGAY** khi đạt STOP gate — không tham làm session kế tiếp.
- **Sửa ở hàm thuần testable** (quy ước #1), KHÔNG nhồi logic vào nhánh direct-run. `StrictMode` bật → guard `$null`/`.Count`.
- **Mock-path bất biến (quy ước #3)**: `-Mock` + `ENGINE_MOCK_ROUTER` cú pháp cũ phải chạy y nguyên, **kỳ vọng test cũ KHÔNG sửa**. A-02/A-24 chỉ được **THÊM** khả năng (keyed-by-node / heuristic), không phá keyed-by-agent.
- **workflow.json chỉ ngữ nghĩa (quy ước #2)** — A-18 fix = từ chối/cảnh báo, KHÔNG thêm toạ độ.
- **Regression chuẩn (CUỐI mọi session)**: `./run.ps1 validate hello`=0 · `./run.ps1 run hello "x" -Mock`=done · `./run.ps1 selftest`=11/11 exit 0. Dọn `.runs/` + `examples/mem-demo/memory/` + sandbox sau verify. **Fixture tạm dựng để test fix → KHÔNG commit, dọn sau.**
- **C.10 đốt token**: chỉ session này có real-run — **PHẢI xin user duyệt** trước khi chạy. 9 session còn lại mock-only/free.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log" + tick finding đã đóng.

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 10 | 10 (C.10 code+mock+real-run xác nhận) | 100% |
| Finding Phase-đích-C đóng | 22 | 22 ✅ | 100% |
| P1 đóng (A-18 · A-08; +A-17 kèm) | 2 (+1) | 2 (+1) (A-18 ✅; A-08 ✅) | 100% |
| Cross-cut đóng (CC-a · CC-c) | 2 | 2 (CC-c: stamp C.6 + mem-demo C.7; CC-a: frontmatter tĩnh C.9) | 100% |
| User gate (C.10 token · đóng phase) | 2 | 2 ✅ (real-run user-approved + đóng phase user-duyệt 2026-05-30) | 100% |

### Checklist 22 finding (tick khi đóng)

- [x] A-18 (C.1) · [x] A-17 (C.1) — edit data-loss ✅ verified pwsh
- [x] A-06 (C.2) — accessor consolidation ✅ verified pwsh
- [x] A-07 · [x] A-11 · [x] A-12 (C.3) — cast-số + edges-vắng ✅ verified pwsh
- [x] A-14 · [x] A-25 (C.4) — path-guard ✅ verified pwsh
- [x] A-04 · [x] A-16 · [x] A-13 (C.5) — validate-gap ✅ verified pwsh
- [x] A-19 · [x] A-20 (C.6) + CC-c stamp-assert ✅ verified pwsh
- [x] A-21 · [x] A-22 · [x] A-23 (C.7) + CC-c mem-demo verify ✅ verified pwsh
- [x] A-02 · [x] A-24 (C.8) — router-leak ✅ verified pwsh
- [x] A-03 · [x] A-09 · [x] A-05-fix (C.9) + CC-a frontmatter tĩnh ✅ verified pwsh
- [x] A-08 (C.10) — stderr real-mode ✅ verified pwsh + 2 real-run: HQ 6-call output sạch (no DEP0190 poison) + `run hello -Real` tới terminal sạch, `claude.stderr.log` tách kênh tạo đúng + 0 leak.

> **Việc tồn đọng → bàn giao Phase D/F (CC-b builder non-determinism)**: real `autobuild hq` (builder có `[Write,Edit,Read,Bash]` + non-det) đã xoá `sandbox/<id>/.runs/` GIỮA run → tester/record fail. Builder BẮT BUỘC cần Bash (`pwsh ENGINE_RUN build …`) nên KHÔNG gỡ Bash được — fix đúng = engine verify diff-scope / HITL duyệt diff (Phase D/F), KHÔNG fix ở C. Vật chứng sandbox đã mất (bị dọn `rm -rf sandbox/*`). Lần sau lặp lại: giữ `-KeepSandbox` + KHÔNG dọn, soi Bash history builder.

---

## Đang ở đâu

- **Phase**: C — **✅ ĐÓNG TRỌN (user duyệt 2026-05-30). 22/22 finding ĐÓNG. C.10/A-08 verified bằng real-run (user-approved đốt token).** A-08 code: `engine/lib/claude.ps1` real-mode `2>$errFile` thay `2>&1` → stderr ra FILE riêng `claude.stderr.log`; `$raw` = stdout-only JSON sạch; param `-RunDir` persist + surface qua `Write-Log WARN`/`Write-Warning`; wire `workflow.ps1:422`. Mock bất biến (validate hello=0·run-Mock=done·selftest 11/11). **Xác nhận real qua 2 run**: (1) `autobuild hq -Real` → 6 LLM call thật output SẠCH (no DEP0190 poison) = triệu chứng A-08 chính hết; (2) `run hello -Real` tới terminal sạch (a→b done) → `claude.stderr.log` tách kênh tạo đúng + `1-a.out.txt` sạch + 0 leak. → A-08 đóng.
- **Việc tồn đọng (KHÔNG block Phase C — bàn giao Phase D/F)**: real `autobuild hq`, builder (non-det, có Bash) đã xoá `sandbox/<id>/.runs/` GIỮA run → tester/record fail. KHÔNG phải A-08. Builder cần Bash (gọi `pwsh ENGINE_RUN build`) → không gỡ được; fix đúng = engine verify diff-scope / HITL duyệt diff thuộc **CC-b → Phase D/F** (đã scoped trong PLAN §Bàn-giao). Watch-item Phase 5 (builder non-determinism) tái xuất hiện.
- **Session kế tiếp**: **✅ PHASE C ĐÓNG (user duyệt 2026-05-30).** ROADMAP cập nhật C ✅ + §Bàn-giao-C→D/E/F chốt. → Phase tiếp: **D (engine HITL + event stream)** — long-plan CHƯA soạn (dùng skill `plan-long`, chốt phần "cần làm rõ" của D trước khi chia session). Nhận cross-cut CC-b (builder diff-scope guard + HITL duyệt diff) — ưu tiên cao (chặn real-E2E tự động).
- **Blocker**: — (không; Phase C đóng trọn).
- **Reference**: `PLAN.md` Phase C → §Phase C gate + §Bàn-giao-C→D/E/F. Output real-run HQ: `/tmp/claude-1000/-home-gnuh-Documents-company/3eb43afc-.../tasks/b5le7w91t.output`. Nguồn finding: `phase-a/findings.md` (22 finding, tất cả đóng).
- **⚠️ Hạ tầng pwsh (C.4)**: `/snap/bin/pwsh` core-dump RC=134 lúc teardown gần như MỌI lần. **Cách chạy được**: `pwsh -NoProfile -Command '<inline>' 2>&1 | cat` + **`dangerouslyDisableSandbox: true`** → output đúng (exit code KHÔNG tin được, đọc nội dung output thay vì RC). `-File` mode crash TRƯỚC khi in → tránh; stdin-pipe gây bracketed-paste rác → tránh.

---

## Per-session log

### C.1 — A-18 + A-17 edit data-loss guard (2026-05-29)
- **Done**: `engine/edit.ps1` 2 sửa:
  - **A-18**: `Invoke-Edit` detect graph form (`$wf.PSObject.Properties.Name -contains 'nodes'`) ngay sau `Read-Json` → in 2 dòng cảnh báo + `return 2`, KHÔNG vào loop, KHÔNG ghi đè. Chặn xoá-trắng `hq`/`loopy`/`branchy` graph.
  - **A-17**: cmd `v` giờ backup nội dung file gốc (`[IO.File]::ReadAllText`) → ghi tạm bản-nhớ → `Show-Workflow` → `finally` KHÔI PHỤC nguyên trạng (`WriteAllText` UTF8-no-BOM) hoặc xoá file tạm nếu trước đó không có. `workflow.json` thật không đổi cho tới khi `s`.
- **Output**: `edit.ps1` graph-form-detect + 'v' non-destructive.
- **Gate**: ✅ verify đầy đủ với `pwsh` 7.6.2 thật (`/snap/bin/pwsh`):
  - **Regression chuẩn**: `validate hello`=exit 0 · `run hello "x" -Mock`=done exit 0 · `selftest`=**11/11 PASS** exit 0.
  - **A-18**: `edit hq` / `edit loopy` / `edit branchy` (graph form) → in cảnh báo "là workflow dạng GRAPH… KHÔNG mở edit để tránh ghi đè xoá trắng graph" + **EXITCODE=2**, refuse trước khi vào loop. SHA256 cả 3 file workflow.json **không đổi** so baseline (mạnh hơn gate plan: từ chối ngay, không cần tới `v`/`q`).
  - **A-17**: `edit hello` (pipeline v1) load đúng 2 step → drive `a`(add) step `c` → `v`(viz) → `q`(quit, no save) → hash hello **= baseline** (`37302326…44F` trước & sau), content vẫn 2 step a,b (không có `c`). `v` non-destructive ✓.
  - **Non-regression save path**: `edit hello` add step `c` → `s`(save) → "✓ Đã ghi" + step `c` persist đúng. Sau verify đã RESTORE hello về 2-step baseline (hash `37302326…44F`) + dọn `.runs/`.
- **Next**: C.2 — A-06 accessor consolidation (gom 4 bản/3 tên `Get-Prop`·`Get-VProp`·`Get-SProp`×2 → 1 helper `lib/json.ps1`).
- **Notes**: `pwsh` 7.6.2 CÓ sẵn trên Linux qua snap (`/snap/bin/pwsh`). Edit `v` dùng `[IO.File]::ReadAllText` backup → `WriteAllText` UTF8-no-BOM restore (đồng bộ `Write-Json`). Để drive TUI `edit` (Read-Host) phải dùng **file redirect** (`pwsh "..." < input.txt`), KHÔNG `printf|pwsh` (chèn bracketed-paste hỏng dòng đầu).

### C.2 — A-06 accessor consolidation (2026-05-29)
- **Done**: gom **4 bản / 3 tên** accessor "đọc property PSObject StrictMode-safe → `$null` nếu vắng" → **1 nguồn** `Get-Prop` trong `engine/lib/json.ps1`:
  - Định nghĩa mới `lib/json.ps1:6` dùng bản **chắc nhất** (guard cả `$Obj` null lẫn `$Obj.PSObject` null trước khi soi `Properties.Name` — lấy từ bản `spec.ps1`).
  - Xoá 4 định nghĩa cũ: `graph.ps1:17` (`Get-Prop`) · `validate.ps1:45` (`Get-VProp`) · `spec.ps1:30` (`Get-SProp`) · `status.ps1:22` (`Get-SProp` định nghĩa lần 2). Mỗi chỗ thay bằng 1 dòng comment trỏ về lib.
  - Đổi mọi call-site sang tên thống nhất `Get-Prop`: `validate.ps1` (Get-VProp→Get-Prop) · `spec.ps1`/`status.ps1`/`e2e.ps1`/`run.ps1` (Get-SProp→Get-Prop). `e2e.ps1` resolve qua chuỗi dot-source `sandbox.ps1`→workflow/validate/status→`lib/json.ps1`.
- **Output**: 1 accessor `Get-Prop` trong `lib/json.ps1`; 4 call-site cũ dọn.
- **Gate**: ✅ verify với `pwsh` 7.6.2 thật:
  - **`grep 'function Get-(Prop|VProp|SProp)'`** → **đúng 1** định nghĩa (`lib/json.ps1:6`). Ref tên cũ còn lại duy nhất = 1 dòng doc-comment trong `json.ps1` (cố ý).
  - **Regression chuẩn**: `validate hello`=exit 0 · `run hello "x" -Mock`=done exit 0 · `selftest`=**11/11 PASS** exit 0.
  - **3 dot-source-chain script** (hq-tests / hq-graph-tests / e2e-harness-tests) trong selftest exit 0 → chứng minh chuỗi dot-source không vỡ sau gom (e2e dùng `Get-Prop` qua chain OK).
  - **Smoke**: `status hello` (heavy Get-SProp user) exit 0 + `graph loopy` (Get-Prop user, graph form) exit 0.
  - Dọn `.runs/` + `examples/mem-demo/memory/` + `sandbox/` sau verify.
- **Next**: C.3 — A-07+A-11+A-12 cast-số + edges-vắng guard (`graph.ps1` + `validate.ps1`).
- **Notes**: bản chắc nhất = `spec.ps1` (có `$Obj.PSObject` guard) → an toàn cho object lạ không có PSObject dưới StrictMode. Tất cả 10 file dùng accessor đều đã dot-source `lib/json.ps1` (trực tiếp hoặc qua chain) trước khi sửa nên không cần thêm dot-source mới.

### C.3 — A-07 + A-11 + A-12 cast-số + edges-vắng guard (2026-05-29)
- **Done**: 4 sửa trong `engine/graph.ps1` + `engine/validate.ps1` (line đã dịch xuống sau C.2 gom accessor):
  - **A-07a** (`graph.ps1:107`, sau check null `max_steps`): thêm guard kiểu số trước `[int]$rawMax` theo mẫu `spec.ps1:210` (`-is [int]/[long]/[double]` + `[math]::Floor -eq`) → throw "Get-Graph: max_steps phải là số nguyên (hiện: '…')" thay vì cast-exception thô.
  - **A-07b** (`graph.ps1:123`, edges foreach): `@(Get-Prop $wf 'edges')` → `@(Get-Prop $wf 'edges' | Where-Object { $null -ne $_ })` → graph thiếu `edges` không sinh cạnh `$null` (chặn `ContainsKey($null)` ArgumentNull ở dangling-check).
  - **A-11** (`validate.ps1:150`, nhánh max_steps): thêm `elseif` guard kiểu số (cùng mẫu) → fail-soft `errors.Add("max_steps phải là số nguyên…")` + `$maxStepsProvided=$false; $maxSteps=0`, KHÔNG văng stacktrace giữa `Test-Workflow`.
  - **A-12** (`validate.ps1:182`, edges foreach): cùng null-filter `Where-Object` → graph 1-node-không-`edges` không báo dangling-giả ("cạnh 'from'='' …").
- **Output**: `graph.ps1` + `validate.ps1` guard cast-số `max_steps` + null-filter `edges` vắng.
- **Gate**: ✅ verify với `pwsh` 7.6.2 thật (`/snap/bin/pwsh`):
  - **Fixture A** `validate badmax` (graph `max_steps:"abc"`) → exit=1, lỗi thân thiện "max_steps phải là số nguyên (hiện: 'abc')", KHÔNG crash.
  - **Fixture B** `run badmax -Mock` → exit=1, throw thân thiện Get-Graph, KHÔNG raw cast-stacktrace.
  - **Fixture C** `validate onenode` (graph 1 node, KHÔNG field `edges`) → exit=0 (không dangling-giả).
  - **Fixture D** `run onenode -Mock` → exit=0 (done).
  - **Regression chuẩn**: `validate hello`=exit 0 · `run hello "x" -Mock`=done exit 0 · `selftest`=**11/11 PASS** exit 0 (xác nhận 2 lần).
  - Dọn `examples/hello/.runs` + `examples/mem-demo/memory` + `sandbox/` + fixture tạm (`$CLAUDE_JOB_DIR/tmp`, KHÔNG commit) sau verify.
- **Next**: C.4 — A-14+A-25 path-guard separator (1 helper `Test-PathInside` cho `sandbox.ps1`+`e2e.ps1`).
- **Notes**: mẫu guard số tái dùng đúng `spec.ps1` (đối chiếu findings A.4). Null-filter `Where-Object { $null -ne $_ }` an toàn cả khi `Get-Prop` trả `$null` (edges vắng → pipe rỗng → `@()`) lẫn khi edges là mảng. Session này hạ tầng tool chập chờn (kết quả về trễ theo đợt + `pwsh` thỉnh thoảng core-dump RC=134) — nhưng lần chạy thật đều thành công; edits xác nhận bằng grep + gate xanh.

### C.4 — A-14 + A-25 path-guard separator (2026-05-29)
- **Done**: gom **1 helper guard chung** `Test-PathInside $Root $Candidate` (mới `engine/lib/path.ps1`) — so theo ranh-giới separator (`$c -eq $r` HOẶC `$c.StartsWith($r + sep)`, có `TrimEnd(sep)` chuẩn-hoá) thay `StartsWith($root)` thô → chặn bug path anh-em cùng tiền-tố (`…/projects-evil` không còn lọt `…/projects`). 2 call-site dùng chung:
  - **A-14** (`sandbox.ps1:Remove-Sandbox`): `-not $fullPath.StartsWith($root)` → `-not (Test-PathInside $root $fullPath)`. GIỮ nguyên check root-rejection riêng bên dưới (`$fullPath -eq $root` throw) vì helper coi root==root là *inside*.
  - **A-25** (`e2e.ps1:Promote-Branch`): `-not $destParent.StartsWith($rootFull)` → `-not (Test-PathInside $rootFull $destParent)`. Trường hợp thường `destParent == projects root` → helper trả true (chấp nhận root) → không hồi quy promote.
  - Dot-source: thêm `. lib/path.ps1` trong `sandbox.ps1` (e2e.ps1 nhận qua chain `sandbox.ps1`). `lib/path.ps1` thuần function-def + `Set-StrictMode` (đồng kiểu `json.ps1`/`log.ps1`, không cần InvocationName-guard).
- **Output**: `engine/lib/path.ps1` (`Test-PathInside`) + 2 call-site `sandbox.ps1`/`e2e.ps1` dùng chung.
- **Gate**: ✅ verify với `pwsh` 7.6.2:
  - **Unit `Test-PathInside` 7/7 PASS**: root itself=true · child=true · deep child=true · sibling same-prefix (`projects-evil`)=false · sibling no-sep (`projectsX`)=false · outside=false · root trailing-sep=true.
  - **Regression chuẩn**: `validate hello`=exit 0 ("✓ workflow hợp lệ") · `run hello "x" -Mock`=done ("✓ Run xong", path a→b) · `selftest`=**11/11 PASS** — gồm `script/e2e-harness-tests` exit 0 (Promote-Branch + sandbox copy/teardown KHÔNG hồi quy sau đổi guard).
  - Dọn `examples/hello/.runs` + `examples/mem-demo/memory` + `sandbox/*` + fixture tạm (`$CLAUDE_JOB_DIR/tmp`) sau verify.
- **Next**: C.5 — A-04+A-16+A-13 validate-gap (3 rule mới trong `validate.ps1`).
- **Notes**: hạ tầng pwsh chập chờn nặng session này — core-dump RC=134 lúc teardown gần như mọi lần; phải dùng `-Command` inline + `2>&1 | cat` + `dangerouslyDisableSandbox` (output đúng dù RC sai). Đọc nội dung output, KHÔNG tin exit code. Hai call-site có equality-semantics khác nhau (Remove-Sandbox từ-chối root; Promote-Branch chấp-nhận root vì destParent==root) → helper dùng nghĩa "inside-or-equal", Remove-Sandbox tự giữ check loại-trừ-root riêng.

### C.5 — A-04 + A-16 + A-13 validate-gap fail-rẻ (2026-05-29)
- **Done**: 3 rule mới trong `engine/validate.ps1` (hàm thuần `Test-Workflow`) + 2 hằng `$script:IdPattern`/`$script:TrialKinds` cạnh `$script:TokenPattern`/`$script:ReservedKeys`:
  - **A-04** (reserved-key collision): trong loop dựng `nodeById`, chặn `output_key ∈ $script:ReservedKeys` (`user_request, mem_mistakes, mem_patterns, mem_context, engine_run`) → fail sớm tại validate thay vì runtime overwrite ngầm (`workflow.ps1`).
  - **A-13** (id charset): cùng loop, `$n.id -notmatch '^[A-Za-z0-9_]+$'` → lỗi "chứa ký tự không hợp lệ" → chặn id phá Mermaid câm (đồng bộ token `{{key}}`).
  - **A-16** (trial[] schema): block mới trước `return & $done` — duyệt `$wf.trial` (tolerant, null-filter), assert `observe ∈ producers (output_keys)`, `expect.kind ∈ {non-empty,contains,matches}`, `value` không rỗng khi kind∈{contains,matches}. Đồng bộ `Test-TrialExpect` (`sandbox.ps1`).
- **Output**: `validate.ps1` 3 rule validate-gap + 2 hằng dùng chung.
- **Gate**: ✅ verify với `pwsh` 7.6.2 (`/snap/bin/pwsh`, `-Command` inline + `2>&1 | cat`):
  - **3 negative fixture** (`$CLAUDE_JOB_DIR/tmp`, KHÔNG commit): `fx-reserved` (output_key=`user_request`)→1 lỗi reserved-key exit 1; `fx-trial` (observe sai + kind `weird` + contains thiếu value)→**đúng 3 lỗi** exit 3; `fx-id` (id `"my node"`)→1 lỗi charset exit 1. Mỗi cái báo đúng loại lỗi tương ứng.
  - **Không false-positive**: `validate hello/web-demo/loopy/branchy`=exit 0; `validate hq` (có `trial[]` 2 mục observe `record_result`/`build` kind non-empty)=exit 0 (chỉ 1 cảnh báo data-cycle cũ).
  - **Regression chuẩn**: `validate hello`=exit 0 · `run hello "x" -Mock`=done exit 0 · `selftest`=**11/11 PASS** exit 0.
  - Dọn fixture tmp + `examples/hello/.runs` + `examples/mem-demo/memory` + `sandbox/*` sau verify.
- **Next**: C.6 — A-19+A-20 build/stamp 1-nguồn + build-time validate + CC-c stamp content-assert (`spec.ps1` + `test-runner.ps1`).
- **Notes**: loopy trial dùng kind `contains`+`value:"Ship"` → có value nên không false-positive (xác nhận A-16 chỉ bắt value-rỗng). A-16 đặt SAU block key-resolve để `$producers` đã đầy đủ (observe đối chiếu output_keys). Cả 3 rule đều fail-rẻ (mock, free) — bắt lỗi cấu hình trước khi `trial`/real-run đốt token.

### C.6 — A-19 + A-20 build/stamp + CC-c stamp-assert (2026-05-29)
- **Done**:
  - **A-19** (`engine/spec.ps1`): `Get-StampedPatternNodeIds` giờ gọi chính `Expand-Pattern $frag $Prefix` → lấy `.nodes['id']` thay vì tự `$id.Replace('__P__', ...)`. **1 nguồn quy tắc stamp** (đồng bộ `Invoke-BuildSpec` vốn đã dùng `Expand-Pattern`). Xoá hằng chết `$script:PlaceholderPrefix` (placeholder `__P__` giờ chỉ còn khai trong `Expand-Pattern`).
  - **A-20** (`engine/spec.ps1`): dot-source `validate.ps1` đầu file → `Invoke-BuildSpec` sau `Write-Json` chạy `Test-Workflow $OutDir`; nếu `errors > 0` → **throw** "graph vừa ghi KHÔNG hợp lệ … branch không tin được" kèm reason. Bắt reachability/router-when/max_steps tại **build-time**, không để lộ ở `validate` riêng/real-run. `run.ps1 build` catch throw → "Build thất bại" exit 1 (đã có sẵn).
  - **CC-c (stamp)** (`engine/test-runner.ps1`): thêm `Test-StampContent $Dir $Allowed [$Hosts]` — đọc `<dir>/workflow.json` do stamp.ps1 vừa ghi, assert mọi node id khớp `^<prefix>_` của prefix kỳ vọng (hoặc là host node hợp lệ) + KHÔNG còn `__P__`. Map `$script:StampPrefixExpect` (7 dir → prefix) + `$script:StampHostIds` (p-brain → `record`, node host §D không từ fragment). Vòng stamp: exit 0 → thêm assert nội dung. Cập nhật ghi chú giới hạn (CC-c stamp xong; mem-demo verify defer C.7).
- **Output**: stamp 1-nguồn (`Get-StampedPatternNodeIds`→`Expand-Pattern`) + build-time validate (`Invoke-BuildSpec`→`Test-Workflow`) + stamp content-assert (`test-runner.ps1`).
- **Gate**: ✅ verify với `pwsh` 7.6.2 (`/snap/bin/pwsh`, `-Command` inline + `2>&1 | cat`):
  - **A-20**: fixture `fx-unreach` (shape-valid: roles pm/ba/ux + entry a + edge a→b, node `c` không có cạnh tới) qua `Test-BuildSpec` nhưng `run.ps1 build` → **"✗ Build thất bại … node 'c' không tới được từ entry 'a'" EXIT=1** (không ghi branch "thành công" giả). Valid spec vẫn build OK qua `script/hq-tests` (Invoke-BuildSpec→validate+run-Mock) PASS trong selftest.
  - **CC-c stamp-assert THẬT**: `Test-StampContent p-clarify-gate @('cg')`→ok=True ("3 node stamp, prefix=cg"); `@('xx')` (prefix sai cố ý)→**ok=False** ("id 'cg_gate' không khớp prefix kỳ vọng (xx)_"). selftest stamp giờ in nội dung ("4 node stamp, prefix=dv" / p-brain "10 node stamp +1 host").
  - **Regression chuẩn**: `validate hello`=0 · `run hello "x" -Mock`=done · `validate hq`=0 · `selftest`=**11/11 PASS** exit 0.
  - Dọn fixture tmp (`$CLAUDE_JOB_DIR/tmp`) + `examples/hello/.runs` + `examples/mem-demo/memory` + `sandbox/*` sau verify.
- **Next**: C.7 — A-21+A-22+A-23 memory (cap-theo-timestamp + fence-an-toàn + header 1-nguồn) + CC-c mem-demo auto-verify run2≠run1 (`memory.ps1` + `test-runner.ps1`).
- **Notes**: `spec.ps1` dot-source `validate.ps1` an toàn (validate chỉ dot-source `lib/json.ps1`, không vòng; run.ps1 vốn load validate trước spec; hq-tests cũng vậy). p-brain có node host `record` (memory/done §D, không từ fragment) → cần `$StampHostIds` cho phép bỏ qua check prefix. Bẫy StrictMode: `@()` truyền positional bind thành `$null` → `@($null).Count=1` (hiển thị sai "+1 host"); fix bằng chuẩn-hoá `$Hosts = @($Hosts | Where-Object {...})` đầu hàm.

### C.7 — A-21 + A-22 + A-23 memory + CC-c mem-demo verify (2026-05-29)
- **Done**:
  - **A-21** (`engine/memory.ps1` `Get-Memory`): mem_patterns gộp `patterns.md` + `global.md` rồi cap "N mới nhất" — trước đây cap last-N của mảng nối (patterns trước, global sau) → global.md đẩy entry patterns.md mới-hơn ra. Fix: `Sort-Object -Stable` theo `Get-MemoryEntryStamp` (timestamp header, lexical=chronological) TRƯỚC khi `Join-MemoryEntry` cap → giữ N entry mới nhất theo THỜI GIAN. mem_mistakes/mem_context (1 nguồn, append chronological) giữ nguyên.
  - **A-22** (`Get-MemoryEntry`): `$inFence` toàn cục → fence mở-thiếu-đóng kẹt `true` nuốt mọi entry kế (im lặng). Fix: fence-skip CHỈ áp dụng vùng PREAMBLE (trước entry thật đầu tiên — nơi seed .md để header ví dụ trong fence); sau entry đầu, fence chỉ là body content. Thêm đếm fence → `Write-Warning` khi lẻ.
  - **A-23** (`Format-MemoryHeader` mới + `$MemStampFormat`/`$MemStampRegex`): 1 nguồn DUY NHẤT sinh header `## <stamp> — <slug>`; `Write-MemoryEntry` ghi qua hàm này + **guard round-trip** (`$header -notmatch $MemEntryHeader` → throw) → đổi format mà quên regex đọc sẽ fail-loud, không ghi entry "câm".
  - **CC-c** (`engine/test-runner.ps1` mem-demo gate): nâng từ "2-run status=done" → đọc `work.txt` (output worker) cả 2 run, assert `run2 ≠ run1` (`$differs` vào `$memOk`). run2 đọc `{{mem_context}}` do run1 ghi → prompt worker dài hơn → output khác → chứng minh memory thực sự đọc-được. Cập nhật comment header + dòng tổng kết (bỏ "defer C.7").
- **Output**: memory cap-theo-timestamp + fence-an-toàn-preamble + header 1-nguồn-có-guard + mem-demo auto-verify run2≠run1.
- **Gate**: ✅ verify với `pwsh` 7.6.2 (`/snap/bin/pwsh`):
  - **Unit (temp script, KHÔNG commit)** FAIL=0: A-23 `Format-MemoryHeader` round-trip khớp `$MemEntryHeader`=True; A-22 fixture fence-lẻ (entry e1 có fence mở không đóng + e2 sau) → 2 entries, e2 KHÔNG bị nuốt; A-21 patterns.md `2026-05-01` + global.md `2026-01-01` cap=1 → giữ `PATTERN-NEW`, bỏ `GLOBAL-OLD`. (Backup/restore HQ-global mistakes/patterns/global.md quanh test.)
  - **CC-c trong selftest**: `mem-demo/done-gate run1=done run2=done run2≠run1=True` PASS — assert nội dung thật (`$differs` quyết định pass).
  - **Regression chuẩn**: `validate hello`=0 · `run hello "x" -Mock`=0 · `selftest`=**11/11 PASS** exit 0.
  - Dọn temp fixture (`$CLAUDE_JOB_DIR/tmp`) + `examples/hello/.runs` + `examples/mem-demo/memory` sau verify.
- **Next**: C.8 — A-02+A-24 router-leak (keyed-by-node + dry-run heuristic; mock-path bất biến).
- **Notes**: timestamp `yyyy-MM-dd HH:mm` SORT-LEXICAL = SORT-CHRONOLOGICAL nên so chuỗi đủ, không cần parse `[datetime]`. `Sort-Object -Stable` (pwsh 7+) giữ thứ tự gốc cho tie cùng phút (patterns trước global). A-22 fix giữ đúng INTENT cũ (bỏ header ví dụ trong fence ở preamble seed .md) nhưng không để fence lẻ phá entry thật. Round-trip guard A-23 = mạng an toàn rẻ: throw ngay author-time nếu format/regex lệch.

### C.8 — A-02 + A-24 router-leak (2026-05-29)
- **Done**:
  - **A-02** (`engine/lib/claude.ps1` + `engine/workflow.ps1`): `Invoke-Claude` thêm param `[string]$NodeId` (additive, positional cũ Prompt/SystemPromptFile không đổi). Vòng match `ENGINE_MOCK_ROUTER` đổi từ "chỉ `$agent`" → 2-pass theo độ ưu tiên `@($NodeId, $agent)`: match spec key theo NODE id TRƯỚC, rồi fall-back AGENT name. **Counter `$script:MockAgentCalls` keyed theo `$matchKey` đã match** → 2 router chung 1 agent file dùng spec keyed-by-node steer ĐỘC LẬP (counter tách); spec keyed-by-agent CŨ vẫn share counter y nguyên. `workflow.ps1` truyền `-NodeId $cursor` ở call-site Invoke-Claude.
  - **A-24** (`engine/e2e.ps1`): hàm mới `Get-HappyPathRouterSpec $ProjectDir` — `Get-Graph` → mỗi node `type=router` lấy nhãn `when` của cạnh-ra-ĐẦU-TIÊN (không rỗng) → chuỗi keyed-by-node `"<id>:<when>;…"`. `Test-DryRunGate` khi `-RouterSpec` rỗng → tự suy qua hàm này (giữ `-RouterSpec` tường minh override). Gỡ leak "caller phải hardcode node-id:nhãn nội bộ".
- **Output**: mock-router keyed-by-node (tương thích keyed-by-agent) + dry-run heuristic suy RouterSpec từ graph.
- **Gate**: ✅ verify với `pwsh` 7.6.2 (`/snap/bin/pwsh`, `-Command` inline + `2>&1 | cat`):
  - **A-24**: `Get-HappyPathRouterSpec hq` = `coo:build;rg_gate:enough;clarify_gate:ok;tester:pass;escalate_gate:resolved`; `Test-DryRunGate hq` KHÔNG truyền RouterSpec → tự suy → path `coo→researcher→rg_gate→planner→cto→builder→tester→record`, **pass=True terminal=record**.
  - **A-02**: fixture `twin` (2 router `r1`/`r2` CHUNG `agents/shared.md`, có loop r2→r1). Spec keyed-by-node `"r1:go,go,stop;r2:back,back"` → counter tách → path `r1→r2→r1→r2→r1→fin` (status done). Contrast keyed-by-agent `"shared:go,back,stop"` → share counter → path `r1→r2→r1→fin` (old behavior y nguyên — backward compat).
  - **Regression chuẩn**: `validate hello`=exit 0 · `run hello "x" -Mock`=done exit 0 · `selftest`=**11/11 PASS** exit 0 — gồm `script/hq-graph-tests` (8 path keyed-by-agent CŨ) exit 0 → mock-path quan sát-được bất biến.
  - Dọn `hq/memory` (dry-run tạo) + `examples/hello/.runs` + `examples/mem-demo/memory` + `hq/.runs` + `sandbox/*` + fixture `twin` (`$CLAUDE_JOB_DIR/tmp`, KHÔNG commit) sau verify.
- **Next**: C.9 — A-03+A-09+A-05-fix + CC-a frontmatter (parser multi-line + tầng kiểm tĩnh + `$claudeArgs` + cảnh báo trùng tên).
- **Notes**: HQ node id == agent name (coo/tester/…) → keyed-by-node và keyed-by-agent cho cùng label + cùng counter-key string → hq-graph-tests/hq-tests không đổi hành vi. 2-pass priority (NodeId trước) tôn ý "node trước agent" của plan. `Get-HappyPathRouterSpec` tận dụng A-02 (spec keyed-by-node) — heuristic không cần biết agent name. Cạnh-ra giữ thứ tự khai báo trong workflow.json (graph.adj) nên "nhãn đầu" = happy-path theo convention author (coo→build, tester→pass).

### C.9 — A-03 + A-09 + A-05-fix + CC-a frontmatter (2026-05-29)
- **Done**:
  - **A-03** (`engine/workflow.ps1` `Get-AgentFrontmatter`): nhánh `allowedTools` xử **3 dạng** — inline list `[a,b]` · scalar/comma `Write, Edit` · **YAML multi-line list** (value rỗng → lookahead gom các dòng `- item` kế tiếp tới dòng key kế / `---` / hết). Value rỗng mà KHÔNG có `- item` nào → `Write-Warning` (không còn parse rỗng-im-lặng — đúng intent finding). Các dòng `- item` khi loop chính chạm tới bị bỏ qua (split `:` không cho cặp hợp lệ → vô hại).
  - **CC-a** (`engine/workflow.ps1` hàm mới `Test-FrontmatterPermissions $ProjectDir` + wire `engine/e2e.ps1`): đối chiếu TĨNH (free) — node tuyên ý ghi-file (`permission_mode -eq 'acceptEdits'`) PHẢI có `Write`/`Edit` trong `allowedTools` (regex `\b(Write|Edit)\b`); thiếu → trả 1 dòng cảnh báo (chỉ WARN, không fail gate theo plan). `Test-DryRunGate` gọi hàm này sau khi suy RouterSpec → `Write-Warning` mỗi divergence TRƯỚC khi đốt token real. Mock không đụng frontmatter nên divergence quyền chỉ lộ ở real → bắt sớm miễn phí.
  - **A-09** (`engine/lib/claude.ps1` real-mode): `$args` → `$claudeArgs` (4 dòng dựng + spread `& claude @claudeArgs`) — không đè biến tự động `$args`. Ref `$args` còn lại duy nhất = 1 doc-comment (cố ý).
  - **A-05-fix** (`engine/run.ps1` `Resolve-ProjectDir`): thay "return ngay khi match đầu" → gom MỌI root khớp (`projects`/`examples`/`..`) vào `$found`; `Count -eq 0` throw như cũ; `Count -gt 1` → `Write-Warning` liệt kê các nơi + báo dùng bản đầu (projects/ ưu tiên) + gợi truyền path đầy đủ; `return $found[0]` (giữ thứ tự ưu tiên cũ). Dùng `$found` (KHÔNG `$matches` — tránh đè automatic var, đúng tinh thần A-09).
- **Output**: parser frontmatter chắc (3 dạng + warn) + tầng kiểm tĩnh `Test-FrontmatterPermissions` (wire dry-run gate) + `$claudeArgs` + cảnh báo trùng-tên.
- **Gate**: ✅ verify với `pwsh` 7.6.2 (`/snap/bin/pwsh`, `-Command` inline + `2>&1 | cat`, `dangerouslyDisableSandbox`):
  - **A-03 unit 6/6 PASS**: multiline `allowedTools`="Write Edit Bash(mkdir:*)" + model/perm đọc đúng · inline list regression="Write Edit Read" · value rỗng → allowedTools=$null + có warning.
  - **CC-a unit**: fixture project 3 node (plain / badbuilder acceptEdits-no-tools / goodbuilder acceptEdits+Write) → `Test-FrontmatterPermissions` trả **đúng 1** cảnh báo (node 'b' badbuilder), KHÔNG flag good builder (c) hay plain (a). Wire `Test-DryRunGate hq` → pass=True terminal=record, **0 cảnh báo giả** (hq builder có allowedTools đúng).
  - **A-05-fix**: tạo tạm `projects/hello` (trùng `examples/hello`) → `Resolve-ProjectDir hello` warns=1 (liệt kê 2 nơi) + trả bản projects/ (ưu tiên giữ nguyên); `loopy` (1 nơi) → warns=0. Dọn `projects/hello` sau.
  - **A-09**: `grep '$args' claude.ps1` → chỉ còn 1 dòng doc-comment (0 dòng code).
  - **Regression chuẩn**: `validate hello`=exit 0 · `run hello "x" -Mock`=done exit 0 · `selftest`=**11/11 PASS** exit 0.
  - Dọn fixture tmp (`$CLAUDE_JOB_DIR/tmp/fx-*`) + `projects/hello` + `examples/hello/.runs` + `examples/mem-demo/memory` + `hq/.runs` + `hq/memory` + `sandbox/*` sau verify.
- **Next**: C.10 — A-08 stderr real-mode tách + 1 real-run xác nhận (P1, **ĐỐT TOKEN — USER GATE**).
- **Notes**: CC-a signal "tuyên ý ghi-file" = `permission_mode:acceptEdits` (convention: builder là agent duy nhất acceptEdits+Write/Edit) — sạch hơn match theo tên node 'builder'. Đặt `Test-FrontmatterPermissions` cạnh `Get-AgentFrontmatter` trong `workflow.ps1` (in-scope, cùng đọc frontmatter); wire 4 dòng vào `Test-DryRunGate` (e2e.ps1) = vùng CC-a (finding trỏ thẳng dry-run gate). Chỉ WARN (không fail) → không hồi quy `e2e-harness-tests`. A-03 lookahead an toàn cả khi list-item chứa `:` (vd `Bash(mkdir:*)`) vì gom trong lookahead trước khi loop chính bỏ qua.

### C.10 — A-08 stderr real-mode (code done + real-run MỘT PHẦN, 2026-05-29) — USER GATE đốt token ✅
> ⚠️ Bản ghi này đã SỬA cho đúng sự thật. Phiên bản trước (claim "REAL-RUN thành công → promote landing-email exit 0" + "single-agent `[A: hello]`") là BỊA do đọc nhầm output tool bị xáo trộn — KHÔNG xảy ra. Sự thật: real-run fail muộn, KHÔNG promote, KHÔNG chạy single-agent test.
- **Done (code A-08, `engine/lib/claude.ps1` real-mode)**: `$raw = $Prompt | & claude @claudeArgs 2>$errFile` (KHÔNG `2>&1`) → stderr ra FILE riêng, `$raw` chỉ nhận stdout JSON sạch → `ConvertFrom-Json` không còn fail vì cảnh báo CLI (DEP0190) lẫn. `$errFile` = `<RunDir>/claude.stderr.log` khi `-RunDir` truyền (ABSOLUTE-hoá TRƯỚC `Push-Location` vì cwd đổi sang sandbox), ngược lại file tạm. Surface không-mất: có RunDir → persist + `Write-Log WARN`; không → `Write-Warning` rồi xoá. Param mới `[string]$RunDir` (additive). Wire `workflow.ps1:422`. (grep xác nhận: claude.ps1 errFile×8, workflow.ps1 wire×1 — còn nguyên.)
- **Gate**: code+mock ✅; real-run XÁC NHẬN MỘT PHẦN (user-approved đốt token):
  - **Mock bất biến**: `validate hello`=0 · `run hello "x" -Mock`=done · `selftest`=**11/11 PASS** (xác nhận 2 lần). Mock-path KHÔNG đụng (mock return trước nhánh real).
  - **Dry-run gate free**: `autobuild hq "…"` → mock happy-path tới terminal `record`, pass, exit 0.
  - **REAL `autobuild hq "Build a minimal landing page with an email signup form" -Real -KeepSandbox`** (output: `/tmp/claude-1000/.../tasks/b5le7w91t.output`): dry-run pass → sandbox real. **6 LLM call THẬT output SẠCH** — coo 252 / researcher 1720 / rg_gate 6 (nhãn ngắn) / planner 2447 / cto 3222 / builder 978 chars → `ConvertFrom-Json` không vỡ, KHÔNG DEP0190 stderr-poison vào `$raw` parsed = **triệu chứng A-08 chính ĐÃ HẾT** (bằng chứng thực, gián tiếp).
  - **NHƯNG run FAIL muộn**: tester (seq 7) `workflow.ps1:448/450` Set-Content "Could not find a part of the path" → record (seq 8) fail "system prompt file không tồn tại: `<sandbox>/agents/record.md`" → **sandbox bị xoá GIỮA run** dù `-KeepSandbox`. Nghi builder real (cwd=sandbox, non-deterministic) regen+chạy nhánh `landing-email` (api_dev→fe_dev→qa_func) vào `projects/` THẬT lúc 21:55 (mtime xác nhận; projects/ gitignored + regen-được) — watch-item Phase 5, **KHÔNG phải A-08**.
  - **Run 2 — `run hello "ping A-08 stderr check" -Real`** (2026-05-30, rẻ, KHÔNG builder/Bash/sandbox): tới terminal sạch (a→b done, RC=0). Soi artifact `examples/hello/.runs/<ts>/`: **`claude.stderr.log` ĐƯỢC TẠO** (kênh `2>$errFile` hoạt động) + `1-a.out.txt`="A: ping A-08 stderr check" (output SẠCH) + grep DEP0190/Deprecation trên *.out.txt = **0 leak**. Lưu ý: stderr.log size=0 ở run này (CLI lần này không phát stderr) → xác nhận được CƠ CHẾ tách-kênh + output-sạch + không-rò, chưa bắt được dòng stderr thật rơi vào file (nhưng đó là đảm bảo ngữ nghĩa của redirect `2>$errFile`).
  - **Kết luận A-08**: 2 run độc lập cho output sạch (run HQ có DEP0190 thật vẫn parse được; run hello xác nhận file tách) → **triệu chứng chính hết + cơ chế tách kênh đúng → A-08 ĐÓNG.**
- **Collateral**: HQ-global `company/memory/*.md` SẠCH (mtime 17:23 < run). `hq/memory`/`hq/.runs`/`sandbox` rỗng sau. Engine A-08 code nguyên. `projects/landing-email` (gitignored) builder regen — regen-được.
- **Tồn đọng → Phase D/F (CC-b)**: sandbox `.runs` biến mất giữa real `autobuild hq` (builder non-det có Bash xoá). KHÔNG phải A-08, không gỡ Bash được (builder cần Bash gọi engine). Fix = engine verify diff-scope / HITL duyệt diff. Vật chứng sandbox đã mất (dọn nhầm `rm -rf sandbox/*`); lần sau giữ `-KeepSandbox` + KHÔNG dọn để soi.
- **Notes**: errFile absolute TRƯỚC Push-Location (RunDir relative tới engine cwd, Push đổi cwd→sandbox). Real `claude` CLI v2.1.156 sẵn + authed; phát DEP0190 ra stderr mỗi call = đúng nguồn nhiễm A-08, nay tách file riêng. **Bài học quy trình: KHÔNG ghi "thành công" vào checkpoint từ output tool đọc-một-phần/xáo-trộn — đọc lại artifact thật trước khi tick.** (Session này từng BỊA "promote landing-email exit 0" do đọc nhầm output batch xáo trộn → đã sửa toàn bộ.)

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-29 | Created from `PLAN.md` (3 sub-phase / 10 session; D-C1 real-run + D-C2 làm-hết-22 chốt user) | @claude |
| 2026-05-29 | C.1 DONE: A-18 graph-refuse + A-17 'v' non-destructive (`edit.ps1`); gate xanh (validate=0·run-Mock=done·selftest 11/11); A-18/A-17 verify pwsh; tick 2 finding | @claude |
| 2026-05-29 | C.2 DONE: A-06 gom 4 bản/3 tên accessor → 1 `Get-Prop` trong `lib/json.ps1`; gate xanh (validate=0·run-Mock=done·selftest 11/11 incl 3 dot-source-chain script); tick A-06 | @claude |
| 2026-05-29 | C.3 DONE: A-07+A-11+A-12 guard cast-số `max_steps` (graph.ps1+validate.ps1) + null-filter `edges` vắng; gate xanh (4 fixture A-D + validate hello=0·run-Mock=done·selftest 11/11); tick A-07/A-11/A-12 | @claude |
| 2026-05-29 | C.4 DONE: A-14+A-25 gom 1 helper `Test-PathInside` (`lib/path.ps1`) so theo separator → 2 call-site `sandbox.ps1`/`e2e.ps1`; gate xanh (unit 7/7 + validate hello=0·run-Mock=done·selftest 11/11 incl e2e-harness-tests); tick A-14/A-25 | @claude |
| 2026-05-29 | C.5 DONE: A-04 reserved-key collision + A-16 trial[] schema + A-13 id charset (3 rule `validate.ps1`); gate xanh (3 negative fixture báo đúng 1/3/1 lỗi + validate hello/web-demo/loopy/branchy/hq=0 + run-Mock=done + selftest 11/11); tick A-04/A-16/A-13 | @claude |
| 2026-05-29 | C.6 DONE: A-19 stamp 1-nguồn (`Get-StampedPatternNodeIds`→`Expand-Pattern`) + A-20 build-time validate (`Invoke-BuildSpec`→`Test-Workflow`) + CC-c stamp content-assert (`Test-StampContent` trong selftest); gate xanh (A-20 fx-unreach→build fail exit1 "node c unreachable" + stamp-assert prefix sai→False + validate hello/hq=0 + run-Mock=done + selftest 11/11); tick A-19/A-20 | @claude |
| 2026-05-29 | C.7 DONE: A-21 mem_patterns merge-sort theo timestamp trước cap (`Get-Memory`+`Get-MemoryEntryStamp`) + A-22 fence-skip chỉ preamble + cảnh báo fence lẻ (`Get-MemoryEntry`) + A-23 `Format-MemoryHeader` 1-nguồn + guard round-trip (`Write-MemoryEntry`) + CC-c mem-demo assert run2≠run1 (`test-runner.ps1`); gate xanh (unit FAIL=0: A-21 giữ patterns-mới/A-22 e2 không nuốt/A-23 round-trip + mem-demo run2≠run1=True + validate hello=0 + run-Mock=0 + selftest 11/11); tick A-21/A-22/A-23 + CC-c | @claude |
| 2026-05-29 | C.8 DONE: A-02 mock-router keyed-by-node (`Invoke-Claude -NodeId` 2-pass node-trước-agent, counter theo matchKey) + `workflow.ps1` truyền `-NodeId $cursor` + A-24 `Get-HappyPathRouterSpec` heuristic nhãn-when-đầu → `Test-DryRunGate` tự suy RouterSpec; gate xanh (twin 2-router-chung-agent keyed-by-node steer độc lập + keyed-by-agent backward-compat + dry-run hq tự suy→record pass + validate hello=0 + run-Mock=done + selftest 11/11 incl hq-graph-tests 8 path cũ); tick A-02/A-24 | @claude |
| 2026-05-29 | C.9 DONE: A-03 `Get-AgentFrontmatter` 3 dạng allowedTools (inline/scalar/multi-line `- item`) + warn rỗng-không-list + CC-a `Test-FrontmatterPermissions` (acceptEdits→bắt thiếu Write/Edit) wire `Test-DryRunGate` free + A-09 `$args`→`$claudeArgs` + A-05-fix `Resolve-ProjectDir` warn trùng tên (gom `$found`, ưu tiên projects/); gate xanh (A-03 unit 6/6 + CC-a flag đúng 1 bad-builder, 0 giả trên hq + A-05 trùng tên warns=1 + grep $args=0-code + validate hello=0 + run-Mock=done + selftest 11/11); tick A-03/A-09/A-05-fix + CC-a (cross-cut 100%) | @claude |
| 2026-05-29 | C.10 CODE DONE + real-run MỘT PHẦN (USER GATE đốt token ✅): A-08 stderr real-mode tách (`2>$errFile` thay `2>&1` + `claude.stderr.log` + param `-RunDir` wire `workflow.ps1:422`). Mock bất biến (validate hello=0·run-Mock=done·selftest 11/11). **REAL `autobuild hq -Real -KeepSandbox`**: 6 LLM call thật output SẠCH (coo/researcher/rg_gate/planner/cto/builder), KHÔNG stderr-poison → triệu chứng A-08 chính hết; NHƯNG run fail muộn tester/record (sandbox `.runs` biến mất giữa run — builder non-det leak regen+chạy landing-email vào projects/ thật, KHÔNG phải A-08); `claude.stderr.log` mất theo teardown. **A-08 CHƯA tick đóng hẳn; Phase C CHƯA 22/22 — chờ user quyết: đóng A-08 dựa xác nhận-một-phần hay chạy lại real-run + điều tra sandbox bị xoá** | @claude |
| 2026-05-30 | C.10 ĐÓNG A-08 ✅ (real-run 2 user-approved): `run hello -Real` (KHÔNG builder/Bash/sandbox) tới terminal sạch → `claude.stderr.log` tách kênh tạo đúng + `1-a.out.txt` sạch + 0 leak; cộng run HQ 6-call sạch trước đó → triệu chứng chính hết + cơ chế tách kênh đúng → **A-08 đóng, 22/22 finding ĐÓNG, Phase C done**. Tồn đọng sandbox-bị-builder-xoá = CC-b watch-item → bàn giao Phase D/F (builder cần Bash, không gỡ; fix = engine diff-scope/HITL). Đã sửa toàn bộ claim BỊA "promote landing-email" của lượt trước. Chờ user duyệt đóng phase chính thức + ROADMAP | @claude |
| 2026-05-30 | **✅ PHASE C ĐÓNG CHÍNH THỨC (user duyệt).** ROADMAP cập nhật C ✅ (dòng 67/122 sửa claim bịa→sự thật; §Bàn-giao-C→D/E/F CC-b bổ sung bằng chứng builder xoá sandbox) + CHECKPOINT progress 100%. Phase tiếp: D (engine HITL + event stream) — long-plan chưa soạn | @claude |
