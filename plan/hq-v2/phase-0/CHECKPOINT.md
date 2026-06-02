# CHECKPOINT — Phase 0: Dọn sạch hq-workflow

> Sổ tay tiến độ. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu").
- **STOP NGAY** khi đạt STOP gate của session đó — không tham làm session kế.
- **Nguyên tắc bất biến**: CHỈ xóa những gì gắn chặt với HQ-workflow. `catalog/`, `patterns/`, `engine/pattern.ps1`, `engine/sandbox.ps1`, toàn bộ executor/validate/graph/check/save-graph/edit → **KHÔNG ĐỤNG**.
- **Engine executor BẤT BIẾN**: `git diff engine/` chỉ được chứa `e2e.ps1`/`spec.ps1`/`run.ps1`/`test-runner.ps1` (các file đang sửa); `workflow.ps1`/`bridge.ps1`/`validate.ps1`/`graph.ps1`/`sandbox.ps1`/`check.ps1`/`save.ps1`/`pattern.ps1` = 0 byte diff.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm entry "Per-session log". Dọn `.runs/` test sau verify.
- **⚠️ Cross-cutting H.4**: khi soạn `hq-cto.md` (session H.4), PHẢI thêm guard anti-pattern: "catalog = tham khảo domain, KHÔNG phải menu lắp role vào pipeline; hq-cto KHÔNG xuất build-spec JSON, KHÔNG lắp workflow.json từ catalog." Xem `PLAN.md` §Cross-cutting.

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 2 (0.1 + 0.2) | 2 | 100% |
| File HQ xóa (engine/) | 2 (e2e.ps1, spec.ps1) | 2 | 100% |
| File HQ xóa (examples/) | 2 (e2e-harness-tests.ps1, broken-web/) | 2 | 100% |
| run.ps1 lệnh HQ bỏ | 3 (build, autobuild, autofix) | 3 | 100% |
| App hq special-case bỏ | 2 (server.mjs, App.jsx) | 2 | 100% |
| Docs cập nhật | 3 (README, CLAUDE.md, ROADMAP) | 3 | 100% |
| Selftest mục sau dọn | 9/9 PASS | 9/9 PASS ✅ | 100% |

---

## Đang ở đâu

- **Phase**: 0 — **✅ DONE** (cả 2 session xong)
- **Session kế tiếp**: không — Phase 0 hoàn tất. Tiếp theo: Phase H Session H.4 (hq-cto)
- **Blocker**: không

---

## Per-session log

| Session | Date | Kết quả | Ghi chú |
| --- | --- | --- | --- |
| 0.1 | 2026-06-02 | ✅ DONE | engine/e2e.ps1 + engine/spec.ps1 + examples/e2e-harness-tests.ps1 + examples/broken-web/ xóa; run.ps1 bỏ build/autobuild/autofix + alias e2e/e2efix; test-runner 10→9 mục; selftest 9/9 PASS |
| 0.2 | 2026-06-02 | ✅ DONE | app/server.mjs + App.jsx bỏ hq special-case; README.md rewrite (2 luồng, bỏ HQ quickstart/lệnh HQ, §HQ → native team note); CLAUDE.md cập nhật (e2e/spec/broken-web ~~ĐÃ XÓA~~, test-runner 9 mục, run.ps1 + README entry); ROADMAP Phase 0 = ✅ DONE; selftest 9/9 PASS |

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-06-02 | Created from `PLAN.md` | @planner |
| 2026-06-02 | Session 0.1 DONE | Claude |
