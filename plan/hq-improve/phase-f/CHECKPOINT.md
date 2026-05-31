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
| Sessions hoàn thành | 6 | 6 | 100% |
| Sub-phase đóng | 3 (F-I/F-II/F-III) | 3 | 100% |
| Server endpoint F | 3 (`/api/run`, `/api/events` SSE, `/api/decision`) | 3 | 100% |
| Done-gate F (HQ mock: live log + highlight → gate → approve → terminal; + reject/đổi nhánh) | pass | ✅ F.5 verified server-driven (approval-demo mock awaiting→approve→terminal) | — |
| `git diff engine/` rỗng mọi session | luôn | ✓ F.1·F.2·F.3·F.4·F.5·F.6 | — |

---

## Đang ở đâu

- **Phase**: F — **✅ PHASE F ĐÓNG (user duyệt 2026-06-01)**. Done-gate đạt đủ; live UX hardening hoàn tất sau F.6.
- **Session kế tiếp**: — (Phase F đóng). Nếu tiếp theo → **Phase G** (in-app edit, tuỳ chọn). Watch-item bàn giao: HQ agent/router robustness (router trả nhãn ngoài tập `when` → hard-fail) — KHÔNG thuộc app, là việc engine/agent-content phase sau.
- **Blocker**: —
- **Reference**: ROADMAP §Bàn-giao-F→G.

---

## Per-session log

### 2026-06-01 — F.6-followup (live UX hardening qua user gate) + ĐÓNG PHASE
- **Bối cảnh**: User chạy thử trên `npm run serve` (live), lộ 3 lỗi run-control + 1 gap UX mà mock-only của F.1–F.6 không bắt. Tất cả **app-only** (`git diff engine/` vẫn RỖNG).
- **Done**:
  1. **cwd spawn** (`server.mjs`) — spawn `run.ps1` từ `cwd: ENGINE_DIR` thay vì `COMPANY`. Từ COMPANY, `Resolve-ProjectDir hq` trả path **tương đối** `hq` (vì `Test-Path hq` đúng) → real claude CLI (sau Push-Location sang project dir) resolve `--system-prompt-file` thành `hq/hq/agents/coo.md` (DOUBLE) → "file not found". Engine-anchored từ engine cwd → hết. Chỉ `hq` dính (tên trùng thư mục con); mock không lộ (không gọi claude thật).
  2. **discovery dir-based** (`server.mjs`) — `pollForNewRunDir` cũ poll `latest.json` (chỉ ghi khi XONG) → real run >10s → timeout → `child.kill()` **giết run thật giữa chừng** + báo 422 sai. Sửa: phát hiện **run dir mới** (tạo lúc START) qua `listRunDirs` diff → trả runId <1s, không kill run chậm.
  3. **abnormal-end surfacing** (`server.mjs`+`RunLog.jsx`) — engine throw ở edge-select (router-mismatch) KHÔNG ghi `run_end` vào events/state.json (chỉ in stdout) → SSE treo. Sửa: `attachTail` thu stdout/stderr child; khi child đóng mà chưa `run_end` và không `awaiting` → phát synthetic `run_end failed` (seq=maxSeq+1) kèm lý do thật từ stdout → đóng stream. `RunLog` run_end hiện `error` (pre đỏ, maxHeight 200). App end-handler: stream kết thúc lúc 'running' → 'failed' (không bịa 'done').
  4. **ô nhập request** (`App.jsx`) — header thêm `<input>` request (Enter=run) → gửi `request` trong POST `/api/run` (server vốn nhận sẵn, App chưa gửi). Sửa "hq không rõ bối cảnh" (trước chạy default `"run"`). Verified: chuỗi nhập tới đúng `1-coo.prompt.txt`.
- **Output**: `app/server.mjs` (attachTail/listRunDirs/dir-discovery/SSE abnormal-end, bỏ snapshotLatestRun) + `app/src/App.jsx` (request input + end→failed) + `app/src/RunLog.jsx` (run_end error display). Build OK.
- **Gate**: ✅ Verified qua server thật (port 5204/5205): **hello** mock→run_end done · **hq** mock→stream coo live→synthetic `run_end failed` với lý do router thật · **approval-demo** mock→awaiting (stream giữ mở, no false-end)→POST decision approve→`resumed`→terminal `run_end done`→`event: end` (HITL trọn vòng) · request "build a landing page…"→coo prompt nhận đúng · **Real hq** (user)→coo done 190ch + escalate_gate done 620ch (path bug HẾT). ✅ `git diff engine/` RỖNG · selftest **12/12** · validate hello=0 · run hello -Mock=done · `server.mjs` dependency-free.
- **Watch-item bàn giao (KHÔNG phải Phase F)**: real router (vd `escalate_gate`) có thể trả nhãn ngoài tập `when` → engine hard-fail. Là độ-bền prompt agent HQ + router resilience (engine) → **phase sau**. Triệu chứng giảm khi có request rõ (happy-path không chạm escalate).
- **USER DUYỆT ĐÓNG PHASE 2026-06-01.**

### 2026-06-01 — Session F.6 (polish + docs + USER GATE)
- **Done**: F.6 — polish nhỏ + docs đầy đủ + regression xanh. (1) **RunLog.jsx** — fix loading state khi `events.length === 0 && runStatus === 'running'`: hiện "⏳ Starting run…" thay vì "No events yet. Press Run (Mock) to start." (2) **README.md** — rename section → "App — Workflow viewer + live log + duyệt (Phase E+F)": giữ Phase E, thêm Phase F (tính năng live log/highlight/approval/Real-guard), cập nhật bảng Files app (ApprovalPanel/RealConfirmDialog/RunLog/nodes+ring mới), cập nhật dir tree + status line (E+F ✅). (3) **ROADMAP** — bảng tiến độ F → ✅ DONE + thêm §Bàn-giao-F→G (bảng cross-cut + server endpoint đầy đủ sau F). (4) **CLAUDE.md** — row `phase-f` → ✅ DONE. (5) **Regression**: `validate hello`=0 · `run hello -Mock`=done · `selftest` **12/12 PASS** · `git diff engine/` RỖNG · build 489 modules OK.
- **Output**: `RunLog.jsx` (patch) + `README.md` (E+F section) + `ROADMAP.md` (F ✅ + §Bàn-giao-F→G) + `CLAUDE.md` (row) + `CHECKPOINT.md` (phase đóng).
- **Gate**: ✅ regression 12/12 · engine diff RỖNG · build OK · docs cập nhật đủ. Done-gate F verified F.5 server-driven (approval-demo mock awaiting→approve→terminal). App live UX verify = user gate (xem note).
- **Notes**: F.6 verify bằng user gate UX thực tế (`npm run dev`): bấm Run (Mock) → log live + node sáng → approval panel → approve → terminal. Server dev chạy trên port thay đổi mỗi session (PORT env) — user cần `cd app && npm run dev` từ terminal riêng. Regression chuẩn (không UX) đã xanh.

### 2026-06-01 — Session F.5 (approval gate UI + Real-run confirm dialog)
- **Done**: HITL UI + Real guard, app-only (server `/api/run` nhận `mock:false`, `/api/decision` nhận label — đủ từ F.1/F.2, KHÔNG đụng server). (1) **`ApprovalPanel.jsx`** (mới) — render khi `awaiting`: prompt + `node` + 1 nút mỗi `choices[]` label (choice[0]=happy-path filled tím, còn lại outlined → đổi-nhãn/reject); `violations[]` (diff_violation) hiện trong khối cam trước khi duyệt (CC-b); `pending` disable nút + "resuming…". (2) **`RealConfirmDialog.jsx`** (mới) — modal overlay cảnh báo đốt token; Cancel→đóng (no spawn), "Run for real"→`handleRun(false)`. (3) **`App.jsx`** — state `realMode`/`showRealConfirm`/`decisionPending`; `handleRunClick` (Real→mở dialog · Mock→`handleRun(true)`); `handleRun(mock)` (param hoá body `{mock}`); `handleDecision(label)` POST `/api/decision {project,run:runId,decision}` → set running (panel ẩn, SSE đang mở chảy tiếp); derive `awaitingEvt`+`pendingViolations` từ events (useMemo, reset trên `resumed`); header thêm nút đổi nhãn Run (Mock/Real màu) + checkbox **Real** toggle; ApprovalPanel render trên RunLog khi `awaiting`; dialog render cuối.
- **Output**: `app/src/ApprovalPanel.jsx` + `RealConfirmDialog.jsx` (mới) + `App.jsx` (update). Build OK (489 modules).
- **Gate**: ✅ **approval-demo mock** server-driven full chain: `POST /api/run`→`awaiting` `{node:"gate",choices:["approve"],prompt:"Duyệt plan…"}` (shape khớp ApprovalPanel reads thẳng) → `POST /api/decision approve` `{ok:true}` → `resumed`(decision=approve)→`run_start`(resume:true)→builder→`run_end`(done,terminal=builder). ✅ Real dialog = pure client (handleRun(false) CHỈ gọi khi confirm; Cancel no-op) → KHÔNG đốt token session này. ✅ build compile sạch. ✅ regression: `validate hello`=0 · `run hello -Mock`=done · `selftest`=**12/12 PASS**. ✅ **`git diff engine/` RỖNG**.
- **Next**: Session F.6 — Polish + docs + USER GATE (done-gate đầy đủ trên app live).
- **Notes**: F.5 logic = client render derive từ events đã verified F.2 (server-level data-path identical). awaitingEvt reset trên `resumed` → panel tự ẩn sau approve. Verify dùng curl server-driven (PATH `pwsh`, port 5193) — KHÔNG mở SSE `curl -N` chung batch (stream giữ mở → cancel batch; bài học F.4). Server-spawn pwsh vẫn PATH `pwsh` (snap SIGABRT). F.6 nên verify bằng `npm run dev` thật (click UI) để đóng done-gate UX.

### 2026-06-01 — Session F.4 (highlight node live trên React Flow)
- **Done**: Nối live event vào graph highlight (app-only, không đụng engine/GraphView semantic). (1) **`App.jsx`** — `nodeStatuses` (useMemo từ `events`, seq-ordered): map node id→status (`node_start`/`node_output`→running · `node_done`→done · `awaiting`→awaiting; last-event-wins xử loop re-visit). Truyền xuống `<GraphView nodeStatuses=…>`. Reset tự nhiên: `handleClear`/đổi project clear `events` → `nodeStatuses` rỗng → highlight tắt. (2) **`GraphView.jsx`** — prop `nodeStatuses={}` + `useEffect` sync `nodeStatuses`→`node.data.runStatus` qua `setNodes(map)` **giữ nguyên position/layout** (guard `changed` tránh re-render thừa). (3) **`nodes.jsx`** — `runRing(rs)` (box-shadow ring: running=xanh+pulse · done=xanh-lá · awaiting=tím+pulse) + `<StatusBadge>` (chấm góc ●/✓/⏸) áp cho cả 4 node type (worker/router/approval/terminal); router+approval thêm `borderRadius:4` cho ring quanh shape clip-path. (4) **`index.css`** — keyframe `rfPulse` (brightness pulse cho running/awaiting).
- **Output**: `app/src/App.jsx` + `GraphView.jsx` + `nodes.jsx` + `index.css` (update). Build OK (487 modules).
- **Gate**: ✅ **hello mock** SSE → `node_start`×2/`node_output`×2/`node_done`×2/`run_end`(done) → nodeStatuses chạy running→done cả 2 node. ✅ **approval-demo mock** SSE → `awaiting` `node:"gate"`,`choices:["approve"]` → highlight ⏸ gate. ✅ build compile sạch. ✅ regression: `validate hello`=0 · `run hello -Mock`=done(0). ✅ **`git diff engine/` RỖNG**.
- **Next**: Session F.5 — approval gate UI + Real-run confirm dialog.
- **Notes**: Highlight là tầng render client thuần (derive từ events đã verified F.2/F.3) — verify qua build + chuỗi SSE đúng (nguồn nodeStatuses). Router project (hq/loopy) vẫn không ghi `latest.json` khi fail mock (engine BẤT BIẾN) → F.4/F.5 verify dùng hello (running/done) + approval-demo (awaiting). Server spawn pwsh: PATH `pwsh` (snap pwsh SIGABRT) — port 5191 dùng session này. ⚠️ Đừng gom `curl -N` SSE (stream awaiting giữ mở → timeout exit 143/144) chung batch song song với edit — sẽ bị cancel cả batch; tách riêng.

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
| 2026-06-01 | F.4 DONE — highlight node live trên React Flow (running/done/awaiting): `nodeStatuses` derive từ events (App) → sync `node.data.runStatus` giữ layout (GraphView) → ring+badge+pulse (nodes.jsx/index.css). Sub-phase F-II ĐÓNG. Verified hello running→done + approval-demo awaiting(gate). Engine diff RỖNG; regression xanh | @claude |
| 2026-06-01 | F.5 DONE — approval gate UI (`ApprovalPanel.jsx`: prompt+choices+diff_violation, đổi-nhãn/reject) + Real-run confirm dialog (`RealConfirmDialog.jsx`) + App wire (realMode/decision/awaitingEvt derive). App-only (server đủ từ F.1/F.2). Verified approval-demo mock awaiting→approve→terminal (server-driven). Build 489 modules; engine diff RỖNG; regression 12/12 | @claude |
| 2026-06-01 | F.6 DONE — polish (RunLog loading state) + docs (README E+F section/§Bàn-giao-F→G/ROADMAP F✅/CLAUDE.md). Regression 12/12; engine diff RỖNG; build 489 modules | @claude |
| 2026-06-01 | **F.6-followup + ĐÓNG PHASE (user duyệt)** — live UX hardening qua user gate (app-only, engine RỖNG): cwd spawn fix (hq double-path), dir-based run discovery (không kill real run chậm), SSE abnormal-end surfacing (synthetic failed run_end + stdout reason), request input (sửa "hq không rõ bối cảnh"). Verified server thật: hello done · hq mock failed-có-lý-do · approval-demo HITL trọn vòng · Real hq qua coo+escalate_gate. selftest 12/12. Watch-item phase sau: HQ router robustness | @claude |
