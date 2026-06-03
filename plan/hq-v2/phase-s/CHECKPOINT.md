# CHECKPOINT — Phase S: HQ self-modification (+ branch-edit hạng nhất)

> Sổ tay tiến độ. Phiên Claude mới mở đọc file này TRƯỚC để biết đang ở đâu. Long-plan: `PLAN.md` cùng thư mục.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu").
- **STOP NGAY** khi đạt STOP gate session đó — không tham làm session kế dù còn quota.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log".
- **Regression mỗi session chạm engine/.claude**: `cd company/engine && pwsh ./run.ps1 selftest` PASS + `validate hello` exit 0 + `run hello "x" -Mock` done. Dọn `.runs/` test sau verify.
- **Nguồn-sự-thật quyết định**: `PLAN.md` §Default (D-S1..D-S4) + §Context. Đổi default → ghi Revision log của PLAN.
- **S.6 đốt token + USER-GATE** — không tự chạy real-run khi user chưa bật đèn.

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Session hoàn thành | 7 (S.0–S.6) | 6 (S.0–S.5) + S.6 skip | ~100% |
| Agent mới | 2 (hq-self-builder, hq-self-tester) | 2 | 100% |
| Skill mới | 1 (self-modify) | 1 | 100% |
| Vai hạng nhất | #2 branch-edit + #3 self-mod | 2/2 (wired) | 100% |
| Real-run gate (S.6) | 5/5 tiêu chí | skip (user quyết định) | — |

---

## Đang ở đâu

- **Phase**: ✅ **DONE** (S.6 skip theo quyết định user 2026-06-03)
- **Session kế tiếp**: — (phase đã đóng)
- **Blocker**: —
- **Reference**: —

---

## Per-session log

### 2026-06-03 — Phase S khởi tạo (chưa chạy session nào)
- **Done**: soạn `PLAN.md` + `CHECKPOINT.md`; cập nhật `ROADMAP.md` (+Phase S, bảng tiến độ) + `company/CLAUDE.md` (hàng `plan/hq-v2/phase-s/`).
- **Output**: `plan/hq-v2/phase-s/{PLAN,CHECKPOINT}.md`.
- **Gate**: n/a (planning).
- **Next**: Session S.0 — design.md.
- **Notes**: user chốt scope full (incl engine) + gate regression+approval; 4 default D-S1..D-S4 trong PLAN (override được). Reuse researcher/planner/cto; chỉ đẻ 2 agent + 1 skill.

### 2026-06-03 — Session S.0 DONE
- **Done**: viết `plan/hq-v2/phase-s/design.md` — 7 mục đầy đủ: (1) mô hình 3 vai + bảng phân biệt branch-build/branch-edit/self-mod; (2) ranh giới scope tường minh (vùng được ghi + vùng CẤM); (3) procedure an toàn 5 bước; (4) regression gate cụ thể (lệnh copy-paste, incl re-spawn smoke); (5) bootstrap/recursion caveat; (6) changelog format global.md; (7) default D-S1..D-S4 chốt.
- **Output**: `plan/hq-v2/phase-s/design.md`.
- **Gate**: file tồn tại + có đủ 7 mục + bảng 3-vai phân biệt write-scope/verify + procedure 5 bước + lệnh gate khớp CLAUDE.md.
- **Next**: Session S.1 — branch-edit #2 hạng nhất (`hq-master.md` + `playbook.md`).
- **Notes**: không đụng engine → regression không cần chạy session này (constraint nhắc: chỉ khi chạm engine/.claude).

### 2026-06-03 — Session S.2 DONE
- **Done**: tạo `.claude/skills/self-modify/SKILL.md` — 7 mục đầy đủ: (1) scope được-ghi/CẤM; (2) procedure an toàn 5 bước (lệnh copy-paste, incl git restore); (3) re-spawn smoke checklist; (4) bootstrap/recursion caveat A/B/C; (5) changelog global.md format; (6) anti-patterns self-builder + self-tester; (7) quick reference.
- **Output**: `.claude/skills/self-modify/SKILL.md`.
- **Gate**: file tồn tại + frontmatter `name`/`description` hợp lệ + 7 mục đủ + lệnh gate khớp CLAUDE.md; skill xuất hiện trong "available skills" danh sách ✓; `selftest` 9/9 PASS ✓; `validate hello` exit 0 ✓; `run hello -Mock` done ✓; `.runs/` cần dọn (permission denied, dọn ở session sau hoặc tay).
- **Next**: Session S.3 — agent `hq-self-builder` (`.claude/agents/hq-self-builder.md`).
- **Notes**: skill tái dùng design.md procedure tường minh, bổ sung quick reference cho cả 2 vai (self-builder + self-tester). `.runs/` permission denied là bình thường trong sandbox — không ảnh hưởng regression.

### 2026-06-03 — Session S.3 DONE
- **Done**: tạo `.claude/agents/hq-self-builder.md` — frontmatter `name: hq-self-builder`, `tools:` đủ `Read,Write,Edit,Bash,TaskGet,TaskUpdate,TaskList,SendMessage`. Body: mission + "Đọc đầu phiên" 5 mục (skill self-modify + memory + TaskGet) + workflow 6 bước (baseline→edit→regression gate→restore→báo tester) + bảng scope cho-phép/CẤM + re-spawn smoke checklist + bootstrap caveat A/B/C + anti-patterns 9 mục + output format + quality gate + TeamCreate mode block.
- **Output**: `.claude/agents/hq-self-builder.md`.
- **Gate**: file tồn tại + frontmatter valid; scope/CẤM/procedure/gate/anti-patterns/TeamCreate đủ; `selftest` 9/9 PASS ✓; `validate hello` exit 0 ✓; `run hello -Mock` done ✓; `.runs/` đã dọn ✓.
- **Next**: Session S.4 — agent `hq-self-tester` (`.claude/agents/hq-self-tester.md`).
- **Notes**: agent không có tool `Agent`/`TeamCreate` → re-spawn smoke do lead thực hiện (đã ghi rõ trong §Re-spawn smoke). Mode-separation D-S4 nhấn mạnh trong description + anti-patterns.

### 2026-06-03 — Session S.4 DONE
- **Done**: tạo `.claude/agents/hq-self-tester.md` — frontmatter `name: hq-self-tester`, `tools:` đủ `Read,Bash,TaskGet,TaskUpdate,TaskList,SendMessage`. Body: mission + "Đọc đầu phiên" 5 mục (skill self-modify + memory + TaskGet) + workflow 6 bước (brief→gate regression→re-spawn smoke req→map criteria→in SELF_CHECK_RESULT→báo lead) + anti-patterns 9 mục (incl gate≠approval + auto-append global.md) + output format + quality gate + TeamCreate mode block.
- **Output**: `.claude/agents/hq-self-tester.md`.
- **Gate**: file tồn tại + frontmatter valid; gate commands/re-spawn smoke/SELF_CHECK_RESULT/anti-patterns/changelog draft/TeamCreate đủ; `selftest` 9/9 PASS ✓; `validate hello` exit 0 ✓; `run hello -Mock` done ✓.
- **Next**: Session S.5 — Orchestration wiring (`hq-master.md` + `playbook.md` + `CLAUDE.md`).
- **Notes**: tester KHÔNG có Agent/TeamCreate → re-spawn smoke do lead thực hiện theo checklist tester gửi (nhất quán với self-builder). Điểm phân biệt cốt lõi: `SELF_CHECK_RESULT` (≠ `CHECK_RESULT` của hq-tester) + gate≠done (user-approval mandatory sau gate).

### 2026-06-03 — Session S.5 DONE
- **Done**: wiring 2 agent + 1 skill vào não HQ. `hq-master.md`: thêm "TỰ SỬA HQ" vào sơ đồ phân loại + bảng chain (self-builder/self-tester + user-approval gate) + roster +2 agent + bảng ranh giới §"Ranh giới nới bất biến" (table hq-builder vs hq-self-builder, mode-separation D-S4) + "Trỏ tài liệu" +2 dòng (self-modify skill, design.md). `playbook.md`: §1 +1 dòng "Tự sửa HQ"; §3 per-role brief self-builder/self-tester; §7 PASS criteria 2 vai; §8 anti-patterns #14–17 (mode-sep/recursion/auto-commit/branch-builder-cấm-cứng); §10 self-mod deliverable contract block; §11 changelog global.md format. `company/CLAUDE.md`: +3 hàng bảng file (self-builder, self-tester, self-modify skill); quy ước #1/#6 ghi nới có kiểm soát; hàng phase-s cập nhật tiến độ S.5 xong.
- **Output**: `.claude/hq-master.md` + `.claude/teams/playbook.md` + `company/CLAUDE.md` (wiring).
- **Gate**: `grep -rn "hq-self-builder\|hq-self-tester\|self-modify" .claude/ CLAUDE.md` → 46 hit nhất quán, không dangling ✓; `selftest` 9/9 PASS ✓; `validate hello` exit 0 ✓; `run hello -Mock` done ✓.
- **Next**: Session S.6 — Real-run gate (⚠️ USER-GATE, đốt token). User phải bật đèn trước.
- **Notes**: Spawn thử 2 agent mới defer sang S.6 (real-run context). Bảng ranh giới trong hq-master ghi tường minh hq-builder cấm cứng/hq-self-builder được nới sau gate — đây là điểm phân biệt cốt lõi.

### 2026-06-03 — Session S.1 DONE
- **Done**: nâng branch-edit #2 thành **loại request hạng nhất** (doc-only). `hq-master.md`: thêm nhánh "SỬA chi nhánh ĐÃ CÓ theo yêu cầu user mới" vào sơ đồ phân loại + cập nhật bảng "Rút gọn chain" (chain `planner(light)→builder→tester`) + callout phân biệt với re-fix-từ-verdict + ghi builder đọc-trước/Edit-phẫu-thuật/không-ghi-đè. `playbook.md` §1: thêm dòng bảng "Khi nào lập team" + callout phân biệt re-fix; §3: per-role brief builder thêm note "khi SỬA chi nhánh đã có".
- **Output**: `.claude/hq-master.md` + `.claude/teams/playbook.md` (diff branch-edit).
- **Gate**: `grep -n "Sửa chi nhánh"` ra 4 hit (2 mỗi file) ✓; `selftest` 9/9 PASS ✓; `validate hello` exit 0 ✓; `run hello -Mock` done ✓ (đụng `.claude/` → chạy regression cho chắc; `.runs/` đã dọn).
- **Next**: Session S.2 — skill `self-modify` (`.claude/skills/self-modify/SKILL.md`).
- **Notes**: builder/tester hiện tại đủ cho branch-edit — KHÔNG đẻ agent mới (đúng scope S.1). Phân biệt cốt lõi: branch-edit = user-request mới trên chi nhánh đang tồn tại (cần planner light chốt delta); re-fix = nhánh FAIL trong LOOP build (không user-request mới).

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-06-03 | Created from `PLAN.md` | planner |
| 2026-06-03 | S.1 done — branch-edit #2 hạng nhất (hq-master + playbook) | builder |
| 2026-06-03 | S.2 done — skill self-modify (.claude/skills/self-modify/SKILL.md, 7 mục) | builder |
| 2026-06-03 | S.4 done — agent hq-self-tester (.claude/agents/hq-self-tester.md) | builder |
| 2026-06-03 | S.5 done — orchestration wiring (hq-master + playbook + CLAUDE.md) | builder |
| 2026-06-03 | S.6 skip — user quyết định bỏ qua real-run gate; phase đóng | user |
