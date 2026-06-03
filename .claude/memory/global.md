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

## 2026-06-03 21:17 — self-mod/phase-j-router-choices-payload

**What**: 5 session thêm 3 hàm engine + fixture + validate warn + docs:
- J.1: `Get-RouterChoices` + bơm suffix "chọn MỘT nhãn" vào prompt router real-mode (guard -not Mock)
- J.2: `Write-RouteIssue` ghi NDJSON vào `company/issues/route-issues.ndjson` + validate tập nhãn + throw fail-fast (không retry)
- J.3: `Get-RouterPayload` + auto-store `<output_key>_payload` trong context (pre-seed + runtime + resume)
- J.4: fixture `examples/branchy` 2-phần + `validate.ps1` WARN additive + selftest mục #10 `branchy/2-part-protocol` (selftest 9→10)
- J.5: docs `README.md` §router-choices + §2-phần + `CLAUDE.md` 4 hàng + `ROADMAP.md` Phase J DONE + `CHECKPOINT.md` 5 entries

**Why**: Phase J CD-2 — engine tự bơm tập nhãn hợp lệ cho router (agent không hardcode); nhãn sai → issue deterministic + fail-fast; router output 2-phần (payload + nhãn) → successor đọc payload qua `{{key_payload}}`; tương thích ngược hoàn toàn

**Files**: `engine/workflow.ps1` (J.1+J.2+J.3) · `engine/validate.ps1` (J.4 _payload warn) · `engine/test-runner.ps1` (J.4 selftest #10) · `examples/branchy/{workflow.json,agents/tier-router.md,agents/output.md}` (J.4) · `README.md`,`CLAUDE.md`,`plan/hq-v2/ROADMAP.md`,`plan/hq-v2/phase-j/CHECKPOINT.md` (J.5)

**Gate result**: selftest 10/10 PASS (5 lần qua 5 session) • validate hello/branchy/loopy exit 0 • run -Mock done trên hello/branchy/loopy • Write-RouteIssue unit test OK • Get-RouterPayload 3 case OK • validate WARN additive (exit 0) • mock-path bất biến toàn Phase J
**Commit**: user tự commit (approved 2026-06-03)
