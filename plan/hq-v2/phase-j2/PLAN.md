# PLAN — Phase J2: Gộp worker+router → routing theo CẠNH (CD-2 extension)

> Sau Phase J2: bỏ hẳn `type: "router"` như một loại node. Routing trở thành **tính chất của graph**
> (số cạnh ra), không phải của node. Mọi node là "worker"; node nào có ≥2 cạnh ra (mỗi cạnh có `when`)
> thì **tự động** là điểm rẽ — engine bơm choices, node tự in nhãn dòng cuối, engine chọn cạnh. Node 1
> cạnh đi thẳng (không đổi gì). `approval` GIỮ NGUYÊN là type riêng (gate không gọi model). Mock-path
> bất biến; selftest 10/10 mỗi session; backward-compat trong nội-bộ-đợt (migrate sạch toàn repo).

---

## Context

- **Vì sao có phase này:** Phase J (CD-2) đã làm "nửa dưới" — engine bơm tập nhãn + validate + tách
  payload — NHƯNG vẫn giữ `type: "router"` như loại node chuyên trách. User (2026-06-03) chốt làm nốt
  "nửa trên": gộp worker+router thành một, để routing là tính chất của **cạnh** (outdeg≥2), đúng intent
  CD-2 gốc "agent biết node kế, chủ động chọn". Node tuyến tính không phải khai báo gì.
- **Quyết định user chốt (2026-06-03):**
  1. **Gộp worker+router → chỉ còn worker.** Node ≥2 cạnh ra = điểm rẽ tự động. Không khai `type`.
  2. **Hard-remove, migrate sạch** (KHÔNG accept-but-ignore lâu dài): trạng thái cuối, `validate` BÁO LỖI
     nếu gặp `type: "router"`. Mọi `workflow.json`/`patterns` trong repo phải migrate.
  3. `approval` đứng ngoài — không gộp (không gọi model, chỉ pause).
- **Đây là self-mod** (sửa `engine/*.ps1`) → chạy chain `hq-self-builder` + `hq-self-tester`, gate đầy
  đủ + **user-approval diff** trước commit (D-S2). Builder branch-thường TUYỆT ĐỐI không đụng engine.
- **Ràng buộc external:** `ENGINE_MOCK_ROUTER` keyed-by-node-id — bất biến (node id không đổi, chỉ bỏ
  type). Mock router 1-dòng → payload "" → bất biến.

### Migration surface (đã khảo sát 2026-06-03)

| Nhóm | File | Ghi chú |
|---|---|---|
| Pattern fragment (NGUỒN) | `patterns/{clarify-gate,research-gather,re-plan-loop,do-verify-loop,plan-decompose,escalate-gate}.json` | 6 file — drive `p-*` qua `stamp.ps1`. Migrate cái này → p-* tự sạch khi re-stamp. |
| Fixture tay | `examples/{loopy,branchy,edit-demo}/workflow.json` | branchy đã có 2-part (J.4) — chỉ bỏ dòng type. |
| Integration | `examples/p-brain/workflow.json` | 5 router node. |
| Stamped (regen) | `examples/p-*/workflow.json` | Sinh từ pattern — re-stamp lúc selftest; không cần sửa tay nếu fragment đã sạch (xác nhận lại). |
| Bỏ qua | `projects/counterfeit-detector/workflow.json` | gitignored, regen-được — KHÔNG migrate. |

---

## Ràng buộc bất biến (nhắc mỗi session)

1. **Mock-path BẤT BIẾN** — `ENGINE_MOCK_ROUTER` trả nhãn trực tiếp; guard `-not $Mock` ở chỗ bơm +
   validate-tập-nhãn + Write-RouteIssue giữ nguyên (chỉ đổi điều-kiện-trigger từ `type` sang outdeg).
2. **Regression mỗi session:** `./run.ps1 validate hello` exit 0 · `run hello "x" -Mock` done ·
   `./run.ps1 selftest` 10/10 PASS. (selftest KHÔNG được đỏ giữa chừng — xem §sequencing.)
3. **Sửa logic ở hàm thuần** — gom 1 helper `Test-NodeBranches` (outdeg≥2), KHÔNG rải `type -eq 'router'`.
   Dot-source-safe.
4. **`approval` không đổi** — mọi nhánh code/validate/viz cho `approval` giữ nguyên.
5. **Chỉ thao tác trong `company/`.**

### Sequencing then chốt (để selftest KHÔNG đỏ giữa đợt)

> Nếu đổi `validate` reject `type:router` TRƯỚC khi migrate xong → selftest đỏ ngay. Nên:
> **S1 = đổi executor sang edge-based + migrate TOÀN BỘ fixture/pattern, NHƯNG validate tạm
> THỜI vẫn tolerate `type:router` (đọc được, bỏ qua).** Cuối S1 selftest xanh dù type đã gỡ khỏi file.
> **S2 = flip validate sang REJECT `type:router` + type lạ (giờ an toàn vì đã migrate) + viz/graph + docs.**

---

## Pipeline 2 session

```
[S1] Executor edge-based + migrate fixtures/patterns ── validate TOLERATE type:router (tạm)
                                                              │  selftest 10/10 xanh
[S2] validate REJECT type:router + viz/graph edge-based + docs ── selftest 10/10 xanh (final state)
```

---

## Session J2.1 — Executor theo cạnh + migrate toàn bộ fixture/pattern

**Mục tiêu:** Quyết định rẽ dựa **số cạnh ra**, không dựa `type`. Gỡ `type:"router"` khỏi mọi
fixture/pattern. Cuối session selftest vẫn 10/10 (validate tạm tolerate type cũ).

- **Scope (engine/workflow.ps1):**
  1. Thêm helper thuần `Test-NodeBranches $Graph $NodeId` → `$true` nếu `@($Graph.adj[$NodeId]).Count -ge 2`.
     Dot-source-safe.
  2. `Select-NextNode` (L121): đổi `if ($node.type -eq 'router')` → `if (Test-NodeBranches $Graph $NodeId)`.
     Logic khớp nhãn giữ nguyên. 1 cạnh → đi thẳng (giữ nhánh hiện tại); 0 cạnh → terminal.
  3. 5 guard còn lại đổi điều-kiện-trigger từ `$node.type -eq 'router'` sang `Test-NodeBranches`
     (pre-seed `_payload` L55 · resume restore L393 · bơm choices L606 · validate-nhãn L657 · store
     `_payload` L678). Giữ nguyên guard `-not $Mock` ở 606/657. `approval` (L558) KHÔNG đụng.
- **Scope (migrate — cùng session, bắt buộc):**
  4. Gỡ dòng `"type": "router"` khỏi: 6 `patterns/*.json` + `examples/{loopy,branchy,edit-demo}/workflow.json`
     + `examples/p-brain/workflow.json`. Edges + `when` đã có sẵn → chỉ xoá field type.
  5. Xác nhận `p-*/stamp.ps1` re-stamp ra workflow KHÔNG còn type:router (fragment đã sạch). Nếu stamp
     copy nguyên field → sửa stamp/Expand-Pattern cho khỏi sinh type.
  6. `projects/counterfeit-detector` KHÔNG đụng (gitignored).
- **Scope (validate — TẠM):** `validate.ps1` tạm thời **tolerate** `type:"router"` (đọc được, coi như
  node thường) để không vỡ nếu sót — nhưng luật cạnh đã chạy theo outdeg (≥2 cạnh cần mỗi cạnh `when`;
  ≤1 cạnh không cần). Việc REJECT để S2.
- **STOP gate:** `./run.ps1 selftest` 10/10 PASS + `validate hello/branchy/loopy/edit-demo/approval-demo`
  exit 0 + `run branchy "x" -Mock` (ENGINE_MOCK_ROUTER=tier:gt1000) done + `run loopy "x" -Mock`
  (verdict:pass) done + `grep -rl '"type".*"router"' patterns/ examples/{loopy,branchy,edit-demo,p-brain}`
  → RỖNG. + `grep 'Test-NodeBranches' engine/workflow.ps1` tồn tại + dùng ≥6 chỗ.
- **Output artifact:** `engine/workflow.ps1` + 6 `patterns/*.json` + 4 fixture json (+ stamp nếu cần).

---

## Session J2.2 — validate REJECT type:router + viz/graph edge-based + docs

**Mục tiêu:** Chốt trạng thái cuối: `validate` báo lỗi `type:"router"` (và type lạ); render rẽ-nhánh
theo số cạnh; docs phản ánh mô hình mới. selftest 10/10 (đã migrate xong ở S1 nên an toàn).

- **Scope (validate.ps1, L253-287):**
  1. Viết lại per-node out-edge rule: `approval` giữ nguyên (L263-277). Còn lại (worker):
     0 cạnh → terminal OK; 1 cạnh → OK (when optional/bỏ qua); ≥2 cạnh → mỗi cạnh cần `when` (cũ là
     luật router, nay áp cho mọi node).
  2. Bỏ lỗi "node thường có >1 cạnh / dùng type='router'" (L279-285).
  3. Thêm check type: chấp nhận `worker` (mặc-định/vắng) + `approval`; gặp `type:"router"` hoặc type lạ
     → **error** rõ ("type 'router' đã bỏ — node ≥2 cạnh tự rẽ; xoá field type").
- **Scope (viz.ps1 + graph.ps1):**
  4. `viz.ps1` (L48/90): node render diamond `{}` nếu `Test-NodeBranches` (≥2 cạnh), else box `[]`.
     `approval` hexagon ⏸ giữ nguyên. Tag (L90) `router`→`branch` theo outdeg.
  5. `graph.ps1` (L184): tag ` (router)` → ` (branch)` nếu ≥2 cạnh (hoặc bỏ tag, để nhãn cạnh tự nói).
- **Scope (docs):**
  6. `README.md` §workflow.json + §router: thay "router node (type=router)" bằng "node ≥2 cạnh ra =
     điểm rẽ; bỏ type". Cập nhật ví dụ.
  7. `CLAUDE.md` Quy ước bất biến #2 + bản-đồ-file (`workflow.ps1`/`validate.ps1`/`viz.ps1`/`graph.ps1`)
     + thêm hàng `plan/hq-v2/phase-j2/`. `plan/hq-v2/ROADMAP.md` thêm dòng Phase J2 ✅ DONE.
- **STOP gate:** `./run.ps1 selftest` 10/10 PASS + `validate hello/branchy/loopy/edit-demo/p-brain/
  approval-demo` exit 0 + `viz branchy` + `viz loopy` không vỡ (diamond đúng node ≥2 cạnh) + 1 fixture
  scratch có `type:"router"` → `validate` exit ≠0 với lỗi rõ (chứng minh reject) + docs cập nhật +
  `grep -rl '"type".*"router"' patterns/ examples/` → RỖNG (trừ projects/ gitignored).
- **Output artifact:** `engine/{validate,viz,graph}.ps1` + `README.md` + `CLAUDE.md` + `ROADMAP.md` + `CHECKPOINT.md`.

---

## Outcome cuối

- **Một loại node** (worker) + `approval` riêng. `type:"router"` bị loại khỏi schema; validate reject.
- **Routing = số cạnh ra**: ≥2 cạnh (mỗi cạnh `when`) → engine bơm choices + node tự chọn; ≤1 cạnh đi thẳng.
- **Node tuyến tính không đổi** — không phải in nhãn. Chỉ node rẽ mới để dòng cuối làm nhãn (+ payload phần trước).
- **Mock-path + selftest 10/10 bất biến**; toàn repo migrate sạch (trừ `projects/` regen-được).
- **Gate đo được:** selftest 10/10 (2 session) + validate reject type:router + `Test-NodeBranches` tồn tại
  + grep type:router rỗng trong patterns/examples.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-06-03 | Initial | User chốt gộp worker+router (routing theo cạnh) + hard-remove migrate sạch, sau khi review Phase J |
