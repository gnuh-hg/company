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
| Sessions hoàn thành | 6 | 6 | 100% ✅ |
| Sub-phase done (K.A/K.B/K.C) | 3 | 3 (K.A,K.B,K.C) | 100% ✅ |
| selftest mục | 11 (từ 10) | 11 | ✅ |
| Done-gate tổng (K.6) | 4/4 | 4/4 | ✅ |

---

## Đang ở đâu

- **Phase**: ✅ PHASE K HOÀN TẤT (K.A + K.B + K.C DONE, 2026-06-04)
- **Session kế tiếp**: — (không còn). Chờ user duyệt git diff (D-S2) → commit.
- **Blocker**: —
- **Reference**: done-gate tổng 4/4 PASS · selftest 11/11 · git scope sạch

---

## Per-session log

### 2026-06-04 — Session K.1
- Done: validate.ps1 pause enum (none|always|ask) + cấm pause trên approval node + user_answer vào ReservedKeys; workflow.ps1 Initialize-Context pre-seed user_answer=''; fixture examples/ask-demo/ (clarify pause:ask → build → terminal + 2 agent stub)
- Output: engine/validate.ps1, engine/workflow.ps1, examples/ask-demo/{workflow.json,agents/clarify.md,agents/build.md}
- Gate: PASS — selftest 10/10, validate ask-demo exit 0, validate hello exit 0, run hello -Mock done, ca âm pause:bogus → exit 1 (lỗi enum rõ), ca âm pause trên approval → lỗi rõ
- Next: Session K.2 — Get-AskRequest + pause:ask → awaiting_input
- Notes: self-tester verify độc lập (tmp copy cho ca âm, đã dọn). KHÔNG đụng .claude/agents → không cần re-spawn smoke. Changelog draft chờ user duyệt cuối phase.

### 2026-06-04 — Session K.2
- Done: workflow.ps1 helper thuần Get-AskRequest (parse marker ASK_USER:) + pause:ask pause-path (sau node_output event, trước ghi output_key) → state awaiting_input + event awaiting kind=input; graph.ps1 ConvertTo-NormNode passthrough field `pause`
- Output: engine/workflow.ps1, engine/graph.ps1
- Gate: PASS (10/10 criteria) — ask-demo mock → status=awaiting_input, awaiting.kind=input, question có nội dung, output_key spec.txt CHƯA ghi; selftest 10/10; approval-demo D.3 bất biến; validate hello exit 0; run hello -Mock done
- Next: Session K.3 — resume -Answer re-run node
- Notes: Phase K.A DONE. Mock dùng ENGINE_MOCK_ROUTER="clarify:ASK_USER: ...". KHÔNG đụng .claude/agents.

### 2026-06-04 — Session K.3
- Done: workflow.ps1 Invoke-Workflow -Answer param + nhánh awaiting_input resume (tách riêng D.3 qua guard `-not $awaitingInputResume`, cursor=node-hỏi re-run, tiêm user_answer, iter++); run.ps1 -Answer flag + truyền vào resume (pull-forward từ K.5)
- Output: engine/workflow.ps1, engine/run.ps1
- Gate: PASS (11/11) — full round-trip ask-demo: run→awaiting_input → resume -Answer "dùng màu xanh" → done; 2-clarify.prompt.txt chứa answer; result.txt tồn tại; event resumed kind=input; selftest 10/10; approval-demo D.3 bất biến (line 484 mutually exclusive)
- Next: Session K.4 — pause:always run-then-gate
- Notes: Mock run1 set marker, resume KHÔNG set ENGINE_MOCK_ROUTER (default mock không có ASK_USER:) → re-run hoàn thành. K.5 giảm scope (run.ps1 -Answer đã xong).

### 2026-06-04 — Session K.4
- Done: workflow.ps1 pause:always run-then-gate (output_key ghi TRƯỚC pause line 784, reuse awaiting/approval D.3 resume) + AutoApprove skip always + AutoApprove fail-rõ với pause:ask; fixture examples/always-demo/ (work pause:always → report) riêng để không phá K.3 round-trip
- Output: engine/workflow.ps1, examples/always-demo/{workflow.json,agents/work.md,agents/report.md}
- Gate: PASS (11/11) — always-demo run→awaiting kind=approval, work_out.txt pre-pause; resume -Decision approve → done; AutoApprove always=skip ask=fail-rõ; selftest 10/10; approval-demo D.3 bất biến
- Next: Session K.5 — status.ps1 surface + selftest #11
- Notes: Phase K.B DONE. Fixture riêng always-demo (không sửa ask-demo). enum pause 3 giá trị hoàn chỉnh.

### 2026-06-04 — Session K.5
- Done: run.ps1 run/resume return 4 + in hint -Answer + câu hỏi khi awaiting_input + Show-Help dòng resume; status.ps1 awaiting_input surface (question+hint, Get-StatusColor/Get-VisitMark ⏸); events.ps1 comment kind=approval|input; test-runner.ps1 selftest #11 ask-demo/done-gate (10→11)
- Output: engine/run.ps1, engine/status.ps1, engine/events.ps1, engine/test-runner.ps1
- Gate: PASS (12/12) — selftest 11/11 (mục #11 ask-demo/done-gate PASS, approval-demo + branchy bất biến); run ask-demo exit=4+hint+question; resume -Answer→done; status surface; validate hello exit 0; run hello -Mock done
- Next: Session K.6 — viz marker + docs + done-gate 4/4
- Notes: baseline selftest GIỜ = 11/11. run.ps1 -Answer parse đã có từ K.3.

### 2026-06-04 — Session K.6 (CUỐI)
- Done: viz.ps1 tag ⏸ask/⏸always (ASCII + Mermaid, approval hexagon + branch diamond bất biến); docs CLAUDE.md (file-map + bất biến #2 + phase-k ✅), README.md (section pause-policy + resume -Answer + selftest 11), ROADMAP Phase K ✅ DONE
- Output: engine/viz.ps1, company/README.md, company/CLAUDE.md, plan/hq-v2/ROADMAP.md
- Gate: PASS — done-gate tổng 4/4 (ask round-trip; always round-trip; selftest 11/11 none/cũ bất biến; validate+run+viz pause marker); git scope sạch (KHÔNG đụng projects/ hay .claude/agents/)
- Next: — (Phase K HOÀN TẤT). Chờ user duyệt git diff → commit (D-S2).
- Notes: Phase K.C DONE. Self-tester chuẩn bị changelog draft tổng hợp self-mod/phase-K-HITL-pause-policy (append global.md SAU khi user approve).


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
