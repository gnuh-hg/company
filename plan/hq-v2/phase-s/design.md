# Design — Phase S: HQ Self-Modification Safety Boundary

> File này KHOÁ ranh giới an toàn trước khi sinh agent. Mọi artifact S.B/S.C bám theo đây.
> Đọc cùng `PLAN.md` §Default (D-S1..D-S4).

---

## 1. Mô hình 3 vai HQ

HQ-team vận hành 3 loại task — **khác nhau về write-scope và cách verify**:

| Loại task | Mô tả | Write-scope | Verify |
|---|---|---|---|
| **#1 Build chi nhánh** | Dựng `projects/<branch>/` mới từ `catalog/` + thiết kế CTO | `projects/<branch>/workflow.json` + `projects/<branch>/agents/*.md` + scaffold | `run.ps1 validate <branch>` exit 0 + `run -Mock` done + output_keys non-empty |
| **#2 Sửa chi nhánh** | Chỉnh sửa chi nhánh đã có theo yêu cầu user mới (≠ re-fix từ verdict) | `projects/<branch>/` đã có — đọc trước, Edit phẫu thuật, KHÔNG ghi đè toàn bộ | Giống #1: `validate <branch>` + `run -Mock` done |
| **#3 Tự sửa HQ** | Tự sửa-build chính HQ-team (agent, skill, engine, docs) theo yêu cầu user | `.claude/agents/`, `.claude/skills/`, `.claude/teams/`, `.claude/hq-master.md`, `engine/*.ps1`, `catalog/`, `README.md`, `company/CLAUDE.md`, `app/` | Regression gate toàn bộ (`selftest` + `validate hello` + `run -Mock`) **+ re-spawn smoke** nếu đụng `.claude/agents/*.md` + **user-approval diff** |

**Ranh giới cứng không vượt**:
- Branch-builder (`hq-builder`) TUYỆT ĐỐI không đụng `engine/` hay `.claude/`.
- Self-builder (`hq-self-builder`) TUYỆT ĐỐI không đụng `projects/` (vùng branch).
- Nới bất biến "engine là code cố định" ÁP DỤNG DUY NHẤT cho `hq-self-builder` sau gate đầy đủ.

---

## 2. Ranh giới scope self-mod

### Vùng `hq-self-builder` ĐƯỢC GHI

```
.claude/
  agents/hq-*.md          ← system prompt teammate HQ
  agents/hq-self-builder.md
  agents/hq-self-tester.md
  skills/*/SKILL.md        ← skill HQ
  teams/playbook.md
  hq-master.md
  settings.json            ← chỉ khi có lý do rõ ràng

company/
  engine/*.ps1             ← sau regression gate
  catalog/*.md             ← catalog vai chi nhánh
  README.md
  CLAUDE.md
  app/                     ← app web viewer
  plan/                    ← doc phase
```

### Vùng CẤM TUYỆT ĐỐI

```
projects/          ← vùng branch, chỉ hq-builder đụng
company/memory/    ← HQ-global store, chỉ engine ghi
~/Documents/       ← project khác ngoài company/
*/.runs/           ← runtime engine, tự-quản
```

---

## 3. Procedure an toàn 5 bước

Mọi self-mod đều theo đúng thứ tự này — KHÔNG rút ngắn:

### Bước 1 — Baseline (git status sạch vùng đụng)

```bash
cd /home/gnuh/Documents/company
rtk git status
```

Vùng đụng (`.claude/` hoặc `engine/`) phải **không có uncommitted changes** trước khi bắt đầu.
Nếu có → dừng, hỏi user.

### Bước 2 — Edit

`hq-self-builder` Write/Edit các file trong vùng cho phép (mục 2).
Ghi chú file thay đổi để backup-aware.

### Bước 3 — Backup-aware

Git-based (D-S1): không cần stash — git tracking IS the backup.
Nếu gate fail (bước 4), restore:
```bash
# File đã tracked → revert
git checkout -- .claude/agents/hq-foo.md
git checkout -- engine/validate.ps1

# File mới chưa track → xóa
rm .claude/agents/hq-new-agent.md
```
KHÔNG dùng `git stash` (ảnh hưởng toàn tree).

### Bước 4 — Regression gate

```bash
cd /home/gnuh/Documents/company/engine
pwsh ./run.ps1 selftest
# → phải PASS (exit 0, 9/9 items)

pwsh ./run.ps1 validate hello
# → exit 0

pwsh ./run.ps1 run hello "x" -Mock
# → terminal done

# Dọn sau verify
rm -rf ../examples/hello/.runs/
```

Nếu bất kỳ bước nào fail → **restore (bước 3)** → báo lead + lý do fail.

Với thay đổi `.claude/agents/*.md` → thêm **re-spawn smoke** (mục 4.b).

### Bước 5 — User-approval diff + commit/restore

```bash
rtk git diff
```

Lead trình `git diff` cho user. **KHÔNG auto-commit** (D-S2).
- User duyệt → user commit (hoặc nói rõ "ok commit" → HQ commit).
- User từ chối → restore (bước 3) → discard.

---

## 4. Regression gate cụ thể

### 4.a Gate tiêu chuẩn (mọi self-mod)

```bash
cd /home/gnuh/Documents/company/engine

pwsh ./run.ps1 selftest      # exit 0, 9/9 PASS
pwsh ./run.ps1 validate hello # exit 0
pwsh ./run.ps1 run hello "x" -Mock  # done

rm -rf ../examples/hello/.runs/
```

Lệnh này chính xác theo `company/CLAUDE.md` §Khi sửa code engine.

### 4.b Re-spawn smoke (khi đụng `.claude/agents/*.md`)

Bài học H.10: agent body chỉ nạp lúc spawn — tự-sửa agent đang chạy không có hiệu lực session hiện tại.

Smoke check sau khi sửa một agent (ví dụ `hq-self-builder.md`):

```
lead → spawn 1 team nhỏ (TeamCreate + 1 agent = agent đã đổi)
     → giao task đơn giản ("ack + nêu tools của mày")
     → verify: agent ack được + tools: gồm TaskGet/TaskUpdate/TaskList/SendMessage
     → nếu câm hoặc thiếu tools → FAIL → restore
```

Điều kiện pass:
- Agent trả lời ack cùng turn.
- `tools:` frontmatter đọc được và có đủ `Task*/SendMessage`.

---

## 5. Bootstrap / Recursion caveat

### Caveat A — Tự-sửa agent đang chạy

Sửa `hq-self-builder.md` hay `hq-self-tester.md` **trong session đang chạy** → thay đổi KHÔNG có hiệu lực cho session đó.
→ Quy tắc: edit → gate → **đóng team session** → re-spawn team mới → smoke check ở team mới.

### Caveat B — Sửa `engine/*.ps1` mid-run

Engine `.ps1` được dot-source mỗi lần gọi `run.ps1` → sửa giữa chừng khi đang chạy pipeline = rủi ro crash mid-run.
→ Quy tắc: self-mod engine **chỉ làm ngoài run-window** (không có pipeline đang chạy song song).

### Caveat C — Đệ quy tự-tiến-hoá

HQ chỉ tự sửa **theo yêu cầu tường minh của user**, gate mỗi lần. Không tự đề xuất + áp self-mod vòng lặp liên tục. Out-of-scope (PLAN.md §Out of scope).

---

## 6. Changelog self-mod

Mỗi lần self-mod thành công (gate xanh + user duyệt), append 1 entry vào `.claude/memory/global.md`:

```markdown
## <YYYY-MM-DD HH:MM> — self-mod/<slug-ngắn>

**What**: <1-2 dòng: files thay đổi và tính chất thay đổi>
**Why**: <lý do / yêu cầu user>
**Files**: `<file1>`, `<file2>`, ...
**Gate result**: selftest PASS • validate hello exit 0 • run -Mock done [• re-spawn smoke PASS nếu đụng agents]
**Commit**: <hash nếu đã commit, "pending" nếu chờ user>
```

Format này dùng delimiter chuẩn `## <datetime> — <slug>` như các entry khác trong `global.md`.

---

## 7. Default D-S1..D-S4 (chốt)

| Default | Nội dung | Override |
|---|---|---|
| **D-S1** | Backup = git-based. Gate FAIL → `git checkout --` (tracked) + `rm` (untracked). KHÔNG `git stash`. | Cần lý do mạnh |
| **D-S2** | KHÔNG auto-commit. Lead trình diff → user duyệt → user commit (hoặc nói rõ "ok commit"). "Done" = diff duyệt + gate xanh. | User có thể nói "ok commit" |
| **D-S3** | Reuse researcher/planner/cto cho phase phân tích (prose, Read-only). Chỉ 2 agent mới: `hq-self-builder` (Write/Edit scope HQ) + `hq-self-tester` (Bash gate, read-only). 1 skill: `self-modify`. | — |
| **D-S4** | Mode separation: `hq-self-builder` KHÔNG chạy chung session với branch-build. `hq-builder` vẫn CẤM đụng `engine/`/`.claude/`. Nới bất biến CHỈ cho self-builder sau gate. | — |

---

*Tạo: 2026-06-03 — Session S.0*
