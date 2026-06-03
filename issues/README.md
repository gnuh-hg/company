# company/issues/ — Nhà chung cho mọi loại issue

> Gom **tất cả loại issue** của `company/` về một chỗ. Mỗi loại = 1 file riêng theo cột dưới.
> Lý do tách khỏi `.claude/`: issue đến từ **nhiều lớp** (HQ-team native + engine chi nhánh + sau này
> nhiều loại khác) — gom về `company/issues/` để dễ quản lý + mở rộng, không lẫn vào config `.claude/`.

---

## Các loại issue

| File | Loại | Nguồn ghi | Commit? | Format |
|---|---|---|---|---|
| `team-issues-queue.md` | Hành vi teammate HQ-team (coordination) | HQ-team (người/lead ghi tay) | ✅ committed | Markdown — xem `.claude/teams/playbook.md` §9 |
| `route-issues.ndjson` | Engine chi nhánh in nhãn router sai tập cạnh hợp lệ | Engine `Write-RouteIssue` (deterministic, KHÔNG gọi model) — Phase J | ❌ gitignored (runtime, regen-được) | NDJSON 1 dòng/entry — xem `plan/hq-v2/phase-j/PLAN.md` §J.2 |

> **Quy ước phân biệt:**
> - `team-issues-queue.md` = **cách agent behave** trong coordination (silent-complete, wrong-recipient…). Hand-curated, committed.
> - `route-issues.ndjson` = **sự kiện runtime của engine** (route mismatch). Máy ghi, gitignored.
> - `company/memory/{mistakes,patterns}.md` (KHÁC, không nằm đây) = code bug / code pattern của engine store.
> - `.claude/memory/` (KHÁC) = bài học HQ-team native.

## Khi thêm loại issue mới
1. Tạo file mới trong `company/issues/`.
2. Thêm 1 hàng vào bảng trên (file · loại · nguồn ghi · commit? · format).
3. Nếu là runtime-generated (máy ghi) → thêm pattern vào `company/.gitignore`.
