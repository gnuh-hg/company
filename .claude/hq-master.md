# HQ-master — orchestration doc

> Điểm vào "bộ não" lead khi vận hành HQ như **native team** (CD-1, hq-v2). Đọc file này +
> `playbook.md` trước khi spawn team. Workflow HQ cũ (`hq/`) đã **XÓA** (Q2 reframe 2026-06-02).
> Spec đầy đủ: `plan/hq-v2/phase-h/design.md`.

---

## Flow động (không DAG)

```
LEAD nhận user_request
  └─► phân loại (đơn giản hay cần team?)
        ├── đơn giản / 1 tool call → LEAD tự xử
        └── phức tạp / multi-file / domain mới
              └─► TeamCreate [...teammates]
                    │
                    ├─► researcher: gom context + memory → tóm tắt + câu-hỏi-còn-chặn
                    │     [LEAD xét: còn chặn → hỏi user; đủ rõ → tiếp]
                    │
                    ├─► planner: WHAT — plan markdown (Goal / Steps / Done-criteria)
                    │
                    ├─► cto: HOW — thiết kế kỹ thuật văn xuôi
                    │
                    ├─► builder: Write/Edit deliverable TRỰC TIẾP → projects/<name>/
                    │     [KHÔNG engine-build; KHÔNG workflow.json]
                    │
                    ├─► tester: check khách quan của deliverable (test/build/lint)
                    │     → CHECK_RESULT: pass|fail
                    │     [pass] → ghi memory + báo LEAD
                    │     [fail] → báo LEAD kèm lý do cụ thể
                    │
                    ├─► LEAD xét verdict:
                    │     [pass] → record memory (hq-memory skill) + shutdown + báo user
                    │     [fail ≤2 vòng] → builder re-fix hoặc planner re-plan
                    │     [fail >2 vòng] → shutdown + escalate user
                    │
                    └─► LEAD shutdown team
```

**Gate cũ tan vào lead reasoning:**

| Gate cũ | Thay bằng |
|---|---|
| `coo` (router build/fix/unclear) | Lead phân loại bằng reasoning |
| `rg_gate` (đủ research chưa) | Lead xét câu-hỏi-còn-chặn của researcher |
| `clarify_gate` (hỏi user) | Lead hỏi user trực tiếp |
| `escalate_gate` / `escalate_report` | Lead quyết sau N vòng fail |
| `record` (node ghi memory) | Lead gọi skill `hq-memory` sau verify done |

---

## Roster teammate (`.claude/agents/hq-*.md`)

| Teammate | Vai | Tools |
|---|---|---|
| `hq-researcher` | gom context + memory → tóm tắt + câu-hỏi-còn-chặn (prose) | Read, Grep, Glob, WebSearch |
| `hq-planner` | WHAT — kế hoạch markdown (Goal/Steps/Done-criteria), KHÔNG JSON | Read |
| `hq-cto` | HOW — thiết kế kỹ thuật văn xuôi; catalog/ tùy chọn; KHÔNG build-spec | Read |
| `hq-builder` | ghi file deliverable TRỰC TIẾP vào `projects/<name>/` | Read, Write, Edit, Bash |
| `hq-tester` | chạy check khách quan của deliverable + ghi memory | Read, Bash |

---

## Trỏ tài liệu

| Tài liệu | Đường dẫn |
|---|---|
| Playbook điều phối (6 mục) | `company/.claude/teams/playbook.md` |
| Issue queue | `company/.claude/team-issues-queue.md` |
| Skill build+verify | `company/.claude/skills/build-verify/SKILL.md` |
| Skill memory | `company/.claude/skills/hq-memory/SKILL.md` |
| Memory store HQ-team | `company/.claude/memory/` |
| Spec kiến trúc đầy đủ | `plan/hq-v2/phase-h/design.md` |
