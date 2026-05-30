# CHECKPOINT — Phase 2: Tester máy-kiểm-được + sandbox + fixture

> Sổ tay tiến độ dài hạn. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ được làm 1 session** (xem mục "Đang ở đâu" để biết session nào).
- **STOP NGAY** khi đạt STOP gate của session đó — không tham làm session kế tiếp dù còn quota.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry vào "Per-session log".
- **Quy ước bất biến #6**: chỉ thao tác trong `company/`; `leafnote/` + `examples/loopy` gốc + `examples/hello` gốc **CHỈ ĐỌC**. Mọi mutation negative-path làm trên **bản copy trong `sandbox/`**, không sửa file gốc.
- **#1**: logic Tester nằm trong `engine/*.ps1` — KHÔNG nhồi vào agent `.md`.
- **#4 Một surface lệnh**: Tester đi qua `run.ps1 <command> <project>` (`check` = tầng cấu trúc; `trial` = sandbox-real). KHÔNG tạo entry point khác.
- **#5 dot-source-safe + StrictMode**: module mới guard `InvocationName`/`Line` + hàm thuần testable; guard `$null`/`.Count`.
- **C-2**: tầng trial đo "ra sản phẩm chạy được", KHÔNG so schema cứng.
- Sau khi sửa engine: regression tối thiểu `./run.ps1 validate hello` + `./run.ps1 run hello "x" -Mock`. Dọn `.runs/` + `sandbox/` test sau verify.

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 4 | 4 | 100% ✅ |
| Tầng cấu trúc (`check`) | pass loopy+hello | ✅ exit 0 cả hai | 100% |
| Negative-path | ≥3 mutation fail đúng tầng | ✅ 3/3 đúng tầng + reason | 100% |
| Sandbox isolation | copy+teardown, gốc sạch | ✅ trial loopy: artifact trong sandbox/, gốc sạch, teardown | 100% |
| Tier trial THẬT | loopy real done + assert pass | ✅ run real done (7 visits, loop 1 vòng) + 2 assertion pass | 100% |

---

## Đang ở đâu

- **Phase**: 2 — ✅ **DONE** (4/4 session). Tester 2 tầng + sandbox harness + `trial[]` đã giao.
- **Session kế tiếp**: — (Phase 2 xong). Phase kế trong ROADMAP = **Phase M** (cơ chế trí nhớ) hoặc **Phase 3** (HQ agents) — soạn long-plan riêng khi bắt đầu.
- **Blocker**: —
- **Reference**: `PLAN.md` Outcome cuối (đã đạt đủ checklist).
- **Bàn giao cho phase sau**: `trial[]` định nghĩa = top-level field trong `workflow.json` (`[{ observe: "<output_key>", expect: { kind: non-empty|contains|matches, value? } }]`) — đầu vào C-3 cho CTO (Phase 3) sinh build-spec. `Invoke-Trial`/`Test-TrialExpect`/`Get-Trials` ở `engine/sandbox.ps1`; Tester HQ (Phase 3) gọi `run.ps1 trial` hoặc các hàm này trực tiếp. Lưu ý real trial **non-deterministic**: loopy có thể loop vài vòng trước khi ship (lần verify B.2 loop 1 vòng rồi pass) — `max_steps` là cầu dao; nếu real model không bao giờ ship → run `failed` → trial fail (đúng nghĩa "không ra sản phẩm").

---

## Quyết định đã chốt (user 2026-05-27)

- **Fixture = tái dùng `examples/loopy`** (không tạo fixture mới) — phục vụ cả 2 tầng.
- **Tier trial = THẬT** (chạy không `-Mock`, gọi model, assert artifact). Chấp nhận tốn token + non-deterministic.
- **Reconcile**: loopy chạy `-Mock` cho tầng cấu trúc (free/deterministic); chạy **real** cho tầng trial (assert `output_key` shipped).
- **Sandbox = copy thư mục** vào `company/sandbox/<runid>/` (KHÔNG git worktree — `company/` chưa là git repo); `sandbox/` gitignored.
- **Surface lệnh đề xuất**: `check` (tầng cấu trúc) + `trial` (sandbox-real, tự chạy `check` làm tiền đề).
- **`trial[]` shape (định nghĩa ở B.2)**: `{ observe: "<output_key>", expect: { kind: non-empty|contains|matches, value? } }`.

---

## Per-session log

### 2026-05-27 — Session A.1
- **Done**: Hiện thực tầng cấu trúc (Tester tầng 1). Tạo `engine/check.ps1` với hàm thuần `Test-StructuralGate -ProjectDir <dir>` (3 tiêu chí tuần tự: validate exit0 → run -Mock done → mọi output_key có file non-empty) + `Write-CheckResult` (in report + exit = số tiêu chí fail) + guard dot-source-safe. Wire vào `engine/run.ps1`: dot-source check.ps1, thêm `check` vào danh sách command hợp lệ, case dispatch, dòng help.
- **Output**: `engine/check.ps1`, dispatch `check` trong `engine/run.ps1`.
- **Gate**: **PASS**.
  - `./run.ps1 check hello` → EXIT=0, 3 tiêu chí pass (regression pipeline v1 ✓).
  - `$env:ENGINE_MOCK_ROUTER="verdict-router:pass"; ./run.ps1 check loopy` → EXIT=0, 3 tiêu chí pass (4 output_key: build/test/verdict/result đều non-empty).
  - Smoke fail (loopy không set router env): EXIT=1 — validate pass, run **fail** (reason nêu router `verdict` + `{ fail, pass }`), output-key **skip** (⊘, không false-positive). Short-circuit + reason máy-đọc-được xác nhận.
  - Regression bắt buộc: `validate hello` V=0, `run hello "x" -Mock` R=0.
- **Next**: A.2 — negative-path ≥3 mutation trên bản copy.
- **Notes**: Quyết định thiết kế — `Test-StructuralGate` nhận `-ProjectDir` (đã resolve) đồng nhất convention engine (Test-Workflow/Invoke-Workflow), run.ps1 resolve tên gọn → dir trước khi gọi (PLAN viết `-Project <name>` là loose). check **không** hardcode fixture/router; honor `$env:ENGINE_MOCK_ROUTER` có sẵn → giữ generic. Lệnh `check` non-destructive (không tự xoá `.runs/`); đã dọn `.runs/` test thủ công sau verify. `company/` chưa là git repo → `sandbox/`/`.gitignore` để session B.1.

### 2026-05-27 — Session A.2
- **Done**: Negative-path tầng cấu trúc. Copy thủ công `examples/loopy` → `company/sandbox/a2/{clean,mut1,mut2,mut3}` (gốc CHỈ ĐỌC, quy ước #6), với `$env:ENGINE_MOCK_ROUTER="verdict-router:pass"`. Positive control (clean copy) → exit 0, 3 tiêu chí pass. 3 mutation mỗi cái phá đúng 1 tầng:
  - **mut1 bad-agent**: build `agent` → `agents/ghost-builder.md` → **fail @validate** (exit 1), reason `node 'build' agent không tồn tại: agents/ghost-builder.md`; run+output-key ⊘ skip.
  - **mut2 router-mismatch**: đổi edge `when:"pass"` → `"approved"` (verdict vẫn ≥2 cạnh `when` ⇒ validate pass), router steer 'pass' → **fail @run** (exit 1), reason `Router 'verdict' trả nhãn 'pass' không khớp 'when' nào trong { fail, approved }`; output-key ⊘ skip.
  - **mut3 missing-output-key**: thêm node `audit` (output_key `audit`) reachable qua edge `verdict→audit when:"review"` (validate pass, run done qua pass→ship), router không bao giờ phát 'review' ⇒ audit không thăm → **fail @output-key** (exit 1), reason `output_key thiếu/rỗng: 'audit' (thiếu file audit.txt)`.
- **Output**: Không file code mới — `check.ps1` reason đã đủ máy-đọc-được, không cần fix. Negative-path tái lập = 3 workflow.json biến thể ở trên (đã ghi cách dựng).
- **Gate**: **PASS** (đo được).
  - 3 mutation đều exit ≥1, mỗi cái fail **đúng 1 tầng**, các tầng sau ⊘ skip (KHÔNG false-positive).
  - Mỗi reason chứa node/key/path cụ thể (không chỉ "failed").
  - `examples/loopy` + `examples/hello` gốc KHÔNG bị sửa (agents 4 file, không `.runs/` rò rỉ); sandbox `company/sandbox/` + test `.runs/` đã teardown sạch.
  - Regression bắt buộc: `validate hello` V=0, `run hello "x" -Mock` R=0.
- **Next**: B.1 — `engine/sandbox.ps1` (`Copy-ToSandbox`/`Remove-Sandbox`) + `.gitignore` + `run.ps1 trial` scaffold.
- **Notes**: mut2 chọn cách **đổi nhãn edge** (không xoá edge) để giữ router ≥2 cạnh — nếu xoá hẳn edge `pass` thì verdict còn 1 cạnh → fail ở tầng *validate* (router cần ≥2), lệch tầng mong muốn. Đây là điểm tinh tế cho ai tái lập. mut3 khai thác "reachable nhưng không-thăm": single-cursor walk không đi nhánh router không được phát → node có output_key vẫn thiếu file dù validate/run đều pass — đúng giá trị tầng output-key.

---

### 2026-05-27 — Session B.1
- **Done**: Sandbox harness cô lập (tiền đề tầng trial). Tạo `engine/sandbox.ps1` với 3 hàm thuần + guard dot-source-safe: `Get-SandboxRoot` (→ `company/sandbox`), `Copy-ToSandbox -ProjectDir [-RunId]` (copy mọi entry top-level TRỪ `.runs/` vào `company/sandbox/<runid>/`, mặc định runid = timestamp; throw nếu trùng), `Remove-Sandbox -SandboxDir` (teardown, **guard an toàn**: chỉ xoá nếu path nằm trong sandbox root + từ chối xoá chính root). Thêm `Invoke-TrialScaffold -ProjectDir` (copy → `Test-StructuralGate` trên bản sandbox vẫn `-Mock` → teardown qua `try/finally`). Tạo `company/.gitignore` (`sandbox/` + `.runs/`). Wire `run.ps1`: dot-source `sandbox.ps1`, thêm `trial` vào command hợp lệ + case dispatch + dòng help.
- **Output**: `engine/sandbox.ps1`, `company/.gitignore`, dispatch `trial` trong `engine/run.ps1`.
- **Gate**: **PASS**.
  - `$env:ENGINE_MOCK_ROUTER="verdict-router:pass"; ./run.ps1 trial loopy` → EXIT=0, 3 tiêu chí pass; run dir sinh tại `company/sandbox/<runid>/.runs/` (log xác nhận path).
  - Isolation: `examples/loopy/.runs` **KHÔNG** tồn tại sau chạy (gốc sạch); teardown xoá `sandbox/<runid>/` (chỉ còn root rỗng).
  - Regression bắt buộc: `validate hello` V=0, `run hello "x" -Mock` R=0. Dọn `examples/hello/.runs` + `sandbox/` root sau verify.
- **Next**: B.2 — `trial[]` spec + `Invoke-Trial` real (no -Mock) + done-gate + cập nhật ROADMAP/CLAUDE.md.
- **Notes**: Quyết định thiết kế — scaffold dùng `try/finally` đảm bảo teardown chạy cả khi `Test-StructuralGate` throw. `Remove-Sandbox` có 2 guard (StartsWith root + ≠ root) để quy ước #6 không bị phá do path sai. Copy theo từng entry top-level (`Get-ChildItem -Force`) thay vì copy cả thư mục, để loại `.runs/` gọn gàng (tránh `-Exclude` đệ quy không đáng tin trong PowerShell). `RunId` mặc định = timestamp nên 2 lần copy trong cùng giây có thể đụng — chấp nhận (test chạy tuần tự); B.2 nếu cần song song thì truyền `-RunId` riêng. `Invoke-TrialScaffold` đặt trong `sandbox.ps1` (không `check.ps1`) vì nó là logic sandbox, không phải tiêu chí cấu trúc.

### 2026-05-27 — Session B.2
- **Done**: Tầng trial THẬT + định nghĩa `trial[]` (đầu vào C-3). (1) Định nghĩa `trial[]` = field top-level trong `workflow.json`: `[{ observe: "<output_key>", expect: { kind: "non-empty"|"contains"|"matches", value? } }]` — loader (Get-Graph) + validate đều bỏ qua field này nên thêm an toàn (KHÔNG phải mutation; xác nhận `validate loopy` exit 0). Thêm `trial[]` cho `examples/loopy` (observe `result`: non-empty + contains "Ship"). (2) Bổ sung vào `engine/sandbox.ps1`: `Get-Trials` (đọc trial[] chuẩn hoá), `Test-TrialExpect` (pure: áp 1 assertion non-empty/contains/matches → {pass,reason}), `Invoke-Trial` (copy sandbox → `Invoke-Workflow` **real** no -Mock → yêu cầu state `done` → đọc `<observe>.txt` → assert → teardown qua try/finally; trả results + actual_excerpt), `Write-TrialResult` (report + exit = số assertion fail). (3) Wire `run.ps1 trial` thành 2 tầng tuần tự: cấu trúc (Invoke-TrialScaffold, mock) → nếu pass → trial THẬT (Invoke-Trial). (4) Cập nhật ROADMAP (Phase 2 → ✅) + `company/CLAUDE.md` (thêm `engine/check.ps1`, `engine/sandbox.ps1`, `sandbox/`, phase-2 row).
- **Output**: `engine/sandbox.ps1` (Get-Trials/Test-TrialExpect/Invoke-Trial/Write-TrialResult), `examples/loopy/workflow.json` (+trial[]), dispatch `trial` 2 tầng trong `run.ps1`, ROADMAP + CLAUDE.md.
- **Gate**: **PASS** (đo được).
  - `$env:ENGINE_MOCK_ROUTER="verdict-router:pass"; ./run.ps1 trial loopy` → EXIT=0. Tầng cấu trúc (mock) pass; tầng trial REAL: run **không -Mock** gọi claude thật → loop 1 vòng (verdict fail iter1 → build iter2 → verdict pass → ship), state `done` sau 7 lượt thăm; 2 assertion pass (`result` non-empty 178 chars + chứa "Ship"); report in actual_excerpt.
  - Isolation: artifact trong `company/sandbox/<runid>/.runs/`; `examples/loopy/.runs` KHÔNG tồn tại sau chạy; cả 2 sandbox subdir teardown (chỉ còn root rỗng → đã xoá thủ công sau verify).
  - Done-gate Outcome cuối: ✅ check loopy+hello exit0; ✅ 3 mutation (A.2) fail đúng tầng + reason; ✅ trial real done + assert pass + isolation; ✅ gốc không sửa (negative-path trên copy); ✅ ROADMAP + CLAUDE.md cập nhật.
  - Regression: `validate hello` V=0, `run hello "x" -Mock` R=0, `check hello`/`check loopy` exit 0, `validate loopy` (có trial[]) exit 0. Dọn `.runs/` + `sandbox/` sau verify.
- **Next**: — (Phase 2 hoàn tất). Phase M / Phase 3 soạn plan riêng.
- **Notes**: Chốt cách nạp `trial[]` = **top-level workflow.json** (không tham số CLI) — bám plan-as-data + C-3 (CTO sinh build-spec có field trial[]). `Invoke-Trial` đặt trong `sandbox.ps1` (cùng Copy/Remove) vì là logic sandbox-tier, không phải tiêu chí cấu trúc. `Test-TrialExpect` tách pure để test độc lập + tái dùng. `contains` dùng `.Contains()` (literal substring, không wildcard) — phân biệt với `matches` (regex). Chọn assertion "contains Ship" thay vì so nội dung đầy đủ vì real model non-deterministic về câu chữ nhưng ship.md luôn mở đầu `Ship:` → assertion ổn định qua các lần chạy. Quan sát: real verdict-router khắt khe hơn mock (fail iter1) → loop là hành vi đúng, max_steps=10 là cầu dao; đây là bằng chứng tier trial THẬT bắt được điều mock không (mock luôn pass ngay).

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-27 | Created from `PLAN.md` | @planner |
| 2026-05-27 | Session A.1 done — `engine/check.ps1` + `run.ps1 check` (gate pass loopy+hello) | @claude |
| 2026-05-27 | Session A.2 done — negative-path 3 mutation fail đúng tầng + reason máy-đọc-được; Phase 2-A xong | @claude |
| 2026-05-27 | Session B.1 done — `engine/sandbox.ps1` (Copy-ToSandbox/Remove-Sandbox/Invoke-TrialScaffold) + `.gitignore` + `run.ps1 trial` scaffold; isolation xác nhận | @claude |
| 2026-05-27 | Session B.2 done — `trial[]` spec (top-level workflow.json) + Get-Trials/Test-TrialExpect/Invoke-Trial/Write-TrialResult + `run.ps1 trial` 2 tầng; trial real loopy done+assert pass; ROADMAP+CLAUDE.md cập nhật. **Phase 2 ✅ DONE** | @claude |
