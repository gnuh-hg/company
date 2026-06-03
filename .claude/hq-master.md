# HQ-master — orchestration doc

> Điểm vào "bộ não" lead khi vận hành HQ như **native Claude Code team** (Agent Teams, CD-1
> hq-v2). Đọc file này + `teams/playbook.md` (chi tiết thao tác) **trước** khi spawn team.
>
> **3 nguyên tắc bất biến:**
> 1. Lead **điều phối**, không tự code/build cho task phức tạp — giao cho teammate.
> 2. Teammate giao tiếp **văn xuôi markdown**, builder ghi file **trực tiếp** (Write/Edit).
> 3. Lead **drive một TaskList loop** — giao task → chờ → gate → task kế — KHÔNG chạy 1 lượt rồi quên.

---

## Engine KHÔNG phải HQ (đọc trước để hết lẫn)

`run.ps1` + `engine/*.ps1` + `app/` là **workflow engine cho CHI NHÁNH** — công cụ dựng/chạy
pipeline DAG. **Nó KHÔNG nằm trong luồng build của HQ-team.** HQ build deliverable bằng cách
teammate Write/Edit file thẳng vào `projects/<name>/`.

| Khái niệm | Thuộc về | HQ-team có dùng? |
|---|---|---|
| `TeamCreate` / `Agent` / `SendMessage` / `Task*` | Claude Code Agent Teams | ✅ Đây là cách HQ chạy |
| `.claude/agents/hq-*.md` + `teams/playbook.md` | HQ-team | ✅ Roster + brain |
| `.claude/memory/` | HQ-team store | ✅ Đọc/ghi qua skill `hq-memory` |
| `run.ps1 run/validate/graph/build` | Engine (chi nhánh) | ❌ KHÔNG — trừ khi request **chính là** dựng workflow pipeline |
| `workflow.json` / `build-spec` / `plan-as-data` JSON | Workflow cũ (đã bỏ khỏi HQ) | ❌ Tàn dư — thấy là dừng |
| `company/memory/` + `<project>/memory/` | Engine branch store (do `memory.ps1` quản) | ❌ HQ KHÔNG đụng |

Nếu một teammate bắt đầu xuất JSON plan-as-data hoặc gọi `run.ps1 autobuild` → đó là lậm
workflow cũ → lead chỉnh ngay (ghi issue `FORM`/`BUILD` vào queue).

---

## Roster teammate (`.claude/agents/hq-*.md`)

| Teammate | Vai | Tools | Output |
|---|---|---|---|
| `hq-researcher` | gom context + memory → tóm tắt + câu-hỏi-còn-chặn | Read, Grep, Glob, WebSearch | prose 4 mục |
| `hq-planner` | WHAT — kế hoạch markdown (Goal/Steps/Done-criteria) | Read | prose, KHÔNG JSON |
| `hq-cto` | HOW — thiết kế kỹ thuật văn xuôi (stack/cấu trúc file/cách tiếp cận) | Read | prose 5 mục A–E |
| `hq-builder` | ghi file deliverable TRỰC TIẾP vào `projects/<name>/` | Read, Write, Edit, Bash | file + cách chạy |
| `hq-tester` | chạy check khách quan + ghi memory | Read, Bash | `CHECK_RESULT: pass\|fail` |

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
        │    → cto       → [gate: thiết kế đủ để builder không phải đoán?]
        │    → builder   → [gate: file đã ghi vào projects/<name>/?]
        │    → tester    → CHECK_RESULT: pass|fail
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
| Xây mới multi-file / domain mới | researcher → planner → cto → builder → tester | — |
| Sửa deliverable đã có | builder → tester | researcher/planner/cto |
| Chỉ thiết kế (chưa build) | researcher → planner → cto | builder/tester |
| Yêu cầu rõ ràng, nhỏ, 1 stack | planner → builder → tester | researcher/cto |

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
| Issue queue (hành vi teammate) | `.claude/team-issues-queue.md` |
| Skill build + verify | `.claude/skills/build-verify/SKILL.md` |
| Skill memory | `.claude/skills/hq-memory/SKILL.md` |
| Memory store HQ-team | `.claude/memory/` |
| Spec kiến trúc đầy đủ (lịch sử thiết kế) | `plan/hq-v2/phase-h/design.md` |
