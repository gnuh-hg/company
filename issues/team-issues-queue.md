# HQ Team — Issue Queue

> Theo dõi issue phát sinh khi chạy HQ team-of-agents. Format + code phân loại: xem
> `company/.claude/teams/playbook.md` §4.
>
> Ghi khi gặp, resolve xong đánh trạng thái `resolved` + ghi fix.

---

<!-- Thêm issue mới bên dưới, mới nhất ở trên cùng -->

## 2026-06-03 — SILENT-COMPLETE — tất cả agent body dùng "trong task" thay vì paste output

- **Code**: SILENT-COMPLETE (systemic, tất cả 5 agent)
- **Session**: H.10 done-gate
- **Mô tả**: planner/cto/builder/tester dùng shorthand "Plan/Thiết kế/Chi tiết trong task" trong SendMessage template. Lead không đọc được output vì không có cơ chế TaskGet automatic sau mỗi message. Kết quả: lead nhận được signal "done" nhưng không có nội dung.
- **Fix**: Sửa tất cả 4 agent body — SendMessage phải PASTE đầy đủ output inline. Done.
- **Status**: resolved 2026-06-03 (edit: hq-planner/cto/builder/tester.md)

## 2026-06-03 — WRONG-RECIPIENT — tất cả agent dùng `to="hq-lead"` (team name = "team-lead")

- **Code**: OTHER (wrong SendMessage recipient)
- **Session**: H.10 done-gate
- **Mô tả**: Tất cả 5 agent body hardcode `SendMessage(to="hq-lead")`. TeamCreate đặt lead name = "team-lead". System treat message đến "hq-lead" như peer DM → chỉ hiện summary trong idle_notification, không deliver đầy đủ đến lead.
- **Root cause**: Agent body viết "hq-lead" theo tên team HQ, nhưng TeamCreate tự đặt name="team-lead" cho lead session.
- **Fix**: sed replace tất cả `to="hq-lead"` → `to="team-lead"` trong 5 agent body. Done.
- **Status**: resolved 2026-06-03 (edit: tất cả hq-*.md)

## 2026-06-02 — SILENT-COMPLETE — researcher completed task #1 không SendMessage output

- **Code**: SILENT-COMPLETE
- **Session**: H.10 done-gate
- **Mô tả**: hq-researcher TaskUpdate completed nhưng không SendMessage research output về lead. Idle notification summary có "[to hq-lead] Research output đầy đủ task #1" nhưng không phải message thật — lead không nhận được content.
- **Root cause**: Brief spawn không có instruction tường minh "khi xong: TaskUpdate completed → SendMessage full output về lead". Researcher tự hiểu "xong = done".
- **Root cause**: Agent body line 114 dạy gửi `"Output trong task"` nhưng không có instruction `TaskUpdate` description với actual output. Lead không tìm được output từ kênh nào.
- **Fix**: Sửa hq-researcher.md — `SendMessage` phải paste TOÀN BỘ output (không shorthand "trong task"). Done.
- **Status**: resolved 2026-06-02 (edit: hq-researcher.md line 114)

## 2026-06-02 15:XX — FORM/LEAD — lead dùng Agent tool thay vì TeamCreate

- **Code**: FORM (lead anti-pattern — dùng sai tool)
- **Session**: H.10 done-gate (lần chạy thật đầu tiên)
- **Mô tả**: Lead spawn researcher bằng `Agent` tool generic thay vì `TeamCreate` + `SendMessage`. Hệ quả: teammate không vào team, không có shared task list, không có idle notification, không đúng luồng native agent teams.
- **Root cause**: Lead chưa load schema `TeamCreate`/`SendMessage` trước khi bắt đầu; Agent tool quen tay hơn TeamCreate.
- **Fix**: Tạo team đúng bằng `TeamCreate` → `TaskCreate` → spawn teammate qua `Agent(team_name=...)` → `SendMessage` để giao việc.
- **Status**: resolved (đã sửa ngay trong session)

## 2026-06-03 10:05 — SILENT — teammate câm do tools allowlist
- **Teammate**: cả 5 hq-* (lộ ở researcher trước)
- **Triệu chứng**: teammate ack ready + làm việc nội bộ nhưng KHÔNG report; lead chỉ thấy idle_notification rỗng; TaskGet vẫn in_progress. Researcher tự nói "TaskUpdate/SendMessage không khả dụng".
- **Root cause**: `tools:` allowlist hẹp (không có Task*/SendMessage) → CC strip tool điều phối khi spawn teammate.
- **Trạng thái**: resolved
- **Fix**: [RESOLVED 2026-06-03 edit:agent-body] thêm `TaskGet, TaskUpdate, TaskList, SendMessage` vào `tools:` cả 5 hq-*.md + note ở hq-master roster table. Xem mistakes.md `agent-tools-allowlist-strips-team-tools`.
