# PLAN — Phase G: App III — in-app edit (graph structural edit)

> Sau toàn bộ Phase G: từ **app web local** (nền Phase E viewer + F live-log) **sửa cấu trúc graph ngay trong app** — thêm/xoá node, nối/xoá cạnh, sửa field node (agent/type/prompt/output_key), sửa nhãn `when`, sửa `entry`/`max_steps` — bấm **Save** → engine ghi `workflow.json` qua đường **validate-gated** (`run.ps1 save-graph`): chỉ commit khi `validate` pass, fail thì **giữ file cũ + trả `errors[]`** cho app hiện. `workflow.json` LUÔN hợp lệ + **coordinate-free** (toạ độ node mới đi `.layout.json`, không vào `workflow.json`). Lấp đúng **gap**: CLI `edit` chỉ sửa pipeline-v1 và TỪ CHỐI graph-format (`hq`/`loopy`/`branchy`/`approval-demo` hiện KHÔNG có editor nào). Đóng Phase G (tuỳ chọn) + đóng trọn đợt **hq-improve**.

---

## Context

- **Vì sao chia nhiều session**: Phase G thêm **đường GHI** (write-path) vào hệ thống tới giờ chỉ-ĐỌC (E vẽ, F stream — đều read-only semantic). Gồm 2 khối: (1) **backend write-validate-commit** (engine command additive `save-graph` ghi atomically + validate-trước-khi-commit + server endpoint shell vào) — nhiều ca lỗi (atomicity, reject-restore, coordinate-strip, encoding); (2) **frontend edit UI** (React Flow edit-mode: connect/delete edge, add/delete node, form field node, graph-level entry/max_steps) — tương tác phong phú, dễ ẩu nếu gom 1 chat. Chia theo **lớp xây tăng dần**: engine writer → server endpoint → edit cạnh → edit node + graph-level → coordinate-free guarantee + layout node mới → polish+docs+gate.
- **Phase G là TUỲ CHỌN** (ROADMAP §Phase G; user: "sửa thì nếu phức tạp cho bằng lệnh là được"). **Quyết định LÀM** vì phát hiện gap thật: CLI `edit` (`engine/edit.ps1`) chỉ hiểu **pipeline-v1** và **CHỦ ĐỘNG TỪ CHỐI** workflow dạng GRAPH (`nodes`/`edges`) — fix A-18 (`edit.ps1:183-187`). Mọi project graph (`hq` 11-node, `loopy`, `branchy`, `approval-demo`) hiện **không có editor visual/TUI nào**. In-app edit KHÔNG trùng CLI — nó là **complement** (CLI = pipeline-v1, app = graph-format).
- **Quyết định đã chốt (user 2026-06-01):**
  - **G-D1. Edit scope = FULL structural (graph).** Thao tác: **thêm/xoá node** + **nối/xoá cạnh** + **sửa field node** (agent / type worker·router·approval·terminal / prompt / output_key) + **sửa nhãn `when`** + **sửa `entry`/`max_steps`**. Đủ để node mới pass `validate` (worker cần agent+output_key; router cần ≥2 cạnh mỗi cạnh có `when`; `approval` miễn agent/output). Lấp đúng phần CLI edit không làm được.
  - **G-D2. Write mechanism = engine command additive (`run.ps1 save-graph <proj> <candidate-file>`).** Engine làm chủ ghi+validate atomically (reuse `Write-Json` UTF-8-no-BOM + `Test-Workflow`); server **shell** vào (giữ "một surface" #4). Giống cách Phase E thêm `-Json` (additive, không đổi path cũ). KHÔNG để JS chạm `workflow.json` trực tiếp (carry bài học E: không parse/ghi workflow.json bằng JS).
  - **G-D3. Validate FAIL = reject + show errors (KHÔNG BAO GIỜ persist file hỏng).** Save → validate: PASS → commit `workflow.json`; FAIL → **giữ file cũ nguyên** + trả `errors[]` cho app hiện. Staging + commit-or-reject. `workflow.json` LUÔN hợp lệ trên đĩa (bất biến mới của G).
- **Bàn giao NHẬN từ phase trước (làm trong G):** (ROADMAP §Bàn-giao-E→F/G + §Bàn-giao-F→G)
  - **Từ Phase E** — app shell + `GraphView` (React Flow render 4-loại node + nhãn `when` + back-edge + approval hexagon ⏸) + dagre auto-layout + **persist `.layout.json`** (GET/POST `/api/layout`, coordinate-free) + project picker + data-layer `GET /api/graph` (engine `graph -Json` chuẩn hoá). G **gắn edit-mode + write-path** lên nền này.
  - **Từ Phase F** — live highlight + `server.mjs` (Node http dependency-free, đã có `/api/health`·`/api/projects`·`/api/graph`·`/api/layout`·`/api/run`·`/api/events`·`/api/decision`). G **thêm 1 endpoint** `POST /api/workflow` lên server này, KHÔNG dựng lại.
- **De-risk / vật chứng (đọc trước khi code):**
  - **⚠️ CLI `edit` là pipeline-v1, KHÔNG đụng nó.** `engine/edit.ps1` từ chối graph-format (A-18). G **KHÔNG sửa** `edit.ps1`; `save-graph` là **module/đường riêng** cho graph-format (bù trừ, không thay thế).
  - **⚠️ Atomicity write-validate-commit:** `Test-Workflow` đọc `<dir>/workflow.json` TỪ ĐĨA. Để validate candidate mà không phá file thật → dùng **pattern backup-write-validate-restore** (đã có tiền lệ `edit.ps1:285-295` nút 'v'): (1) backup `ReadAllText` file hiện tại; (2) `Write-Json` candidate → `workflow.json`; (3) `Test-Workflow`; (4) errs==0 → giữ (`ok:true`); errs>0 → **restore backup** (`WriteAllText`) → `ok:false`+`errors[]`. → file thật chỉ đổi khi validate PASS.
  - **⚠️ pwsh hạ tầng** (carry C/D/E/F): `/snap/bin/pwsh` (7.6.2) hay core-dump RC=134 lúc teardown — **đọc NỘI DUNG output, KHÔNG tin exit code**. Hệ quả: `save-graph` PHẢI in **kết quả máy-đọc-được** ra stdout (vd JSON 1 dòng `{"ok":bool,"errors":[...]}`, theo pattern `Write-CheckResult`/`Write-E2EResult`) → server parse stdout, không chỉ dựa exit code. Chạy tay: `pwsh -NoProfile ... 2>&1 | cat` + `dangerouslyDisableSandbox: true`.
  - **⚠️ Coordinate-free (bất biến #2):** candidate từ app có thể lẫn `x/y`/`position` (React Flow node) → `save-graph` PHẢI **strip toạ độ** mỗi node trước `Write-Json` (defense engine-side); server **cũng strip** (defense-in-depth). Toạ độ node mới → `.layout.json` qua `/api/layout` (E sẵn). Done-gate kiểm `git diff workflow.json` sau edit = CHỈ semantic, ZERO `x/y`.
  - **⚠️ KHÔNG để fixture thật bẩn:** edit demo trên `hq/workflow.json` sẽ **sửa file committed**. Để tránh: dùng **fixture scratch** `examples/edit-demo/` (graph-format nhỏ, committed như `approval-demo`/`mem-demo`) cho mọi demo edit; HOẶC revert project thật sau demo. Done-gate G.6 phải kiểm `git diff hq/workflow.json` = RỖNG (không để hq bẩn).
  - **`server.mjs` dependency-free**: giữ Node `http`/`fs`/`child_process` thuần (như E/F). Bind `127.0.0.1`. Validate `project` (`SAFE_PROJECT` regex) + chặn traversal (`resolveProjectDir`) như F.
  - **Validate đã đủ mạnh cho graph:** `validate.ps1` v2 sẵn kiểm schema/agent/router-when/reachability/max_steps + luật `approval` (miễn agent/input/output, ≥1 cạnh ra, ≥2 cạnh → mỗi cạnh `when`). `save-graph` chỉ cần gọi `Test-Workflow` — **không thêm luật validate mới** (gate sẵn lo).
- **Ràng buộc bất biến (6 quy ước `company/CLAUDE.md`)** — Phase G áp như sau:
  - **#1 engine code cố định**: G **chỉ THÊM** `save-graph` (additive, hàm thuần reuse `Write-Json`+`Test-Workflow`) — giống E thêm `-Json`. KHÔNG sửa walk/normalize/mock/validate-logic. App KHÔNG chứa logic workflow.
  - **#2 `workflow.json` coordinate-free**: G ghi **semantic-only** (`nodes`/`edges`/`entry`/`max_steps`); strip `x/y` 2 lớp (engine+server). Toạ độ đi `.layout.json`. `git diff workflow.json` sau drag = ZERO toạ độ.
  - **#3 mock bất biến**: `save-graph` additive — đường mock/validate/run engine KHÔNG đổi. Regression chuẩn xanh ở session chạm engine (G.1).
  - **#4 một surface lệnh**: server shell `run.ps1 save-graph` (mở rộng surface sẵn) — KHÔNG entry point engine mới. `POST /api/workflow` là tầng app (chấp nhận theo D-1/D-2).
  - **#5 dot-source-safe**: module `save-graph` guard `InvocationName`/`Line`.
  - **#6 chỉ trong `company/`**: app + server tại `company/app/`; candidate temp trong OS temp / `<project>/.runs/` (không lan ngoài).
- **Out of scope (defer — không thuộc G):**
  - **Chạy `autobuild`/`autofix` real từ app** (E2E real, sandbox/promote/diff-scope) — defer từ F-D3, vẫn defer sau G (chỉ thêm nếu cần, ngoài đợt này).
  - **Sửa pipeline-v1 trong app** (CLI `edit` đã làm tốt; G tập trung graph-format — đường CLI chưa phủ). App có thể từ chối/ẩn edit cho project pipeline-v1 (chỉ-xem), giống `edit.ps1` từ chối graph.
  - **Undo/redo nhiều bước** (history stack) — G dùng "discard = reload-from-server" (bỏ thay đổi chưa-save bằng re-fetch). Multi-step undo = nice-to-have ngoài scope.

---

## Pipeline 3 sub-phase / 6 session

```
[G-I — Write-path backend (engine command + server endpoint)]
[G.1] Engine `save-graph` (additive): write→validate→commit-or-restore ─► run.ps1 save-graph <proj> <file>: ghi atomic, reject-on-invalid, strip toạ độ, in {ok,errors[]}
                                                                          │
[G.2] Server POST /api/workflow (shell save-graph, reject UX) ──────────► curl POST graph hợp lệ→200 ok; graph hỏng→422 errors[]; file bất biến; round-trip qua GET /api/graph
                                                                          │
[G-II — In-app edit interactions (frontend)]
[G.3] Edit-mode: nối/xoá cạnh + sửa nhãn `when` + nút Save ─────────────► trên graph có sẵn: thêm/bớt cạnh, sửa when, Save→commit/reject hiện errors
                                                                          │
[G.4] Thêm/xoá node + form field node + entry/max_steps ────────────────► add node (chọn type+field) / del node (cascade cạnh) / sửa entry·max_steps → Save validate-gated
                                                                          │
[G-III — Coordinate-free + polish + gate]
[G.5] Coordinate-free guarantee + layout cho node mới ──────────────────► edit+drag→ git diff workflow.json CHỈ semantic (ZERO x/y); node mới vị trí vào .layout.json
                                                                          │
[G.6] Polish + docs + handoff + USER GATE ──────────────────────────────► done-gate đủ (add node+nối cạnh→Save→validate pass+coord-free; invalid→reject) + docs + đóng đợt hq-improve
```

---

## Phase G — App III: in-app edit

**Mục tiêu**: từ app sửa cấu trúc graph (full structural) → Save → engine ghi `workflow.json` validate-gated (commit nếu pass, reject+errors nếu fail) → file LUÔN hợp lệ + coordinate-free. Mỗi session = 1 lớp; STOP gate đo được; `git diff engine/` chỉ chứa `save-graph` additive (G.1) và RỖNG mọi session app-only.

> **Bất biến cốt lõi Phase G**: engine chỉ THÊM `save-graph` (additive — walk/normalize/mock/validate-logic y nguyên); `workflow.json` semantic-only + coordinate-free (strip `x/y` 2 lớp; `git diff workflow.json` sau drag = ZERO toạ độ); `workflow.json` LUÔN hợp lệ trên đĩa (reject-on-invalid); `server.mjs` dependency-free + bind `127.0.0.1`; CLI `edit.ps1` KHÔNG đụng (G là đường graph riêng).
> **Regression chuẩn (session chạm engine = G.1; + bất kỳ session lỡ chạm)**: `./run.ps1 validate hello`=exit 0 · `./run.ps1 run hello "x" -Mock`=done · `./run.ps1 selftest`=PASS. Session app-only (G.2–G.6) → `git diff engine/` PHẢI rỗng.
> **pwsh**: `/snap/bin/pwsh` + `dangerouslyDisableSandbox: true`; `save-graph` in `{ok,errors[]}` ra stdout → **server parse stdout, KHÔNG tin child exit code** (core-dump teardown).
> **Node toolchain**: chạy trong `company/app/`. Dev: `npm run dev` (Vite proxy `/api`→server). Serve: `npm run build && node server.mjs` (port 5179). Dọn `.runs/`/temp + **revert project thật** sau verify (hoặc demo trên `examples/edit-demo/`).

### Sub-phase G-I — Write-path backend (engine command + server endpoint)

#### Session G.1 — Engine `save-graph` (additive): write → validate → commit-or-restore
- **Scope** (`engine/` — additive module + `run.ps1` dispatch; reuse `lib/json.ps1` + `validate.ps1`):
  - Module mới (vd `engine/save.ps1`) hàm thuần `Save-Graph $ProjectDir $Candidate` (Candidate = object đọc từ file): **(1)** backup `ReadAllText` `workflow.json` hiện tại (nếu có); **(2)** **strip toạ độ** mỗi node (xoá `x`/`y`/`position` nếu lẫn) → giữ semantic (`nodes[{id,agent,type,prompt?,output_key?,input?}]`, `edges[{from,to,when?}]`, `entry`, `max_steps`); **(3)** `Write-Json` candidate → `workflow.json`; **(4)** `$errs = Test-Workflow $ProjectDir`; **(5)** `errs.Count==0` → giữ + trả `{ok=$true; errors=@()}`; else → **restore backup** (`WriteAllText` UTF8-no-BOM; nếu trước không có file thì xoá) + trả `{ok=$false; errors=$errs}`.
  - Hàm in kết quả máy-đọc-được: `Write-SaveResult` in 1 dòng JSON `{"ok":bool,"errors":[...]}` ra stdout (server parse). Exit = số lỗi (0 = commit).
  - `run.ps1 save-graph <proj> <candidate-file>`: resolve project (thứ-tự B: `projects/`>`examples/`>`hq/`) + **guard path** candidate-file (`Test-PathInside`, reuse C) + đọc candidate qua `Read-Json` → `Save-Graph` → `Write-SaveResult`. Dot-source-safe (#5).
  - **Fixture scratch** `examples/edit-demo/` (graph-format nhỏ: 2-3 node worker + 1 router, committed như `approval-demo`) để demo/test save-graph KHÔNG bẩn `hq`.
- **STOP gate** (đo được):
  - Candidate HỢP LỆ (vd nhân bản `edit-demo` thêm 1 node+cạnh đúng) → `run.ps1 save-graph edit-demo <file>` → stdout `{"ok":true,...}` + `workflow.json` cập nhật + `run.ps1 validate edit-demo`=exit 0.
  - Candidate HỎNG (vd cạnh trỏ node không tồn tại / router thiếu `when`) → `save-graph` → stdout `{"ok":false,"errors":[...]}` (errors non-empty) + **`workflow.json` SHA256 BẤT BIẾN** so trước khi gọi (restore đúng).
  - Candidate có `x/y` trong node → `workflow.json` ghi ra **KHÔNG có `x/y`** (strip verified, `grep -c '"x"' workflow.json`=0).
  - **Regression chuẩn xanh** (G.1 chạm engine): validate hello=0 · run hello -Mock=done · selftest PASS. `run.ps1 graph hq -Json` + ASCII vẫn y cũ (save-graph không đụng path đọc).
  - `git diff engine/` chỉ thêm `save.ps1` + dispatch `save-graph` trong `run.ps1` (additive).
- **Output artifact**: `engine/save.ps1` (`Save-Graph` write-validate-atomic + reject-restore + strip-toạ-độ + `Write-SaveResult`) + `run.ps1 save-graph` + fixture `examples/edit-demo/`.

#### Session G.2 — Server `POST /api/workflow` (shell save-graph, reject UX)
- **Scope** (`app/server.mjs` — additive endpoint, dependency-free):
  - `POST /api/workflow?project=<p>` body `{nodes, edges, entry, max_steps}` (semantic-only): **strip toạ độ** server-side (defense) → ghi candidate ra temp file (OS temp / `<project>/.runs/.edit-candidate.json`) → shell `pwsh -NoProfile -File run.ps1 save-graph <p> <tmpfile>` (cwd `COMPANY`) → **parse stdout** `{ok,errors[]}` (KHÔNG tin exit code) → `ok:true` ⇒ 200 `{ok:true}`; `ok:false` ⇒ **422** `{ok:false, errors}`. Reuse `SAFE_PROJECT` + `resolveProjectDir` (project lạ/traversal → 400/404, KHÔNG ghi). Dọn temp file.
  - Round-trip đọc lại qua `GET /api/graph?project=` (E sẵn — chuẩn hoá).
- **STOP gate** (đo được):
  - `curl -X POST '/api/workflow?project=edit-demo' -d '<graph hợp lệ>'` → 200 `{ok:true}`; `curl '/api/graph?project=edit-demo'` phản ánh thay đổi.
  - `curl -X POST '/api/workflow?project=edit-demo' -d '<graph hỏng>'` → 422 + `errors[]`; `workflow.json` BẤT BIẾN (SHA256 so trước).
  - Project lạ (`?project=nope`) → 400/404, KHÔNG spawn/ghi.
  - **`git diff engine/` = RỖNG** (G.2 app-only); revert `edit-demo` về trạng thái committed sau test.
- **Output artifact**: `POST /api/workflow` (validate-gated, reject-on-invalid, coord-strip) trên `server.mjs`.

### Sub-phase G-II — In-app edit interactions (frontend)

#### Session G.3 — Edit-mode: nối/xoá cạnh + sửa nhãn `when` + nút Save
- **Scope** (`app/src/` — React Flow edit, không phá view/run mode E/F):
  - **Edit-mode toggle** (tách khỏi view/run): bật → React Flow cho phép `onConnect` (kéo nối cạnh mới `from→to`), `onEdgesDelete` (xoá cạnh), sửa **nhãn `when`** của cạnh (inline/panel). Pending-state cục bộ (chưa ghi đĩa).
  - **Nút "Save graph"**: gom semantic graph hiện tại (nodes/edges/entry/max_steps — KHÔNG toạ độ) → `POST /api/workflow?project=`. `ok:true` → toast + re-fetch `GET /api/graph` (xác nhận đồng bộ); `422` → **panel errors[]** hiện cho user (file chưa đổi).
  - **Discard** = reload-from-server (re-fetch graph, bỏ pending). Cảnh báo "unsaved changes" khi đổi project/rời.
- **STOP gate**:
  - `edit-demo` (hoặc copy `loopy`): nối 1 cạnh mới giữa 2 node → hiện; xoá 1 cạnh → mất; sửa 1 nhãn `when` → cập nhật; **Save → 200** → reload thấy thay đổi giữ.
  - Save edit phá luật router (router 2 cạnh thiếu `when`) → **422** → errors hiện, graph KHÔNG persist (file bất biến).
  - **`git diff engine/` = RỖNG**.
- **Output artifact**: edit-mode cạnh (connect/delete + when-label) + nút Save + panel reject errors + discard-reload.

#### Session G.4 — Thêm/xoá node + form field node + entry/max_steps
- **Scope** (`app/src/` — node CRUD + graph-level):
  - **Add node**: chọn `type` (worker / router / approval / terminal) → form field theo type: worker = agent (chọn từ `agents/`? hoặc nhập) + output_key + prompt/input; router = (cạnh + when ở G.3); approval = miễn agent/output (prompt tuỳ); terminal = node không cạnh-ra. Node mới đặt vị trí default/dagre (semantic-only; toạ độ → G.5).
  - **Delete node**: xoá node + **cascade** xoá mọi cạnh dính (in/out).
  - **Form sửa field node** đang có (agent/type/prompt/output_key).
  - **Graph-level**: sửa `entry` (chọn node) + `max_steps` (số).
  - Save → cùng `POST /api/workflow` (G.3) — validate gate bắt mọi field thiếu.
- **STOP gate**:
  - `edit-demo`: add 1 worker node (agent+output_key) → nối cạnh → **Save → validate pass** → persist.
  - Add node THIẾU field bắt buộc (worker không agent/output_key) → **Save → 422** errors (validate bắt) → KHÔNG persist.
  - Delete 1 node → cạnh dính mất theo → Save hợp lệ.
  - Sửa `max_steps`/`entry` → Save → `GET /api/graph` phản ánh.
  - **`git diff engine/` = RỖNG**.
- **Output artifact**: add/delete node (cascade) + form field node + sửa entry/max_steps (validate-gated).

### Sub-phase G-III — Coordinate-free + polish + gate

#### Session G.5 — Coordinate-free guarantee + layout cho node mới
- **Scope** (`app/src/` + verify 2-lớp strip):
  - Đảm bảo semantic-save KHÔNG mang `x/y` (verify cả server-strip G.2 + engine-strip G.1). Node MỚI: vị trí (dagre auto hoặc drop-position) → persist vào **`.layout.json`** qua `POST /api/layout` (E sẵn), TUYỆT ĐỐI không vào `workflow.json`.
  - Sau structural edit + drag: `workflow.json` chỉ đổi semantic; `.layout.json` giữ toạ độ (gồm node mới).
- **STOP gate**:
  - Add node + kéo nó + Save graph + (drag→save layout) → **`git diff <proj>/workflow.json` CHỈ chứa semantic** (nodes/edges/entry/max_steps), **ZERO `x/y`** (`grep '"x"'`=0); `.layout.json` có vị trí node mới.
  - Reload → node mới ở vị trí đã lưu; semantic graph nguyên.
  - Round-trip: edit → Save → `GET /api/graph` → re-render khớp (không mất/đổi node-edge).
  - **`git diff engine/` = RỖNG**.
- **Output artifact**: coordinate-free edit đảm bảo (2-lớp strip) + node-mới layout vào `.layout.json` (workflow.json semantic-only verified).

#### Session G.6 — Polish + docs + handoff + USER GATE
- **Scope** (polish nhẹ + docs):
  - **Polish**: edit-mode rõ (badge "EDIT"); chỉ-báo unsaved-changes; panel errors khi reject; confirm trước delete node; (project pipeline-v1 → app **chỉ-xem**, ẩn edit graph — đối xứng `edit.ps1` từ chối graph); nút "Discard changes" (reload-from-server).
  - **README**: mục mới "App — In-app edit (Phase G)": bật edit-mode, thêm/xoá node + form field, nối/xoá cạnh + when-label, sửa entry/max_steps, Save (validate-gated, reject hiện errors), coordinate-free (`.layout.json`); giới hạn (chỉ graph-format; pipeline-v1 dùng CLI `edit`; autobuild/autofix-from-app vẫn defer). Tài liệu `run.ps1 save-graph`.
  - **CLAUDE.md** bảng "Bản đồ file": cập nhật hàng `company/app/` (thêm in-app edit) + `engine/run.ps1` (`save-graph`) + hàng mới `engine/save.ps1` + `examples/edit-demo/` + `plan/hq-improve/phase-g/`.
  - **ROADMAP**: bảng tiến độ **G ✅** + **§"Bàn giao G→(ngoài đợt)"** (autobuild/autofix-from-app defer; in-app edit đóng) + ghi **đợt hq-improve ĐÓNG**.
- **STOP gate** (Done-gate Phase G — ROADMAP §Phase G):
  - Trong app: **thêm node + nối cạnh** → **Save** → `validate` pass → `workflow.json` hợp lệ + **coordinate-free** (ZERO `x/y`).
  - Thử **1 edit invalid** → **rejected với errors[]**, file BẤT BIẾN (chứng minh reject-on-invalid).
  - **`git diff hq/workflow.json` = RỖNG** (demo trên `examples/edit-demo/` hoặc revert project thật — KHÔNG để fixture committed bẩn).
  - Regression chuẩn xanh (validate hello=0 · run hello -Mock=done · selftest PASS); `git diff engine/` chỉ `save-graph` additive (G.1); mock-path bất biến.
  - Server bind `127.0.0.1`; `server.mjs` dependency-free (chỉ Node core).
  - README + CLAUDE.md + ROADMAP cập nhật (G ✅ + đóng đợt hq-improve).
  - **User duyệt** đóng phase (ghi CHECKPOINT).
- **Output artifact**: polish + docs + CLAUDE.md/ROADMAP → Phase G đóng → đợt hq-improve đóng.

**Phase G gate** (sau G.6): app local bật edit-mode → full structural edit graph (add/del node + form field + nối/xoá cạnh + when-label + entry/max_steps) → Save → engine `save-graph` validate-gated (commit nếu pass; reject+errors nếu fail) → `workflow.json` LUÔN hợp lệ + coordinate-free (ZERO toạ độ, `.layout.json` riêng); engine chỉ thêm `save-graph` additive (mock/validate/ASCII cũ y nguyên, regression xanh); CLI `edit` bất biến; server dependency-free + localhost; ROADMAP §Bàn-giao + đóng đợt ghi đủ; user duyệt. → cập nhật ROADMAP (G ✅, hq-improve ĐÓNG).

---

## Bàn giao sang (ngoài đợt) (ghi vào ROADMAP cuối G.6)

> G *đóng in-app edit* + đóng đợt **hq-improve**. Phần dưới = nice-to-have **ngoài đợt**, chỉ làm nếu user cần sau.

| Hạng mục | G làm gì | Ngoài đợt (nếu cần) |
| --- | --- | --- |
| **In-app edit graph** | ✅ Full structural (add/del node + field + cạnh + when + entry/max_steps) → `save-graph` validate-gated, coordinate-free | (đóng ở G) |
| **autobuild/autofix từ app** | Vẫn defer (F-D3 + G out-of-scope) | Nút chạy `autobuild`/`autofix` real từ app (sandbox/promote/diff-scope, real-only) — chỉ nếu cần |
| **Pipeline-v1 edit trong app** | App chỉ-xem pipeline-v1 (CLI `edit` phủ) | Hợp nhất editor (graph + pipeline) trong app — nếu muốn 1 chỗ |
| **Undo/redo nhiều bước** | Discard = reload-from-server (bỏ pending) | History stack multi-step undo/redo |

**Server endpoint sau G** (đầy đủ): `GET /api/health` · `/api/projects` · `/api/graph?project=` · `GET/POST /api/layout?project=` (E) + `POST /api/run` · `GET /api/events` (SSE) · `POST /api/decision` (F) + **`POST /api/workflow?project=`** (G — ghi `workflow.json` đã validate). **Đợt hq-improve ĐÓNG.**

---

## Outcome cuối

- App web local (`company/app/`, React+Vite+Tailwind+React Flow+dagre) **bật edit-mode** → sửa cấu trúc graph **full structural**: thêm/xoá node (form field agent/type/prompt/output_key) + nối/xoá cạnh + sửa nhãn `when` + sửa `entry`/`max_steps`.
- **Save** → `POST /api/workflow` → server shell `run.ps1 save-graph <proj> <candidate>` → engine **write-validate-commit-or-restore**: PASS → commit `workflow.json`; FAIL → **giữ file cũ + trả `errors[]`** → app hiện. `workflow.json` LUÔN hợp lệ trên đĩa.
- **Coordinate-free** (bất biến #2): `workflow.json` semantic-only (strip `x/y` 2 lớp engine+server); toạ độ node (gồm node mới) → `.layout.json` qua `/api/layout`; `git diff workflow.json` sau drag = ZERO toạ độ.
- **Lấp gap**: CLI `edit` (pipeline-v1, từ chối graph) + in-app edit (graph-format) = phủ trọn 2 dạng workflow. CLI `edit.ps1` BẤT BIẾN.
- **Engine bất biến trừ `save-graph` additive** (mock/validate/run/ASCII cũ y nguyên; regression xanh); `server.mjs` dependency-free (Node core); bind localhost.
- `ROADMAP.md`: G ✅ + §Bàn-giao + **đợt hq-improve ĐÓNG**; user duyệt.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-06-01 | Initial | Soạn long-plan Phase G từ `ROADMAP.md` §Phase G + §Bàn-giao-E→F/G + §Bàn-giao-F→G (in-app edit). Chốt G-D1..G-D3 (user 2026-06-01): **Full structural graph edit** · **engine command additive `save-graph`** (write→validate→commit-or-restore, pattern backup-restore từ `edit.ps1`) · **reject-on-invalid** (workflow.json luôn hợp lệ). 3 sub-phase / 6 session. Phát hiện gap: CLI `edit.ps1` chỉ pipeline-v1, từ chối graph-format (A-18) → in-app edit lấp đúng. Fixture scratch `examples/edit-demo/` tránh bẩn `hq` |
