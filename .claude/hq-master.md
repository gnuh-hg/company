# HQ-master — orchestration doc

> Điểm vào "bộ não" lead khi vận hành HQ như **native Claude Code team** (Agent Teams, CD-1
> hq-v2). Đọc file này + `teams/playbook.md` (chi tiết thao tác) **trước** khi spawn team.
>
> **HQ build CHI NHÁNH, KHÔNG build app.** Deliverable HQ-team = **cơ sở của một chi nhánh** chạy được
> (`workflow.json` + roster `agents/*.md` từ `catalog/` + scaffold tại `projects/<branch>/`). Chi nhánh ấy
> sau này mới build app/web. Lead/teammate KHÔNG tự dựng landing page / API / app — mà dựng chi nhánh.
>
> **3 nguyên tắc bất biến:**
> 1. Lead **điều phối**, không tự code/build cho task phức tạp — giao cho teammate.
> 2. Teammate giao tiếp **văn xuôi markdown**; builder ghi file chi nhánh **trực tiếp** (Write/Edit `workflow.json` + `agents/*.md`, KHÔNG `autobuild`); tester verify bằng `run.ps1 validate/run -Mock`.
> 3. Lead **drive một TaskList loop** — giao task → chờ → gate → task kế — KHÔNG chạy 1 lượt rồi quên.

---

## Engine LÀ vật-liệu HQ dựng nên (đọc trước để hết lẫn)

`run.ps1` + `engine/*.ps1` + `app/` là **workflow engine cho CHI NHÁNH**. Vì **deliverable của HQ
chính là một chi nhánh** (`workflow.json` + agents), engine vừa là **định dạng output** HQ ghi ra,
vừa là **công cụ verify**. Builder Write/Edit `workflow.json` + `agents/*.md` thẳng vào
`projects/<branch>/` (KHÔNG `autobuild` — đã xóa); tester gọi `run.ps1 validate/run -Mock` để gate.
**Engine là code cố định — KHÔNG sửa `engine/*.ps1`; chỉ GỌI `run.ps1`.**

| Khái niệm | Thuộc về | HQ-team dùng thế nào? |
|---|---|---|
| `TeamCreate` / `Agent` / `SendMessage` / `Task*` | Claude Code Agent Teams | ✅ Cách HQ điều phối |
| `.claude/agents/hq-*.md` + `teams/playbook.md` | HQ-team | ✅ Roster + brain |
| `.claude/memory/` | HQ-team store | ✅ Đọc/ghi qua skill `hq-memory` |
| `projects/<branch>/workflow.json` + `agents/*.md` | **Deliverable HQ** | ✅ Builder Write/Edit TRỰC TIẾP |
| `catalog/*.md` | Menu vai chi nhánh | ✅ CTO chọn, builder phỏng theo dựng roster |
| `run.ps1 validate/run/check/graph` | Engine | ✅ Builder smoke-check + tester gate (`-Mock`) |
| `run.ps1 autobuild/autofix` | Workflow cũ (đã xóa) | ❌ Không tồn tại — builder tự viết workflow.json |
| `build-spec` / `plan-as-data` JSON giữa teammate | Workflow cũ | ❌ Teammate giao tiếp prose; workflow.json là artifact, KHÁC |
| `company/memory/` + `<branch>/memory/` | Engine branch store (`memory.ps1` quản) | ❌ HQ KHÔNG đụng tay |

Teammate build **app trực tiếp** (index.html app, src/ app...) thay vì dựng chi nhánh → sai vai →
lead chỉnh ngay (ghi issue `SCOPE`/`FORM`). Teammate gọi `autobuild` hoặc trao đổi plan-as-data JSON
giữa các vai → tàn dư cũ → chỉnh (`FORM`).

---

## Roster teammate (`.claude/agents/hq-*.md`)

| Teammate | Vai | Tools | Output |
|---|---|---|---|
| `hq-researcher` | gom context (catalog/engine/chi nhánh mẫu) + memory → tóm tắt + câu-hỏi-còn-chặn | Read, Grep, Glob, WebSearch, Task*, SendMessage | prose 4 mục |
| `hq-planner` | WHAT — kế hoạch chi nhánh (Goal/Steps/Done-criteria = validate+run-Mock) | Read, Task*, SendMessage | prose, KHÔNG JSON |
| `hq-cto` | HOW — thiết kế chi nhánh (pipeline node/edge/when + roster từ catalog/) | Read, Task*, SendMessage | prose 5 mục A–E |
| `hq-builder` | Write/Edit `workflow.json` + `agents/*.md` chi nhánh vào `projects/<branch>/` | Read, Write, Edit, Bash, Task*, SendMessage | file + lệnh verify |
| `hq-tester` | verify chi nhánh bằng `run.ps1 validate/run -Mock` + ghi memory | Read, Bash, Task*, SendMessage | `CHECK_RESULT: pass\|fail` |

> **Lưu ý tool (bài học H.10):** mỗi agent body PHẢI có `TaskGet/TaskUpdate/TaskList/SendMessage` trong
> `tools:` — nếu chỉ liệt tool domain (Read/Bash...) thì teammate KHÔNG report/TaskUpdate được → câm.

Mỗi agent body đã chứa section **"Trong TeamCreate mode"** (ack + `TaskGet` + `TaskUpdate
in_progress` **cùng turn**; xong = `TaskUpdate completed` rồi `SendMessage` paste-full-output).
Lead KHÔNG cần lặp lại protocol đó trong brief.

---

## Vòng lặp điều phối (lead-driven TaskList loop)

Đây là khác biệt cốt lõi so với bản cũ: lead **không** chạy researcher→…→tester một lượt
rồi return. Lead quản một **TaskList** và drive từng bước, gate sau mỗi handoff, lặp tới khi
TaskList rỗng — giống leader trong demo tham chiếu.

```
LEAD nhận user_request
  │
  ├─ Phân loại
  │     ├── đơn giản / 1–2 tool call → LEAD tự xử (không spawn)
  │     ├── XÂY chi nhánh MỚI → lập team full chain ↓
  │     ├── SỬA chi nhánh ĐÃ CÓ theo yêu cầu user mới → lập team chain rút gọn ↓
  │     │     (loại request hạng nhất — KHÁC re-fix từ verdict tester ở nhánh FAIL bên dưới)
  │     └── phức tạp / multi-file / domain mới → lập team ↓
  │
  ├─ TeamCreate([researcher, planner, cto, builder, tester])  ← chọn tối thiểu cần
  │     spawn từng teammate bằng Agent(team_name, name, subagent_type, run_in_background:true)
  │     đợi ≥30–45s cho teammate đọc đầu phiên → ack
  │
  ├─ Lập TaskList: tách request thành các bước/deliverable (TaskCreate mỗi bước)
  │
  └─ LOOP cho từng task trong TaskList (theo thứ tự):
        │
        ├─ HANDOFF CHAIN (mỗi mũi tên = 1 gate của lead):
        │    researcher  → [gate: open_questions còn chặn? → hỏi user]
        │    → planner   → [gate: Goal/Done-criteria đo được?]
        │    → cto       → [gate: pipeline+roster đủ để builder không phải đoán?]
        │    → builder   → [gate: workflow.json+agents ghi vào projects/<branch>/, validate exit 0?]
        │    → tester    → CHECK_RESULT: pass|fail (run.ps1 validate + run -Mock)
        │
        │    Mỗi handoff: TaskUpdate(owner=teammate) + SendMessage wake → CHỜ report → gate
        │
        ├─ tester PASS → ghi memory (skill hq-memory) → TaskList còn task?
        │                   ├── còn → task kế (lặp LOOP)
        │                   └── hết → thoát LOOP
        │
        └─ tester FAIL → đọc lý do cụ thể (output lệnh, dòng lỗi)
                          ├── bug nhỏ      → SendMessage builder re-fix → tester re-verify
                          ├── sai kế hoạch → SendMessage planner re-plan → chain lại
                          └── fail ≥3 vòng → dừng, ghi mistakes.md, escalate user

  Khi thoát LOOP (mọi task pass):
    → ghi context.md + patterns.md (hq-memory)
    → shutdown_request tới mọi teammate → chờ ack
    → TeamDelete → báo user (tổng kết: task nào pass, file ở đâu, cách chạy)
```

**Rút gọn chain theo loại task** (không phải task nào cũng cần đủ 5 vai):

| Loại request | Vai cần | Bỏ qua |
|---|---|---|
| Xây chi nhánh mới multi-file / domain mới | researcher → planner → cto → builder → tester | — |
| **Sửa chi nhánh đã có theo yêu cầu user mới** (hạng nhất) | planner (light) → builder → tester | researcher/cto |
| Chỉ thiết kế (chưa build) | researcher → planner → cto | builder/tester |
| Yêu cầu rõ ràng, nhỏ, 1 stack | planner → builder → tester | researcher/cto |

> **⚠️ "Sửa chi nhánh đã có theo yêu cầu user mới" ≠ re-fix từ verdict.** Đây là **loại request
> hạng nhất** (user yêu cầu thay đổi một chi nhánh đang tồn tại — vd "thêm node X", "đổi roster") →
> cần **planner light** chốt WHAT thay đổi rồi builder Edit phẫu thuật → tester verify. KHÁC với
> nhánh FAIL trong LOOP (tester báo fail → builder re-fix bug) vốn không có user-request mới. Builder
> ở loại này **đọc `projects/<branch>/` hiện có TRƯỚC**, Edit chính xác phần cần đổi, **KHÔNG ghi đè
> toàn bộ** workflow.json/agents.

**Gate cũ tan vào lead reasoning** (không còn node router):

| Gate workflow cũ | Nay là |
|---|---|
| `coo` (router build/fix/unclear) | Lead phân loại bằng reasoning |
| `rg_gate` (đủ research chưa) | Lead xét `open_questions[]` của researcher |
| `clarify_gate` (hỏi user) | Lead hỏi user trực tiếp |
| `escalate_gate` | Lead quyết escalate sau N vòng fail |
| `record` (node ghi memory) | Lead gọi skill `hq-memory` sau verify pass |

---

## Cách spawn (cụ thể — đây là phần hay vướng)

```
1. TeamCreate(team_name="hq-<slug-task>")
2. Với mỗi teammate cần:
     Agent(team_name="hq-<slug>", name="<role>", subagent_type="hq-<role>",
           run_in_background=true)
   - name = tên gọi ngắn ("researcher", "builder"…); subagent_type = file agent ("hq-researcher"…)
   - spawn song song (cùng 1 response block) các teammate độc lập
3. ĐỢI ≥30–45s — teammate đọc memory + agent body trước khi ack.
     Gửi SendMessage sớm → bị queue đè → SLOW-PICKUP.
4. TaskCreate(title, description=<brief đầy đủ self-contained>, owner="<role>")
5. SendMessage(to="<role>", message="Task #N ready — TaskGet(N) đọc brief rồi bắt đầu.")
6. Chờ teammate SendMessage report → gate → handoff kế / re-fix.
7. Xong tất cả: SendMessage shutdown_request → TeamDelete.
```

Brief template + per-role brief + layout terminal + xử lý teammate im → **`teams/playbook.md`**.

---

## Trỏ tài liệu

| Tài liệu | Đường dẫn |
|---|---|
| Playbook thao tác (spawn template, layout, failure-mode) | `.claude/teams/playbook.md` |
| Roster agent body | `.claude/agents/hq-*.md` |
| Issue queue (hành vi teammate) | `company/issues/team-issues-queue.md` |
| Skill build + verify | `.claude/skills/build-verify/SKILL.md` |
| Skill memory | `.claude/skills/hq-memory/SKILL.md` |
| Memory store HQ-team | `.claude/memory/` |
| Spec kiến trúc đầy đủ (lịch sử thiết kế) | `plan/hq-v2/phase-h/design.md` |
