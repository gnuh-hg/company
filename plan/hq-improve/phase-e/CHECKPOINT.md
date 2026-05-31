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
| Sessions hoàn thành | 6 | 2 | 33% |
| Scaffold app (Vite+React+Tailwind+ReactFlow+dagre) | 1 | 1 | 100% |
| Data-layer (engine `-Json` + API projects/graph) | 1 | 1 | 100% |
| Render graph (4 node + cạnh + nhãn + back-edge + dagre) | 1 | 0 | 0% |
| Tương tác (zoom/pan/drag) | 1 | 0 | 0% |
| Persist layout (`.layout.json` GET/POST, coordinate-free) | 1 | 0 | 0% |
| Docs (README app · CLAUDE.md · ROADMAP E✅+D-1 revise+bàn-giao) | 1 | 0 | 0% |
| User gate (đóng phase) | 1 | 0 | — |

---

## Đang ở đâu

- **Phase**: E — App I: workflow viewer (#4). **E.1 + E.2 DONE** (2026-05-31). Làm trực tiếp trên `main` (KHÔNG worktree — worktree E.1 cũ đã mất, scaffold `app/` vẫn còn trên đĩa nên tái dùng).
- **Session kế tiếp**: **E.3** — React Flow render: `GraphView` fetch `/api/graph?project=` → map React Flow nodes/edges; custom node 4-loại (worker rect / router diamond / **approval hexagon ⏸** / terminal no-out) + nhãn `when` + back-edge phân biệt + **dagre** auto-layout (rankdir TB) + project picker từ `/api/projects`. Verify `hq` 11 node/17 cạnh đúng topo + `approval-demo` hexagon. App-only → `git diff engine/` PHẢI rỗng (đừng đụng engine).
- **Blocker**: — (data-layer E.2 đã sẵn: `/api/projects` + `/api/graph?project=` chạy thật).
- **Reference**: `PLAN.md` Phase E → Session E.3.
- **⚠️ Carry hạ tầng**: pwsh `/snap/bin/pwsh` core-dump teardown (đọc output, không tin exit code) · `workflow.json` = UTF-16 (dùng engine `-Json`, không JS-parse) · file `engine/*.ps1` có thể UTF-16 (dùng pwsh/`iconv` để soi nếu `grep` trả rỗng).

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

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-31 | Created from `PLAN.md` (3 sub-phase / 6 session). Chốt stack React+Vite+Tailwind+ReactFlow+dagre (REVISE D-1) + persist `.layout.json`+server-POST (user 2026-05-31) | @claude |
| 2026-05-31 | E.2 DONE — engine `graph -Json` additive + server `/api/projects`+`/api/graph`; selftest 12/12; engine diff = chỉ run.ps1 | @claude |
