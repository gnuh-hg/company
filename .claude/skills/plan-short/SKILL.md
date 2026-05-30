---
name: plan-short
description: "Use when scoping a task that can be completed with quality in a single chat session (≤10 file touches, no cross-session resume, no human gate mid-way). Produces an inline phased plan — no file artifact."
---

# Plan-Short — company/

> Form chuẩn cho kế hoạch ngắn hạn: đủ chi tiết để thực thi ngay trong chat hiện tại, không cần checkpoint.

## Khi nào dùng

Short-term khi:

- Ước lượng ≤ 1 chat hoàn thành chất lượng.
- ≤ ~10 file touches.
- Không có gate human verify giữa các phase.
- Không có bulk ≥ 100 unit.

Nếu **bất kỳ** điều trên sai → dùng `plan-long` thay.

## Form chuẩn

Output **inline trong response** — không tạo file `.md` riêng:

```markdown
# Plan: <tên task ngắn>
> [outcome 1 câu — sau khi xong người dùng được gì]

## Context
- Vì sao bây giờ
- Scope (in scope / out of scope)
- Ràng buộc (vd Phase 1 only, không động backend, etc.)

## Phases
### Phase 1 — <tên ngắn>
- [ ] Step cụ thể (động từ + đối tượng, vd "Tạo `src/services/x.ts` với function getX()")
- [ ] Step cụ thể
- **Gate**: <điều kiện verify được trước khi sang Phase 2>

### Phase 2 — <tên ngắn>
- [ ] ...
- **Gate**: <điều kiện verify>

## Verification
- Test end-to-end: <cách run thật>
- Files dự kiến sẽ tạo/sửa: liệt kê path cụ thể
```

## Rules

1. **Mỗi phase phải có gate kiểm chứng được**. Không gate = không phase. Gate dạng "code chạy không lỗi" thì OK, "code đẹp hơn" thì KHÔNG.
2. **Steps là động từ + đối tượng cụ thể**. Tốt: "Thêm endpoint `POST /api/v1/x` trả `XOut`". Xấu: "Improve X module".
3. **2-5 phase là đủ**. Nhiều hơn → có thể là long-term ẩn, kiểm tra lại rubric.
4. **Không cần per-session log** vì làm trong 1 chat liền mạch.
5. **Liệt kê file path cụ thể** trong Verification — sau khi xong dễ verify đúng scope.

## Anti-pattern

| Sai | Sửa |
| --- | --- |
| Phase chỉ có 1 step | Gom vào phase khác hoặc mở rộng |
| Gate là "ok" / "done" | Viết điều kiện cụ thể: "build pass 0 error", "endpoint trả 200" |
| 8+ phase với 1-2 step mỗi cái | Gom thành 3-4 phase ý nghĩa |
| Step "Refactor X" không nói refactor cái gì | Chia thành step nhỏ với đối tượng cụ thể |

## Sau khi viết plan

- Hỏi user approve (1 câu, ngắn).
- Nếu OK → execute luôn trong chat. Tick checkbox khi xong từng step.
- Nếu giữa chừng phát hiện scope thực ra long-term → dừng, thông báo user, chuyển sang `plan-long`.
