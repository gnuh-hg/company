# PLAN — Phase E: App I — Workflow viewer (#4)

> Sau toàn bộ Phase E: có **app web local** (React + Vite + Tailwind) đọc `workflow.json` của bất kỳ project nào → vẽ graph tương tác (node + cạnh có hướng + nhãn `when` router + back-edge loop + ký hiệu gate `approval`), **zoom / pan / kéo thả node**, layout mặc định auto (dagre) và **persist vị trí node app-side** (`<project>/.layout.json` — KHÔNG đụng `workflow.json`). Đóng vấn đề #4 ("xem workflow khó") + nhận bàn giao `#4 viewer` từ Phase D. Đặt nền app shell + server data-layer cho Phase F (live log + duyệt).

---

## Context

- **Vì sao chia nhiều session**: Đây là **app mới dựng từ số 0** — chưa có thư mục `app/`, repo `company/` hiện thuần PowerShell. Phải: scaffold toolchain (Vite/React/Tailwind) + server data-layer + tích hợp React Flow + auto-layout dagre + render đúng 4 dạng node (worker / router-diamond / approval-hexagon / terminal) & cạnh (nhãn `when` + back-edge) + tương tác zoom/pan/drag + persist layout qua file. Gom 1 chat sẽ ẩu, khó verify từng lớp. Chia theo **lớp xây tăng dần**: scaffold → data-layer (chuẩn hoá graph) → render graph → tương tác → persist layout → polish+docs+gate.
- **Quyết định đã chốt (user 2026-05-31 — REVISE cross-cutting D-1):**
  - **E-D1. Stack = React + Vite + Tailwind.** ⚠️ **Sửa lại D-1 cũ** ("web tĩnh, KHÔNG bundler/build step"). Lý do: Phase E là viewer nhẹ nhưng **Phase F** (live log SSE + highlight node chạy + form duyệt plan/diff) là app tương tác nặng — component-model + state của React tiết kiệm lớn; và có lib chuyên dụng (React Flow). Đánh đổi đã chấp nhận: thêm Node toolchain + build step + `node_modules`; **vẫn full-local** (không cloud) — server nhỏ serve `dist/` đã build. Ghi Revision vào `ROADMAP.md` (D-1 đổi).
  - **E-D2. Graph lib = React Flow (xyflow).** Sẵn zoom/pan/drag, custom node-shape (approval hexagon `⏸`, router diamond, worker rect), edge có nhãn, minimap. Xử gần trọn Done-gate E + pair tốt với Phase F (highlight node live).
  - **E-D3. Auto-layout = dagre.** Layered top-down (giống `.mmd` hiện `graph TD`), pair chuẩn với React Flow, xử back-edge loop tốt. 1 helper nhỏ tính `{id→{x,y}}` rồi feed React Flow.
  - **E-D4. Persist layout = file `<project>/.layout.json` + server có endpoint GHI (POST).** Vị trí node kéo-thả persist bền vào file app-side (gitignore), **KHÔNG ghi vào `workflow.json`** (giữ bất biến #2 + D-3 coordinate-free). Hệ quả: server Phase E **không chỉ-GET** — có serve `dist/` + `GET /api/projects` + `GET /api/graph` + `GET/POST /api/layout`. **KHÔNG** có run-control / SSE / ghi-decision (để Phase F).
- **Bàn giao NHẬN từ phase trước (làm trong E):**
  - **Từ Phase D — `#4 viewer`** (ROADMAP §Bàn-giao-D→E/F): node `approval` đã render được ở engine (ASCII `⏸` + Mermaid hexagon) → **app vẽ graph + ký hiệu gate + zoom/pan/drag**. Đây là phần CỐT của Phase E. App đọc `workflow.json` phải phân biệt + vẽ rõ node `approval`.
  - **Từ Phase B** (ROADMAP §dependency): surface lệnh + đường-dẫn-resolve project (`projects/` > `examples/` > `hq/`) đã ổn định → data-layer dựa vào đó để liệt kê + nạp project.
- **De-risk / vật chứng (đọc trước khi code):**
  - **⚠️ `workflow.json` mã hoá UTF-16** (Windows-authored — xác nhận khi soạn plan: `iconv -f UTF-16` đọc được, `cat` trả rác). Engine `Get-Graph` đọc đúng (qua pwsh). **Hệ quả thiết kế (E-D-impl):** data-layer KHÔNG tự parse `workflow.json` bằng JS (sẽ vấp UTF-16 + phải tái hiện loader pipeline-v1→graph). **Dùng engine làm nguồn chuẩn hoá**: thêm **`run.ps1 graph <proj> -Json`** (additive — emit `{nodes,edges,entry,max_steps}` đã chuẩn hoá từ `Get-Graph`); server shell `pwsh run.ps1 graph <proj> -Json` → trả thẳng JSON cho app. Lợi: tái dùng normalization engine (pipeline-v1, adjacency, when-label), xử encoding free, giữ #4 một-surface.
  - **engine bất biến**: Phase E **chỉ THÊM** `-Json` cho `graph` (additive, không đổi output ASCII/Mermaid cũ). Mọi path engine khác KHÔNG đụng. Regression chuẩn vẫn áp cho session chạm engine.
  - **pwsh hạ tầng** (carry C/D): `/snap/bin/pwsh` (7.6.2) hay core-dump RC=134 lúc teardown — đọc NỘI DUNG output, KHÔNG tin exit code; chạy `pwsh -NoProfile -Command '<inline>' 2>&1 | cat` + `dangerouslyDisableSandbox: true`.
  - **Graph HQ tham chiếu kỳ vọng** (verify render đúng): `hq` = **11 node** (`coo` router, `researcher`, `rg_gate` router, `clarify_gate` router, `planner`, `cto`, `builder`, `tester` router, `escalate_gate` router, `escalate_report`, `record`) + **17 cạnh** (COO 3 nhãn build/fix/unclear; rg_gate enough/need_clarify; clarify_gate ok/missing_input; tester pass/fail_fix/fail_replan/escalate; escalate_gate resolved/escalate; back-edge `tester→builder`, `tester→planner`). `entry=coo`, `max_steps=40`. 2 terminal: `record` / `escalate_report`. (Nguồn: `hq/workflow.mmd`.)
- **Ràng buộc bất biến (6 quy ước `company/CLAUDE.md`)** — Phase E là app nên áp như sau:
  - **#1 engine code cố định**: chỉ thêm `-Json` cho `graph` ở **hàm thuần** (reuse `Get-Graph`), KHÔNG sửa logic walk/normalize. App KHÔNG chứa logic workflow.
  - **#2 `workflow.json` chỉ ngữ nghĩa — KHÔNG toạ độ**: app TUYỆT ĐỐI không ghi `x/y` vào `workflow.json`. Toạ độ đi `<project>/.layout.json`. Done-gate kiểm `git diff` `workflow.json` = rỗng sau kéo-thả.
  - **#3 mock bất biến**: app không đụng đường chạy engine; `-Json` additive không đổi mock-path. Regression chuẩn xanh ở session chạm engine.
  - **#4 một surface lệnh**: data-layer gọi engine qua `run.ps1 graph -Json` (mở rộng lệnh sẵn), KHÔNG entry point engine mới. (Server app là tầng *app*, không phải lệnh engine — chấp nhận theo D-1/D-2 đã chốt "1 server local nhẹ".)
  - **#5 dot-source-safe**: nếu thêm code pwsh, giữ guard `InvocationName`/`Line`.
  - **#6 chỉ trong `company/`**: app đặt tại `company/app/`.
- **Out of scope (bàn giao — xem §"Bàn giao sang F/G")**: Live log streaming (SSE đọc `events.ndjson`) + highlight node đang chạy → **Phase F**. Nút chạy run (`run`/`autobuild`) + UI duyệt plan/diff/cấp-quyền + post-decision về engine → **Phase F**. Sửa workflow trong app (kéo nối cạnh, thêm/xoá node) → **Phase G**. Phase E **chỉ xem + layout** (read graph + drag-persist) — KHÔNG chạy, KHÔNG sửa graph, KHÔNG stream.

---

## Pipeline 3 sub-phase / 6 session

```
[E-I — Scaffold + data-layer (nền app + nguồn graph chuẩn hoá)]
[E.1] Scaffold Vite+React+Tailwind + server skeleton ──► app/ dựng được, dev+build chạy, server serve dist/ + /api/health
                                                            │
[E.2] Data-layer: engine -Json + API graph/projects ─────► run.ps1 graph -Json (additive) + GET /api/projects + GET /api/graph?project=
                                                            │
[E-II — Render graph + tương tác]
[E.3] React Flow render: node 4-loại + cạnh + dagre ─────► chọn project → vẽ graph đúng topo (hq 11 node/17 cạnh) + approval hexagon + nhãn when + back-edge
                                                            │
[E.4] Tương tác: zoom / pan / drag node ────────────────► zoom-pan-drag mượt; minimap; fit-view
                                                            │
[E-III — Persist layout + polish + gate]
[E.5] Persist layout: .layout.json GET/POST ────────────► kéo thả → POST lưu file; reload giữ vị trí; workflow.json BẤT BIẾN
                                                            │
[E.6] Polish + docs + handoff + USER GATE ──────────────► README app + CLAUDE.md + ROADMAP (E ✅ + D-1 revise + §Bàn-giao-E→F/G) + done-gate đủ
```

---

## Phase E — App I: workflow viewer

**Mục tiêu**: app local đọc `workflow.json` → vẽ graph tương tác (4 loại node + cạnh nhãn + back-edge + gate), zoom/pan/drag, layout auto dagre + persist file app-side coordinate-free; chọn project. Mỗi session = 1 lớp; STOP gate đo được + (session chạm engine) regression chuẩn + `git diff` không lan ngoài scope.

> **Regression chuẩn (chỉ session CHẠM engine — E.2)**: `./run.ps1 validate hello`=exit 0 · `./run.ps1 run hello "x" -Mock`=done · `./run.ps1 selftest`=PASS (exit 0). Session app-only (E.1/E.3/E.4/E.5/E.6) KHÔNG đụng engine → regression engine không bắt buộc, nhưng `git diff engine/` PHẢI rỗng (trừ E.2).
> **Bất biến cốt lõi Phase E**: `workflow.json` KHÔNG bao giờ bị app ghi toạ độ (kiểm `git diff workflow.json`=rỗng sau drag); engine chỉ THÊM `-Json` (E.2) — output ASCII/Mermaid/mock cũ y nguyên.
> **pwsh**: `/snap/bin/pwsh` + `dangerouslyDisableSandbox: true`, đọc nội-dung-output không tin exit-code (core-dump teardown).
> **Node toolchain**: `npm`/`node` chạy trong `company/app/`. `npm install` lần đầu (E.1). `app/node_modules` + `app/dist` + `**/.layout.json` vào `.gitignore`.

### Sub-phase E-I — Scaffold + data-layer

#### Session E.1 — Scaffold app + server skeleton
- **Scope** (`company/app/` mới):
  - Dựng Vite + React + Tailwind trong `company/app/` (cấu trúc tối thiểu: `package.json`, `vite.config.js`, `tailwind.config.js`, `postcss.config.js`, `index.html`, `src/main.jsx`, `src/App.jsx`, `src/index.css` có Tailwind directives). `npm install`.
  - **Server nhỏ** `app/server.mjs` (Node `http` thuần hoặc express tối thiểu): serve `app/dist/` (static, sau build) + `GET /api/health` → `{ok:true}`. Vite dev config `server.proxy` `/api` → server (cho dev mode).
  - `.gitignore`: thêm `app/node_modules/`, `app/dist/`, `**/.layout.json`.
  - README/CHECKPOINT ghi cách chạy: `cd app && npm install && npm run dev` (dev) hoặc `npm run build && node server.mjs` (serve).
- **STOP gate** (đo được):
  - `cd company/app && npm install` thành công (exit 0, `node_modules/` có React+Vite+Tailwind+React Flow+dagre).
  - `npm run build` → `app/dist/index.html` tồn tại.
  - `node server.mjs` chạy → `curl localhost:<port>/api/health` trả `{"ok":true}` + `curl localhost:<port>/` trả HTML có root `#root`.
  - `git diff engine/` rỗng (E.1 không đụng engine).
- **Output artifact**: `company/app/` scaffold (React+Vite+Tailwind+React Flow+dagre deps) + `server.mjs` skeleton + `.gitignore` cập nhật.

#### Session E.2 — Data-layer: engine `-Json` + API graph/projects
- **Scope** (`engine/run.ps1` + tuỳ `engine/viz.ps1`/`engine/graph.ps1` — **additive** + `app/server.mjs`):
  - **Engine (additive)**: `run.ps1 graph <proj> -Json` → emit JSON chuẩn hoá `{entry, max_steps, nodes:[{id,agent,type,prompt?}], edges:[{from,to,when?}]}` từ `Get-Graph` (KHÔNG đổi nhánh ASCII/Mermaid cũ — chỉ rẽ khi `-Json`). Reuse `Get-Graph` (đã xử pipeline-v1→graph + UTF-16). Giữ #1 (hàm thuần) + #5 (dot-source-safe).
  - **Server**: `GET /api/projects` → liệt kê project khả-vẽ (quét `hq/` + `examples/*/` + `projects/*/` có `workflow.json`; tôn trọng thứ-tự-resolve B). `GET /api/graph?project=<name>` → shell `pwsh run.ps1 graph <name> -Json` → trả JSON (cache nhẹ tuỳ chọn).
- **STOP gate** (đo được):
  - `run.ps1 graph hq -Json` → JSON hợp lệ (`ConvertFrom-Json` không lỗi); đúng **11 nodes / 17 edges**, `entry=coo`, `node.type` phân biệt `router`(coo/rg_gate/clarify_gate/tester/escalate_gate) vs `worker`; `approval` xuất hiện đúng khi có (test thêm `approval-demo`).
  - `run.ps1 graph loopy -Json` + `branchy -Json` + `hello -Json` (pipeline-v1) đều JSON hợp lệ (chứng minh reuse loader).
  - Server: `curl /api/projects` trả mảng có `hq`,`loopy`,`branchy`,`hello`,`approval-demo`; `curl '/api/graph?project=hq'` trả JSON 11/17.
  - **Regression chuẩn xanh** (E.2 chạm engine): validate hello=0 · run hello -Mock=done · selftest PASS. `run.ps1 graph hq` (KHÔNG -Json) vẫn ra ASCII/Mermaid y cũ.
- **Output artifact**: `run.ps1 graph -Json` (additive) + `/api/projects` + `/api/graph` server.

### Sub-phase E-II — Render graph + tương tác

#### Session E.3 — React Flow render: node 4-loại + cạnh + dagre auto-layout
- **Scope** (`app/src/` — React Flow + dagre):
  - Component `GraphView`: fetch `/api/graph?project=` → map sang React Flow `nodes`/`edges`. Custom node-type theo `type`: `worker`(rect), `router`(diamond), `approval`(hexagon `⏸`), terminal (node không cạnh-ra — style riêng). Edge: directed arrow + `label` = `when` (router/approval); back-edge (loop, vd `tester→builder`/`tester→planner`) vẽ phân biệt (vd cong/màu).
  - **dagre auto-layout** helper: build dagre graph từ nodes/edges → `{id→{x,y}}` (rankdir TB) → set `position` ban đầu cho React Flow.
  - **Project picker**: dropdown/sidebar từ `/api/projects` → đổi project re-fetch + re-layout.
- **STOP gate**:
  - Mở app → chọn `hq` → thấy **11 node + 17 cạnh** đúng topo (so `hq/workflow.mmd`): COO 3 nhãn build/fix/unclear; 5 router là diamond; nhãn `when` hiện trên cạnh router; back-edge `tester→builder`/`tester→planner` vẽ phân biệt; 2 terminal `record`/`escalate_report` không cạnh-ra.
  - Chọn `approval-demo` → node `approval` vẽ **hexagon `⏸`** (khác router diamond) — nhận bàn giao #4 viewer.
  - Đổi sang `loopy`/`branchy`/`hello` → vẽ lại đúng (không vỡ, không lẫn project cũ).
  - `git diff engine/` rỗng (E.3 app-only).
- **Output artifact**: `GraphView` + custom nodes 4-loại + dagre layout + project picker.

#### Session E.4 — Tương tác: zoom / pan / drag node
- **Scope** (`app/src/` — React Flow controls):
  - Bật zoom (scroll/buttons) + pan (kéo nền) + drag node (React Flow built-in) + `fitView` + `<Controls>` + `<MiniMap>` + `<Background>`.
  - Drag node → cập nhật `position` trong state (chưa persist — E.5). Đảm bảo drag mượt, không nhảy, không reset layout khi pan/zoom.
- **STOP gate**:
  - Trên `hq`: scroll zoom in/out mượt; kéo nền pan; kéo 1 node → node theo chuột, cạnh nối lại đúng; `fitView` đưa toàn graph vào màn; minimap phản ánh viewport.
  - Reload (chưa có persist) → về auto-layout dagre (đúng — persist là E.5).
  - `git diff engine/` rỗng.
- **Output artifact**: zoom/pan/drag + Controls/MiniMap/Background.

### Sub-phase E-III — Persist layout + polish + gate

#### Session E.5 — Persist layout: `.layout.json` GET/POST (coordinate-free guarantee)
- **Scope** (`app/server.mjs` + `app/src/`):
  - Server: `GET /api/layout?project=<name>` → đọc `<project>/.layout.json` (`{positions:{id→{x,y}}, version}`) nếu có, else `{}`. `POST /api/layout?project=<name>` body `{positions}` → ghi `<project>/.layout.json` (UTF-8). **Guard #6 + path**: chỉ ghi trong project dir resolve được (tái dùng tinh thần `Test-PathInside` — chặn path traversal); TUYỆT ĐỐI không đụng `workflow.json`.
  - App: khi load graph → `GET /api/layout` → nếu có positions, dùng thay dagre (else dagre auto). Khi drag dừng (`onNodeDragStop`) → debounce → `POST /api/layout`. (Tuỳ chọn nút "Reset layout" → xoá positions → về dagre.)
- **STOP gate**:
  - Kéo thả vài node trên `hq` → reload trang → **vị trí giữ nguyên** (đọc từ `.layout.json`).
  - `<project>/.layout.json` (vd `hq/.layout.json`) tồn tại, JSON hợp lệ, chỉ chứa `positions` (KHÔNG có semantic graph).
  - **`git diff hq/workflow.json` = RỖNG** sau kéo-thả+lưu (bất biến #2 — chứng minh coordinate-free). `.layout.json` bị gitignore (không hiện trong `git status` untracked-cần-commit).
  - Đổi project → load layout riêng của project đó; project chưa có `.layout.json` → dagre auto.
  - `git diff engine/` rỗng.
- **Output artifact**: `/api/layout` GET/POST + load-on-open + save-on-drag + coordinate-free đảm bảo.

#### Session E.6 — Polish + docs + handoff + USER GATE
- **Scope** (polish nhẹ + docs):
  - **Polish**: hiển thị metadata graph (entry, max_steps, #node/#edge); trạng thái loading/empty/error khi fetch; legend ký hiệu node (worker/router/approval/terminal). KHÔNG thêm tính năng run/stream (F).
  - **README**: mục mới "App — Workflow viewer (Phase E)": cách chạy (`cd app && npm install && npm run dev` / `npm run build && node server.mjs`), chọn project, zoom/pan/drag, layout persist (`.layout.json` app-side, coordinate-free), giới hạn (chỉ xem — run/duyệt là Phase F).
  - **CLAUDE.md** bảng "Bản đồ file": hàng `company/app/` (mô tả app + server + data-layer) + cập nhật `engine/run.ps1`/`engine/viz.ps1` (`graph -Json`) + hàng `plan/hq-improve/phase-e/`.
  - **ROADMAP**: bảng tiến độ E ✅ + **Revision log: D-1 đổi sang React+Vite+Tailwind** (nêu lý do Phase F nặng + React Flow) + **§"Bàn giao E→F/G"** (app shell + GraphView + server data-layer sẵn cho F gắn SSE/run-control; in-app edit cho G).
- **STOP gate** (Done-gate Phase E đầy đủ — ROADMAP §Phase E):
  - Mở app local → chọn `hq` → thấy **11 node + 17 cạnh** đúng topo; **zoom/pan/drag mượt**; **kéo thả rồi reload giữ nguyên vị trí**; **đổi project vẽ lại đúng**; **`workflow.json` KHÔNG bị ghi toạ độ** (`git diff`=rỗng).
  - `approval-demo` vẽ gate hexagon `⏸` (bàn giao #4 viewer đóng).
  - README + CLAUDE.md + ROADMAP cập nhật (E ✅ + D-1 revise + §Bàn-giao-E→F/G).
  - Regression engine xanh (validate hello=0 · run hello -Mock=done · selftest PASS) — chứng minh app không hồi quy engine.
  - **User duyệt** đóng phase (ghi CHECKPOINT).
- **Output artifact**: polish + docs + CLAUDE.md/ROADMAP → Phase E đóng.

**Phase E gate** (sau E.6): app web (React+Vite+Tailwind) đọc `workflow.json` qua engine `-Json` → vẽ graph tương tác (4 loại node + nhãn when + back-edge + gate hexagon); zoom/pan/drag; layout dagre auto + persist `.layout.json` coordinate-free; chọn project; `workflow.json` bất biến (không toạ độ); engine chỉ thêm `-Json` (mock/ASCII/Mermaid cũ y nguyên, regression xanh); ROADMAP §Bàn-giao-E→F/G + Revision D-1 ghi đủ; user duyệt. → cập nhật ROADMAP (E ✅).

---

## Bàn giao sang F / G (ghi vào ROADMAP cuối E.6)

> E *cung cấp app shell + viewer + server data-layer*; **streaming/run-control/duyệt** thuộc F, **in-app edit** thuộc G.

| Cross-cut | E làm gì | Phase sau phải làm tiếp |
| --- | --- | --- |
| **#3 live log** | App shell + `GraphView` (highlight-able) + server data-layer sẵn | **Server stream SSE** đọc `events.ndjson` + app hiển live output + **highlight node đang chạy** trên graph → **Phase F** |
| **#3 run control + duyệt** | Server có GET/POST (data) — KHÔNG có run/decision | **Nút chạy run** (`run`/`autobuild`) + **UI duyệt plan/diff/cấp-quyền** + POST decision → engine `resume -Decision` (surface D) → **Phase F** |
| **#4 viewer** (NHẬN từ D) | ✅ App vẽ graph + ký hiệu gate `approval` (hexagon ⏸) + zoom/pan/drag + layout persist | (đóng ở E) |
| **G in-app edit** | Graph render + drag layout (read-only graph semantic) | **Sửa graph trong app** (thêm/xoá node, nối cạnh) → ghi `workflow.json` hợp lệ (`validate` pass), vẫn coordinate-free → **Phase G** (tuỳ chọn) |

**Server endpoint Phase F gắn thêm** (E đã có nền): `GET /api/health`, `GET /api/projects`, `GET /api/graph?project=`, `GET/POST /api/layout?project=`. F thêm: `POST /api/run` (spawn `run.ps1 run/autobuild`), `GET /api/events?project=&run=` (SSE tail `events.ndjson`), `POST /api/decision` (gọi `run.ps1 resume -Decision`).

---

## Outcome cuối

- App web local (`company/app/`, React+Vite+Tailwind+React Flow+dagre) đọc `workflow.json` qua **engine `run.ps1 graph -Json`** (additive, reuse `Get-Graph` — xử UTF-16 + pipeline-v1 free) → vẽ graph tương tác.
- Render đúng: 4 loại node (worker rect / router diamond / **approval hexagon ⏸** — bàn giao #4 / terminal) + cạnh có hướng + nhãn `when` + back-edge loop; verify khớp `hq` 11 node/17 cạnh + `approval-demo`.
- Tương tác: **zoom / pan / kéo thả node** (React Flow) + minimap + fitView; layout mặc định **dagre** auto.
- Persist layout **app-side** (`<project>/.layout.json` via server GET/POST) — **`workflow.json` coordinate-free bất biến** (`git diff`=rỗng sau drag; bất biến #2 + D-3).
- Chọn project (hq + examples + projects); đổi project vẽ lại đúng.
- **Engine bất biến trừ `-Json` additive** (mock/ASCII/Mermaid cũ y nguyên; regression xanh).
- `ROADMAP.md`: E ✅ + **Revision D-1** (đổi sang React stack) + §Bàn-giao-E→F/G; user duyệt.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-05-31 | Initial | Soạn long-plan Phase E từ `ROADMAP.md` §Phase E (4 mục "Cần làm rõ") + §Bàn-giao-D→E/F (#4 viewer). Chốt E-D1..E-D4 (user 2026-05-31): **REVISE D-1** → React+Vite+Tailwind (thay vanilla no-build) · React Flow · dagre · persist `.layout.json`+server-POST. 3 sub-phase / 6 session. Impl-note: data-layer dùng engine `-Json` (additive) vì `workflow.json` UTF-16 |
