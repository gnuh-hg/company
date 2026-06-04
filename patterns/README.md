# patterns/ — Thư viện pattern robustness (fragment author-time)

> Fragment topology tái sử dụng cho đầu-não HQ (research → plan → do/verify → re-plan → escalate).
> **Engine runtime KHÔNG load fragment.** Đây là tài nguyên *author/build-time*: Builder dùng
> `Expand-Pattern` đóng dấu fragment thành `nodes`/`edges` explicit rồi ghép vào `workflow.json`
> (runtime luôn "thấy gì chạy nấy" — quy ước bất biến #2 + C-1).

---

## Định dạng fragment `<name>.json`

```jsonc
{
  "meta":  { ... },          // tài liệu cho Builder — engine & Expand-Pattern KHÔNG đọc
  "nodes": [ ... ],          // node, id dùng placeholder __P__<x>
  "edges": [ ... ]           // cạnh điều khiển, from/to dùng __P__<x>, when = nhãn router
}
```

- **Không** chứa `name` / `entry` / `max_steps` — host workflow (demo wrapper hoặc graph HQ thật) cấp.
- **Không** chứa `agent` — host **bind** agent mỗi node (xem dưới). Fragment chỉ lo *topology*
  (node/edge/`when`), không lo nội dung agent (C-2: engine không validate shape output agent).

### Placeholder `__P__<x>`

`node.id`, `edge.from`, `edge.to` dùng tiền tố `__P__` (vd `__P__verdict`, `__P__builder`).
`Expand-Pattern $fragment <prefix>` đổi `__P__<x>` → `<prefix>_<x>` ở **chỉ** 3 chỗ đó.
Mọi field khác (`type`, `input`, `output_key`, `when`, kể cả `agent` nếu có) clone **nguyên văn**.

> ⚠️ Data key (`input` / `output_key`) là **tên thật**, KHÔNG phải placeholder — chúng không
> được stamp. Khi ghép nhiều pattern vào 1 workflow, host tự lo namespace data key (vd đặt
> tên riêng) để tránh đụng. Đây là việc của host, không phải `Expand-Pattern`.

### `meta` (tài liệu, engine bỏ qua)

| Khoá | Ý nghĩa |
|---|---|
| `entry` | node vào của pattern (placeholder) |
| `exits` | `[{label, node}]` — điểm ra + nhãn |
| `routers` | danh sách node router (placeholder) |
| `router_labels` | router → nhãn `when` chuẩn |
| `fallback` | mô tả nhánh fallback an toàn của router |

---

## Bind agent (host làm sau khi stamp)

`Expand-Pattern` **không** gán agent. Host wrapper bind theo convention:

```
agent = "agents/<stamped-id>.md"
```

→ router node `dv_verdict` ⇒ file `agents/dv_verdict.md`. Convention này khiến **basename agent =
node id**, nên `ENGINE_MOCK_ROUTER="dv_verdict:fail,pass"` steer đúng router (hook mock khớp theo
basename `.md`). Builder thay agent stub bằng vai catalog thật ở Phase 3.

---

## Nhãn router chuẩn (chốt từ `brain-model.md` §B)

| Pattern | Router | Nhãn `when` chuẩn | Bước vòng đời |
|---|---|---|---|
| `research-gather` | `__P__researcher`→router | `need_clarify` / `enough` | research |
| `clarify-gate` | gate router | `missing_input` / `ok` | research→plan (biên) |
| `plan-decompose` | classify router | `long` / `short` | plan (dài→ngắn) |
| `re-plan-loop` | `__P__verdict` (back-edge → `__P__planner`) | `fail` / `clarify` / `proceed` | re-plan |
| `do-verify-loop` | `__P__verdict` | `pass` / `fail` (→builder) | orchestrate (làm/kiểm) |
| `escalate-gate` | gate router | `escalate` / `resolved` | escalate khi bí |

**Bất biến:** mỗi router có ≥1 nhánh fallback an toàn (nhãn mặc định / back-edge); mỗi cycle có
`max_steps` cầu dao cứng (graph host cấp).

---

## Quy trình chuẩn (fragment → chạy)

```
patterns/<name>.json
   │  Expand-Pattern $fragment <prefix>   (engine/pattern.ps1, author-time)
   ▼
{ nodes, edges } đã stamp (không còn __P__)
   │  host bind agent + cấp name/entry/max_steps
   ▼
examples/p-<name>/workflow.json  →  validate + run -Mock
```

Demo wrapper mẫu: [`../examples/p-do-verify-loop/`](../examples/p-do-verify-loop/)
(`stamp.ps1` tái sinh `workflow.json` từ fragment). Helper: [`../engine/pattern.ps1`](../engine/pattern.ps1).

---

## Giao thức 2-phần: dòng route + payload đích (Phase J / I.C.2)

> **Khi nào dùng:** node branching (outdeg≥2) cần truyền context CỤ THỂ cho nhánh được-chọn — thay vì phát thông tin chung cho mọi successor.

### Cơ chế (Phase J, engine bất biến)

```
Agent output:
  <payload đích cho nhánh>    ← 0..N dòng, shaped CHO nhánh sẽ đi
  <nhãn route>                ← dòng cuối không-trắng, khớp `when` cạnh ra

Engine:
  1. Route theo dòng cuối (ConvertTo-RouterLabel)
  2. Auto-store <output_key>_payload = mọi dòng trước nhãn (Get-RouterPayload)
  3. Successor dùng {{<output_key>_payload}} nhận payload đúng nhánh
```

### Nguyên tắc "định-hướng-đích"

| Nhánh | Payload nên chứa | Payload nên tránh |
|---|---|---|
| `fail` (→ fix loop) | Chẩn đoán + hành động cụ thể cho fixer | Thông tin về nhánh `pass` (irrelevant) |
| `pass` (→ terminal) | Tóm tắt ngắn hoặc rỗng | Chỉ dẫn sửa dài (node không cần) |
| `escalate` | Lý do + context cho escalation handler | Thông tin nhánh `resolved` |
| `need_clarify` | Câu hỏi cụ thể cần user trả lời | Detail kỹ thuật |

**Nguyên tắc:** agent BIẾT nhánh nào sẽ đi (chính nó quyết định nhãn) → payload shaped tối ưu cho đúng nhánh đó. Tránh "one-size-fits-all" payload vừa dài vừa pha trộn context hai nhánh.

### Ví dụ — verdict-router (loopy)

```
# Nhánh fail: payload = fix guidance cho builder
FIX: NullPointerException tại method processOrder() — kiểm tra null trước khi gọi .toString()
fail

# Nhánh pass: payload ngắn (ship không cần giải thích)
pass
```

```json
// workflow.json — build node dùng {{verdict_payload}} thay vì {{verdict}} (tránh nhúng nhãn)
{ "id": "build", "input": "{{user_request}}\n{{verdict_payload}}", "output_key": "build" }
```

Mock demo:
```bash
$env:ENGINE_MOCK_ROUTER = "verdict-router:FIX: error on line 42\nfail,pass"
# → iter 1: verdict_payload="FIX: error on line 42", route=fail → build nhận fix guidance
# → iter 2: verdict_payload="", route=pass → ship (không cần payload)
```

### So sánh `{{key}}` vs `{{key_payload}}` vs `{{key_ref}}`

| Token | Giá trị | Khi nào dùng |
|---|---|---|
| `{{key}}` | Full output của node (inline) | Node sinh output ngắn / cần toàn văn |
| `{{key_payload}}` | Payload 2-phần (trước nhãn route) | Successor của branching node — nhận shaped context |
| `{{key_ref}}` | Đường dẫn tới `.txt` file | Output lớn (>2000 chars) — consumer tự Read chọn lọc |
