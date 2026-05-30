# PLAN — Phase 2: Tiêu chí Tester máy-kiểm-được + sandbox cô lập + fixture

> Sau toàn bộ pipeline: có **Tester 2 tầng** chạy được qua `run.ps1` — (1) **gate cấu trúc** (`validate` exit 0 → `run -Mock` done → mọi `output_key` ra, non-empty) nhanh & free; (2) **trial thật** trong `company/sandbox/` cô lập (chạy project **không** `-Mock`, quan sát artifact ra sản phẩm chạy được) + định nghĩa `trial[]` (đầu vào cho build-spec C-3). Fixture = `examples/loopy` (tái dùng): checker chạy → pass cả 2 tầng; cố tình làm hỏng → fail **đúng chỗ**, máy báo được **lý do đọc-được**.

---

## Context

- **Vì sao chia nhiều session:** Tester 2 tầng có 2 phần tách bạch — tầng cấu trúc (deterministic, mock, free) và tầng trial (real model, tốn token, non-deterministic + cần sandbox isolation an toàn ghi file). Gộp 1 chat → harness sandbox ẩu (rủi ro ghi đè ngoài scope) + negative-path (cố tình làm hỏng) không kiểm kỹ. Tầng cấu trúc + negative-path phải chốt TRƯỚC khi đụng real trial.
- **Quyết định đã chốt (user 2026-05-27):**
  - **Fixture = tái dùng `examples/loopy`** (không tạo fixture mới). loopy đã có vòng `build→test→verdict` + router thoát (`pass`/`fail`) + `max_steps` — đủ để demo gate pass/fail bằng `ENGINE_MOCK_ROUTER` cho tầng cấu trúc.
  - **Tier trial = THẬT** (chạy không `-Mock`, gọi model, sinh artifact, áp assertion). Chấp nhận tốn token + non-deterministic ngay ở P2 để bám đúng C-2 "thử-thật" thay vì LLM-phán.
  - **Reconcile fixture↔trial:** 1 fixture (`loopy`) phục vụ **cả 2 tầng** — tầng cấu trúc chạy `-Mock` (free, deterministic); tầng trial chạy **real** rồi assert trên artifact `output_key` shipped (vd `{{result}}` chứa nội dung kỳ vọng + run đạt `done`). Không cần fixture thứ hai.
  - **Sandbox isolation = copy thư mục** vào `company/sandbox/<runid>/` (KHÔNG dùng git worktree — `company/` hiện không phải git repo). `sandbox/` được gitignore (tạo `.gitignore` nếu chưa có) cho forward-compat.
- **Đầu vào đã chốt (không thiết kế lại):**
  - **C-2** (ROADMAP cross-cutting): Tester 2 tầng = (1) gate cấu trúc `validate` exit0 + mock done + mọi `output_key` ra; (2) trial hành vi chạy việc thật trong sandbox cô lập. Catalog (P1) KHÔNG cần shape contract cứng → tầng trial đo "ra sản phẩm chạy được", không so schema.
  - **C-3** (ROADMAP cross-cutting): build-spec CTO có field `trial[]` (việc thật cho Tester). Phase 2 **định nghĩa `trial[]` nghĩa là gì + quan sát thế nào** (đầu vào để P3 CTO sinh được).
  - **Engine hiện có** (README + Quy ước bất biến): `validate` exit = số lỗi; `run [-Mock]` → state `done`/`failed`; artifact run = `.runs/<ts>/<output_key>.txt` (latest-wins) + `state.json` (`visits[]`, `status`); `ENGINE_MOCK_ROUTER` đa-spec `;`-separated điều khiển router offline; `ENGINE_MOCK_FAIL` ép fail xác định. Project resolve: path → `projects/` → `examples/`.
- **Ràng buộc engine (quy ước bất biến):**
  - **#1**: logic Tester nằm trong `engine/*.ps1`, KHÔNG nhồi vào agent `.md`.
  - **#4 Một surface lệnh**: Tester đi qua `run.ps1 <command> <project>` — KHÔNG tạo entry point khác. (Đề xuất: `check` = tầng cấu trúc; `trial` = tầng sandbox-real, tự chạy `check` làm tiền đề.)
  - **#5 Module dot-source-safe**: module mới guard `InvocationName`/`Line`; hàm thuần testable (`Test-StructuralGate`, `Invoke-Trial`, `Copy-ToSandbox`) + wrapper direct-run.
  - **#6 Chỉ thao tác trong `company/`**: sandbox copy chỉ ghi trong `company/sandbox/`; KHÔNG đụng `leafnote/` hay project khác. `examples/loopy` gốc CHỈ ĐỌC — mọi mutation negative-path làm trên **bản copy trong sandbox**, không sửa file gốc.
  - **StrictMode**: guard `$null`/`.Count` (PowerShell ép `@()`→`$null`).
- **Out of scope (plan riêng sau):** HQ Tester agent thật + ghi memory kết cục (P3 + PM); chạy end-to-end HQ build thật (P5); checker đo nhiều fixture / nhiều chi nhánh (P5 tích luỹ). P2 chỉ giao **cơ chế checker 2 tầng + sandbox harness + định nghĩa `trial[]`** chạy pass/fail đúng trên 1 fixture (`loopy`).

---

## Pipeline 2 sub-phase / 4 session

```
[2-A] Tầng cấu trúc (deterministic, mock, free) + negative-path
      A.1 engine/check.ps1: Test-StructuralGate + run.ps1 check → pass trên loopy/hello
      A.2 negative-path: làm hỏng bản copy → check fail ĐÚNG tầng + lý do máy-đọc-được
                                    │
[2-B] Sandbox isolation + tier trial THẬT + done-gate
      B.1 engine/sandbox.ps1: Copy-ToSandbox + teardown + .gitignore; run.ps1 trial scaffold (chạy check trong sandbox)
      B.2 trial[] spec + Invoke-Trial real (no -Mock) → assert artifact; done-gate (pass + break→fail) + ROADMAP/CLAUDE.md
                                    │
                                Phase 2 done
```

---

## Phase 2-A — Tầng cấu trúc (gate máy-kiểm-được) + negative-path

**Mục tiêu**: hiện thực **tầng 1** của Tester — deterministic, mock, free — và chứng minh nó **fail đúng chỗ với lý do đọc-được** khi workflow hỏng. Đây là nền: tầng trial (2-B) chỉ chạy khi tầng cấu trúc pass.

### Session A.1 — `engine/check.ps1` + `run.ps1 check` (tầng cấu trúc, positive)
- **Scope**:
  1. Tạo `engine/check.ps1` với **hàm thuần** `Test-StructuralGate -Project <name>` trả object `{ pass: bool, checks: [{ name, pass, reason }] }` gồm 3 tiêu chí tuần tự:
     - `validate` → exit 0 (gọi lại `Test-Workflow`/validate, đếm lỗi = 0).
     - `run -Mock` → state `done` (không `failed`/`max_steps`).
     - **mọi `output_key`** khai trong nodes có file `.runs/<ts>/<key>.txt` tồn tại & **non-empty**.
  2. Wrapper direct-run + dispatch trong `run.ps1`: `run.ps1 check <proj>` → in report từng tiêu chí (pass/fail + reason) + **exit = số tiêu chí fail** (0 = pass toàn bộ — đồng nhất convention `validate`).
  3. Dọn `.runs/` test sau verify.
- **STOP gate** (đo được):
  - [ ] `engine/check.ps1` tồn tại, guard dot-source-safe, có hàm thuần `Test-StructuralGate`.
  - [ ] `./run.ps1 check loopy` → exit 0, report liệt kê 3 tiêu chí đều pass (dùng `ENGINE_MOCK_ROUTER` để loopy đạt `pass` thoát loop).
  - [ ] `./run.ps1 check hello` → exit 0 (regression — pipeline v1 vẫn qua gate).
- **Output artifact**: `engine/check.ps1`, dispatch `check` trong `engine/run.ps1`.

### Session A.2 — Negative-path: hỏng → fail đúng tầng + lý do máy-đọc-được
- **Scope**: trên **bản copy** loopy (không sửa gốc — quy ước #6), tạo ≥3 mutation, mỗi cái phá đúng 1 tiêu chí, xác nhận `check` fail **đúng tiêu chí** + reason string chỉ rõ chỗ hỏng:
  1. **Bad agent path** (sửa `agent` trỏ file không tồn tại) → fail tầng `validate`, reason nêu node + path.
  2. **Unreachable / router không khớp** (vd xoá edge `when:"pass"` hoặc ép `ENGINE_MOCK_ROUTER` ra nhãn không có `when`) → fail tầng `run` (`failed`/`max_steps`), reason nêu node router + nhãn.
  3. **Missing output_key** (đổi 1 node để `output_key` không sinh file / rỗng) → fail tầng output-key, reason nêu key thiếu.
- **STOP gate** (đo được):
  - [ ] 3 mutation, mỗi cái `check` → exit ≥1 (fail), report chỉ đúng tiêu chí bị phá (không false-positive tiêu chí khác).
  - [ ] Mỗi reason là chuỗi **máy-đọc-được** (chứa tên node/key/path bị lỗi — không chỉ "failed").
  - [ ] `examples/loopy` gốc KHÔNG bị sửa (diff sạch); mọi mutation làm trên bản copy; copy đã dọn.
- **Output artifact**: xác nhận negative-path (ghi cách tái lập 3 mutation vào CHECKPOINT per-session log — không cần file code mới ngoài fix `check.ps1` nếu reason chưa đủ rõ).

**Phase 2-A gate**: `check` pass trên loopy + hello; 3 mutation fail đúng tầng + lý do đọc-được. Tầng cấu trúc xong → sang sandbox + trial.

---

## Phase 2-B — Sandbox isolation + tier trial THẬT + done-gate

**Mục tiêu**: hiện thực **tầng 2** — chạy trial THẬT (không `-Mock`) trong sandbox cô lập, an toàn không đụng project gốc; định nghĩa `trial[]` (đầu vào C-3) + quan sát "trial đạt".

### Session B.1 — Sandbox harness: `engine/sandbox.ps1` + `run.ps1 trial` scaffold
- **Scope**:
  1. Tạo `engine/sandbox.ps1`: hàm thuần `Copy-ToSandbox -Project <name>` → copy thư mục project (workflow.json + agents/, **trừ** `.runs/`) vào `company/sandbox/<runid>/`, trả path sandbox; hàm `Remove-Sandbox` teardown. StrictMode-safe.
  2. Tạo/cập nhật `company/.gitignore` thêm `sandbox/` (forward-compat — gitignore khi repo hoá).
  3. Dispatch `run.ps1 trial <proj>` (scaffold): copy vào sandbox → chạy **tầng cấu trúc** (`Test-StructuralGate` trên bản sandbox, vẫn `-Mock` ở bước này) → teardown. Chứng minh isolation TRƯỚC khi thêm real.
- **STOP gate** (đo được):
  - [ ] `engine/sandbox.ps1` tồn tại, dot-source-safe; `company/.gitignore` chứa `sandbox/`.
  - [ ] `./run.ps1 trial loopy` (scaffold, mock) → done; artifact run nằm trong `company/sandbox/<runid>/.runs/`, **KHÔNG** xuất hiện trong `examples/loopy/.runs/`.
  - [ ] Teardown dọn `company/sandbox/<runid>/` sau chạy (sandbox trống sau verify).
- **Output artifact**: `engine/sandbox.ps1`, dispatch `trial`, `company/.gitignore`.

### Session B.2 — `trial[]` spec + `Invoke-Trial` real + done-gate
- **Scope**:
  1. **Định nghĩa `trial[]`** (đầu vào C-3): list item `{ observe: "<output_key>", expect: { kind: "non-empty" | "contains" | "matches", value?: "<substring/regex>" } }` — assertion quan sát trên artifact `output_key` shipped. Tài liệu hoá trong report/README (mô tả, không over-engineer).
  2. `Invoke-Trial -Project <name> -Trials <trial[]>`: copy sandbox → chạy project **THẬT** (không `-Mock`, qua `claude` CLI) → đọc `<observe>.txt` mới nhất → áp `expect` → trả `{ pass, results: [{observe, expect, actual_excerpt, pass}] }` → teardown. Yêu cầu state run đạt `done` mới tính trial.
  3. Gắn vào `run.ps1 trial <proj>`: chạy tầng cấu trúc (mock) → nếu pass, chạy `Invoke-Trial` real. Định nghĩa `trial[]` cho loopy (vd `observe:"result"`, `expect: non-empty` + `contains` mẩu request) — cạnh `workflow.json` hoặc tham số; chốt cách nạp đầu session.
  4. **Done-gate verify** (Outcome cuối) + cập nhật `ROADMAP.md` (Phase 2 → ✅, cột Long-plan trỏ `plan/hq-build/phase-2/`) + `company/CLAUDE.md` bản đồ file (thêm `engine/check.ps1`, `engine/sandbox.ps1`, lệnh `check`/`trial`, `plan/hq-build/phase-2/`, `sandbox/`).
- **STOP gate** (đo được):
  - [ ] `Invoke-Trial` chạy loopy **real** (không `-Mock`) trong sandbox → run `done` + trial assertion pass (artifact `result` non-empty + chứa mẩu kỳ vọng); report in `actual_excerpt`.
  - [ ] Done-gate checklist (Outcome cuối) tick đủ: checker pass cả 2 tầng trên loopy; ≥1 mutation negative (từ A.2) → fail đúng tầng + lý do.
  - [ ] `trial[]` spec tài liệu hoá; ROADMAP + CLAUDE.md cập nhật; sandbox + `.runs/` test dọn sạch.
- **Output artifact**: `Invoke-Trial` trong `engine/check.ps1` (hoặc `trial.ps1`), `trial[]` định nghĩa tài liệu hoá, ROADMAP + CLAUDE.md cập nhật.

**Phase 2-B gate** = Outcome cuối.

---

## Outcome cuối

- **Tester 2 tầng chạy qua `run.ps1`:** `check` (tầng cấu trúc: `validate` exit0 + `run -Mock` done + mọi `output_key` non-empty, free/deterministic) + `trial` (tầng hành vi: sandbox isolation copy + chạy **real** + assert `trial[]` trên artifact).
- **`trial[]` định nghĩa** (đầu vào build-spec C-3 cho P3 CTO): `{ observe, expect{kind,value} }` quan sát trên `output_key` shipped.
- **Sandbox harness:** `company/sandbox/<runid>/` cô lập (gitignored), copy-in/teardown, không đụng project gốc.
- **Done-gate (checklist đo được):** ✅ ĐẠT ĐỦ (2026-05-27, Session B.2)
  - [x] `./run.ps1 check loopy` + `check hello` → exit 0, report 3 tiêu chí pass.
  - [x] ≥3 mutation (bad-agent / unreachable-router / missing-output-key) → `check` fail **đúng tầng** + reason máy-đọc-được (chứa node/key/path). *(Session A.2)*
  - [x] `./run.ps1 trial loopy` → tầng cấu trúc pass → trial **real** chạy `done` (loop 1 vòng, 7 lượt thăm) + 2 assertion `trial[]` pass (`result` non-empty + chứa "Ship"); sandbox isolation xác nhận (artifact trong `sandbox/`, gốc sạch); teardown dọn.
  - [x] `examples/loopy` + `examples/hello` gốc KHÔNG bị sửa logic; mọi mutation negative-path trên bản copy. (`trial[]` thêm vào loopy là field plan-as-data, không phải mutation — validate vẫn exit 0.)
  - [x] ROADMAP bảng tiến độ Phase 2 → ✅; CLAUDE.md bản đồ file cập nhật (`engine/check.ps1`, `engine/sandbox.ps1`, lệnh `check`/`trial`, `plan/hq-build/phase-2/`, `sandbox/`).

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-05-27 | Initial | Tạo từ ROADMAP Phase 2 + C-2/C-3 + engine README; chốt (user): fixture = tái dùng `loopy`, tier trial = THẬT (no -Mock). Reconcile: 1 fixture phục vụ cả 2 tầng (mock cho gate cấu trúc, real cho trial). Sandbox = copy thư mục vào `company/sandbox/` (không git worktree — chưa là repo) |
