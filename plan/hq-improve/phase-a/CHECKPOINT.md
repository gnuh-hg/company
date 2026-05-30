# CHECKPOINT — Phase A: Audit

> Sổ tay tiến độ. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu. Đọc kèm `plan/hq-improve/phase-a/PLAN.md`.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu").
- **KHÔNG sửa code** ở bất kỳ session nào — Phase A là audit thuần đọc. Chỉ ghi `findings.md` + cập nhật file plan. `git diff` engine phải sạch.
- **KHÔNG chạy `-Real`** (D-A3) — chỉ mock. Real-run đốt token, ngoài scope audit.
- **STOP NGAY** khi đạt STOP gate của session — không tham làm session kế tiếp.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log".

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 5 | 5 | 100% |
| File engine đã read ✓ | 17 | 17 | 100% |
| Test script chạy baseline | 3 (+7 stamp +mem-demo) | 3 (+7 stamp +mem-demo) | 100% |
| Findings có đủ mức+phase | 100% | 100% (25/25) | 100% |
| User duyệt findings | 1 | 1 | 100% |

---

## Đang ở đâu

- **Phase**: A — **✅ DONE** (5/5 session, user duyệt 2026-05-28).
- **Session kế tiếp**: Phase A đóng. Bước tiếp theo = soạn long-plan **Phase B (CLI & docs)** hoặc **Phase C (fix + de-chắp-vá)** khi user yêu cầu — bám `findings.md` §Tổng hợp (thứ tự 13 bước) + ROADMAP §"Rà scope B+ theo findings".
- **Blocker**: —
- **Reference**: `findings.md` chốt — 25 finding, 0 P0, 3 P1 (A-18 mất-dữ-liệu edit + A-17, A-08 stderr real-mode **cần 1 real-run**, A-01 mock-router doc). Mang sang Phase C: (1) cụm sửa chung thay vì theo file. (2) A-06 4 bản/3 tên accessor. (3) Mẫu cast-số đúng `spec.ps1:217`/`:131` → fix A-07/A-11/A-12. (4) CC-a/b/c nuôi C/D/E/F.

---

## Per-session log

### A.1 — Baseline + surface sweep (2026-05-28)
- **Làm**: Tạo `findings.md` (§Baseline + §Surface đầy + §Findings/§Cross-cut/§Tổng-hợp skeleton). Chạy mock baseline trên pwsh (Linux snap 7.x).
- **Baseline**: 3/3 test script PASS (hq-tests / hq-graph-tests / e2e-harness-tests, đều exit 0). validate 5/5 exit 0. run -Mock: hello+web-demo done (0); branchy+loopy+hq exit 1 — **kỳ vọng** (router echo `<request>` không khớp `when`; cần `ENGINE_MOCK_ROUTER`, đã cover trong test script chuyên dụng). mem-demo 2-run done-gate PASS (chạy tay, không có runner). 7/7 stamp PASS.
- **§Surface**: bảng 12 lệnh (run/resume/viz/validate/check/trial/build/e2e/e2efix/status/logs/edit) × [HQ·proj-con·author] + 4 artifact dir (`.runs/`·`projects/`·`sandbox/`·gốc) + thứ tự `Resolve-ProjectDir`.
- **Pre-seed finding** (ghi nhận, chưa vào §Findings): (1) `run -Mock` không tự lái router → người mới tưởng vỡ → doc/UX. (2) `Resolve-ProjectDir` ưu tiên `projects/` trước `examples/` khi trùng tên → cân nhắc A.2.
- **Cleanup**: dọn mọi `.runs/` + `examples/mem-demo/memory/` sau verify. 0 file code engine bị sửa.
- **STOP gate**: ✅ findings.md tồn tại; §Baseline đủ 1 dòng/test + 5 project; §Surface đủ 12 lệnh 3 cột + 4 dir; mock-only; 0 code sửa.

---

### A.2 — Deep-read executor core (2026-05-28)
- **Read ✓ (7 file)**: `graph.ps1` · `workflow.ps1` · `bridge.ps1` · `run.ps1` · `lib/json.ps1` · `lib/log.ps1` · `lib/claude.ps1`.
- **Clean** (ghi explicit trong findings): `lib/json.ps1`, `lib/log.ps1`, `bridge.ps1`.
- **Findings ghi (10)**: A-01 mock không lái router (doc/UX P1, B) · A-02 ENGINE_MOCK_ROUTER keyed-by-agent-không-node (chắp-vá P2, C) · A-03 Get-AgentFrontmatter YAML-parser inline-only (chắp-vá P2, C) · A-04 reserved-key bảo vệ không nhất quán (chắp-vá P2, C) · A-05 Resolve-ProjectDir projects>examples che ngầm (doc/UX P2, B/C) · A-06 property-accessor trùng 3 chỗ/2 tên (chắp-vá P2, C) · A-07 cast int max_steps + edges-vắng crash thô (bug P2, C) · A-08 real-mode 2>&1 trộn stderr vào JSON (bug P1, C — cần real-run) · A-09 reassign `$args` (chắp-vá P2, C) · A-10 flag thiếu value nuốt im (doc/UX P2, B).
- **Cleanup**: 0 file engine sửa (`git status` engine clean). Không chạy run nào (đọc thuần) → không sinh `.runs/`.
- **STOP gate**: ✅ 7 file có "read ✓"; mỗi finding có `file:line` thật theo schema; file sạch ghi explicit "clean"; mock-only; 0 code sửa.

### A.3 — Deep-read validate + viz + tester tier (2026-05-28)
- **Read ✓ (6 file)**: `validate.ps1` · `viz.ps1` · `check.ps1` · `sandbox.ps1` · `status.ps1` · `edit.ps1`.
- **Clean** (ghi explicit): `check.ps1` (StructuralGate short-circuit + reason máy-đọc-được + honor env router không hardcode).
- **Xác minh carry-over**: A-04 đúng (validate KHÔNG chặn output_key ∈ reserved) · A-06 mở rộng (`Get-VProp` validate:45 là bản thứ 4 / 3 tên) · A-07 lan sang validate (→ A-11, A-12).
- **Findings ghi (8)**: A-11 cast `[int]max_steps` validate crash (bug P2 C) · A-12 edges-vắng → phantom dangling-error (bug P2 C) · A-13 node-id charset chưa validate + viz Mermaid giả định an toàn (chắp-vá P2 C) · A-14 Remove-Sandbox StartsWith guard không separator (chắp-vá P2 C) · A-15 run-time log chỉ "(N chars)" observability (doc/UX P2 E) · A-16 validate bỏ qua schema trial[] → lỗi lộ lúc real-run đốt token (chắp-vá P2 C) · A-17 edit 'v' ghi đè workflow.json trước save (bug P2 C) · **A-18 edit pipeline-only → save/viz trên project graph XOÁ TRẮNG graph, kể cả hq/ source committed (bug mất-dữ-liệu P1 C)**.
- **Cleanup**: 0 file engine sửa (chỉ findings.md + CHECKPOINT.md). Đọc thuần → không sinh `.runs/`. Không `-Real`.
- **STOP gate**: ✅ 6 file "read ✓"; mỗi finding có `file:line` thật theo schema; check.ps1 ghi "clean"; carry-over A-04/A-06/A-07 xác minh; mock-only; 0 code sửa.

### A.4 — Deep-read HQ/E2E layer + cross-cut (2026-05-28)
- **Read ✓ (4 file)**: `spec.ps1` · `e2e.ps1` · `pattern.ps1` · `memory.ps1` → engine 17/17 file đã đọc xong.
- **Clean** (ghi explicit): `pattern.ps1` (Expand-Pattern stamp đúng id/from/to, throw rõ, clone verbatim, author-time-only).
- **Xác minh carry-over**: A-06 chốt biên **4 bản/3 tên** (spec.ps1:30 là bản đã đếm; e2e dùng lại Get-SProp của status, KHÔNG nhân bản; pattern/memory không trùng) · A-03 vẫn là điểm parse frontmatter duy nhất (e2e/spec không tự parse) · A-07/A-11 đối chiếu bản ĐÚNG ở `spec.ps1:217`+`:131` (guard kiểu số) → mẫu fix Phase C.
- **Findings ghi (6)**: A-19 stamp logic nhân đôi (chắp-vá P2 C) · A-20 Invoke-BuildSpec không validate graph → lỗi lộ muộn (chắp-vá P2 C) · A-21 cap mem_patterns gộp theo file-order không theo time → global đẩy patterns mới ra (bug P2 C) · A-22 fence ``` lẻ nuốt trắng phần còn lại file (chắp-vá P2 C) · A-23 format delimiter memory khai 2 nơi coupling (chắp-vá P2 C) · A-24 Test-DryRunGate RouterSpec leaky (chắp-vá P2 C) · A-25 Promote-Branch StartsWith thiếu separator cùng lớp A-14 (chắp-vá P2 C).
- **§Cross-cut draft (3 tiểu mục)**: CC-a mock-vs-real divergence (mock bỏ qua frontmatter/router → gate CẦN không ĐỦ; nối A-03/A-08/A-16) · CC-b Builder non-determinism (Invoke-E2EFix verify outcome không verify method; nối Phase D/F) · CC-c test fragmentation (3 script+7 stamp in-only+mem-demo tay, không runner gom; memory/pattern thiếu test riêng).
- **Cleanup**: 0 file engine sửa (chỉ findings.md + CHECKPOINT.md). Đọc thuần → không sinh `.runs/`. Không `-Real` (D-A3).
- **STOP gate**: ✅ 4 file "read ✓" (engine 17/17); mỗi finding có `file:line` thật theo schema; pattern.ps1 ghi "clean"; §Cross-cut đủ 3 tiểu mục mỗi mục ≥1 finding/bằng-chứng; mock-only; 0 code sửa.

### A.5 — Synthesis + user gate (2026-05-28)
- **Làm**: Verify 25/25 finding (A-01..A-25) đủ Mức + Phase đích (không sửa nội dung finding). Chốt §Cross-cut (CC-a/b/c "Kết luận tạm"→"Kết luận"). Viết §Tổng hợp: bảng đếm theo Mức (0 P0 / 3 P1 / 22 P2) + theo Loại (7 bug / 14 chắp-vá / 4 doc-UX) + theo Phase đích (B:2 / C:22 / E:1) + 3 mục P1 chi tiết + **thứ tự xử lý 13 bước** (gom theo cụm sửa chung) + hệ quả ROADMAP. Cập nhật ROADMAP (A ✅ + §"Rà scope B+ theo findings").
- **User gate**: ✅ user duyệt **nguyên trạng** (25 finding + thứ tự 13 bước) — 2026-05-28.
- **Cleanup**: 0 file engine sửa (chỉ findings.md + CHECKPOINT.md + ROADMAP.md). Mock-only; không `-Real`.
- **STOP gate**: ✅ 100% finding có Mức+Phase đích; §Baseline+§Surface+§Cross-cut+§Tổng hợp đầy đủ; user duyệt ghi vào CHECKPOINT; 0 code sửa. → **Phase A đóng.**

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-28 | Created from `PLAN.md` | @planner |
| 2026-05-28 | A.1 done — baseline + surface sweep ghi `findings.md` | @claude |
| 2026-05-28 | A.2 done — deep-read executor core (7 file), ghi 10 findings A-01..A-10 | @claude |
| 2026-05-28 | A.3 done — deep-read validate/viz/tester (6 file), ghi 8 findings A-11..A-18 (A-18 P1 data-loss) | @claude |
| 2026-05-28 | A.4 done — deep-read HQ/E2E (4 file, engine 17/17), ghi 6 findings A-19..A-25 + §Cross-cut draft CC-a/b/c | @claude |
| 2026-05-28 | A.5 done — chốt §Cross-cut + §Tổng hợp (25 finding, 0 P0, 3 P1, thứ tự 13 bước); user duyệt; ROADMAP A ✅. **Phase A đóng** | @claude |
