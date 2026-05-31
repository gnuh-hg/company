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
| Sessions hoàn thành | 6 | 1 | 17% |
| Scaffold app (Vite+React+Tailwind+ReactFlow+dagre) | 1 | 1 | 100% |
| Data-layer (engine `-Json` + API projects/graph) | 1 | 0 | 0% |
| Render graph (4 node + cạnh + nhãn + back-edge + dagre) | 1 | 0 | 0% |
| Tương tác (zoom/pan/drag) | 1 | 0 | 0% |
| Persist layout (`.layout.json` GET/POST, coordinate-free) | 1 | 0 | 0% |
| Docs (README app · CLAUDE.md · ROADMAP E✅+D-1 revise+bàn-giao) | 1 | 0 | 0% |
| User gate (đóng phase) | 1 | 0 | — |

---

## Đang ở đâu

- **Phase**: E — App I: workflow viewer (#4). **E.1 DONE** (2026-05-31). Đang thực thi trong worktree `phase-e-1-scaffold`.
- **Session kế tiếp**: **E.2** — Data-layer: engine `run.ps1 graph <proj> -Json` (additive, reuse `Get-Graph`) + server `GET /api/projects` + `GET /api/graph?project=`. ⚠️ Session CHẠM engine → áp regression chuẩn (validate hello=0 · run hello -Mock=done · selftest PASS) + giữ output ASCII/Mermaid cũ y nguyên.
- **Blocker**: — (Phase E chỉ phụ thuộc Phase B = surface ổn định; B đã DONE. KHÔNG cần Phase D cho viewer).
- **Reference**: `PLAN.md` Phase E → Session E.2.
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

<!--
### YYYY-MM-DD — Session E.x
- **Done**: <làm gì>
- **Output**: <file/artifact>
- **Gate**: pass/fail + metric (vd "hq render 11 node/17 cạnh"; "git diff workflow.json rỗng"; "regression selftest PASS")
- **Next**: Session E.(x+1)
- **Notes**: <vấn đề phát sinh>
-->

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-31 | Created from `PLAN.md` (3 sub-phase / 6 session). Chốt stack React+Vite+Tailwind+ReactFlow+dagre (REVISE D-1) + persist `.layout.json`+server-POST (user 2026-05-31) | @claude |
