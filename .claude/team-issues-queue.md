# HQ Team — Issue Queue

> Theo dõi issue phát sinh khi chạy HQ team-of-agents. Format + code phân loại: xem
> `company/.claude/teams/playbook.md` §4.
>
> Ghi khi gặp, resolve xong đánh trạng thái `resolved` + ghi fix.

---

<!-- Thêm issue mới bên dưới, mới nhất ở trên cùng -->

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
