# CHECKPOINT — Phase J2: Gộp worker+router → routing theo CẠNH (CD-2 extension)

> Sổ tay tiến độ. Phiên Claude mới mở đọc file này TRƯỚC để biết đang ở đâu.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu").
- **STOP NGAY** khi đạt STOP gate session đó — không tham làm tiếp.
- **TRƯỚC khi đóng chat:** cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log".
- Đây là **self-mod** (sửa `engine/*.ps1`) → chạy chain `hq-self-builder` + `hq-self-tester`, gate đầy
  đủ + **user-approval diff** trước commit. Builder branch-thường KHÔNG đụng engine.

### Ràng buộc bất biến Phase J2

1. **Mock-path BẤT BIẾN** — guard `-not $Mock` ở bơm/validate-nhãn/Write-RouteIssue giữ nguyên; chỉ đổi
   điều-kiện-trigger `type -eq 'router'` → `Test-NodeBranches` (outdeg≥2).
2. **Regression mỗi session:** `validate hello` exit 0 · `run hello "x" -Mock` done · `selftest` 10/10.
   **selftest KHÔNG được đỏ giữa chừng** — S1 migrate trước + validate tạm tolerate; S2 mới flip reject.
3. **Logic ở hàm thuần** `Test-NodeBranches` (1 chỗ), không rải `type` check. Dot-source-safe.
4. **`approval` không đổi.**
5. **Chỉ trong `company/`**; `projects/` (gitignored) KHÔNG migrate.

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 2 | 1 (J2.1) | 50% |
| Helper mới | 1 (Test-NodeBranches) | 1 ✅ | 100% |
| Fixture/pattern migrate sạch | 10 (6 patterns + loopy/branchy/edit-demo/p-brain) | 10 ✅ | 100% |
| validate reject type:router | có (S2) | chưa (tolerate — đúng S1) | — |
| Regression gate pass | 2 (cuối mỗi session) | 1 (J2.1) | 50% |

---

## Đang ở đâu

- **Session kế tiếp:** J2.2 — validate REJECT type:router (+ type lạ) + viz/graph render rẽ theo số cạnh
  + docs (README/CLAUDE.md/ROADMAP). selftest 10/10 cuối session. (Migrate đã xong ở J2.1 → an toàn flip reject.)
- **Blocker:** — (J2.1 chờ user duyệt git diff + commit; chưa commit per D-S2.)
- **Reference:** `PLAN.md` → Session J2.2. Migration surface đã sạch (grep type:router rỗng trong patterns/examples).

---

## Per-session log

### J2.1 — Executor edge-based + migrate fixtures/patterns (2026-06-04)
- **Chain:** self-mod (hq-self-builder build → hq-self-tester verify độc lập). Lead điều phối TaskList loop.
- **Engine:** `engine/workflow.ps1` — thêm hàm thuần `Test-NodeBranches $Graph $NodeId` (outdeg≥2, field `.adj`,
  StrictMode-safe `@().Count`, dot-source-safe) + thay 6 chỗ `$node.type -eq 'router'` → `Test-NodeBranches`
  (pre-seed _payload, Select-NextNode, resume restore, bơm choices, validate-nhãn, store _payload). Guard
  `-not $Mock` + approval branch GIỮ NGUYÊN.
- **Validate:** `engine/validate.ps1` — rewrite luật out-edge sang outdeg-based (≥2 cạnh → mỗi cạnh cần `when`;
  ≤1 → không); bỏ lỗi "node thường >1 cạnh"; `_payload` check dùng outdeg≥2; **TẠM tolerate** type:router
  (chưa reject — để J2.2).
- **Migrate:** gỡ `"type":"router"` khỏi 6 `patterns/*.json` + `examples/{loopy,branchy,edit-demo,p-brain}/workflow.json`.
  p-* stamped re-gen sạch tự động (fragment đã sạch, không cần sửa stamp.ps1).
- **Gate (self-tester độc lập):** `SELF_CHECK_RESULT: pass` — selftest 10/10 • validate hello/branchy/loopy/
  edit-demo/approval-demo exit 0 • run branchy(tier:gt1000)/loopy(verdict:pass) -Mock done • grep type:router
  RỖNG • Test-NodeBranches count=9.
- **Trạng thái:** code + migrate xong, gate xanh. **CHƯA commit** — chờ user duyệt git diff (D-S2).

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-06-03 | Created from design discussion (sau Phase J review) | lead |
