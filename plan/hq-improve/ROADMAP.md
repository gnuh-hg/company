# HQ Improve — Roadmap chia phase (hardening + CLI + app local)

> Bản đồ chia đợt cải thiện HQ thành các phase độc lập; **mỗi phase = 1 long-plan** sẽ soạn riêng khi user yêu cầu (giống `plan/hq-build/ROADMAP.md`). File này KHÔNG phải long-plan — chỉ mô tả *cần làm gì* + *cần làm rõ gì* để mỗi lần dựa vào đây dựng PLAN/CHECKPOINT.
>
> **Quy ước thư mục đợt này:** ROADMAP + mọi phase long-plan nằm gọn trong `plan/hq-improve/` (tránh đụng `plan/hq-build/phase-*` của đợt build cũ). Mỗi phase = `plan/hq-improve/<phase-slug>/PLAN.md` + `CHECKPOINT.md`.

---

## Nền tảng đã có (KHÔNG build lại)

- **Toàn bộ HQ đã DONE** (Phase R/0/1/2/3/4/5/M — xem `plan/hq-build/ROADMAP.md`): engine v2 (single-cursor walk, router OR, loop + `max_steps`, resume, mock offline), catalog 17 vai, 6 pattern robustness, Tester 2 tầng + sandbox, memory 2 tầng, 6 agent HQ, `hq/workflow.json` 11 node, E2E thật (`e2e`/`e2efix`) đã promote branch thật.
- **Đây là đợt CẢI THIỆN trên nền đó** — không phải build mới. Mục tiêu: chữa các vấn đề lộ ra sau khi build xong (CLI khó dùng, log trống, workflow khó xem) + dọn chắp vá + thêm app local.
- **Ràng buộc bất biến (giữ nguyên 6 quy ước trong `company/CLAUDE.md`):**
  1. Engine là code cố định; agent `.md` chỉ chứa system prompt.
  2. **`workflow.json` chỉ ngữ nghĩa — KHÔNG BAO GIỜ lưu toạ độ.** ⚠ App vẽ graph PHẢI tôn trọng điều này: toạ độ là chuyện của app, lưu RIÊNG (xem D-3), không nhét vào workflow.json.
  3. Mock được offline (`-Mock` + `ENGINE_MOCK_ROUTER`) — mọi thay đổi engine phải giữ mock-path bất biến.
  4. Một surface lệnh duy nhất (`run.ps1`). Cải thiện CLI = dọn/gom *trong* surface này, KHÔNG mọc entry point mới.
  5. Module dot-source-safe (guard `InvocationName`/`Line`).
  6. Chỉ thao tác trong `company/`.

---

## Vấn đề khởi phát (nguồn của roadmap này)

Bốn vấn đề user nêu + thực trạng đã soi trong code:

- **#1 — CLI khó hiểu (ưu tiên cao nhất).** 12 lệnh (`run/resume/viz/validate/check/trial/build/e2e/e2efix/status/logs/edit`) + mô hình tư duy nặng: đọc README không rõ **lệnh nào chạy HQ vs lệnh nào chạy project con**, "nối node" làm bằng cách nào (`build` từ spec? `edit` TUI? sửa tay?), và 4 nơi artifact đi tới (`.runs/` vs `projects/` vs `sandbox/` vs gốc). → Cần **gom/đặt lại tên lệnh + làm rõ mô hình + viết lại doc**.
- **#2 — Sandbox để làm gì (ĐÃ TRẢ LỜI — không phải lỗi).** `company/sandbox/` = khu nháp cô lập để chạy THẬT (gọi model, sinh file) mà không bẩn project gốc; dùng bởi `trial` (tier thật) và `e2e`/`e2efix` (build branch rồi promote). Gitignored, rỗng khi rảnh. → Chỉ cần **tài liệu hoá rõ hơn** (đưa vào phase CLI/doc), không cần sửa cơ chế.
- **#3 — Log chạy quá trống + thiếu human-in-the-loop.** Log live chỉ in `node 'x' → done (N chars)` — KHÔNG có nội dung output (phải chạy `logs` SAU mới xem được). Và engine chạy một mạch entry→terminal, **không có điểm dừng để người duyệt plan / cấp quyền**. Đây là **thiếu sót kiến trúc**, không chỉ là hiển thị.
- **#4 — Xem workflow khó.** `viz` chỉ ra ASCII + file `.mmd` (cần renderer ngoài). Cần app trực quan: phóng to/thu nhỏ, kéo thả node, di chuyển màn hình.

**Ứng viên chắp vá đã thấy sơ bộ** (phase Audit sẽ xác nhận + bổ sung): mock router spec `-Router "a:l;b:l"` rò node-id nội bộ; `-Router` BẮT BUỘC cho dry-run gate (người phải tự khai path); path `engine/../hq/...` xấu trong log; `Get-AgentFrontmatter` là YAML-parser tự chế (chỉ hiểu inline list); Builder non-determinism (watch-item Phase 5, chỉ prompt-harden chưa guard); test rải rác nhiều script `examples/*-tests.ps1` không có runner gom.

---

## Cross-cutting — chốt TRƯỚC phase đầu (1 lần, áp mọi phase)

- **D-1. App stack** → **CHỐT (user): web tĩnh + server nhỏ.** UI = HTML/JS/canvas (hoặc SVG) thuần, không bundler/build step (hợp ngữ cảnh full-local + giống style frontend user quen). 1 server local nhẹ (PowerShell hoặc Python `http.server`-class) để: serve UI, đọc `workflow.json` + `.runs/`, và shell ra `run.ps1`. Không Electron/Tauri.
- **D-2. Vai trò app** → **CHỐT (user): xem + điều khiển + duyệt.** App không chỉ hiển thị: bấm nút chạy run, **duyệt plan / cấp quyền giữa chừng**. Hệ quả: engine PHẢI có cơ chế **pause-for-human** + phát event để app stream (Phase D). Đây là thay đổi kiến trúc lớn nhất đợt này — giải quyết trọn #3.
- **D-3. Toạ độ node** → **CHỐT: workflow.json coordinate-free (giữ bất biến #2); layout lưu RIÊNG phía app.** App tính **layout mặc định** (auto, vd theo rank topo) → user kéo thả → vị trí persist ở file app-side tách biệt (vd `<project>/.layout.json`, gitignorable) hoặc store của app, KHÔNG ghi vào workflow.json. Regen/đổi graph vẫn vẽ được (thiếu toạ độ → rớt về auto-layout).
- **D-4. Audit trước tiên** → **CHỐT (user): có phase Audit riêng mở đầu.** Phase A = chỉ điều tra (không sửa) → 1 tài liệu findings xếp ưu tiên (bug + chắp vá). Các phase sau bám theo đó. Hệ quả: scope các phase B+ là **provisional**, sẽ tinh chỉnh theo findings của A.

---

## Các phase (mỗi phase = 1 long-plan)

### Phase A — Audit (tìm lỗi + liệt kê chắp vá)
- **Mục tiêu:** bức tranh tổng + danh sách hành động xếp ưu tiên TRƯỚC khi sửa gì. KHÔNG sửa code ở phase này (chỉ đọc + ghi findings).
- **Xây gì:** `plan/hq-improve/phase-a/findings.md` — mỗi mục: { id, loại (bug/chắp-vá/doc/UX), file:line, mô tả, tác động, mức nghiêm trọng, đề xuất hướng, phase nào nên xử }. Quét: engine `*.ps1` (correctness + StrictMode edge), mock-path so real-path, watch-item Builder non-determinism, leaky abstraction (mock router/`-Router`), YAML-parser tự chế, test coverage (chạy lại toàn bộ `examples/*-tests.ps1` ghi nhận pass/fail hiện trạng làm baseline).
- **Cần làm rõ:** thang ưu tiên (P0 chặn / P1 nên / P2 nice); ranh giới "bug" vs "chắp vá" (chắp vá = chạy đúng nhưng khó mở rộng/sửa); có chạy lại E2E thật để soi không (đốt token — cân nhắc).
- **Phụ thuộc:** không (đi đầu).
- **Done-gate:** `findings.md` chốt — mọi mục có file:line + mức + phase đích; baseline test (pass/fail hiện tại) ghi lại; user duyệt danh sách + thứ tự xử.

### Phase B — CLI & docs ergonomics (#1)
- **Mục tiêu:** lệnh dễ hiểu, mô hình HQ-vs-project-vs-wiring rõ; người mới đọc doc là chạy được.
- **Xây gì:** rà 12 lệnh → gom/đặt lại tên/nhóm trong **cùng** `run.ps1` (giữ bất biến #4); làm rõ 3 cách "nối node" (spec→`build`, TUI `edit`, app kéo thả sau này); cờ rườm rà (vd `-Router` bắt buộc cho dry-run) → default/đoán thông minh hoặc tách lệnh riêng; path xấu `../` → resolve gọn khi in. Viết lại README (quickstart "chạy HQ" vs "chạy project" tách bạch) + tài liệu hoá sandbox (#2).
- **Cần làm rõ:** gom thế nào (nhóm theo verb? alias?) mà KHÔNG phá script đang gọi lệnh cũ (e2e harness, tests) — cần lớp tương thích hay đổi luôn; lệnh nào ẩn-khỏi-user (nội bộ) vs phơi ra; mức "đoán" cho `-Router` (suy path từ graph?).
- **Phụ thuộc:** Phase A (biết chỗ nào rối/chắp vá trong dispatcher). Cung cấp surface ổn định cho app (Phase E/F shell vào).
- **Done-gate:** surface lệnh mới + README viết lại; mọi test cũ vẫn xanh (hoặc cập nhật theo tên mới); 1 người-mới-giả-định theo quickstart chạy được cả "HQ build" lẫn "project thường" không hỏi thêm.

### Phase C — Fix bug + de-chắp-vá refactor
- **Mục tiêu:** xử các mục P0/P1 trong `findings.md` — sửa lỗi + thay cơ chế chắp vá bằng cách sạch, dễ mở rộng.
- **Xây gì:** theo findings (provisional cho tới khi A xong). Ứng viên hiện thấy: thay mock-router-spec rò node-id bằng cơ chế steer sạch hơn; `Get-AgentFrontmatter` YAML-parser tự chế → parser chắc hơn hoặc thu hẹp scope rõ ràng; Builder non-determinism → guard/retry có kiểm soát; gom test rải rác thành 1 runner (`run.ps1 test` chạy hết `examples/*-tests.ps1` + báo tổng).
- **Cần làm rõ:** thứ tự (bug chặn trước, refactor sau); refactor nào đáng (chắp-vá chạy-được không tự động đáng đập — cân nhắc chi phí/lợi); mỗi thay đổi giữ mock-path + regression xanh (bất biến #3).
- **Phụ thuộc:** Phase A (findings). Nên trước Phase D (HITL build trên engine đã sạch).
- **Done-gate:** mọi mục P0 + P1-đã-chọn đóng; regression engine xanh (`validate hello` + `run hello -Mock` + bộ test gom); không hồi quy lệnh Phase B.
- **✅ DONE (10/10 session, 2026-05-29 → 2026-05-30):** 22 finding Phase-đích-C đóng hết. C.1 A-18+A-17 edit data-loss · C.2 A-06 accessor 4→1 (`Get-Prop` lib/json) · C.3 A-07/11/12 cast-số+edges-vắng · C.4 A-14/25 `Test-PathInside` · C.5 A-04/16/13 validate-gap · C.6 A-19/20 stamp 1-nguồn+build-time-validate+CC-c stamp-assert · C.7 A-21/22/23 memory+CC-c mem-demo run2≠run1 · C.8 A-02/24 router keyed-by-node+dry-run heuristic · C.9 A-03/09/05-fix+CC-a frontmatter tĩnh · **C.10 A-08 stderr real-mode tách (`2>$errFile`+`claude.stderr.log`+`-RunDir`) + REAL-RUN xác nhận** (2 run user-approved: `autobuild hq -Real` → 6 LLM call output SẠCH, không DEP0190 poison; `run hello -Real` → terminal sạch, `claude.stderr.log` tách kênh đúng + 0 leak). Mock-path bất biến suốt (selftest 11/11 mỗi session). ⚠️ Real `autobuild hq` FAIL muộn (tester/record) do **builder non-determinism xoá sandbox `.runs` giữa run** — KHÔNG phải A-08, bàn giao CC-b Phase D/F (xem §Bàn giao). **✅ ĐÓNG PHASE (user duyệt 2026-05-30).**

### Phase D — Engine: human-in-the-loop + event stream (#3)
- **Mục tiêu:** engine biết **dừng chờ người** (duyệt plan / cấp quyền) + **phát event** để app theo dõi live. Đây là tiền đề kỹ thuật cho app "điều khiển + duyệt" (D-2).
- **Xây gì:** (1) cơ chế pause: node/gate khi tới → state `awaiting` + ghi context cần-duyệt + dừng; quyết định người (approve/reject/nhãn/grant) bơm vào → tiếp tục walk. (2) event stream: ghi event có cấu trúc mỗi lượt (start/done/awaiting/output) ra `<run>/events.ndjson` để server stream (SSE) — thay vì chỉ `run.log` + char-count.
- **Cần làm rõ:** **tái dùng resume** (pause = state đặc biệt, "duyệt" = resume kèm quyết định) hay cơ chế chờ mới; node type mới (`approval`/`gate`) vs cờ trên node sẵn có; "cấp quyền" map thế nào (duyệt workflow-level trước Builder vs `--permission-mode` của claude CLI); event schema (đủ cho live log đầy đủ output, không chỉ N chars); giữ headless-không-app vẫn chạy (pause auto-resume hoặc fail rõ khi không có người).
- **Phụ thuộc:** Phase C (engine sạch). Độc lập với Phase E — có thể song song.
- **Done-gate:** demo mock: graph có gate → chạy dừng ở `awaiting` → bơm quyết định → chạy tiếp tới terminal; `events.ndjson` ghi đủ chuỗi event + nội dung output mỗi node; chạy không-gate vẫn y như cũ (regression xanh).

### Phase E — App I: workflow viewer (#4)
- **Mục tiêu:** xem workflow trực quan, tương tác được — giải quyết #4.
- **Xây gì:** app web tĩnh + server nhỏ (D-1): đọc `workflow.json` → vẽ graph (node + cạnh có hướng + nhãn `when` cho router + back-edge của loop); **phóng to/thu nhỏ, kéo màn hình, kéo thả node**; layout mặc định auto + persist vị trí app-side (D-3, không đụng workflow.json); chọn project (HQ + examples + projects).
- **Cần làm rõ:** thư viện vẽ (canvas tay / SVG / lib nhẹ như vẽ graph) — ưu tiên không-build-step; auto-layout dùng gì (rank topo tự code vs lib); lưu layout ở đâu (`<project>/.layout.json` vs localStorage app); server tối thiểu (chỉ GET file) ở phase này hay dựng chung luôn với F.
- **Phụ thuộc:** Phase B (surface/đường dẫn ổn định) + D-1/D-3. KHÔNG cần Phase D.
- **Done-gate:** mở app local → chọn `hq` → thấy 11 node + 17 cạnh đúng topo; zoom/pan/drag mượt; kéo thả rồi reload giữ nguyên vị trí; đổi project vẽ lại đúng; workflow.json KHÔNG bị ghi toạ độ.

### Phase F — App II: live log + run control + duyệt (#3)
- **Mục tiêu:** xem log THẬT khi đang chạy (đầy đủ output từng bước) + chạy/duyệt từ app — giải quyết trọn #3.
- **Xây gì:** server stream `events.ndjson` (Phase D) qua SSE → app hiển thị live: node đang chạy, **nội dung output mỗi bước** (không chỉ N chars), highlight node trên graph (tích hợp Phase E). Nút: chạy run (`run`/`e2e`), và khi gặp gate `awaiting` → UI duyệt plan / cấp quyền → post quyết định về server → engine tiếp.
- **Cần làm rõ:** server gọi `run.ps1` thế nào (spawn + theo dõi run dir) + đẩy quyết định vào engine (gọi resume-kèm-decision của Phase D); bảo mật cục bộ (chỉ localhost); hiển thị run đang chạy vs lịch sử `.runs/`; xử lý run dài/đốt token (cảnh báo trước khi `-Real`).
- **Phụ thuộc:** Phase D (HITL + event) + Phase E (app shell + graph).
- **Done-gate:** từ app chạy 1 HQ build (mock) → thấy log live đầy đủ output + node sáng dần trên graph → tới gate duyệt → bấm approve → chạy tới terminal; thử 1 lần reject/đổi nhãn đi nhánh khác đúng.

### Phase G — App III (tuỳ chọn, sau cùng): in-app edit
- **Mục tiêu:** sửa workflow ngay trong app (kéo nối cạnh, sửa node) — chỉ làm nếu CLI `edit` không đủ.
- **Lưu ý (user):** "sửa thì nếu phức tạp cho bằng lệnh là được". Ưu tiên giữ edit ở CLI `edit` TUI; chỉ thêm vào app nếu rẻ. Để cuối, không chặn các phase trước.
- **Phụ thuộc:** Phase E.
- **Done-gate:** (định nghĩa khi tới — nếu làm) thêm/xoá node + nối cạnh trong app → ghi `workflow.json` hợp lệ (`validate` pass), vẫn coordinate-free.

---

## Thứ tự phụ thuộc (tóm tắt)

```
Cross-cutting D-1/D-2/D-3/D-4 (đã chốt)
   │
   ▼
Phase A (Audit) ──► findings.md ─┬─► Phase B (CLI & docs) ─┐
                                 └─► Phase C (fix + refactor) ─┬─► Phase D (engine HITL + event) ─┐
                                                              │                                   ├─► Phase F (app: live log + duyệt)
                                              Phase B ────────────────────► Phase E (app: viewer) ─┘
                                                                                  └─► Phase G (app edit, tuỳ chọn)
```

A đi đầu (de-risk). B + C dựa A; D dựa C (engine sạch rồi mới thêm HITL); E dựa B (chỉ cần surface ổn định, không cần D) → E và D song song được; F cần cả D + E; G tuỳ chọn sau E.

---

## Bảng tiến độ

| Phase | Long-plan | Trạng thái |
|---|---|---|
| Cross-cutting D-1/D-2/D-3/D-4 | — | ✅ chốt (D-1/D-2/D-4 user; D-3 đề xuất bám bất biến #2) |
| A — Audit (findings) | `plan/hq-improve/phase-a/` | ✅ DONE (5/5 session) — `findings.md` chốt: 25 finding, 0 P0, 3 P1; user duyệt 2026-05-28 |
| B — CLI & docs ergonomics (#1) | `plan/hq-improve/phase-b/` | ✅ DONE (4/4 session, 2026-05-29) — 13 lệnh tên mới (graph/autobuild/autofix/selftest) + alias im lặng + Show-Help nhóm + A-10 + A-01-hint (`run.ps1`); `engine/test-runner.ps1` (`selftest` gom 11 mục); README 3 luồng + doc A-01/05/15/24+sandbox; user duyệt. Engine executor bất biến |
| C — Fix bug + de-chắp-vá | `plan/hq-improve/phase-c/` | ✅ DONE (10/10 session, 2026-05-29 → 2026-05-30) — 22 finding Phase-đích-C đóng hết (accessor·cast-số·path-guard·validate-gap·stamp·memory·router·frontmatter·edit·A-08 stderr); CC-a+CC-c đóng; A-08 xác nhận bằng 2 REAL-RUN (`autobuild hq -Real` 6-call output sạch + `run hello -Real` stderr tách kênh đúng, 0 leak). Mock-path bất biến (selftest 11/11). ⚠️ Phát hiện builder non-det xoá sandbox giữa real-run → CC-b Phase D/F. ✅ user duyệt đóng phase 2026-05-30 |
| D — Engine HITL + event stream (#3) | `plan/hq-improve/phase-d/` | 🟡 long-plan soạn xong (3 sub-phase / 7 session), chưa thực thi — D.1 events.ndjson full-output · D.2 node `approval` · D.3 pause→awaiting+Resume-Decision (reuse resume) · D.4 headless `-AutoApprove`/fail-rõ · D.5 `Test-DiffScope` (CC-b) · D.6 violation→awaiting+approval-demo · D.7 docs+gate. Default D-D1..D-D5 (user skip câu hỏi 2026-05-30→"Recommended") |
| E — App I: workflow viewer (#4) | `plan/hq-improve/phase-e/` | ⬜ |
| F — App II: live log + duyệt (#3) | `plan/hq-improve/phase-f/` | ⬜ |
| G — App III: in-app edit (tuỳ chọn) | `plan/hq-improve/phase-g/` | ⬜ |

---

## Rà scope B+ theo findings (sau Phase A — 2026-05-28)

`findings.md` chốt 25 finding, **0 P0** (không chặn lộ trình). Tinh chỉnh scope từ findings:
- **Phase C là khối lớn nhất** (22 finding) — nên chia sub-phase theo *cụm sửa chung* thay vì theo file: accessor (A-06) · cast-số (A-07/11/12) · path-guard (A-14/25) · validate-gap fail-rẻ (A-04/16/13) · build-stamp (A-19/20) · memory (A-21/22/23) · router-leak (A-02/24) · lặt-vặt (A-03/09/05). Gồm **3 P1**: A-18 (mất-dữ-liệu edit) + A-17, A-08 (stderr real-mode, **cần 1 real-run xác nhận**).
- **Phase B** gọn: A-01 (mock-router doc, P1) · A-10 · phần doc A-05/A-15 + CC-c (`run.ps1 test` gom runner).
- **Phase D/E/F** nhận cross-cut: CC-a (tầng kiểm frontmatter tĩnh → C) · CC-b (verify diff-scope + HITL → D/F) · A-15 observability (→ E).
- Thứ tự xử lý 13 bước chi tiết: xem `phase-a/findings.md` §Tổng hợp.

---

## Bàn giao B→C (chốt cuối B.4 — 2026-05-29)

> Phase B *chạm* các vùng dưới và **đã làm phần doc/surface; cố ý hoãn phần sâu** cho C (chốt user 2026-05-28). Trạng thái dưới = thực tế sau khi đóng B. Chi tiết: `phase-b/PLAN.md` §"Bàn giao sang C".

| Finding/CC | B đã làm (✅) | C phải làm tiếp |
| --- | --- | --- |
| **A-24** `-Router` leaky | ✅ doc "bắt buộc cho graph có router" + cú pháp `node:label;...` (README §autobuild + §Router) | heuristic **suy RouterSpec happy-path từ graph** (chọn nhãn `when` đầu mỗi router) |
| **A-05** resolve projects>examples | ✅ doc thứ-tự-resolve + footgun trùng-tên-sau-promote (README §Surface lệnh) | **cảnh báo runtime** khi tên gọn match >1 root |
| **CC-c** test fragmentation | ✅ surface `run.ps1 selftest` gom 11 mục (3 script+7 stamp+mem-demo) → tổng exit (`engine/test-runner.ps1`) | **bổ assert nội dung** stamp (so node/edge kỳ vọng) + **auto-verify** mem-demo "run2 khác run1" |
| **A-01** mock không lái router | ✅ doc "`-Mock` trần KHÔNG lái router; cần `ENGINE_MOCK_ROUTER`" (README §Router) + error-hint `Show-RouterHint` (run.ps1) — **đóng ở B** | liên đới **A-02** router-spec keyed-by-agent (rò node-id) |
| **A-15** log "(N chars)" | ✅ doc "dùng `logs <proj> [node]`" (README §Surface lệnh) | *(không thuộc C)* → stream output trực tiếp = **Phase E** |
| **A-10** flag thiếu value | ✅ **đóng ở B** — `Split-DispatchArgs` cảnh báo flag cuối thiếu value | — |

---

## Bàn giao C→D/E/F (chốt cuối C.10 — 2026-05-29)

> Phase C *chạm* các vùng dưới nhưng phần SÂU (kiến trúc HITL / observability / app) thuộc phase sau. Chi tiết: `phase-c/PLAN.md` §"Bàn giao sang D/E/F".

| Cross-cut | C đã làm (✅) | Phase sau phải làm tiếp |
| --- | --- | --- |
| **CC-a** mock CẦN-không-ĐỦ | ✅ Tầng kiểm frontmatter tĩnh `Test-FrontmatterPermissions` (quyền ghi-file `acceptEdits`→Write/Edit) chạy free trong `Test-DryRunGate` trước real (C.9) | đủ ở C — tầng tĩnh bắt được divergence quyền trước khi đốt token |
| **CC-b** builder non-determinism | ✅ A-08 làm sạch INPUT (stderr không lẫn `$raw`) — bớt 1 nguồn nhiễu (C.10, xác nhận real-run). ⚠️ **Bằng chứng mới (real-run C.10):** builder (non-det, có `Bash`) đã **xoá `sandbox/<id>/.runs/` GIỮA run** → tester/record fail, run không tới terminal. Builder BẮT BUỘC cần Bash (gọi `pwsh ENGINE_RUN build`) nên KHÔNG gỡ Bash được. | **verify diff-scope** (chỉ cho builder đụng path khai báo — vd whitelist `projects/<name>` + `spec.json`, chặn xoá ngoài) + **HITL duyệt diff** → **Phase D** (engine pause/event/guard) / **Phase F** (app duyệt). Mức ưu tiên cao hơn dự kiến: đây là lỗi chặn real-E2E tự động, không chỉ "nhiễu". |
| **A-15** log "(N chars)" observability | (doc đã ở B) | **stream output trực tiếp** lúc run → **Phase E** (app live-log) |

---

## Cách dùng file này

Mỗi lần build một phase: user trỏ vào phase tương ứng → mình dựng long-plan (`plan/hq-improve/<phase>/PLAN.md` + `CHECKPOINT.md`) theo plan-long, **chốt phần "cần làm rõ" của phase đó trước** rồi mới chia session. Cập nhật bảng tiến độ khi một phase xong. Vì D-4 (audit-first), scope B+ là provisional — sau Phase A, rà lại roadmap này theo findings rồi mới soạn long-plan các phase sau.
