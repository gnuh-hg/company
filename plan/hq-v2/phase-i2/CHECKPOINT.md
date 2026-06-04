# CHECKPOINT — Phase I2: Handoff-by-workspace + model-tiering có nguyên tắc (hq-v2)

> Sổ tay tiến độ. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu"). **STOP NGAY** khi đạt STOP gate — không tham session kế.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log".
- **Regression mỗi session chạm engine** (bắt buộc trước STOP): `./run.ps1 validate hello` exit 0 · `./run.ps1 run hello "x" -Mock` done · `./run.ps1 selftest` PASS (**12/12**, hoặc 13 nếu I2.B.2 thêm fixture). Dọn `.runs/` test sau verify.
- **Mock-path BẤT BIẾN**: `-Mock` + `ENGINE_MOCK_ROUTER` không đổi semantics. Mọi thay đổi engine ADDITIVE; graph cũ (no `handoff`) chạy y hệt.
- **Key bridge mới** (`_brief`/`workspace`, I2.B) phải reserved-aware: thêm vào `$script:ReservedKeys` / suffix-check + validate chặn làm `output_key` (như `_ref`/`_payload`).
- **⚠️ Session I2.E.1 ĐỐT TOKEN** (real-run A/B) — STOP chờ user bật đèn xanh + chốt fixture/ngân sách TRƯỚC khi chạy `run` không `-Mock`.

> **Ngoại lệ team-lead:** nếu user giao cả Phase I2 cho lead mà không giới hạn "1 session", lead làm hết các session liên tiếp (vẫn update CHECKPOINT + STOP gate sau MỖI session). RIÊNG **I2.E.1 luôn dừng chờ user-gate** dù lead-mode (đốt token).

---

## Quyết định cần user chốt (Q1–Q4 — trước/khi approve)

- **[?] Q1** — Brief do **producer agent tự viết** (default) hay engine sinh tĩnh?
- **[?] Q2** — Handoff-by-workspace **opt-in qua field `handoff: workspace`** (default) hay default mọi output lớn?
- **[?] Q3** — Lean system-prompt: **áp fixture/catalog mẫu** (default) hay viết lại toàn bộ 17 catalog?
- **[?] Q4** — Real-run A/B fixture = **web-demo-scale 11 node** (default) + ngân sách token? (todo-web 5 node quá ngắn để thấy lợi.)

> 4 đề xuất default ghi trong `PLAN.md` §"Quyết định cần user chốt". Lead chốt với user TRƯỚC khi thực thi I2.B.1 (Q1/Q2) và I2.E.1 (Q4); Q3 trước I2.C.2.

---

## Bối cảnh kế thừa (Phase I — DONE 2026-06-05)

- **Phát hiện cốt lõi:** real input KHÔNG giảm dù mock-proxy giảm — vì **system-prompt + tool-defs chi phối ~50–80% input/call**, không phải template. Template-trim ≈ 0 real savings.
- **Nền sẵn dùng:** `{{key_ref}}` (artifact-by-reference, I.C.1) · `run.ps1 tokens` + `node_usage` event (I.A) · `Test-SingleConsumer` (I.C.3) · `model:` frontmatter (5.1) · prompt-caching tự-hoạt xác nhận (I.D).
- **Bẫy đã đo:** `Read` tool-def cộng token → handoff-by-file chỉ net-thắng khi output lớn + đọc-một-phần + pipeline dài + rút system/tool song song.

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 9 | 0 | 0% |
| Sub-phase pass | 5 (A/B/C/D/E) | 0 | 0% |
| Estimator giải phẫu input | `tokens -Anatomy` + input-anatomy.md | — | — |
| Handoff-by-workspace chạy được | fixture handoff-demo done + selective | — | — |
| Real input giảm (real-run) | giảm rõ (nhắm system/tool/user) | — | — |
| Regression (validate/run-Mock/selftest 12/12) | PASS mỗi session | — | — |

---

## Đang ở đâu

- **Phase**: I2.A (Giải phẫu input) — chưa bắt đầu
- **Session kế tiếp**: **I2.A.1** — Estimator thành phần input (`run.ps1 tokens <proj> -Anatomy` / `engine/anatomy.ps1`): tách system_chars / tool_def_estimate / user_msg_chars / mem_chars mỗi node + `input-anatomy.md` 3 fixture. Mock, không đốt token.
- **Blocker**: — (Q1/Q2 chốt trước I2.B.1, không chặn I2.A.1)
- **Reference**: `PLAN.md` Phase I2.A → Session I2.A.1
- **Lưu ý orchestration**: nếu chạy qua HQ-team self-mod → chain gọn self-builder → self-tester (như Phase I); KHÔNG auto-commit (D-S2 — bài học Phase I: teammate đã commit+push trái phép `fa6b386`, lead phải nhắc RÕ "KHÔNG git commit/push" trong brief + kiểm `git log` sau mỗi session).

---

## Per-session log

(chưa có — bắt đầu từ I2.A.1)

---

## Bản đồ session (tham chiếu nhanh PLAN.md)

| Session | Scope 1 dòng | STOP gate cốt lõi |
| --- | --- | --- |
| I2.A.1 | Estimator giải phẫu input (system/tool/user/mem) + input-anatomy.md | `tokens -Anatomy` bảng %-share; anatomy.md ≥3 fixture chỉ rõ phần chi phối |
| I2.B.1 | Thiết kế giao thức brief + field `handoff` + reserved `_brief`/`workspace` (schema/validate) | helper Get-HandoffBrief unit test; validate chấp nhận+chặn; selftest 12/12 |
| I2.B.2 | Wire executor + fixture handoff-demo (pipeline dài) | consumer prompt = brief+path không full text; graph cũ y hệt; selftest 12/13 |
| I2.B.3 | Selective-read guideline + đo proxy net-thắng + ngưỡng | guideline+ngưỡng ghi; proxy user_msg giảm đo được |
| I2.C.1 | Tool-set tối thiểu mỗi agent (frontmatter) | ≥2 agent rút tool; estimator tool_def giảm; run -Mock done |
| I2.C.2 | Lean system-prompt convention + áp mẫu | ≥2–3 agent lean; estimator system_chars giảm; selftest 12/12 |
| I2.D.1 | Bảng vai→hạng model + áp đa-hạng (không cào bằng) | bảng tier catalog; ≥3 agent model: đa hạng; run -Mock done |
| I2.E.1 | ⚠️ REAL-RUN A/B (USER-GATE, đốt token) | token-report-v2.md real input giảm + breakdown + lossless+chất-lượng |

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-06-05 | Created from `PLAN.md` | planner (lead) |
