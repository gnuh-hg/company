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
| Session hoàn thành | 7 (S.0–S.6) | 2 (S.0–S.1) | 29% |
| Agent mới | 2 (hq-self-builder, hq-self-tester) | 0 | 0% |
| Skill mới | 1 (self-modify) | 0 | 0% |
| Vai hạng nhất | #2 branch-edit + #3 self-mod | 0/2 | 0% |
| Real-run gate (S.6) | 5/5 tiêu chí | — | — |

---

## Đang ở đâu

- **Phase**: S.B (S.A xong)
- **Session kế tiếp**: **S.2 — Skill `self-modify`** (`.claude/skills/self-modify/SKILL.md`)
- **Blocker**: —
- **Reference**: `PLAN.md` → Sub-phase S.B → Session S.2

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
