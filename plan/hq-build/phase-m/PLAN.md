# PLAN — Phase M: Cơ chế trí nhớ

> Sau toàn bộ pipeline: HQ có **memory store 2 tầng** (HQ-global + per-branch) mà engine **đọc đầu vòng đời** (bridge nạp `{{mem_*}}` theo loại + cap N) và **ghi cuối vòng đời** (node `record`). Chất lượng tích luỹ qua các run — một lỗi ghi ở run trước được run sau đọc + tránh lặp, chứng minh bằng `examples/mem-demo` chạy mock.

---

## Context

- **Vì sao chia nhiều session:** Phase M = code engine + convention store, có gate giữa các bước. Phải (1) chốt schema + layout store 2 tầng, (2) code read-path (bridge nạp memory, hàm thuần testable), (3) code write-path (node `record` append), (4) dựng fixture + chạy done-gate 2-run. Mỗi bước cần regression `validate`/`run -Mock` riêng → vượt 1 chat nếu dồn.
- **Quyết định đã chốt (input cho M — user duyệt):**
  - **Store 2 tầng**: HQ-global (`company/memory/` — `mistakes`/`patterns`/`global`, bài học tái dùng xuyên branch) + per-branch (`<project>/memory/` — `context`, quyết định riêng của branch). Bridge **merge** hai nguồn khi nạp.
  - **Chỉ HQ ghi** qua node `record` (deterministic, mock-được, khớp brain-model §D). Branch agent KHÔNG tự ghi (để mở rộng sau).
  - **Bridge nạp theo loại + cap N**: từng loại → 1 key (`mem_mistakes` / `mem_patterns` / `mem_context`), mỗi loại giới hạn **N entry mới nhất** (chống phình prompt). Agent chọn key cần trong `input` template.
  - **Fixture mới** `examples/mem-demo` (không tái dùng loopy — tránh lẫn ý nghĩa loop verdict).
- **Bám brain-model.md:** §Mô hình C (memory đọc/ghi + bridge nạp context) + §Prior-art #6 (4 loại file, đọc-nhiều/ghi-cuối, format entry đo được) + §D (node `record` cuối graph → DONE).
- **Bất biến engine (không vi phạm):** memory đọc qua **bridge `{{key}}`** — node KHÔNG tự đọc file thủ công (brain-model §C); engine là code cố định, mock offline; module dot-source-safe + `StrictMode`; một surface lệnh `run.ps1`.
- **Out of scope:** agent HQ thật `researcher`/`planner`/`record` đọc-ghi trong graph HQ (Phase 3); bridge lọc memory bằng keyword/tag (chỉ cap N ở M); per-branch memory sinh tự động bởi Builder (Phase 5); branch agent tự ghi. M chỉ giao **cơ chế store + read-path + write-path + demo**, không wiring vào graph HQ.

---

## Pipeline 2 sub-phase / 4 session

```
[M-A] Store + read-path ──────► company/memory/ + <project>/memory/ schema
                                 + engine/memory.ps1 (Get-Memory: by-type + cap N)
                                 + bridge nạp {{mem_*}} vào context
                                     │
[M-B] Write-path + demo ──────► node record append (Write-MemoryEntry)
                                 + examples/mem-demo (read+write)
                                 + done-gate 2-run: run1 ghi lỗi → run2 đọc + tránh lặp
                                     │
                                 Phase M done — ROADMAP cập nhật
```

Vòng đời memory: **đầu vòng** bridge nạp `context/mistakes/patterns` làm bối cảnh → **cuối vòng** node `record` persist decision/mistake/pattern (brain-model §Mô hình C).

---

## Phase M-A — Memory store + read-path

**Mục tiêu**: chốt layout + schema store 2 tầng; code hàm thuần `Get-Memory` (đọc by-type + cap N); wire vào `Initialize-Context` để `{{mem_*}}` resolve được — agent đọc memory qua bridge, không tự đọc file.

### Session A.1 — Schema + layout store 2 tầng
- **Scope**:
  - Tạo `company/memory/` (HQ-global) với 3 file seed: `mistakes.md`, `patterns.md`, `global.md` — mỗi file header mô tả + **format entry đo được** (delimiter `## YYYY-MM-DD HH:MM — <slug>` mỗi entry, field cố định theo loại: mistake = Triệu chứng/Root cause/Fix/Phòng tránh; pattern = Vấn đề/Cách/Caveats).
  - Định nghĩa convention per-branch: `<project>/memory/context.md` (quyết định riêng branch) — viết trong `company/memory/README.md`.
  - `company/memory/README.md`: bảng **loại → tầng → key bridge → ai-đọc/ai-ghi** (`mistakes`→HQ-global→`{{mem_mistakes}}`; `patterns`→HQ-global→`{{mem_patterns}}`; `context`→per-branch→`{{mem_context}}`; `global`→HQ-global, nạp gộp vào `{{mem_patterns}}` hoặc key riêng — chốt trong session), + quy ước cap N (mặc định **N=10** entry mới nhất/loại) + reserved-key `mem_*` (tránh đè `output_key`).
- **STOP gate**: `company/memory/{mistakes,patterns,global}.md` + `README.md` tồn tại; README có bảng loại→tầng→key→đọc/ghi đủ ≥3 loại + 1 entry ví dụ mẫu mỗi loại; convention per-branch `context.md` ghi rõ.
- **Output artifact**: `company/memory/` (3 file + README).

### Session A.2 — Read-path: `engine/memory.ps1` + wire bridge
- **Scope**:
  - `engine/memory.ps1` — hàm thuần `Get-Memory $ProjectDir [-Cap N]` → hashtable `{ mem_mistakes; mem_patterns; mem_context }`: đọc HQ-global từ `company/memory/` + per-branch từ `$ProjectDir/memory/`, **split theo delimiter entry → giữ N block cuối** → join lại. File/thư mục thiếu → key = `''` (không throw). Guard `StrictMode`/`$null`/`.Count`. Wrapper direct-run + dot-source-safe guard.
  - Wire vào `engine/workflow.ps1` `Initialize-Context`: sau khi seed `user_request` + output_keys, **merge** `Get-Memory` vào context (chỉ key chưa tồn tại — output_key luôn thắng; cảnh báo nếu trùng tên). `mem_*` không khớp `output_key` → an toàn.
  - Quyết định nguồn `company/memory/` path: resolve tương đối từ engine (vd `$PSScriptRoot/../memory`) — chốt + comment trong code.
- **STOP gate**: `Get-Memory` chạy độc lập trả hashtable 3 key đúng cap (test tay: tạo file >N entry → chỉ N block cuối ra; file thiếu → `''`, không throw); regression `validate hello` exit 0 + `run hello "x" -Mock` done (memory rỗng không phá pipeline cũ); dọn `.runs/` test.
- **Output artifact**: `engine/memory.ps1` + sửa `Initialize-Context` trong `engine/workflow.ps1`.

**Phase M-A gate**: agent có thể đọc memory qua `{{mem_mistakes}}`/`{{mem_patterns}}`/`{{mem_context}}`; cap N hoạt động; pipeline cũ (hello) không regress.

---

## Phase M-B — Write-path + demo + done-gate

**Mục tiêu**: node `record` ghi kết cục vào đúng tầng store (append date-stamped, by-type→tầng); dựng `examples/mem-demo` chứng minh đọc-ghi qua 2 run.

### Session B.1 — Write-path: node `record` append
- **Scope**:
  - Quy ước node `record`: thuộc tính `memory_write` trong workflow.json node (vd `"memory_write": "mistakes"`) khai loại ghi. Loại → tầng theo bảng A.1 (`mistakes`/`patterns`/`global`→HQ-global `company/memory/`; `context`→per-branch `$ProjectDir/memory/`).
  - `engine/memory.ps1` thêm hàm thuần `Write-MemoryEntry $ProjectDir $type $content` — append block `## <timestamp> — run<seq>` + nội dung output node vào đúng file/tầng (tạo file nếu thiếu). Idempotent về format (luôn 1 block/lần).
  - Wire `engine/workflow.ps1` sau khi node chạy xong (cạnh ghi `output_key`, ~line 303–306): nếu node có `memory_write` → gọi `Write-MemoryEntry`. Additive, không phá nhánh fail/resume.
  - `engine/validate.ps1`: thêm check nhẹ `memory_write` (nếu có) ∈ {mistakes,patterns,global,context} — sai loại = lỗi máy-đọc-được.
- **STOP gate**: `Write-MemoryEntry` append đúng 1 block vào đúng file/tầng (test tay 1 mock run có node `memory_write` → entry xuất hiện trong store); `validate` bắt được `memory_write` sai loại; regression `run hello -Mock` done (node không có `memory_write` không bị ảnh hưởng); dọn store test + `.runs/`.
- **Output artifact**: `engine/memory.ps1` (+`Write-MemoryEntry`) + sửa `engine/workflow.ps1` + `engine/validate.ps1`.

### Session B.2 — `examples/mem-demo` + done-gate 2-run
- **Scope**:
  - `examples/mem-demo/`: `workflow.json` tối thiểu — node `worker` (agent đọc `{{mem_mistakes}}` trong input, mock echo phản ánh "đã đọc lỗi cũ" nếu có) → node `record` (`memory_write: mistakes`, mock xuất 1 lỗi). Agent stub `.md` echo deterministic. `max_steps` đặt.
  - **Done-gate 2-run (mock)**: **run 1** — `company/memory/mistakes.md` rỗng → `worker` không thấy lỗi → `record` ghi 1 entry lỗi. **run 2** — `worker` đọc `{{mem_mistakes}}` thấy entry run 1 → output phản ánh "tránh lặp" (khác run 1). Chứng minh đọc-ghi tích luỹ.
  - Verify isolation: ghi vào `company/memory/` (HQ-global) thật → **dọn entry demo sau verify** (hoặc dùng project-local store cho demo để khỏi bẩn HQ-global — chốt trong session, ưu tiên không bẩn HQ-global).
  - Cập nhật `company/CLAUDE.md` bảng "Bản đồ file" (`engine/memory.ps1`, `company/memory/`, `examples/mem-demo/`, `plan/hq-build/phase-m/`) + ROADMAP bảng tiến độ Phase M → ✅.
- **STOP gate**: done-gate checklist (xem Outcome) **tất cả tick**; 2 run mock cho output run2 ≠ run1 do đọc memory; store demo dọn sạch (HQ-global không còn entry rác); CLAUDE.md + ROADMAP cập nhật.
- **Output artifact**: `examples/mem-demo/` + CLAUDE.md + ROADMAP cập nhật.

**Phase M-B gate** = Outcome cuối.

---

## Outcome cuối

- Memory store 2 tầng + read-path (`{{mem_*}}` by-type + cap N) + write-path (node `record` append) hoạt động end-to-end trên mock; `examples/mem-demo` chứng minh tích luỹ xuyên run.
- **Done-gate (checklist đo được):**
  - [ ] `company/memory/` có schema 2 tầng (HQ-global 3 file + README bảng loại→tầng→key→đọc/ghi) + convention per-branch `context.md`.
  - [ ] `Get-Memory` đọc by-type + cap N entry mới nhất; file thiếu → `''` không throw; merge vào `Initialize-Context` (output_key thắng khi trùng).
  - [ ] Agent đọc được memory qua `{{mem_mistakes}}`/`{{mem_patterns}}`/`{{mem_context}}`.
  - [ ] Node `record` (`memory_write`) append đúng 1 block vào đúng tầng theo loại; `validate` bắt loại sai.
  - [ ] `examples/mem-demo`: run1 ghi lỗi → run2 đọc + output khác (tránh lặp), demo bằng mock.
  - [ ] Regression: `validate hello` exit 0 + `run hello -Mock` done (memory rỗng không phá pipeline cũ); store demo dọn sạch.
  - [ ] `company/CLAUDE.md` Bản đồ file + ROADMAP bảng tiến độ Phase M ✅ cập nhật.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-05-27 | Initial | Tạo từ ROADMAP Phase M; chốt (user): store 2 tầng HQ-global+per-branch, chỉ HQ ghi qua node record, bridge by-type+cap N, fixture mới examples/mem-demo |
