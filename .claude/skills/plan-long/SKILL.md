---
name: plan-long
description: "Use when scoping multi-session work that can't finish with quality in one chat (bulk generation ≥100 unit, multi-phase pipeline with human gates, external manual steps). Produces plan/<slug>/PLAN.md + plan/<slug>/CHECKPOINT.md."
---

# Plan-Long — company/

> Form chuẩn cho kế hoạch dài hạn: sinh 2 file (`PLAN.md` + `CHECKPOINT.md`) trong `plan/<slug>/`, ràng buộc "1 chat = 1 session".

## Khi nào dùng

Long-term khi **bất kỳ**:

- Tổng work vượt 1 chat capacity.
- Bulk lặp ≥ 100 unit.
- Có gate quality giữa các phase cần human/script verify.
- Có human-in-the-loop pause (script chạy ngoài, user manual setup).
- User yêu cầu rõ "chia phase" / "checkpoint".

## Output: 2 file đồng bộ trong `plan/<slug>/`

Cả hai đặt trong thư mục `plan/<slug>/` (theo pattern hiện có `plan/hq-build/phase-r/PLAN.md` + `plan/hq-build/phase-r/CHECKPOINT.md`):

1. `plan/<slug>/PLAN.md` — bản thiết kế, immutable sau approve.
2. `plan/<slug>/CHECKPOINT.md` — sổ tay tiến độ, mutable, update sau mỗi session.

Slug: kebab-case từ tên task (vd `gen-narrative-500`, `migrate-supabase-rls`).

## Form `PLAN.md`

```markdown
# PLAN — <tên task>

> [pipeline outcome 1 câu — sau khi xong toàn bộ pipeline ta được gì]

---

## Context

- Vì sao phải chia nhiều session (lý do quy mô / gate / external).
- Ràng buộc external (vd "RunPod cần user thuê tay").
- Scope ngoài plan này (out of scope).

---

## Pipeline N phase / M session

```
[Phase 1] <tên> ──────────────► <artifact 1>
                                    │
[Phase 2] <tên> ──────────────► <artifact 2>
                                    │
[Phase N] <tên> ──────────────► outcome
```

---

## Phase 1 — <tên>

**Mục tiêu**: <1-2 câu>.

### Session 1.1 — <scope ngắn>
- **Scope**: liệt kê công việc tối đa cho 1 chat (vd "sinh 50 examples doc_type=theory chủ đề ML").
- **STOP gate**: <điều kiện dừng cứng, đo được — vd "đủ 50 dòng trong raw_leaves.jsonl", "script validate trả 0 hard error">.
- **Output artifact**: <file/section sẽ được sinh ra>.

### Session 1.2 — ...
- Scope: ...
- STOP gate: ...
- Output artifact: ...

**Phase 1 gate** (sau Session 1.x cuối): <điều kiện sang Phase 2>.

## Phase 2 — <tên>
(tương tự)

## Outcome cuối

- <trạng thái cuối sau Phase N>
- <gate đo lường thành công>

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| YYYY-MM-DD | Initial | — |
```

## Form `CHECKPOINT.md`

```markdown
# CHECKPOINT — <tên task>

> Sổ tay tiến độ dài hạn. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ được làm 1 session** (xem mục "Đang ở đâu" để biết session nào).
- **STOP NGAY** khi đạt STOP gate của session đó — không tham làm session kế tiếp dù còn quota.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry vào "Per-session log".

> **Ngoại lệ team-lead (ai điều phối HQ-team):** quy ước "1 chat = 1 session" **KHÔNG ràng buộc
> team-lead**. Khi user giao cả một phase cho lead mà KHÔNG nói rõ "chỉ làm 1 session / dừng sau
> session X", lead **ngầm hiểu là làm hết** các session của phase liên tiếp trong cùng chat (vẫn
> update CHECKPOINT + STOP gate sau MỖI session để giữ context sạch). Ràng buộc "1 session" **vẫn
> nguyên hiệu lực với teammate** (mỗi teammate chỉ làm đúng 1 task được giao, STOP tại done-criteria)
> và với người tự tay chạy plan-long trực tiếp (không qua team). Lead chỉ dừng giữa phase khi: user
> giới hạn rõ, gặp blocker thật, hoặc cần user-gate (vd duyệt diff self-mod D-S2).

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| <vd Sessions hoàn thành> | <vd 10> | 0 | 0% |
| <vd Unit sinh ra> | <vd 500> | 0 | 0% |
| <vd Gate pass> | <vd ≥75%> | — | — |

---

## Đang ở đâu

- **Phase**: 1
- **Session kế tiếp**: 1.1 — <tóm tắt scope>
- **Blocker** (nếu có): —
- **Reference**: `PLAN.md` Phase 1 → Session 1.1

---

## Per-session log

### YYYY-MM-DD — Session A.B
- **Done**: <những gì đã làm>
- **Output**: <file / artifact đã sinh ra>
- **Gate**: pass / fail (kèm metric)
- **Next**: Session A.(B+1) hoặc Phase tiếp theo
- **Notes**: <vấn đề phát sinh, ghi nhớ>

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| YYYY-MM-DD | Created from `PLAN.md` | @planner |
```

## Rules

1. **PLAN immutable sau approve** — thay đổi qua "Revision log" ở cuối PLAN, không sửa session breakdown trừ khi user yêu cầu rõ.
2. **CHECKPOINT mutable** — update sau mỗi session.
3. **Mỗi session phải có STOP gate đo được**. Không vague ("xong là dừng"). Cụ thể: dòng JSONL = N, script trả 0 error, file tồn tại, v.v.
4. **Mỗi session đủ nhỏ để 1 chat làm xong với chất lượng**. Nếu phải gắng → chia 2 session.
5. **Tên slug kebab-case**, không dấu, không space. Vd `gen-narrative-500`, `migrate-rls`.
6. **Trước khi ghi file** — verify `plan/<slug>/PLAN.md` chưa tồn tại. Nếu có → hỏi user (overwrite vs đổi slug).
7. **Sau khi tạo** — update `company/CLAUDE.md` bảng "Bản đồ file" với hàng mới cho `plan/<slug>/`; nếu là 1 phase ROADMAP thì update bảng tiến độ cuối `ROADMAP.md`.

## Anti-pattern

| Sai | Sửa |
| --- | --- |
| Session quá to ("sinh 500 examples 1 session") | Chia thành 10 session × 50 |
| STOP gate là "khi nào thấy đủ" | Đo được: "đủ N dòng JSONL" |
| Chỉ có PLAN, không có CHECKPOINT | Bắt buộc cả 2 file |
| CHECKPOINT không có "Constraint reminder" ở đầu | Reminder phải là section đầu tiên — Claude đọc top-down |
| Update CHECKPOINT sau khi đóng chat | Phải update TRƯỚC khi đóng — nếu không session sau mất context |

## Reference patterns đã có

- `plan/hq-build/phase-r/PLAN.md` — pipeline 3 sub-phase / 5 session, có Context + diagram + Phase blocks + done-gate checklist.
- `plan/hq-build/phase-r/CHECKPOINT.md` — Constraint reminder ở đầu + bảng tiến độ + per-session log.

Khi viết file mới, copy structure từ 2 file này; bắt buộc giữ **Constraint reminder** ở đầu CHECKPOINT.
