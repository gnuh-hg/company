# CHECKPOINT — Phase I: Tối ưu token engine chi nhánh (hq-v2)

> Sổ tay tiến độ. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu"). **STOP NGAY** khi đạt STOP gate — không tham session kế.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log".
- **Regression mỗi session chạm engine** (bắt buộc trước STOP): `./run.ps1 validate hello` exit 0 · `./run.ps1 run hello "x" -Mock` done · `./run.ps1 selftest` PASS (11/11). Dọn `.runs/` test sau verify.
- **Mock-path BẤT BIẾN**: `-Mock` + `ENGINE_MOCK_ROUTER` không đổi semantics. Mọi thay đổi engine là ADDITIVE.
- **Key bridge mới `*_ref`** (I.C.1) phải reserved-aware: thêm vào `$script:ReservedKeys` + validate chặn làm `output_key`.
- **⚠️ Session I.D.2 ĐỐT TOKEN** (real-run) — STOP chờ user bật đèn xanh TRƯỚC khi chạy `run` không `-Mock`.

> **Ngoại lệ team-lead:** nếu user giao cả Phase I cho lead mà không giới hạn "1 session", lead làm hết các session liên tiếp (vẫn update CHECKPOINT + STOP gate sau MỖI session). RIÊNG **I.D.2 luôn dừng chờ user-gate** dù lead-mode (đốt token).

---

## Quyết định user đã chốt (2026-06-04)

- **D-I1** — Lossy handoff = **LAYER CẢ HAI**: artifact-by-reference (lossless) làm nền + conditional-trim CHỈ khi single-consumer.
- **D-I2** — Scope = **đủ cả 6 hạng mục** (đo · model-tier · siết template · artifact-by-ref · prompt-caching đào sâu · handoff-output).
- **D-I3** — Real-run burn = **user-gate 1 session cuối** (I.D.2); mọi session khác mock-only.

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 9 | 0 | 0% |
| Sub-phase pass | 4 (A/B/C/D) | 0 | 0% |
| Harness đo token | `run.ps1 tokens` + baseline.md | — | — |
| Token giảm real-run | giảm rõ (≥20% kỳ vọng) | — | — |
| Regression (validate/run-Mock/selftest) | PASS mỗi session | — | — |

---

## Đang ở đâu

- **Phase**: I.A (Đo lường)
- **Session kế tiếp**: **I.A.1** — Bắt usage từ JSON (`.usage`/cache/cost) trong `lib/claude.ps1` + emit event `node_usage` + proxy mock (chars). Additive, chữ ký `Invoke-Claude` cũ vẫn callable.
- **Blocker**: —
- **Reference**: `PLAN.md` Phase I.A → Session I.A.1

---

## Per-session log

_(chưa có session nào — cập nhật sau mỗi session)_

<!--
### YYYY-MM-DD — Session I.A.1
- **Done**:
- **Output**:
- **Gate**: pass/fail (kèm metric)
- **Next**: I.A.2
- **Notes**:
-->

---

## Bản đồ session (tham chiếu nhanh PLAN.md)

| Session | Scope 1 dòng | STOP gate cốt lõi |
| --- | --- | --- |
| I.A.1 | Bắt usage JSON + event `node_usage` + proxy mock | events.ndjson có usage/proxy mỗi node; chữ ký cũ callable |
| I.A.2 | `run.ps1 tokens` + `engine/tokens.ps1` + baseline.md | `tokens loopy` in bảng; baseline.md có số ≥3 fixture |
| I.B.1 | Model-tier router/gate → Haiku (frontmatter) | agent branching/gate có `model:`; run -Mock done |
| I.B.2 | Siết template `input` bỏ key dư + guideline | fixture siết run -Mock done; proxy prompt giảm |
| I.C.1 | Artifact-by-reference `{{key_ref}}` (ngưỡng) | consumer prompt chứa path không full text; `_ref` reserved |
| I.C.2 | Handoff-output đích (payload per-successor, xây trên J) | payload nhánh-chọn flow đúng; branchy/2-part PASS |
| I.C.3 | Conditional-trim `Test-SingleConsumer` (bảo thủ) | single→trim-eligible, multi-consumer→giữ full (lossless) |
| I.D.1 | Prompt-caching verify/wire/document (mock-only) | caching.md kết luận rõ; mock-path bất biến |
| I.D.2 | ⚠️ REAL-RUN token report trước/sau (USER-GATE, đốt token) | token-report.md số thật giảm rõ + lossless path thực |

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-06-04 | Created from `PLAN.md` | planner |
