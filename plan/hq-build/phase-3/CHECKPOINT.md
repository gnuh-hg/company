# CHECKPOINT — Phase 3: HQ agents + skills

> Sổ tay tiến độ dài hạn. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ được làm 1 session** (xem mục "Đang ở đâu" để biết session nào).
- **STOP NGAY** khi đạt STOP gate của session đó — không tham làm session kế tiếp dù còn quota.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry vào "Per-session log".
- **Bất biến không vi phạm**: engine cố định, agent `.md` chỉ prompt (logic ở `engine/*.ps1`); một surface lệnh `run.ps1`; mock offline cho mọi test; module dot-source-safe + `StrictMode`. Builder-only Write/Edit là **convention frontmatter**, KHÔNG ép bằng engine guard.
- **Đọc trước khi code**: `plan/hq-build/phase-3/PLAN.md` (context + chốt) + `plan/hq-build/phase-r/brain-model.md` (plan-as-data schema, KHÔNG lặp lại). Phase 3 test **đơn lẻ** từng agent — KHÔNG nối graph HQ (đó là Phase 4).

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 4 | 4 | 100% |
| Lớp spec + validator (`engine/spec.ps1`) | Test-PlanSchema + Test-BuildSpec + Invoke-BuildSpec | Test-PlanSchema + Test-BuildSpec + Invoke-BuildSpec ✅ | 100% |
| Agent `.md` HQ | 5 (coo/planner/cto/builder/tester) | 5 ✅ | 100% |
| Per-agent mock test pass | 5 | 5 ✅ | 100% |
| Done-gate checklist tick | 8 | 8 ✅ | 100% |

---

## Đang ở đâu

- **Phase**: 3-B — ✅ DONE (vừa xong B.2). **Phase 3 hoàn tất.**
- **Session kế tiếp**: — (chuyển sang Phase 4: nối `hq/workflow.json` graph có robustness — soạn long-plan `plan/hq-build/phase-4/` khi bắt đầu).
- **Blocker**: —
- **Reference**: Phase 3 deliverable đầy đủ. Per-agent test = `examples/hq-tests.ps1` (chạy `pwsh examples/hq-tests.ps1`, exit=số fail).

---

## Per-session log

### B.2 — Per-agent mock test + done-gate (2026-05-27)
- **Làm**: 5 fixture `examples/hq-*` + test runner `examples/hq-tests.ps1` (dot-source engine, mock offline, 15 assertion, exit=số fail, dọn artifact sau verify). **COO** (`examples/hq-coo/`): copy `hq/agents/coo.md` làm node router + 3 leaf stub, 3 edge `when` build/fix/unclear → `Invoke-Workflow -Mock` với `ENGINE_MOCK_ROUTER "coo:<label>"` ×3, assert `state.path` chạm đúng terminal + `status=done`. **Planner**: `Test-PlanSchema` trên `plan-long.json` (4 step + open_questions) + `plan-short.json` (1 step, open_questions rỗng) → ok; `plan-bad.json` (done_criteria thiếu `verify`) → fail, reason chứa 'verify'. **CTO**: `Test-BuildSpec` trên `spec-ok.json` (tái dùng `tiny-api`: pm+api-developer + pattern dv) → ok; `spec-bad.json` (role `nonexistent-role`) → fail, reason đúng field. **Builder**: `Invoke-BuildSpec spec-ok.json sandbox/_hq_builder_test` → copy `agents/{pm,api}.md` + stamp `dv_builder` (không còn `__P__`) + `Test-Workflow` 0 lỗi + `Invoke-Workflow -Mock` (`dv_verdict:fail,pass`) done qua 9 lượt → teardown. **Tester**: `examples/hq-tester/` record-node `memory_write: context` → run mock tạo `memory/context.md` (date-stamped `##`) + `Test-StructuralGate` pass → dọn `.runs/`+`memory/`. Cập nhật `company/CLAUDE.md` Bản đồ file (`engine/spec.ps1`, `hq/`, `examples/hq-*`, dòng phase-3 → ✅) + `ROADMAP.md` (Phase 3 header + bảng tiến độ → ✅ DONE).
- **STOP gate**: PASS. `pwsh examples/hq-tests.ps1` → 15/15 assertion ✓, exit 0. Regression `validate hello` exit 0 + `run hello -Mock` done. Không leftover (`.runs/`/`memory/`/`sandbox/` sạch). Done-gate checklist 8/8 tick.
- **Pitfall ghi lại**: module engine khi dot-source gán `$here` trong **scope chung** → clobber `$here` của script gọi. Runner dùng tên riêng `$hqRoot`/`$hqRepo`/`$hqEngine`. Cần nhớ khi viết script test dot-source nhiều module engine.

### B.1 — 5 agent `.md` HQ + skills (2026-05-27)
- **Làm**: `hq/agents/{coo,planner,cto,builder,tester}.md` (5 system prompt, template 5 mục Một việc/Input/Trả ra/Không làm/Handoff). COO=router 3 nhãn `build`/`fix`/`unclear` (in dòng cuối, `unclear`=default an toàn); Planner=plan-as-data WHAT (link brain-model §Plan-as-data, không lặp); CTO=build-spec HOW (link `hq/build-spec.md`); Builder=gọi `run.ps1 build`+patch (frontmatter `allowedTools:[Write,Edit,Read,Bash]`+`permission_mode:acceptEdits` — agent DUY NHẤT ghi file); Tester=`check`/`trial`+ghi memory (read-only). `hq/skills.md` = bảng 5 skill (scaffold→`build`/Invoke-BuildSpec; patch→Builder Edit; diagnose→reason `check`/`trial`; run-test→`check`+`trial`; report→node `record`/`Write-MemoryEntry`) + nêu rõ skill KHÔNG phải engine code mới.
- **STOP gate**: PASS. 5 file đủ 5/5 mục (grep); **chỉ** `builder.md` có Write/Edit trong `allowedTools` (4 file kia read-only); `skills.md` map đủ 5 skill→lệnh engine; "Không làm" chống đè (COO≠plan, Planner≠spec/vai/pattern, CTO≠build/mục-tiêu, Builder≠design/≠engine code, Tester≠sửa code). Không động `engine/*.ps1` → không cần regression engine.
- **Ghi chú cho B.2**: agent là prompt thuần — test đơn lẻ bằng mock + lớp spec sẵn có. COO test = workflow 1 router + 3 edge `when`, steer bằng `ENGINE_MOCK_ROUTER "coo:build|fix|unclear"`. Planner/CTO test = feed sample qua `Test-PlanSchema`/`Test-BuildSpec` (tái dùng sample A.1: plan dài/ngắn + spec `tiny-api`). Builder test = `Invoke-BuildSpec` trên `tiny-api` (tái dùng gate A.2). Tester test = tiny workflow node `record` → assert `Write-MemoryEntry` ghi store + dọn sau. CLAUDE.md Bản đồ file CHƯA có dòng `hq/agents/`,`hq/skills.md`,`engine/spec.ps1` — B.2 thêm.

### A.2 — Builder engine `Invoke-BuildSpec` + lệnh `build` (2026-05-27)
- **Làm**: `engine/spec.ps1` thêm `Invoke-BuildSpec $Spec $OutDir` (validate-trước-khi-ghi: gọi `Test-BuildSpec` trước, fail→throw không chạm filesystem; copy `catalog/<role>.md`→`agents/<id>.md`; `Expand-Pattern` stamp pattern→node+edge nội-pattern; sinh stub agent `New-PatternStubContent` cho node pattern (router/work); ráp `workflow.json` nodes+edges+trial top-level) + dot-source `pattern.ps1`. `engine/run.ps1`: lệnh `build <spec-file> [<outName>]` (xử lý TRƯỚC `Resolve-ProjectDir` vì nhận spec-file; outName có `/\`→path nguyên trạng, ngược lại→`projects/<outName>`; default outName=`spec.name`) + help + whitelist + dot-source `spec.ps1`.
- **STOP gate**: PASS. Sample `tiny-api` (2 vai catalog pm+api-developer + pattern do-verify-loop prefix dv): `build`→sinh `agents/{pm,api,dv_builder,dv_tester,dv_verdict,dv_done}.md` (pm/api copy đúng catalog) + `workflow.json` (stamp đúng, KHÔNG còn `__P__`, trial giữ nguyên); `validate` exit 0; `run -Mock` (`ENGINE_MOCK_ROUTER=dv_verdict:fail,pass`) done qua 9 lượt (loop fail→pass→dv_done). Spec hỏng (role lạ + edge→node lạ)→throw, reason đúng field, **KHÔNG** tạo outDir. Regression `validate hello` exit 0 + `run hello -Mock` done. Dọn `sandbox/_a2test` + `.runs/` test.
- **Ghi chú cho B.1**: lớp spec 3-A xong đủ. Builder agent (`builder.md`) CHỈ gọi `run.ps1 build` + patch — không tự thiết kế. Node pattern dùng stub auto-sinh (không thuộc catalog); chỉ `roles[]` gắn vai catalog thật. B.2 mới cập nhật CLAUDE.md Bản đồ file (`engine/spec.ps1` chưa có dòng trong map) + ROADMAP.

### A.1 — Schema docs + validator (2026-05-27)
- **Làm**: `hq/build-spec.md` (chốt build-spec schema C-3+node-level: `name/entry/max_steps/roles[]{id,role,input,output_key}/patterns[]{name,prefix}/edges[]{from,to,when?}/trial[]{observe,expect{kind,value}}` + ví dụ instance `tiny-api` 2 vai + 1 pattern; link plan-as-data sang `brain-model.md`, không lặp). `engine/spec.ps1`: `Test-PlanSchema` + `Test-BuildSpec` (hàm thuần `{ok;errors[]}`, gom mọi lỗi không throw, reason máy-đọc-được) + helper `Get-CatalogRoles`/`Get-PatternNames`/`Get-StampedPatternNodeIds` (tính lười từ thư mục) + `Write-SpecResult` + direct-run `./spec.ps1 plan|buildspec <file>` (dot-source-safe guard, StrictMode).
- **STOP gate**: PASS. 12/12 test — plan: dài+ngắn valid, 4 hỏng (thiếu goal / step thiếu action / done_criteria thiếu verify / revision sai kiểu+thiếu open_questions). buildspec: 1 valid (ví dụ tiny-api), 5 hỏng (role lạ / edge→node lạ / thiếu max_steps+roles / pattern lạ+entry lạ / trial kind lạ) — reason chỉ đúng field. Regression `validate hello` exit 0 + `run hello -Mock` done. `.runs/` test dọn.
- **Ghi chú cho A.2**: `Invoke-BuildSpec` gọi `Test-BuildSpec` trước; tập node id = `roles[].id` ∪ pattern stamp (logic `Get-StampedPatternNodeIds` đã có, tái dùng được). Stamp rule khớp `Expand-Pattern` (`__P__x`→`<prefix>_x`). Ví dụ `tiny-api` dùng làm sample spec gate A.2. `run.ps1 build` CHƯA wire (đúng scope A.1).

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-27 | Created from `PLAN.md` | @planner |
| 2026-05-27 | Session A.1 done — `hq/build-spec.md` + `engine/spec.ps1` (Test-PlanSchema/Test-BuildSpec) | @claude |
| 2026-05-27 | Session A.2 done — `Invoke-BuildSpec` + lệnh `run.ps1 build`; Phase 3-A hoàn tất | @claude |
| 2026-05-27 | Session B.1 done — 5 agent `.md` `hq/agents/` + `hq/skills.md` (Builder-only Write/Edit) | @claude |
| 2026-05-27 | Session B.2 done — 5 fixture `examples/hq-*` + `examples/hq-tests.ps1` (15/15 pass); Phase 3 hoàn tất | @claude |
