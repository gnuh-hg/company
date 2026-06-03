# CHECKPOINT — Phase K: HITL hợp nhất (pause-policy + hỏi-user, CD-3)

> Sổ tay tiến độ dài hạn. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu.
> Long-plan nguồn: `plan/hq-v2/phase-k/PLAN.md` (immutable). ROADMAP: `plan/hq-v2/ROADMAP.md`.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ được làm 1 session** (xem "Đang ở đâu"). **STOP NGAY** khi đạt STOP gate — không tham
  làm session kế tiếp dù còn quota.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log".
- **Regression chuẩn MỖI session chạm engine** (bắt buộc, từ `company/engine/`):
  `./run.ps1 validate hello` exit 0 · `./run.ps1 run hello "x" -Mock` done · `./run.ps1 selftest` PASS
  (10 mục hiện tại; K.5 nâng 11). Dọn `.runs/` test sau verify.
- **Bất biến tuyệt đối**: mock-path (`-Mock` + `ENGINE_MOCK_ROUTER`) KHÔNG đổi hành vi; `workflow.json`
  không lưu toạ độ; sửa engine ở HÀM THUẦN; chỉ thao tác trong `company/`. **KHÔNG phá nhánh resume
  `awaiting` (approval, D.3)** — Phase K thêm nhánh `awaiting_input` SONG SONG.

> **Ngoại lệ team-lead:** nếu user giao cả Phase K cho lead mà KHÔNG giới hạn session, lead làm hết 6
> session liên tiếp trong cùng chat (vẫn update CHECKPOINT + chạy regression sau MỖI session). Dừng giữa
> phase chỉ khi: user giới hạn rõ, blocker thật, hoặc cần user-gate.

---

## Quyết định đã CHỐT (user 2026-06-04) — không hỏi lại

| # | Chốt |
|---|---|
| D-K1 | Tín hiệu `ask` = marker `ASK_USER: <câu hỏi>` (helper `Get-AskRequest`), mock qua `ENGINE_MOCK_ROUTER`. Forced tool-use defer. |
| D-K2 | Tiêm answer = **re-run node đã hỏi** với `{{user_answer}}` (cursor giữ nguyên, không advance). |
| D-K3 | Pause-policy đầy đủ `pause: none\|always\|ask` trên worker; `type:approval` cũ giữ nguyên. `always` = run agent XONG rồi gate. |
| D-K4 | State mới `awaiting_input` + reuse event `awaiting` + field `kind: approval\|input`. KHÔNG thêm loại event. |

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 6 | 0 | 0% |
| Sub-phase done (K.A/K.B/K.C) | 3 | 0 | 0% |
| selftest mục | 11 (từ 10) | 10 | — |
| Done-gate tổng (K.6) | 4/4 | — | — |

---

## Đang ở đâu

- **Phase**: K.A — Foundation
- **Session kế tiếp**: K.1 — Schema `pause` enum + validate + `user_answer` reserved + fixture `ask-demo` skeleton
- **Blocker**: —
- **Reference**: `PLAN.md` → Phase K.A → Session K.1

---

## Per-session log

_(chưa có session nào — điền sau mỗi session theo mẫu dưới)_

```
### YYYY-MM-DD — Session K.x
- Done: <những gì đã làm>
- Output: <file/artifact>
- Gate: pass/fail (kèm metric — vd selftest N/N, validate exit 0, awaiting_input đạt)
- Next: Session K.(x+1) / Phase tiếp
- Notes: <vấn đề phát sinh>
```

---

## Bản đồ session (tóm tắt từ PLAN)

| Session | Scope 1 dòng | STOP gate cốt lõi | File chính |
|---|---|---|---|
| K.1 | pause enum + user_answer reserved + ask-demo fixture | validate ask-demo exit 0 + ca `pause:bogus` fail | validate.ps1, workflow.ps1 (ctx), examples/ask-demo/ |
| K.2 | Get-AskRequest + pause:ask → awaiting_input | run mock → status awaiting_input, kind=input, output_key chưa ghi | workflow.ps1 |
| K.3 | resume -Answer → tiêm user_answer → re-run node | resume -Answer → done + prompt re-run chứa answer | workflow.ps1 |
| K.4 | pause:always run-then-gate + AutoApprove mở rộng | always → awaiting approval → resume -Decision → done | workflow.ps1 |
| K.5 | run.ps1 -Answer + status + selftest #11 | selftest 11/11 + CLI -Answer round-trip | run.ps1, status.ps1, test-runner.ps1 |
| K.6 | viz pause marker + docs + done-gate 4/4 | done-gate 4/4 + selftest 11/11 + git diff in-scope | viz.ps1, CLAUDE.md, README, ROADMAP |

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-06-04 | Created from `PLAN.md` | @planner |
