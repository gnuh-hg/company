# CHECKPOINT — Phase J: Rẽ nhánh chủ động (engine bơm choices + validate, CD-2)

> Sổ tay tiến độ dài hạn. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ được làm 1 session** (xem mục "Đang ở đâu" để biết session nào).
- **STOP NGAY** khi đạt STOP gate của session đó — không tham làm session kế tiếp dù còn quota.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry vào "Per-session log".

### Ràng buộc bất biến Phase J (nhắc lại mỗi chat)

1. **Mock-path BẤT BIẾN**: `ENGINE_MOCK_ROUTER` trả nhãn trực tiếp, KHÔNG qua bơm suffix. `if (-not $Mock)` guard mọi chỗ bơm + validate tập nhãn + `Write-RouteIssue`.
2. **Regression mỗi session chạm engine**: chạy 3 lệnh sau khi sửa bất kỳ `.ps1`:
   - `./run.ps1 validate hello` → exit 0
   - `./run.ps1 run hello "x" -Mock` → status done
   - `./run.ps1 selftest` → `10/10 PASS` (J.4 đã thêm mục thứ 10)
3. **Sửa logic ở hàm thuần testable** (`Get-RouterChoices`, `Write-RouteIssue`, `Get-RouterPayload`), KHÔNG nhồi vào nhánh direct-run. Module dot-source-safe.
4. **Chỉ thêm khả năng, không break tương thích ngược**: workflow không dùng router vẫn chạy y hệt; router chỉ in nhãn đơn vẫn hoạt động (payload = `""`).
5. **Không retry khi nhãn sai**: ghi `Write-RouteIssue` → `throw` ngay. Không re-ask model.
6. **`route-issues.ndjson` ghi tập trung tại `company/issues/route-issues.ndjson`** (gitignored `issues/*.ndjson`; mỗi entry mang `run_id`) — KHÔNG ghi vào `company/issues/team-issues-queue.md` (cái đó cho HQ-team native behave).
7. **Chỉ thao tác trong `company/`**.

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 5 | 5 | 100% |
| Hàm thuần mới | 3 (Get-RouterChoices, Write-RouteIssue, Get-RouterPayload) | 3 | 100% |
| Regression gate pass | 5 lần (cuối mỗi session) | 5 | 100% |
| Mock-path bất biến | confirm mỗi session | 5/5 confirm | 100% |

---

## Đang ở đâu

- **Phase**: ✅ COMPLETE — Phase J đã hoàn thành toàn bộ 5 session (2026-06-03)
- **Session kế tiếp**: N/A — Phase J đóng
- **Blocker**: —
- **Reference**: `ROADMAP.md` → Phase J = ✅ DONE

---

## Per-session log

### J.1 — 2026-06-03

**Session**: Get-RouterChoices + wire choice-injection suffix vào prompt router real-mode
**Artifact**: `engine/workflow.ps1` — 2 delta:
- Thêm hàm thuần `Get-RouterChoices` (dòng 131): nhận `$Graph` + `$NodeId` → trả `[string[]]` tập nhãn `when` (lọc blank, lowercase, sort-unique). Dot-source-safe.
- Wire suffix bơm trong `Invoke-Workflow` (guard `if ($node.type -eq 'router' -and -not $Mock)`): gọi `Get-RouterChoices` → ghép suffix `"\n\n---\nChọn đúng MỘT nhãn sau (in nhãn ở dòng cuối):\n{ ... }"` vào `$prompt` trước `Invoke-Claude`.
**Gate**: selftest 9/9 PASS · validate hello exit 0 · run hello -Mock done · run branchy -Mock done (mock bất biến) · validate loopy exit 0
**Ghi chú**: branchy cần `ENGINE_MOCK_ROUTER` khi chạy -Mock (router có 4 nhãn). Mock-path bất biến.

---

### J.2 — 2026-06-03

**Session**: Write-RouteIssue + validate nhãn ∈ tập bơm (fail-fast, no retry)
**Artifact**: `engine/workflow.ps1` — 2 delta:
- Thêm hàm thuần `Write-RouteIssue` (dòng 156): nhận `$RunDir`, `$NodeId`, `$RawOutput`, `$ValidChoices[string[]]` → resolve `$PSScriptRoot/../issues/route-issues.ndjson` → tạo thư mục nếu chưa có → append 1 dòng JSON (fields: `ts`, `run_id`, `node`, `raw_output`, `valid_choices[]`, `label_extracted`). Deterministic, không gọi model.
- Validate site trong `Invoke-Workflow` (sau `Invoke-Claude`, trước `node_output`, guard `if ($node.type -eq 'router' -and -not $Mock)`): `ConvertTo-RouterLabel` + `Get-RouterChoices` → nếu nhãn không trong tập → `Write-RouteIssue` → throw (text bất biến tương thích ngược).
**Issue file**: `company/issues/route-issues.ndjson` (gitignored)
**Gate**: selftest 9/9 PASS · validate branchy exit 0 · run branchy -Mock done · validate/run hello PASS
**Verify**: unit-style dot-source → `Write-RouteIssue` trực tiếp → entry parse được (`run_id`, `node`, `label_extracted`, `valid_choices` đúng)

---

### J.3 — 2026-06-03

**Session**: Get-RouterPayload + auto-store `<output_key>_payload` trong context
**Artifact**: `engine/workflow.ps1` — 4 delta:
- Thêm hàm thuần `Get-RouterPayload` (dòng 196): nhận `$Output` → trả payload = toàn bộ output TRỪ dòng không-trắng cuối (nhãn route). Chỉ 1 dòng → "". Dot-source-safe.
- Pre-seed `_payload` trong `Initialize-Context`: với mọi router node có `output_key`, thêm `ctx["${k}_payload"] = ""` → loop-feedback safe.
- Restore `_payload` trong resume loop: khi nạp lại `<k>.txt`, nếu node type `router` → tính lại `Get-RouterPayload` → lưu vào context.
- Wire lưu `_payload` trong main walk: sau `$context[$node.output_key] = $output`, nếu router → `context["${k}_payload"] = Get-RouterPayload $output`. Áp cả mock + real.
**Gate**: selftest 9/9 PASS · validate hello/branchy/loopy exit 0 · run hello/branchy -Mock done
**Verify**: 4 case unit test ALL PASS (`"line1\nline2\nbranch_a"→"line1\nline2"`, `"branch_a"→""`, trailing-blank, empty)

---

### J.4 — 2026-06-03

**Session**: Fixture branchy 2-part + validate.ps1 _payload warn + selftest entry #10
**Artifacts**:
- `examples/branchy/agents/tier-router.md` — cập nhật sang 2-part format: dòng đầu = lý do, dòng cuối = nhãn
- `examples/branchy/workflow.json` — thêm `{{tier_payload}}` vào input node `output`
- `examples/branchy/agents/output.md` — nhận `tier_payload` và in trong kết quả
- `engine/validate.ps1` — thêm `_payload` check trong key-resolve loop: `{{x_payload}}` không có router `output_key=x` → WARN (không error); có router → no warn; exit code không đổi
- `engine/test-runner.ps1` — thêm selftest entry #10 `branchy/2-part-protocol`: mock router trả `"PAYLOAD_DATA\ngt1000"` (multi-line via `ENGINE_MOCK_ROUTER`) → verify `result.txt` chứa "PAYLOAD_DATA". Header/footer: 10 mục.
**Gate**: **selftest 10/10 PASS** (kể cả entry mới `status=done payload-in-result=True`) · validate branchy/hello/loopy/approval-demo exit 0 · run -Mock done
**Verify validate warn**: FIRES cho `{{foo_payload}}` (no router foo) · KHÔNG fire cho hello/branchy (tier router valid) — ALL PASS
**Quyết định selftest**: THÊM entry #10 — sạch + deterministic + không brittle

---

### J.5 — 2026-06-03

**Session**: Docs + CLAUDE.md + ROADMAP + CHECKPOINT close-out (pure docs)
**Artifacts**:
- `README.md` — thêm §"Router choices auto-inject" + §"Giao thức 2-phần" dưới §Router; cập nhật selftest "9 mục"→"10 mục" (3 chỗ: surface lệnh table, cấu trúc thư mục, footer)
- `CLAUDE.md` — sửa 4 hàng bản đồ file: `engine/workflow.ps1` (Phase J 3 hàm) · `engine/test-runner.ps1` (10 mục + branchy/2-part) · `engine/validate.ps1` (_payload warn additive) · `plan/hq-v2/phase-j/` (✅ DONE)
- `plan/hq-v2/ROADMAP.md` — Phase J → ✅ DONE (2026-06-03)
- `plan/hq-v2/phase-j/CHECKPOINT.md` — (file này) 5/5 sessions done + per-session log đủ 5 entry
**Gate**: selftest 10/10 PASS · validate hello exit 0 · run hello -Mock done · validate branchy exit 0 · run branchy -Mock done · grep 3 hàm tồn tại

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-06-03 | Created from `PLAN.md` | @planner |
| 2026-06-03 | J.1–J.5 completed — Phase J DONE | @hq-self-builder |
