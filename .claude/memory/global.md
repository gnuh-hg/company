# global — HQ-team

> Ghi chú cross-cutting: con người, quyết định kiến trúc, phạm vi engine.
> Format entry: `## <YYYY-MM-DD HH:MM> — <slug>`. Cap N=10 khi đọc. Xem `README.md`.

<!-- entries below, mới nhất ở cuối -->

## 2026-06-03 10:00 — q3-reframe-hq-builds-branches-not-apps

VAI TRÒ HQ-team (user chốt, đảo một phần Q2): HQ KHÔNG build app/web trực tiếp. HQ build **CƠ SỞ CỦA CHI NHÁNH** = một chi nhánh cấu hình sẵn, chạy được, đặt tại `projects/<branch>/`:
- `workflow.json` (engine pipeline — nodes/edges/entry/max_steps hoặc pipeline v1)
- roster agent `.md` (chọn/biến tấu từ `catalog/`), thường ở `projects/<branch>/agents/`
- scaffold chi nhánh cần
Sau đó CHI NHÁNH mới là người build app/web (qua engine + agent của nó).

Hệ quả (đảo Q2):
- Engine = OUTPUT MEDIUM của HQ (HQ build workflow.json), KHÔNG còn "engine không phải HQ".
- `catalog/` = MENU lắp chi nhánh lại (Q2 nói "không phải menu" → sai, đảo lại).
- builder: Write/Edit workflow.json + agent .md + scaffold TRỰC TIẾP (vẫn KHÔNG `autobuild` — đã xóa). Smoke = `run.ps1 validate <branch>` exit 0.
- tester: verify chi nhánh bằng `run.ps1 validate <branch>` exit 0 + `run.ps1 run <branch> "..." -Mock` done (+ output_keys non-empty / check). KHÔNG còn "KHÔNG run.ps1".
- planner/cto: plan/thiết kế là VỀ chi nhánh (pipeline + roster), không phải app.
Vẫn giữ: giao tiếp prose (không JSON ceremony giữa teammate — nhưng workflow.json LÀ artifact, khác chuyện đó). Memory store `.claude/memory/` (HQ) vs `company/memory/` (engine) vẫn tách.
