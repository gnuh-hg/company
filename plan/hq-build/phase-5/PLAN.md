# PLAN — Phase 5: Build-test-fix chạy thật end-to-end

> Sau Phase 5: chạy `run hq "<request>"` **không `-Mock`** (LLM thật), HQ tự sinh một *pipeline chi nhánh* (web-demo subset) lên disk trong sandbox cô lập, Tester verify branch bằng `validate`/`check` thật, vòng fix thật hoạt động, branch đạt được promote sang `projects/`. Headless, không người can thiệp giữa chừng.

---

## Context

- **Vì sao chia nhiều session**: Phase 5 lần đầu gọi **LLM thật** (đốt token, non-deterministic) → phải tách phần *plumbing* (test được bằng mock, gần free) khỏi phần *real run* (token, rủi ro). Mỗi real run cần mock dry-run gate trước. Gộp 1 chat sẽ vừa sửa engine vừa debug real-run → quá tải + đốt token mù.
- **Phát hiện then chốt (đã khảo code trước khi soạn)**:
  1. **HQ sinh ra một *pipeline chi nhánh*** (`workflow.json` + `agents/<id>.md` qua `Invoke-BuildSpec`), **KHÔNG** phải app chạy được. Builder happy-path = gọi `run.ps1 build <spec>` (deterministic); `Write/Edit` chỉ dùng cho fix-loop patch. → HQ Tester verify branch bằng `validate`/`check` (máy-kiểm-được Phase 2), deterministic **ngay cả khi agent HQ chạy LLM thật**. Đây là điều khiến Phase 5 kiểm được.
  2. **Gap engine**: `engine/workflow.ps1:295` gọi `Invoke-Claude $prompt $agentPath -Mock:$Mock -Model $Model` — **KHÔNG** đọc frontmatter agent (`allowedTools`/`permission_mode`/`model`), **KHÔNG** truyền `--allowedTools`/`--permission-mode` cho `claude` CLI. → real-mode Builder **chưa** ghi được file. Đây là việc plumbing trung tâm của Phase 5.
- **Quyết định đã chốt với user (input Phase 5 — không lật lại)**:
  - **Q1 (branch target)**: **web-demo subset** — HQ tự sinh branch web nhỏ rút từ catalog (pm→ba→frontend-developer→qa-functional), thay vì lắp tay như `examples/web-demo/`.
  - **Q2 (engine gap)**: **Wire executor (additive)** — sửa `workflow.ps1` đọc frontmatter → truyền `--allowedTools`/`--permission-mode`/`--model`. Có hàm thuần test được. Đây là ngoại lệ có chủ đích với bất biến #1 (engine cố định) vì Phase 5 vốn cần real file-write; thay đổi additive + mock-path bất biến.
  - **Q3 (isolation)**: **sandbox copy → promote** — chạy HQ real trong `company/sandbox/<runid>/` (tái dùng `Copy-ToSandbox` Phase 2), verify, rồi promote branch đạt sang `projects/`. Gốc luôn sạch.
  - **Q4 (token/model)**: **mock dry-run gate + model phân tầng** — trước mỗi real run chạy `-Mock` đúng path trước (free); real run dùng model rẻ cho router/gate, mạnh cho cto/builder (qua frontmatter `model:`); `max_steps=40` backstop sẵn có.
- **Ràng buộc bất biến**: chỉ thao tác trong `company/`; không đụng `leafnote/`. Engine sửa **chỉ** ở hàm thuần testable (bất biến: §"Khi sửa code engine"), giữ dot-source-safe + StrictMode guard. Mock-path PHẢI bất biến sau wiring (1 spec không-`;` + run -Mock vẫn y cũ).

---

## Out of scope (plan riêng sau)

- Branch tự-do từ request bất kỳ user gõ (non-deterministic done-gate) — Phase 5 cố định web-demo subset.
- Để branch sinh ra **tự chạy LLM thật** xuống tới app cuối (đệ quy tốn token) — Phase 5 chỉ verify branch **cấu trúc** (validate/check), không chạy branch real.
- App GUI (Phase 6).
- Tối ưu prompt/agent HQ cho chất lượng cao — Phase 5 chỉ cần E2E *hoạt động*, không tinh chỉnh.

---

## Pipeline 2 sub-phase / 4 session

```
[5-A Plumbing — mock-tested, ~free]
  5.1 Wire frontmatter (allowedTools/permission_mode/model) vào executor ─► workflow.ps1 + hq agents có model:
  5.2 Real-run harness (sandbox-copy + promote + dry-run gate) ───────────► engine/e2e.ps1 (hoặc script) + mock-verified
                                    │
[5-B Real E2E — token thật]
  5.3 Happy-path real: HQ real → branch web-subset → validate pass → promote ─► projects/<branch> validates
  5.4 Fix-loop real: broken branch + fix request → Builder patch → pass ──────► fix route E2E + done-gate + doc
                                    │
                                 outcome: build-test-fix E2E thật, headless, no-intervention
```

---

## Phase 5-A — Plumbing (mock-tested, gần free)

**Mục tiêu**: làm cho real file-write + model phân tầng **khả thi** và **test được bằng mock**, trước khi đốt 1 token real nào.

### Session 5.1 — Wire frontmatter → executor → claude CLI flags
- **Scope**:
  - Thêm hàm thuần `Get-AgentFrontmatter $agentPath` (hoặc tương đương) trong `engine/workflow.ps1` (hoặc `lib/`): parse YAML frontmatter `allowedTools` (list→space-joined string cho CLI), `permission_mode`, `model`. Trả hashtable; agent không có frontmatter → tất cả `$null` (giữ hành vi cũ).
  - Sửa chỗ gọi `Invoke-Claude` (workflow.ps1:~295): đọc frontmatter node-agent → truyền `-AllowedTools`/`-PermissionMode`/`-Model` (frontmatter `model:` **override** `-Model` global; global là fallback). `Invoke-Claude` đã có sẵn 3 param này → chỉ nối dây.
  - Thêm frontmatter `model:` vào 6 agent `hq/agents/*.md`: router/gate (`coo`,`rg_gate`,`clarify_gate`,`escalate_gate`,`tester`) → model rẻ (`claude-haiku-4-5-20251001`); `researcher`,`planner`,`cto`,`builder`,`escalate_report`,`record` → `sonnet` (cto/builder cần mạnh). Builder đã có `allowedTools`/`permission_mode`.
- **STOP gate** (đo được, **mock-only, free**):
  1. `Get-AgentFrontmatter hq/agents/builder.md` trả `allowedTools="Write Edit Read Bash"` + `permission_mode="acceptEdits"` + `model` đúng (assert trong 1 test inline/script).
  2. `Get-AgentFrontmatter hq/agents/coo.md` trả `allowedTools=$null` + `model` rẻ (no Write/Edit cho non-builder).
  3. Regression mock bất biến: `validate hello` exit 0 + `run hello "x" -Mock` done; `validate ../hq` exit 0 + happy-path mock (`ENGINE_MOCK_ROUTER="coo:build;rg_gate:enough;tester:pass"`) done — **output mock không đổi** (mock bỏ qua flags).
- **Output artifact**: `engine/workflow.ps1` (hàm `Get-AgentFrontmatter` + dây nối) + 6 `hq/agents/*.md` có `model:`.

### Session 5.2 — Real-run harness: sandbox-copy + promote + dry-run gate
- **Scope**:
  - Script điều phối real-E2E (vd `engine/e2e.ps1` với hàm thuần, hoặc mở rộng `run.ps1 e2e <request>`): (a) `-Mock` dry-run HQ trước (xác nhận path tới `record`/`escalate_report`) → nếu mock fail thì **dừng, không real**; (b) `Copy-ToSandbox ../hq` → `<runid>/`; (c) chạy HQ **real** trong sandbox; (d) sau done: locate branch sinh ra (`sandbox/<runid>/projects/<name>/`), chạy `validate`/`check` trên branch; (e) `Promote-Branch`: copy branch đạt → `company/projects/<name>/`; (f) `Remove-Sandbox`.
  - `company/.gitignore`: thêm `projects/*/` nếu cần (branch sinh ra = regen được, không commit) — xác nhận quy ước với pattern sandbox hiện có.
  - **Builder ghi vào đâu trong sandbox**: Builder gọi `run.ps1 build <spec>` → `Invoke-BuildSpec` ghi `projects/<name>/` **tương đối sandbox cwd**. Xác nhận đường dẫn out đúng nằm trong sandbox (không rò ra gốc).
- **STOP gate** (đo được, **vẫn mock cho phần HQ — chưa đốt real**):
  1. Harness dry-run gate: mock HQ path-happy → harness báo "dry-run pass, sẵn sàng real" (KHÔNG tự chạy real ở session này).
  2. `Copy-ToSandbox`/`Remove-Sandbox` round-trip trên `../hq`: sandbox tạo có đủ `agents/`+`workflow.json`, teardown sạch, gốc `hq/` không đổi (so `git`-less: so sánh file count/hash trước-sau).
  3. `Promote-Branch` (mock branch giả trong sandbox) → xuất hiện ở `projects/` → dọn được.
- **Output artifact**: `engine/e2e.ps1` (hoặc `run.ps1 e2e`) + cập nhật `.gitignore`. **0 token real tiêu.**

**Phase 5-A gate**: frontmatter wired + mock regression xanh + harness round-trip (sandbox+promote) pass — tất cả mock/offline. Sẵn sàng đốt token ở 5-B.

---

## Phase 5-B — Real E2E (token thật)

**Mục tiêu**: chứng minh build-test-fix chạy thật, headless, không can thiệp.

### Session 5.3 — Happy-path real E2E (web-demo subset)
- **Scope**:
  - Request cố định (vd `"Tạo pipeline web nhỏ: landing page + form đăng ký"`) → `run hq "<request>" e2e` (real).
  - HQ thật đi `coo:build → researcher → rg_gate → planner → cto → builder → tester:pass → record`. CTO sinh build-spec chọn ~4 vai (pm→ba→frontend-developer→qa-functional) + 1 pattern (do-verify). Builder gọi `run.ps1 build` → branch trên disk (sandbox).
  - Tester verify branch: `validate` exit 0 + `check` (Phase 2 structural gate). Promote sang `projects/<name>/`.
- **STOP gate** (đo được, **real run**):
  1. HQ run `state.status=done`, terminal = `record` (không `escalate_report`).
  2. Branch sinh ra ở sandbox có `workflow.json` + `agents/<id>.md` ≥4 vai; `validate <branch>` exit 0; `check <branch>` exit 0.
  3. HQ `trial[]` assert pass (`record_result` + `build` non-empty).
  4. Promote: `projects/<name>/` tồn tại + `validate` exit 0; sandbox teardown sạch; `hq/` gốc không đổi.
  - **Nếu real run lệch nhánh/fail**: ghi log + lỗi vào CHECKPOINT "Notes", KHÔNG ép pass — sửa prompt agent (chỉ `hq/agents/*.md`, không engine) ở session này rồi re-run; nếu vượt budget 1 chat → STOP, để 5.3-retry chat sau.
- **Output artifact**: `projects/<web-subset-branch>/` (branch real đầu tiên) + run log lưu vào CHECKPOINT.

### Session 5.4 — Fix-loop real + done-gate + doc
- **Scope**:
  - **Fix route E2E** (tận dụng `coo --fix--> planner`): pre-seed một branch **cố ý hỏng** trong sandbox (vd xoá 1 agent file mà node tham chiếu, hoặc edge trỏ node không tồn tại → `validate` fail deterministic). Request `"fix: branch <name> validate đang fail"` → `run hq` real → COO route `fix` → planner → cto → builder **patch** (Write/Edit thật — chứng minh wiring 5.1) → tester `validate` lại → `pass` → record.
  - (Tuỳ chọn, nếu budget) do-verify loop trong 1 build: Builder patch lần 1 chưa đủ → tester `fail_fix` → builder iter 2 → pass. Không bắt buộc cho done-gate.
  - Cập nhật doc: `ROADMAP.md` bảng tiến độ (Phase 5 ✅), `CLAUDE.md` bảng "Bản đồ file" (thêm `engine/e2e.ps1` + `projects/<branch>` + `plan/hq-build/phase-5/`).
- **STOP gate** (đo được, **real run**):
  1. Fix run `state.status=done`, terminal = `record`; visits cho thấy `builder` chạy (patch) **sau** `tester` fail → `tester` pass.
  2. Branch sau fix: `validate` exit 0 (lỗi gài đã được Builder sửa) — so với trước fix `validate` exit ≠ 0.
  3. Builder thực ghi file thật (kiểm: file đã sửa mtime/nội dung đổi trong sandbox) — chứng minh `--allowedTools`/`--permission-mode` wiring hoạt động real.
  4. `ROADMAP.md` + `CLAUDE.md` cập nhật; `.runs/`+`sandbox/` dọn sạch sau verify.
- **Output artifact**: branch fix real + doc cập nhật + done-gate Phase 5 đánh dấu.

**Phase 5-B gate** = Outcome cuối.

---

## Outcome cuối

- `run hq "<request>" e2e` real: HQ sinh branch web-subset hợp lệ trong sandbox → Tester `validate`/`check` pass → promote `projects/`.
- Vòng fix real: branch hỏng + fix request → Builder patch file thật → Tester pass — headless, không can thiệp giữa chừng.
- Engine wired (frontmatter → CLI flags) additive, mock-path bất biến.
- **Done-gate đo lường (đạt = Phase 5 ✅)**:
  1. 5.1 mock regression xanh (hello + hq) + frontmatter parse đúng.
  2. Harness sandbox round-trip + promote pass (mock).
  3. Real happy-path: HQ done → branch validate exit 0 → promote.
  4. Real fix-loop: broken branch → Builder patch real → validate exit 0; visit log cho thấy fix route.
  5. Gốc `hq/` sạch, sandbox teardown, doc cập nhật.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-05-28 | Initial | Soạn từ ROADMAP §Phase 5 + 4 quyết định user (web-subset / wire-executor / sandbox-promote / mock-dry-run+model-tier) |
