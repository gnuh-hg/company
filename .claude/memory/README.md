# `.claude/memory/` — HQ-team store

> Store **làm việc của HQ-team** (lead + teammate). TÁCH BẠCH với engine branch store
> `company/memory/` + `<project>/memory/` — đừng trộn. Xem `plan/hq-v2/phase-h/design.md` §3–§4.

## Phân biệt 2 store

| Store | Ai đọc/ghi | Bất biến? |
|---|---|---|
| `company/.claude/memory/` (đây) | HQ-team lead + tester qua skill `hq-memory` | sống — team ghi mỗi task |
| `company/memory/` (HQ-global engine) | engine `memory.ps1` → node `record` | **BẤT BIẾN** Phase H |
| `<project>/memory/` (per-branch engine) | engine `Write-MemoryEntry` type `context` | **BẤT BIẾN** Phase H |

⚠️ Team HQ-native **KHÔNG** ghi vào engine store. Bài học từ chi nhánh → ghi vào
`mistakes.md` / `patterns.md` ở đây.

## 4 file

| File | Ai ghi | Ai đọc | Nội dung |
|---|---|---|---|
| `context.md` | Lead / tester | Lead đầu task | Bối cảnh: branch đang build, trạng thái, quyết định gần đây |
| `mistakes.md` | Lead / tester | Lead + researcher | Lỗi thực tế (builder fail, spec hỏng, engine error) — không tái phạm |
| `patterns.md` | Lead / tester | Lead + cto | Pattern thành công (loại request → cách build hiệu quả) |
| `global.md` | Lead | Lead | Cross-cutting: con người, quyết định kiến trúc, phạm vi engine |

## Format entry (mirror engine memory)

```
## <YYYY-MM-DD HH:MM> — <slug-ngắn>
<nội dung>
```

- **Delimiter**: heading `## ` mở mỗi entry.
- **Cap N = 10**: chỉ 10 entry mới nhất được load khi đọc (cũ hơn vẫn lưu trong file, bỏ qua lúc đọc).
- **Đọc**: đầu task — lead thường load `context.md` + `mistakes.md` trước khi giao việc (qua skill `hq-memory`, soạn ở H.8).
- **Ghi**: cuối task — append 1 entry vào đúng file theo loại.
