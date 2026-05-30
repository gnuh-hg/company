# mistakes.md — Lỗi đã gặp (HQ-global)

> Tầng: **HQ-global** · Bridge key: `{{mem_mistakes}}` · Đọc: mọi vai đầu-não (researcher/planner) đầu vòng đời · Ghi: node `record` (`memory_write: mistakes`).
>
> Mục đích: ghi lại lỗi đã gặp để run sau **đọc + tránh lặp**. Bài học tái dùng xuyên branch.

## Format entry (đo được)

Mỗi entry là 1 block, mở bằng delimiter `## <YYYY-MM-DD HH:MM> — <slug>` rồi 4 field cố định:

```
## 2026-05-27 14:30 — vd-slug-mo-ta-ngan
- **Triệu chứng**: hiện tượng quan sát được (lỗi/sai output).
- **Root cause**: nguyên nhân gốc.
- **Fix**: cách đã sửa.
- **Phòng tránh**: cách tránh lặp ở lần sau.
```

Read-path (`Get-Memory`) split theo delimiter `## ` → giữ **N=10 block cuối** → nạp vào `{{mem_mistakes}}`. Node `record` **append** block mới xuống cuối file (mới nhất ở dưới).

---

<!-- entries below, mới nhất ở cuối -->
