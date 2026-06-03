# PLAN — Phase S: HQ self-modification (+ branch-edit hạng nhất)

> Sau Phase S, HQ-team có **3 vai**: (1) build chi nhánh — đã có; (2) **chỉnh sửa chi nhánh** đã có như loại request hạng nhất; (3) **tự sửa & build chính nó** (scope full kể cả `engine/*.ps1`) qua một luồng có **regression gate + user-approval diff + backup/restore**.

---

## Context

### Vì sao chia nhiều session
- Vai #3 **phá vỡ bất biến cốt lõi** của `company/CLAUDE.md` ("engine là code cố định"; "builder chỉ ghi `projects/<branch>/`"). Phải nới bất biến **có kiểm soát** — thiết kế ranh giới an toàn trước khi đẻ agent, nếu không sẽ brick chính team.
- Cách verify self-mod **khác hẳn** branch-build: không phải `run.ps1 validate <branch>` mà là **regression gate** (`selftest` + `validate hello` + `run -Mock`) + (với thay đổi `.claude/`) **re-spawn smoke** — vì agent body chỉ nạp lúc spawn (thay đổi có hiệu lực ở team session KẾ, không phải session đang chạy).
- Đụng nhiều file não HQ: 2 agent mới + 1 skill + `hq-master.md` + `playbook.md` + `CLAUDE.md` + ROADMAP. Mỗi session = 1 artifact chất lượng (đúng nhịp CD-1).
- Kết bằng **real-run gate đốt token** (USER-GATE) — phải tách session riêng.

### Quyết định đã chốt (user, 2026-06-03)
- **Scope tự-sửa**: TẤT CẢ, kể cả `engine/*.ps1`.
- **Cổng an toàn**: regression gate (auto) **+ user duyệt diff** trước khi thay đổi được coi là "done".
- **Độ sâu**: không chỉ 1 agent/skill — long-plan đầy đủ (user yêu cầu).

### Default tự chốt (override được — ghi vào Revision log nếu đổi)
- **D-S1. Backup = git-based.** File `.claude/` + `engine/` đều tracked → backup mặc nhiên là git. Gate FAIL → `git checkout -- <changed>` (file tracked) + `rm` (file mới chưa track) để khôi phục. KHÔNG dùng `git stash` (đụng cả tree).
- **D-S2. KHÔNG auto-commit.** Luồng self-mod: edit → gate → trình `git diff` cho user → user duyệt → **user commit** (hoặc HQ commit khi user nói rõ "ok commit"). "Done" = diff đã duyệt + gate xanh + working tree mang thay đổi.
- **D-S3. Reuse researcher/planner/cto** cho self-mod (chúng prose+Read, không rủi ro write-scope) với brief self-mod-context. Chỉ đẻ **2 agent mới có write/verify khác biệt**: `hq-self-builder` (write scope `.claude/`+`company/` incl engine; backup+gate) và `hq-self-tester` (gate = regression + re-spawn smoke). **1 skill mới**: `self-modify`.
- **D-S4. Mode separation.** `hq-self-builder` KHÔNG chạy chung session với branch-build; branch `hq-builder` vẫn TUYỆT ĐỐI không đụng `engine/`/`.claude/`. Nới bất biến áp DUY NHẤT cho `hq-self-builder` sau gate.

### Out of scope
- Tự-sửa tự-động hoàn toàn (không user gate) — bị loại bởi quyết định cổng.
- Tự-sửa các project khác ngoài `company/` (quy ước 6: chỉ `company/`).
- Vòng tự-tiến-hoá đệ quy (HQ tự nghĩ ra cải tiến rồi tự áp liên tục) — phase này chỉ làm **HQ sửa-mình-theo-yêu-cầu-user**, có gate mỗi lần.

---

## Pipeline 3 sub-phase / 7 session

```
[S.A Design + branch-edit]
   S.0 design.md (khoá ranh giới an toàn) ──────────► design.md
   S.1 branch-edit #2 hạng nhất (doc-only) ─────────► hq-master + playbook (loại request mới)
                                                          │
[S.B Build self-mod machinery #3]                         │
   S.2 skill self-modify ───────────────────────────► .claude/skills/self-modify/SKILL.md
   S.3 agent hq-self-builder ────────────────────────► .claude/agents/hq-self-builder.md
   S.4 agent hq-self-tester ─────────────────────────► .claude/agents/hq-self-tester.md
   S.5 orchestration wiring ─────────────────────────► hq-master + playbook + CLAUDE.md (+2 agent,+1 skill)
                                                          │
[S.C Prove it]                                            │
   S.6 real-run gate (USER-GATE, đốt token) ─────────► 1 self-mod commit qua luồng đầy đủ
```

---

## Sub-phase S.A — Design + branch-edit hạng nhất

**Mục tiêu**: khoá thiết kế ranh giới an toàn cho #3 + đưa #2 thành loại request hạng nhất (light, doc-only).

### Session S.0 — Design doc (KHÓA trước khi đẻ agent)
- **Scope**: viết `plan/hq-v2/phase-s/design.md` chốt:
  1. **Mô hình 3 vai** + bảng phân biệt branch-build / branch-edit / self-mod (ai làm, write-scope, verify thế nào).
  2. **Ranh giới scope self-mod**: liệt tường minh vùng `hq-self-builder` được ghi (`.claude/agents`, `.claude/skills`, `.claude/teams/playbook.md`, `.claude/hq-master.md`, `.claude/settings.json`, `engine/*.ps1`, `catalog/`, `README.md`, `company/CLAUDE.md`, `app/`) + vùng CẤM tuyệt đối (`projects/`, `company/memory/` engine store, project khác ngoài `company/`).
  3. **Procedure an toàn 5 bước** (chuẩn để skill + agent bám theo): `baseline (git status sạch vùng đụng) → edit → backup-aware → regression gate → user-approval diff → commit/restore`.
  4. **Regression gate cụ thể**: `cd company/engine; pwsh ./run.ps1 selftest` PASS + `validate hello` exit 0 + `run hello "x" -Mock` done. Với thay đổi `.claude/agents/*.md`: thêm **re-spawn smoke** (spawn lại agent đã đổi trong 1 team nhỏ → ack được + `tools:` còn Task*/SendMessage — bài học H.10).
  5. **Bootstrap/recursion caveat**: agent body nạp lúc spawn → tự-sửa `hq-self-builder.md`/`hq-self-tester.md` đang chạy KHÔNG có hiệu lực session hiện tại; sửa `engine/*.ps1` đang dùng có thể gãy mid-run → quy tắc thứ tự (edit → gate ở session SẠCH / re-spawn).
  6. **Changelog self-mod**: append vào `.claude/memory/global.md` (quyết định kiến trúc) — what/why/files/gate-result.
  7. Chốt 4 default D-S1..D-S4 (hoặc user override).
- **STOP gate**: `design.md` tồn tại, có đủ 7 mục trên; bảng 3-vai phân biệt rõ write-scope + verify; procedure 5 bước + regression gate ghi **đúng lệnh** từ `company/CLAUDE.md`.
- **Output artifact**: `plan/hq-v2/phase-s/design.md`.

### Session S.1 — Branch-edit #2 hạng nhất (doc-only)
- **Scope**: nâng "chỉnh sửa chi nhánh đã có" từ chỗ ẩn (re-fix loop) thành **loại request hạng nhất**:
  - `hq-master.md`: thêm vào sơ đồ phân loại + bảng "Rút gọn chain theo loại task" một dòng rõ "Sửa chi nhánh đã có **theo yêu cầu user mới**" (≠ re-fix từ verdict) → chain `planner(light)/builder/tester`.
  - `playbook.md` §1: thêm dòng bảng "Khi nào lập team" + per-role brief note: builder **đọc file `projects/<branch>/` hiện có trước**, Edit phẫu thuật, KHÔNG ghi đè.
  - KHÔNG đẻ agent mới (builder/tester hiện đã đủ — chỉ làm rõ).
- **STOP gate**: `hq-master.md` + `playbook.md` thể hiện branch-edit là loại request hạng nhất (phân biệt với re-fix); `grep -n "Sửa chi nhánh" .claude/hq-master.md .claude/teams/playbook.md` ra kết quả; regression `selftest` PASS (session này không đụng engine nên đương nhiên xanh — chạy để chắc).
- **Output artifact**: `hq-master.md` + `playbook.md` (diff branch-edit).

**S.A gate**: `design.md` khoá xong (ranh giới + procedure + gate rõ) **và** #2 hạng nhất trong doc. Mới sang S.B.

---

## Sub-phase S.B — Build self-mod machinery (#3)

**Mục tiêu**: đẻ skill + 2 agent + wiring để HQ tự-sửa-mình an toàn. Mỗi session 1 artifact.

### Session S.2 — Skill `self-modify`
- **Scope**: `.claude/skills/self-modify/SKILL.md` — quy ước CHUNG cho `hq-self-builder` + `hq-self-tester` (giống `build-verify` cho branch). Gồm:
  - Procedure 5 bước (từ design.md S.0) viết thành lệnh cụ thể.
  - Bảng scope cho-phép / CẤM (từ design.md).
  - Lệnh regression gate copy-paste-được + re-spawn smoke checklist.
  - Backup/restore git-based (D-S1): trước edit `git status` vùng đụng; gate FAIL → `git checkout -- <file>` / `rm` file mới.
  - Bootstrap/recursion caveat (D-S3 thứ tự).
  - Format changelog `.claude/memory/global.md`.
- **STOP gate**: `SKILL.md` tồn tại + frontmatter `name`/`description` hợp lệ; chứa đủ procedure + scope-table + gate-commands + restore + caveat; lệnh gate **khớp chính xác** `company/CLAUDE.md` regression. Liệt kê trong "available skills" (Skill tool đọc được).
- **Output artifact**: `.claude/skills/self-modify/SKILL.md`.

### Session S.3 — Agent `hq-self-builder`
- **Scope**: `.claude/agents/hq-self-builder.md` — system prompt + frontmatter. Đặc tả:
  - Mission: nhận thiết kế self-mod (từ planner/cto + lead) → Write/Edit các file HQ trong scope cho-phép → chạy backup-aware edit + smoke regression gate → báo self-tester.
  - `tools:` BẮT BUỘC gồm `Read, Write, Edit, Bash, TaskGet, TaskUpdate, TaskList, SendMessage` (bài học H.10: thiếu Task*/SendMessage → câm).
  - "Đọc đầu phiên" gồm skill `self-modify` + `.claude/memory/*`.
  - Anti-patterns nhấn: (a) đụng vùng CẤM (`projects/`, `company/memory/`, ngoài `company/`); (b) chạy chung session branch-build; (c) tự-sửa file agent/engine đang dùng mid-run mà không theo thứ tự caveat; (d) báo tester khi regression chưa xanh; (e) auto-commit (vi phạm D-S2).
  - "Trong TeamCreate mode" block (ack+TaskGet+in_progress cùng turn; xong→TaskUpdate completed→SendMessage paste-full).
- **STOP gate**: file frontmatter valid (`name: hq-self-builder`, `tools:` đủ Task*/SendMessage); thân nêu đủ scope cho-phép/CẤM + procedure + gate + anti-patterns + TeamCreate block; xuất hiện trong danh sách agent (`/agents` hoặc spawn thử ack). Regression `selftest` PASS.
- **Output artifact**: `.claude/agents/hq-self-builder.md`.

### Session S.4 — Agent `hq-self-tester`
- **Scope**: `.claude/agents/hq-self-tester.md` — verify self-mod bằng **regression gate khách quan**:
  - Chạy `selftest` + `validate hello` + `run hello -Mock`, đọc exit-code.
  - Với thay đổi `.claude/agents/*.md`: **re-spawn smoke** (spawn agent đã đổi trong team con → ack + `tools:` còn Task*/SendMessage).
  - In `SELF_CHECK_RESULT: pass|fail` (máy đọc) + bảng tiêu chí|evidence.
  - Ghi `.claude/memory/` (mistakes/patterns/context) + chuẩn bị dòng changelog `global.md`.
  - `tools:` `Read, Bash, TaskGet, TaskUpdate, TaskList, SendMessage` (+ tối thiểu để re-spawn smoke nếu cần — cân nhắc Agent/TeamCreate; nếu không cấp, lead làm re-spawn smoke thay).
  - Anti-patterns: phán cảm tính; quên re-spawn smoke khi đụng `.claude/agents`; sửa file (tester read+run only); coi gate xanh là "done" mà bỏ user-approval (gate ≠ approval — lead trình diff cho user).
- **STOP gate**: file frontmatter valid; gate = đúng lệnh regression + re-spawn smoke; in `SELF_CHECK_RESULT`; anti-patterns đủ. Regression `selftest` PASS.
- **Output artifact**: `.claude/agents/hq-self-tester.md`.

### Session S.5 — Orchestration wiring
- **Scope**: nối 2 agent + skill vào não HQ:
  - `hq-master.md`: thêm loại request "**tự sửa HQ**" vào sơ đồ phân loại + bảng chain (`researcher?/planner/cto?/self-builder/self-tester` + **user-approval gate** trước "done"); roster +2 agent; **bảng ranh giới**: ghi rõ nới bất biến "engine cố định" CHỈ cho `hq-self-builder` sau gate, branch-builder vẫn cấm.
  - `playbook.md`: §1 phân loại +1 dòng; §3 per-role brief cho self-builder/self-tester; §7 PASS criteria 2 vai mới; §8 anti-patterns (mode-separation, recursion, auto-commit); §10 build-contract self-mod block; §11 changelog `global.md`.
  - `company/CLAUDE.md`: bảng "Bản đồ file" +3 hàng (2 agent + 1 skill) + cập nhật ghi chú quy ước (nới bất biến #1/#6 có kiểm soát cho self-mod); `plan/hq-v2/phase-s/` hàng mới.
- **STOP gate**: `grep -rn "hq-self-builder\|hq-self-tester\|self-modify" .claude/ company/CLAUDE.md` nhất quán (không dangling); bảng ranh giới nêu rõ nới-bất-biến-có-kiểm-soát; regression `selftest` PASS. Spawn thử team có 2 agent mới → cả hai ack.
- **Output artifact**: `hq-master.md` + `playbook.md` + `CLAUDE.md` (wiring).

**S.B gate**: skill + 2 agent tồn tại + wiring nhất quán + cả 2 agent ack khi spawn + regression xanh. Mới sang S.C.

---

## Sub-phase S.C — Prove it (real run)

**Mục tiêu**: chứng minh HQ **tự sửa được chính mình** end-to-end qua luồng có gate, trên một thay đổi nhỏ-an-toàn-đảo-được.

### Session S.6 — Real-run gate (⚠️ USER-GATE, ĐỐT TOKEN)
- **Scope**: lead lập team self-mod thật, thực hiện 1 self-mod **benign + reversible** chạm **cả 2 path** để chứng minh đủ:
  - 1 file `.claude/` (vd thêm 1 anti-pattern dòng vào skill `build-verify`, hoặc siết 1 câu trong 1 agent) → exercise **re-spawn smoke**.
  - 1 thay đổi trivial trong `engine/*.ps1` (vd thêm 1 comment vô hại) → exercise **engine regression gate**.
  - Luồng đầy đủ: researcher?/planner thiết kế → `hq-self-builder` edit + backup-aware → `hq-self-tester` regression gate + re-spawn smoke → in `SELF_CHECK_RESULT: pass` → **lead trình `git diff` cho user** → user duyệt → commit (D-S2) → changelog `global.md`.
  - Thử **1 ca FAIL có chủ đích** (vd builder cố sửa `engine` gây selftest fail) → tester bắt fail → `git checkout` khôi phục → chứng minh restore hoạt động. (Có thể mock/nhỏ để đỡ token.)
- **STOP gate**:
  1. Một self-mod thật **đã commit** qua luồng (diff user-duyệt).
  2. `pwsh ./run.ps1 selftest` PASS sau thay đổi + `validate hello` exit 0 + `run hello -Mock` done.
  3. Thay đổi `.claude/` được re-spawn pick-up (agent đổi ack đúng).
  4. Ca FAIL chủ đích → restore về sạch (`git status` không còn rác).
  5. 1 entry changelog trong `.claude/memory/global.md`.
- **Output artifact**: 1 commit self-mod + CHECKPOINT cập nhật + changelog entry.

**S.C gate (= Outcome)**: đủ 5 tiêu chí S.6.

---

## Outcome cuối

- HQ-team có 3 vai vận hành: build chi nhánh / sửa chi nhánh (hạng nhất) / **tự sửa-build chính nó** qua luồng `hq-self-builder` + `hq-self-tester` + skill `self-modify`, gác bởi regression gate + user-approval diff + git restore.
- Bất biến "engine cố định" được nới **có kiểm soát** (chỉ self-builder, chỉ sau gate); branch-builder vẫn cấm — ranh giới ghi rõ ở `CLAUDE.md` + `hq-master.md`.
- Chứng minh bằng 1 real-run self-mod đã commit + 1 ca restore.
- **Gate đo thành công**: real-run S.6 đạt 5/5 tiêu chí.

---

## Rủi ro & guard

| Rủi ro | Guard |
|---|---|
| Self-mod brick engine → mọi verify gãy | regression gate trước commit; git restore khi fail (D-S1) |
| Sửa frontmatter `tools:` sai → teammate câm (H.10) | re-spawn smoke trong gate self-tester |
| Branch-builder tưởng mình cũng được sửa engine | bảng ranh giới CLAUDE.md/hq-master: nới CHỈ cho self-builder; mode-separation D-S4 |
| Tự-sửa agent/engine đang chạy mid-session vô hiệu/gãy | bootstrap caveat + thứ tự edit→gate→re-spawn (design.md S.0 mục 5) |
| HQ tự đổi não mà user không thấy | D-S2 không auto-commit + user-approval diff bắt buộc |
| Đệ quy tự-tiến-hoá vô hạn | out-of-scope: chỉ sửa-theo-yêu-cầu, gate mỗi lần |

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-06-03 | Initial | User thêm vai #2 (branch-edit hạng nhất) + #3 (self-mod full-scope, gate+approval) |
