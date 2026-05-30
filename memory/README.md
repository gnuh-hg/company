# memory/ — Memory store 2 tầng (Phase M)

> Kho trí nhớ có schema theo loại. Engine **đọc đầu vòng đời** (bridge nạp `{{mem_*}}` theo loại + cap N) và **ghi cuối vòng đời** (node `record`). Bám `plan/hq-build/phase-r/brain-model.md` §Prior-art #6 + §Mô hình C.

---

## 2 tầng store

| Tầng | Vị trí | Nội dung | Ai ghi |
|---|---|---|---|
| **HQ-global** | `company/memory/` (thư mục này) | Bài học **tái dùng xuyên branch** — lỗi, pattern, ghi chú toàn cục | Chỉ HQ (node `record`) |
| **per-branch** | `<project>/memory/` | Quyết định **riêng của branch** đó (context cục bộ) | Chỉ HQ (node `record`) — branch agent KHÔNG tự ghi (mở rộng sau) |

Bridge **merge** hai nguồn khi nạp context. Khi key trùng `output_key` → **output_key luôn thắng** (memory không đè dữ liệu run).

---

## Bảng loại → tầng → key bridge → đọc/ghi

| Loại (file) | Tầng | Key bridge | Ai đọc | Ai ghi (`memory_write`) |
|---|---|---|---|---|
| `mistakes.md` | HQ-global | `{{mem_mistakes}}` | researcher, planner (đầu vòng đời) | node `record` · `mistakes` |
| `patterns.md` | HQ-global | `{{mem_patterns}}` | researcher, planner | node `record` · `patterns` |
| `global.md` | HQ-global | **gộp vào `{{mem_patterns}}`** | researcher, planner | node `record` · `global` |
| `context.md` | **per-branch** (`<project>/memory/`) | `{{mem_context}}` | mọi vai đọc đầu vòng | node `record` · `context` |

→ Hợp đồng bridge = **3 key**: `mem_mistakes`, `mem_patterns` (gộp patterns+global), `mem_context`. Agent chọn key cần trong `input` template của node; không ép node nào phải đọc.

---

## Cap N (chống phình prompt)

- Read-path `Get-Memory` (Phase M-A.2) split mỗi file theo delimiter entry `## ` → giữ **N=10 block mới nhất** mỗi loại → join lại nạp vào key.
- `{{mem_patterns}}` = (patterns.md + global.md) gộp rồi cap N chung.
- File/thư mục thiếu → key = `''` (chuỗi rỗng), **không throw**.

---

## Reserved-key `mem_*`

- Prefix `mem_` **dành riêng** cho memory bridge. Workflow.json **không** được dùng `mem_*` làm `output_key` (tránh đè). `Initialize-Context` cảnh báo nếu trùng và **giữ output_key**.

---

## Format entry (đo được)

Mọi loại: 1 entry = 1 block mở bằng delimiter `## <YYYY-MM-DD HH:MM> — <slug>`, field cố định theo loại. Append mới nhất xuống cuối file.

**mistakes** (4 field) — ví dụ:
```
## 2026-05-27 14:30 — uvicorn-reload-treo-dev
- **Triệu chứng**: server dev không nhận request sau vài phút, treo im.
- **Root cause**: chạy uvicorn với --reload trong môi trường file-watch quá tải.
- **Fix**: bỏ --reload khi chạy dev nền.
- **Phòng tránh**: chỉ dùng --reload khi sửa code chủ động, không để chạy lâu.
```

**patterns** (3 field) — ví dụ:
```
## 2026-05-27 14:30 — router-cap-max-steps
- **Vấn đề**: loop build→test→verdict có thể lặp vô hạn nếu verdict luôn fail.
- **Cách**: đặt max_steps trên graph + router edge thoát khi đạt ngưỡng.
- **Caveats**: max_steps quá thấp cắt loop hợp lệ; cân theo độ sâu re-plan kỳ vọng.
```

**global** (1 field `Ghi chú`) — ví dụ:
```
## 2026-05-27 14:30 — i18n-cap-nhat-ca-hai-locale
- **Ghi chú**: mọi project có i18n phải cập nhật cả en.json lẫn vi.json khi thêm chuỗi.
```

**context** (per-branch, append theo ngày — quyết định/pending/tech-debt) — ví dụ:
```
## 2026-05-27 14:30 — chot-dung-sqlite-dev
- **Quyết định**: branch này dùng SQLite cho dev, hoãn PostgreSQL tới khi deploy.
- **Pending/tech-debt**: migration script chưa viết.
```

---

## Convention per-branch (`<project>/memory/context.md`)

- Mỗi branch (project trong `projects/`) có thư mục `memory/` riêng chứa **chỉ** `context.md` — quyết định cục bộ của branch đó.
- Tạo **lười**: chỉ sinh khi node `record` ghi loại `context` lần đầu (Phase M-B). Thiếu file → `{{mem_context}}` = `''`.
- KHÔNG đặt `mistakes`/`patterns`/`global` ở tầng branch — các loại đó là HQ-global để tái dùng xuyên branch.
