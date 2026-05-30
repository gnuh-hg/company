# patterns.md — Pattern thực chiến tái dùng (HQ-global)

> Tầng: **HQ-global** · Bridge key: `{{mem_patterns}}` (gộp cả `global.md` — xem README) · Đọc: vai đầu-não đầu vòng đời · Ghi: node `record` (`memory_write: patterns`).
>
> Mục đích: pattern đã chứng minh hiệu quả để run sau **tái dùng**, khỏi nghĩ lại từ đầu.

## Format entry (đo được)

Mỗi entry là 1 block, mở bằng delimiter `## <YYYY-MM-DD HH:MM> — <slug>` rồi 3 field cố định:

```
## 2026-05-27 14:30 — vd-slug-pattern
- **Vấn đề**: bài toán pattern này giải.
- **Cách**: cách làm / implementation cốt lõi.
- **Caveats**: điều kiện áp dụng + bẫy cần tránh.
```

Read-path (`Get-Memory`) split theo delimiter `## ` → giữ **N=10 block cuối** → nạp vào `{{mem_patterns}}`. Node `record` **append** block mới xuống cuối file.

---

<!-- entries below, mới nhất ở cuối -->
