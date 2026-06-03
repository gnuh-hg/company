---
name: hq-memory
description: "Đọc `.claude/memory/` đầu task + append bài học cuối task (date-stamped). Store HQ-team — TÁCH BẠCH với engine branch store `company/memory/`."
---

# HQ-Memory — đọc/ghi memory HQ-team

> Skill dùng chung cho **lead** (đọc bối cảnh + ghi context/global) và **tester** (ghi mistakes/patterns sau verify).
> ⚠️ Store đây là `company/.claude/memory/` — **KHÔNG** nhầm với `company/memory/` (engine branch store, bất biến).

---

## 1. Phân biệt 2 store — đọc trước khi làm gì cả

| Store | Đường dẫn | Ai ghi | Ghi khi nào |
|---|---|---|---|
| **HQ-team** (skill này) | `company/.claude/memory/` | Lead + tester | Đầu/cuối mỗi task HQ |
| **Engine branch** (bất biến) | `company/memory/` + `<project>/memory/` | Engine `memory.ps1` via node `record` | Workflow engine chạy |

**Quy tắc vàng:** HQ-team KHÔNG ghi vào `company/memory/`. Ngược lại, engine KHÔNG ghi vào `.claude/memory/`. Không bao giờ trộn.

---

## 2. Đọc memory — đầu mỗi task

### Khi nào đọc

- **Lead**: đọc trước khi spawn team hoặc tự làm task mới.
- **Researcher**: đọc `mistakes.md` + `context.md` trước khi gather context.
- **Tester**: không cần đọc trước (chỉ ghi sau).

### Các file và mục đích

| File | Đọc khi | Nội dung |
|---|---|---|
| `context.md` | Mọi task mới | Branch đang build, trạng thái, quyết định gần đây |
| `mistakes.md` | Trước khi plan / trước khi build | Lỗi thực tế trước đây — không tái phạm |
| `patterns.md` | Trước khi thiết kế / CTO call | Pattern thành công, loại request → cách build hiệu quả |
| `global.md` | Khi có quyết định kiến trúc / cross-cutting | Con người, scope engine, quyết định lâu dài |

### Cách đọc (cap N = 10 entry mới nhất)

Đọc toàn bộ file, nhưng **chỉ dùng 10 entry mới nhất** (kể từ delimiter `## ` cuối cùng đếm lên). Entry cũ hơn bỏ qua — còn lưu trong file nhưng không load vào context làm việc.

```bash
# Đọc file trực tiếp (Read tool hoặc Bash cat)
cat company/.claude/memory/context.md
cat company/.claude/memory/mistakes.md
cat company/.claude/memory/patterns.md
# global.md chỉ đọc khi có quyết định kiến trúc liên quan
```

Nếu file rỗng (chỉ có header comment) → chưa có memory, tiếp tục bình thường.

---

## 3. Ghi memory — cuối mỗi task

### Nguyên tắc

- Append **1 entry** vào đúng file theo loại (không ghi đè, không sửa entry cũ).
- Format **bắt buộc**: `## <YYYY-MM-DD HH:MM> — <slug-ngắn>` trên 1 dòng riêng, nội dung dưới.
- Slug ngắn, kebab-case, mô tả bài học hoặc sự kiện (vd `landing-email-fail-cors`, `auth-api-pattern-success`).
- Nội dung: **đo được, cụ thể** — không "cảm tính" hay "trông ổn". 2–5 dòng là đủ.

### Ai ghi gì

| Vai trò | File ghi | Khi nào |
|---|---|---|
| **Tester** (sau CHECK_RESULT fail) | `mistakes.md` | Ghi lỗi: loại lỗi + file/lệnh + nguyên nhân |
| **Tester** (sau CHECK_RESULT pass) | `patterns.md` | Ghi pattern: stack/cấu trúc đã thành công |
| **Tester** (sau mọi verify) | `context.md` | Ghi trạng thái: branch, done-criteria pass/fail, việc tiếp theo |
| **Lead** | `context.md` | Ghi quyết định, thay đổi hướng, branch mới |
| **Lead** | `global.md` | Ghi quyết định kiến trúc lâu dài, thay đổi scope |

### Template entry

```markdown
## 2026-06-15 14:30 — landing-email-cors-fail

Build: `projects/landing-email/` — tester fail vì CORS header thiếu trên `/api/subscribe`.
Fix: thêm `Access-Control-Allow-Origin: *` vào backend Express middleware.
Lệnh confirm: `npm test` exit 0 sau fix.
```

```markdown
## 2026-06-15 16:00 — auth-api-jwt-pattern

Stack: Node + Express + jsonwebtoken. Cấu trúc `src/{routes,middleware,models}/`.
Pattern: middleware `verifyToken` inject `req.user` → routes không cần parse lại.
Done-criteria: `npm test` 12/12 pass, `npm run build` exit 0.
```

### Lệnh ghi (append vào cuối file)

```bash
# Dùng Bash append — KHÔNG dùng Write (ghi đè toàn bộ)
cat >> company/.claude/memory/mistakes.md << 'EOF'

## 2026-06-15 14:30 — landing-email-cors-fail

<nội dung>
EOF
```

⚠️ Dùng **`>>`** (append), không bao giờ `>` (overwrite). File chứa lịch sử — ghi đè = mất data.

---

## 4. Quick reference

```
ĐỌC (đầu task):
  Lead      → cat .claude/memory/context.md + mistakes.md
  Researcher→ cat .claude/memory/context.md + mistakes.md
  CTO call  → cat .claude/memory/patterns.md

GHI (cuối task):
  Tester fail  → .claude/memory/mistakes.md   (lỗi cụ thể + nguyên nhân)
  Tester pass  → .claude/memory/patterns.md   (stack + cấu trúc thành công)
  Tester luôn  → .claude/memory/context.md    (trạng thái branch + việc tiếp)
  Lead quyết định → .claude/memory/context.md hoặc global.md

FORMAT:  ## YYYY-MM-DD HH:MM — slug-ngắn
APPEND:  cat >> file.md (không bao giờ >)
CAP:     10 entry mới nhất khi đọc
STORE:   .claude/memory/ ≠ company/memory/  (không trộn)
```

---

## 5. Ranh giới — điều KHÔNG làm

| Không làm | Lý do |
|---|---|
| Ghi vào `company/memory/mistakes.md` hoặc `company/memory/patterns.md` | Engine store — bất biến Phase H, HQ không đụng |
| Ghi vào `<project>/memory/context.md` | Per-branch engine store — engine `memory.ps1` quản |
| Dùng Write tool (overwrite) để ghi entry mới | Mất toàn bộ lịch sử entry cũ |
| Ghi entry không có delimiter `## ` | Parser cap-N không nhận ra — entry bị bỏ qua khi đọc |
| Builder ghi memory | Builder chỉ build; memory là việc của tester + lead |
| Đọc memory thay cho đọc brief task | Memory là bối cảnh phụ — brief task (TaskGet) là nguồn sự thật chính |
