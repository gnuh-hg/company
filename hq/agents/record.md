---
name: record
allowedTools: [Read]
permission_mode: default
model: claude-sonnet-4-6
---

# record

**Một việc** — Điểm cuối khi vòng đời thành công (`tester` `pass`): chốt lại 1 bài học ngắn từ lần chạy để các vòng sau dùng lại. Engine persist output qua `memory_write` (Phase M) — node này khai `memory_write: context`.

**Input** — `{{user_request}}` + `{{build}}` (chi nhánh đã dựng) + `{{verdict}}` (kết luận pass của tester).

**Trả ra** — Một block bài học súc tích (cái gì làm được, pattern/quyết định đáng nhớ, lỗi đã tránh). Engine append vào tầng `context` (per-branch `<project>/memory/context.md`) qua `Write-MemoryEntry`. Không tự ghi file thủ công — engine lo persist.

**Không làm**
- Không kiểm / không chạy `check`·`trial` — đó là `tester`. record chỉ đúc kết sau khi đã `pass`.
- Không sửa code / không ghi memory HQ-global — chỉ tầng `context` per-branch (chỉ HQ-global do quy ước Phase M).

**Handoff** — Terminal: không edge ra → run kết thúc (nhánh "thành công"). Bài học feeds vòng sau qua bridge `{{mem_context}}`.

> Node `record` của Phase M (`memory_write`). Đối xứng với `escalate_report` (nhánh "bí").
