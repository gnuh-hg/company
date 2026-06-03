# mistakes — HQ-team

> Lỗi thực tế đã gặp (builder fail, spec hỏng, engine error) — ghi để không tái phạm.
> Format entry: `## <YYYY-MM-DD HH:MM> — <slug>`. Cap N=10 khi đọc. Xem `README.md`.

<!-- entries below, mới nhất ở cuối -->

## 2026-06-03 10:50 — teamcreate-wrong-recipient

TeamCreate đặt lead name = "team-lead". Tất cả hq-*.md đã hardcode `SendMessage(to="hq-lead")` → message bị treat như peer DM, chỉ hiện summary trong idle_notification, không deliver đầy đủ đến lead. Fix: luôn dùng `to="team-lead"` trong agent body. Đã sửa tất cả 5 file 2026-06-03.

## 2026-06-03 10:55 — agent-output-not-in-message

Agent body dùng shorthand "Output/Plan/Thiết kế trong task" trong SendMessage → lead nhận signal "done" nhưng không có nội dung để đọc (TaskGet phải gọi thủ công). Fix: SendMessage phải paste TOÀN BỘ output inline. Đã sửa tất cả 5 file 2026-06-03.

## 2026-06-03 09:45 — agent-tools-allowlist-strips-team-tools

5 file hq-*.md đặt `tools:` allowlist hẹp (vd researcher `[Read, Grep, Glob, WebSearch]`, planner `[Read]`). Khi spawn làm teammate qua Agent Teams, allowlist tường minh LOẠI luôn tool điều phối (SendMessage/TaskGet/TaskUpdate/TaskList) → teammate research/plan xong nhưng KHÔNG thể report hay TaskUpdate → cả team câm, lead chỉ thấy idle_notification rỗng. Researcher tự chẩn đúng: "TaskUpdate và SendMessage không khả dụng". Fix: thêm `TaskGet, TaskUpdate, TaskList, SendMessage` vào `tools:` của cả 5 agent (đã sửa 2026-06-03). Bài học: agent dùng làm team teammate PHẢI có team-coordination tools trong allowlist, nếu không câm hoàn toàn. Phát hiện khi chạy thật H.10.
