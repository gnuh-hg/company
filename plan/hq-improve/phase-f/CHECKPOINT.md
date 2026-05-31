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
| Sessions hoàn thành | 6 | 3 | 50% |
| Sub-phase đóng | 3 (F-I/F-II/F-III) | 1 (F-I) | 33% |
| Server endpoint F | 3 (`/api/run`, `/api/events` SSE, `/api/decision`) | 3 | 100% |
| Done-gate F (HQ mock: live log + highlight → gate → approve → terminal; + reject/đổi nhánh) | pass | — | — |
| `git diff engine/` rỗng mọi session | luôn | ✓ F.1·F.2·F.3 | — |

---

## Đang ở đâu

- **Phase**: F — **Session F.3 DONE** (2026-05-31). Sub-phase F-I (server backend) ĐÓNG. F.3 thêm nút Run + RunLog panel.
- **Session kế tiếp**: **F.4** — highlight node đang chạy trên React Flow (running/done/awaiting) theo event live.
- **Blocker**: — (SSE + RunLog full chain verified: hello run_start→node_output(nội dung thật)→run_end + event:end; bundle chứa EventSource/api/run/api/events/Run(Mock)/node_output).
- **Reference**: `PLAN.md` Phase F → Session F.4.

---

## Per-session log

### 2026-05-31 — Session F.3 (EventSource client + RunLog panel)
- **Done**: (1) **`RunLog.jsx`** (component mới) — renders mỗi loại event thành row: `run_start` (▶ Run started), `node_start` (→ node agent), `node_output` (nội dung thật full trong `<pre>` có scroll max 220px), `node_done` (✓), `awaiting` (⏸ nổi bật nền tím), `resumed` (▶ resumed + decision), `run_end` (■ status màu + terminal), `diff_violation` (⚠ + violations list), fallback raw JSON. Auto-scroll ref khi events.length đổi. Panel header: "Run Log" chip + status pill (màu theo idle/running/done/awaiting/failed) + nút Clear. (2) **`App.jsx`** — thêm run state (runId/events/runStatus/runErr) + `esRef` (EventSource ref cleanup on unmount). Nút **▶ Run (Mock)** trong header: POST /api/run → nhận {runId} → mở EventSource(`/api/events?project=&run=`) → parse events (dedup bằng seq) → update runStatus từ `run_end`/`awaiting`. `event: end` → đóng ES. Selector project thay đổi → clear run state. Layout: `main` split flexColumn (graph flex:1 minHeight:0 / log panel 280px cố định khi showLog). `handleClear` tắt ES + reset state.
- **Output**: `app/src/RunLog.jsx` (mới) + `app/src/App.jsx` (update). Build thành công (487 modules). Bundle chứa EventSource/api/run/api/events/Run(Mock)/node_output.
- **Gate**: ✅ **POST /api/run hello** → {runId, runDir} + events.ndjson EXISTS. ✅ **SSE hello full chain**: run_start→node_start→node_output(output=`[MOCK:echo-a]\nping`, nội dung thật)→node_done→run_end(done)→event:end. ✅ `git diff engine/` = RỖNG.
- **Next**: Session F.4 — highlight node trên React Flow theo event live (running/done/awaiting).
- **Notes**: ⚠️ **`hq`/`loopy`/router projects không ghi `latest.json` khi fail** (router label không khớp `when` → engine throw trước khi ghi). Poll timeout ra 504. Đây là engine behavior (BẤT BIẾN). Workaround: test F.3 gate bằng pipeline projects không có router (hello, web-demo, mem-demo). F.4 dùng `approval-demo` (có `awaiting` real) + `hello` (fast done). pwsh SIGABRT khi spawn từ Node với `/snap/bin/pwsh` — giữ PATH `pwsh` (default).

### 2026-05-31 — Session F.2 (GET /api/events SSE + POST /api/decision)
- **Done**: 2 endpoint additive vào `server.mjs` (E + F.1 bất biến, dependency-free). (1) **`GET /api/events?project=&run=`** — SSE `text/event-stream`: tail `<run>/events.ndjson` theo **byte-offset** (đọc qua `fs.open`+`read` mỗi 300ms), decode-tới-newline-cuối (multibyte UTF-8 không vỡ ở ranh giới tick — `pending` Buffer giữ phần dư), đẩy mỗi dòng NDJSON `data: <line>`; parse `.type==='run_end'` → gửi `event: end` + `res.end()`; heartbeat `: ping` 15s; `req.on('close')` clear timers. (2) **`POST /api/decision {project,run,decision}`** — spawn `run.ps1 resume <p> -Decision <label> [-Mock]` (mock-mode lấy từ run registry, default mock nếu entry mất) → resume ghi tiếp CÙNG `events.ndjson` → SSE đang mở tự đọc byte mới. Guard: `SAFE_PROJECT` cho project+run, decision label regex `^[A-Za-z0-9_-]+$` (chặn command-injection).
- **Output**: `app/server.mjs` (+import `open`; SSE handler + decision handler).
- **Gate**: ✅ **hello mock**: SSE full chain `run_start`→`node_start`/`node_output`(**output nội dung thật** `[MOCK:echo-a]\nping`, không "(N chars)")/`node_done`→`run_end`(done)→`event: end`, đóng sạch. ✅ **approval-demo mock**: SSE giữ mở tại `awaiting` (seq5, KHÔNG run_end) → `POST /api/decision approve` → CÙNG stream chảy tiếp `resumed`→run_start(resume:true)→builder→`run_end`(terminal=builder,done)→`event: end` (**resume nối-tiếp-cùng-run-dir** verified, seq 6→11 cùng file). ✅ Validation: missing param→400 · bad project (`../etc`)→400 · missing decision→400 · bad label (`a b;rm`)→400. ✅ **`git diff engine/` RỖNG**.
- **Next**: Session F.3 — EventSource client + `RunLog` panel (full output, auto-scroll) + nút Run (mock).
- **Notes**: ⚠️ **Hạ tầng quan trọng — node-spawn pwsh**: `/snap/bin/pwsh` bị **SIGABRT** khi spawn từ Node (`code=null`, no output); `pwsh` trên PATH chạy OK (`code=0`, "OK"). Server **PHẢI dùng default `PWSH='pwsh'`** (KHÔNG override `PWSH=/snap/bin/pwsh`). Chạy server: `cd app && PORT=5188 node server.mjs` (run_in_background + `dangerouslyDisableSandbox`). Đây là điểm khác với chạy pwsh tay (tay dùng `/snap/bin/pwsh` được). Verify ở F.3+ phải nhớ.

### 2026-05-31 — Session F.1 (POST /api/run)
- **Done**: Thêm `POST /api/run` vào `server.mjs` (additive — E endpoints bất biến). Run registry `Map<runId→{child,project,runDir,mockMode,status,startedAt}>`. `snapshotLatestRun` + `pollForNewRunDir` race-safe (poll 200ms, timeout 10s, so sánh `latest.json .run`). Default request `"run"` khi omit (engine require non-empty). `child.stdout/stderr.resume()` drain để không block pipe. Server bind `127.0.0.1`. `git diff engine/` = rỗng.
- **Output**: `app/server.mjs` — `POST /api/run` + helper functions.
- **Gate**: ✅ hello (with request) → `{runId,runDir}` + `events.ndjson` EXISTS ✓ | approval-demo (no request) → discovery OK ✓ | project lạ → 404 ✓ | `git diff engine/` rỗng ✓
- **Next**: Session F.2 — `GET /api/events` SSE + `POST /api/decision`.
- **Notes**: Engine từ chối empty request string → server default `"run"`. STOP gate plan viết không có request cho approval-demo — thực tế engine cần; fixed bằng default. Shape `awaiting` event cần verify ở F.2 (xem approval-demo `events.ndjson`).

### 2026-05-31 — Session F.0 (soạn plan)
- **Done**: Đọc ROADMAP §Phase F + 3 §Bàn-giao (D→E/F, E→F/G) + `server.mjs` (E) + `events.ps1` + surface `run.ps1 run/resume/status`. Chốt F-D1..F-D4 với user (poll latest.json / mock-default+Real-confirm / scope chỉ `run` / SSE dependency-free). Soạn `PLAN.md` (3 sub-phase / 6 session) + CHECKPOINT này.
- **Output**: `plan/hq-improve/phase-f/PLAN.md` + `CHECKPOINT.md`.
- **Gate**: n/a (planning). Chờ user duyệt PLAN → mở F.1.
- **Next**: Session F.1.
- **Notes**: F **không sửa engine** — khác các phase build. Verify chính = `git diff engine/` rỗng + đường mock. Race latest.json + resume-nối-tiếp-cùng-run-dir là 2 điểm dễ sai nhất (ghi rõ trong PLAN Context).

---

## Ghi chú kỹ thuật tích luỹ (cập nhật khi phát hiện)

- **Shape event `awaiting`** (✅ xác nhận F.2 — chạy `approval-demo` đọc `events.ndjson`): **TOP-LEVEL, KHÔNG nested**. Ví dụ thật: `{"seq":5,"type":"awaiting","node":"gate","prompt":"Duyệt plan trước khi builder chạy?","choices":["approve"],"step":2}`. → `node` (string id), `prompt` (string), `choices` (mảng phẳng các nhãn `when`, vd `["approve"]`), `step` (int). F.5 approval UI đọc thẳng `evt.node`/`evt.prompt`/`evt.choices`. `resumed` event shape: `{type:"resumed", node, decision, cursor}`. Resume cũng phát thêm 1 `run_start` (resume:true) sau `resumed` — client nên bỏ qua run_start thứ 2 hoặc coi như mốc tiếp tục.
- **latest.json format**: con trỏ `<project>/.runs/latest.json` (status.ps1 `Get-LatestRun` ưu tiên). Snapshot trước spawn để bắt run dir mới.
- **Resume nối tiếp**: `resume -Decision` ghi tiếp CÙNG `events.ndjson` (seq theo số dòng). SSE giữ stream mở, đọc byte mới — KHÔNG mở run dir mới.
- **Exit code run**: 0=done · 3=awaiting · ≠0=fail (nhưng server dựa event, không tin exit).

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-31 | Created from `PLAN.md` | @planner |
| 2026-05-31 | F.2 DONE — `GET /api/events` SSE (byte-offset tail, dependency-free) + `POST /api/decision` (resume nối-tiếp cùng run dir). Verified hello full chain + approval-demo awaiting→approve→terminal. `awaiting` shape = top-level. Engine diff RỖNG. Hạ tầng: node-spawn dùng PATH `pwsh` (snap pwsh SIGABRT) | @claude |
