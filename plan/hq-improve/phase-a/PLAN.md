# PLAN — Phase A: Audit (findings + baseline)

> Sau toàn bộ Phase A ta có `plan/hq-improve/phase-a/findings.md`: danh sách hành động xếp ưu tiên (bug + chắp-vá + doc/UX) — mỗi mục có `file:line`, mức nghiêm trọng, phase đích — cộng với baseline test pass/fail hiện trạng. Đây là tài liệu các phase B+ bám theo. **KHÔNG sửa code ở phase này.**

---

## Context

- **Vì sao chia nhiều session**: Audit phải quét ~3.800 dòng engine across 17 file `.ps1` + 3 test script + 7 `p-*/stamp.ps1` + mem-demo done-gate. Đọc kỹ để ghi findings đo được (`file:line` + tác động + đề xuất) cho từng file là khối lượng vượt 1 chat nếu muốn chất lượng. Chia theo cụm module để mỗi chat đọc trọn 1 cụm rồi STOP.
- **Đây là phase đi đầu (D-4 audit-first)**: scope các phase B+ là *provisional* — sau khi `findings.md` chốt, ROADMAP sẽ được rà lại theo findings rồi mới soạn long-plan các phase sau.
- **Quyết định đã chốt (default; user override được)**:
  - **D-A1. Thang ưu tiên**: `P0` = chặn (sai/vỡ, phải sửa trước khi xây tiếp) · `P1` = nên (chắp-vá/UX cản trở rõ) · `P2` = nice (dọn dẹp, không cản).
  - **D-A2. Ranh giới bug vs chắp-vá**: *bug* = hành vi sai/không đúng spec (kể cả StrictMode edge `$null`/`.Count`). *chắp-vá* = chạy đúng nhưng khó mở rộng/sửa (leaky abstraction, parser tự chế, path xấu, test rải rác). *doc/UX* = đúng nhưng khó hiểu/khó dùng.
  - **D-A3. KHÔNG chạy E2E thật**: audit chỉ đọc code + chạy mock (`-Mock` / `ENGINE_MOCK_ROUTER`) để lấy baseline. Lý do: real-run đốt token; rủi ro real-path đã quan sát gián tiếp qua code + watch-item Phase 5. Nếu sau A.5 còn nghi vấn real-path cụ thể → ghi thành finding "cần real-run xác nhận" cho phase sau, không burn ngay.
  - **D-A4. Scope rộng**: ghi findings cho cả correctness, StrictMode, leaky abstraction, doc/UX, CLI — để mọi phase B/C/D/E/F đều có findings đầu vào. KHÔNG bỏ qua loại "doc/UX" dù phase này không sửa.

- **Out of scope**: mọi sửa code (kể cả fix 1 dòng), refactor, viết lại README, dựng app. Chỉ đọc + chạy mock + ghi `findings.md`. Sửa thuộc Phase B/C trở đi.

---

## Pipeline 3 sub-phase / 5 session

```
[A.1] Baseline + surface sweep ───────► findings.md (§Baseline + §Surface) + skeleton
                                             │
[A.2] Deep-read: executor core ──────────► findings entries: graph/workflow/bridge/run/lib
[A.3] Deep-read: validate+viz+tester ────► findings entries: validate/viz/check/sandbox/status/edit
[A.4] Deep-read: HQ/E2E + leaky-abstract ► findings entries: spec/e2e/pattern/memory + §cross-cut
                                             │
[A.5] Synthesis + gate ──────────────────► findings.md chốt (mọi mục có mức + phase đích) + user duyệt
```

---

## Phase A — Audit

**Mục tiêu**: 1 tài liệu `findings.md` đầy đủ, xếp ưu tiên, mỗi mục `file:line` → mức → phase đích; + baseline test (pass/fail hiện trạng). Không sửa code.

### Schema mỗi mục trong `findings.md` (bất biến qua mọi session)

```
### A-<NN> — <tiêu đề ngắn>
- **Loại**: bug | chắp-vá | doc/UX
- **File:line**: engine/<file>.ps1:<line> (hoặc nhiều vị trí)
- **Mô tả**: <chuyện gì đang xảy ra>
- **Tác động**: <vỡ cái gì / cản cái gì / ai gặp>
- **Mức**: P0 | P1 | P2
- **Đề xuất hướng**: <ý sửa, KHÔNG thực hiện>
- **Phase đích**: B | C | D | E | F
```

### Session A.1 — Baseline + surface sweep
- **Scope**:
  - Tạo `findings.md` với skeleton: header + §Baseline + §Surface + §Findings (rỗng) + §Cross-cut (rỗng, điền A.4/A.5).
  - Chạy mock baseline + ghi pass/fail (KHÔNG sửa nếu fail — chỉ ghi):
    - `examples/hq-tests.ps1`, `examples/hq-graph-tests.ps1`, `examples/e2e-harness-tests.ps1` (mỗi cái: exit code + số test fail).
    - `run.ps1 validate` + `run.ps1 run … -Mock` cho: `hello`, `branchy`, `loopy`, `web-demo`, `hq`.
    - mem-demo done-gate (2-run mock) nếu có runner; nếu chạy tay thì ghi cách + kết quả.
    - 7 `examples/p-*/stamp.ps1` (chỉ ghi pass/fail stamp, không sửa).
  - §Surface: lập bảng 12 lệnh `run.ps1` (`run/resume/viz/validate/check/trial/build/e2e/e2efix/status/logs/edit`) → cột [chạy HQ | chạy project con | tác giả-time/nội bộ] + 4 nơi artifact (`.runs/` · `projects/` · `sandbox/` · gốc). Đây là dữ kiện thô cho Phase B, KHÔNG đề xuất gom ở đây.
- **STOP gate**: `findings.md` tồn tại; §Baseline có 1 dòng/test-script + 5 project mock-run với exit code thực tế ghi lại; §Surface có bảng 12 lệnh đủ 3 cột + 4 artifact dir. Mọi run là mock (không `-Real`). 0 file code bị sửa (`git status`/diff sạch ngoài `findings.md`).
- **Output artifact**: `plan/hq-improve/phase-a/findings.md` (§Baseline + §Surface đầy + skeleton phần sau).

### Session A.2 — Deep-read: executor core
- **Scope**: đọc kỹ + ghi findings cho cụm executor lõi:
  - `engine/graph.ps1` (188), `engine/workflow.ps1` (425), `engine/bridge.ps1` (50), `engine/run.ps1` (278, dispatcher), `engine/lib/json.ps1` (43), `engine/lib/log.ps1` (42), `engine/lib/claude.ps1` (102, mock plumbing + `ENGINE_MOCK_ROUTER`).
  - Soi: correctness của single-cursor walk + router edge-select + max_steps guard + resume; StrictMode edge (`$null`/`.Count`/`@()`→`$null`); mock-router-spec rò node-id; path `../` xấu trong log.
- **STOP gate**: mỗi file trong cụm có dòng "read ✓" trong CHECKPOINT; mỗi finding ghi theo schema có `file:line` thật; nếu file sạch → ghi explicit "clean" cho file đó. 0 file code bị sửa.
- **Output artifact**: findings entries cụm executor-core append vào `findings.md` §Findings.

### Session A.3 — Deep-read: validate + viz + tester tier
- **Scope**: đọc kỹ + ghi findings cho:
  - `engine/validate.ps1` (332), `engine/viz.ps1` (149), `engine/check.ps1` (160), `engine/sandbox.ps1` (302), `engine/status.ps1` (213), `engine/edit.ps1` (305).
  - Soi: validation v2 đủ/sót rule không; viz ASCII/Mermaid correctness; `Test-StructuralGate` short-circuit; sandbox copy/teardown guard; status/logs (liên quan #3 log trống — ghi cụ thể chỗ chỉ in `node→done (N chars)`); edit TUI.
- **STOP gate**: mỗi file trong cụm "read ✓" trong CHECKPOINT + findings hoặc "clean" mỗi file, có `file:line`. 0 file code bị sửa.
- **Output artifact**: findings entries cụm validate/viz/tester append vào `findings.md`.

### Session A.4 — Deep-read: HQ/E2E layer + cross-cut leaky abstraction
- **Scope**: đọc kỹ + ghi findings cho:
  - `engine/spec.ps1` (504), `engine/e2e.ps1` (407), `engine/pattern.ps1` (104), `engine/memory.ps1` (187).
  - Soi: `Test-PlanSchema`/`Test-BuildSpec`/`Invoke-BuildSpec`; `Get-AgentFrontmatter` YAML-parser tự chế (chỉ hiểu inline list — ghi giới hạn); dry-run gate + `-Router` BẮT BUỘC (leaky); promote guard; `Get-Memory` cap/fence-skip StrictMode.
  - Viết §Cross-cut (draft): (a) mock-path vs real-path divergence (suy từ code, không real-run); (b) Builder non-determinism (watch-item Phase 5 — ghi hiện trạng prompt-harden, chưa guard engine); (c) test fragmentation (3 script + 7 stamp, không runner gom).
- **STOP gate**: 4 file "read ✓" + findings/clean mỗi file; §Cross-cut có cả 3 tiểu mục với ít nhất 1 finding/tiểu mục. 0 file code bị sửa.
- **Output artifact**: findings entries cụm HQ/E2E + §Cross-cut draft append vào `findings.md`.

### Session A.5 — Synthesis + user gate
- **Scope**:
  - Rà toàn bộ §Findings: mỗi mục PHẢI có `Mức` (P0/P1/P2) + `Phase đích` (B/C/D/E/F). Điền chỗ còn thiếu.
  - Hoàn thiện §Cross-cut (từ draft A.4 → kết luận).
  - Thêm §Tổng hợp: bảng đếm theo mức + theo phase đích; danh sách P0 đầu bảng; thứ tự xử đề xuất.
  - Trình user duyệt danh sách + thứ tự.
- **STOP gate**: 100% mục findings có Mức + Phase đích (không mục nào trống); §Baseline + §Surface + §Cross-cut + §Tổng hợp đầy đủ; **user duyệt danh sách + thứ tự** (ghi xác nhận vào CHECKPOINT). 0 file code bị sửa.
- **Output artifact**: `findings.md` chốt.

**Phase A gate** (sau A.5): `findings.md` hoàn chỉnh — mọi mục có `file:line` + mức + phase đích; baseline pass/fail ghi lại; user duyệt. → Cập nhật `ROADMAP.md` bảng tiến độ (A ✅) + rà scope B+ theo findings.

---

## Outcome cuối

- `plan/hq-improve/phase-a/findings.md`: 1 nguồn chân lý cho mọi phase sau, xếp ưu tiên, máy/người đọc được.
- Baseline test mock ghi lại (điểm so sánh cho regression Phase C+).
- 0 dòng code engine thay đổi (audit thuần đọc).
- Gate đo lường: mọi mục findings có `file:line` + mức + phase đích; user approve.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-05-28 | Initial | Soạn long-plan Phase A từ `plan/hq-improve/ROADMAP.md` (3 sub-phase / 5 session) |
