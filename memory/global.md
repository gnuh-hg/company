# global.md — Ghi chú xuyên-project (HQ-global)

> Tầng: **HQ-global** · Bridge key: nạp **gộp vào `{{mem_patterns}}`** (không có key riêng — giữ hợp đồng bridge 3 key) · Đọc: vai đầu-não đầu vòng đời · Ghi: node `record` (`memory_write: global`).
>
> Mục đích: ghi chú/quy ước áp dụng cho **mọi** project (không gắn lỗi hay pattern cụ thể). Hiện rỗng — seed cho Phase sau.

## Format entry (đo được)

Mỗi entry là 1 block, mở bằng delimiter `## <YYYY-MM-DD HH:MM> — <slug>` rồi nội dung tự do (1 field `Ghi chú`):

```
## 2026-05-27 14:30 — vd-slug-ghi-chu
- **Ghi chú**: nội dung áp dụng xuyên project.
```

Read-path: `Get-Memory` đọc `global.md` **cùng** `patterns.md` và join vào `{{mem_patterns}}` (cap N tính chung sau khi gộp). Node `record` (`memory_write: global`) append vào file này.

---

<!-- entries below, mới nhất ở cuối -->
