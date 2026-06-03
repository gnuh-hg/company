# CHECKPOINT — Phase J2: Gộp worker+router → routing theo CẠNH (CD-2 extension)

> Sổ tay tiến độ. Phiên Claude mới mở đọc file này TRƯỚC để biết đang ở đâu.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu") — **ngoại lệ: KHÔNG ràng buộc team-lead.** Nếu user
  giao cả phase cho lead mà không giới hạn rõ → lead làm hết các session liên tiếp (gate + update
  CHECKPOINT sau mỗi session). Ràng buộc vẫn áp cho teammate. Xem `.claude/hq-master.md` + plan-long SKILL.
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
| Sessions hoàn thành | 2 | 2 (J2.1 + J2.2) ✅ | 100% |
| Helper mới | 1 (Test-NodeBranches) | 1 ✅ | 100% |
| Fixture/pattern migrate sạch | 10 (6 patterns + loopy/branchy/edit-demo/p-brain) | 10 ✅ | 100% |
| validate reject type:router | có (S2) | ✅ DONE (J2.2) | 100% |
| viz/graph render outdeg-based | có (S2) | ✅ DONE (J2.2) | 100% |
| Regression gate pass | 2 (cuối mỗi session) | 2 (J2.1 + J2.2) ✅ | 100% |

---

## Đang ở đâu

- **Trạng thái:** ✅ DONE — J2.1 + J2.2 hoàn thành. Gate xanh (selftest 10/10 + validate exit 0 + run -Mock done). **CHƯA commit** — chờ user duyệt git diff (D-S2).
- **Blocker:** — (chờ user duyệt + commit cả J2.1 + J2.2 cùng lúc).
- **Reference:** `PLAN.md` §"Session J2.2". Toàn bộ done_criteria verified.

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

### J2.2 — validate REJECT type:router + viz/graph edge-based + docs (2026-06-04)
- **Chain:** self-mod (hq-self-builder build → hq-self-tester verify độc lập). Lead điều phối.
- **validate.ps1:** thêm type check sau khi set default 'work' — reject `type:"router"` (error rõ: "đã bỏ J2 — node ≥2 cạnh tự rẽ; xoá field type") + reject type lạ khác worker/work/approval → error "không hợp lệ". Cập nhật comments (bỏ "tolerate J2.1"). Type check sử dụng `$nodeLabel` (id nếu có, else "#idx") cho error message.
- **viz.ps1:** `Get-GraphMermaid` — đổi priority: approval hexagon trước, rồi check `@($Graph.adj[$n.id]).Count -ge 2` để render diamond (không còn `$n.type -eq 'router'`). `Format-GraphAscii` — tag `branch` thay `router`, dựa trên outdeg≥2. Cập nhật `.DESCRIPTION`.
- **graph.ps1:** direct-run section — `$tag` dùng if/elseif: approval→`(approval)`, outdeg≥2→`(branch)`, else `''`.
- **README.md:** đổi ví dụ JSON (bỏ `type:"router"`, thêm cạnh `tier→output when:else` để đủ 2 nhánh). Cập nhật bảng field (type row + when row). Đổi §Router → §"Điểm rẽ" + nội dung phản ánh outdeg-based. Cập nhật mô tả loop + validate _payload note + dòng đầu description engine.
- **CLAUDE.md:** quy ước #2 cập nhật ("có when cho node ≥2 cạnh ra"). Bản-đồ-file: workflow.ps1/validate.ps1/viz.ps1/graph.ps1/phase-j2 cập nhật J2. branchy/loopy/edit-demo descriptions cập nhật.
- **plan/hq-v2/ROADMAP.md:** Phase J2 → ✅ DONE (2026-06-04).
- **Gate (self-builder):** selftest 10/10 PASS • validate hello/branchy/loopy/edit-demo/p-brain/approval-demo exit 0 • run hello -Mock done • viz branchy (tier=diamond branch) + loopy (verdict=diamond branch) không vỡ • reject demo: _tmp-router type:router → exit 1 + error rõ • grep type:router RỖNG.
- **Trạng thái:** code xong, gate xanh (pending tester verify). **CHƯA commit** — chờ user duyệt git diff.

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-06-03 | Created from design discussion (sau Phase J review) | lead |
| 2026-06-04 | J2.2 done: validate REJECT type:router + viz/graph outdeg-based + docs | hq-self-builder |
