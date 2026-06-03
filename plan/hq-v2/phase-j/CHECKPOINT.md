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
   - `./run.ps1 selftest` → `9/9 PASS` (hoặc số mục hiện tại nếu J.4 thêm mục)
3. **Sửa logic ở hàm thuần testable** (`Get-RouterChoices`, `Write-RouteIssue`, `Get-RouterPayload`), KHÔNG nhồi vào nhánh direct-run. Module dot-source-safe.
4. **Chỉ thêm khả năng, không break tương thích ngược**: workflow không dùng router vẫn chạy y hệt; router chỉ in nhãn đơn vẫn hoạt động (payload = `""`).
5. **Không retry khi nhãn sai**: ghi `Write-RouteIssue` → `throw` ngay. Không re-ask model.
6. **`route-issues.ndjson` ghi tập trung tại `company/issues/route-issues.ndjson`** (gitignored `issues/*.ndjson`; mỗi entry mang `run_id`) — KHÔNG ghi vào `company/issues/team-issues-queue.md` (cái đó cho HQ-team native behave).
7. **Chỉ thao tác trong `company/`**.

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 5 | 0 | 0% |
| Hàm thuần mới | 3 (Get-RouterChoices, Write-RouteIssue, Get-RouterPayload) | 0 | 0% |
| Regression gate pass | 5 lần (cuối mỗi session) | 0 | 0% |
| Mock-path bất biến | confirm mỗi session | 0 | 0% |

---

## Đang ở đâu

- **Phase**: 1
- **Session kế tiếp**: J.1 — Hàm `Get-RouterChoices` + wire suffix bơm choices vào prompt router real-mode
- **Blocker**: —
- **Reference**: `PLAN.md` Phase 1 → Session J.1

---

## Per-session log

_(chưa có — Phase J chưa bắt đầu)_

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-06-03 | Created from `PLAN.md` | @planner |
