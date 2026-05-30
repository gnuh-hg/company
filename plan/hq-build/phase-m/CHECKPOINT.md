# CHECKPOINT — Phase M: Cơ chế trí nhớ

> Sổ tay tiến độ dài hạn. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ được làm 1 session** (xem mục "Đang ở đâu" để biết session nào).
- **STOP NGAY** khi đạt STOP gate của session đó — không tham làm session kế tiếp dù còn quota.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry vào "Per-session log".
- **Mọi session sửa engine**: regression tối thiểu `./run.ps1 validate hello` + `./run.ps1 run hello "x" -Mock` rồi dọn `.runs/` test trước khi đóng.

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 4 | 4 | 100% |
| Sub-phase done | 2 (M-A, M-B) | 2 (M-A, M-B) | 100% |
| Done-gate tick | 7 | 7 | 100% |

---

## Đang ở đâu

- **Phase**: M **✅ DONE** (M-A ✅; M-B ✅: B.1 ✅, B.2 ✅)
- **Session kế tiếp**: — (Phase M hoàn tất; tiếp theo theo ROADMAP là Phase 3 — HQ agents)
- **Blocker**: —
- **Reference**: `PLAN.md` Outcome cuối — done-gate 7/7 tick

---

## Per-session log

### A.1 — Schema + layout store 2 tầng (2026-05-27)
- **Làm gì**: tạo `company/memory/` HQ-global với `mistakes.md` / `patterns.md` / `global.md` (header + format entry đo được, delimiter `## <YYYY-MM-DD HH:MM> — <slug>`) + `README.md` (bảng loại→tầng→key→đọc/ghi 4 loại, cap N=10, reserved-key `mem_*`, convention per-branch `context.md`).
- **Quyết định chốt**: `global.md` **nạp gộp vào `{{mem_patterns}}`** (không key riêng) → giữ hợp đồng bridge 3 key (`mem_mistakes`/`mem_patterns`/`mem_context`), khớp hashtable read-path A.2. Per-branch `memory/context.md` tạo **lười** (chỉ sinh khi node `record` ghi `context` lần đầu).
- **STOP gate**: ✅ 3 file + README tồn tại; README có bảng ≥3 loại + 1 entry ví dụ/loại (mistakes/patterns/global/context); convention per-branch ghi rõ. Không sửa engine → không cần regression.
- **Done-gate tick**: schema 2 tầng (item 1) ✅.

### A.2 — Read-path: `engine/memory.ps1` + wire bridge (2026-05-27)
- **Làm gì**: tạo `engine/memory.ps1` — `Get-Memory $ProjectDir [-Cap N=10]` → hashtable 3 key (`mem_mistakes`/`mem_patterns`/`mem_context`); helper `Get-MemoryEntry` (split file theo delimiter `## <YYYY-MM-DD HH:MM>`, **bỏ qua block trong code-fence** vì seed .md chứa ví dụ trong fence), `Join-MemoryEntry` (giữ N block cuối), `Get-MemoryRoot` (`$PSScriptRoot/../memory`). Wire `Initialize-Context` (`engine/workflow.ps1`): thêm param `$ProjectDir` tuỳ chọn → merge `Get-Memory` (output_key thắng + `Write-Warning` nếu trùng `mem_*`); truyền `$ProjectDir` ở cả 2 call site (run mới + resume); dot-source `memory.ps1`.
- **Quyết định chốt**: `mem_patterns` = `patterns.md` + `global.md` gộp rồi cap N **chung** (khớp README, hợp đồng 3 key). Path HQ-global resolve `$PSScriptRoot/../memory` (nested `Join-Path` cho tương thích). File/thư mục thiếu → key `''`, không throw.
- **STOP gate**: ✅ `Get-Memory` trả 3 key; cap N=10 giữ đúng 10 block cuối của 12 (oldest kept = m3); `global.md` merge vào `mem_patterns` (3 block); seed rỗng → cả 3 key `''` (fence-skip đúng); `{{mem_mistakes}}` resolve qua bridge end-to-end với entry tạm; regression `validate hello` exit 0 + `run hello "x" -Mock` done; dọn `.runs/` + restore seed.
- **Done-gate tick**: `Get-Memory` by-type+cap N (item 2) ✅; agent đọc qua `{{mem_*}}` (item 3) ✅.

---

### B.1 — Write-path: node `record` append (2026-05-27)
- **Làm gì**: thêm `Write-MemoryEntry $ProjectDir $Type $Content [-Slug]` + helper `Get-MemoryWriteTarget` vào `engine/memory.ps1` — append đúng 1 block `## <yyyy-MM-dd HH:mm> — <slug>` + content vào đúng tầng theo loại (mistakes/patterns/global → HQ-global `company/memory/`; context → per-branch `<ProjectDir>/memory/context.md`, tạo lười); ngăn block cũ bằng dòng trống; loại sai → throw; `$script:MemTypes` dùng chung. Wire `engine/workflow.ps1` (sau khi ghi output_key): node có `memory_write` → gọi `Write-MemoryEntry` (additive, lỗi ghi chỉ WARN không phá run). `engine/graph.ps1` `ConvertTo-NormNode` carry thêm field `memory_write` (truy cập member trực tiếp `$node.memory_write`, không Get-Prop — ordered hashtable). `engine/validate.ps1`: capture `memory_write` cả 2 nhánh (pipeline/nodes) + check ∈ {mistakes,patterns,global,context}.
- **Quyết định chốt**: slug mặc định = `$cursor` (node id) khi wire — header khớp delimiter regex read-path. Lỗi `Write-MemoryEntry` lúc runtime = WARN (không fail run) vì validate đã chặn loại sai từ author-time. Node thường (`memory_write` = `$null`) hoàn toàn không bị ảnh hưởng.
- **STOP gate**: ✅ `Write-MemoryEntry` append đúng 1 block/lần (2 lần → 2 block), đọc lại qua `Get-Memory`/`Get-MemoryEntry` khớp; loại sai throw; `validate` bắt `memory_write` sai loại (hợp lệ → 0 lỗi); end-to-end mock run node `memory_write: context` → per-branch `context.md` tạo + 1 block + log; regression `validate hello` exit 0 + `run hello "x" -Mock` done (hello không có `memory_write` không regress); dọn `.runs/` test; HQ-global store không bẩn (chỉ ghi `context` vào temp dir).
- **Done-gate tick**: node `record` (`memory_write`) append đúng tầng + `validate` bắt loại sai (item 4) ✅.

### B.2 — `examples/mem-demo` + done-gate 2-run (2026-05-27)
- **Làm gì**: tạo `examples/mem-demo/` — `workflow.json` graph 2 node (`worker` đọc `{{mem_context}}` trong input → `record` `memory_write: context`, output_key `lesson`, edge worker→record, `max_steps: 5`) + agent stub `worker.md`/`record.md` (echo deterministic, mô tả vòng đời đọc-đầu/ghi-cuối). Fix engine: `engine/validate.ps1` thêm `$script:ReservedKeys` (`user_request` + `mem_mistakes`/`mem_patterns`/`mem_context`) → key resolve skip reserved (trước đó `{{mem_context}}` bị báo lỗi "không resolve được").
- **Quyết định chốt**: demo dùng loại **`context`** (per-branch `examples/mem-demo/memory/context.md`) thay vì `mistakes` như PLAN gốc gợi ý — để **không bẩn HQ-global** (ưu tiên đã ghi trong "Đang ở đâu"); `mem_context` cũng đọc per-branch nên demo self-contained. Fixture **không commit `memory/`** (xoá sau verify) → done-gate tái lập được từ trạng thái sạch.
- **STOP gate**: ✅ `validate mem-demo` exit 0 (sau fix reserved-key); run1 (memory rỗng) → `worker` output 74 chars (mem_context rỗng) + `record` ghi 1 block vào `context.md`; run2 → `worker` output 180 chars (đọc entry run1 qua `{{mem_context}}`) ≠ run1 → tránh lặp chứng minh tích luỹ; HQ-global `company/memory/` không bẩn (0 entry `record`); regression `validate hello` exit 0 + `run hello "x" -Mock` done; dọn `.runs/` + `examples/mem-demo/memory/`.
- **Done-gate tick**: demo run1→run2 output khác (item 5) ✅; regression + store sạch (item 6) ✅; CLAUDE.md + ROADMAP cập nhật (item 7) ✅. **Phase M done-gate 7/7 ✅.**

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-27 | Created from `PLAN.md` | @planner |
| 2026-05-27 | Session A.1 done — store 2 tầng schema + README | @claude |
| 2026-05-27 | Session A.2 done — `engine/memory.ps1` (Get-Memory) + wire Initialize-Context; M-A ✅ | @claude |
| 2026-05-27 | Session B.1 done — write-path `Write-MemoryEntry` + wire workflow/graph/validate | @claude |
| 2026-05-27 | Session B.2 done — `examples/mem-demo` + done-gate 2-run + validate reserved-key `mem_*`; **Phase M ✅** | @claude |
