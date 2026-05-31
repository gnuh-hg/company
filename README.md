# Workflow Engine + HQ

> **Engine** điều phối agent chạy full-local trên PowerShell — đọc `workflow.json` dạng **đồ thị điều khiển** (`nodes` + `edges` + `entry`), đi theo đồ thị bằng con trỏ đơn (single-cursor walk), gọi agent qua `claude -p`, ghép context bằng bridge, log + state. Hỗ trợ rẽ nhánh OR (router agent quyết), merge, loop (cycle có chặn `max_steps`).
>
> **HQ** là bộ "thợ lắp" chạy *trên* engine: nhận yêu cầu user → chọn vai từ `catalog/` + pattern từ `patterns/` → sinh ra một **chi nhánh** (`workflow.json` + agents) → tự test (cấu trúc + trial thật) → tích luỹ trí nhớ. Engine là code cố định; HQ là một workflow chạy bằng chính engine đó.

`pipeline` tuyến tính (v1) vẫn chạy nguyên: loader tự chuyển thành graph nội bộ → **một executor duy nhất** cho cả hai dạng. Không lưu toạ độ — layout tính lúc render.

---

## Yêu cầu

- PowerShell 7 (`pwsh`).
- `claude` CLI trong PATH — **chỉ cần cho run thật** (không `-Mock`).
- Không cần build, không cần cài thêm gì cho mock mode.

---

## Quickstart — 3 luồng

Mọi lệnh chạy từ `company/engine/`. Có **3 luồng** dùng engine, tách bạch theo mục tiêu:

```powershell
cd company/engine
```

### Luồng 1 — chạy & soi một project con (demo/fixture có sẵn)

```powershell
./run.ps1 graph    hello              # 1. Xem đồ thị (node + cạnh) + xuất Mermaid     (cũ: viz)
./run.ps1 validate hello              # 2. Kiểm tra hợp lệ (exit = số lỗi)
./run.ps1 run      hello "ping" -Mock # 3. Chạy offline (mock — không gọi model, không đốt token)
./run.ps1 status   hello              # 4. Xem tiến độ run vừa rồi
./run.ps1 logs     hello              #    + prompt/output từng lượt thăm
```

Sau bước 3, run `hello` (2 node `a → b`) phải báo cả 2 lượt `done`, path `a → b`, in đường dẫn run dir. Chạy thật (gọi model qua `claude` CLI) — bỏ `-Mock`: `./run.ps1 run hello "câu hỏi thật" -Model claude-opus-4-7`.

### Luồng 2 — chạy HQ (sinh chi nhánh thật)

HQ là một workflow có **router** → cần `-Router` để steer dry-run gate (xem [§Lúc nào vào sandbox](#lúc-nào-vào-sandbox-lúc-nào-vào-projects)):

```powershell
./run.ps1 autobuild hq "Landing page thu email" -Router "coo:build;rg_gate:enough;tester:pass"        # dry-run gate, free  (cũ: e2e)
./run.ps1 autobuild hq "Landing page thu email" -Router "coo:build;rg_gate:enough;tester:pass" -Real  # chạy thật → promote vào projects/
```

`autofix` (cũ: `e2efix`) là biến thể fix-loop: seed một branch hỏng → HQ patch → verify fail→pass → promote.

### Luồng 3 — nối node (tạo workflow mới)

3 cách dựng `workflow.json`, **không** lưu toạ độ (xem [§workflow.json](#workflowjson--đồ-thị-điều-khiển-không-toạ-độ)):

```powershell
./run.ps1 build my-spec.json my-app   # (a) Builder deterministic: build-spec JSON → chi nhánh (copy vai + stamp pattern)
./run.ps1 edit my-app                  # (b) TUI: thêm/xoá/đổi node, chọn agent, set input deps
# (c) App Workflow Viewer — xem § "App — Workflow viewer" bên dưới
```

---

## Surface lệnh

```
./run.ps1 <command> <project> [args]
```

> **`hq` chỉ là MỘT project — không có lệnh "dành riêng cho hq".** Cái quyết định bạn thao tác với HQ hay project con **không phải tên lệnh, mà là `<project>` bạn truyền vào**. `hq` (ở `company/hq`) tự nó là một `workflow.json` 11 node — khác ở chỗ việc nó làm là *đẻ ra chi nhánh khác*; project con (`hello`, `landing-email`) là workflow lá, chạy nó chỉ thực thi pipeline của chính nó. Hệ quả:
> - **Nhóm PROJECT** (`run`/`resume`/`graph`/`validate`/`check`/`trial`/`status`/`logs`/`edit`) — **generic, dùng cho cả hai**. `graph hello` xem đồ thị app lá; `graph hq` xem đồ thị nhà máy. Cùng lệnh, khác đối tượng.
> - **`autobuild`/`autofix`** — 2 lệnh **duy nhất gắn chặt hq**: chạy nhà máy end-to-end để đẻ + promote một chi nhánh (`<project>` luôn là `hq`).
> - **`build`** — đẻ chi nhánh **không qua hq**, nhận `<spec-file>` (không phải project).

`<project>` nhận **tên gọn** (`hello`, `hq`) hoặc **path** (`examples/hello`) — engine resolve theo thứ tự: path nguyên trạng → `projects/<name>` (app thật) → `examples/<name>` (demo/fixture) → `company/<name>` (top-level, vd `hq`). ⚠ **Footgun (A-05)**: nếu sau khi `autobuild` promote ra `projects/<name>` mà cũng có `examples/<name>` trùng tên, tên gọn **ưu tiên `projects/`** — gọi dạng path (`examples/<name>`) để chỉ đích chính xác.

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
| **BUILD** | `build` | `build <spec-file> [<outName>]` | **Builder engine**: build-spec JSON → sinh chi nhánh (copy vai + stamp pattern + nối edge) |
| | `autobuild` | `autobuild <proj> "<request>" [-Router s] [-Real] [-KeepSandbox]` | **Real-run harness HQ**: dry-run gate (free) → (`-Real`) sandbox → run thật → verify → promote |
| | `autofix` | `autofix <proj> "<req>" -Seed <br> -Branch <n> [-Router s] [-Real]` | **Fix-loop harness**: seed branch hỏng → HQ patch → verify fail→pass → promote |
| **AUTHOR** | `edit` | `edit <proj>` | TUI thêm/xoá/đổi thứ tự node, chọn agent, set input deps |
| **Advanced** | `selftest` | `selftest [all]` | Chạy bộ test engine (3 script + 7 stamp + mem-demo); **exit = số mục fail** |

Không arg / `help` / `-h` / `--help` → in help đầy đủ.

**Tương thích**: tên cũ vẫn chạy như **alias im lặng** (route thẳng tên mới, không in note) — `viz`→`graph`, `e2e`→`autobuild`, `e2efix`→`autofix`, `test`→`selftest`.

- **Claude** dùng nhiều: `run`/`resume` (mock khi test), `validate`/`check`/`trial` (gate trước khi báo done), `status`+`logs` (kiểm tra). Non-interactive, exit code rõ ràng.
- **User** dùng nhiều: `graph` (đọc đồ thị), `edit` (TUI tương tác — không hợp với Claude vì nhập tay).
- **Đốt token**: `run`/`resume` không `-Mock`, `trial` (tầng 2 luôn thật), `autobuild`/`autofix` với `-Real`. Còn lại free.
- **Xem output**: lúc chạy, `run` chỉ in `node 'x' → done (N chars)` — **không** in nội dung lên màn hình. Dùng `logs <proj> [node]` SAU đó để đọc prompt/output đầy đủ; hoặc đọc `<run>/events.ndjson` (mỗi dòng JSON chứa nội dung output đầy đủ — xem [§Human-in-the-loop](#human-in-the-loop-hitl)). *(Stream live → Phase F.)*
- **Gate duyệt (`awaiting`)**: khi gặp node `approval` hoặc vi phạm diff-scope, engine **dừng** (exit 3) + in hướng dẫn resume. Thêm `-AutoApprove` để tự duyệt (dùng cho test/CI offline, không tương tác).

---

## Lúc nào vào `sandbox/`, lúc nào vào `projects/`?

Đây là điểm hay nhầm. Có **3 nơi** artifact đi tới, tuỳ lệnh:

| Nơi | Là gì | Lệnh nào ghi vào đây | Project gốc bị đụng? |
|---|---|---|---|
| `<project>/.runs/<ts>/` | Lịch sử run **của chính project đó** | `run`, `resume` (kể cả khi chạy `hq`) | ✅ tại chỗ (ghi vào `.runs/` của nó) |
| `projects/<name>/` | **Nhà cuối** của một chi nhánh đã sinh/đạt | `build` ghi **thẳng**; `autobuild`/`autofix` **promote** vào sau khi verify | — (tạo branch mới) |
| `sandbox/<runid>/` | Bản **COPY tạm cô lập** để chạy thật rồi vứt | `trial` (tầng 2); `autobuild`/`autofix` với `-Real` | ❌ KHÔNG — gốc giữ sạch |

Mô hình tư duy theo lệnh:

- **`run` / `resume` / `graph` / `validate` / `check` / `status` / `logs` / `edit`** — thao tác **tại chỗ** trên project. Artifact (nếu có) vào `<project>/.runs/`. Không liên quan sandbox.
- **`build <spec>`** — Builder deterministic, ghi **thẳng** một chi nhánh mới vào `projects/<name>/` (không qua sandbox).
- **`trial <proj>`** — copy project vào `sandbox/<runid>/`, chạy **THẬT** ở đó, assert `trial[]`, rồi **teardown** (xoá sandbox). Project gốc không bị bẩn bởi run thật.
- **`autobuild` / `autofix` với `-Real`** — copy `hq/` vào `sandbox/<runid>/`, **HQ chạy thật ngay trong sandbox** → Builder sinh chi nhánh tại `sandbox/<runid>/projects/<name>/` → verify (`validate`/`check`) → **promote** (copy) chi nhánh đạt ra `projects/<name>/` → teardown sandbox. (Không `-Real`: chỉ chạy dry-run gate mock, **không** đụng sandbox.)

> Vì sao phải qua sandbox? Run thật + Builder ghi file là thao tác "bẩn". Cô lập trong `sandbox/` để `hq/` gốc luôn sạch; chỉ thứ đã **verify đạt** mới được promote ra `projects/`. `-KeepSandbox` giữ lại sandbox để soi artifact khi debug (mặc định teardown).

### Ví dụ cụ thể — `autobuild` build một chi nhánh

Giả sử muốn HQ tự dựng một landing page thu email. **Trước khi chạy**, thư mục sạch:

```
company/
├── hq/              # graph HQ (nguồn — sẽ KHÔNG bị đụng)
├── projects/        # rỗng
└── sandbox/         # rỗng
```

Bước 1 — chạy dry-run gate (free, không token) để chắc graph đi tới terminal:

```powershell
./run.ps1 autobuild hq "Landing page thu email, có nút submit" -Router "coo:build;rg_gate:enough;tester:pass"
# → chỉ mock: COO→…→record tới terminal OK. CHƯA đụng sandbox, CHƯA sinh file.
```

> **`-Router` là bắt buộc cho graph có router (A-24).** Cú pháp `"<node>:<label>;<node>:<label>;..."` (đa-spec ngăn bởi `;`; mỗi router 1 nhãn, hoặc `node:l1,l2` cho nhiều lượt). Gate chạy `-Mock`, mà ở mock router **không tự nghĩ ra nhãn** — phải khai path kỳ vọng để steer. `"coo:build;rg_gate:enough;tester:pass"` = path build-happy: COO chọn `build` → rg_gate `enough` → tester `pass` → terminal `record`. Thiếu `-Router` → router `coo` không khớp `when` nào → gate fail. Spec này **chỉ** tác động lên dry-run mock; khi `-Real`, router thật tự quyết theo output model. *(Heuristic suy RouterSpec happy-path từ graph → Phase C.)*
>
> `hq` là project top-level (`company/hq`). Resolver tìm tên gọn theo thứ tự `projects/` → `examples/` → `company/` nên `hq` chạy được; vẫn có thể gọi dạng path `../hq`.

Bước 2 — chạy thật (đốt token) bằng `-Real`:

```powershell
./run.ps1 autobuild hq "Landing page thu email, có nút submit" -Router "coo:build;rg_gate:enough;tester:pass" -Real
```

**Trong lúc chạy**, engine tự làm tuần tự:

```
1. dry-run gate (mock)         ✓ graph tới terminal
2. copy hq/ → sandbox/20260528-153000/        (bản tạm cô lập)
3. HQ chạy THẬT trong sandbox:
      COO → researcher → … → CTO → Builder
      Builder sinh chi nhánh → sandbox/20260528-153000/projects/landing-email/
      Tester verify (validate + check)         ✓ pass
4. promote: copy chi nhánh đạt → company/projects/landing-email/
5. teardown: xoá sandbox/20260528-153000/
```

**Sau khi xong**, gốc vẫn sạch, chỉ có chi nhánh đạt nằm ở `projects/`:

```
company/
├── hq/                       # vẫn y nguyên
├── projects/
│   └── landing-email/        # ← chi nhánh HQ vừa build, đã verify đạt
│       ├── workflow.json
│       └── agents/{pm,ux,frontend-developer,qa-functional}.md
└── sandbox/                  # rỗng lại (đã teardown)
```

> Nếu verify **không đạt**, chi nhánh nằm lại trong sandbox và **không** promote — `projects/` vẫn rỗng. Thêm `-KeepSandbox` để giữ sandbox mà soi Builder đã sinh ra gì.

### Ví dụ — `trial` test một project có sẵn

`trial` KHÔNG sinh chi nhánh mới; nó test một project đã có, chạy thật trong bản copy rồi vứt:

```powershell
./run.ps1 trial loopy
# 1. tầng cấu trúc (mock, free): validate + run -Mock + output_key  ✓
# 2. copy examples/loopy → sandbox/<runid>/ → chạy THẬT → assert trial[]  ✓
# 3. teardown sandbox. examples/loopy gốc KHÔNG có .runs mới (chạy ở bản copy).
```

### Ví dụ — `build` ghi thẳng, không sandbox

`build` là Builder deterministic (không LLM), nên ghi **thẳng** vào `projects/`, bỏ qua sandbox:

```powershell
./run.ps1 build my-spec.json my-app
# → company/projects/my-app/{workflow.json, agents/*.md}  (copy vai catalog + stamp pattern)
./run.ps1 validate my-app      # rồi kiểm tra như project thường
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
    { "id": "tier",   "agent": "agents/tier-router.md", "type": "router", "input": "{{user_request}}", "output_key": "tier" },
    { "id": "d10",    "agent": "agents/disc.md",   "input": "{{user_request}}\n10%", "output_key": "discount" },
    { "id": "output", "agent": "agents/output.md",  "input": "{{user_request}}\n{{discount}}", "output_key": "result" }
  ],
  "edges": [
    { "from": "tier", "to": "d10", "when": "gt5000" },
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
| `type` | node | ⬜ | `"router"` nếu là điểm rẽ; vắng = node việc thường |
| `input` | node | ✅ | Template `{{key}}` — `{{user_request}}` (input gốc), `{{output_key}}` node đã chạy, hoặc `{{mem_*}}` (trí nhớ) |
| `output_key` | node | ✅ | Key lưu output node này (ghi vào context, **latest-wins** khi loop) |
| `from`/`to` | edge | ✅ | `id` node nguồn/đích |
| `when` | edge | ✅ nếu `from` là router | Nhãn khớp output router để chọn cạnh; node thường có đúng **1** cạnh ra (không `when`) |

- Cạnh là **cạnh điều khiển khai báo tường minh** (không suy từ `{{key}}`). Cho phép **cycle** (loop) qua cạnh quay lại node trước.
- `{{user_request}}` là input gốc lúc `run`. Loop-feedback resolve rỗng ở vòng đầu — hợp lệ.

### Router — rẽ nhánh do agent quyết

Engine **không có ngôn ngữ biểu thức**. Logic chọn cạnh nằm trong engine, agent chỉ trả nhãn:

- Node `type:"router"`: engine **chuẩn hoá output** → nhãn = dòng không-trắng **cuối**, trim, lowercase.
- Engine khớp nhãn với `when` của các cạnh ra. Khớp 1 → đi cạnh đó. Không khớp `when` nào → node **fail** (liệt kê `when` hợp lệ) → sửa rồi `resume`.

> **`-Mock` trần KHÔNG lái router (A-01).** Mock chỉ echo output xác định, không sinh nhãn router. Project **có router** chạy `-Mock` mà không khai `ENGINE_MOCK_ROUTER` (hoặc `-Router` cho `autobuild`) → router không khớp `when` nào → fail. Phải set `$env:ENGINE_MOCK_ROUTER = 'coo:build;tester:pass'` để steer. Project tuyến tính (như `hello`) không có router → `-Mock` trần chạy thẳng.

Ví dụ chạy thử demo router 4 nhánh (`examples/branchy`):

```powershell
./run.ps1 graph branchy                          # xem 4 nhánh + merge
# Mock-steer router đi nhánh cụ thể (không cần model):
$env:ENGINE_MOCK_ROUTER = "tier:gt5000"
./run.ps1 run branchy "đơn 8000" -Mock           # router trả nhãn "gt5000" → đi cạnh d10
./run.ps1 status branchy                          # path đi qua: tier → d10 → output
```

### Loop — cycle có chặn

- Cạnh `to` trỏ về node đã đi qua = **vòng lặp** (vd `verdict → build` khi `when:"fail"`).
- **Điều kiện thoát = router** (vd `verdict → ship` khi `when:"pass"`).
- **`max_steps` bắt buộc**: chạm trần → state `failed`, exit ≠ 0. Là cầu dao an toàn, **không** thay router làm exit chính.

Ví dụ demo loop build→test→verdict (`examples/loopy`): `verdict` là router, `fail` → quay về `build` (loop), `pass` → `ship` (thoát).

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

## HQ — bộ lắp ráp chi nhánh

HQ không phải engine mới; nó là một **workflow chạy bằng engine** (`hq/workflow.json`, 11 node, `entry=coo`, `max_steps=40`). Triết lý: **chất lượng = graph giàu tầng robustness**, không phải agent đặc biệt.

```
COO (router build/fix/unclear) → researcher → rg_gate → clarify_gate
   → Planner → CTO → Builder → Tester (router)
        ├─ fail  → Builder        (do-verify loop)
        ├─ replan→ Planner        (re-plan loop)
        └─ pass  → record         (ghi memory, terminal thành công)
   escalate-gate → escalate_report (terminal khi bí)
```

| Vai HQ | Việc | Quyền ghi file |
|---|---|---|
| **COO** | Router phân loại request: `build` / `fix` / `unclear` | — |
| **researcher** | Gom hiểu biết + memory → tóm tắt + `open_questions[]` | read-only |
| **Planner** | **plan-as-data** (WHAT): mục tiêu + bước + tiêu chí xong | — |
| **CTO** | **build-spec** (HOW): chọn vai catalog + pattern + nối edge + `trial[]` | — |
| **Builder** | build-spec → `workflow.json` + copy vai + stamp pattern + scaffold | ✅ chỉ Builder |
| **Tester** | Router: gọi checker (cấu trúc + trial) → `pass`/`fail`/`replan` + ghi memory | — |

Hợp đồng dữ liệu: **plan-as-data** (Planner) → **build-spec** (CTO) → **`workflow.json`** (Builder). Chi tiết schema + validator: [`hq/build-spec.md`](hq/build-spec.md). Validate spec bằng `Test-PlanSchema`/`Test-BuildSpec` **trước khi** Builder ghi file (validate-trước-khi-build).

### catalog/ — menu vai (input của CTO)

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
Vi phạm = đụng NGOÀI 4 vùng trên (vd builder ghi hq/agents/, catalog/, hay ../).
```

> Snapshot bọc **cả workflow** (không chỉ riêng node builder) nên `.runs/` + `memory/` mà engine tự sinh phải nằm trong whitelist — nếu không sẽ false-positive. Builder xoá `.runs/` *giữa* run đã bị bắt sớm hơn (tester/record fail → run fail trước cả diff-check).

---

### E2E thật (`autobuild` / `autofix`)

`engine/e2e.ps1`: dry-run gate (mock, xác nhận GRAPH tới terminal **trước khi** đốt token) → sandbox cô lập → run thật → verify (`validate`/`check`) → **kiểm diff-scope builder** → promote branch đạt vào `projects/`. `autofix` thêm fix-loop: seed branch hỏng → assert pre-fix `validate` FAIL → HQ patch thật → assert post-fix exit 0 + `file_changed` → promote.

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

## App — Workflow viewer (Phase E)

App web local (`company/app/`) đọc `workflow.json` qua engine `run.ps1 graph -Json` → vẽ graph tương tác (React + Vite + Tailwind + React Flow + dagre).

### Chạy app

```bash
# Dev mode (hot-reload, Vite dev server proxy sang server.mjs)
cd company/app
npm install          # lần đầu
npm run dev          # → http://localhost:5173

# Serve từ build (sau khi build)
npm run build
node server.mjs      # → http://localhost:5179
```

`server.mjs` cũng chạy độc lập (serve `dist/` đã build + API). Nếu chỉ đổi JS/CSS, build lại bằng `npm run build`.

### Tính năng

- **Chọn project** từ dropdown (hiển thị toàn bộ project có `workflow.json` trong `projects/`, `examples/`, `hq/`).
- **Vẽ graph tương tác**: 4 loại node (worker rect / router diamond ◇ / approval hexagon ⏸ / terminal); cạnh có hướng; nhãn `when` trên cạnh router; back-edge (loop) = dashed orange.
- **Zoom / pan / kéo thả node** — scroll để zoom, kéo nền để pan, kéo node cá nhân để bố trí lại.
- **Auto-layout dagre** mặc định (TB top-down). Nút **Reset layout** trên góc phải để quay về layout auto.
- **Persist vị trí**: kéo node xong → vị trí tự lưu vào `<project>/.layout.json` (app-side, gitignored); reload giữ nguyên. Đổi project → load layout riêng của project đó.
- **Metadata strip**: hiển thị `entry`, `#nodes`, `#edges`, `max_steps` của project đang xem.

### Bất biến

- **`workflow.json` KHÔNG bao giờ bị ghi toạ độ** — toạ độ chỉ nằm trong `<project>/.layout.json` (tách biệt, gitignored). Bất biến #2 đảm bảo `git diff workflow.json` luôn rỗng sau kéo thả.
- Data-layer gọi engine `run.ps1 graph <proj> -Json` để chuẩn hoá graph (xử UTF-16, reuse loader pipeline-v1). App KHÔNG tự parse `workflow.json`.

### Giới hạn (Phase E — chỉ xem)

App hiện chỉ **xem graph + layout**. Các tính năng sau thuộc Phase F/G:
- **Xem log live + chạy run** từ app → Phase F.
- **Duyệt plan / cấp quyền (approval gate)** từ app → Phase F.
- **Sửa graph trong app** (thêm/xoá node, nối cạnh) → Phase G.

### Files app

| File | Vai trò |
|---|---|
| `app/server.mjs` | Server Node http: serve `dist/` + `GET /api/projects` + `GET /api/graph` + `GET/POST /api/layout` |
| `app/src/App.jsx` | Root: header + project picker + `ReactFlowProvider` |
| `app/src/GraphView.jsx` | Graph canvas: fetch graph+layout → dagre → React Flow + save-on-drag + reset layout |
| `app/src/nodes.jsx` | 4 custom node types: WorkerNode / RouterNode / ApprovalNode / TerminalNode |
| `app/src/layout.js` | `applyDagreLayout`: dagre TB layout + detect back-edges |

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
│   ├── spec.ps1         # Test-PlanSchema / Test-BuildSpec / Invoke-BuildSpec (lệnh build)
│   ├── e2e.ps1          # Real-run harness HQ (autobuild/autofix) + Test-DiffScope (diff-scope guard)
│   ├── test-runner.ps1  # Invoke-SelfTest (lệnh: selftest) — gom 3 script + 7 stamp + mem-demo + approval-demo (12 mục)
│   ├── pattern.ps1      # Expand-Pattern (stamp fragment)
│   ├── memory.ps1       # Get-Memory / Write-MemoryEntry
│   ├── status.ps1       # status + logs viewer; hiện awaiting gate + prompt + choices
│   ├── edit.ps1         # TUI
│   └── lib/{json,log,claude}.ps1
├── app/                 # App web — Workflow viewer (Phase E): React+Vite+Tailwind+React Flow+dagre
│   ├── server.mjs       # Node http: serve dist/ + /api/projects + /api/graph + /api/layout
│   ├── src/             # React source: App.jsx · GraphView.jsx · nodes.jsx · layout.js
│   └── package.json     # npm — npm run dev / npm run build / node server.mjs
├── hq/                  # HQ graph: workflow.json (11 node) + agents/ + build-spec.md + skills.md
├── catalog/             # 17 vai chi nhánh hand-authored (menu cho CTO)
├── patterns/            # 6 fragment robustness
├── memory/              # Store trí nhớ HQ-global (mistakes/patterns/global)
├── projects/            # App thật HQ build ra (gitignored — regen từ build-spec)
├── sandbox/             # Khu cô lập Tester tầng trial (gitignored — rỗng khi rảnh)
├── examples/            # Demo + fixture + test scripts (hello, branchy, loopy, p-*, hq-*, *-tests.ps1)
├── information/         # Master design brief gốc
└── plan/                # hq-build/{ROADMAP.md + phase-*/} (đợt build, DONE) + hq-improve/ (đợt cải thiện)
```

**Trạng thái build**: toàn bộ Phase R / 0 / 1 / 2 / 3 / 4 / 5 / M đã ✅ DONE (xem [`plan/hq-build/ROADMAP.md`](plan/hq-build/ROADMAP.md)). **Phase E (App — Workflow viewer) ✅ DONE** — app web React+Vite+Tailwind+React Flow đọc `workflow.json` qua engine → vẽ graph tương tác, zoom/pan/drag, persist layout (xem §App bên trên).

Bộ test offline (mock, không đốt token): `examples/hq-tests.ps1` (per-agent HQ), `examples/hq-graph-tests.ps1` (8 path HQ graph), `examples/e2e-harness-tests.ps1` (harness round-trip). Chạy gom tất cả qua **`./run.ps1 selftest`** (3 script + 7 `p-*/stamp.ps1` + mem-demo + approval-demo done-gate; **12 mục tổng**; exit = số mục fail).
