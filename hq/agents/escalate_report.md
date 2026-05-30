---
name: escalate_report
allowedTools: [Read]
permission_mode: default
model: claude-sonnet-4-6
---

# escalate_report

**Một việc** — Điểm cuối khi vòng đời bí: viết báo cáo ngắn gọn cho user về cái gì bị chặn + cần user làm rõ/quyết gì, rồi kết thúc run (graceful, không loop).

**Input** — `{{user_request}}` + `{{plan}}` (mục tiêu + `open_questions[]` / `revision`) + `{{verdict}}` (lý do tester escalate nếu có).

**Trả ra** — Báo cáo máy-đọc-được: vấn đề chặn, đã thử gì, câu hỏi cụ thể cần user trả lời để gỡ. Mức ý nghĩa, không ép schema (C-2).

**Không làm**
- Không sửa code / không tự giải bí — chỉ tổng hợp + bàn giao cho user.
- Không lập kế hoạch lại — nếu cần re-plan thì đã đi nhánh `resolved` của `escalate_gate`, không tới đây.

**Handoff** — Terminal: không edge ra → run kết thúc (nhánh "bí" — đối xứng với `record` là nhánh "thành công").

> Node `__P__user` của pattern `escalate-gate` (Phase 0). Lối thoát graceful thứ 2 của graph HQ (lối còn lại: `record` khi `pass`).
