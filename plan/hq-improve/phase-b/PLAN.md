# PLAN — Phase B: CLI & docs ergonomics (#1)

> Sau toàn bộ Phase B: surface lệnh `run.ps1` **đặt lại tên rõ ràng + nhóm theo verb + lớp alias tương thích** (lệnh cũ vẫn chạy), README viết lại tách bạch "chạy HQ" vs "chạy project con" vs "nối node", + lệnh `test` gom mọi test script, + vá các finding doc/UX gọn (A-01, A-10) — người mới đọc doc là chạy được, không hỏi thêm.

---

## Context

- **Vì sao chia nhiều session**: Phase B vừa **đổi tên triệt để 12 lệnh** (chốt user) — đụng `engine/run.ps1` (dispatcher `Invoke-Dispatch` + `Show-Help`) — vừa viết lại README (~370 dòng) + thêm runner `test` + vá finding. Đổi tên cần 1 bước **đề xuất + user duyệt tên** trước khi code (PLAN immutable, tên không thể tự quyết). Gom hết vào 1 chat sẽ ẩu. Chia theo *bước có gate* để mỗi chat làm trọn 1 bước rồi STOP.
- **De-risk đã xác nhận (A.0 khảo sát)**: test script (`hq-tests`/`hq-graph-tests`/`e2e-harness-tests`) + 7 `p-*/stamp.ps1` **gọi hàm trực tiếp** (`Invoke-Workflow`, `Test-StructuralGate`, `Invoke-E2E`…), KHÔNG đi qua `Invoke-Dispatch` bằng command-string. → **Đổi tên command KHÔNG làm vỡ test**. Lớp alias chủ yếu phục vụ thói quen user + ví dụ README, không phải để cứu script. Rủi ro hồi quy chính = README/docs lệch tên + `Show-Help`.
- **Quyết định đã chốt (user, 2026-05-28)**:
  - **D-B1. Đổi tên triệt để + lớp tương thích**: đặt lại tên/nhóm 12 lệnh cho rõ (HQ vs project vs author/nội bộ), **giữ alias tên cũ** để không vỡ thói quen/script. Ẩn lệnh nội bộ khỏi help chính.
  - **D-B2. `-Router` (A-24) doc-only ở B**: B chỉ **tài liệu hoá** "`-Router` bắt buộc cho graph có router" + gợi ý `ENGINE_MOCK_ROUTER` (A-01). Heuristic suy RouterSpec từ graph → **Phase C** (A-24). Không đụng hành vi `-Router`/`ENGINE_MOCK_ROUTER` ở B.
  - **D-B3. `run.ps1 test` (CC-c) chỉ là surface gom runner ở B**: thêm lệnh chạy hết script + báo tổng exit. **Bổ assert nội dung** cho stamp + auto-verify mem-demo "run2 khác run1" → **Phase C**.
- **Ràng buộc bất biến (6 quy ước `company/CLAUDE.md`)** — đặc biệt:
  - **#4 một surface lệnh**: gom/đổi tên *trong* `run.ps1`, **KHÔNG** mọc entry point mới. `test` cũng là 1 command của `run.ps1`.
  - **#3 mock bất biến**: mọi thay đổi giữ `-Mock`/`ENGINE_MOCK_ROUTER` y nguyên. B không sửa engine executor — chỉ dispatcher + help + docs + runner.
  - **#1 engine code cố định**: B đụng dispatcher (routing/UX) + thêm runner, KHÔNG đổi logic workflow/graph/validate.
- **Out of scope (bàn giao — xem §"Bàn giao sang C")**: mọi fix bug/de-chắp-vá có finding Phase đích = C (A-02..A-25 trừ phần doc). Heuristic `-Router`. Assert nội dung test. Stream output app (A-15 → E). HITL (D/F).

---

## Pipeline 2 sub-phase / 4 session

```
[B-I — CLI surface]
[B.1] CLI redesign proposal + khảo caller ──► cli-design.md (bảng tên cũ→mới + alias) + USER GATE tên
                                                  │
[B.2] Implement rename + alias compat ───────► run.ps1 (Invoke-Dispatch + Show-Help nhóm) + A-10 + A-01-hint
                                                  │
[B.3] Runner `run.ps1 test [all]` (CC-c) ────► lệnh test gom 3 script+7 stamp+mem-demo → tổng exit
                                                  │
[B-II — docs + gate]
[B.4] README rewrite + doc finding + gate ───► README mới + doc sandbox/resolve/logs/router + ROADMAP carry-over + USER GATE
```

---

## Phase B — CLI & docs ergonomics

**Mục tiêu**: lệnh dễ hiểu (tên rõ + nhóm), mô hình HQ-vs-project-vs-wiring tách bạch trong doc, runner test gom, finding doc/UX gọn đóng. Engine executor KHÔNG đổi (chỉ dispatcher + help + docs + runner).

### Session B.1 — CLI redesign proposal + khảo caller
- **Scope**:
  - Khảo đủ caller: grep mọi nơi nhắc 12 lệnh (`README.md`, `engine/README` nếu có, comment trong `run.ps1`, `examples/*.ps1`, `hq/skills.md`). Lập danh sách vị trí phải sửa khi đổi tên.
  - Soạn `plan/hq-improve/phase-b/cli-design.md`: bảng **tên-cũ → tên-mới + nhóm verb + alias + ẩn/phơi** cho cả 12 lệnh (`run/resume/viz/validate/check/trial/build/e2e/e2efix/status/logs/edit` + lệnh mới `test`). Đề xuất nhóm (vd: *Run* = run/resume; *Inspect* = viz/validate/status/logs; *Test* = check/trial/test; *Build* = build/e2e/e2efix; *Author* = edit). Đánh dấu lệnh nội bộ/author-time ẩn khỏi help chính. Định nghĩa cơ chế alias (map tên-cũ→tên-mới trong `Invoke-Dispatch`, in deprecation note nhẹ hoặc im lặng — đề xuất + lý do).
  - Ghi rõ ràng buộc: tên mới giữ bất biến #4 (vẫn 1 surface), `build` vẫn nhận spec-file (không phải project) — không gộp nhầm.
- **STOP gate**: `cli-design.md` tồn tại với bảng đủ 13 lệnh (12 + `test`) có cột [tên cũ | tên mới | nhóm | alias | ẩn/phơi]; danh sách caller-cần-sửa (file\:line) đầy đủ; **user duyệt bảng tên** (ghi xác nhận vào CHECKPOINT). 0 file code engine sửa.
- **Output artifact**: `plan/hq-improve/phase-b/cli-design.md` + user-approved naming table.

### Session B.2 — Implement rename + alias compat + finding CLI (A-10, A-01-hint)
- **Scope** (chỉ `engine/run.ps1`, có thể chạm `engine/lib/claude.ps1` cho A-01 hint nếu chọn hướng error-message):
  - Áp bảng tên mới (B.1 duyệt) vào `Invoke-Dispatch`: routing theo tên mới + **alias map** tên-cũ→tên-mới (allowlist command mở rộng giữ cả 2 bộ tên). `Show-Help` viết lại theo **nhóm verb**, ẩn lệnh nội bộ vào mục phụ/"advanced".
  - **A-10** (`run.ps1:99–102` Split-DispatchArgs): flag-có-value (`-Model`/`-Router`/`-Seed`/`-Branch`) đứng cuối thiếu value → in cảnh báo "flag X thiếu value" thay vì nuốt im.
  - **A-01** (doc/UX, phần help/hint — phần README để B.4): khi router throw ở mock-mode, thông báo lỗi gợi ý `ENGINE_MOCK_ROUTER='...'` (hoặc tối thiểu thêm dòng help). Chốt hướng (error-message vs help-only) trong session, ưu tiên ít chạm engine.
- **STOP gate** (regression đo được):
  - `./run.ps1 validate hello` exit 0 + `./run.ps1 run hello "x" -Mock` done (0).
  - **Alias**: mọi tên-cũ vẫn chạy (spot-check ≥4 lệnh: `run`/`validate`/`viz`/`e2e --help-path`).
  - **Tên mới**: chạy được (spot-check tương ứng).
  - 3 test script (`hq-tests`/`hq-graph-tests`/`e2e-harness-tests`) vẫn exit 0 (không vỡ — vì gọi hàm trực tiếp).
  - A-10: gõ `run hello "x" -Mock -Model` (thiếu value) → có cảnh báo.
  - Dọn `.runs/` sau verify. Engine executor (workflow/graph/validate) `git diff` sạch.
- **Output artifact**: `run.ps1` tên mới + alias + help nhóm + A-10 + A-01-hint.

### Session B.3 — Runner `run.ps1 test [all]` (CC-c surface)
- **Scope** (thêm 1 command vào `run.ps1` + có thể 1 module mỏng `engine/test-runner.ps1` dot-source-safe theo quy ước #5):
  - Lệnh `test [all]` chạy tuần tự: 3 test script (`hq-tests`/`hq-graph-tests`/`e2e-harness-tests`) + 7 `p-*/stamp.ps1` + mem-demo done-gate (2-run mock, start sạch `memory/` → dọn sau). Mỗi mục in 1 dòng PASS/FAIL + exit; cuối in bảng tổng; **exit = số mục fail** (đồng quy ước với check/validate).
  - **CHỈ surface gom** (D-B3): chạy + đếm + báo. KHÔNG thêm assert nội dung cho stamp, KHÔNG auto-verify "run2 khác run1" của mem-demo (→ C). mem-demo coi PASS nếu cả 2 run exit 0 (như baseline A.1) — ghi rõ giới hạn này trong output + CHECKPOINT.
  - Bảo đảm runner dọn artifact (`.runs/`, `mem-demo/memory/`, sandbox) sau khi chạy — không để lại rác (như quy ước test thủ công hiện tại).
- **STOP gate**: `./run.ps1 test` chạy đủ ≥11 mục, in bảng tổng, exit phản ánh số fail (baseline kỳ vọng: 3 script + 7 stamp + mem-demo đều pass → exit 0). Chạy lại `validate hello` + `run hello -Mock` vẫn xanh. Artifact dọn sạch sau chạy. Engine executor `git diff` sạch.
- **Output artifact**: command `test` + (tuỳ) `engine/test-runner.ps1`.

### Session B.4 — README rewrite + doc finding + ROADMAP carry-over + user gate
- **Scope**:
  - **README viết lại**: quickstart tách bạch **3 luồng** — (1) chạy HQ (`run hq`/`e2e hq` + `-Router`/`ENGINE_MOCK_ROUTER`), (2) chạy project con thường (hello/web-demo), (3) **nối node** (3 cách: `build` từ spec / `edit` TUI / app sau này). Bảng 13 lệnh theo **tên mới + nhóm** (đồng bộ `Show-Help`). Liệt kê alias tên-cũ ở 1 mục "tương thích".
  - **Doc finding**:
    - **A-01** (doc): ghi rõ "`-Mock` trần KHÔNG lái router; project có router cần `ENGINE_MOCK_ROUTER='coo:build;tester:pass'`".
    - **A-05** (doc thứ-tự-resolve): tài liệu hoá `Resolve-ProjectDir` ưu tiên `projects/` > `examples/` > top-level + footgun trùng tên sau promote. *(Cảnh báo runtime khi match >1 root → C.)*
    - **A-15** (doc): ghi "`run` chỉ in (N chars); dùng `logs <proj> [node]` để xem nội dung". *(Stream output trực tiếp → Phase E.)*
    - **A-24** (doc): "`-Router` bắt buộc cho graph có router; cú pháp `node:label;...`". *(Suy tự động → C.)*
    - **#2 sandbox**: tài liệu hoá `company/sandbox/` = khu nháp cô lập chạy THẬT của `trial`/`e2e`, gitignored, rỗng khi rảnh (không phải lỗi).
  - **Update `company/CLAUDE.md`** bảng "Bản đồ file": hàng mới cho `plan/hq-improve/phase-b/` + (nếu thêm) `engine/test-runner.ps1`; cập nhật mô tả `run.ps1`/`README.md` theo tên mới.
  - **Update `plan/hq-improve/ROADMAP.md`**: bảng tiến độ B ✅ + **§"Bàn giao B→C"** (xem dưới) ghi rõ phần B chạm-nhưng-hoãn để khi soạn Phase C biết đường.
- **STOP gate**: README có đủ 3 luồng quickstart + bảng 13 lệnh tên mới + mục alias + doc 5 finding (A-01/05/15/24 + sandbox); CLAUDE.md + ROADMAP cập nhật (B ✅ + §Bàn giao B→C); regression cuối (`validate hello` + `run hello -Mock` + `run.ps1 test` xanh); **user duyệt** README + đóng phase (ghi CHECKPOINT). Engine executor `git diff` sạch.
- **Output artifact**: `README.md` mới + CLAUDE.md/ROADMAP cập nhật. → Phase B đóng.

**Phase B gate** (sau B.4): surface lệnh tên mới + alias + help nhóm; README 3 luồng; `run.ps1 test` gom runner; A-01/A-10 + doc A-05/A-15/A-24 + sandbox đóng; mọi test cũ xanh; ROADMAP §Bàn giao B→C ghi đủ; user duyệt. → cập nhật ROADMAP (B ✅).

---

## Bàn giao sang C (ghi vào ROADMAP cuối B.4 — để soạn Phase C biết đường)

> B *chạm* các vùng sau nhưng **cố ý hoãn phần sâu** cho C. Ghi vào `ROADMAP.md` §"Bàn giao B→C" khi đóng B.

| Finding/Cross-cut | B làm gì | C phải làm tiếp |
| --- | --- | --- |
| **A-24** `-Router` leaky | Doc-only: "bắt buộc cho graph có router" | Heuristic **suy RouterSpec happy-path từ graph** (chọn nhãn `when` đầu mỗi router) |
| **A-01** mock không lái router | Doc + error-hint `ENGINE_MOCK_ROUTER` | (đóng ở B nếu doc đủ) — liên đới A-02 router-spec keyed-by-agent (C) |
| **A-05** resolve projects>examples | Doc thứ-tự-resolve | **Cảnh báo runtime** khi tên gọn match >1 root |
| **A-15** log "(N chars)" | Doc "dùng `logs`" | *(không thuộc C)* — stream output trực tiếp → **Phase E** |
| **CC-c** test fragmentation | Surface `run.ps1 test` gom runner | **Bổ assert nội dung** cho 7 stamp (so node/edge kỳ vọng) + **auto-verify** mem-demo "run2 khác run1" |
| **A-10** flag thiếu value | Đóng ở B | — |

---

## Outcome cuối

- `engine/run.ps1`: 12→13 lệnh tên mới + nhóm verb + alias tên-cũ + help phân nhóm; A-10 + A-01-hint.
- `README.md`: 3 luồng quickstart (HQ / project / nối node) + bảng tên mới + doc sandbox/resolve/router/logs.
- `run.ps1 test`: 1 lệnh gom ≥11 test → tổng exit (surface; assert nội dung defer C).
- 0 thay đổi engine executor (workflow/graph/validate/bridge) — mock-path bất biến; mọi test cũ xanh.
- `ROADMAP.md` §Bàn giao B→C đầy đủ để Phase C khởi từ đó; gate đo lường: README 3 luồng + alias xanh + `test` chạy + user duyệt.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-05-28 | Initial | Soạn long-plan Phase B từ `plan/hq-improve/ROADMAP.md` §B + `phase-a/findings.md`. Chốt D-B1/B2/B3 (user 2026-05-28). 2 sub-phase / 4 session |
