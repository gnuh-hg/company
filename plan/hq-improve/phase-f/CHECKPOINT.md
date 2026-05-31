# CHECKPOINT — Phase F: App II — live log + run control + duyệt (#3)

> Sổ tay tiến độ dài hạn. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu. PLAN immutable: `plan/hq-improve/phase-f/PLAN.md`.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ được làm 1 session** (xem "Đang ở đâu"). **STOP NGAY** khi đạt STOP gate session đó — không tham làm session kế.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log".
- **Bất biến Phase F**: engine KHÔNG đổi — **`git diff engine/` PHẢI rỗng mọi session** (run/resume/status/events đã sẵn từ Phase D, F chỉ shell + gắn UI). `server.mjs` **dependency-free** (Node `http`/`fs`/`child_process` thuần — KHÔNG thêm express/ws). Server bind `127.0.0.1`. Mặc định `-Mock` — KHÔNG đốt token trừ khi user bật Real + confirm dialog.
- **pwsh**: `/snap/bin/pwsh` + `dangerouslyDisableSandbox: true`. **Tin event `run_end` + file, KHÔNG tin child exit code** (core-dump teardown RC=134).
- **Node toolchain** trong `company/app/`: dev `npm run dev` (Vite proxy `/api`→server) · serve `npm run build && node server.mjs` (port 5179). Dọn `.runs/` test sau verify.
- **Quyết định đã chốt (user 2026-05-31)**: F-D1 run-discovery = poll `.runs/latest.json` (zero engine change) · F-D2 mock-default + Real-confirm dialog · F-D3 scope chỉ `run` (autobuild/autofix defer) · F-D4 SSE dependency-free (tail file theo offset).

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 6 | 0 | 0% |
| Sub-phase đóng | 3 (F-I/F-II/F-III) | 0 | 0% |
| Server endpoint F | 3 (`/api/run`, `/api/events` SSE, `/api/decision`) | 0 | 0% |
| Done-gate F (HQ mock: live log + highlight → gate → approve → terminal; + reject/đổi nhánh) | pass | — | — |
| `git diff engine/` rỗng mọi session | luôn | — | — |

---

## Đang ở đâu

- **Phase**: F (App II — live log + run control + duyệt) — **CHƯA bắt đầu** (PLAN vừa soạn 2026-05-31, chờ user duyệt mở session F.1).
- **Session kế tiếp**: **F.1** — `POST /api/run` (spawn `run.ps1 run -Mock`) + run registry + latest.json discovery (race-safe).
- **Blocker**: — (Phase E DONE; engine surface D sẵn; `server.mjs` nền E sẵn).
- **Reference**: `PLAN.md` Phase F → Session F.1.

---

## Per-session log

### 2026-05-31 — Session F.0 (soạn plan)
- **Done**: Đọc ROADMAP §Phase F + 3 §Bàn-giao (D→E/F, E→F/G) + `server.mjs` (E) + `events.ps1` + surface `run.ps1 run/resume/status`. Chốt F-D1..F-D4 với user (poll latest.json / mock-default+Real-confirm / scope chỉ `run` / SSE dependency-free). Soạn `PLAN.md` (3 sub-phase / 6 session) + CHECKPOINT này.
- **Output**: `plan/hq-improve/phase-f/PLAN.md` + `CHECKPOINT.md`.
- **Gate**: n/a (planning). Chờ user duyệt PLAN → mở F.1.
- **Next**: Session F.1.
- **Notes**: F **không sửa engine** — khác các phase build. Verify chính = `git diff engine/` rỗng + đường mock. Race latest.json + resume-nối-tiếp-cùng-run-dir là 2 điểm dễ sai nhất (ghi rõ trong PLAN Context).

---

## Ghi chú kỹ thuật tích luỹ (cập nhật khi phát hiện)

- **Shape event `awaiting`** (xác nhận tại F.2, ghi vào đây): _(chưa xác nhận — chạy `approval-demo` đọc `events.ndjson`)_. Cần để F.5 dựng panel duyệt đúng (`prompt`/`choices[]` nested hay top-level).
- **latest.json format**: con trỏ `<project>/.runs/latest.json` (status.ps1 `Get-LatestRun` ưu tiên). Snapshot trước spawn để bắt run dir mới.
- **Resume nối tiếp**: `resume -Decision` ghi tiếp CÙNG `events.ndjson` (seq theo số dòng). SSE giữ stream mở, đọc byte mới — KHÔNG mở run dir mới.
- **Exit code run**: 0=done · 3=awaiting · ≠0=fail (nhưng server dựa event, không tin exit).

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-31 | Created from `PLAN.md` | @planner |
