# CHECKPOINT — Phase H: HQ team-of-agents native

> Sổ tay tiến độ dài hạn. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu. Đọc kèm `PLAN.md` (immutable) cùng thư mục.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu"). CD-1: **1 session = 1 teammate HOẶC 1 skill** (chất lượng).
- **STOP NGAY** khi đạt STOP gate của session đó — không tham làm session kế dù còn quota.
- **H KHÔNG sửa engine.** Mọi session: trước khi đóng chạy regression — `./run.ps1 validate hello` exit 0 · `./run.ps1 run hello "x" -Mock` done · `./run.ps1 selftest` PASS · `git diff engine/` RỖNG. Engine chỉ được GỌI như tool, không sửa (sửa engine để dành Phase I/J/K).
- **Mock-first.** KHÔNG spawn team thật / KHÔNG chạy engine real cho tới H.10 (đốt token, user-gate). H.0–H.9 = authoring + mock regression.
- **Memory 2 store tách bạch:** `.claude/memory/` = HQ-team; `company/memory/`+`<project>/memory/` = engine branch (BẤT BIẾN). Đừng trộn.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log". Dọn `.runs/` test sau verify.

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 11 (H.0–H.10) | 1 (H.0) | 9% |
| design.md (9 mục) | 1 | 1 ✅ | 100% |
| Teammate def (`.claude/agents/hq-*`) | 5 | 0 | 0% |
| Skill project-scope | 2 | 0 | 0% |
| Nền (flag+memory+playbook) | 3 artifact | 0 | 0% |
| Done-gate checklist | 11 tick | 1 (design.md) | 9% |
| Regression 3-lệnh | PASS mỗi session | PASS (H.0) | — |

---

## Đang ở đâu

- **Phase**: H.1 (Nền team)
- **Session kế tiếp**: H.1 — bật flag `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` trong `settings.json`, verify CC ≥ 2.1.32, scaffold `.claude/{memory/*,teams/playbook.md}` skeleton + `hq-master.md`
- **Blocker**: chưa verify `claude --version` ≥ 2.1.32 (kiểm đầu H.1; nếu < → blocker cần user nâng cấp trước khi team chạy thật H.10)
- **Reference**: `PLAN.md` Phase H.1 → Session H.1; `design.md` §3 (bố cục .claude/) + §4 (memory schema)

---

## Per-session log

### 2026-06-02 — Session H.0 — Viết design.md

- **Done**: viết `plan/hq-v2/phase-h/design.md` đủ 9 mục theo PLAN.md H.0. Chốt: (1) flow orchestration ĐỘNG (prose, không DAG) + gate cũ tan vào lead; (2) roster 5 teammate `hq-*` + 6 thành phần không-thành-teammate có lý do; (3) bố cục `.claude/` cây đích; (4) memory 2-store tách bạch (engine `memory.ps1` bất biến); (5) hợp đồng engine-as-tool (7 lệnh + cách đọc kết quả); (6) quality-gate convention-trong-body, hook defer I/K; (7) skill inventory 2 skill (engine-ops + hq-memory) — `patch` không còn (builder dùng autobuild); (8) legacy giữ tham chiếu; (9) done-gate checklist + token baseline ước tính ~20–30k tokens HQ-workflow cũ.
- **Output**: `plan/hq-v2/phase-h/design.md`.
- **Gate**: design.md tồn tại + 9 mục đủ + mỗi mục có quyết định cụ thể (không TBD) + roster 5 teammate đúng + bố cục cây + memory khẳng định engine bất biến ✅
- **Regression**: validate hello exit 0 ✅ · run hello -Mock done ✅ · `git diff engine/` = 0 byte ✅ (selftest defer — chưa thay đổi gì)
- **Next**: Session H.1 — bật flag, scaffold `.claude/memory/` + `teams/playbook.md` + `hq-master.md`.
- **Notes**: Convention tên `hq-` tiền tố để tránh nhầm META planner. `patch` skill bỏ (builder H-native không Write/Edit trực tiếp). Hook quality-gate defer Phase I/K.

### 2026-06-02 — Phase H long-plan tạo (chưa phải session H.0)
- **Done**: soạn `PLAN.md` + `CHECKPOINT.md`; chốt 5 quyết định kiến trúc với user (orchestration native team · builder qua engine · teammate gọi engine trực tiếp · memory→`.claude/memory/` tách store · legacy giữ+dọn-cuối-roadmap); đọc docs agent-teams chính thức.
- **Output**: `plan/hq-v2/phase-h/{PLAN,CHECKPOINT}.md`.
- **Gate**: n/a (planning).
- **Next**: Session H.0 — viết `design.md`.
- **Notes**: Agent teams experimental (flag + CC ≥2.1.32). Teammate skills frontmatter bị bỏ qua → skill phải project-scope. Quality-gate có thể dùng hook `TaskCompleted`/`TeammateIdle` chạy `run.ps1 check` — chốt cơ chế ở H.0 mục 6.

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-06-02 | Created from `PLAN.md` | @planner |
