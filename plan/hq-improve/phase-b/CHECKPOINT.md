# CHECKPOINT — Phase B: CLI & docs ergonomics

> Sổ tay tiến độ. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu. Đọc kèm `plan/hq-improve/phase-b/PLAN.md`.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu").
- **STOP NGAY** khi đạt STOP gate của session — không tham làm session kế tiếp.
- **Giữ engine executor bất biến**: B chỉ đụng `run.ps1` (dispatcher/help) + thêm runner `test` + docs. KHÔNG đổi logic `workflow.ps1`/`graph.ps1`/`validate.ps1`/`bridge.ps1`. Mock-path (`-Mock`/`ENGINE_MOCK_ROUTER`) giữ y nguyên (quy ước #3).
- **Hoãn cho C**: KHÔNG làm heuristic `-Router` (A-24), KHÔNG assert nội dung stamp/mem-demo (CC-c), KHÔNG cảnh báo runtime trùng-tên (A-05) — chỉ doc. Ghi §Bàn giao B→C vào ROADMAP ở B.4.
- **Sau mỗi session**: dọn `.runs/` + `examples/mem-demo/memory/` + sandbox; `git diff` engine executor phải sạch.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log".

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 4 | 4 | 100% |
| Tên lệnh đổi + alias | 13 lệnh | 13 (3 đổi+9 giữ+selftest) | 100% |
| Finding đóng (A-01·A-10) + doc (A-05·A-15·A-24·sandbox) | 6 | 6 ✅ | 100% |
| Runner `run.ps1 selftest` | 1 | 1 ✅ | 100% |
| User gate (B.1 tên · B.4 README) | 2 | 2 ✅ | 100% |

---

## Đang ở đâu

- **Phase**: B — B.1 ✅ · B.2 ✅ · B.3 ✅ · B.4 ✅ DONE (2026-05-29). **PHASE B ĐÓNG — user gate duyệt 2026-05-29** (kèm yêu cầu thêm callout "hq chỉ là một project" đầu §Surface lệnh — đã thêm).
- **Session kế tiếp**: → **Phase C** (Fix bug + de-chắp-vá). Soạn long-plan từ `ROADMAP.md` §Bàn-giao-B→C + `phase-a/findings.md` §Tổng-hợp 13 bước (22 finding, 3 P1: A-18/A-17/A-08).
- **Blocker**: —
- **Bảng tên DUYỆT (immutable cho B.2-B.4)**: đổi 3 lệnh `viz→graph` · `e2e→autobuild` · `e2efix→autofix`; thêm `selftest` (alias `test`); 9 lệnh giữ nguyên (run/resume/validate/check/trial/build/status/logs/edit). Alias **im lặng** (map tên-cũ→mới trong `Invoke-Dispatch`, không in note). Help nhóm theo trục PROJECT / BUILD / AUTHOR / Advanced. Chi tiết + caller-list + cấu trúc help: `cli-design.md`.
- **Reference**: `PLAN.md` Phase B → Session B.3.

---

## Per-session log

- **B.4 — README rewrite + doc finding + ROADMAP carry-over + user gate** (2026-05-29): Chỉ sửa **docs** (`README.md`/`CLAUDE.md`/`ROADMAP.md`) — engine executor + `run.ps1` KHÔNG đụng. (a) **README 3 luồng**: thay "Quickstart (engine)" bằng 3 luồng tách bạch — Luồng 1 chạy/soi project con (`graph`/`validate`/`run -Mock`/`status`/`logs`), Luồng 2 chạy HQ (`autobuild` + `-Router`), Luồng 3 nối node (`build`/`edit`/app-sau). (b) **Bảng 13 lệnh** gắn cột Nhóm (PROJECT/BUILD/AUTHOR/Advanced) + tên mới + `selftest` + mục **Tương thích** liệt kê 4 alias. (c) **Doc 5 finding**: A-05 footgun trùng-tên-sau-promote (§Surface lệnh), A-15 "`run` chỉ in N chars → dùng `logs`" (§Surface lệnh), A-24 cú pháp `-Router node:label;...` + "bắt buộc graph có router" (callout §autobuild), A-01 "`-Mock` trần KHÔNG lái router, cần `ENGINE_MOCK_ROUTER`" (callout §Router), #2 sandbox đã doc sẵn §Lúc-nào-vào-sandbox. (d) Đổi mọi ví dụ lệnh `viz/e2e/e2efix` → tên mới (giữ tên **file** `viz.ps1`/`e2e.ps1` + chú `(lệnh: ...)`); thêm `test-runner.ps1` vào cây thư mục + đoạn bộ-test. (e) **CLAUDE.md** Bản đồ file: +hàng `engine/test-runner.ps1`, mô tả `run.ps1`/`README.md` tên mới, hàng `phase-b/` → ✅ DONE. (f) **ROADMAP**: bảng tiến độ B ✅ DONE + §Bàn-giao-B→C chốt (mỗi finding ghi "B đã làm ✅ / C tiếp"). Regression cuối: `validate hello`=0 · `run hello -Mock`=done(0) · `selftest`=11/11 PASS exit 0; artifact dọn sạch (hello/.runs xoá, sandbox+mem-demo/memory rỗng). **STOP gate đạt — chờ user duyệt README đóng phase.**
- **B.3 — Runner `run.ps1 selftest [all]`** (2026-05-29): Thêm module mỏng **`engine/test-runner.ps1`** (dot-source-safe, quy ước #5) + wire `selftest` vào `engine/run.ps1`. Module: `Invoke-SelfTest` chạy 11 mục → (a) 3 test script (`hq-tests`/`hq-graph-tests`/`e2e-harness-tests`) qua subprocess `pwsh -NoProfile -File` (mỗi script tự `exit $fails`) → bắt `$LASTEXITCODE`; (b) 7 `p-*/stamp.ps1` qua subprocess (Get-ChildItem `p-*` sort); (c) mem-demo done-gate 2-run `-Mock` **inline** (gọi `Invoke-Workflow ... 6>$null` để nuốt Write-Host, assert `(Get-RunState).status -eq 'done'` cả 2 run) + `Clear-MemDemoArtifacts` dọn `.runs/`+`memory/` trước & sau (try/finally). In PASS/FAIL từng mục (`Write-SelfTestLine`) + bảng tổng; **exit = số mục fail** (đồng quy ước check/validate). `$script:SelfTestEngineDir = $PSScriptRoot` để định vị `examples/` ổn định. Wire run.ps1: dot-source `test-runner.ps1`; allowlist +`selftest`; aliasMap +`'test'='selftest'`; Show-Help +mục `Advanced: selftest [all]` + dòng Tương thích → `viz/e2e/e2efix/test`; header comment +selftest; **xử lý `selftest` TRƯỚC project-count check** (không cần `<project>`, giống `build` được xử lý sớm). **Giới hạn B chốt** (D-B3): chỉ kiểm exit 0 — KHÔNG assert nội dung stamp + KHÔNG verify mem-demo "run2≠run1" (defer C); in 1 dòng DarkGray nhắc giới hạn. STOP gate đạt: `selftest`=11/11 PASS exit 0 · alias `test`=exit 0 · `validate hello`=0 · `run hello -Mock`=0 · help hiện Advanced+selftest+Tương thích · artifact sạch (mem-demo/memory + sandbox rỗng, dọn hello/.runs). Engine executor (workflow/graph/validate/bridge) KHÔNG đụng — chỉ +1 dòng dot-source ở run.ps1 + file mới test-runner.ps1.
- **B.2 — Implement rename + alias + A-10 + A-01-hint** (2026-05-29): Sửa **chỉ `engine/run.ps1`** (engine executor bất biến). (a) **3 đổi tên** `viz→graph`/`e2e→autobuild`/`e2efix→autofix`: case switch + usage-string + allowlist + header comment. (b) **aliasMap im lặng** `@{viz=graph;e2e=autobuild;e2efix=autofix}` ngay sau `$command.ToLower()` → tên cũ route thẳng tên mới. (c) **Show-Help nhóm** PROJECT/BUILD/AUTHOR + dòng "Tương thích". (d) **A-10**: `Split-DispatchArgs` flag-có-value (`-Model/-Router/-Seed/-Branch`) thiếu value cuối → `Write-Warning` thay vì nuốt im. (e) **A-01-hint**: helper `Show-RouterHint` (dispatcher-level, KHÔNG đụng engine) in gợi ý `$env:ENGINE_MOCK_ROUTER` khi router throw "không khớp 'when'" dưới `-Mock` mà chưa set env; gọi trong catch của `run`/`resume`. **Deviation chốt**: `selftest` cố ý hoãn TRỌN sang B.3 (allowlist/alias/help/branch) — tránh advertise command rỗng trong B.2 (cli-design B.2-table ghi "thêm selftest ở allowlist" nhưng tách runner ở B.3 ⇒ wire chung 1 lần ở B.3 sạch hơn). STOP gate đạt: validate hello=0 · run hello -Mock=0 · graph/viz/autobuild/e2e/e2efix alias đúng exit · 3 test script (hq-tests/hq-graph-tests/e2e-harness-tests)=0 · A-10 warning hiện · A-01 hint hiện trên `run hq -Mock`. Dọn `.runs/` sạch.
- **B.1 — CLI redesign proposal + khảo caller** (2026-05-29): Khảo caller toàn repo → xác nhận examples/*.ps1 + 7 stamp.ps1 gọi hàm trực tiếp (KHÔNG command-string); HQ agents (builder/cto/tester/planner) + build-spec.md gọi runtime chỉ `build/validate/check/trial` qua `ENGINE_RUN`. Soạn `cli-design.md`: bảng 13 lệnh (tên cũ→mới + nhóm + alias + ẩn/phơi) + cơ chế aliasMap + cấu trúc Show-Help theo trục + danh sách caller file:line. **User duyệt** (AskUserQuestion 3 câu, chọn cả 3 Recommended): đổi 3 jargon (viz→graph, e2e→autobuild, e2efix→autofix), lệnh mới = selftest (alias test), alias im lặng. 0 file code engine sửa. STOP gate đạt.

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-28 | Created from `PLAN.md` | @claude |
| 2026-05-29 | B.1 DONE — `cli-design.md` + user duyệt bảng tên (3 đổi + selftest + alias im lặng) | @claude |
| 2026-05-29 | B.2 DONE — `run.ps1` rename(3)+aliasMap+Show-Help nhóm+A-10+A-01-hint; selftest hoãn B.3; STOP gate xanh | @claude |
| 2026-05-29 | B.3 DONE — `engine/test-runner.ps1` (Invoke-SelfTest gom 3 script+7 stamp+mem-demo) + wire `selftest`(alias `test`) vào run.ps1; 11/11 PASS exit 0; engine executor bất biến | @claude |
| 2026-05-29 | B.4 DONE — README 3 luồng + bảng 13 lệnh + doc A-01/05/15/24+sandbox; CLAUDE.md/ROADMAP cập nhật (B ✅ + §Bàn-giao-B→C chốt); regression xanh; chỉ docs (engine + run.ps1 bất biến); chờ user gate | @claude |
| 2026-05-29 | **PHASE B ĐÓNG** — user duyệt gate B.4; thêm callout "hq chỉ là một project, lệnh nhận `<project>` dùng chung, chỉ autobuild/autofix gắn riêng hq" đầu §Surface lệnh README | @user+@claude |
