# PLAN — Phase 3: HQ agents (COO/Planner/CTO/Builder/Tester) + skills

> Sau toàn bộ pipeline: HQ có **5 agent `.md`** (system prompt headless) + **lớp spec deterministic** (plan-as-data + build-spec schema + validator + Builder engine `Invoke-BuildSpec`) + **skills** (scaffold/patch/diagnose/run-test/report ánh xạ vào lệnh engine có sẵn). Mỗi agent **test đơn lẻ bằng mock**: Planner ra plan-as-data dài→ngắn (validate shape), CTO ra build-spec parse được, Builder sinh đúng cây + `workflow.json` validate pass, Tester gọi checker (P2) + ghi memory (PM). **Chưa nối** thành graph HQ — đó là Phase 4.

---

## Context

- **Vì sao chia nhiều session:** Phase 3 = (1) lớp spec/validator + Builder engine (code `.ps1`, mock-được, regression riêng) + (2) 5 agent `.md` (prompt) + skills + per-agent mock test. Mỗi nhóm cần STOP gate + regression `validate`/`run -Mock` độc lập → vượt 1 chat nếu dồn.
- **Quyết định đã chốt (user duyệt — input cho Phase 3):**
  - **C-3 build-spec = C-3 + node-level field.** Schema cố định: `{ name, entry, max_steps, roles[]{id,role,input,output_key}, patterns[]{name,prefix}, edges[]{from,to,when?}, trial[]{observe,expect{kind,value}} }`. `roles[]` khai đủ `input` (template `{{key}}`) + `output_key` → Builder ráp **1:1** ra `workflow.json`, không đoán mapping. Validate spec bằng schema TRƯỚC khi Builder hành động.
  - **Ranh giới Planner = WHAT, CTO = HOW.** Planner chỉ xuất **plan-as-data** (`goal/revision/prev_verdict/steps[]/done_criteria[]/open_questions[]` — brain-model §Plan-as-data) — KHÔNG nhắc tên vai/pattern. CTO dịch plan → build-spec: chọn vai catalog, chọn pattern, nối edge, viết `trial[]`. Tách mờ-thiết-kế (CTO) khỏi tư-duy-mục-tiêu (Planner).
  - **COO 3 nhãn: `build` / `fix` / `unclear`.** `build` → Planner→CTO→Builder→Tester (chi nhánh mới); `fix` → do-verify/Builder loop (bỏ qua Planner, sửa branch có sẵn); `unclear` → escalate-gate hỏi user (fallback an toàn, default khi không chắc).
  - **Builder-only Write/Edit + copy+stamp deterministic.** CHỈ agent `builder` khai `allowedTools: [Write,Edit,Read]` + `permission_mode: acceptEdits` trong `.md` frontmatter (convention; các agent khác read-only). Builder dựng `workflow.json` = copy `catalog/<role>.md` → `<project>/agents/` + `Expand-Pattern $fragment $prefix` stamp pattern + nối `edges[]` từ spec + scaffold. Gần-deterministic, mock-được. **Không** ép bằng engine guard (giữ "engine cố định, agent là prompt").
- **Bám brain-model.md:** §Plan-as-data schema (6 field) + §Re-plan loop 6 bước + §Ranh giới & dừng re-plan (research/clarify + 3 điều kiện đo được) + §Mô hình A (vai researcher/planner). COO/CTO/Builder/Tester là **tay-chân/điều phối** quanh 2 vai tư duy.
- **Bám nền đã có:** catalog 17 vai (`catalog/*.md`, P1) — menu cho CTO; 6 pattern (`patterns/*.json` + `Expand-Pattern`, P0) — Builder stamp; `engine/check.ps1` + `engine/sandbox.ps1` (P2) — Tester gọi; `engine/memory.ps1` `Write-MemoryEntry` + node `record` (PM) — Tester/report ghi.
- **Bất biến engine (không vi phạm):** engine là code cố định, agent `.md` chỉ chứa prompt — KHÔNG chứa logic workflow; một surface lệnh `run.ps1`; module dot-source-safe + `StrictMode`; mock offline (`-Mock` + `ENGINE_MOCK_ROUTER`) cho mọi test; `workflow.json` chỉ ngữ nghĩa.
- **Out of scope (Phase 4+):** nối 5 agent thành `hq/workflow.json` graph có robustness (clarify/escalate/re-plan wiring) = **Phase 4**; chạy thật end-to-end không mock = **Phase 5**. Phase 3 CHỈ giao **từng agent + lớp spec + Builder engine**, test **đơn lẻ** bằng fixture nhỏ — không lắp graph HQ hoàn chỉnh.

---

## Pipeline 2 sub-phase / 4 session

```
[3-A] Lớp spec + Builder engine ──► hq/build-spec.md (schema C-3 + plan-as-data)
                                     + engine/spec.ps1 (Test-PlanSchema / Test-BuildSpec)
                                     + Invoke-BuildSpec (copy vai + stamp pattern + wire edge)
                                     + lệnh run.ps1 build <spec>
                                        │
[3-B] 5 agent .md + skills + test ─► hq/agents/{coo,planner,cto,builder,tester}.md
                                     + hq/skills.md (scaffold/patch/diagnose/run-test/report)
                                     + per-agent mock test (5 fixture nhỏ)
                                        │
                                     Phase 3 done — ROADMAP cập nhật
```

Lý do thứ tự: lớp spec + Builder engine (3-A) là **xương deterministic** mà agent `.md` (3-B) dựa vào để test — validator + `Invoke-BuildSpec` phải có trước thì mới kiểm được "CTO ra spec parse được" + "Builder sinh cây validate pass".

---

## Phase 3-A — Lớp spec + Builder engine

**Mục tiêu**: chốt 2 schema (plan-as-data của Planner, build-spec của CTO) + validator máy-đọc-được + Builder engine `Invoke-BuildSpec` (gần-deterministic copy+stamp+wire). Cô lập phần mờ (CTO design) khỏi phần nguy hiểm (Builder ghi file) bằng validate-trước-khi-build.

### Session A.1 — Schema docs + validator
- **Scope**:
  - `hq/build-spec.md`: chốt build-spec schema C-3 + node-level (`{ name, entry, max_steps, roles[]{id,role,input,output_key}, patterns[]{name,prefix}, edges[]{from,to,when?}, trial[]{observe,expect{kind,value}} }`) + 1 ví dụ instance đầy đủ (tái dùng 1 chi nhánh nhỏ, vd 2-3 vai từ catalog). Mô tả ranh giới: plan-as-data (Planner) → build-spec (CTO) → `workflow.json` (Builder). Tham chiếu plan-as-data schema đã chốt ở `brain-model.md` (KHÔNG lặp lại, link sang).
  - `engine/spec.ps1` — 2 hàm thuần testable:
    - `Test-PlanSchema $planJson` → kiểm plan-as-data có đủ field bắt buộc (`goal`, `revision`, `steps[]` mỗi phần tử có `action`, `done_criteria[]` mỗi phần tử có `verify` không rỗng, `open_questions[]` là mảng). Trả object `{ ok; errors[] }` (reason máy-đọc-được).
    - `Test-BuildSpec $specJson` → kiểm build-spec: field bắt buộc đủ; mọi `roles[].role` ∈ tên file `catalog/*.md`; mọi `patterns[].name` ∈ `patterns/*.json`; `edges[].from/to` trỏ `roles[].id` hoặc node pattern đã stamp; `entry` ∈ node id; `trial[].expect.kind` ∈ {non-empty,contains,matches}. Trả `{ ok; errors[] }`.
  - Wrapper direct-run + dot-source-safe guard; `StrictMode` guard `$null`/`.Count`.
- **STOP gate**: `Test-PlanSchema` + `Test-BuildSpec` chạy độc lập — 1 sample hợp lệ → `ok=$true, errors=@()`; **≥3 sample hỏng mỗi loại** (thiếu field / vai không có trong catalog / edge trỏ node lạ) → `ok=$false` + reason chỉ đúng field sai; regression `validate hello` exit 0 + `run hello "x" -Mock` done (không động engine cũ).
- **Output artifact**: `hq/build-spec.md` + `engine/spec.ps1`.

### Session A.2 — Builder engine `Invoke-BuildSpec` + lệnh `build`
- **Scope**:
  - `engine/spec.ps1` thêm `Invoke-BuildSpec $specJson $outDir` (gần-deterministic):
    1. Gọi `Test-BuildSpec` trước — fail → throw với reason (không ghi gì).
    2. Tạo `<outDir>/` + `<outDir>/agents/`; mỗi `roles[]` → copy `catalog/<role>.md` → `<outDir>/agents/<id>.md`.
    3. Mỗi `patterns[]` → `Expand-Pattern $fragment $prefix` → fragment node+edge explicit (id `__P__x` → `<prefix>_x`).
    4. Sinh `<outDir>/workflow.json`: `nodes` từ `roles[]` (id/agent/input/output_key) + node pattern đã stamp; `edges` từ `spec.edges[]` (+ edge nội-pattern); `entry` + `max_steps`; `trial[]` top-level (đầu vào Tester P2).
    5. Ghi `trial[]` đúng vị trí `workflow.json` mà `Get-Trials` (P2) đọc được.
  - Lệnh `run.ps1 build <spec-file> [<outName>]` → wrapper gọi `Invoke-BuildSpec`. Mặc định outDir = `projects/<name>/` (hoặc `examples/` cho test — chốt trong session, ưu tiên KHÔNG bẩn `projects/`: dùng outDir tạm rồi dọn).
  - **Quyền file**: `Invoke-BuildSpec` là engine code (được ghi file) — đây là lớp deterministic THAY agent Builder thực thi phần nguy hiểm; agent `builder` (3-B) chỉ *gọi* lệnh này + patch. Comment rõ ranh giới trong code.
- **STOP gate**: feed sample build-spec hợp lệ (≥2 vai catalog + ≥1 pattern stamp) → `Invoke-BuildSpec` sinh `<outDir>/` có `agents/<id>.md` (copy đúng từ catalog) + `workflow.json`; `validate <outDir>` exit 0; `run <outDir> "x" -Mock` done; pattern stamp đúng (id `<prefix>_x` xuất hiện, không còn `__P__`); spec hỏng → throw, KHÔNG sinh file. Dọn outDir test + `.runs/`.
- **Output artifact**: `engine/spec.ps1` (+`Invoke-BuildSpec`) + lệnh `build` trong `engine/run.ps1`.

**Phase 3-A gate**: build-spec/plan-as-data validate được máy-đọc; `Invoke-BuildSpec` biến 1 spec hợp lệ thành chi nhánh `validate` pass + `run -Mock` done; spec hỏng bị chặn trước khi ghi file.

---

## Phase 3-B — 5 agent .md + skills + per-agent test

**Mục tiêu**: viết 5 system prompt HQ + skills reference; test **từng agent đơn lẻ** bằng mock (chưa nối graph).

### Session B.1 — 5 agent .md + skills reference
- **Scope**:
  - `hq/agents/` 5 file `.md` (system prompt, template 5 mục như catalog: Một việc / Input / Trả ra / Không làm / Handoff):
    - `coo.md` — router phân loại `build`/`fix`/`unclear`; "Trả ra" = nhãn dòng cuối (router đọc); "Không làm" = không lập kế hoạch/không build; `unclear` = default an toàn.
    - `planner.md` — xuất **plan-as-data** (WHAT: goal/steps/done_criteria/open_questions); "Không làm" = không chọn vai/pattern/không code; tái sinh plan khi `prev_verdict` = fail/clarify; đọc `{{mem_*}}` (PM) + `{{research}}`.
    - `cto.md` — dịch plan → **build-spec** (HOW: chọn vai catalog + pattern + edge + trial); "Không làm" = không tự lập mục tiêu (đó là Planner), không ghi file (đó là Builder).
    - `builder.md` — nhận build-spec → gọi `run.ps1 build` (Invoke-BuildSpec) + patch; **frontmatter `allowedTools: [Write,Edit,Read]` + `permission_mode: acceptEdits`** (agent DUY NHẤT được ghi file); "Không làm" = không thiết kế spec.
    - `tester.md` — gọi `run.ps1 check`/`trial` (P2) + ghi memory qua node `record`/`Write-MemoryEntry` (PM); "Trả ra" = verdict `pass`/`fail` + reason; read-only (không sửa code, báo fail về Builder).
  - `hq/skills.md` — bảng ánh xạ **skill → lệnh engine/cơ chế có sẵn**: `scaffold`→`run.ps1 build`(Invoke-BuildSpec)/`Expand-Pattern`; `patch`→Builder Edit; `diagnose`→đọc `check`/`trial` reason máy-đọc-được; `run-test`→`run.ps1 check` + `run.ps1 trial`; `report`→node `record` (`memory_write`) + `Write-MemoryEntry`. Nêu rõ skills KHÔNG phải engine code mới — là convention agent dùng lệnh sẵn.
  - Các agent khác (coo/planner/cto/tester) frontmatter read-only (không Write/Edit) — kiểm chứng ranh giới Builder-only.
- **STOP gate**: 5 `.md` tồn tại đủ 5 mục; **chỉ `builder.md`** có `Write`/`Edit` trong `allowedTools` (grep xác nhận 4 file kia không có); `hq/skills.md` ánh xạ đủ 5 skill → lệnh engine cụ thể; mỗi agent "Không làm" nêu ranh giới chống đè (COO≠plan, Planner≠spec, CTO≠build, Builder≠design, Tester≠sửa code).
- **Output artifact**: `hq/agents/{coo,planner,cto,builder,tester}.md` + `hq/skills.md`.

### Session B.2 — Per-agent mock test + done-gate
- **Scope**: 5 fixture nhỏ (mỗi agent 1 test đơn lẻ, mock), đặt trong `examples/hq-*/` (hoặc test inline bằng `engine/spec.ps1` cho phần schema — chốt trong session):
  - **COO**: workflow 1 router node `coo` + 3 edge `when: build/fix/unclear`; `ENGINE_MOCK_ROUTER "coo:build"` / `:fix` / `:unclear` → assert đi đúng 3 nhánh (3 path).
  - **Planner**: feed sample plan-as-data Planner *sẽ* xuất → `Test-PlanSchema` trả `ok` cho cả bản **dài** (nhiều steps + open_questions) lẫn **ngắn** (1-2 steps, open_questions rỗng); bản thiếu `verify` → fail.
  - **CTO**: feed sample build-spec CTO *sẽ* xuất → `Test-BuildSpec` trả `ok` (parse được, vai ∈ catalog); spec vai-không-có-trong-catalog → fail.
  - **Builder**: `Invoke-BuildSpec` trên sample spec → sinh cây + `workflow.json`; `validate` exit 0 + `run -Mock` done (tái dùng gate 3-A.2, gắn vào agent builder).
  - **Tester**: tiny workflow node `record` (`memory_write`) → chạy mock → assert `Write-MemoryEntry` ghi entry vào store + `run.ps1 check` trên fixture trả verdict đúng tầng (tái dùng P2/PM).
  - Verify isolation: test ghi store/outDir thật → **dọn sau verify** (không bẩn HQ-global/`projects/`).
  - Cập nhật `company/CLAUDE.md` Bản đồ file (`hq/agents/`, `hq/skills.md`, `hq/build-spec.md`, `engine/spec.ps1`, `examples/hq-*`, `plan/hq-build/phase-3/`) + ROADMAP bảng tiến độ Phase 3 → ✅.
- **STOP gate**: done-gate checklist (xem Outcome) **tất cả tick**; 5 agent test đơn lẻ pass (COO 3 path, Planner dài+ngắn validate, CTO spec parse, Builder validate+mock done, Tester check+ghi memory); store/outDir test dọn sạch; CLAUDE.md + ROADMAP cập nhật.
- **Output artifact**: `examples/hq-*/` fixtures + CLAUDE.md + ROADMAP cập nhật.

**Phase 3-B gate** = Outcome cuối.

---

## Outcome cuối

- 5 agent HQ (`.md` prompt) + lớp spec deterministic (validator + `Invoke-BuildSpec`) + skills reference, **mỗi agent test đơn lẻ pass bằng mock**. Chưa nối graph HQ (Phase 4).
- **Done-gate (checklist đo được):**
  - [x] `hq/build-spec.md` chốt build-spec schema (C-3 + node-level `roles[]{id,role,input,output_key}` + `patterns[]{name,prefix}` + `edges[]{from,to,when?}` + `trial[]`) + ví dụ instance; link plan-as-data sang `brain-model.md`.
  - [x] `engine/spec.ps1`: `Test-PlanSchema` + `Test-BuildSpec` trả `{ok;errors[]}`; sample hợp lệ pass, ≥3 sample hỏng/loại fail + reason đúng field.
  - [x] `Invoke-BuildSpec` (validate-trước-khi-ghi): sample spec hợp lệ → sinh `agents/<id>.md` (copy catalog) + `workflow.json`; `validate` exit 0 + `run -Mock` done; pattern stamp đúng (`__P__`→`<prefix>_`); spec hỏng → throw không ghi file. Lệnh `run.ps1 build`.
  - [x] 5 agent `.md` đủ 5 mục; **chỉ `builder.md`** có `Write`/`Edit` (`permission_mode: acceptEdits`); ranh giới "Không làm" chống đè (COO/Planner/CTO/Builder/Tester).
  - [x] `hq/skills.md` ánh xạ 5 skill (scaffold/patch/diagnose/run-test/report) → lệnh engine có sẵn (không code engine mới).
  - [x] Per-agent mock test pass: COO 3 path; Planner dài+ngắn validate; CTO spec parse; Builder validate+mock done; Tester check+ghi memory.
  - [x] Regression: `validate hello` exit 0 + `run hello -Mock` done; store/outDir test dọn sạch.
  - [x] `company/CLAUDE.md` Bản đồ file + ROADMAP bảng tiến độ Phase 3 ✅ cập nhật.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-05-27 | Initial | Tạo từ ROADMAP Phase 3; chốt (user): build-spec C-3 + node-level input/output_key; Planner=WHAT/CTO=HOW; COO 3 nhãn build/fix/unclear; Builder-only Write/Edit + copy+stamp deterministic qua Invoke-BuildSpec |
