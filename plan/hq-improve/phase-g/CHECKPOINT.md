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
| Sessions hoàn thành | 6 | 2 | 33% |
| Sub-phase đóng | 3 (G-I/G-II/G-III) | 0 (G-I 2/2 ✅) | 0% |
| Engine `save-graph` (additive) | 1 lệnh + fixture `edit-demo` | ✅ G.1 DONE | 100% |
| Server `POST /api/workflow` | validate-gated, reject-on-invalid | ✅ G.2 DONE | 100% |
| Edit UI (cạnh + node + graph-level) | full structural | — | — |
| Coordinate-free verified | `git diff workflow.json` ZERO toạ độ | — | — |
| Done-gate Phase G (user duyệt) | pass | — | — |

---

## Đang ở đâu

- **Phase**: G (App III — in-app edit; **tuỳ chọn — user chốt LÀM** 2026-06-01 vì gap CLI edit không phủ graph-format)
- **Session kế tiếp**: **G.3 — Edit-mode: nối/xoá cạnh + sửa nhãn `when` + nút Save (frontend)**
- **Blocker**: — (G.2 DONE; `POST /api/workflow` sẵn trên `server.mjs`, validate-gated, reject-on-invalid, coord-strip)
- **Reference**: `PLAN.md` Phase G → Session G.3 · ROADMAP §Phase G
- **Nhắc G.3** (frontend `app/src/`, KHÔNG đụng engine): edit-mode toggle (tách view/run E/F) → React Flow `onConnect`/`onEdgesDelete` + sửa nhãn `when` (pending-state cục bộ) → nút "Save graph" gom semantic graph (nodes/edges/entry/max_steps — KHÔNG toạ độ) `POST /api/workflow?project=` → 200 toast+re-fetch `GET /api/graph`; 422 → panel `errors[]`. Discard = reload-from-server. Cảnh báo unsaved khi đổi project/rời. `git diff engine/` PHẢI rỗng.
- **⚠️ Test harness note (sandbox lồng)**: server spawn pwsh — wrapper `/snap/bin/pwsh` bị **SIGABRT** khi là grandchild node trong sandbox này; dùng binary thật `PWSH=/snap/powershell/current/opt/powershell/pwsh` để test. Long-running bg node bị SIGSTKFLT (exit 144) → chạy server+curl+kill **trong 1 bash call** (`run_in_background:true` cũng chết). Runtime thật của user (`pwsh` PATH, server ngoài sandbox) chạy bình thường — đây chỉ là artifact test.

---

## Quyết định đã chốt (user 2026-06-01) — KHÔNG mở lại trừ khi user yêu cầu

- **G-D1. Edit scope = FULL structural (graph)**: add/del node + nối/xoá cạnh + field node (agent/type/prompt/output_key) + nhãn `when` + `entry`/`max_steps`.
- **G-D2. Write = engine command additive `run.ps1 save-graph <proj> <candidate-file>`**: engine ghi+validate atomic (reuse `Write-Json`+`Test-Workflow`); server shell vào (một-surface #4). KHÔNG để JS chạm `workflow.json`.
- **G-D3. Validate FAIL = reject + show errors**: giữ file cũ nguyên + trả `errors[]`; KHÔNG BAO GIỜ persist file hỏng (staging + commit-or-reject).

---

## Per-session log

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
