# build-spec — schema chốt (Phase 3-A.1)

> Hợp đồng dữ liệu giữa 3 vai HQ. **plan-as-data** (Planner) → **build-spec** (CTO) → **`workflow.json`** (Builder).
> File này chốt **build-spec** (đầu ra CTO) + validator máy-đọc-được (`engine/spec.ps1`). Schema **plan-as-data**
> đã chốt ở [`../plan/hq-build/phase-r/brain-model.md` §Plan-as-data schema](../plan/hq-build/phase-r/brain-model.md) — KHÔNG lặp lại ở đây.

---

## Ranh giới 3 tầng

```
Planner ──plan-as-data──► CTO ──build-spec──► Builder ──► workflow.json
 (WHAT)                   (HOW)               (copy+stamp+wire, deterministic)
```

| Tầng | Ai xuất | Là gì | "Không chứa" |
|---|---|---|---|
| **plan-as-data** | Planner | Mục tiêu + bước + tiêu chí xong (`goal/revision/prev_verdict/steps[]/done_criteria[]/open_questions[]`). | KHÔNG nhắc tên vai catalog / pattern / edge. |
| **build-spec** | CTO | Bản thiết kế chi nhánh: chọn vai catalog, chọn pattern, nối edge, viết trial. | KHÔNG đặt lại mục tiêu (đó là Planner); KHÔNG ghi file (đó là Builder). |
| **`workflow.json`** | Builder (`Invoke-BuildSpec`) | Graph engine chạy được + `agents/<id>.md` copy từ catalog + node pattern đã stamp. | — |

- `Test-PlanSchema` kiểm shape plan-as-data; `Test-BuildSpec` kiểm shape build-spec **trước khi** Builder ghi file (validate-trước-khi-build).
- Engine KHÔNG ép shape lúc runtime (QĐ C-2) — validator là **gate author-time** của HQ, không phải engine guard.

---

## build-spec schema (C-3 + node-level)

```json
{
  "name": "string — tên chi nhánh (→ workflow.json.name)",
  "entry": "string — id node bắt đầu (∈ node id sau khi stamp pattern)",
  "max_steps": 12,
  "roles": [
    {
      "id": "string — id node trong graph (unique)",
      "role": "string — tên file catalog/<role>.md (không .md)",
      "input": "string — template {{key}} bơm vào agent",
      "output_key": "string — key node này xuất (downstream {{output_key}})"
    }
  ],
  "patterns": [
    { "name": "string — tên fragment patterns/<name>.json", "prefix": "string — tiền tố stamp (__P__x → <prefix>_x)" }
  ],
  "edges": [
    { "from": "node-id", "to": "node-id", "when": "nhãn router (optional, chỉ router edge)" }
  ],
  "trial": [
    { "observe": "output_key cần quan sát", "expect": { "kind": "non-empty|contains|matches", "value": "string (bắt buộc với contains/matches)" } }
  ]
}
```

| Field | Bắt buộc | Luật (validator) |
|---|---|---|
| `name` | ✓ | non-empty. |
| `entry` | ✓ | ∈ tập node id (roles[].id ∪ node pattern đã stamp). |
| `max_steps` | ✓ | số nguyên > 0 (cầu dao chống loop vô hạn). |
| `roles[]` | ✓ | ≥1 phần tử; mỗi phần tử: `id` non-empty + unique; `role` ∈ tên file `catalog/*.md`; `output_key` non-empty; `input` là string. |
| `patterns[]` | — | mỗi phần tử: `name` ∈ tên file `patterns/*.json`; `prefix` non-empty. Vắng = chi nhánh không dùng pattern. |
| `edges[]` | ✓ | mỗi `from`/`to` ∈ tập node id; `when` optional. Edge nội-pattern do Builder tự thêm — KHÔNG khai lại ở đây. |
| `trial[]` | — | mỗi phần tử: `observe` non-empty; `expect.kind` ∈ {`non-empty`,`contains`,`matches`}; `value` bắt buộc khi kind ∈ {contains,matches}. |

**Tập node id** = `roles[].id` ∪ (mỗi `patterns[]` → node `__P__x` trong fragment stamp thành `<prefix>_x`). `entry` và `edges[].from/to` phải nằm trong tập này. Edge **nội-pattern** (vd `dv_verdict --fail--> dv_builder`) đã có sẵn trong fragment → Builder thêm khi `Expand-Pattern`; `edges[]` của spec CHỈ khai cạnh **nối** giữa role-node ↔ pattern-node và giữa các role-node.

---

## Ví dụ instance (chi nhánh `tiny-api` — 2 vai + 1 pattern)

```json
{
  "name": "tiny-api",
  "entry": "pm",
  "max_steps": 12,
  "roles": [
    { "id": "pm",  "role": "pm",            "input": "{{user_request}}", "output_key": "spec" },
    { "id": "api", "role": "api-developer", "input": "{{spec}}",         "output_key": "api_design" }
  ],
  "patterns": [
    { "name": "do-verify-loop", "prefix": "dv" }
  ],
  "edges": [
    { "from": "pm",  "to": "api" },
    { "from": "api", "to": "dv_builder" }
  ],
  "trial": [
    { "observe": "result", "expect": { "kind": "non-empty" } }
  ]
}
```

- Vai `pm`, `api-developer` ∈ `catalog/`. Pattern `do-verify-loop` ∈ `patterns/` → stamp prefix `dv` ra node `dv_builder/dv_tester/dv_verdict/dv_done` + edge nội-pattern (`dv_builder→dv_tester→dv_verdict`; `dv_verdict --fail--> dv_builder`; `dv_verdict --pass--> dv_done`).
- `edges[]` chỉ khai 2 cạnh nối: `pm→api`, `api→dv_builder`. Cạnh trong loop là của fragment, Builder tự ráp.
- `entry = pm` ∈ tập node id. `trial[0].observe = result` = `output_key` của `dv_done` (Tester P2 assert non-empty).

---

## Liên quan

- plan-as-data schema (đầu vào CTO): [`../plan/hq-build/phase-r/brain-model.md`](../plan/hq-build/phase-r/brain-model.md) §Plan-as-data schema.
- Catalog vai (menu CTO chọn): [`../catalog/README.md`](../catalog/README.md) — 17 vai.
- Pattern fragment (CTO chọn, Builder stamp): [`../patterns/README.md`](../patterns/README.md) — 6 fragment.
- Validator: `engine/spec.ps1` (`Test-PlanSchema` / `Test-BuildSpec`). Builder engine `Invoke-BuildSpec` + lệnh `run.ps1 build <spec-file> [<outName>]` (Session 3-A.2): copy vai catalog + `Expand-Pattern` stamp + nối edge + sinh stub agent cho node pattern → `workflow.json` (validate-trước-khi-ghi). Default outDir = `projects/<name>/`.
