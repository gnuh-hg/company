# CHECKPOINT — Phase E: App I — Workflow viewer

> Sổ tay tiến độ. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu. Đọc kèm `plan/hq-improve/phase-e/PLAN.md` + `plan/hq-improve/ROADMAP.md` §Phase E + §Bàn-giao-D→E/F + cross-cutting D-1/D-3.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu"). **STOP NGAY** khi đạt STOP gate — không tham làm session kế tiếp.
- **Bất biến cốt lõi #2 (quan trọng NHẤT Phase E)**: app **TUYỆT ĐỐI KHÔNG ghi toạ độ vào `workflow.json`**. Toạ độ đi `<project>/.layout.json`. Done-gate mỗi session chạm layout: kiểm `git diff <project>/workflow.json` = RỖNG.
- **Engine chỉ THÊM `-Json`** (E.2). Mọi session khác `git diff engine/` PHẢI rỗng. `-Json` additive — KHÔNG đổi output ASCII/Mermaid/mock cũ; reuse `Get-Graph` (hàm thuần, #1) + dot-source-safe (#5).
- **Stack đã chốt**: React + Vite + Tailwind + **React Flow (xyflow)** + **dagre** (REVISE D-1 cũ — đã ghi ROADMAP). Đặt tại `company/app/` (#6 chỉ trong `company/`).
- **Persist**: file `<project>/.layout.json` (gitignore) + server `GET/POST /api/layout`. Server E **không** run-control/SSE (để F).
- **`workflow.json` mã hoá UTF-16** → KHÔNG parse bằng JS. Data-layer gọi engine `run.ps1 graph <proj> -Json` (reuse loader, xử encoding free).
- **Regression chuẩn (session CHẠM engine = E.2)**: `./run.ps1 validate hello`=0 · `./run.ps1 run hello "x" -Mock`=done · `./run.ps1 selftest`=PASS. Dọn `.runs/` + mem-demo memory + sandbox sau verify.
- **pwsh**: `/snap/bin/pwsh` + `dangerouslyDisableSandbox: true`; `pwsh -NoProfile -Command '<inline>' 2>&1 | cat`; đọc NỘI DUNG output, KHÔNG tin exit code (core-dump teardown). Tránh `-File` mode.
- **Node**: `npm`/`node` trong `company/app/`. `npm install` lần đầu (E.1). `.gitignore` đã loại `app/node_modules/`+`app/dist/`+`**/.layout.json`.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log".

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 6 | 4 | 67% |
| Scaffold app (Vite+React+Tailwind+ReactFlow+dagre) | 1 | 1 | 100% |
| Data-layer (engine `-Json` + API projects/graph) | 1 | 1 | 100% |
| Render graph (4 node + cạnh + nhãn + back-edge + dagre) | 1 | 1 | 100% |
| Tương tác (zoom/pan/drag) | 1 | 1 | 100% |
| Persist layout (`.layout.json` GET/POST, coordinate-free) | 1 | 1 | 100% |
| Docs (README app · CLAUDE.md · ROADMAP E✅+D-1 revise+bàn-giao) | 1 | 0 | 0% |
| User gate (đóng phase) | 1 | 0 | — |

---

## Đang ở đâu

- **Phase**: E — App I: workflow viewer (#4). **E.1 + E.2 + E.3 + E.4 + E.5 DONE**. Làm trực tiếp trên `main`.
- **Session kế tiếp**: **E.6** — Polish + docs + handoff + USER GATE. Scope: hiển thị metadata graph (entry/max_steps/#node/#edge đã có từ E.3); README mục "App — Workflow viewer"; cập nhật CLAUDE.md bảng file; ROADMAP E✅ + Revision D-1 + §Bàn-giao-E→F/G; user duyệt đóng phase.
- **Blocker**: — (E.5 STOP gate PASS đầy đủ; build 486 modules; engine diff RỖNG; workflow.json bất biến).
- **Reference**: `PLAN.md` Phase E → Session E.6.
- **⚠️ Carry hạ tầng**: pwsh `/snap/bin/pwsh` core-dump teardown (đọc output, không tin exit code) · `workflow.json` = UTF-16 (dùng engine `-Json`, không JS-parse).

---

## Tham chiếu kỳ vọng (verify render đúng)

- **`hq`**: 11 node (`coo`·`researcher`·`rg_gate`·`clarify_gate`·`planner`·`cto`·`builder`·`tester`·`escalate_gate`·`escalate_report`·`record`), 17 cạnh, `entry=coo`, `max_steps=40`. Router (diamond): `coo`(build/fix/unclear)·`rg_gate`(enough/need_clarify)·`clarify_gate`(ok/missing_input)·`tester`(pass/fail_fix/fail_replan/escalate)·`escalate_gate`(resolved/escalate). Back-edge: `tester→builder`·`tester→planner`. Terminal: `record`·`escalate_report`. (Nguồn `hq/workflow.mmd`.)
- **`approval-demo`**: có node `type:approval` → render hexagon `⏸` (bàn giao #4 viewer từ D).
- Project khả-vẽ khác: `loopy` (loop+router), `branchy` (router OR 4 nhánh), `hello` (pipeline-v1 — chứng minh engine `-Json` reuse loader cũ).

---

## Per-session log

### 2026-05-31 — Session E.1 — Scaffold app + server skeleton
- **Done**: Dựng `company/app/` từ số 0 — Vite 6 + React 18 + Tailwind 3 (config classic `tailwind.config.js`+`postcss.config.js`+directives) + deps React Flow (`@xyflow/react` v12) + dagre. `server.mjs` Node-http thuần (serve `dist/` static + SPA fallback + `GET /api/health`; path-traversal guard; `/api/*` lạ → 404 JSON). App.jsx placeholder ping `/api/health`. `.gitignore` += `app/node_modules/` + `app/dist/` + `**/.layout.json`.
- **Output**: `app/{package.json,vite.config.js,tailwind.config.js,postcss.config.js,index.html,server.mjs}` + `app/src/{main.jsx,App.jsx,index.css}` + `.gitignore` cập nhật.
- **Gate**: PASS — `npm install` exit 0 (154 pkg, 9/9 deps chính có); `npm run build` → `dist/index.html` (có `#root`) + tailwind css bundled; `node server.mjs` (PORT=5179) → `curl /api/health`=`{"ok":true}` + `curl /`=HTML có `#root` + `/api/bogus`=404 JSON. `git diff engine/`=RỖNG (E.1 app-only).
- **Next**: Session E.2 — engine `graph -Json` additive + server `/api/projects`+`/api/graph`.
- **Notes**: Tailwind pin v3 (không v4) để khớp plan (config file + postcss plugin). React Flow package = `@xyflow/react` (v12, kế thừa `reactflow` v11). Worktree `phase-e-1-scaffold`; `plan/hq-improve/phase-e/` untracked ở main nên copy vào worktree để cập nhật cùng nhánh. Server port mặc định 5179 (dev Vite proxy 5173→5179).

### 2026-05-31 — Session E.2 — Data-layer: engine `-Json` + API graph/projects
- **Done**: (1) **Engine additive** — `run.ps1 graph <proj> -Json`: thêm flag `-Json` vào `Split-DispatchArgs` (init + switch arm + cả 2 return hashtable) + nhánh JSON trong dispatch `graph` (reuse `Get-Graph`, emit `{entry,max_steps,nodes:[{id,agent,type,prompt?}],edges:[{from,to,when?}]}`). **Bug bắt+fix**: output ban đầu rỗng vì footer `$code = Invoke-Dispatch $args` nuốt pipeline output → ghi thẳng bằng `[Console]::Out.WriteLine($jsonText)` thay vì để rơi xuống pipeline. (2) **Server** `server.mjs` — thêm `GET /api/projects` (quét `projects/`>`examples/`>`hq`, lọc có `workflow.json`, dedup theo precedence) + `GET /api/graph?project=` (spawn `pwsh run.ps1 graph <p> -Json`, tin stdout không tin exit-code, path-guard regex `^[A-Za-z0-9._-]+$`).
- **Output**: `engine/run.ps1` (+21 dòng, BOM/CRLF giữ nguyên) + `app/server.mjs` (3 endpoint mới).
- **Gate**: PASS. Engine direct `-Json` 5/5 project: `hq`=11n/17e/5router/entry=coo/max=40, `loopy`=4n/4e, `branchy`=6n/8e, `hello`=2n/1e (pipeline-v1 reuse loader ✓), `approval-demo`=3n/2e types=`approval|work` ✓. Server: health ok · `/api/projects`=18 project (đủ hq/loopy/branchy/hello/approval-demo) · `/api/graph?project=hq`=11/17 · `approval-demo`=approval|work · missing-param=400 · bad-name=`invalid project name`. **Regression chuẩn**: validate hello=exit0 · run hello -Mock=done · graph hq ASCII+Mermaid path y nguyên · **selftest 12/12 PASS**. Scope: `git diff engine/`=chỉ `run.ps1` · không `.mmd`/`workflow.json` đổi · `app/` untracked.
- **Next**: Session E.3 — React Flow render + dagre + project picker.
- **Notes**: ⚠️ Đầu session phát hiện worktree `phase-e-1-scaffold` (E.1) đã mất — NHƯNG `app/` scaffold vẫn còn trên đĩa (untracked, gitignore nuốt node_modules/dist nên git tưởng mất). E.1 thực chất còn nguyên + server health re-verify PASS → KHÔNG re-scaffold, chỉ làm tiếp E.2 trên `main`. Patch engine dùng Python (giữ BOM `utf-8-sig` + CRLF) với anchor-count guard (abort nếu ≠1) thay vì Edit tool để an toàn encoding. `pwsh` qua `/bin/bash --noprofile --norc` (profile zsh gây nhiễu) — đọc output file, không tin exit code.

### 2026-05-31 — Session E.3 — React Flow render: node 4-loại + dagre + project picker
- **Done**: (1) **`app/src/layout.js`** — `applyDagreLayout(nodes, edges)`: dagre TB layout (ranksep=80, nodesep=44) → set positions + detect back-edges (source.y > target.y = đi ngược chiều layout). (2) **`app/src/nodes.jsx`** — 4 custom node types: `WorkerNode` (rect, blue left-border) / `RouterNode` (diamond via clip-path, amber) / `ApprovalNode` (hexagon via clip-path, violet, ⏸) / `TerminalNode` (green/red border based on id pattern). Export `nodeTypes` map. (3) **`app/src/GraphView.jsx`** — fetch `/api/graph?project=` → `toReactFlow()` (engine type `'work'` → worker/terminal by topology; `router`/`approval` by type) → `applyDagreLayout` → `styleBackEdges` (back-edge = orange dashed bezier) → `ReactFlow` với Controls+MiniMap+Background + metadata strip + legend. (4) **`app/src/App.jsx`** — project picker (dropdown từ `/api/projects`, default `hq`) + `ReactFlowProvider` wrapper. (5) `vite.config.js` += `optimizeDeps: {include: ['dagre']}` (CJS dep).
- **Output**: `app/src/{layout.js,nodes.jsx,GraphView.jsx}` (new) + `App.jsx` + `vite.config.js` (updated).
- **Gate**: `npm run build` pass (486 modules, 427KB JS, 24KB CSS) · server `/api/health`+`/api/projects` (18 proj, all 5 required present)+`/api/graph?project=hq` (11n/17e/entry=coo) · `approval-demo` gate→approval ntype → ApprovalNode hexagon · dagre smoke test (back-edge `router→worker1` detected, PASS) · `git diff engine/` = EMPTY. ⚠️ Visual verify không thực hiện được (browser extension không kết nối) — cần user verify khi chạy `npm run dev`.
- **Next**: Session E.4 — tương tác zoom/pan/drag mượt (React Flow built-in đã gắn trong GraphView, cần verify behavior).
- **Notes**: Engine trả `type: 'work'` (không phải `'worker'`), nhưng `toReactFlow` phân loại bằng topology (has outgoing edges?) nên không bị ảnh hưởng. `FitOnLoad` helper dùng `useReactFlow` hook + setTimeout 80ms để React Flow đo node dimensions trước khi fitView. Dagre multigraph mode cần edge ID unique (dùng `e.id`).

### 2026-05-31 — Session E.4 — Tương tác: zoom/pan/drag
- **Done**: (1) **`app/src/nodes.jsx`** — Fix border rendering trên `RouterNode` và `ApprovalNode`: `border` CSS bị clip khi dùng `clip-path`, dùng two-layer technique thay thế (outer div = border color, inner div `inset:2` = fill color — cho polygon outline đúng hình). (2) **`app/src/GraphView.jsx`** — Bỏ `fitView` prop khỏi `<ReactFlow>` component (redundant với `FitOnLoad` helper đã có từ E.3; `FitOnLoad` trigger sau 80ms khi node đã đo xong nên timing chính xác hơn). Thêm explicit `panOnDrag`, `zoomOnScroll`, `nodesDraggable` props cho rõ ràng.
- **Output**: `app/src/nodes.jsx` (border fix) + `app/src/GraphView.jsx` (fitView + props).
- **Gate**: PASS — `npm run build` exit 0 (486 modules, 427KB JS) · server (đã chạy từ E.3) `/api/health`=`{"ok":true}` · `/api/projects`=18 · `/api/graph?project=hq`=11n/17e/entry=coo/max_steps=40/5 routers · `approval-demo`=1 approval node (type=`approval`) · `git diff engine/`=RỖNG. ⚠️ Visual verify zoom/pan/drag không thực hiện được qua browser extension — user cần mở `http://localhost:5179` để confirm tương tác trực tiếp.
- **Next**: Session E.5 — persist layout `.layout.json` GET/POST (server + app).
- **Notes**: Drag không reset layout vì `useEffect` trong GraphView chỉ depend `[project]` → pan/zoom/drag không trigger re-layout. `useNodesState` + `onNodesChange` handle position updates đúng chuẩn.

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-31 | Created from `PLAN.md` (3 sub-phase / 6 session). Chốt stack React+Vite+Tailwind+ReactFlow+dagre (REVISE D-1) + persist `.layout.json`+server-POST (user 2026-05-31) | @claude |
| 2026-05-31 | E.2 DONE — engine `graph -Json` additive + server `/api/projects`+`/api/graph`; selftest 12/12; engine diff = chỉ run.ps1 | @claude |
| 2026-05-31 | E.3 DONE — React Flow render 4-loại node + dagre + project picker; engine diff = EMPTY | @claude |
| 2026-05-31 | E.4 DONE — tương tác zoom/pan/drag; fix border rendering RouterNode+ApprovalNode (two-layer clip-path); bỏ fitView prop (FitOnLoad handles); build pass; engine diff = EMPTY | @claude |
| 2026-05-31 | E.5 DONE — persist layout `.layout.json` GET/POST: server `resolveProjectDir`+path-guard+writeFile; app load layout song song với graph (saved positions override dagre), `onNodeDragStop` debounce 600ms → POST; build pass (486 modules); STOP gate 6/6 PASS; workflow.json RỖNG; engine diff RỖNG | @claude |
