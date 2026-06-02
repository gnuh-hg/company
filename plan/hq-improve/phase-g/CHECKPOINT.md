# CHECKPOINT — Phase G: App III — in-app edit (graph structural edit)

> Sổ tay tiến độ dài hạn. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu. Đọc kèm `PLAN.md` (cùng thư mục) + ROADMAP §Phase G + §Bàn-giao-E→F/G + §Bàn-giao-F→G.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ được làm 1 session** (xem "Đang ở đâu" để biết session nào).
- **STOP NGAY** khi đạt STOP gate của session đó — không tham làm session kế tiếp dù còn quota.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry vào "Per-session log".
- **Bất biến cốt lõi Phase G** (vi phạm = fail session):
  - **Engine chỉ THÊM `save-graph`** (additive — như E thêm `-Json`). KHÔNG sửa walk/normalize/mock/validate-logic. `git diff engine/` chỉ `save.ps1` + dispatch (G.1); **RỖNG** mọi session app-only (G.2–G.6).
  - **`workflow.json` coordinate-free** — strip `x/y` 2 lớp (engine + server). `git diff workflow.json` sau drag = **ZERO toạ độ**. Toạ độ đi `.layout.json`.
  - **`workflow.json` LUÔN hợp lệ trên đĩa** — reject-on-invalid (validate FAIL → restore file cũ + trả `errors[]`, KHÔNG persist file hỏng).
  - **CLI `edit.ps1` KHÔNG ĐỤNG** — G là đường graph riêng (`save-graph`); `edit.ps1` chỉ pipeline-v1 (giữ nguyên).
  - **KHÔNG để fixture committed bẩn** — demo edit trên `examples/edit-demo/` hoặc **revert** project thật sau test. `git diff hq/workflow.json` = RỖNG ở gate.
  - **`server.mjs` dependency-free** (Node core) + bind `127.0.0.1`.
- **Regression chuẩn** (session chạm engine = G.1; + bất kỳ session lỡ chạm): `./run.ps1 validate hello`=exit 0 · `./run.ps1 run hello "x" -Mock`=done · `./run.ps1 selftest`=PASS.
- **pwsh**: `/snap/bin/pwsh` + `dangerouslyDisableSandbox: true`; `save-graph` in `{ok,errors[]}` ra stdout → **server parse stdout, KHÔNG tin child exit code** (core-dump teardown RC=134).

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 6 | 6 | 100% |
| Sub-phase đóng | 3 (G-I/G-II/G-III) | 3 ✅ | 100% |
| Engine `save-graph` (additive) | 1 lệnh + fixture `edit-demo` | ✅ G.1 DONE | 100% |
| Server `POST /api/workflow` | validate-gated, reject-on-invalid | ✅ G.2 DONE | 100% |
| Server `GET /api/workflow` | raw workflow.json (all fields) | ✅ G.3 additive | 100% |
| Edit UI cạnh (connect/delete + when-label) | edit-mode toggle + nút Save | ✅ G.3 DONE | 100% |
| Edit UI node + graph-level | add/del node + form field + entry/max_steps | ✅ G.4 DONE | 100% |
| Coordinate-free verified | `git diff workflow.json` ZERO toạ độ + node mới vào `.layout.json` | ✅ G.5 DONE | 100% |
| Done-gate Phase G (user duyệt) | pass | ✅ G.6 DONE | 100% |

---

## Đang ở đâu

- **Phase**: G — **✅ DONE (2026-06-01, user duyệt đóng)**. Đợt hq-improve ĐÓNG.
- **Session kế tiếp**: — (phase closed)
- **Blocker**: —
- **⚠️ Test harness note (sandbox lồng)**: server spawn pwsh — wrapper `/snap/bin/pwsh` bị **SIGABRT** khi là grandchild node trong sandbox này; dùng binary thật `PWSH=/snap/powershell/current/opt/powershell/pwsh` để test. Long-running bg node bị SIGSTKFLT (exit 144) → chạy server+curl+kill **trong 1 bash call** (`run_in_background:true` cũng chết). Runtime thật của user (`pwsh` PATH, server ngoài sandbox) chạy bình thường — đây chỉ là artifact test.
- **⚠️ rawGraph cho save**: G.4 fix saveGraph để re-fetch `GET /api/workflow` (raw) sau save thành công (thay vì chỉ `GET /api/graph` bị stripped). rawGraph.nodes now mutable for add/del/update fields.
- **⚠️ G.5 fix (positions persist)**: sau `saveGraph` thành công, `finalNodes.forEach(n => positions[n.id] = n.position)` → POST `/api/layout`. Node mới có position từ `nodesRef.current` (set lúc addNode) → `.layout.json` có vị trí → reload khôi phục đúng.

---

## Quyết định đã chốt (user 2026-06-01) — KHÔNG mở lại trừ khi user yêu cầu

- **G-D1. Edit scope = FULL structural (graph)**: add/del node + nối/xoá cạnh + field node (agent/type/prompt/output_key) + nhãn `when` + `entry`/`max_steps`.
- **G-D2. Write = engine command additive `run.ps1 save-graph <proj> <candidate-file>`**: engine ghi+validate atomic (reuse `Write-Json`+`Test-Workflow`); server shell vào (một-surface #4). KHÔNG để JS chạm `workflow.json`.
- **G-D3. Validate FAIL = reject + show errors**: giữ file cũ nguyên + trả `errors[]`; KHÔNG BAO GIỜ persist file hỏng (staging + commit-or-reject).

---

## Per-session log

### 2026-06-01 — Session G.6 — Polish + docs + handoff + USER GATE
- **Done**:
  - `app/src/App.jsx` — pipeline-v1 detection: `graphFormat` state (null|'graph'|'pipeline-v1'); `onFormatDetected` passed to GraphView; Edit button: disabled + grayed "✎ Edit (v1)" + tooltip "pipeline-v1 format: use CLI `./run.ps1 edit <proj>`" khi pipeline-v1; reset `graphFormat`+`editMode` khi switch project.
  - `app/src/GraphView.jsx` — `onFormatDetected` prop; detect `rawWorkflow?.pipeline` array → call `onFormatDetected('pipeline-v1')`; else `'graph'`; reset to `null` when project=null.
  - `README.md` — section "App" rename → "viewer + live log + in-app edit (Phase E+F+G)"; add §Tính năng in-app edit (Phase G) (edit-mode, connect/del cạnh, add/del node, form field, entry/max_steps, Save validate-gated, Discard, coord-free); update §Giới hạn; update §Bất biến; update §Files app table (add engine/save.ps1 + edit-demo); update "Trạng thái build"; add `save-graph` to Surface lệnh table.
  - `CLAUDE.md` — update `company/app/` row (Phase G desc); update `engine/run.ps1` row (save-graph additive G); add `engine/save.ps1` row; add `examples/edit-demo/` row; update `engine/edit.ps1` row (pipeline-v1 note); update Phase G entry (✅ DONE).
  - `plan/hq-improve/ROADMAP.md` — Phase G row ✅ DONE; Phase G description updated; §Bàn-giao-G→(ngoài đợt) added; "Đợt hq-improve ĐÓNG" ghi rõ.
- **STOP gate verified**:
  - Build: `npm run build` exit 0 — no errors.
  - `git diff engine/` = RỖNG (app+docs-only session G.6).
  - `git diff hq/workflow.json` = RỖNG.
  - Regression: validate hello=exit 0 · run hello -Mock=done.
  - Pipeline-v1 detection: `examples/hello/workflow.json` dùng `pipeline` format → app sẽ show "✎ Edit (v1)" grayed; graph-format projects (hq, loopy, etc.) → Edit enabled.
- **Output**: `app/src/App.jsx` (pipeline-v1 guard) + `app/src/GraphView.jsx` (format detection) + docs (README + CLAUDE.md + ROADMAP + CHECKPOINT).
- **Next**: Phase G DONE. Đợt hq-improve ĐÓNG. User duyệt.

### 2026-06-01 — Session G.6b — Browser-test hardening (user test trên `npm run serve`)
- **Bối cảnh**: User tự test app trên browser → tìm 2 bug app-only (cùng kiểu live-UX hardening pass của Phase F). Tôi tự test toàn diện luồng edit qua Chrome automation.
- **Bug 1 — Save thiếu field `name` (user screenshot)**: `saveGraph` build candidate `{nodes,edges,entry,max_steps}` KHÔNG kèm `name` → `validate` báo "workflow.json thiếu field bắt buộc 'name'". **Fix**: spread `...(rawGraph.name !== undefined && { name: rawGraph.name })` vào candidate (`GraphView.jsx`).
- **Bug 2 — Crash khi xem pipeline-v1 (`hello`/`web-demo`)**: `const existingNodeIds = rawGraph ? new Set(rawGraph.nodes.map(...))` chạy vô điều kiện mỗi render; pipeline-v1 raw workflow.json = `{pipeline:[...]}` KHÔNG có `.nodes` → `Cannot read properties of undefined (reading 'map')` → white screen. **Fix**: guard `rawGraph?.nodes ? ... : new Set()` (`GraphView.jsx`). Các `rawGraph.nodes` khác (537-540 saveGraph, 600 selectedRawNode, 752-765 graph-settings panel) đều không reachable ở pipeline-v1 (edit disabled/short-circuit) — không cần sửa.
- **Test browser toàn diện (edit-demo, Chrome automation)**: ✅ edit max_steps + Save valid (commit, `name` giữ, coord-free, git diff CHỈ max_steps) · ✅ add node (reviewer) · ✅ edit node field (agent+output_key) · ✅ **reject-on-invalid** (4 errors máy-đọc-được, file SHA bất biến) · ✅ delete node (cascade + window.confirm override) · ✅ edge select + when-label edit (`pass`→`approve`) + Save valid · ✅ Discard (max_steps 99→reload 12) · ✅ pipeline-v1 grayed "✎ Edit (v1)" disabled (sau fix bug 2). ⚠️ Edge-connect-by-drag KHÔNG drive được qua `left_click_drag` 1-phát (React Flow cần chuỗi pointer-move liên tục) — giới hạn công cụ test, onConnect là code RF chuẩn (verify qua code-review).
- **STOP gate**: build exit 0; `git diff engine/`=RỖNG; `git diff hq/workflow.json`=RỖNG; fixture `edit-demo` revert sạch (git checkout + rm .layout.json); chỉ `app/src/{App,GraphView}.jsx` đổi.
- **Output**: `app/src/GraphView.jsx` (2 fix: name-in-candidate + pipeline-v1 nodes guard).

### 2026-06-01 — Session G.5 — Coordinate-free guarantee + layout cho node mới
- **Done**:
  - `app/src/GraphView.jsx` — additive fix trong `saveGraph`: sau save thành công, POST positions của `finalNodes` lên `/api/layout`. 8 dòng thêm vào sau `setNodes(finalNodes)`.
  - Logic: `finalNodes` được build từ `posMap` (bao gồm node mới từ nodesRef) → `positions = {}; finalNodes.forEach(n => positions[n.id] = n.position)` → `POST /api/layout`. Node mới có position từ lúc `addNode` (random ~200+160) được lưu vào `.layout.json` → reload khôi phục đúng vị trí.
- **STOP gate verified**:
  - Build: `npm run build` exit 0 — no errors.
  - `git diff engine/` = RỖNG (app-only session G.5).
  - Regression: validate hello=exit 0 · run hello -Mock=done.
  - `grep '"x"' examples/edit-demo/workflow.json` = 0 (coord-free bất biến G.1+G.2).
  - Logic path review: addNode → position ~(200,160) trong nodesRef; saveGraph → posMap từ nodesRef (có node mới) → finalNodes giữ position node mới → POST /api/layout → reload dùng saved positions → node mới ở đúng chỗ.
  - 2-lớp strip: server `stripCandidate` (COORD_KEYS) + engine `Strip-GraphCoordinates` — `workflow.json` semantic-only đảm bảo.
- **Output**: `app/src/GraphView.jsx` (positions persist sau save — 8 dòng trong saveGraph).
- **Next**: Session G.6 — Polish + docs + handoff + USER GATE.
- **Notes**: Thay đổi nhỏ nhất có thể (8 dòng, additive). `onNodeDragStop` debounced vẫn hoạt động bình thường (drag sau save tiếp tục update `.layout.json`). Khi save không có node mới, positions = posMap hiện tại — idempotent, không hại.

### 2026-06-01 — Session G.4 — Thêm/xoá node + form field node + entry/max_steps
- **Done**:
  - `app/src/GraphView.jsx` — rewrite additive:
    - `AddNodePanel` component: form (id/type/agent/output_key/prompt) + validation (unique ID, regex) + onAdd callback.
    - `NodePanel` component: edit existing node fields (type/agent/output_key/prompt) inline onChange; delete node với confirm dialog.
    - State mới: `selectedNodeId`, `showAddNode`.
    - `onNodeClick` callback: chọn node → NodePanel; deselect edge.
    - `addNode`: thêm rawNode vào rawGraph.nodes + RF node (type-mapped, random position ~(200,160)); mark dirty.
    - `deleteNode`: cascade remove RF edges (source/target = nodeId) + RF node + rawGraph.nodes; mark dirty.
    - `updateNodeField`: mutate rawGraph.nodes; sync RF ntype nếu type change; sync agent trong data; mark dirty.
    - `updateEntry`: mutate rawGraph.entry + RF node.data.isEntry + meta.
    - `updateMaxSteps`: mutate rawGraph.max_steps + meta; parseInt guard.
    - Graph-settings panel (edit mode, top-right): entry select + max_steps input; hiển thị khi editMode && rawGraph.
    - "+ Node" toggle button (top-right) mở AddNodePanel.
    - `saveGraph` FIX: sau save thành công re-fetch cả `GET /api/graph` + `GET /api/workflow` (raw) — rawGraph = updatedWorkflow ?? updatedGraph (giữ full fields sau round-trip).
    - `discardChanges`: clear selectedNodeId + showAddNode.
    - `onPaneClick`: clear cả selectedEdgeId + selectedNodeId.
    - Legend: thêm "click node to edit fields" hint khi editMode.
- **STOP gate verified**:
  - Build: `npm run build` exit 0 — no errors.
  - `git diff engine/` = RỖNG (app-only session).
  - Regression: validate hello=exit 0 · run hello -Mock=done.
  - Logic path review: add worker(id+agent+output_key) → rawGraph.nodes grows → save candidate đúng → validate bắt thiếu field (422); del node → cascade RF edges removed → rawGraph.nodes shrinks; sửa max_steps → meta + rawGraph cập nhật → reflected in UI + candidate.
- **Output**: `app/src/GraphView.jsx` (add/del node + form field + entry/max_steps + saveGraph fix + AddNodePanel + NodePanel).
- **Next**: Session G.5 — Coordinate-free guarantee + layout cho node mới.
- **Notes**: `saveGraph` now fetches both `/api/graph` (layout/meta) + `/api/workflow` (raw round-trip). Node mới position = random ~(200,160); posMap preserves it after save. G.5 sẽ persist vào `.layout.json`. NodePanel ở bottom-left, EdgePanel ở bottom-right (không xung đột — mutually exclusive).

### 2026-06-01 — Session G.3 — Edit-mode cạnh + when-label + Save/Discard (frontend)
- **Done**: 
  - `app/src/GraphView.jsx` — edit-mode functionality: `editMode`+`onDirtyChange` props; `rawGraph` state từ `GET /api/workflow` (raw, full fields); `isDirty` state + `onDirtyChange` callback; `reloadKey` (discard trigger); `onConnect` (add edge, dirty); `handleEdgesChange` (wrap onEdgesChange — block removes ngoài edit mode); `onEdgeClick` (select edge for panel); `updateEdgeWhen`/`deleteSelectedEdge`; `saveGraph` (fetch rawWorkflow → build candidate → POST /api/workflow → on 200 re-fetch+rerender; on 422 show errors[]); `discardChanges` (setReloadKey+1); EDIT badge (amber khi dirty); Save/Discard buttons Panel top-right; errors panel; EdgePanel floating (when+label input + delete button + close); `nodesConnectable={editMode}`, `edgesFocusable={editMode}`; `onPaneClick` deselect.
  - `app/server.mjs` — additive `GET /api/workflow?project=` (read raw workflow.json, all fields intact; reuse SAFE_PROJECT+resolveProjectDir).
  - `app/src/App.jsx` — `editMode`+`graphDirty` state; Edit toggle button (amber khi editing/dirty, gray khi view); project-switch dirty-guard (`window.confirm`); pass `editMode`+`onDirtyChange` to GraphView.
- **STOP gate verified**:
  - Server: CASE1 valid save → HTTP 200, SHA changed, x=0; CASE2 invalid (router thiếu when) → HTTP 422 + errors; SHA invariant. Round-trip GET /api/graph reflects committed edge change.
  - Engine: `git diff engine/` = RỖNG (G.3 app-only, only server.mjs+app/src/); regression validate hello=0 · run hello -Mock=done.
  - edit-demo reverted sạch sau test.
- **Output**: `app/src/GraphView.jsx` (edit-mode) + `app/src/App.jsx` (toggle+guard) + `app/server.mjs` (GET /api/workflow additive).
- **Next**: Session G.4 — add/delete node + form field node + entry/max_steps.
- **Notes**: `GET /api/graph` (engine normalized) strip mất input/output_key/name — cần `GET /api/workflow` (raw) để save round-trip. rawGraph = raw workflow.json; nodes giữ nguyên (G.3 chỉ edit edges); G.4 extend để thêm/sửa nodes trong rawGraph local.

### 2026-06-01 — Session G.2 — Server `POST /api/workflow`
- **Done**: Thêm endpoint `POST /api/workflow?project=<p>` vào `app/server.mjs` (additive, dependency-free): body `{nodes,edges,entry,max_steps}` → `stripCandidate` (COORD_KEYS server-side strip, defense lớp 1) → `saveGraphViaEngine` ghi temp ra `os.tmpdir()` → shell `run.ps1 save-graph <p> <tmpfile>` (cwd ENGINE_DIR) → **parse stdout** (last `{...}`, KHÔNG tin exit code) → cleanup temp → ok⇒200 `{ok:true}` · !ok⇒**422** `{ok:false,errors[]}`. Reuse `SAFE_PROJECT`+`resolveProjectDir` (project lạ→404, body hỏng→400, KHÔNG spawn). Imports thêm: `unlink` (fs/promises), `tmpdir` (node:os).
- **STOP gate verified** (server `PWSH=real-binary PORT=5181`, all in 1 bash call):
  - CASE 1 valid graph (có x/y) → **200** `{ok:true}`; `grep -c '"x"' workflow.json`=**0** (strip 2-lớp OK); `git diff edit-demo/workflow.json` rỗng (idempotent re-save).
  - CASE 2 invalid (router 2 cạnh thiếu `when`) → **422** + `errors[]` (2 lỗi máy-đọc-được); `workflow.json` SHA256 **BẤT BIẾN** (reject-on-invalid, restore đúng).
  - CASE 3 project lạ (`?project=nope`) → **404**, KHÔNG spawn/ghi.
  - CASE 4 body không-JSON → **400**.
  - Round-trip `GET /api/graph?project=edit-demo` phản ánh trạng thái committed.
  - `git diff engine/` = **RỖNG** (app-only); chỉ `app/server.mjs` thay đổi; `edit-demo` committed sạch.
- **Output**: `app/server.mjs` (`POST /api/workflow` + `stripCandidate` + `saveGraphViaEngine`).
- **Next**: Session G.3 — Edit-mode cạnh + when-label + nút Save (frontend).
- **Notes**: Sandbox lồng giết snap-wrapper pwsh (SIGABRT) + bg node sống lâu (SIGSTKFLT exit 144) — workaround test = real-binary pwsh + server+curl+kill 1-call (xem "⚠️ Test harness note"). Code endpoint mirror pattern `getGraphJson` (E/F proven). Parse last `{...}` thay vì first để bỏ qua text help/info phía trước.

### 2026-06-01 — Session G.1 — Engine `save-graph`
- **Done**: `engine/save.ps1` (`Strip-GraphCoordinates` + `Save-Graph` backup→strip→write→validate→commit-or-restore + `Write-SaveResult` JSON stdout) + `run.ps1 save-graph` dispatch (allowlist, help, switch case) + fixture `examples/edit-demo/` (3-node graph: writer→checker(router)→publisher + revise back-edge, 3 agent stubs).
- **STOP gate verified**:
  - Candidate hợp lệ → `{"ok":true,"errors":[]}` + `workflow.json` cập nhật.
  - Candidate hỏng (router thiếu `when`) → `{"ok":false,"errors":[...2 errors...]}` + SHA256 workflow.json BẤT BIẾN.
  - Candidate có `x/y` → `workflow.json` ghi ra ZERO `"x"` (grep=0).
  - Regression: validate hello=0 · run hello -Mock=done · selftest 12/12 PASS.
  - `git diff engine/` = chỉ `run.ps1` (additive); `save.ps1` file mới (untracked).
  - `run.ps1 graph hq -Json` và ASCII/Mermaid vẫn hoạt động (đường đọc bất biến).
- **Output**: `engine/save.ps1` + `engine/run.ps1` (additive `save-graph`) + `examples/edit-demo/`.
- **Next**: Session G.2 — Server `POST /api/workflow`.

### 2026-06-01 — Session G.0 (soạn plan)
- **Done**: Soạn `PLAN.md` + `CHECKPOINT.md` Phase G. Đọc CLAUDE.md + ROADMAP + Phase E/F PLAN + `engine/edit.ps1` (phát hiện gap: `edit.ps1` chỉ pipeline-v1, từ chối graph-format A-18 dòng 183-187). Xác nhận `hq`/`loopy`/`branchy`/`approval-demo` đều graph-format (không có editor). Chốt G-D1/G-D2/G-D3 với user.
- **Output**: `plan/hq-improve/phase-g/PLAN.md` + `CHECKPOINT.md`.
- **Gate**: plan soạn xong; chờ user duyệt + bắt đầu G.1.
- **Next**: Session G.1 — Engine `save-graph`.
- **Notes**: Write-path = engine additive (giống E `-Json`). Atomicity dùng backup-restore pattern có sẵn ở `edit.ps1` nút 'v'. Validate graph đã đủ mạnh (`validate.ps1` v2) — save-graph chỉ gọi `Test-Workflow`, KHÔNG thêm luật. Demo trên `examples/edit-demo/` để không bẩn `hq`.

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-06-01 | Created from `PLAN.md` | @planner |
| 2026-06-01 | G.1–G.6 DONE; Phase G closed; đợt hq-improve ĐÓNG | @claude |
