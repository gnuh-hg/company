# HQ-master — orchestration doc (SKELETON, đầy đủ ở H.9)

> Điểm vào "bộ não" lead khi vận hành HQ như **native team** (CD-1, hq-v2). Lead đọc file
> này để biết flow động + trỏ tới roster teammate + playbook. Workflow HQ cũ (`hq/`) đã XÓA
> (Q2 reframe) — HQ build deliverable TRỰC TIẾP. Xem `plan/hq-v2/phase-h/design.md`.
>
> ⚠️ TRẠNG THÁI: skeleton (roster đã cập nhật Q2) — flow + playbook đầy đủ ở H.9.

---

## Flow động (không DAG)

`request → research → plan (WHAT) → cto thiết kế (HOW) → builder build TRỰC TIẾP → tester check khách quan → record memory`

Lead điều phối bằng reasoning + TeamCreate; các gate cũ (coo/rg_gate/clarify_gate/
escalate_gate/record) **tan vào lead**. Teammate giao tiếp **văn xuôi** (KHÔNG JSON/build-spec);
builder **Write/Edit trực tiếp** (KHÔNG engine-build). _Chi tiết flow: design.md §1; đổ đầy ở H.9._

## Roster teammate (`.claude/agents/hq-*.md`)

| Teammate | Vai | Tools | Session đẻ |
|---|---|---|---|
| `hq-researcher` | gom context + memory → tóm tắt + câu-hỏi-còn-chặn (prose) | Read,Grep,Glob,WebSearch | H.2 ✅ |
| `hq-planner` | WHAT — kế hoạch markdown (Goal/Steps/Done-criteria), KHÔNG JSON | Read | H.3 ✅ |
| `hq-cto` | HOW — thiết kế kỹ thuật văn xuôi; catalog/ tùy chọn; KHÔNG build-spec | Read | H.4 |
| `hq-builder` | ghi file deliverable TRỰC TIẾP vào `projects/<name>/` | Read,Write,Edit,Bash | H.5 |
| `hq-tester` | chạy check khách quan của deliverable (test/build/lint) + ghi memory | Read,Bash | H.6 |

## Trỏ tài liệu

- Playbook điều phối: `company/.claude/teams/playbook.md`
- Skill build+verify: `company/.claude/skills/build-verify/SKILL.md` (H.7)
- Skill memory: `company/.claude/skills/hq-memory/SKILL.md` (H.8)
- Memory store HQ-team: `company/.claude/memory/`
- Spec kiến trúc: `plan/hq-v2/phase-h/design.md` (§Revise = reframe Q2)
