---
name: self-modify
description: "Quy ước để HQ-team tự sửa chính nó (agent, skill, engine, docs) an toàn: procedure 5 bước, scope cho-phép/CẤM, regression gate copy-paste, backup/restore git-based, re-spawn smoke, changelog global.md. Dùng chung cho hq-self-builder (edit) và hq-self-tester (gate)."
---

# Self-Modify — HQ self-modification convention

> Quy ước chung cho **hq-self-builder** (Write/Edit scope HQ) và **hq-self-tester** (regression gate).
>
> ⚠️ **Nới bất biến "engine là code cố định" CHỈ áp dụng cho `hq-self-builder` sau gate đầy đủ.**
> `hq-builder` (branch-builder) vẫn TUYỆT ĐỐI cấm đụng `engine/` và `.claude/`.
> Đọc cùng `plan/hq-v2/phase-s/design.md` để nắm đầy đủ ranh giới.

---

## 1. Scope — vùng được ghi và vùng CẤM

### `hq-self-builder` ĐƯỢC GHI

```
.claude/
  agents/hq-*.md              ← system prompt teammate HQ
  skills/*/SKILL.md            ← skill HQ
  teams/playbook.md
  hq-master.md
  settings.json                ← chỉ khi có lý do rõ ràng

company/
  engine/*.ps1                 ← sau regression gate
  catalog/*.md                 ← catalog vai chi nhánh
  README.md
  CLAUDE.md
  app/                         ← app web viewer
  plan/                        ← doc phase
```

### CẤM TUYỆT ĐỐI

```
projects/          ← vùng branch, chỉ hq-builder đụng
company/memory/    ← HQ-global store, chỉ engine ghi
~/Documents/       ← project khác ngoài company/
*/.runs/           ← runtime engine, tự-quản
```

---

## 2. Procedure an toàn 5 bước

Mọi self-mod đều theo đúng thứ tự này — KHÔNG rút ngắn:

### Bước 1 — Baseline (git status sạch vùng đụng)

```bash
cd /home/gnuh/Documents/company
rtk git status
```

Vùng đụng (`.claude/` hoặc `engine/`) phải **không có uncommitted changes** trước khi bắt đầu.
Nếu có → dừng, hỏi user.

### Bước 2 — Edit

`hq-self-builder` Write/Edit các file trong vùng cho phép (mục 1).
Ghi chú danh sách file thay đổi để backup-aware.

### Bước 3 — Backup-aware (git-based, D-S1)

Git tracking IS the backup — không cần stash riêng.
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

Chạy từ `company/engine/`:

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

Nếu bất kỳ bước nào fail → **restore (bước 3)** → báo lead + lý do fail cụ thể.

Với thay đổi `.claude/agents/*.md` → thêm **re-spawn smoke** (mục 3).

### Bước 5 — User-approval diff + commit/restore (D-S2)

```bash
rtk git diff
```

Lead trình `git diff` cho user. **KHÔNG auto-commit.**
- User duyệt → user commit (hoặc nói rõ "ok commit" → HQ commit).
- User từ chối → restore (bước 3).

---

## 3. Re-spawn smoke (khi đụng `.claude/agents/*.md`)

Bài học H.10: agent body chỉ nạp lúc spawn — tự-sửa agent đang chạy KHÔNG có hiệu lực session hiện tại.

Sau khi sửa một agent (ví dụ `hq-self-builder.md`):

```
lead → spawn 1 team nhỏ (TeamCreate + 1 agent = agent đã đổi)
     → giao task đơn giản ("ack + nêu tools của mày")
     → verify: agent ack được + tools: gồm TaskGet/TaskUpdate/TaskList/SendMessage
     → nếu câm hoặc thiếu tools → FAIL → restore (bước 3)
```

**Điều kiện pass:**
- Agent trả lời ack cùng turn.
- `tools:` frontmatter đọc được và có đủ `Task*/SendMessage`.

---

## 4. Bootstrap / Recursion caveat

### Caveat A — Tự-sửa agent đang chạy

Sửa `hq-self-builder.md` hay `hq-self-tester.md` trong session đang chạy → thay đổi KHÔNG có hiệu lực session đó.
→ Quy tắc: edit → gate → **đóng team session** → re-spawn team mới → smoke check ở team mới.

### Caveat B — Sửa `engine/*.ps1` mid-run

Engine `.ps1` dot-source mỗi lần gọi `run.ps1` → sửa giữa chừng khi đang chạy pipeline = rủi ro crash.
→ Quy tắc: self-mod engine **chỉ làm ngoài run-window** (không có pipeline chạy song song).

### Caveat C — Đệ quy tự-tiến-hoá

HQ chỉ tự sửa theo yêu cầu tường minh của user, gate mỗi lần. Không tự đề xuất + áp self-mod vòng lặp liên tục.

---

## 5. Changelog `global.md`

Sau mỗi self-mod thành công (gate xanh + user duyệt), append 1 entry vào `.claude/memory/global.md`:

```markdown
## <YYYY-MM-DD HH:MM> — self-mod/<slug-ngắn>

**What**: <1-2 dòng: files thay đổi và tính chất thay đổi>
**Why**: <lý do / yêu cầu user>
**Files**: `<file1>`, `<file2>`, ...
**Gate result**: selftest PASS • validate hello exit 0 • run -Mock done [• re-spawn smoke PASS nếu đụng agents]
**Commit**: <hash nếu đã commit, "pending" nếu chờ user>
```

Delimiter `## <YYYY-MM-DD HH:MM> — <slug>` là chuẩn `global.md` — giữ đúng format.

---

## 6. Anti-patterns

### `hq-self-builder` anti-patterns
- Đụng vùng CẤM: `projects/`, `company/memory/`, ngoài `company/`.
- Chạy chung session với branch-build (vi phạm D-S4 mode-separation).
- Sửa agent/engine đang chạy mid-session mà không theo thứ tự caveat.
- Báo tester khi gate chưa xanh.
- Auto-commit (vi phạm D-S2).
- Dùng `git stash` thay vì `git checkout --`.

### `hq-self-tester` anti-patterns
- Phán cảm tính không chạy lệnh engine.
- Quên re-spawn smoke khi đụng `.claude/agents/*.md`.
- Sửa file (tester read+run only).
- Coi gate xanh là "done" mà bỏ user-approval (gate ≠ approval — lead trình diff cho user).

---

## 7. Quick reference

```
SELF-BUILDER (edit HQ):
  → Bước 1 : cd company && rtk git status  (vùng đụng sạch)
  → Bước 2 : Write/Edit file trong scope cho phép
  → Bước 3 : ghi chú file đổi (git tracking = backup)
  → Bước 4 : cd company/engine
             pwsh ./run.ps1 selftest        # 9/9 PASS
             pwsh ./run.ps1 validate hello  # exit 0
             pwsh ./run.ps1 run hello "x" -Mock  # done
             rm -rf ../examples/hello/.runs/
             [nếu đụng agents] → re-spawn smoke
  → Bước 5 : rtk git diff → lead trình user → chờ duyệt

SELF-TESTER (gate):
  → Chạy đúng 3 lệnh selftest / validate / run -Mock → in exit-code
  → Nếu đụng .claude/agents → spawn team nhỏ smoke check
  → In SELF_CHECK_RESULT: pass|fail (bảng tiêu chí + evidence)
  → Ghi .claude/memory/ + chuẩn bị dòng changelog global.md
  → Báo lead (KHÔNG commit)
```
