# findings.md — Phase A Audit (HQ improve)

> Nguồn chân lý cho mọi phase B+. Mỗi mục `§Findings` theo schema: Loại / File:line / Mô tả / Tác động / Mức (P0·P1·P2) / Đề xuất hướng / Phase đích.
> **Phase A là audit thuần đọc** — file này KHÔNG đề xuất sửa được thực hiện ở Phase A; sửa thuộc Phase B/C+.

Trạng thái: **A.5 — chốt, chờ user duyệt** (Baseline + Surface + 25 Findings + Cross-cut + Tổng hợp đầy đủ). 25 finding · 0 P0 · 3 P1.

---

## §Baseline (mock-only, 2026-05-28)

Tất cả chạy `pwsh -NoProfile` trên Linux (snap powershell 7.x), KHÔNG `-Real` (D-A3). Exit code thực tế ghi lại — **không sửa** dù fail.

### Test script

| Script | Exit | Kết quả |
| --- | --- | --- |
| `examples/hq-tests.ps1` | 0 | PASS — 5 test đơn lẻ agent HQ (COO 3 path / Planner / CTO / Builder Invoke-BuildSpec→validate+run-Mock / Tester memory+StructuralGate) |
| `examples/hq-graph-tests.ps1` | 0 | PASS — 8 path graph HQ (6 coverage + re-plan escalate soft + max_steps=40 backstop throw → state failed) |
| `examples/e2e-harness-tests.ps1` | 0 | PASS — round-trip + dry-run gate mock (dry-run-only pass / sandbox copy-teardown / Promote-Branch). 0 token |

### `run.ps1 validate` + `run … -Mock` (5 project)

| Project | validate | run -Mock | Ghi chú |
| --- | --- | --- | --- |
| `hello` | 0 | 0 | Pipeline tuyến tính 2 agent — done sạch |
| `web-demo` | 0 | 0 | Pipeline tuyến tính 11 vai — done sạch |
| `branchy` | 0 | **1** | **Kỳ vọng**: router `tier` echo `ping` → không khớp `when {gt10000,gt5000,gt1000,else}`. Cần `ENGINE_MOCK_ROUTER` để lái. |
| `loopy` | 0 | **1** | **Kỳ vọng**: router `verdict` echo `ping` → không khớp `{fail,pass}`. Cần router spec. |
| `hq` | 0 | **1** | **Kỳ vọng**: router `coo` echo `ping` → không khớp `{build,fix,unclear}`. HQ có nhiều router (coo, rg_gate, tester…) → plain `-Mock` luôn dừng ở router đầu. |

**Lưu ý baseline router**: plain `run … -Mock` chỉ done với pipeline tuyến tính (hello, web-demo). Mọi project mang router fail tại router đầu tiên vì mock echo `<request>` không khớp `when`. Các path router được cover đầy đủ qua `ENGINE_MOCK_ROUTER` đa-spec trong test script chuyên dụng (`hq-graph-tests.ps1` v.v.) — đều PASS. → Đây KHÔNG phải regression; là đặc tính mock. (Đáng cân nhắc finding doc/UX A-? : `run -Mock` không tự lái router → người mới tưởng vỡ.)

### mem-demo done-gate (chạy tay — không có runner)

Cách chạy: start sạch (xoá `memory/` nếu có) → `run mem-demo "demo" -Mock` 2 lần liên tiếp.

| Run | Exit | Quan sát |
| --- | --- | --- |
| run1 (memory rỗng) | 0 | node `record` `memory_write context` → tạo `memory/context.md` (1 entry date-stamped) |
| run2 (memory có) | 0 | worker đọc `{{mem_context}}` (output 150 chars), record append → `context.md` 2 entry |

PASS chức năng: ghi→đọc→append hoạt động. (Không có runner assert "output khác" tự động — chỉ kiểm tay; cân nhắc finding test-fragmentation A.4.) Đã dọn `memory/` sau verify (fixture start sạch).

### 7 `examples/p-*/stamp.ps1`

| Stamp | Exit | | Stamp | Exit |
| --- | --- | --- | --- | --- |
| `p-brain` | 0 | | `p-plan-decompose` | 0 |
| `p-clarify-gate` | 0 | | `p-re-plan-loop` | 0 |
| `p-do-verify-loop` | 0 | | `p-research-gather` | 0 |
| `p-escalate-gate` | 0 | | | |

Cả 7 stamp PASS (Expand-Pattern stamp fragment `__P__x` → explicit).

**Tổng baseline**: 3/3 test script PASS · 2/5 project done plain `-Mock` (3 router-project fail kỳ vọng) · mem-demo 2-run PASS · 7/7 stamp PASS. Dọn `.runs/` + `mem-demo/memory/` sau verify.

---

## §Surface — 12 lệnh `run.ps1` + nơi artifact

Nguồn: `engine/run.ps1` (dispatcher, `Invoke-Dispatch` L109–272). Cột phân loại: **HQ** = chạy graph `hq/` · **proj-con** = chạy chi nhánh trong `examples/`·`projects/` · **author/nội bộ** = công cụ tác-giả-time / build-time, không phải "chạy 1 project có sẵn".

| Lệnh | Cú pháp | HQ | proj-con | author/nội bộ | Module |
| --- | --- | :-: | :-: | :-: | --- |
| `run` | `run <proj> "<req>" [-Mock] [-Model]` | ✓ | ✓ | | `workflow.ps1 Invoke-Workflow` |
| `resume` | `resume <proj> [-Mock] [-Model]` | ✓ | ✓ | | `workflow.ps1 Invoke-Workflow -Resume` |
| `viz` | `viz <proj> [out.mmd]` | ✓ | ✓ | ✓ (render) | `viz.ps1 Show-Workflow/Export` |
| `validate` | `validate <proj>` | ✓ | ✓ | | `validate.ps1 Test-Workflow` |
| `check` | `check <proj>` | ✓ | ✓ | | `check.ps1 Test-StructuralGate` |
| `trial` | `trial <proj>` | ✓ | ✓ | | `sandbox.ps1 Invoke-TrialScaffold/Invoke-Trial` (tầng 2 THẬT đốt token) |
| `build` | `build <spec-file> [<outName>]` | | | ✓ (CTO build-spec→branch) | `spec.ps1 Invoke-BuildSpec` |
| `e2e` | `e2e <proj> "<req>" [-Router] [-Real]` | ✓ | ✓ | ✓ (harness real-run) | `e2e.ps1 Invoke-E2E` |
| `e2efix` | `e2efix <proj> "<req>" -Seed <br> -Branch <n> [-Router][-Real]` | ✓ | ✓ | ✓ (harness fix-loop) | `e2e.ps1 Invoke-E2EFix` |
| `status` | `status <proj>` | ✓ | ✓ | | `status.ps1 Show-Status` |
| `logs` | `logs <proj> [step]` | ✓ | ✓ | | `status.ps1 Show-Logs` |
| `edit` | `edit <proj>` | ✓ | ✓ | ✓ (TUI) | `edit.ps1 Invoke-Edit` |

(Ngoài 12 lệnh: `help`/`-h`/`--help` in Show-Help; command lạ → exit 2.)

### Resolve-ProjectDir (run.ps1 L62–78) — thứ tự tìm project
`<arg>` nguyên path → `../projects/<arg>` → `../examples/<arg>` → `../<arg>` (top-level, vd `hq`). Throw nếu không thấy. → Tên gọn trùng nhau giữa `projects/` và `examples/` sẽ ưu tiên `projects/` (cân nhắc finding A.2).

### 4 nơi artifact

| Dir | Nội dung | Vòng đời |
| --- | --- | --- |
| `<proj>/.runs/<runid>/` | Log + state (visits, status) + prompt/output mỗi lượt thăm. Per-project. | Sinh mỗi `run`/`resume`; gitignored; dọn sau test |
| `company/projects/<name>/` | App THẬT chi nhánh promote ra (E2E real). | `Promote-Branch` ghi; gitignored (`projects/*/`), regen-được |
| `company/sandbox/<runid>/` | Copy cô lập project cho tầng trial / E2E (chạy real → teardown). | `Copy-ToSandbox` tạo → `Remove-Sandbox` xoá; gitignored; rỗng khi rảnh |
| `company/` (gốc) | `hq/` · `examples/` · `catalog/` · `patterns/` · `memory/` (HQ-global store) · `engine/`. | Source committed (trừ artifact gitignored) |

---

## §Findings

### Cụm A.2 — executor core (graph / workflow / bridge / run / lib)

**Read ✓**: `graph.ps1` · `workflow.ps1` · `bridge.ps1` · `run.ps1` · `lib/json.ps1` · `lib/log.ps1` · `lib/claude.ps1`.
**Clean** (không finding): `lib/json.ps1` (Read/Write-Json guard file rỗng + JSON hỏng, depth 20 đủ) · `lib/log.ps1` (level threshold + file append guard dir; Level qua ValidateSet nên `$LogLevelOrder[$Level]` luôn có key) · `bridge.ps1` (Resolve-Prompt regex chặt, missing-key throw liệt kê rõ).

---

### A-01 — `run -Mock` không tự lái router → người mới tưởng engine vỡ
- **Loại**: doc/UX
- **File:line**: `engine/lib/claude.ps1:64–65` (mock echo `[MOCK:$agent]\n$Prompt`) + `engine/workflow.ps1:115–124` (router throw khi nhãn không khớp `when`)
- **Mô tả**: Plain `run <proj> "ping" -Mock` cho project có router: mock trả nguyên văn prompt → `ConvertTo-RouterLabel` ra nhãn rác → không khớp `when` nào → throw, exit≠0. Chỉ pipeline tuyến tính (hello, web-demo) done. Muốn đi qua router phải set `ENGINE_MOCK_ROUTER`.
- **Tác động**: branchy/loopy/hq fail ngay router đầu khi chạy `-Mock` trần (xác nhận ở §Baseline). Người mới không biết `ENGINE_MOCK_ROUTER` sẽ tưởng engine hỏng. Không phải regression — là đặc tính mock.
- **Mức**: P1
- **Đề xuất hướng**: README / `Show-Help` ghi rõ "mock không lái router; dùng `ENGINE_MOCK_ROUTER='coo:build;tester:pass'`"; hoặc thông báo lỗi router gợi ý đúng env khi đang ở mock-mode. KHÔNG thực hiện ở Phase A.
- **Phase đích**: B (CLI & docs)

### A-02 — ENGINE_MOCK_ROUTER khoá theo TÊN AGENT, không theo NODE id
- **Loại**: chắp-vá (leaky abstraction)
- **File:line**: `engine/lib/claude.ps1:34` (`$agent = GetFileNameWithoutExtension`) + `:51–62` (match spec theo `$agent`) + bộ đếm `$script:MockAgentCalls` keyed by `$agent`
- **Mô tả**: Spec router (`"<agent>:l1,l2"`) và bộ đếm vòng gọi đều keyed theo tên file agent, trong khi engine định tuyến theo NODE id (graph.adj). Hai node router khác nhau dùng CHUNG 1 file agent sẽ share counter → không steer độc lập được.
- **Tác động**: Hiện HQ các router dùng agent riêng (coo/rg_gate/tester/escalate_gate) nên chưa lộ. Nhưng là coupling ngầm: test-author phải biết "agent name" thay vì "node id" — lệch mô hình graph. Cản mở rộng (vd reuse 1 router agent ở nhiều node).
- **Mức**: P2
- **Đề xuất hướng**: cho phép spec keyed theo node id (hoặc cả hai), hoặc tài liệu hoá rõ "keyed by agent filename". KHÔNG thực hiện ở Phase A.
- **Phase đích**: C (fix + de-chắp-vá)

### A-03 — Get-AgentFrontmatter là YAML-parser tự chế (chỉ hiểu inline)
- **Loại**: chắp-vá
- **File:line**: `engine/workflow.ps1:130–178`
- **Mô tả**: Parser frontmatter chỉ hiểu `key: value` 1 dòng + inline list `[a, b]`. KHÔNG hỗ trợ YAML list nhiều dòng (`- item`), giá trị có dấu `:` phức tạp, comment `#`, hay quote. Field thiếu → `$null` (executor giữ hành vi cũ — an toàn).
- **Tác động**: Hiện 11 agent dùng inline list nên chạy đúng. Nhưng nếu ai sửa agent .md sang YAML list nhiều dòng (cú pháp YAML hợp lệ + phổ biến) thì `allowedTools` sẽ parse rỗng → mất quyền tool lúc real-run, không cảnh báo. Mock-path không đụng nên im lặng.
- **Mức**: P2
- **Đề xuất hướng**: hoặc tài liệu hoá ràng buộc "frontmatter chỉ inline" trong convention agent, hoặc mở rộng parser xử multi-line list. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-04 — Bảo vệ reserved-key không nhất quán (mem_* cảnh báo, user_request/engine_run im lặng)
- **Loại**: chắp-vá
- **File:line**: `engine/workflow.ps1:46–63` (Initialize-Context) + `:390–393` (runtime overwrite output_key)
- **Mô tả**: `engine_run` (L49) và `user_request` (L46) là reserved key nhưng nếu node đặt `output_key` trùng thì: pre-seed bỏ qua (giữ giá trị reserved) NHƯNG runtime L392 `$context[output_key]=output` vẫn ghi đè → token `{{user_request}}`/`{{engine_run}}` ở node sau nhận giá trị sai, không warning. Trái lại `mem_*` được cảnh báo lúc init (L57) — nhưng cũng KHÔNG được bảo vệ ở runtime L392.
- **Tác động**: Workflow lỡ đặt output_key trùng reserved-key → hỏng ngầm, khó debug. Hiếm xảy ra nhưng không có lưới an toàn đồng nhất; validate cũng chưa chặn (xác minh ở A.3).
- **Mức**: P2
- **Đề xuất hướng**: gom danh sách reserved-key (`user_request`, `engine_run`, `mem_*`) → validate.ps1 chặn output_key trùng (fail sớm) thay vì cảnh báo lẻ + overwrite ngầm. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-05 — Resolve-ProjectDir ưu tiên projects/ trước examples/ → trùng tên gọn bị che ngầm
- **Loại**: doc/UX
- **File:line**: `engine/run.ps1:62–78`
- **Mô tả**: Thứ tự tìm: path nguyên → `projects/<n>` → `examples/<n>` → `../<n>`. Tên gọn tồn tại ở cả 2 nơi → `projects/` thắng, im lặng. Sau khi E2E promote 1 branch (vd `broken-web` có cả fixture `examples/broken-web` lẫn promote `projects/broken-web`), `validate broken-web` / `run broken-web` sẽ trỏ bản promote, KHÔNG phải fixture committed.
- **Tác động**: Footgun cho người chạy lệnh bằng tên gọn sau khi đã promote — kiểm thử nhầm artifact. Không vỡ, nhưng dễ nhầm lẫn.
- **Mức**: P2
- **Đề xuất hướng**: tài liệu hoá thứ tự resolve (B); cân nhắc cảnh báo khi tên gọn match >1 root. KHÔNG thực hiện ở Phase A.
- **Phase đích**: B (doc) / C

### A-06 — Property-accessor trùng lặp 3 chỗ, 2 tên khác nhau
- **Loại**: chắp-vá
- **File:line**: `engine/graph.ps1:17` (`Get-Prop`) · `engine/spec.ps1:30` (`Get-SProp`) · `engine/status.ps1:22` (`Get-SProp` — định nghĩa LẦN 2)
- **Mô tả**: Cùng một helper "đọc property PSObject StrictMode-safe, trả $null nếu vắng" được định nghĩa 3 lần dưới 2 tên (`Get-Prop` vs `Get-SProp`), trong đó `Get-SProp` bị khai trùng ở spec.ps1 và status.ps1. (status.ps1/spec.ps1 đọc kỹ ở A.3/A.4 — ở đây chỉ ghi nhận trùng lặp.)
- **Tác động**: Trùng định nghĩa → khi dot-source nhiều module, bản nạp sau đè bản trước (cùng signature nên vô hại hiện tại) nhưng là nợ kỹ thuật, dễ phân kỳ khi sửa 1 chỗ quên chỗ khác.
- **Mức**: P2
- **Đề xuất hướng**: gom 1 helper dùng chung (vd vào `lib/json.ps1` hoặc `lib/util.ps1`) + xoá 2 bản còn lại. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-07 — Cast `[int]max_steps` + graph thiếu `edges` → crash thô (không thông báo thân thiện)
- **Loại**: bug
- **File:line**: `engine/graph.ps1:116` (`[int]$rawMax`) + `:129,155` (`@(Get-Prop $wf 'edges')` → `@($null)` khi vắng edges)
- **Mô tả**: (a) `max_steps` không phải số → `[int]$rawMax` ném cast-error thô thay vì lỗi Get-Graph rõ ràng. (b) Graph form KHÔNG khai `edges` → `@(Get-Prop ... 'edges')` thành mảng 1 phần tử `$null` → loop chạy 1 lần với `$e=$null` → L155 `$nodeById.ContainsKey($null)` ném ArgumentNull. Cả hai bỏ qua tầng "throw thông báo đẹp" mà Get-Graph cố cung cấp.
- **Tác động**: Edge case hiếm (graph 1 node không edge, hoặc max_steps gõ sai kiểu) nhưng vỡ với lỗi khó hiểu thay vì message hướng dẫn. Validate có thể bắt sớm hơn (kiểm ở A.3).
- **Mức**: P2
- **Đề xuất hướng**: guard `edges` vắng → `@()`; validate `max_steps` là số trước cast. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-08 — Real-mode trộn stderr vào stdout trước ConvertFrom-Json
- **Loại**: bug (real-path — cần real-run xác nhận, D-A3)
- **File:line**: `engine/lib/claude.ps1:82` (`$Prompt | & claude @args 2>&1`) + `:92–101`
- **Mô tả**: `2>&1` gộp stderr của claude CLI vào `$raw` rồi `ConvertFrom-Json`. Nếu claude in cảnh báo/log ra stderr, JSON parse fail → rơi vào catch → trả nguyên `$raw` (string thô lẫn cảnh báo) làm "output" của agent. Output bẩn này chảy vào context/file.
- **Tác động**: Chỉ ảnh hưởng real-run (mock không qua nhánh này). Có thể là nguồn của "builder non-determinism" watch-item Phase 5. Chưa xác nhận vì D-A3 không chạy real.
- **Mức**: P1
- **Đề xuất hướng**: tách stderr riêng (không `2>&1`), hoặc parse JSON từ stdout-only; ghi stderr vào log. Cần 1 real-run nhỏ để xác nhận giả thuyết. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C (kèm 1 real-run xác nhận)

### A-09 — Reassign biến tự động `$args` trong Invoke-Claude
- **Loại**: chắp-vá
- **File:line**: `engine/lib/claude.ps1:69` (`$args = @('-p', ...)`)
- **Mô tả**: Gán đè biến tự động `$args` của PowerShell bên trong hàm. Hàm dùng param block nên `$args` chỉ chứa arg thừa (rỗng) → vô hại, nhưng che biến builtin, dễ gây nhầm khi đọc.
- **Mức**: P2
- **Đề xuất hướng**: đổi tên `$claudeArgs`. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-10 — Flag thiếu giá trị (-Model/-Router/-Seed/-Branch) bị nuốt im lặng
- **Loại**: doc/UX
- **File:line**: `engine/run.ps1:99–102` (Split-DispatchArgs)
- **Mô tả**: `-Model` (và -Router/-Seed/-Branch) ở cuối args không có value: `$i++; if ($i -lt Count){...}` → guard đúng nhưng để giá trị `$null` im lặng, không báo "flag thiếu value".
- **Tác động**: User gõ `run hello "x" -Mock -Model` (quên tên model) → chạy như không có -Model, không cảnh báo → khó nhận ra. Minor.
- **Mức**: P2
- **Đề xuất hướng**: cảnh báo khi flag-có-value đứng cuối mà thiếu value. KHÔNG thực hiện ở Phase A.
- **Phase đích**: B (CLI & docs)

---

### Cụm A.3 — validate / viz / tester tier (validate / viz / check / sandbox / status / edit)

**Read ✓**: `validate.ps1` · `viz.ps1` · `check.ps1` · `sandbox.ps1` · `status.ps1` · `edit.ps1`.
**Clean** (không finding): `check.ps1` (Test-StructuralGate short-circuit đúng, reason máy-đọc-được, exit=số fail; router-fixture honor env không hardcode).
**Xác minh carry-over A.3**:
- **A-04 (reserved-key collision)** → **xác nhận đúng**: `validate.ps1` KHÔNG có check `output_key ∈ ReservedKeys`. `$producers` (L209–212) chỉ gom output_key, không đối chiếu `$script:ReservedKeys` (L30). Validate không chặn → A-04 giữ nguyên (Phase C nên thêm rule này vào validate).
- **A-06 (accessor trùng)** → **mở rộng**: ngoài `Get-Prop`/`Get-SProp`×2 đã ghi, còn **`Get-VProp` (validate.ps1:45)** là bản thứ **4** cùng hàm "đọc property PSObject StrictMode-safe". Tổng: 4 bản / 3 tên (`Get-Prop`·`Get-VProp`·`Get-SProp`×2). Khi gom helper (Phase C) nhớ gộp cả `Get-VProp`.
- **A-07 (max_steps/edges)** → lan sang validate: xem A-11, A-12 dưới.

### A-11 — validate cast `[int]max_steps` không guard → crash giữa chừng thay vì lỗi thân thiện
- **Loại**: bug
- **File:line**: `engine/validate.ps1:158` (`$maxSteps = [int]$rawMax`)
- **Mô tả**: `max_steps` không phải số (vd `"abc"`) → `[int]$rawMax` ném cast-error NGAY trong thân `Test-Workflow`, KHÔNG nằm trong try/catch nào (chỉ đoạn Read-Json L99–103 có catch). Validate — công cụ chuyên gom lỗi thân thiện — lại tự văng stacktrace thô. Đây là bản-sao validate của A-07 (graph.ps1:116).
- **Tác động**: Một workflow gõ sai kiểu `max_steps` không nhận được "max_steps phải là số" mà nhận cast-exception khó hiểu; lệnh `validate`/`check` (gọi Test-Workflow) crash thay vì exit=số-lỗi.
- **Mức**: P2
- **Đề xuất hướng**: kiểm `[int]::TryParse($rawMax)` trước cast; fail-soft thành `errors.Add("max_steps phải là số …")`. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-12 — validate: graph thiếu `edges` → phantom edge → lỗi dangling giả
- **Loại**: bug
- **File:line**: `engine/validate.ps1:184` (`foreach ($e in @(Get-VProp $wf 'edges'))`)
- **Mô tả**: Graph form KHÔNG khai field `edges` → `Get-VProp` trả `$null` → `@($null)` = mảng 1 phần tử `$null` → vòng lặp add 1 cạnh `{from=$null; to=$null; when=$null}`. Sau đó khối dangling-check (L224–230) báo 2 lỗi giả: "cạnh có 'from' không tồn tại: ''" + "...'to'...". → Graph 1-node hợp lệ (entry, không cạnh) FAIL validate sai. (Cùng gốc `@($null)` với A-07 graph.ps1:129,155, nhưng ở validate biểu hiện là lỗi-giả thay vì crash.)
- **Tác động**: Không cho phép graph tối giản không cạnh; thông báo lỗi sai lệch đánh lạc hướng. Hiếm (mọi graph thật đều có edges) nhưng là lỗi correctness của validator.
- **Mức**: P2
- **Đề xuất hướng**: guard `edges` vắng → `@()` (lọc `$null`) trước foreach; xét hợp lệ graph 1-node-không-cạnh. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-13 — node id không được validate charset; viz nhúng thẳng vào Mermaid (giả định an toàn)
- **Loại**: chắp-vá
- **File:line**: `engine/validate.ps1` (không có rule charset cho `id`) + `engine/viz.ps1:49,52` (`'{0}{{"{1}"}}' -f $n.id, …` / `'{0}["{1}"]'`)
- **Mô tả**: validate kiểm id-unique + trỏ-tồn-tại nhưng KHÔNG ràng buộc id chỉ `[A-Za-z0-9_]` (trong khi token `{{key}}` thì bị siết bởi `$TokenPattern`). viz.ps1 (comment L37 "Node id alphanumeric/_ → an toàn") nhúng id chưa-escape làm Mermaid node-id. id có space/dấu đặc biệt → Mermaid sinh ra cú pháp hỏng câm (chỉ vỡ khi render `.mmd`, engine không báo).
- **Tác động**: Footgun tác-giả-time: đặt id "my node" hay "a-b" → validate pass nhưng `.mmd` hỏng. Hiện mọi project dùng id sạch nên chưa lộ.
- **Mức**: P2
- **Đề xuất hướng**: thêm rule validate "id chỉ `[A-Za-z0-9_]`" (đồng bộ với token), hoặc viz sanitize/quote id. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-14 — Remove-Sandbox guard dùng `StartsWith($root)` không separator → path anh-em cùng tiền tố lọt
- **Loại**: chắp-vá
- **File:line**: `engine/sandbox.ps1:93` (`if (-not $fullPath.StartsWith($root))`)
- **Mô tả**: Guard chống xoá-ngoài-scope so khớp tiền tố chuỗi trần. `$root = …/company/sandbox`; một path anh em `…/company/sandbox-foo` cũng `StartsWith($root)` = true → guard KHÔNG chặn. Hiện vô hại vì `Copy-ToSandbox` luôn tạo dir bên TRONG root qua Join-Path (không sinh path anh em), nhưng guard không chặt như docstring "chỉ xoá nếu nằm TRONG sandbox/" tuyên bố.
- **Tác động**: Lưới an toàn yếu hơn quảng cáo; nếu sau này có caller truyền SandboxDir tuỳ ý thì guard rò. Rủi ro thấp hiện tại.
- **Mức**: P2
- **Đề xuất hướng**: so khớp `$fullPath.StartsWith($root + [IO.Path]::DirectorySeparatorChar)` (kèm case-sensitivity hợp lý). KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-15 — Log run-time chỉ in "(N chars)" → output thật không thấy ở console (phải `logs`)
- **Loại**: doc/UX
- **File:line**: `engine/workflow.ps1:412` (`Write-Log "[$seq] node '$cursor' → done ($($output.Length) chars)"`)
- **Mô tả**: Trong lúc `run`, mỗi node chỉ log số ký tự output, không thấy nội dung. Muốn xem prompt/output thật phải `run.ps1 logs <proj> [node]` (status.ps1 Show-Logs in đầy đủ từ `<seq>-<node>.out.txt`). status/logs hoạt động đúng — đây là vấn đề quan sát-được lúc chạy, không phải bug log trống.
- **Tác động**: Người mới chạy `run` thấy "(N chars)" tưởng output rỗng/không rõ engine làm gì; phải biết lệnh `logs` riêng. Cản observability — liên quan trực tiếp Phase E (app viewer / live-log).
- **Mức**: P2
- **Đề xuất hướng**: cờ verbose in trích đoạn output, hoặc tài liệu hoá "dùng `logs` để xem nội dung"; cấp app (E/F) stream output trực tiếp. KHÔNG thực hiện ở Phase A.
- **Phase đích**: E (app live-log) / B (doc)

### A-16 — validate bỏ qua schema `trial[]` → lỗi trial chỉ lộ lúc chạy THẬT (đốt token)
- **Loại**: chắp-vá
- **File:line**: `engine/validate.ps1` (không kiểm `trial`) + `engine/sandbox.ps1:102–131` (Get-Trials tolerant) + `:170–172` (Test-TrialExpect default-branch "kind không hỗ trợ")
- **Mô tả**: `trial[]` (plan-as-data, đầu vào C-3) cố ý bị validate/Get-Graph bỏ qua (allowlist field). Nhưng nghĩa là `observe` trỏ output_key không tồn tại, `expect.kind` sai (≠ non-empty/contains/matches), hay `value` thiếu cho contains/matches CHỈ bị phát hiện trong `Invoke-Trial` — sau khi đã chạy project THẬT (đốt token, non-deterministic).
- **Tác động**: Vi phạm nguyên tắc fail-rẻ: lỗi cấu hình trial đáng-bắt-tĩnh lại tốn 1 real-run mới lộ. Tác-giả trial gõ sai kind → burn token rồi mới biết.
- **Mức**: P2
- **Đề xuất hướng**: thêm validate (mock, free) cho trial[]: `observe ∈ output_keys`, `kind` hợp lệ, `value` bắt buộc khi contains/matches. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-17 — edit lệnh 'v' (viz) ghi đè workflow.json TRƯỚC khi 'save' — mâu thuẫn hợp đồng TUI
- **Loại**: bug
- **File:line**: `engine/edit.ps1:277–278` (cmd 'v': `Write-Json $wfPath $obj` trước Show-Workflow) vs docstring `:163` ("Mọi thao tác sửa trên bản nhớ; chỉ ghi đĩa khi chọn 's'")
- **Mô tả**: TUI hứa chỉ chạm đĩa khi chọn `s` (save), nhưng lệnh `v` (xem DAG) lại `Write-Json` toàn bộ pipeline-bản-nhớ ra `workflow.json` để Show-Workflow đọc lại. User thêm/xoá step → bấm `v` xem → bấm `q` (không save) → file ĐÃ bị ghi đè với thay đổi chưa-cam-kết.
- **Tác động**: Phá kỳ vọng "thoát không lưu = không đổi"; mất kiểm soát thay đổi. Kết hợp A-18 thành lỗi mất-dữ-liệu nặng trên project graph.
- **Mức**: P2
- **Đề xuất hướng**: Show-Workflow nên nhận graph in-memory (không cần file), hoặc 'v' ghi file tạm rồi khôi phục. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-18 — edit chỉ hiểu pipeline v1 → mở `edit` trên project GRAPH rồi save/viz XOÁ TRẮNG graph
- **Loại**: bug (mất dữ liệu)
- **File:line**: `engine/edit.ps1:181` (chỉ nạp field `pipeline`) + `:140–144` (Save-Workflow ghi `{name, pipeline}`) + `:277–278` (cmd 'v' cũng ghi)
- **Mô tả**: Invoke-Edit chỉ đọc `wf.pipeline`; với workflow.json dạng GRAPH (`nodes`/`edges`/router/when — vd `hq/`, `loopy`, `branchy`) thì `$pipeline` ở lại RỖNG (không có field 'pipeline'), `name` vẫn nạp. Bấm `s` (hoặc cả `v` — A-17) → Save-Workflow ghi đè `workflow.json` thành `{ name, pipeline: [] }` → toàn bộ nodes/edges/entry/max_steps/trial BIẾN MẤT. `edit hq` resolve `../hq` (file SOURCE committed) → một lần save/viz là xoá trắng graph HQ hand-authored.
- **Tác động**: Mất dữ liệu câm trên file nguồn được commit (hq/workflow.json + mọi project graph). Không cảnh báo, không backup. Đây là footgun nặng nhất cụm A.3.
- **Mức**: P1
- **Đề xuất hướng**: edit phải DETECT graph form (có `nodes`) → từ chối + cảnh báo "edit chỉ hỗ trợ pipeline v1; project này là graph, sửa tay/khác", hoặc nâng edit hiểu graph. Tối thiểu: không ghi đè khi không nạp được pipeline. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

---

### Cụm A.4 — HQ/E2E layer (spec / e2e / pattern / memory)

**Read ✓**: `spec.ps1` · `e2e.ps1` · `pattern.ps1` · `memory.ps1`.
**Clean** (không finding):
- `pattern.ps1` — `Expand-Pattern` stamp `__P__x`→`<prefix>_x` chỉ ở id/from/to, clone field khác verbatim; throw rõ khi fragment null / prefix rỗng / thiếu `nodes`; `Copy-ObjectWithOverrides` giữ thứ tự field. StrictMode-safe (ternary `?:` cần pwsh7 — đã là baseline). Author-time, runtime không load (đúng QĐ #2/C-1).

**Xác minh carry-over A.4**:
- **A-06 (accessor trùng)** → **chốt biên 4 bản / 3 tên**: `spec.ps1:30` `Get-SProp` đúng là bản thứ 4 đã đếm ở A.3 (cùng `Get-Prop`·`Get-VProp`·`status.ps1` `Get-SProp`). `e2e.ps1` **dùng lại** `Get-SProp` của `status.ps1` qua chuỗi dot-source (sandbox→…→status) — KHÔNG định nghĩa lại. `pattern.ps1`/`memory.ps1` KHÔNG nhân bản accessor. → A-06 giữ nguyên 4 bản/3 tên, không nở thêm.
- **A-03 (Get-AgentFrontmatter)** → e2e/spec KHÔNG tự parse frontmatter; real-run đi qua `Invoke-Workflow` (workflow.ps1) nên A-03 vẫn là điểm duy nhất. Liên quan §Cross-cut (a).
- **A-07/A-11 (cast số thô)** → **đối chiếu bản đúng**: `spec.ps1:217` (Test-BuildSpec `max_steps`) + `:131` (Test-PlanSchema `revision`) ĐÃ guard kiểu số đúng cách (`-is [int]/[long]/[double]` + so sánh) trước khi dùng. Đây là mẫu fail-soft mà `graph.ps1:116`/`validate.ps1:158` thiếu → Phase C gom theo mẫu spec.ps1.

### A-19 — Logic stamp pattern nhân đôi: Test-BuildSpec (String.Replace) vs Invoke-BuildSpec (Expand-Pattern)
- **Loại**: chắp-vá
- **File:line**: `engine/spec.ps1:92` (`Get-StampedPatternNodeIds`: `$id.Replace('__P__', $stamp)`) vs `engine/spec.ps1:434` + `engine/pattern.ps1:62–67` (Invoke-BuildSpec gọi `Expand-Pattern` dùng rewrite scriptblock)
- **Mô tả**: Cùng phép "stamp `__P__x`→`<prefix>_x`" được hiện thực hai lần bằng hai code-path khác nhau: validator (`Test-BuildSpec` → `Get-StampedPatternNodeIds`) tự `String.Replace` để biết tập node id, còn builder (`Invoke-BuildSpec`) gọi `Expand-Pattern`. Hiện cả hai cho kết quả giống nhau, nhưng nếu quy tắc stamp đổi (vd stamp thêm field, hoặc anchor placeholder) thì phải sửa 2 nơi — quên 1 nơi → validator chấp nhận spec mà builder sinh graph lệch (hoặc ngược lại).
- **Tác động**: Nợ kỹ thuật, dễ phân kỳ giữa "tập node id validator thấy" và "node id builder thực ghi". Cản mở rộng pattern.
- **Mức**: P2
- **Đề xuất hướng**: `Get-StampedPatternNodeIds` nên gọi chính `Expand-Pattern` (rồi lấy `.nodes.id`) thay vì tự Replace — 1 nguồn quy tắc stamp. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-20 — Invoke-BuildSpec ghi workflow.json KHÔNG chạy validate graph → lỗi graph lộ muộn
- **Loại**: chắp-vá
- **File:line**: `engine/spec.ps1:404–408` (chỉ gọi `Test-BuildSpec` shape) + `:458–467` (ghi `workflow.json` rồi return, KHÔNG gọi `Test-Workflow`)
- **Mô tả**: `Test-BuildSpec` chỉ kiểm SHAPE (field bắt buộc, id unique, role∈catalog, from/to∈node id) — KHÔNG kiểm tầng GRAPH: reachability từ entry, router có đủ cạnh `when`, `max_steps` đủ cho vòng, data-cycle. `Invoke-BuildSpec` ghi file xong return ngay, không chạy `Test-Workflow`. → build-spec hợp-lệ-shape vẫn sinh graph mà `validate` sẽ báo lỗi (vd node không reachable, router thiếu `when`). Lỗi chỉ lộ khi tác giả chạy `validate <branch>` riêng — hoặc tệ hơn, ở real-run.
- **Tác động**: `run.ps1 build` "thành công" nhưng branch có thể vỡ validate → người dùng tưởng build OK. Vi phạm tinh thần fail-sớm (validate là free/mock).
- **Mức**: P2
- **Đề xuất hướng**: `Invoke-BuildSpec` chạy `Test-Workflow` trên graph vừa ghi (hoặc lệnh `build` tự gọi `validate` sau khi ghi) → báo lỗi graph ngay tại build-time. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-21 — Get-Memory: cap `mem_patterns` gộp theo THỨ TỰ FILE, không theo thời gian → global.md đẩy patterns.md mới hơn ra
- **Loại**: bug (correctness nhẹ)
- **File:line**: `engine/memory.ps1:109` (`Join-MemoryEntry (@($patterns) + @($global)) $Cap`) + `:69–71` (cap = giữ N phần tử CUỐI mảng)
- **Mô tả**: `mem_patterns` = nối `patterns.md` rồi `global.md` thành 1 mảng, cap giữ N block cuối. Vì `global.md` luôn nối SAU, khi tổng > N thì các block bị evict luôn là của `patterns.md` (đầu mảng) — **kể cả khi entry patterns.md có timestamp mới hơn global.md**. Block KHÔNG được sort theo `## <date time>`; "giữ N mới nhất" (docstring `:91`, README) chỉ đúng trong-một-file, sai khi gộp 2 file.
- **Tác động**: Bài học `patterns.md` (HQ học pattern) mới ghi có thể biến mất khỏi prompt vì global.md (ít đổi) chiếm chỗ → memory nạp lệch, không phản ánh "N mới nhất" như cam kết. Hiện cap=10 và 2 file còn ít entry nên chưa lộ.
- **Mức**: P2
- **Đề xuất hướng**: parse timestamp header → merge-sort 2 nguồn theo thời gian rồi mới cap; hoặc cap riêng từng file trước khi gộp + tài liệu hoá. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-22 — Get-MemoryEntry: code-fence ``` không cân bằng nuốt trắng phần còn lại của file
- **Loại**: chắp-vá
- **File:line**: `engine/memory.ps1:44–47` (`$inFence = -not $inFence`; header trong fence không mở block)
- **Mô tả**: Cờ `$inFence` lật mỗi khi gặp dòng ``` (mục đích: bỏ qua entry-ví-dụ trong fence của seed .md). Nếu một entry có khối code fence MỞ mà thiếu fence ĐÓNG (markdown lỗi, hoặc fence lồng), `$inFence` kẹt `true` → mọi header `## <date>` sau đó bị coi là trong-fence → KHÔNG mở block → toàn bộ entry phía sau bị bỏ im lặng. Không cảnh báo.
- **Tác động**: 1 entry memory viết fence lỗi → "ăn" hết entry mới hơn → memory đọc thiếu, khó debug (im lặng). Rủi ro tăng theo thời gian khi memory tích nhiều entry tự do.
- **Mức**: P2
- **Đề xuất hướng**: chỉ skip-fence ở vùng header tài liệu đầu file (trước entry thật), hoặc dùng delimiter mạnh hơn (vd `---` HR) thay vì đếm fence toàn cục; cảnh báo khi fence lẻ. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-23 — Định dạng delimiter entry memory khai 2 nơi (read-regex vs write-format) → coupling ngầm
- **Loại**: chắp-vá
- **File:line**: `engine/memory.ps1:20` (`MemEntryHeader = '^##\s+\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\b'`) vs `:159–160` (write: `(Get-Date).ToString('yyyy-MM-dd HH:mm')` + `"## $stamp — $Slug"`)
- **Mô tả**: Hợp đồng round-trip "ghi rồi đọc lại được" phụ thuộc 2 hằng tách rời: regex đọc và format-string ghi phải khớp thủ công. Đổi format (vd thêm giây, đổi separator `—`) ở 1 nơi mà quên nơi kia → entry ghi ra không match regex đọc → Get-MemoryEntry bỏ qua entry mới (im lặng, như A-22).
- **Tác động**: Sửa format memory là thao tác mong manh; lỗi không lộ tới khi đọc thiếu. Hiện khớp đúng.
- **Mức**: P2
- **Đề xuất hướng**: gom format vào 1 hàm `Format-MemoryHeader`/hằng dùng chung cho cả ghi lẫn (sinh) regex; hoặc test round-trip tự động. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-24 — Test-DryRunGate đòi RouterSpec + caller phải hardcode node-id:nhãn nội bộ (leaky)
- **Loại**: chắp-vá (leaky abstraction)
- **File:line**: `engine/e2e.ps1:50` (`$RouterSpec` optional) + `:54–55` (set `ENGINE_MOCK_ROUTER=$RouterSpec`) + `:73–84` (fail nếu không tới `done`/terminal)
- **Mô tả**: Dry-run gate chạy `-Mock`, mà mock không tự lái router (A-01). Để gate xanh, caller PHẢI truyền `RouterSpec` đúng happy-path (vd `"coo:build;rg_gate:enough;tester:pass"`) — tức phải biết node-id router nội bộ + nhãn thắng của graph HQ. `RouterSpec` khai là optional nhưng thực tế bắt buộc với mọi graph có router; thiếu → gate luôn fail. Harness E2E do đó couple chặt với nội tại graph (kế thừa leak A-01 + keyed-by-agent A-02).
- **Tác động**: Không thể dry-run E2E một branch lạ mà không đọc graph để soạn RouterSpec tay; thay đổi node-id router làm vỡ mọi caller hardcode. Cản tự động hoá gate cho branch sinh động.
- **Mức**: P2
- **Đề xuất hướng**: hoặc suy RouterSpec happy-path từ graph (chọn nhãn `when` đầu mỗi router theo heuristic), hoặc tài liệu hoá rõ "RouterSpec bắt buộc cho graph có router" + đổi param thành Mandatory-có-điều-kiện. Liên quan A-01/A-02. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

### A-25 — Promote-Branch guard `StartsWith($rootFull)` thiếu separator (cùng lớp A-14)
- **Loại**: chắp-vá
- **File:line**: `engine/e2e.ps1:150` (`if (-not $destParent.StartsWith($rootFull))`)
- **Mô tả**: Guard chống path-traversal trong `$Name` so khớp tiền tố chuỗi trần `$destParent.StartsWith($rootFull)`. Bình thường `$destParent == $rootFull` nên qua. Nhưng nếu `$Name` chứa traversal trỏ tới thư mục anh-em chia tiền tố (vd root `…/projects`, một dir `…/projects-x`), `StartsWith` vẫn true → guard rò. Cùng lớp lỗi với A-14 (`Remove-Sandbox`): so tiền tố không kèm `DirectorySeparatorChar`.
- **Tác động**: Lưới an toàn yếu hơn quảng cáo "nằm TRONG projects root". Hiện caller chỉ truyền `$Name` sạch (Split-Path -Leaf hoặc `-Branch`), rủi ro thấp; nhưng là cùng pattern cần sửa đồng bộ.
- **Mức**: P2
- **Đề xuất hướng**: so `$destParent.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar) -or $destParent -eq $rootFull`; gom chung helper guard với A-14. KHÔNG thực hiện ở Phase A.
- **Phase đích**: C

---

## §Cross-cut

_(Chốt A.5 — 3 tiểu mục, mỗi mục có kết luận + finding liên đới + phase đích. Nối vào §Tổng hợp dưới.)_

### CC-a — Mock-path vs real-path divergence (suy từ code, KHÔNG real-run — D-A3)
- **Hiện tượng**: mock (`lib/claude.ps1 -Mock`, A.2) echo prompt và **bỏ qua hoàn toàn frontmatter** agent (`allowedTools`/`permission_mode`/`model` — wire ở workflow.ps1 5.1). Mock cũng không tự lái router (A-01). Hệ quả: mọi gate "mock" chỉ chứng minh **topology graph tới được terminal**, KHÔNG chứng minh agent thật có đủ quyền/tool để làm việc.
- **Bằng chứng**: `Test-DryRunGate` (e2e.ps1:35–93) chạy `-Mock` → kết luận "sẵn sàng real", nhưng builder thiếu `allowedTools:[Write,Edit]` vẫn pass dry-run (mock không ghi gì) rồi fail real (không ghi được file). `Invoke-BuildSpec` copy `catalog/<role>.md` verbatim (spec.ps1:421) — nếu vai catalog thiếu frontmatter quyền ghi thì lỗi chỉ lộ ở real. A-03 (parser frontmatter inline-only) + A-08 (real-mode `2>&1` trộn stderr vào JSON) là 2 điểm divergence cụ thể chỉ cắn ở real-path.
- **Kết luận**: dry-run gate là điều kiện CẦN (graph đúng) nhưng KHÔNG ĐỦ (quyền/tool/stderr). Đề xuất phase sau: thêm "tầng kiểm frontmatter tĩnh" (free) — đối chiếu node ghi-file có `allowedTools` Write — để bắt divergence trước khi đốt token. Liên quan A-03/A-08/A-16. Phase đích: C (+ 1 real-run xác nhận A-08).

### CC-b — Builder non-determinism (watch-item Phase 5)
- **Hiện tượng**: phần deterministic (Invoke-BuildSpec copy+stamp, spec.ps1:378–469) tách bạch với phần **non-deterministic** = agent `builder` LLM thật patch file ở fix-loop. Engine KHÔNG guard nội dung patch; chỉ prompt-harden (CHECKPOINT Phase 5 watch-item).
- **Bằng chứng**: `Invoke-E2EFix` (e2e.ps1:261–360) verify OUTCOME, không verify METHOD — assert `pre_fix validate FAIL` → `post_fix validate 0` + `file_changed` (hash đổi). Tức "builder có ghi và validate xanh" được chứng minh, nhưng "builder patch tối thiểu/đúng chỗ/không phá thứ khác" thì KHÔNG. `file_changed` chỉ so SHA256 `workflow.json`, không soi builder có đụng file ngoài phạm vi.
- **Kết luận**: non-determinism bị **chặn ở cổng verify** (validate deterministic) nhưng chưa bị **loại trừ**. Rủi ro còn lại: builder sửa đúng-validate-nhưng-sai-ý, hoặc đụng file khác trong sandbox. Đề xuất phase sau: verify chặt hơn (diff scope, chỉ cho đụng path khai báo) + HITL duyệt diff (Phase D/F). Phase đích: D (engine HITL) / F (app duyệt).

### CC-c — Test fragmentation (3 script + 7 stamp + mem-demo tay, không runner gom)
- **Hiện tượng**: test rải rác, không 1 surface chạy-tất-cả: 3 script tách (`hq-tests` / `hq-graph-tests` / `e2e-harness-tests`) + 7 `p-*/stamp.ps1` (chỉ in, không assert pass/fail máy-đọc) + mem-demo done-gate **chạy tay** (A.1 §Baseline — không runner). Một số module lõi A.4 **không có test tự động riêng**: `memory.ps1` (Get-Memory cap/fence A-21/A-22 chỉ gián tiếp qua mem-demo tay + Tester trong hq-tests); `pattern.ps1` (chỉ qua 7 stamp in-only + gián tiếp Invoke-BuildSpec).
- **Bằng chứng**: không có `run.ps1 test`/`examples/all-tests.ps1` gom exit code; CI/regression phải nhớ chạy ≥11 thứ tách rời. `stamp.ps1` exit 0 kể cả khi nội dung stamp sai (chỉ in JSON, không so kỳ vọng) — A.1 ghi "7/7 PASS" thực chất là "7/7 chạy không throw", không phải assert nội dung.
- **Kết luận**: thiếu một runner gom + thiếu assert-nội-dung cho stamp/memory → regression dễ lọt. Đề xuất phase sau: 1 lệnh `run.ps1 test [all]` chạy toàn bộ script + thêm assert cho stamp (so node/edge stamp kỳ vọng) + runner cho mem-demo (tự verify "output run2 khác run1"). Phase đích: B (CLI surface `test`) / C (bổ assert).

---

## §Tổng hợp

Chốt A.5 — 25 finding (A-01..A-25), tất cả có Mức + Phase đích. **0 mục P0** (không có gì CHẶN việc xây tiếp). Cao nhất là 3 mục P1.

### Đếm theo Mức

| Mức | Số | Finding |
| --- | --- | --- |
| P0 (chặn) | 0 | — |
| P1 (nên) | 3 | A-01 · A-08 · A-18 |
| P2 (nice) | 22 | A-02..07 · A-09..17 · A-19..25 |

### Đếm theo Loại

| Loại | Số | Finding |
| --- | --- | --- |
| bug | 7 | A-07 · A-08 · A-11 · A-12 · A-17 · A-18 · A-21 |
| chắp-vá | 14 | A-02 · A-03 · A-04 · A-06 · A-09 · A-13 · A-14 · A-16 · A-19 · A-20 · A-22 · A-23 · A-24 · A-25 |
| doc/UX | 4 | A-01 · A-05 · A-10 · A-15 |

### Đếm theo Phase đích

| Phase | Số (primary) | Finding |
| --- | --- | --- |
| B (CLI & docs) | 2 | A-01 · A-10 _(+ phần doc của A-05, A-15)_ |
| C (fix + de-chắp-vá) | 22 | A-02·03·04·05·06·07·08·09·11·12·13·14·16·17·18·19·20·21·22·23·24·25 |
| E (app live-log) | 1 | A-15 _(phần observability; phần doc thuộc B)_ |
| D / F (HITL + duyệt diff) | — | CC-b (cross-cut, không đánh số finding) |

Ghi chú split: **A-05** doc-thứ-tự-resolve → B, fix cảnh-báo-trùng-tên → C. **A-15** doc "dùng `logs`" → B, stream output trực tiếp → E.

### Danh sách P0

Không có. → Phase A KHÔNG chặn lộ trình; các phase B+ tiến hành theo thứ tự đề xuất dưới.

### 3 mục P1 (ưu tiên cao nhất)

| # | Finding | Vì sao P1 | Lưu ý xử lý |
| --- | --- | --- | --- |
| 1 | **A-18** edit save/viz xoá-trắng project graph | **Mất dữ liệu câm** trên file SOURCE committed (`hq/workflow.json` + mọi graph). Footgun nặng nhất. | Đi kèm A-17 (cùng vùng `edit.ps1`, cùng cơ chế ghi-trước-save). Phase C. |
| 2 | **A-08** real-mode `2>&1` trộn stderr vào JSON | Nghi là gốc "builder non-determinism" (watch-item Phase 5); output bẩn chảy vào context/file ở real-run. | **Cần 1 real-run nhỏ xác nhận** (D-A3 cấm real ở Phase A → để Phase C). Phase C. |
| 3 | **A-01** mock không tự lái router | Người mới chạy `-Mock` trần thấy fail → tưởng engine vỡ. Rẻ, doc-only. | Phase B (docs/help). Liên đới A-02/A-24 (cùng mô hình router-spec). |

### Thứ tự xử lý đề xuất

Nguyên tắc: (1) P1 trước; (2) gom theo *cụm sửa chung* để giảm churn (1 lần đụng nhiều finding cùng gốc); (3) ưu tiên việc fail-rẻ (validate/mock) trước việc cần real-run.

1. **A-18 + A-17** — chặn mất-dữ-liệu `edit` trên graph form. _(P1, C)_
2. **A-01** — doc mock-router + gợi ý `ENGINE_MOCK_ROUTER`. _(P1, B — rẻ, làm sớm)_
3. **A-08** — tách stderr real-mode + **1 real-run xác nhận** giả thuyết non-determinism. _(P1, C)_
4. **Cụm accessor**: A-06 — gom 4 bản/3 tên (`Get-Prop`·`Get-VProp`·`Get-SProp`×2) về 1 helper `lib`. Làm sớm vì đụng nhiều file, giảm churn về sau. _(P2, C)_
5. **Cụm cast-số**: A-07 · A-11 · A-12 — guard `[int]max_steps` + `edges` vắng, theo **mẫu đúng có sẵn** `spec.ps1:217`/`:131`. _(P2, C)_
6. **Cụm path-guard**: A-14 · A-25 — `StartsWith($root + sep)`, gom 1 helper guard. _(P2, C)_
7. **Cụm validate-gap (fail-rẻ)**: A-04 (reserved-key) · A-16 (schema trial[]) · A-13 (charset id) — thêm rule vào `validate.ps1` để bắt tĩnh trước khi đốt token. _(P2, C)_
8. **Cụm build/stamp**: A-19 (stamp nhân đôi) · A-20 (build không validate graph). _(P2, C)_
9. **Cụm memory**: A-21 (cap theo file-order) · A-22 (fence lẻ) · A-23 (delimiter 2 nơi). _(P2, C)_
10. **Cụm router-leak**: A-02 (keyed-by-agent) · A-24 (RouterSpec leaky). _(P2, C)_
11. **Lặt vặt C**: A-03 (frontmatter parser) · A-09 (`$args` reassign) · A-05-fix (cảnh báo trùng tên). _(P2, C)_
12. **Phase B docs còn lại**: A-10 (flag thiếu value) · A-05-doc · A-15-doc. _(P2, B)_
13. **Phase E**: A-15 — stream output trực tiếp (app live-log). _(P2, E)_

Cross-cut nuôi phase sau: **CC-a** (mock CẦN-không-ĐỦ → tầng kiểm frontmatter tĩnh, C) · **CC-b** (builder non-determinism → verify diff-scope + HITL, D/F) · **CC-c** (test fragmentation → `run.ps1 test [all]` + assert stamp/memory, B/C).

### Hệ quả cho ROADMAP

- **Phase C là khối lớn nhất** (22 finding) — phần lớn de-chắp-vá + bug nhỏ; nên chia sub-phase theo *cụm sửa chung* ở trên (accessor / cast-số / path-guard / validate-gap / memory / router-leak) thay vì theo file.
- **Phase B** (CLI & docs) gọn: A-01, A-10, phần doc A-05/A-15 + CC-c (`test` surface).
- **Phase D/E/F** nhận cross-cut (HITL, observability, app duyệt) — chưa có finding đánh số riêng ngoài A-15.
- **Không có P0** → ROADMAP không cần chèn việc-chặn trước khi tiếp tục.

---

### ✅ User gate (A.5 STOP)

_Chờ user duyệt: danh sách 25 finding + thứ tự xử lý 13 bước ở trên. Sau khi duyệt → ghi xác nhận vào `CHECKPOINT.md` + cập nhật `ROADMAP.md` (A ✅)._
