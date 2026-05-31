# PLAN — Phase F: App II — live log + run control + duyệt (#3)

> Sau toàn bộ Phase F: từ **app web local** (Phase E shell) **bấm chạy 1 run** (`run <proj>`, mock mặc định) → xem **log THẬT live** (nội dung output đầy đủ mỗi node, không chỉ "(N chars)") qua SSE stream `events.ndjson` + **node sáng dần trên graph React Flow** → khi engine dừng ở gate `awaiting` (duyệt plan / cấp quyền / diff-violation) → **UI duyệt** post quyết định về server → engine `resume -Decision` chạy tiếp tới terminal. Đóng trọn vấn đề #3 ("log trống + thiếu human-in-the-loop"). Nhận trọn bàn giao `#3 live log` + `#3 run control + duyệt` + `CC-b UI duyệt diff` từ Phase D/E.

---

## Context

- **Vì sao chia nhiều session**: Phase F gắn **2 khối mới** lên nền Phase E: (1) **server run-control + event stream** (spawn `run.ps1`, theo dõi run dir, SSE tail `events.ndjson`, post decision) — backend bất đồng bộ, nhiều ca lỗi (race latest.json, child exit, resume nối tiếp seq); (2) **app live UI** (EventSource client, log panel full-output, highlight node live trên React Flow, form duyệt gate). Gom 1 chat sẽ ẩu — stream + HITL là async khó verify từng lớp. Chia theo **lớp xây tăng dần**: server run/registry → server SSE + decision → app live-log client → app highlight graph → app approval-UI + Real-guard → polish + docs + gate.
- **Quyết định đã chốt (user 2026-05-31):**
  - **F-D1. Run-discovery = poll `.runs/latest.json`.** Sau khi spawn `run.ps1 run`, server đọc con trỏ `<project>/.runs/latest.json` để lấy run dir mới → tail `events.ndjson`. **ZERO engine change** (giữ engine bất biến tuyệt đối — run/resume/status đã sẵn từ Phase D). Capture `latest.json` (hoặc danh sách `.runs/`) **TRƯỚC** spawn → poll tới khi đổi (run dir mới xuất hiện) + timeout + retry để xử race "latest.json chưa kịp ghi".
  - **F-D2. Mock mặc định + Real cần xác nhận.** Nút Run mặc định `-Mock` (offline — done-gate F dùng path này, không đốt token). Muốn `-Real` phải bật toggle + **dialog cảnh báo đốt token** (xử "run dài/đốt token" ROADMAP §F). An toàn + khớp done-gate mock.
  - **F-D3. Run-control scope = chỉ `run`.** App chỉ chạy `run <proj> [-Mock]` (HQ + project con) + `resume -Decision` cho gate. **`autobuild`/`autofix` defer** (E2E real, sandbox/promote/diff-scope, real-only — phình scope + session, không cần cho done-gate F "HQ build mock → gate → approve → terminal"). Bàn giao G/sau nếu cần.
  - **F-D4. SSE + dependency-free.** Stream qua `text/event-stream` bằng Node `http` thuần (KHÔNG thêm dep — `server.mjs` giữ dependency-free như Phase E). Tail = poll file theo offset (đọc byte mới từ last-offset ~300ms) → parse NDJSON → push `data:`; gặp `run_end` hoặc child exit → gửi event cuối + đóng stream.
- **Bàn giao NHẬN từ phase trước (làm trong F):**
  - **Từ Phase D — `events.ndjson` schema + surface HITL** (ROADMAP §Bàn-giao-D→E/F): engine phát 8 loại event (full output mỗi node) + pause `awaiting` + `Resume-Workflow -Decision` + surface CLI (`run.ps1 run` exit 0/3/fail · `resume -Decision` · `status`). F **chỉ tiêu thụ** các surface này — KHÔNG sửa engine.
  - **Từ Phase E — app shell + server data-layer** (ROADMAP §Bàn-giao-E→F/G): `server.mjs` (Node http, đã có `GET /api/health` · `/api/projects` · `/api/graph?project=` · `GET/POST /api/layout?project=`) + `App.jsx` + `GraphView.jsx` (React Flow, node highlight-able bằng update style) + project picker + dagre layout. F **gắn thêm** endpoint + UI lên nền này, KHÔNG dựng lại.
- **Schema event tiêu thụ** (nguồn: `engine/events.ps1` + ROADMAP §Bàn-giao-D→E/F):
  - Field cố định: `seq` (int tăng dần), `ts` (ISO), `type`, + payload trộn top-level (`node`, `agent`, …).
  - `run_start` · `node_start` (node/agent) · `node_output` (thêm `output` = full string) · `node_done` · `awaiting` (thêm `awaiting.node`/`awaiting.prompt`/`awaiting.choices[]` — hoặc node+prompt+choices top-level, xác nhận tại F.2) · `resumed` (thêm `decision`) · `diff_violation` (thêm `violations[]`) · `run_end` (thêm `status`, `terminal`).
- **Surface engine F gọi** (không sửa, chỉ shell):
  - Chạy: `run.ps1 run <proj> "<req>" [-Mock] [-AutoApprove]` → exit 0 (done) / **exit 3 (awaiting)** / exit≠0 (fail).
  - Bơm quyết định: `run.ps1 resume <proj> -Decision <label> [-Mock]` → tiếp từ awaiting (resume nối tiếp seq vào CÙNG run dir).
  - Trạng thái: `run.ps1 status <proj>` → in state + awaiting info.
  - Events: `<proj>/.runs/<id>/events.ndjson` (NDJSON, stream đuôi được) + con trỏ `<proj>/.runs/latest.json`.
- **De-risk / vật chứng (đọc trước khi code):**
  - **⚠️ Resume nối tiếp CÙNG run dir**: `Resume-Workflow` ghi tiếp `events.ndjson` của run dir đang awaiting (seq self-sequencing theo số dòng — `engine/events.ps1`). Hệ quả: SSE phải **tiếp tục tail CÙNG file** sau khi POST decision (không mở run dir mới). Server giữ `runDir` của run hiện hành; `POST /api/decision` spawn `resume` rồi để SSE đang mở đọc tiếp byte mới.
  - **⚠️ Race latest.json**: spawn async — run dir + latest.json ghi sau vài trăm ms. Server phải poll (so danh sách `.runs/` trước/sau spawn, hoặc đợi `latest.json` trỏ dir mới) + timeout rõ + báo lỗi nếu quá hạn (đừng treo vô hạn).
  - **⚠️ pwsh hạ tầng** (carry C/D/E): `/snap/bin/pwsh` (7.6.2) hay core-dump RC=134 lúc teardown — **đọc NỘI DUNG output / event, KHÔNG tin exit code** từ child. Server dựa `run_end` event + sự tồn tại file, không chỉ child exit code. Chạy tay: `pwsh -NoProfile ... 2>&1 | cat` + `dangerouslyDisableSandbox: true`.
  - **`server.mjs` dependency-free**: giữ Node `http`/`fs`/`child_process` thuần (như E) — KHÔNG thêm express/ws.
  - **Bind localhost**: server chỉ nghe `127.0.0.1` (bảo mật cục bộ — ROADMAP §F). Spawn `run.ps1` là lệnh local đã tin cậy; vẫn validate `project` (`SAFE_PROJECT` regex sẵn) + chặn path traversal (tái dùng `resolveProjectDir`).
- **Ràng buộc bất biến (6 quy ước `company/CLAUDE.md`)** — Phase F áp như sau:
  - **#1 engine code cố định**: F **KHÔNG sửa engine** (run/resume/status/events đã sẵn từ D). `git diff engine/` PHẢI rỗng MỌI session. Run-control/stream/duyệt nằm ở **tầng app** (`server.mjs` + `app/src/`), không phải logic workflow.
  - **#2 `workflow.json` coordinate-free**: F không đụng `workflow.json` (chỉ đọc graph qua `/api/graph` của E). Không ghi toạ độ.
  - **#3 mock bất biến**: F mặc định chạy `-Mock` (F-D2) — đường mock engine không đổi. Regression chuẩn xanh ở session đóng (F.6).
  - **#4 một surface lệnh**: server shell qua `run.ps1 run/resume/status` (surface sẵn) — KHÔNG entry point engine mới. Server app là tầng app (chấp nhận theo D-1/D-2).
  - **#5 dot-source-safe**: F không thêm code pwsh (không đụng engine) → N/A; nếu lỡ chạm, giữ guard.
  - **#6 chỉ trong `company/`**: app + server tại `company/app/`; run dir trong `<project>/.runs/`.
- **Out of scope (bàn giao — xem §"Bàn giao sang G")**: Sửa workflow trong app (thêm/xoá node, nối cạnh) → **Phase G** (tuỳ chọn). Chạy `autobuild`/`autofix` từ app (E2E real) → defer (F-D3). Replay/diff-viewer lịch sử `.runs/` cũ = nice-to-have, chỉ làm nếu rẻ ở F.6 (không phải done-gate).

---

## Pipeline 3 sub-phase / 6 session

```
[F-I — Server run-control + event stream (backend)]
[F.1] POST /api/run: spawn run.ps1 + run registry + latest.json discovery ─► bấm API → spawn `run <proj> -Mock` → trả {runId,runDir}; race-safe
                                                                              │
[F.2] GET /api/events (SSE tail) + POST /api/decision (resume) ────────────► SSE đẩy đủ chuỗi event (full output); decision → resume nối tiếp CÙNG run dir
                                                                              │
[F-II — App live log + graph highlight (frontend)]
[F.3] EventSource client + live log panel (full output per node) ──────────► UI: bấm Run → log live hiện nội dung output từng node, cuộn theo
                                                                              │
[F.4] Highlight node trên React Flow theo event (tích hợp E GraphView) ────► node running/done/awaiting sáng/đổi màu dần trên graph
                                                                              │
[F-III — Approval UI + Real-guard + polish + gate]
[F.5] Approval gate UI + Real-run confirm dialog ──────────────────────────► awaiting → form duyệt (choices/diff) → POST decision → engine tiếp; -Real có cảnh báo
                                                                              │
[F.6] Polish + docs + handoff(G) + USER GATE ──────────────────────────────► done-gate đủ (HQ mock: live log + highlight → gate → approve → terminal; + reject/đổi nhánh) + docs
```

---

## Phase F — App II: live log + run control + duyệt

**Mục tiêu**: từ app bấm chạy run (mock mặc định) → xem log live đầy đủ output + node sáng trên graph → tới gate `awaiting` duyệt từ UI → engine resume tới terminal. Mỗi session = 1 lớp; STOP gate đo được; `git diff engine/` = RỖNG mọi session (F không sửa engine).

> **Bất biến cốt lõi Phase F**: engine KHÔNG đổi (`git diff engine/` rỗng mọi session — run/resume/status/events đã sẵn từ D); `server.mjs` dependency-free (Node http thuần); mặc định `-Mock` (không đốt token trừ khi user bật Real + xác nhận); server bind `127.0.0.1`.
> **Regression chuẩn (session đóng F.6, + bất kỳ session lỡ chạm engine)**: `./run.ps1 validate hello`=exit 0 · `./run.ps1 run hello "x" -Mock`=done · `./run.ps1 selftest`=PASS. F không sửa engine nên đây là **proof-of-no-regression**, không phải sửa-rồi-test.
> **pwsh**: `/snap/bin/pwsh` + `dangerouslyDisableSandbox: true`; **server tin event `run_end` + file, KHÔNG tin child exit code** (core-dump teardown).
> **Node toolchain**: chạy trong `company/app/`. Dev: `npm run dev` (Vite proxy `/api`→server). Serve: `npm run build && node server.mjs` (port 5179). Dọn `.runs/` test sau verify.

### Sub-phase F-I — Server run-control + event stream (backend)

#### Session F.1 — POST /api/run: spawn + run registry + latest.json discovery
- **Scope** (`app/server.mjs` — additive endpoint, dependency-free):
  - `POST /api/run` body `{project, request?, mock?:true, autoApprove?:false}` → **(F-D3)** chỉ map sang `run.ps1 run <project> "<request>" [-Mock] [-AutoApprove]`. Mặc định `mock:true` (F-D2); `mock:false` (Real) chấp nhận nhưng app sẽ chỉ gửi sau confirm (F.5) — server không tự chặn nhưng KHÔNG mặc định Real.
  - **Run discovery (F-D1)**: trước spawn, đọc snapshot `<project>/.runs/` (danh sách dir + `latest.json` nếu có). Spawn child `pwsh -NoProfile -File run.ps1 run …` (cwd `COMPANY`). Poll `latest.json`/danh sách `.runs/` tới khi run dir MỚI xuất hiện (timeout ~10s, interval ~200ms) → đó là `runDir`. Trả `{runId, runDir, project}` (runId = tên dir timestamp). Timeout → 504 `{error:'run dir not detected'}` (không treo).
  - **Run registry** in-memory: `Map<runId → {child, project, runDir, status:'running', startedAt}>`. Cập nhật `status` khi child `close` (đọc nội dung, không tin exit). Tái dùng `SAFE_PROJECT` + `resolveProjectDir` (chặn project lạ/traversal).
- **STOP gate** (đo được):
  - `curl -X POST /api/run -d '{"project":"hello","request":"x","mock":true}'` → trả JSON `{runId, runDir}` với `runDir` trỏ thư mục `hello/.runs/<ts>/` MỚI (khác snapshot trước spawn) + `events.ndjson` tồn tại trong đó.
  - `curl -X POST /api/run -d '{"project":"approval-demo","mock":true}'` → run dir mới + (run dừng awaiting — verify ở F.2, ở đây chỉ cần spawn + discovery OK).
  - Project lạ (`/api/run -d '{"project":"nope"}'`) → 404/400 (không spawn).
  - **`git diff engine/` = RỖNG** (F.1 chỉ đụng `server.mjs`).
- **Output artifact**: `POST /api/run` + run registry + latest.json discovery (race-safe).

#### Session F.2 — GET /api/events (SSE tail) + POST /api/decision (resume)
- **Scope** (`app/server.mjs` — additive, dependency-free SSE):
  - `GET /api/events?project=<p>&run=<runId>` → `Content-Type: text/event-stream`; **tail `events.ndjson`** của run dir (F-D4): đọc từ last-offset mỗi ~300ms, parse từng dòng NDJSON → `res.write('data: ' + line + '\n\n')`. Gặp event `run_end` (hoặc `awaiting` → vẫn giữ mở chờ resume) → tiếp tục đến khi `run_end`; child đã `close` + đọc hết file → gửi sentinel `event: end` rồi `res.end()`. Heartbeat comment `: ping` định kỳ (giữ kết nối). Xử client disconnect (`req.on('close')` → clear interval).
  - `POST /api/decision` body `{project, run, decision}` → spawn `run.ps1 resume <project> -Decision <decision> [-Mock]` (cùng mock-mode run gốc — lưu trong registry). Resume ghi tiếp CÙNG `events.ndjson` (seq nối tiếp) → **SSE đang mở của run đó tự đọc byte mới** (không mở stream mới). Trả `{ok:true}`.
  - Xác nhận **shape event `awaiting`** thực tế (chạy `approval-demo` rồi đọc `events.ndjson`): field `awaiting.node`/`prompt`/`choices[]` nằm nested hay top-level → ghi rõ vào CHECKPOINT cho F.5 dùng đúng.
- **STOP gate** (đo được):
  - Spawn `run hello -Mock` (F.1) rồi `curl -N '/api/events?project=hello&run=<id>'` → nhận đủ chuỗi SSE `data:` gồm `run_start` → các `node_start`/`node_output`(có `output` full) /`node_done` → `run_end` (status done) → `event: end`. Output trong `node_output` là **nội dung thật** (không "(N chars)").
  - `approval-demo`: SSE đẩy tới event `awaiting` rồi GIỮ mở; `curl -X POST /api/decision -d '{"project":"approval-demo","run":"<id>","decision":"approve"}'` → SSE (đang mở) đọc tiếp `resumed` + node sau + `run_end` (terminal) → `event: end`. Chứng minh resume nối tiếp CÙNG file.
  - Shape `awaiting` ghi vào CHECKPOINT.
  - **`git diff engine/` = RỖNG**.
- **Output artifact**: `GET /api/events` (SSE tail nối-tiếp-qua-resume) + `POST /api/decision` + shape `awaiting` xác nhận.

### Sub-phase F-II — App live log + graph highlight (frontend)

#### Session F.3 — EventSource client + live log panel (full output per node)
- **Scope** (`app/src/` — component mới, không đụng `GraphView` semantic):
  - Nút **Run** trên header (mặc định Mock — F-D2): `POST /api/run` → nhận `{runId}` → mở `new EventSource('/api/events?project=&run=')`.
  - **Log panel** (component `RunLog`): mỗi event render 1 dòng/khối; `node_output` hiện **nội dung output đầy đủ** (collapsible nếu dài), kèm node/agent/ts; `run_start`/`node_start`/`node_done`/`run_end` hiện trạng thái gọn. Auto-scroll theo event mới. Hiển trạng thái run (running/done/awaiting/failed) từ `run_end.status`/`awaiting`.
  - State: lưu events nhận được trong React state theo `seq` (dedup). Đóng EventSource khi `event: end`.
- **STOP gate**:
  - App (`npm run dev`) → chọn `hello` → bấm Run (Mock) → **log panel hiện live** đủ chuỗi: run_start → node output (nội dung thật từng node) → run_end done. Cuộn theo.
  - `loopy` (Mock) → thấy nhiều lượt node (loop) live.
  - Không lỗi console; EventSource đóng sạch khi `end`.
  - **`git diff engine/` = RỖNG** (F.3 app-only).
- **Output artifact**: nút Run (mock) + `RunLog` panel (full output, auto-scroll) + EventSource client.

#### Session F.4 — Highlight node đang chạy trên React Flow (tích hợp E GraphView)
- **Scope** (`app/src/` — nối live event vào `GraphView` của E):
  - Khi nhận event live: map `node_start`→node "running" (vd viền/nền active), `node_done`→"done", `awaiting`→"awaiting" (⏸ nổi bật), `run_end`→giữ trạng thái cuối. Truyền `activeNode`/`nodeStatuses` xuống `GraphView` → update node style (E đã để node highlight-able). KHÔNG đổi layout/semantic.
  - Reset highlight khi bắt đầu run mới. Graph + log panel cùng phản ánh 1 run.
- **STOP gate**:
  - `hq` (Mock) Run → **node sáng dần** trên graph đúng thứ tự walk (coo→…); node done đổi trạng thái; tới gate `awaiting` (nếu path) node ⏸ nổi bật; `run_end` giữ trạng thái cuối.
  - Highlight khớp với thứ tự trong log panel (cùng `seq`).
  - Drag/zoom/pan (E.4) vẫn hoạt động khi đang highlight (không vỡ layout/persist).
  - **`git diff engine/` = RỖNG**.
- **Output artifact**: live highlight node trên React Flow (running/done/awaiting) tích hợp log panel.

### Sub-phase F-III — Approval UI + Real-guard + polish + gate

#### Session F.5 — Approval gate UI + Real-run confirm dialog
- **Scope** (`app/src/` — HITL UI + Real guard):
  - **Approval UI**: khi event `awaiting` tới → hiện panel duyệt với `prompt` + danh sách `choices[]` (nút mỗi nhãn `when`, vd approve/reject). Bấm → `POST /api/decision {decision:<label>}` → engine resume → SSE chảy tiếp. Hỗ trợ **đổi nhãn đi nhánh khác** (chọn choice khác happy-path).
  - **`diff_violation`** (CC-b — nếu event tới): hiện `violations[]` (list path ngoài whitelist) trong panel duyệt để người xem trước khi approve/reject (UI duyệt diff — bàn giao CC-b).
  - **Real-run confirm (F-D2)**: toggle "Real" cạnh nút Run; bật + bấm Run → **dialog cảnh báo đốt token** (xác nhận trước khi gửi `mock:false`). Mặc định off.
- **STOP gate**:
  - `approval-demo` (Mock) Run → tới gate → **panel duyệt hiện prompt + choices** → bấm approve → SSE tiếp → terminal (run_end done). Log + graph phản ánh.
  - Thử **reject / chọn nhãn khác** (nếu graph có ≥2 nhánh) → engine đi nhánh tương ứng (verify qua event/terminal khác). (`hq` `approval`? — dùng `approval-demo`; nếu cần nhánh-khác dùng graph có router sau gate.)
  - Bật toggle Real + Run → **dialog cảnh báo** xuất hiện; Cancel → KHÔNG spawn; (KHÔNG bấm confirm Real trong session này để không đốt token — chỉ verify dialog chặn).
  - **`git diff engine/` = RỖNG**.
- **Output artifact**: approval panel (choices + diff_violation) + POST decision + Real-confirm dialog.

#### Session F.6 — Polish + docs + handoff + USER GATE
- **Scope** (polish nhẹ + docs):
  - **Polish**: trạng thái loading/empty/error khi run/stream; nút "Stop watching"/clear log; (tuỳ chọn, chỉ nếu rẻ) liệt kê run lịch sử `.runs/` để xem lại events cũ — read-only, KHÔNG bắt buộc done-gate. Cảnh báo nhẹ khi mock=false vẫn còn.
  - **README**: mục mới "App — Live log + run control + duyệt (Phase F)": cách bấm Run (mock mặc định), xem log live, highlight node, duyệt gate (approve/reject/đổi nhãn), Real-run + cảnh báo token; giới hạn (chỉ `run`; autobuild/autofix qua CLI).
  - **CLAUDE.md** bảng "Bản đồ file": cập nhật hàng `company/app/` (thêm run-control + SSE + approval UI) + hàng `plan/hq-improve/phase-f/`.
  - **ROADMAP**: bảng tiến độ F ✅ + **§"Bàn giao F→G"** (app render + drag layout sẵn cho in-app edit; run-control/stream/duyệt đóng ở F).
- **STOP gate** (Done-gate Phase F đầy đủ — ROADMAP §Phase F):
  - Từ app chạy **1 HQ build (mock)** → thấy **log live đầy đủ output** mỗi bước + **node sáng dần trên graph** → tới gate duyệt → **bấm approve → chạy tới terminal**.
  - Thử **1 lần reject / đổi nhãn đi nhánh khác** đúng (engine đi nhánh tương ứng).
  - **Real-run** có dialog cảnh báo trước khi đốt token (chặn được, không tự chạy).
  - Server bind `127.0.0.1`; `server.mjs` dependency-free (chỉ Node core).
  - **`git diff engine/` = RỖNG** toàn Phase F + **regression chuẩn xanh** (validate hello=0 · run hello -Mock=done · selftest PASS) — proof-of-no-regression.
  - README + CLAUDE.md + ROADMAP cập nhật (F ✅ + §Bàn-giao-F→G).
  - **User duyệt** đóng phase (ghi CHECKPOINT).
- **Output artifact**: polish + docs + CLAUDE.md/ROADMAP → Phase F đóng.

**Phase F gate** (sau F.6): app local bấm Run (mock) → SSE live log đầy đủ output + node sáng dần trên React Flow → gate `awaiting` duyệt từ UI (approve/reject/đổi nhãn) → engine `resume -Decision` tới terminal; Real-run sau dialog cảnh báo; server dependency-free + localhost; engine BẤT BIẾN (`git diff engine/` rỗng, regression xanh); ROADMAP §Bàn-giao-F→G ghi đủ; user duyệt. → cập nhật ROADMAP (F ✅).

---

## Bàn giao sang G (ghi vào ROADMAP cuối F.6)

> F *đóng trọn #3* (live log + run control + duyệt); **in-app edit** thuộc G (tuỳ chọn).

| Cross-cut | F làm gì | Phase sau phải làm tiếp |
| --- | --- | --- |
| **#3 live log** | ✅ Server SSE tail `events.ndjson` + app log panel full-output + highlight node live trên graph | (đóng ở F) |
| **#3 run control + duyệt** | ✅ `POST /api/run` (mock-default, Real-confirm) + `POST /api/decision` → `resume -Decision` + approval UI (choices/diff_violation, reject/đổi nhãn) | (đóng ở F) |
| **CC-b UI duyệt diff** (NHẬN từ D) | ✅ `diff_violation` event hiện `violations[]` trong panel duyệt trước approve/reject | (đóng ở F) |
| **G in-app edit** | Graph render (E) + drag layout + live highlight (F) — vẫn read-only semantic | **Sửa graph trong app** (thêm/xoá node, nối cạnh) → ghi `workflow.json` hợp lệ (`validate` pass), coordinate-free → **Phase G** (tuỳ chọn) |
| **autobuild/autofix từ app** | Defer (F-D3 — chỉ `run`) | (tuỳ chọn) thêm nút chạy `autobuild`/`autofix` real từ app (sandbox/promote/diff-scope) — chỉ nếu cần, sau G |

**Server endpoint sau F** (đầy đủ): `GET /api/health` · `GET /api/projects` · `GET /api/graph?project=` · `GET/POST /api/layout?project=` (E) + **`POST /api/run` · `GET /api/events?project=&run=` (SSE) · `POST /api/decision`** (F). G (nếu làm) thêm: `POST /api/workflow?project=` (ghi `workflow.json` đã validate).

---

## Outcome cuối

- App web local (`company/app/`, React+Vite+Tailwind+React Flow+dagre — nền Phase E) **bấm Run** → `server.mjs` spawn `run.ps1 run <proj> [-Mock]`, phát hiện run dir qua `latest.json` (zero engine change).
- **Log live đầy đủ output** mỗi node qua SSE tail `events.ndjson` (không chỉ "(N chars)") + **node sáng dần** trên graph React Flow (running/done/awaiting) — đóng #3 live log.
- **Duyệt từ UI**: gate `awaiting` → panel duyệt (prompt + choices + `diff_violation` violations) → `POST /api/decision` → `run.ps1 resume -Decision` → engine tiếp tới terminal; hỗ trợ approve/reject/đổi nhãn đi nhánh khác — đóng #3 HITL + CC-b.
- **Mock mặc định** (không đốt token); **Real** sau dialog cảnh báo (F-D2). Run scope **chỉ `run`** (F-D3).
- **Engine BẤT BIẾN**: `git diff engine/` rỗng toàn phase; `server.mjs` dependency-free (Node core); bind localhost; regression chuẩn xanh (proof-of-no-regression).
- `ROADMAP.md`: F ✅ + §Bàn-giao-F→G; user duyệt.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-05-31 | Initial | Soạn long-plan Phase F từ `ROADMAP.md` §Phase F (4 mục "Cần làm rõ") + §Bàn-giao-D→E/F (#3 live log + HITL + CC-b) + §Bàn-giao-E→F/G (server nền + endpoint F gắn thêm). Chốt F-D1..F-D4 (user 2026-05-31): poll `latest.json` (zero engine change) · mock-default + Real-confirm · scope chỉ `run` · SSE dependency-free. 3 sub-phase / 6 session. Engine BẤT BIẾN (run/resume/status/events sẵn từ D) — F chỉ gắn `server.mjs` + `app/src/` |
