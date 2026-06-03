# Workflow Engine

> **Engine** điều phối agent chạy full-local trên PowerShell — đọc `workflow.json` dạng **đồ thị điều khiển** (`nodes` + `edges` + `entry`), đi theo đồ thị bằng con trỏ đơn (single-cursor walk), gọi agent qua `claude -p`, ghép context bằng bridge, log + state. Hỗ trợ rẽ nhánh OR (node ≥2 cạnh ra tự rẽ, agent quyết nhãn), merge, loop (cycle có chặn `max_steps`).

`pipeline` tuyến tính (v1) vẫn chạy nguyên: loader tự chuyển thành graph nội bộ → **một executor duy nhất** cho cả hai dạng. Không lưu toạ độ — layout tính lúc render.

---

## Yêu cầu

- PowerShell 7 (`pwsh`).
- `claude` CLI trong PATH — **chỉ cần cho run thật** (không `-Mock`).
- Không cần build, không cần cài thêm gì cho mock mode.

---

## Quickstart — 2 luồng

Mọi lệnh chạy từ `company/engine/`. Có **2 luồng** chính:

```powershell
cd company/engine
```

### Luồng 1 — chạy & soi một project (demo/fixture có sẵn)

```powershell
./run.ps1 graph    hello              # 1. Xem đồ thị (node + cạnh) + xuất Mermaid     (cũ: viz)
./run.ps1 validate hello              # 2. Kiểm tra hợp lệ (exit = số lỗi)
./run.ps1 run      hello "ping" -Mock # 3. Chạy offline (mock — không gọi model, không đốt token)
./run.ps1 status   hello              # 4. Xem tiến độ run vừa rồi
./run.ps1 logs     hello              #    + prompt/output từng lượt thăm
```

Sau bước 3, run `hello` (2 node `a → b`) phải báo cả 2 lượt `done`, path `a → b`, in đường dẫn run dir. Chạy thật (gọi model qua `claude` CLI) — bỏ `-Mock`: `./run.ps1 run hello "câu hỏi thật" -Model claude-opus-4-7`.

### Luồng 2 — dựng workflow mới (author)

2 cách dựng `workflow.json`, **không** lưu toạ độ (xem [§workflow.json](#workflowjson--đồ-thị-điều-khiển-không-toạ-độ)):

```powershell
./run.ps1 edit my-app    # (a) TUI: thêm/xoá/đổi node, chọn agent, set input deps (pipeline-v1)
# (b) App Workflow Viewer — xem § "App — Workflow viewer" bên dưới (in-app edit, graph-format)
```

---

## Surface lệnh

```
./run.ps1 <command> <project> [args]
```

`<project>` nhận **tên gọn** (`hello`) hoặc **path** (`examples/hello`) — engine resolve theo thứ tự: path nguyên trạng → `projects/<name>` (app thật) → `examples/<name>` (demo/fixture). ⚠ **Footgun (A-05)**: nếu có `projects/<name>` trùng tên `examples/<name>`, tên gọn **ưu tiên `projects/`** — gọi dạng path để chỉ đích chính xác.

| Nhóm | Command | Cú pháp | Việc |
|---|---|---|---|
| **PROJECT** | `run` | `run <proj> "<request>" [-Mock] [-Model m] [-AutoApprove]` | Chạy pipeline end-to-end |
| | `resume` | `resume <proj> [-Mock] [-Model m] [-Decision label]` | Tiếp tục run dở / `failed` mới nhất; `-Decision` bơm quyết định duyệt (`approve`/`reject`/nhãn router) |
| | `graph` | `graph <proj> [out.mmd]` | Liệt kê node + cạnh trong terminal + xuất Mermaid `.mmd` |
| | `validate` | `validate <proj>` | Kiểm tra graph hợp lệ; **exit = số lỗi** (data-cycle = warning) |
| | `status` | `status <proj>` | Tiến độ run gần nhất: `path` + lượt thăm (node + iter + status) |
| | `logs` | `logs <proj> [node]` | Prompt + output từng lượt thăm (lọc 1 node nếu truyền) |
| | `check` | `check <proj>` | **Tester tầng cấu trúc**: `validate` exit 0 → `run -Mock` done → mọi `output_key` non-empty (exit = số tiêu chí fail) |
| | `trial` | `trial <proj> [-Model m]` | **Tester tầng trial**: tầng cấu trúc (mock) → copy vào sandbox cô lập → chạy **THẬT** → assert `trial[]` trên artifact |
| **AUTHOR** | `edit` | `edit <proj>` | TUI thêm/xoá/đổi thứ tự node, chọn agent, set input deps (pipeline-v1) |
| | `save-graph` | `save-graph <proj> <candidate-file>` | Ghi + validate atomic (graph-format); PASS → commit; FAIL → restore + `{"ok":false,"errors":[]}` |
| **Advanced** | `selftest` | `selftest [all]` | Chạy bộ test engine (7 stamp + mem-demo + approval-demo + branchy/2-part); **exit = số mục fail** |

Không arg / `help` / `-h` / `--help` → in help đầy đủ.

**Tương thích**: tên cũ vẫn chạy như **alias im lặng** — `viz`→`graph`, `test`→`selftest`.

- **Claude** dùng nhiều: `run`/`resume` (mock khi test), `validate`/`check`/`trial` (gate trước khi báo done), `status`+`logs` (kiểm tra). Non-interactive, exit code rõ ràng.
- **User** dùng nhiều: `graph` (đọc đồ thị), `edit` (TUI tương tác — không hợp với Claude vì nhập tay).
- **Đốt token**: `run`/`resume` không `-Mock`, `trial` (tầng 2 luôn thật). Còn lại free.
- **Xem output**: lúc chạy, `run` chỉ in `node 'x' → done (N chars)` — **không** in nội dung lên màn hình. Dùng `logs <proj> [node]` SAU đó để đọc prompt/output đầy đủ; hoặc đọc `<run>/events.ndjson` (mỗi dòng JSON chứa nội dung output đầy đủ — xem [§Human-in-the-loop](#human-in-the-loop-hitl)).
- **Gate duyệt (`awaiting`)**: khi gặp node `approval` hoặc vi phạm diff-scope, engine **dừng** (exit 3) + in hướng dẫn resume. Thêm `-AutoApprove` để tự duyệt (dùng cho test/CI offline, không tương tác).

---

## Lúc nào vào `sandbox/`, lúc nào vào `projects/`?

Có **2 nơi** artifact đi tới, tuỳ lệnh:

| Nơi | Là gì | Lệnh nào ghi vào đây | Project gốc bị đụng? |
|---|---|---|---|
| `<project>/.runs/<ts>/` | Lịch sử run **của chính project đó** | `run`, `resume` | ✅ tại chỗ (ghi vào `.runs/` của nó) |
| `sandbox/<runid>/` | Bản **COPY tạm cô lập** để chạy thật rồi vứt | `trial` (tầng 2) | ❌ KHÔNG — gốc giữ sạch |

- **`run` / `resume` / `graph` / `validate` / `check` / `status` / `logs` / `edit`** — thao tác **tại chỗ** trên project. Artifact (nếu có) vào `<project>/.runs/`. Không liên quan sandbox.
- **`trial <proj>`** — copy project vào `sandbox/<runid>/`, chạy **THẬT** ở đó, assert `trial[]`, rồi **teardown** (xoá sandbox). Project gốc không bị bẩn bởi run thật.

### Ví dụ — `trial` test một project có sẵn

`trial` KHÔNG sinh chi nhánh mới; nó test một project đã có, chạy thật trong bản copy rồi vứt:

```powershell
./run.ps1 trial loopy
# 1. tầng cấu trúc (mock, free): validate + run -Mock + output_key  ✓
# 2. copy examples/loopy → sandbox/<runid>/ → chạy THẬT → assert trial[]  ✓
# 3. teardown sandbox. examples/loopy gốc KHÔNG có .runs mới (chạy ở bản copy).
```

---

## workflow.json — đồ thị điều khiển, không toạ độ

Mỗi project là một thư mục chứa `workflow.json` + `agents/*.md`. Dạng **graph** khai báo `nodes` + `edges` + `entry` + `max_steps`:

```json
{
  "name": "branchy",
  "entry": "tier",
  "max_steps": 30,
  "nodes": [
    { "id": "tier",   "agent": "agents/tier-router.md", "input": "{{user_request}}", "output_key": "tier" },
    { "id": "d10",    "agent": "agents/disc.md",   "input": "{{user_request}}\n10%", "output_key": "discount" },
    { "id": "output", "agent": "agents/output.md",  "input": "{{user_request}}\n{{discount}}", "output_key": "result" }
  ],
  "edges": [
    { "from": "tier", "to": "d10",    "when": "gt5000" },
    { "from": "tier", "to": "output", "when": "else" },
    { "from": "d10",  "to": "output" }
  ],
  "trial": [
    { "observe": "result", "expect": { "kind": "contains", "value": "Ship" } }
  ]
}
```

| Field | Cấp | Bắt buộc | Ý nghĩa |
|---|---|---|---|
| `name` | root | ✅ | Tên project, khớp tên thư mục |
| `entry` | root | ✅ (graph) | `id` node bắt đầu walk |
| `max_steps` | root | ✅ (graph) | **Cầu dao**: tổng số node được phép thực thi trong 1 run; vượt → fail an toàn (chống loop vô hạn) |
| `nodes` | root | ✅ (graph) | Danh sách node |
| `edges` | root | ✅ (graph) | Cạnh có hướng nối node |
| `trial` | root | ⬜ | Việc thật cho `trial`: mảng `{ observe: output_key, expect: { kind: non-empty\|contains\|matches, value } }` |
| `id` | node | ✅ | ID node, **unique** — dùng đặt tên file debug |
| `agent` | node | ✅ | Path agent `.md` **tương đối** so với project dir |
| `type` | node | ⬜ | `"approval"` nếu là gate người-duyệt (không gọi model); vắng / `"work"` = node worker thường. **`"router"` đã bỏ (J2)** — node có ≥2 cạnh ra tự là điểm rẽ |
| `input` | node | ✅ | Template `{{key}}` — `{{user_request}}` (input gốc), `{{output_key}}` node đã chạy, hoặc `{{mem_*}}` (trí nhớ) |
| `output_key` | node | ✅ | Key lưu output node này (ghi vào context, **latest-wins** khi loop) |
| `from`/`to` | edge | ✅ | `id` node nguồn/đích |
| `when` | edge | ✅ nếu node có ≥2 cạnh ra | Nhãn để engine chọn cạnh; node ≥2 cạnh ra (điểm rẽ) cần `when` trên mỗi cạnh; node ≤1 cạnh ra không cần |

- Cạnh là **cạnh điều khiển khai báo tường minh** (không suy từ `{{key}}`). Cho phép **cycle** (loop) qua cạnh quay lại node trước.
- `{{user_request}}` là input gốc lúc `run`. Loop-feedback resolve rỗng ở vòng đầu — hợp lệ.

### Điểm rẽ — node ≥2 cạnh ra, agent quyết

Engine **không có ngôn ngữ biểu thức**. Logic chọn cạnh nằm trong engine, agent chỉ trả nhãn:

- **Node có ≥2 cạnh ra** = điểm rẽ tự động (không cần khai `type`): engine **chuẩn hoá output** → nhãn = dòng không-trắng **cuối**, trim, lowercase.
- Engine khớp nhãn với `when` của các cạnh ra. Khớp 1 → đi cạnh đó. Không khớp `when` nào → node **fail** (liệt kê `when` hợp lệ) → sửa rồi `resume`.
- **Node ≤1 cạnh ra** = đường thẳng: không cần in nhãn, engine đi thẳng cạnh duy nhất (hoặc terminal nếu 0 cạnh).

> **`"router"` đã bỏ (J2).** Không khai `type:"router"` — `validate` sẽ báo lỗi. Chỉ cần thêm ≥2 cạnh ra kèm nhãn `when` để biến node thành điểm rẽ.

> **`-Mock` trần KHÔNG lái điểm rẽ (A-01).** Mock chỉ echo output xác định, không sinh nhãn. Project **có điểm rẽ** chạy `-Mock` mà không khai `ENGINE_MOCK_ROUTER` → không khớp `when` nào → fail. Phải set `$env:ENGINE_MOCK_ROUTER = 'tester:pass'` để steer. Project tuyến tính (như `hello`) không có điểm rẽ → `-Mock` trần chạy thẳng.

Ví dụ chạy thử demo điểm rẽ 4 nhánh (`examples/branchy`):

```powershell
./run.ps1 graph branchy                          # xem 4 nhánh + merge
# Mock-steer router đi nhánh cụ thể (không cần model):
$env:ENGINE_MOCK_ROUTER = "tier:gt5000"
./run.ps1 run branchy "đơn 8000" -Mock           # router trả nhãn "gt5000" → đi cạnh d10
./run.ps1 status branchy                          # path đi qua: tier → d10 → output
```

#### Router choices auto-inject (Phase J / CD-2)

Engine **tự bơm tập nhãn hợp lệ** vào prompt router lúc chạy real-mode — agent `.md` **không cần hardcode nhãn**. Nguồn sự thật duy nhất là `edges`/`when` từ graph:

```
---
Chọn đúng MỘT nhãn sau (in nhãn ở dòng cuối):
{ gt10000 | gt5000 | gt1000 | else }
```

Suffix này ghép **engine-side** (hằng cố định, không cấu hình per-node), chỉ khi chạy real-mode. Khi `-Mock`: bỏ qua (mock trả nhãn qua `ENGINE_MOCK_ROUTER` — bất biến). Nhãn sai (không trong tập `when`): engine ghi 1 entry deterministic vào `company/issues/route-issues.ndjson` (gitignored) rồi `throw` ngay — không retry.

#### Giao thức 2-phần: payload + nhãn route

Router có thể in **2 phần**: payload tự do (phần trước) + nhãn route (dòng cuối). Engine tách tự động:

- `{{<output_key>_payload}}` → phần payload (string; `""` nếu router chỉ in nhãn đơn)
- Tương thích ngược: router chỉ in nhãn đơn → `_payload = ""` → không break workflow hiện có

Ví dụ output router 2-phần:
```
Order value: 8500 → tier gt5000
gt5000
```

Node successor dùng `{{tier_payload}}` trong `input` để nhận dòng lý do. `validate` cảnh báo (WARN, không error) nếu dùng `{{x_payload}}` mà không có node rẽ nhánh (outdeg≥2) nào với `output_key=x`.

---

### Loop — cycle có chặn

- Cạnh `to` trỏ về node đã đi qua = **vòng lặp** (vd `verdict → build` khi `when:"fail"`).
- **Điều kiện thoát = điểm rẽ** (vd `verdict` có ≥2 cạnh: `pass` → `ship`, `fail` → `build`).
- **`max_steps` bắt buộc**: chạm trần → state `failed`, exit ≠ 0. Là cầu dao an toàn, **không** thay điểm rẽ làm exit chính.

Ví dụ demo loop build→test→verdict (`examples/loopy`): `verdict` có ≥2 cạnh ra, `fail` → quay về `build` (loop), `pass` → `ship` (thoát).

```powershell
# Steer router: fail 2 lần rồi pass — loop 2 vòng rồi thoát:
$env:ENGINE_MOCK_ROUTER = "verdict:fail,fail,pass"
./run.ps1 run loopy "làm tính năng X" -Mock
./run.ps1 status loopy     # path: build→test→verdict→build→test→verdict→build→test→verdict→ship
```

### Agent frontmatter → CLI (run thật)

Agent `.md` có thể khai frontmatter; executor đọc và truyền xuống `claude` CLI:

```yaml
---
allowedTools: [Write, Edit]      # → --allowedTools  (chỉ Builder HQ được ghi file)
permission_mode: acceptEdits     # → --permission-mode
model: claude-opus-4-7           # → --model (tier theo từng agent)
---
```

### Migrate flat `pipeline` → graph

`pipeline` (v1) vẫn hợp lệ — loader chuẩn hoá: mỗi `step` → 1 node, cạnh tuyến tính `step[i] → step[i+1]`, `entry` = step đầu, không loop. Demo `hello` là pipeline cũ — chứng minh tương thích ngược.

---

## HQ — native team-of-agents

HQ hiện là **native team-of-agents Claude Code** (`.claude/agents/hq-*.md` + `.claude/hq-master.md`), không còn là `workflow.json`. Builder build chi nhánh trực tiếp bằng Write/Edit — không đi qua engine. Engine + app là tool workflow **chi nhánh** đứng riêng.

Xem `plan/hq-v2/phase-h/design.md` để biết kiến trúc HQ native team.

### catalog/ — thư viện vai chi nhánh

17 vai chi nhánh hand-authored (`catalog/*.md`), mỗi vai = system prompt + ranh giới theo template 5 mục (Một việc / Input / Trả ra / Không làm / Handoff): đầu-não (researcher, planner), Product (pm, ba), Design (ux, ui), Engineering (tech-lead, db-architect, api-developer, auth-engineer, frontend-developer, devops, mobile-ios/android/flutter), QA (qa-functional, qa-regression). Xem [`catalog/README.md`](catalog/README.md) — ma trận ranh giới chống đè.

### patterns/ — fragment robustness (stamp lúc build)

6 cụm node+edge tái dùng (`patterns/*.json`, id placeholder `__P__x`): `research-gather`, `clarify-gate`, `plan-decompose`, `re-plan-loop`, `do-verify-loop`, `escalate-gate`. Builder dùng `Expand-Pattern $fragment $prefix` đóng dấu (`__P__x → <prefix>_x`) vào `workflow.json`. **Runtime luôn explicit** — engine KHÔNG expand ẩn lúc chạy (giữ "thấy gì chạy nấy", test-được-trước-khi-chạy).

### Tester 2 tầng

1. **Cấu trúc** (mock, free): `check` — `validate` exit 0 + `run -Mock` done + mọi `output_key` non-empty.
2. **Trial** (thật, đốt token): `trial` — copy project vào `company/sandbox/<runid>/` cô lập, chạy THẬT (no `-Mock`), assert `trial[]` trên artifact. Teardown sau chạy.

Thay "LLM phán cảm tính" bằng "thử việc thật".

### memory/ — trí nhớ 2 tầng

Chất lượng tích luỹ qua các run: HQ-global (`company/memory/{mistakes,patterns,global}.md`) + per-branch (`<project>/memory/context.md`, sinh lười). Bridge nạp 3 key vào prompt: `{{mem_mistakes}}` / `{{mem_patterns}}` (gộp `global.md`) / `{{mem_context}}` — đọc by-type + cap N=10 mới nhất. Vai đầu-não **đọc** đầu vòng đời; node `record` (`memory_write`) **ghi** kết cục. Xem [`memory/README.md`](memory/README.md).

Ví dụ: một node researcher khai `input` có `{{mem_mistakes}}` → lúc chạy, bridge thay nó bằng 10 block lỗi mới nhất trong `memory/mistakes.md`. Demo `examples/mem-demo` chứng minh vòng tích luỹ (chạy mock 2 lần):

```powershell
./run.ps1 run mem-demo "việc A" -Mock   # run 1: memory rỗng → worker làm → node record GHI bài học
./run.ps1 run mem-demo "việc A" -Mock   # run 2: worker ĐỌC được bài học vừa ghi → output khác (tránh lặp)
```

### Human-in-the-loop (HITL)

Engine hỗ trợ **dừng chờ người** tại những điểm cần duyệt, và **phát event** có cấu trúc đầy đủ nội dung output mỗi node.

#### Node `approval` — gate duyệt author-time

Khai node `type: "approval"` trong `workflow.json` để đặt điểm dừng chờ người:

```json
{
  "id": "review_gate",
  "type": "approval",
  "prompt": "Kiểm tra plan trên. Duyệt thì approve, không thì reject.",
  "output_key": "gate_decision"
},
```

- `agent` không cần khai (gate không gọi model).
- Phải có **≥1 cạnh ra**. Nếu có ≥2 cạnh, mỗi cạnh cần nhãn `when` (vd `approve` / `reject`) để engine rẽ đúng nhánh.
- Render ASCII: `⏸ review_gate (approval)`. Mermaid: hexagon `review_gate{{"⏸ label"}}`.

#### Vòng đời khi chạy có gate

```powershell
# 1. Chạy → engine dừng tại gate, exit 3
./run.ps1 run my-app "request" -Mock
# → status=awaiting, in prompt + hướng dẫn resume

# 2. Xem trạng thái (hiện gate + prompt + choices)
./run.ps1 status my-app

# 3. Bơm quyết định → engine tiếp tục
./run.ps1 resume my-app -Decision approve

# Hoặc: tự duyệt happy-path (cho test/CI offline)
./run.ps1 run my-app "request" -Mock -AutoApprove
```

- `exit 3` = run đang chờ người. Không phải lỗi — tiếp bằng `resume -Decision`.
- `-Decision` nhận: `approve` / `reject` / nhãn `when` bất kỳ trên cạnh ra của gate.
- `-AutoApprove`: tự chọn cạnh đầu tiên (ưu tiên `when='approve'`) — dùng cho test offline, không cần tương tác.
- Demo: `examples/approval-demo/` — graph có node `approval` giữa plan→build; `selftest` auto-verify vòng pause→resume→done.

#### `events.ndjson` — output đầy đủ mỗi lượt

Mỗi run ghi `<run>/events.ndjson` — mỗi dòng là 1 JSON hợp lệ:

```
{"seq":1,"ts":"...","type":"run_start","node":"a","agent":"...","entry":"a","request":"ping"}
{"seq":2,"ts":"...","type":"node_start","node":"a","agent":"agents/a.md"}
{"seq":3,"ts":"...","type":"node_output","node":"a","output":"A: ping"}   ← nội dung ĐẦY ĐỦ
{"seq":4,"ts":"...","type":"node_done","node":"a","output_key":"result","chars":7}
...
{"seq":N,"ts":"...","type":"run_end","status":"done","terminal":"b"}
```

7 loại event: `run_start` · `node_start` · `node_output` · `node_done` · `awaiting` · `resumed` · `diff_violation` · `run_end`. `run.log` cũ giữ nguyên (additive). `events.ndjson` là nguồn cho app stream live (Phase F).

#### Diff-scope guard (builder sandbox)

Builder đôi khi ghi ngoài vùng khai báo. Sau khi HQ chạy xong (trong sandbox), engine so snapshot file trước/sau: nếu có file bị **thêm/sửa/xoá ngoài whitelist** → phát event `diff_violation` + **pause `awaiting`** (không promote mù). Resume bằng `approve` để bỏ qua (manual override); `reject` để huỷ.

```
Whitelist mặc định (vùng được phép đổi trong 1 run):
  projects/<name>/   ← builder output (scope của builder)
  spec.json          ← build-spec input
  .runs/             ← engine TỰ QUẢN: run artifacts (state/events/output_key txt)
  memory/            ← engine TỰ QUẢN: memory write (record node)
Vi phạm = đụng NGOÀI 4 vùng trên (vd builder ghi catalog/, hay ../).
```

> Snapshot bọc **cả workflow** (không chỉ riêng node builder) nên `.runs/` + `memory/` mà engine tự sinh phải nằm trong whitelist — nếu không sẽ false-positive. Builder xoá `.runs/` *giữa* run đã bị bắt sớm hơn (tester/record fail → run fail trước cả diff-check).

---

---

## Artifact mỗi lần run (state v2 — theo lượt thăm)

Node lặp được (loop) → state keyed theo **lượt thăm** (`seq`), không theo step name:

```
<project>/.runs/<timestamp>/
├── state.json              # entry, max_steps, path[], visits[]: {seq,node,iter,status,output_key,error}, status run-level
│                           # (khi awaiting: thêm field awaiting:{node,prompt,choices})
├── events.ndjson           # chuỗi event có cấu trúc + nội dung output đầy đủ mỗi node (7 loại)
├── <output_key>.txt        # output MỚI NHẤT của key (nguồn bridge, latest-wins)
├── <seq>-<node>.out.txt    # lịch sử output từng lượt (debug, không ghi đè)
├── <seq>-<node>.prompt.txt # prompt cuối nhét vào claude
├── <seq>-<node>.raw.json   # raw JSON claude trả (chỉ real mode)
└── run.log
<project>/.runs/latest.json # con trỏ tới run mới nhất
```

`resume` đọc `latest.json`, nạp lại context từ các `<output_key>.txt` mới nhất + `path` đã đi, giữ các lượt `done`, retry node dở (đúng `seq`/`iter`) rồi tiếp tục walk **trên cùng run dir**.

`.runs/` (mỗi project) và `sandbox/` được gitignore — artifact regen-được, không commit.

---

## Biến môi trường

| Biến | Tác dụng |
|---|---|
| `ENGINE_LOG_LEVEL` | Lọc log: `Debug` / `Info` / `Warn` / `Error` (mặc định `Info`) |
| `ENGINE_MOCK_FAIL` | Chỉ trong `-Mock`: khớp tên agent → ném lỗi xác định, test fail/resume offline |
| `ENGINE_MOCK_ROUTER` | Chỉ trong `-Mock`: đa-spec ngăn bởi `;` (`"a:l1,l2;b:l3"`) — mỗi router steer độc lập; lần gọi thứ i của `<agent>` trả nhãn `lᵢ` (cạn list → giữ nhãn cuối) |

---

## App — Workflow viewer + live log + duyệt + in-app edit (Phase E + F + G)

App web local (`company/app/`) xem graph workflow tương tác, chạy run từ UI, theo dõi log live, duyệt gate HITL.
Stack: React + Vite + Tailwind + React Flow + dagre. Server Node `http` thuần (dependency-free), bind `localhost`.

### Chạy app

```bash
# Dev mode (hot-reload, Vite dev server proxy sang server.mjs)
cd company/app
npm install          # lần đầu
npm run dev          # → http://localhost:5173

# Serve từ build
npm run build
node server.mjs      # → http://localhost:5179
```

`server.mjs` cũng chạy độc lập (serve `dist/` đã build + API). Nếu chỉ đổi JS/CSS, build lại bằng `npm run build`.

### Tính năng viewer (Phase E)

- **Chọn project** từ dropdown (hiển thị toàn bộ project có `workflow.json` trong `projects/`, `examples/`).
- **Vẽ graph tương tác**: 4 loại node (worker rect / router diamond ◇ / approval hexagon ⏸ / terminal); cạnh có hướng; nhãn `when` trên cạnh router; back-edge (loop) = dashed orange.
- **Zoom / pan / kéo thả node** — scroll để zoom, kéo nền để pan, kéo node cá nhân để bố trí lại.
- **Auto-layout dagre** mặc định (TB top-down). Nút **Reset layout** trên góc phải để quay về layout auto.
- **Persist vị trí**: kéo node xong → vị trí tự lưu vào `<project>/.layout.json` (app-side, gitignored); reload giữ nguyên.
- **Metadata strip**: hiển thị `entry`, `#nodes`, `#edges`, `max_steps`.

### Tính năng live log + run control + duyệt (Phase F)

- **Ô request**: gõ task/ngữ cảnh cho run (vd "build a landing page with email signup"). Router workflow đọc `{{user_request}}` để định tuyến; mock bỏ qua. Enter = chạy luôn.
- **Nút ▶ Run (Mock)**: bấm → app spawn `run.ps1 run <proj> "<request>" -Mock` qua server, stream log live qua SSE.
- **Log panel**: mỗi event hiện 1 dòng/khối — `node_output` hiện **nội dung output đầy đủ** (không chỉ "N chars"); `run_end` hiện trạng thái (done/failed/awaiting). Auto-scroll theo event mới. Nút **Clear** dọn log + dừng stream.
- **Highlight node live**: node `running` (viền xanh + pulse) → `done` (xanh lá + ✓) → `awaiting` (tím + ⏸ + pulse) trên graph React Flow theo thứ tự walk thực tế.
- **Approval gate UI**: khi engine dừng ở `awaiting` → panel duyệt hiện `prompt` + danh sách `choices[]`; bấm 1 nhãn → `POST /api/decision` → engine resume tiếp, SSE chảy tiếp (cùng run dir). Hỗ trợ approve / reject / đổi nhãn đi nhánh khác. `diff_violation` (builder đụng file ngoài vùng trắng) hiện danh sách `violations[]` trong panel trước khi duyệt.
- **Real-run guard (F-D2)**: checkbox "Real" cạnh nút Run; bật + bấm Run → **dialog cảnh báo đốt token**; Cancel = không spawn. Mặc định Mock (không đốt token).

### Tính năng in-app edit (Phase G)

Edit cấu trúc graph **ngay trong app** — chỉ cho project dạng **graph** (`nodes`/`edges`); project pipeline-v1 hiện nút grayed-out "✎ Edit (v1)" → dùng CLI `run.ps1 edit` thay.

- **Bật edit mode**: nút **✎ Edit** (góc phải header) → badge `✎ EDIT` hiện trên canvas.
- **Nối / xoá cạnh**: kéo từ handle node nguồn → node đích để tạo cạnh mới; click cạnh → **EdgePanel** (sửa nhãn `when` + nút Delete edge).
- **Thêm node**: nút **+ Node** → **AddNodePanel** (điền `id` / `type` / `agent` / `output_key` / `prompt`).
- **Xoá node**: click node → **NodePanel** → **Delete node** (cascade xoá mọi cạnh dính; dialog xác nhận).
- **Sửa field node**: click node (edit mode) → NodePanel inline (type / agent / output_key / prompt).
- **Sửa graph-level**: panel **Graph settings** (top-right khi edit mode) → dropdown `entry` + input `max_steps`.
- **Save (validate-gated)**: nút **💾 Save graph** → `POST /api/workflow` → engine ghi `workflow.json` atomically:
  - `validate` PASS → **commit** + toast `✓ Saved` + re-fetch graph.
  - `validate` FAIL → **file cũ giữ nguyên** + panel **Validation errors** hiện `errors[]`. `workflow.json` LUÔN hợp lệ trên đĩa.
- **Discard**: nút **Discard** → reload graph từ đĩa, bỏ mọi thay đổi chưa lưu.
- **Unsaved guard**: chuyển project khi có thay đổi chưa save → dialog xác nhận. Badge `✎ EDIT — unsaved changes` khi dirty.
- **Coordinate-free** (bất biến #2): `workflow.json` chỉ chứa semantic (`nodes`/`edges`/`entry`/`max_steps`); toạ độ (kể cả node mới) → `.layout.json` qua `/api/layout`. `git diff workflow.json` sau drag = ZERO toạ độ.

> **Giới hạn**: App chỉ chạy `run` (mock mặc định). Edit graph = chỉ dạng **graph-format** (`nodes`/`edges`); pipeline-v1 dùng CLI `run.ps1 edit` (TUI). Undo/redo nhiều bước: reload = discard pending.

### Bất biến

- **`workflow.json` KHÔNG bao giờ bị ghi toạ độ** — toạ độ chỉ nằm trong `<project>/.layout.json` (tách biệt, gitignored).
- Data-layer gọi engine `run.ps1 graph <proj> -Json` (chuẩn hoá graph, xử UTF-16). App KHÔNG tự parse `workflow.json`.
- **Engine ghi qua `save-graph` additive** — `POST /api/workflow` shell `run.ps1 save-graph` (validate-gated, atomic); mock/validate/run path cũ y nguyên.
- `server.mjs` dependency-free (Node `http`/`fs`/`child_process` thuần). Server bind `127.0.0.1`.

### Files app (Phase E + F + G)

| File | Vai trò |
|---|---|
| `app/server.mjs` | Server Node http: serve `dist/` + `GET /api/projects` + `GET /api/graph` + `GET/POST /api/layout` (E) + `POST /api/run` + `GET /api/events` SSE + `POST /api/decision` (F) + `GET /api/workflow` (raw) + `POST /api/workflow` validate-gated (G) |
| `app/src/App.jsx` | Root: header + project picker + nút Run (Mock/Real) + run state + SSE client + `handleDecision` + **edit-mode toggle** (disabled khi pipeline-v1) |
| `app/src/GraphView.jsx` | Graph canvas: fetch graph+layout → dagre → React Flow + `nodeStatuses` highlight + save-on-drag + reset + **edit-mode** (add/del node + form field + connect/delete edge + when-label + entry/max_steps + save validate-gated + discard) |
| `app/src/RunLog.jsx` | Log panel: render từng event live (node_output đầy đủ, trạng thái, auto-scroll, clear) |
| `app/src/ApprovalPanel.jsx` | Gate duyệt: prompt + choices (nút mỗi nhãn) + violations (diff_violation) |
| `app/src/RealConfirmDialog.jsx` | Dialog cảnh báo đốt token khi bật Real mode |
| `app/src/nodes.jsx` | 4 custom node types + ring highlight (running/done/awaiting) + StatusBadge |
| `app/src/layout.js` | `applyDagreLayout`: dagre TB layout + detect back-edges |
| `engine/save.ps1` | `Save-Graph` write→validate→commit-or-restore + `Strip-GraphCoordinates` + `Write-SaveResult` JSON stdout |
| `examples/edit-demo/` | Fixture scratch graph-format (3 node: writer→checker router→publisher + revise back-edge) cho demo edit không bẩn `hq` |

---

## Cấu trúc thư mục

```
company/
├── engine/              # Engine — code cố định, một surface lệnh (run.ps1)
│   ├── run.ps1          # dispatcher (graph -Json additive — Phase E)
│   ├── graph.ps1        # Get-Graph: load workflow → graph chuẩn hoá
│   ├── workflow.ps1     # executor: single-cursor walk + router + loop + state + resume + approval-pause + frontmatter→CLI
│   ├── events.ps1       # Write-Event: append NDJSON vào events.ndjson (7 loại event + full output)
│   ├── bridge.ps1       # resolve {{key}} + {{mem_*}} → prompt
│   ├── viz.ps1          # graph → ASCII + Mermaid; approval node = hexagon ⏸
│   ├── validate.ps1     # graph validation; approval: không cần agent, ≥1 cạnh ra
│   ├── check.ps1        # Tester tầng cấu trúc
│   ├── sandbox.ps1      # Tester tầng trial + harness cô lập
│   ├── test-runner.ps1  # Invoke-SelfTest (lệnh: selftest) — 7 stamp + mem-demo + approval-demo + branchy/2-part (10 mục)
│   ├── pattern.ps1      # Expand-Pattern (stamp fragment)
│   ├── memory.ps1       # Get-Memory / Write-MemoryEntry
│   ├── status.ps1       # status + logs viewer; hiện awaiting gate + prompt + choices
│   ├── edit.ps1         # TUI
│   └── lib/{json,log,claude}.ps1
├── app/                 # App web (Phase E+F+G): React+Vite+Tailwind+React Flow+dagre
│   ├── server.mjs       # Node http: serve dist/ + API projects/graph/layout (E) + run/events SSE/decision (F) + workflow save-graph (G)
│   ├── src/             # React: App·GraphView·RunLog·ApprovalPanel·RealConfirmDialog·nodes·layout
│   └── package.json     # npm — npm run dev / npm run build / node server.mjs
├── catalog/             # 17 vai chi nhánh hand-authored (thư viện vai tham khảo)
├── patterns/            # 6 fragment robustness
├── memory/              # Store trí nhớ HQ-global (mistakes/patterns/global)
├── projects/            # Chi nhánh build ra (gitignored — regen-được)
├── sandbox/             # Khu cô lập Tester tầng trial (gitignored — rỗng khi rảnh)
├── examples/            # Demo + fixture (hello, branchy, loopy, p-*, mem-demo, approval-demo, edit-demo)
├── information/         # Master design brief gốc
└── plan/                # hq-build/ + hq-improve/ (DONE) + hq-v2/ (đang làm)
```

**Trạng thái build**: Phase hq-build (R/0/1/2/M/3/4/5) + hq-improve (A→G) ✅ DONE. hq-v2 Phase 0 + H.0–H.3 ✅ DONE; Phase H.4+ đang làm. App web React+Vite+Tailwind+React Flow: xem graph tương tác + bấm Run → log live + node highlight + duyệt HITL + **sửa cấu trúc graph validate-gated**. Xem §App bên trên.

Bộ test offline (mock, không đốt token): **`./run.ps1 selftest`** (7 `p-*/stamp.ps1` + mem-demo + approval-demo done-gate + branchy/2-part-protocol; **10 mục tổng**; exit = số mục fail).
