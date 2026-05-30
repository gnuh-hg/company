# PLAN — Phase C: Fix bug + de-chắp-vá refactor

> Sau toàn bộ Phase C: 22 finding Phase-đích-C trong `phase-a/findings.md` được đóng — bug sửa, chắp-vá thay bằng cơ chế sạch (1 accessor dùng chung, guard cast-số/path/validate-gap, memory đúng thứ tự, router-spec hết leaky, frontmatter chắc hơn) + A-08 real-mode stderr xác nhận bằng 1 real-run. Engine executor **vẫn giữ mock-path bất biến**; mọi regression cũ xanh; surface lệnh Phase B không hồi quy.

---

## Context

- **Vì sao chia nhiều session**: Phase C là **khối lớn nhất đợt improve** — 22 finding (`findings.md` §Đếm-theo-Phase: A-02·03·04·05·06·07·08·09·11·12·13·14·16·17·18·19·20·21·22·23·24·25), trải **10 file engine** (`graph/workflow/validate/viz/check/sandbox/status/edit/spec/e2e/pattern/memory/lib + run`). Gom 1 chat sẽ ẩu + churn cao. `findings.md` §Tổng-hợp đã chốt (user duyệt Phase A) **thứ tự 13 bước theo cụm sửa chung** — Phase C bám đúng cụm đó, mỗi session = 1 cụm có STOP gate đo được.
- **Quyết định đã chốt (user, 2026-05-29)**:
  - **D-C1. A-08 có real-run xác nhận**: Phase C có 1 session riêng (cuối) tách stderr real-mode + chạy **1 real-run nhỏ** xác nhận giả thuyết builder non-determinism. Session này **đốt token** — cần user bật đèn xanh khi tới (xem C.10).
  - **D-C2. Làm hết 22 finding**: de-chắp-vá trọn theo findings, gồm cả lặt-vặt cosmetic (A-09 `$args`, A-05-fix cảnh báo trùng tên, A-13 charset id). Không tỉa. Mục tiêu: engine sạch nhất trước Phase D (HITL).
- **De-risk đã xác nhận (findings + Phase B)**:
  - **Mẫu fix đúng đã có sẵn**: `spec.ps1:217`/`:131` guard cast-số đúng cách (`-is [int]/[long]/[double]`) — cụm cast-số (A-07/11/12) gom theo mẫu này, không phát minh lại.
  - **Test gọi hàm trực tiếp** (xác nhận Phase A.0/B.1): `examples/*-tests.ps1` + 7 `stamp.ps1` gọi `Invoke-Workflow`/`Test-StructuralGate`/`Invoke-E2E`… KHÔNG qua command-string → refactor nội bộ hàm KHÔNG vỡ test miễn signature giữ. `run.ps1 selftest` (Phase B) là **runner regression chuẩn** dùng mọi session.
  - **Accessor 4 bản/3 tên** (A-06) làm **sớm** (C.2) để giảm churn cho mọi session sau.
- **Ràng buộc bất biến (6 quy ước `company/CLAUDE.md`)** — đặc biệt với Phase C (đụng engine executor THẬT, khác Phase B chỉ dispatcher):
  - **#1 engine là code cố định**: sửa ở **hàm thuần testable** (`Get-Graph`/`Test-Workflow`/`Resolve-Prompt`/`Get-Memory`…), KHÔNG nhồi logic vào nhánh direct-run.
  - **#3 mock bất biến**: mọi thay đổi giữ `-Mock` + `ENGINE_MOCK_ROUTER` y nguyên hành vi quan sát-được (trừ A-02 **mở rộng** spec keyed-by-node-id = thêm khả năng, không phá cú pháp keyed-by-agent cũ; A-24 thêm heuristic = default mới khi thiếu RouterSpec, không đổi khi có).
  - **#2 workflow.json chỉ ngữ nghĩa**: A-18 fix = từ chối/cảnh báo trên graph form, KHÔNG thêm toạ độ.
  - **#5 dot-source-safe**: nếu thêm helper vào `lib/` (A-06, path-guard A-14/25) giữ guard `InvocationName`/`Line`.
  - **StrictMode -Version Latest**: guard `$null`/`.Count` (`@()`→`$null`).
- **Out of scope (bàn giao — xem §"Bàn giao sang D/E/F")**: HITL pause + event stream (CC-b verify diff-scope → D/F). Stream output trực tiếp lúc run (A-15 observability → E). App (E/F/G). Phase C **không** thêm node type mới, không đụng cơ chế resume.

---

## Pipeline 3 sub-phase / 10 session

```
[C-I — P1 + correctness core (fail-rẻ, mock-only)]
[C.1] A-18+A-17 edit data-loss guard (P1) ──────► edit.ps1 detect graph form → từ chối; 'v' không ghi đè
                                                      │
[C.2] A-06 accessor consolidation ──────────────► 1 helper lib (gộp 4 bản/3 tên) — làm sớm giảm churn
                                                      │
[C.3] A-07+A-11+A-12 cast-số guard ─────────────► graph.ps1/validate.ps1 guard max_steps + edges vắng
                                                      │
[C.4] A-14+A-25 path-guard ─────────────────────► StartsWith($root+sep) — helper guard chung
                                                      │
[C-II — de-chắp-vá clusters (fail-rẻ, mock-only)]
[C.5] A-04+A-16+A-13 validate-gap fail-rẻ ──────► validate rule: reserved-key + trial[] schema + id charset
                                                      │
[C.6] A-19+A-20 build/stamp + CC-c stamp ───────► stamp 1 nguồn (Expand-Pattern) + build chạy validate + assert stamp
                                                      │
[C.7] A-21+A-22+A-23 memory + CC-c mem-demo ────► cap theo timestamp + fence an toàn + format 1 nguồn + verify run2≠run1
                                                      │
[C.8] A-02+A-24 router-leak ────────────────────► spec keyed-by-node-id + heuristic suy RouterSpec từ graph
                                                      │
[C.9] A-03+A-09+A-05-fix + CC-a frontmatter ────► parser frontmatter chắc + $args rename + cảnh báo trùng-tên + tầng kiểm frontmatter tĩnh
                                                      │
[C-III — real-run confirm (token, USER GATE)]
[C.10] A-08 stderr + 1 real-run xác nhận (P1) ──► tách stderr real-mode + 1 real-run nhỏ + USER GATE đốt token
```

---

## Phase C — Fix bug + de-chắp-vá

**Mục tiêu**: đóng 22 finding Phase-đích-C; engine sạch + fail-rẻ (lỗi cấu hình bắt tĩnh trước khi đốt token); mock-path bất biến; regression xanh suốt. Mỗi session = 1 cụm; STOP gate gồm **regression chuẩn** (`validate hello`=0 · `run hello -Mock`=done · `run.ps1 selftest`=11/11 exit 0) + assertion riêng của cụm + **`git diff` không đụng vùng ngoài finding của session**.

> **Regression chuẩn (mọi session)**: sau khi sửa, chạy `./run.ps1 validate hello` (exit 0) + `./run.ps1 run hello "x" -Mock` (done) + `./run.ps1 selftest` (11/11 PASS, exit 0). Dọn `.runs/` + `examples/mem-demo/memory/` + sandbox sau verify.

### Sub-phase C-I — P1 + correctness core

#### Session C.1 — A-18 + A-17: edit data-loss guard (P1)
- **Scope** (`engine/edit.ps1`):
  - **A-18 (P1, mất dữ liệu)**: `Invoke-Edit` (L181) chỉ nạp `wf.pipeline`; mở `edit` trên project GRAPH (`nodes`/`edges` — `hq`/`loopy`/`branchy`) → save/viz ghi đè thành `{name, pipeline:[]}` → **xoá trắng graph**. Fix: **detect graph form** (có field `nodes`) → từ chối vào edit + in cảnh báo rõ ("edit chỉ hỗ trợ pipeline v1; project này là graph — sửa tay hoặc dùng `build`"); KHÔNG ghi đè. Tối thiểu-bất-biến: không bao giờ `Write-Json` khi không nạp được pipeline.
  - **A-17 (cùng vùng)**: cmd `v` (L277–278) `Write-Json` bản-nhớ ra đĩa TRƯỚC `Show-Workflow` → mâu thuẫn hợp đồng "chỉ ghi khi `s`". Fix: `Show-Workflow` đọc graph in-memory (không cần file), hoặc `v` ghi file tạm rồi khôi phục — không chạm `workflow.json` thật cho tới khi `s`.
- **STOP gate** (đo được):
  - SHA256 `hq/workflow.json` **không đổi** sau chuỗi `edit hq` → (thử thêm step) → `v` → `q` (không save).
  - `edit hello` (pipeline v1) vẫn vào edit + thao tác + save bình thường (không hồi quy).
  - `edit loopy`/`edit branchy` (graph) → từ chối + cảnh báo, file không đổi.
  - Regression chuẩn xanh.
- **Output artifact**: `edit.ps1` graph-form-detect + 'v' non-destructive.

#### Session C.2 — A-06: accessor consolidation (làm sớm — giảm churn)
- **Scope** (`engine/lib/` + `graph.ps1`/`validate.ps1`/`spec.ps1`/`status.ps1`):
  - Gom **4 bản / 3 tên** helper "đọc property PSObject StrictMode-safe → `$null` nếu vắng": `Get-Prop` (graph.ps1:17) · `Get-VProp` (validate.ps1:45) · `Get-SProp` (spec.ps1:30) · `Get-SProp` (status.ps1:22, định nghĩa lần 2). `e2e.ps1` dùng lại `Get-SProp` qua dot-source — sau khi gom phải vẫn resolve được.
  - Đưa **1 định nghĩa** vào `lib` (đề xuất `lib/json.ps1` — đã có sẵn + được dot-source rộng; chốt vị trí trong session). Xoá 4 bản kia, đổi mọi call-site sang 1 tên thống nhất (đề xuất `Get-Prop`). Giữ dot-source-safe (#5).
- **STOP gate**:
  - `grep -rn 'function Get-\(Prop\|VProp\|SProp\)'` → còn **đúng 1** định nghĩa.
  - Regression chuẩn xanh + 3 test script (`hq-tests`/`hq-graph-tests`/`e2e-harness-tests`) exit 0 (chứng minh chuỗi dot-source không vỡ).
- **Output artifact**: 1 accessor helper trong `lib`; 4 call-site cũ dọn.

#### Session C.3 — A-07 + A-11 + A-12: cast-số + edges-vắng guard
- **Scope** (`engine/graph.ps1` + `engine/validate.ps1`):
  - **A-07** (graph.ps1:116 `[int]$rawMax`; :129,155 `@(Get-Prop … 'edges')`→`@($null)`): guard `max_steps` là số trước cast (theo mẫu `spec.ps1:217`); guard `edges` vắng → `@()` (lọc `$null`) để graph 1-node-không-cạnh không crash.
  - **A-11** (validate.ps1:158 `[int]$rawMax`): `[int]::TryParse` trước cast → fail-soft `errors.Add("max_steps phải là số…")` thay vì văng stacktrace.
  - **A-12** (validate.ps1:184 `@(Get-VProp … 'edges')`): guard edges vắng → `@()` để graph 1-node hợp lệ không báo dangling-giả.
- **STOP gate**:
  - Fixture tạm graph `max_steps:"abc"` → `validate` trả lỗi-thân-thiện (không crash), exit≠0; `run` không văng stacktrace thô.
  - Fixture tạm graph 1-node-không-`edges` → `validate` exit 0 (không dangling-giả) + `run -Mock` done.
  - Regression chuẩn xanh. (Fixture tạm dọn sau verify — KHÔNG commit.)
- **Output artifact**: `graph.ps1` + `validate.ps1` guard cast-số + edges-vắng.

#### Session C.4 — A-14 + A-25: path-guard separator
- **Scope** (`engine/sandbox.ps1` + `engine/e2e.ps1`):
  - **A-14** (sandbox.ps1:93 `StartsWith($root)`): path anh-em `…/sandbox-foo` lọt guard. Fix: `StartsWith($root + [IO.Path]::DirectorySeparatorChar) -or -eq $root`.
  - **A-25** (e2e.ps1:150 `StartsWith($rootFull)` Promote-Branch): cùng lớp lỗi. Fix đồng bộ.
  - Gom **1 helper guard chung** (vd `Test-PathInside $root $candidate` trong `lib`) cho cả 2 call-site — 1 nguồn quy tắc.
- **STOP gate**:
  - Unit kiểm: `Test-PathInside` reject path anh-em-cùng-tiền-tố, accept path con thật + chính root.
  - `e2e-harness-tests.ps1` exit 0 (Promote-Branch + sandbox copy/teardown không hồi quy).
  - Regression chuẩn xanh.
- **Output artifact**: 1 helper path-guard + 2 call-site dùng chung.

### Sub-phase C-II — de-chắp-vá clusters

#### Session C.5 — A-04 + A-16 + A-13: validate-gap (fail-rẻ)
- **Scope** (`engine/validate.ps1`):
  - **A-04** (reserved-key collision): thêm rule chặn `output_key ∈ {user_request, engine_run, mem_*}` (gom từ `$script:ReservedKeys` L30) — fail sớm thay vì overwrite ngầm runtime (workflow.ps1:392).
  - **A-16** (trial[] schema): validate (mock, free) cho `trial[]`: `observe ∈ output_keys`, `expect.kind ∈ {non-empty, contains, matches}`, `value` bắt buộc khi contains/matches. Bắt tĩnh trước khi `trial` đốt token real.
  - **A-13** (id charset): rule "node `id` chỉ `[A-Za-z0-9_]`" (đồng bộ `$TokenPattern`) → chặn id phá Mermaid câm.
- **STOP gate**:
  - 3 negative fixture tạm (output_key=`user_request` / trial `kind` sai / id="my node") → `validate` mỗi cái báo đúng lỗi tương ứng, exit≠0.
  - `validate hello`/`web-demo`/`loopy`/`branchy`/`hq` vẫn exit 0 (không false-positive trên project thật) — incl. `hq` có `trial[]` cấu trúc.
  - Regression chuẩn xanh. (Fixture tạm dọn.)
- **Output artifact**: 3 validate rule mới + reserved-key list dùng chung.

#### Session C.6 — A-19 + A-20: build/stamp + CC-c stamp assert
- **Scope** (`engine/spec.ps1` + assert trong `engine/test-runner.ps1` cho stamp):
  - **A-19** (stamp nhân đôi): `Get-StampedPatternNodeIds` (spec.ps1:92, tự `String.Replace`) → gọi chính `Expand-Pattern` rồi lấy `.nodes.id` → 1 nguồn quy tắc stamp (đồng bộ Invoke-BuildSpec).
  - **A-20** (build không validate graph): `Invoke-BuildSpec` (spec.ps1:458) sau khi ghi `workflow.json` → chạy `Test-Workflow` trên graph vừa ghi → báo lỗi graph (reachability/router-when/max_steps) tại build-time, không để lộ ở `validate` riêng/real-run.
  - **CC-c (phần stamp)**: bổ assert nội dung cho 7 `p-*/stamp.ps1` trong `selftest` — so node/edge stamp kỳ vọng (không chỉ "chạy không throw"). (Giữ nhẹ: assert tập node-id stamp khớp `<prefix>_<x>`.)
- **STOP gate**:
  - Spec hợp-lệ-shape nhưng graph hỏng (vd node unreachable) → `run.ps1 build` báo lỗi graph ngay (exit≠0), KHÔNG ghi branch "thành công" giả.
  - `hq-tests.ps1` (Builder Invoke-BuildSpec→validate+run-Mock) exit 0.
  - `selftest` stamp-assert: đổi 1 stamp kỳ vọng sai → mục đó FAIL (chứng minh assert thật); revert → 11/11 PASS.
  - Regression chuẩn xanh.
- **Output artifact**: stamp 1-nguồn + build-time validate + stamp content-assert.

#### Session C.7 — A-21 + A-22 + A-23: memory + CC-c mem-demo verify
- **Scope** (`engine/memory.ps1` + verify trong `test-runner.ps1`):
  - **A-21** (cap theo file-order, bug): `mem_patterns` = `patterns.md` + `global.md` cap N block CUỐI → evict luôn patterns.md kể cả mới hơn. Fix: parse timestamp header → merge-sort 2 nguồn theo thời gian rồi mới cap (đúng "N mới nhất").
  - **A-22** (fence lẻ nuốt entry): `$inFence` toàn cục → fence MỞ thiếu ĐÓNG kẹt `true` → bỏ im mọi entry sau. Fix: chỉ skip-fence vùng header đầu file (trước entry thật), hoặc delimiter mạnh hơn; cảnh báo khi fence lẻ.
  - **A-23** (delimiter 2 nơi): regex đọc (memory.ps1:20) vs format ghi (:159) tách rời. Fix: gom `Format-MemoryHeader` + (sinh) regex 1 nguồn.
  - **CC-c (phần mem-demo)**: nâng verify mem-demo trong `selftest` từ "2-run exit 0" → **auto-verify run2 output KHÁC run1** (chứng minh đọc-memory-tránh-lặp thật).
- **STOP gate**:
  - Fixture tạm: patterns.md có entry mới hơn global.md, tổng>cap → `Get-Memory` GIỮ entry patterns.md mới (không bị global.md đẩy ra).
  - Fixture tạm fence-lẻ → `Get-Memory` không nuốt entry sau + có cảnh báo.
  - `selftest` mem-demo verify run2≠run1 PASS; cố tình làm run2=run1 → FAIL (assert thật).
  - Regression chuẩn xanh. (Fixture + `memory/` dọn sau verify.)
- **Output artifact**: memory cap-theo-timestamp + fence-an-toàn + header 1-nguồn + mem-demo auto-verify.

#### Session C.8 — A-02 + A-24: router-leak
- **Scope** (`engine/lib/claude.ps1` + `engine/e2e.ps1`):
  - **A-02** (ENGINE_MOCK_ROUTER keyed-by-agent): hiện spec + counter keyed `$agent` (file name), engine định tuyến theo NODE id → 2 node router chung 1 agent share counter. Fix: cho phép spec **keyed theo node id** (giữ keyed-by-agent cũ tương thích — thêm khả năng, không phá #3). Chốt cú pháp trong session (vd `node#id:label` vs `id:label` ưu tiên node trước agent).
  - **A-24** (Test-DryRunGate RouterSpec leaky): caller phải hardcode node-id:nhãn happy-path. Fix (theo §Bàn-giao-B→C): **heuristic suy RouterSpec happy-path từ graph** — chọn nhãn `when` đầu mỗi router → dry-run gate tự lái mà không cần caller khai tay. Giữ `-Router`/`RouterSpec` tường minh override khi truyền.
- **STOP gate**:
  - Mock test: 2 node router dùng chung 1 agent file, spec keyed-by-node → steer độc lập đúng (counter tách).
  - `Test-DryRunGate` trên `hq` KHÔNG truyền RouterSpec → tự suy happy-path → tới terminal (exit 0).
  - `hq-graph-tests.ps1` (8 path đa-spec) exit 0 — cú pháp keyed-by-agent CŨ vẫn chạy (tương thích).
  - Regression chuẩn xanh. **Mock-path quan sát-được bất biến** (test cũ không đổi kỳ vọng).
- **Output artifact**: spec keyed-by-node-id (tương thích cũ) + dry-run gate heuristic.

#### Session C.9 — A-03 + A-09 + A-05-fix + CC-a: frontmatter + lặt vặt
- **Scope** (`engine/workflow.ps1` + `engine/lib/claude.ps1` + `engine/run.ps1`):
  - **A-03** (Get-AgentFrontmatter inline-only, workflow.ps1:130–178): parser tự chế chỉ hiểu inline list → YAML multi-line `- item` parse rỗng → mất `allowedTools` lúc real-run im lặng. Fix: mở rộng parser xử multi-line list **hoặc** thu hẹp scope rõ ràng + cảnh báo khi gặp cú pháp không hỗ trợ. Chốt hướng trong session (ưu tiên cảnh-báo + multi-line tối thiểu).
  - **CC-a** (mock CẦN-không-ĐỦ): thêm **tầng kiểm frontmatter tĩnh** (free, mock-time) — đối chiếu node ghi-file (builder) PHẢI có `allowedTools` chứa Write/Edit → bắt divergence quyền trước khi đốt token. (Đặt cạnh A-03 vì cùng đọc frontmatter.)
  - **A-09** (`$args` reassign, claude.ps1:69): đổi tên `$claudeArgs` (che biến builtin).
  - **A-05-fix** (run.ps1:62–78 Resolve-ProjectDir): doc đã làm ở B; C thêm **cảnh báo runtime** khi tên gọn match >1 root (`projects/` + `examples/` cùng tên) → in warning chọn bản nào.
- **STOP gate**:
  - Agent .md fixture tạm dùng YAML multi-line `allowedTools` → parser hoặc đọc đúng hoặc cảnh báo rõ (không rỗng-im-lặng).
  - Tầng frontmatter tĩnh: fixture builder thiếu `allowedTools:Write` → cảnh báo trước real (mock-time, free).
  - Trùng tên (tạo tạm `projects/hello`) → lệnh báo warning match >1 root; dọn sau.
  - `grep '\$args' claude.ps1` → 0 (đã đổi tên).
  - Regression chuẩn xanh.
- **Output artifact**: parser frontmatter chắc + tầng kiểm tĩnh + `$claudeArgs` + cảnh báo trùng-tên.

### Sub-phase C-III — real-run confirm (token, USER GATE)

#### Session C.10 — A-08: real-mode stderr + 1 real-run xác nhận (P1)
- **Scope** (`engine/lib/claude.ps1:82,92–101`):
  - **A-08 (P1, bug real-path)**: `$Prompt | & claude @args 2>&1` gộp stderr vào `$raw` → `ConvertFrom-Json` fail → catch trả `$raw` thô (lẫn cảnh báo) làm "output" agent → bẩn context/file. Nghi là gốc builder non-determinism (watch-item Phase 5). Fix: tách stderr riêng (KHÔNG `2>&1`) hoặc parse JSON từ stdout-only; ghi stderr vào log.
  - **1 real-run nhỏ xác nhận** (D-C1, **ĐỐT TOKEN — USER GATE trước khi chạy**): chạy 1 real-run tối thiểu (vd `e2e` happy-path hoặc 1 agent đơn) trước+sau fix → xác nhận stderr không còn lẫn vào output. Ghi kết quả vào CHECKPOINT.
- **STOP gate**:
  - **Trước real-run**: trình bày lệnh + chi phí ước tính → **user duyệt đốt token**.
  - Sau fix: real-run nhỏ → output agent là JSON sạch (không lẫn stderr); stderr xuất hiện trong log riêng.
  - Mock-path KHÔNG đụng (mock không qua nhánh real `2>&1`) → regression chuẩn xanh.
- **Output artifact**: `claude.ps1` stderr-tách + ghi nhận real-run xác nhận trong CHECKPOINT.

**Phase C gate** (sau C.10): 22 finding Phase-đích-C đóng (đối chiếu checklist `findings.md`); engine fail-rẻ (cấu hình lỗi bắt tĩnh); mock-path bất biến (mọi test cũ xanh, kỳ vọng không đổi); surface lệnh Phase B không hồi quy; A-08 xác nhận bằng real-run; ROADMAP §Bàn-giao-C→D/E/F ghi đủ; **user duyệt** đóng phase. → cập nhật ROADMAP (C ✅).

---

## Bàn giao sang D / E / F (ghi vào ROADMAP cuối C.10)

> C *chạm* các vùng sau nhưng **phần sâu thuộc phase sau** (kiến trúc HITL/observability/app).

| Cross-cut | C làm gì | Phase sau phải làm tiếp |
| --- | --- | --- |
| **CC-a** mock CẦN-không-ĐỦ | Tầng kiểm frontmatter tĩnh (quyền ghi-file) free trước real | (đủ ở C nếu tầng tĩnh bắt được divergence quyền) |
| **CC-b** builder non-determinism | A-08 làm sạch input (stderr) — bớt 1 nguồn nhiễu | **verify diff-scope** (chỉ cho đụng path khai báo) + **HITL duyệt diff** → D (engine pause/event) / F (app duyệt) |
| **A-15** log "(N chars)" observability | (doc đã ở B) | **stream output trực tiếp** lúc run → E (app live-log) |

---

## Outcome cuối

- 22 finding Phase-đích-C đóng: 1 accessor dùng chung; guard cast-số + edges-vắng (graph+validate); 1 path-guard helper; validate fail-rẻ (reserved-key + trial schema + id charset); stamp 1-nguồn + build-time validate; memory cap-theo-timestamp + fence-an-toàn + header 1-nguồn; router-spec keyed-by-node + dry-run heuristic; frontmatter parser chắc + tầng kiểm tĩnh; edit từ-chối graph form (chống mất dữ liệu); A-08 stderr tách + real-run xác nhận; lặt-vặt ($args, cảnh báo trùng-tên).
- **0 thay đổi mock-path quan sát-được** — `-Mock`/`ENGINE_MOCK_ROUTER` cú pháp cũ chạy y nguyên (A-02/A-24 chỉ THÊM khả năng); mọi test cũ xanh, kỳ vọng không sửa.
- `run.ps1 selftest` mạnh hơn: +assert nội dung stamp +auto-verify mem-demo run2≠run1 (đóng nốt CC-c).
- `ROADMAP.md` §Bàn-giao-C→D/E/F đầy đủ; gate đo lường: 22 finding checklist + regression xanh + A-08 real-run + user duyệt.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-05-29 | Initial | Soạn long-plan Phase C từ `ROADMAP.md` §Phase C + §Bàn-giao-B→C + `phase-a/findings.md` §Tổng-hợp (13 bước / 22 finding cluster). Chốt D-C1 (A-08 real-run) + D-C2 (làm hết 22) — user 2026-05-29. 3 sub-phase / 10 session |
