# brain-model.md — Mô hình "đầu-não" HQ

> Deliverable Phase R. Tổng hợp prior-art Leafnote → mô hình đầu-não headless cho HQ
> (vai + pattern + cơ chế + plan-as-data schema). Sinh dần qua 5 session — xem
> `CHECKPOINT.md` để biết section nào đã chốt.
>
> **Vòng đời đầu-não** cần mô hình hoá:
> `research → plan(dài→ngắn) → orchestrate(làm/kiểm) → re-plan khi mơ hồ/fail → escalate khi bí → ghi nhớ kết cục`.

---

## Prior-art extraction

> Mỗi mục: **(A) Tham khảo CÁI GÌ** — ý đáng giữ từ Leafnote · **(B) Dịch sang CÁCH headless** —
> diễn đạt lại bằng router/loop/escalate-gate/plan-as-data của engine v2 (KHÔNG port nguyên cơ chế
> tương tác/người-trong-vòng-lặp) · **(C) Map về phần đầu-não** — bước nào trong vòng đời.

### 1. `plan-long/SKILL.md` — kế hoạch dài, 2 file PLAN + CHECKPOINT, "1 chat = 1 session"

- **(A) Tham khảo CÁI GÌ**: Tách *thiết kế bất biến* (PLAN) khỏi *tiến độ mutable* (CHECKPOINT); mỗi đơn vị công việc có **STOP gate đo được** (file tồn tại / N dòng / script trả 0 error), không vague; pipeline khai báo dạng `phase → artifact`. Đây là khung "plan-as-data" sơ khai: kế hoạch là dữ liệu có cấu trúc (phase/session/gate/artifact), không phải văn xuôi.
- **(B) Dịch sang CÁCH headless**: Bỏ ràng buộc "1 chat = 1 session" (đó là cơ chế người-trong-vòng-lặp để cắt context window của agent tương tác). HQ headless: PLAN → **plan-as-data JSON** mà node `planner` *xuất ra*; CHECKPOINT → **state visits/progress** mà `engine/workflow.ps1` đã giữ; STOP gate đo được → **điều kiện `when` trên router edge** (verdict pass/fail/clarify). Pipeline `phase→artifact` → **nodes + edges** của graph cố định.
- **(C) Map về phần đầu-não**: `plan` (sinh kế hoạch có cấu trúc) + nền cho **plan-as-data schema** (Phase R-C) + cơ chế **memory/state** ghi tiến độ (cross-ref Phase M).

### 2. `plan-short/SKILL.md` — kế hoạch ngắn inline, gate + verification, không file

- **(A) Tham khảo CÁI GÌ**: Khi scope đủ nhỏ (≤1 chat, ≤10 file, không gate human, không bulk) → kế hoạch **gọn, inline, vẫn có gate kiểm chứng được** mỗi phase + mục Verification (cách run thật + file path dự kiến). Ý cốt: *độ chi tiết của plan tỉ lệ với độ lớn task* — không phải task nào cũng cần CHECKPOINT.
- **(B) Dịch sang CÁCH headless**: "Inline trong response" (đặc thù chat tương tác) → headless thành **plan-as-data nhẹ**: cùng schema với plan-long nhưng `steps[]` ngắn, không cần nhánh re-plan lặp. Quyết định *dài hay ngắn* không do người chọn mà do **router node phân loại** (xem mục 3). Mục Verification → **`done_criteria[]` mỗi tiêu chí kèm cách verify** (đầu vào cho do-verify-loop).
- **(C) Map về phần đầu-não**: `plan` ở dạng **dài→ngắn** (cùng một schema, khác độ sâu) + cấp `done_criteria` cho bước **orchestrate(làm/kiểm)**.

### 3. `workflows/plan.md` — classifier short/long, rubric 5 tiêu chí, route

- **(A) Tham khảo CÁI GÌ**: Một bước **phân loại tường minh** trước khi lập kế hoạch: clarify tối thiểu (≤3 câu, chỉ hỏi khi thiếu info) → áp **rubric đo được** (TẤT CẢ đúng = short / BẤT KỲ đúng = long) → **route** sang nhánh tương ứng; quy tắc an toàn "**khi không chắc → default long**".
- **(B) Dịch sang CÁCH headless**: Classifier short/long → **router node** với 2 edge `when: short` / `when: long` chọn dựa trên dữ liệu (số file, có bulk, có gate) chứ không hỏi người. "Clarify tối thiểu (hỏi user)" → **escalate-gate** chỉ kích hoạt khi info thiếu thật sự (không phải mặc định), tránh hỏi-để-hỏi. "Default long khi không chắc" → **nhãn router mặc định an toàn** (fallback edge).
- **(C) Map về phần đầu-não**: `clarify-gate` (escalate khi bí/thiếu input) + định tuyến đầu vào của bước **plan**; ranh giới **research vs clarify** (R-C).

### 4. `agents/helpers/planner.md` — template vai `planner` (classify + sinh PLAN/CHECKPOINT)

- **(A) Tham khảo CÁI GÌ**: Một **vai chuyên trách lập kế hoạch**, "DO NOT implement — output là plan only"; đọc context theo thứ tự cố định (CLAUDE/ROADMAP/memory/rubric) **trước khi** draft; output format chuẩn hoá; hard-constraint "không sửa plan cũ trừ khi yêu cầu, chỉ append revision-log".
- **(B) Dịch sang CÁCH headless**: Vai `planner` (Leafnote = sub-agent gọi qua `@`, người duyệt) → **node `planner` trong graph HQ**, nhận context qua **bridge `{{key}}`** thay vì đọc file thủ công, *xuất plan-as-data JSON* thay vì văn xuôi cho người đọc. "Classify rồi branch A/B" → chính **router edge-select**. Ranh giới "chỉ plan, không code" → giữ nguyên: `planner` không phải `builder` (cross-ref Phase 1 catalog vai + Phase 3 planner headless/plan-as-data).
- **(C) Map về phần đầu-não**: định nghĩa **vai `planner`** + đầu mối **re-plan-loop** (node được loop-edge quay về khi verdict = fail/clarify).

### 5. `workflows/master.md` — entry point duy nhất, route theo nhãn + post-task checklist

- **(A) Tham khảo CÁI GÌ**: **Một điểm vào duy nhất** điều phối mọi task: BƯỚC 0 nạp context bắt buộc (CLAUDE/memory) → BƯỚC 1 gán **nhãn task** (feature/bug/refactor/plan/...) → route sang sub-workflow tương ứng → BƯỚC 3 **post-task checklist** (bảng trigger→update memory/doc, "không cập nhật = chưa xong"). Cốt lõi orchestrate: *trước khi làm phải nạp ngữ cảnh, sau khi làm phải ghi lại kết cục*; định tuyến công việc theo loại, không làm tất cả một mạch.
- **(B) Dịch sang CÁCH headless**: "Đọc file này TRƯỚC TIÊN" (chỉ thị cho agent người-trong-vòng-lặp) → **node entry cố định** của graph HQ + **bridge nạp context** (CLAUDE/memory → `{{key}}`) trước khi vào `planner`/`builder`. "Route theo nhãn" → **router node** chọn edge theo verdict/loại task (không để agent tự đọc bảng rồi quyết). "Post-task checklist + bảng trigger→update" → **bước ghi-memory sau cùng** trong vòng đời (node ghi kết cục) + điều kiện done trên edge; "không cập nhật = chưa xong" → **`done_criteria` buộc có bước persist** trước khi thoát. Bỏ phần spawn team/sub-agent qua `@` (đó là mô hình tương tác Leafnote) — HQ headless chỉ có node trong graph cố định.
- **(C) Map về phần đầu-não**: **orchestrate(làm/kiểm)** — entry + routing theo loại + do-verify-loop; nối với **ghi nhớ kết cục** (post-task → memory). Cross-ref Phase 0 (pattern do-verify-loop) + Phase 3 (orchestrator headless).

### 6. `memory/` (`context.md` / `mistakes.md` / `patterns.md` / `global.md`) — kho trí nhớ phân loại

- **(A) Tham khảo CÁI GÌ**: Trí nhớ **chia theo loại đời sống**, mỗi file một mục đích + format entry cố định: `context.md` = quyết định đã chốt + pending/tech-debt (append theo ngày); `mistakes.md` = lỗi đã gặp (Triệu chứng/Root cause/Fix/Phòng tránh) để tránh lặp; `patterns.md` = pattern thực chiến tái dùng (Vấn đề/Implementation/Ví dụ/Caveats); `global.md` = ghi chú xuyên-project (hiện rỗng). **Ai đọc**: mọi task đọc context+mistakes+patterns ở BƯỚC 0 trước khi làm. **Ai ghi**: post-task checklist ghi lại khi chốt quyết định / gặp lỗi / rút pattern. Cốt lõi: memory là *store có schema theo loại*, đọc đầu vào — ghi đầu ra của vòng đời.
- **(B) Dịch sang CÁCH headless**: "Đọc memory thủ công ở BƯỚC 0" → **bridge tự nạp** các file memory vào prompt qua `{{key}}` (node không tự đọc file). "Post-task checklist người tick tay" → **node ghi-memory tường minh** ở cuối graph, ghi theo loại (decision/mistake/pattern). Phân loại 4 file giữ nguyên làm **khung store Phase M** (đọc-nhiều/ghi-cuối), nhưng cơ chế trigger→update do **engine/node điều phối**, không do checklist thủ công. Format entry đo được (ngày + field cố định) → khung record cho memory store.
- **(C) Map về phần đầu-não**: **ghi nhớ kết cục** (decision/mistake/pattern) + nguồn **đọc context đầu vòng đời**. Cross-ref Phase M (memory store: loại file, ai-đọc/ai-ghi, format record).

---

## Mô hình đầu-não

> Tổng hợp từ §Prior-art extraction → danh sách chốt *vai + pattern + cơ chế* mà đầu-não HQ cần.
> Mỗi mục có dòng **→ Phase** cross-ref nơi sẽ hiện thực (P0 = pattern engine, P1 = catalog vai `.md`,
> P3 = orchestrator headless, PM = memory store). Shape "Trả ra" mô tả mức ý nghĩa, **không cứng** (theo
> cross-cutting C-2 — engine không validate shape output của agent).

### A. Vai (đầu-não)

Đầu-não chỉ gồm **2 vai tư duy** — không phải vai thực thi (`builder`/`tester` thuộc tay-chân, Phase 1+3).

| Vai | Một việc | Trả ra (mô tả, không shape cứng) | → Phase |
|---|---|---|---|
| `researcher` | Thu thập + tổng hợp hiểu biết về task TRƯỚC khi lập kế hoạch (đọc code/doc/memory, không hỏi user). | Bản tóm tắt hiểu biết + danh sách `open_questions[]` còn lại (cái không tự tìm được → đẩy clarify). | P1 (viết `.md`), P3 (gọi headless) |
| `planner` | Biến mục tiêu + hiểu biết thành **plan-as-data** có cấu trúc; tái sinh plan khi nhận verdict fail/clarify. | JSON plan (`goal/steps[]/done_criteria[]/open_questions[]` — chốt field ở R-C) + verdict đường đi tiếp. | P1 (viết `.md`), P3 (planner headless/plan-as-data) |

- Ranh giới bất biến (từ ref #4): `planner` **chỉ lập kế hoạch, không thực thi**; `researcher` **chỉ tìm hiểu, không quyết kế hoạch**. Tách 2 vai để re-plan-loop quay về `planner` mà không lặp lại research tốn kém.

### B. 6 pattern robustness (map vào vòng đời)

> Mỗi pattern = một cụm node/edge tái dùng được trên graph cố định. "Nhãn router" = giá trị `when` dự kiến
> trên edge điều khiển. Tất cả hiện thực bằng engine v2 (router + cycle + `max_steps`) — **không cần engine mới**.

| Pattern | Vai trò | Nhãn router dự kiến | Bước vòng đời | → Phase |
|---|---|---|---|---|
| `research-gather` | Node `researcher` gom hiểu biết; nếu còn `open_questions[]` → rẽ clarify, else → plan. | `need_clarify` / `enough` | research | P0 |
| `clarify-gate` | Router chặn trước plan: chỉ escalate khi info thiếu THẬT (không hỏi mặc định). | `missing_input` / `ok` | research→plan (biên) | P0 |
| `plan-decompose` | Node `planner` xuất plan-as-data; độ sâu dài/ngắn do router phân loại, không do người. | `long` / `short` | plan (dài→ngắn) | P0 |
| `re-plan-loop` | Loop-edge quay về `planner` khi verdict = fail/clarify; data plan đổi, graph cố định. | `fail` / `clarify` → `planner` | re-plan | P0 |
| `do-verify-loop` | `builder`→`tester`→router verdict; pass→tiến, fail→re-plan. (Khung từ loopy.) | `pass` / `fail` | orchestrate(làm/kiểm) | P0 |
| `escalate-gate` | Cầu dao thoát ra user khi bí thật (vượt re-plan max, hoặc `open_questions[]` không tự giải). | `escalate` / `resolved` | escalate khi bí | P0 |

### C. Cơ chế nền (≥3)

| Cơ chế | Vai trò trong đầu-não | → Phase |
|---|---|---|
| **memory (đọc/ghi)** | Đầu vòng đời: nạp `context/mistakes/patterns` làm bối cảnh. Cuối vòng đời: node ghi-kết-cục persist decision/mistake/pattern. Store có schema theo loại (khung từ ref #6). | PM |
| **bridge nạp context** | `{{key}}` resolve output node trước + file memory/CLAUDE vào prompt — node KHÔNG tự đọc file thủ công (thay BƯỚC 0 của Leafnote). | PM (memory→bridge), P3 |
| **`max_steps` (cầu dao)** | Chặn re-plan-loop / do-verify-loop lặp vô hạn; đạt ngưỡng → buộc escalate-gate. An toàn cho mọi cycle. | P0 (đã có trong engine) |

### D. Sơ đồ vòng đời (node/edge sơ bộ)

6 bước `research → plan → orchestrate → re-plan → escalate → ghi nhớ` map thành graph cố định
(diễn đạt được bằng schema `nodes`+`edges`+`when` của engine v2):

```
              ┌───────────── (memory đọc qua bridge) ─────────────┐
              ▼                                                    │
 entry ─► [researcher] ──need_clarify──► [clarify-gate]──missing──► (escalate ▼)
              │ enough                        │ ok                            │
              ▼                               ▼                               │
         [planner] ◄───────── fail/clarify ───────────┐                       │
              │ (xuất plan-as-data)                    │                       │
       long/short (router phân loại)                   │                       │
              ▼                                         │                       │
         [builder] ──► [tester] ──► [verdict:router]────┤ (do-verify + re-plan) │
                                          │ pass        │                       │
                                          ▼             │                       │
                                   [record:memory] ◄────┴── escalate ───────────┘
                                          │ (ghi decision/mistake/pattern)
                                          ▼
                                        DONE   (max_steps = cầu dao mọi cycle)
```

- **Router nodes**: `clarify-gate`, `planner`(long/short), `verdict` — chọn edge theo `when`.
- **Loop edges** (back-edge): `verdict --fail/clarify--> planner` (re-plan); `verdict --escalate--> record` qua nhánh thoát.
- **Cố định vs động**: cấu trúc node/edge bất biến; chỉ *dữ liệu plan* (plan-as-data) đổi giữa các vòng — chi tiết lời giải tension ở R-C.

---

## Tension & lời giải

> Căng thẳng cốt lõi của Phase R: **đầu-não phải thích nghi động** (re-plan, đổi hướng khi fail/mơ hồ)
> nhưng **engine là graph CỐ ĐỊNH** (nodes/edges khai báo trước, không sinh cạnh lúc chạy).

### Tension

Một "đầu-não" thông minh có vẻ cần khả năng *tự bẻ lái*: nhìn kết quả rồi tự quyết đi đâu, tạo bước
mới, nhảy nhánh tuỳ ý. Nhưng engine v2 (`engine/workflow.ps1`) là **single-cursor walk trên graph bất
biến**: tập node + edge + `when` được khai báo trong `workflow.json` và **không đổi lúc chạy**. Nếu cho
agent tự chế cạnh/đích, ta mất 4 thứ engine đang bảo đảm: validate trước (`validate.ps1`), viz tĩnh
(`viz.ps1`), resume xác định (state.visits), và cầu dao `max_steps`. → Không bẻ lái động.

### Lời giải: cố định TOPOLOGY, cho đổi DATA

Tách hai trục:

| Trục | Trạng thái | Cơ chế engine |
|---|---|---|
| **Topology** (node + edge + when) | **Bất biến** — khai báo trong `workflow.json`, validate được, viz được. | `Get-Graph` load 1 lần; `Select-NextNode` chỉ chọn trong cạnh đã khai. |
| **Data** (plan-as-data + verdict + context) | **Thay đổi mỗi vòng** — plan mới ghi đè plan cũ. | bridge `{{key}}` latest-wins (`workflow.ps1:303-305`). |

**Re-plan KHÔNG phải bẻ lái — nó là một CẠNH LOOP cố định quay về node `planner`.** Cấu trúc graph
y nguyên; cái đổi giữa hai vòng chỉ là *nội dung* plan-as-data mà `planner` xuất ra. Đầu-não "thông
minh" nằm ở **nội dung agent sinh ra trong data**, không nằm ở việc đổi hình dạng graph.

### Bằng chứng: `examples/loopy` đã chứng minh đúng shape này

`loopy/workflow.json` có back-edge `verdict --fail--> build`, và `build` đọc `{{verdict}}` (output vòng
trước) trong input. Mỗi vòng fail: `verdict.txt` đổi → bridge nạp giá trị mới vào prompt `build` →
`build` sinh output khác, **dù node/edge không hề đổi**. Đầu-não HQ chỉ việc thay đích loop-edge từ
`build` → `planner`: cùng một cơ chế, nhưng cái được tái sinh là *plan-as-data* thay vì code.

```
loopy (đã có):    verdict --fail--> build     (build đọc {{verdict}} → sinh lại)
HQ re-plan:       verdict --fail--> planner   (planner đọc {{plan}}+{{verdict}} → sinh plan mới)
                  ▲ cùng cơ chế: back-edge cố định + data đổi qua bridge ▲
```

### Vì sao tách `researcher` ↔ `planner` (không gộp)

Re-plan-loop quay về `planner`, **không** về `researcher`. Nếu gộp, mỗi lần re-plan sẽ lặp lại
research tốn kém + phi xác định. Tách ra: research chạy 1 lần đầu (gom hiểu biết → `{{research}}`),
re-plan-loop chỉ tái sinh plan từ hiểu biết đã có + verdict mới. Đây là lý do mô hình cần **2 vai tư
duy riêng** (§Mô hình đầu-não A).

---

## Plan-as-data schema

> `planner` *xuất* một block JSON (text output → `plan.txt` qua `output_key`, resolve lại bằng
> `{{plan}}`). Theo cross-cutting **C-2**, engine KHÔNG validate shape này — đây là **convention agent
> tuân thủ**, không phải schema engine ép. Router chỉ đọc *nhãn dòng cuối*, coi JSON là text mờ.

### Schema (field đã chốt)

```json
{
  "goal": "string — mục tiêu tổng, 1 câu",
  "revision": 0,
  "prev_verdict": null,
  "steps": [
    { "id": "s1", "action": "string — việc cụ thể", "agent": "builder", "status": "todo" }
  ],
  "done_criteria": [
    { "criterion": "string — điều kiện xong", "verify": "string — CÁCH kiểm (lệnh/quan sát đo được)" }
  ],
  "open_questions": [
    "string — câu hỏi chưa tự trả được (rỗng ⇒ đủ rõ để chạy)"
  ]
}
```

| Field | Vai trò | Ai đọc (downstream) |
|---|---|---|
| `goal` | Mục tiêu bất biến xuyên các vòng re-plan. | mọi node thực thi |
| `revision` | **Bộ đếm re-plan mang trong DATA** (0 = plan gốc). Tăng mỗi lần `planner` tái sinh. | `verdict` router → escalate khi `revision ≥ N` |
| `prev_verdict` | Lý do tái sinh (`fail`/`clarify` + chi tiết). `null` ở plan gốc. | `planner` (vòng re-plan đọc để sửa đúng chỗ) |
| `steps[]` | Phân rã hành động có thứ tự; `agent` gợi ý vai thực thi; `status` theo dõi tiến độ. | `builder` |
| `done_criteria[]` | Mỗi tiêu chí **kèm `verify` đo được** → đầu vào do-verify-loop. | `tester`, `verdict` router |
| `open_questions[]` | Không tự giải được → rẽ clarify/escalate. **Rỗng = tín hiệu "đủ rõ"** (R-C/C.2 sẽ chốt làm tiêu chí dừng re-plan). | `clarify-gate` router |

### Ví dụ instance (plan gốc, revision 0)

```json
{
  "goal": "Thêm endpoint GET /tasks/{id} trả 1 task theo id",
  "revision": 0,
  "prev_verdict": null,
  "steps": [
    { "id": "s1", "action": "Thêm route GET /tasks/{id} trong app/tasks.py", "agent": "builder", "status": "todo" },
    { "id": "s2", "action": "Trả 404 khi id không tồn tại", "agent": "builder", "status": "todo" }
  ],
  "done_criteria": [
    { "criterion": "GET /tasks/1 trả 200 + đúng task", "verify": "pytest test_tasks.py::test_get_one" },
    { "criterion": "GET /tasks/9999 trả 404", "verify": "pytest test_tasks.py::test_get_missing" }
  ],
  "open_questions": []
}
```

### Re-plan loop dùng schema này thế nào

1. `planner` xuất plan (revision 0) → `{{plan}}`.
2. `builder` đọc `{{plan}}.steps[]` → làm; `tester` đọc `{{plan}}.done_criteria[].verify` → chạy kiểm.
3. `verdict` (router) đọc kết quả tester, in nhãn dòng cuối: `pass` / `fail` / `escalate`.
4. **`fail`** → back-edge về `planner`. `planner` đọc `{{plan}}` (cũ) + `{{verdict}}` (lý do), xuất plan
   mới với `revision += 1`, `prev_verdict` = lý do, `steps[]` sửa lại. Ghi đè `plan.txt` (latest-wins).
5. **`escalate`** → khi `verdict` router thấy `{{plan}}.revision ≥ N` (đếm nằm trong DATA, router đọc
   được) → rẽ nhánh thoát ra user. Không cần engine đếm hộ.
6. **`pass`** → tiến tới node `record` (ghi memory) → DONE.

### Xác nhận: diễn đạt được bằng engine v2 — KHÔNG cần sửa engine

| Yêu cầu | Cơ chế engine v2 có sẵn | Bằng chứng |
|---|---|---|
| `planner` xuất plan → downstream đọc | `output_key: "plan"` → `{{plan}}` (bridge latest-wins) | `workflow.ps1:303-306` |
| Re-plan = loop về `planner` | back-edge `verdict --fail--> planner` | `loopy`: `verdict --fail--> build` |
| Plan mới ghi đè plan cũ mỗi vòng | latest-wins: `Set-Content "$key.txt"` + `context[key]=output` | `workflow.ps1:303-305` |
| Router chọn nhánh theo nhãn | `type:"router"` + `when` + nhãn dòng cuối | `Select-NextNode` `workflow.ps1:88-99` |
| Escalate sau N vòng (graceful) | `revision` mang trong DATA; router đọc `{{plan}}` → in `escalate` | router đọc input text (C-2) |
| Cầu dao loop vô hạn (backstop) | `max_steps` → throw `failed` | `workflow.ps1:243-253` |

**Engine-gap đã cân nhắc (không phải gap thật):** `max_steps` khi chạm trần **throw cứng** (`failed`),
không *route* mềm sang escalate-gate. Lời giải KHÔNG cần engine mới: escalate mềm do **`revision`
counter nằm trong plan-as-data** lo — `verdict` router đọc `{{plan}}.revision` và chủ động in `escalate`
TRƯỚC khi đụng trần. `max_steps` chỉ là *backstop* an toàn cho trường hợp data-counter hỏng. Kết luận:
**plan-as-data + re-plan loop diễn đạt trọn vẹn bằng router + cycle + max_steps hiện có.**

---

## Ranh giới & dừng re-plan

> Hai câu hỏi cuối Phase R: (1) khi đầu-não thiếu thông tin — bao giờ **tự tìm** (research) vs **hỏi
> user** (clarify)? (2) re-plan-loop dựa vào đâu để biết **đủ rõ để ngừng**? Cả hai phải **đo được**
> để router quyết, không phán cảm tính.

### Research vs clarify — ranh giới

Mặc định **research trước, clarify sau cùng**. `researcher` phải vét sạch mọi nguồn *tự giải được*
TRƯỚC khi đẩy bất cứ gì sang clarify. Chỉ thứ **không thể tự trả** mới thành `open_questions[]` → rẽ
escalate-gate hỏi user. Đây là dịch trực tiếp "clarify tối thiểu, chỉ hỏi khi thiếu info thật" của
ref #3 sang headless: không hỏi-để-hỏi.

| | research (tự giải) | clarify (escalate hỏi user) |
|---|---|---|
| **Bản chất** | Đọc + suy ra từ nguồn có sẵn. | Lấy thông tin **chỉ user mới biết**. |
| **Nguồn** | code, doc, memory (`context/mistakes/patterns`), `{{key}}` output node trước. | user (ngoài graph). |
| **Cơ chế** | node `researcher` + bridge nạp context. | `escalate-gate` → thoát ra user. |
| **Khi nào** | Mặc định — luôn thử trước. | Chỉ khi research đã cạn mà vẫn thiếu (vd: chọn business ưu tiên, secret, quyết định ngoài-kỹ-thuật). |
| **Tín hiệu** | Còn nguồn chưa đọc → tiếp tục research. | `open_questions[]` còn phần tử **sau khi** research cạn. |

Quy tắc an toàn (từ "default long khi không chắc", ref #3): khi không chắc một câu hỏi là
research-được hay phải clarify → **thử research trước**; chỉ escalate khi research thực sự không trả ra.
Tốn token research < chi phí làm phiền user sai chỗ.

### Tiêu chí "đủ rõ để ngừng re-plan" (đo được)

Re-plan-loop dừng khi plan-as-data thoả **cả 3 điều kiện đo được** — router `verdict`/`clarify-gate`
đọc thẳng từ `{{plan}}`, không cần engine tính hộ:

| # | Điều kiện | Đọc từ | Router dùng để |
|---|---|---|---|
| 1 | `open_questions[]` **rỗng** | `{{plan}}.open_questions` | `clarify-gate`: rỗng → `ok` (vào plan/do); có phần tử → `missing_input` → escalate |
| 2 | **mọi** `done_criteria[]` đều có `verify` không rỗng | `{{plan}}.done_criteria[].verify` | gate plan hợp lệ: thiếu `verify` ⇒ chưa đủ rõ để do-verify-loop kiểm → quay `planner` |
| 3 | `revision < max` (vd `max = 3`) | `{{plan}}.revision` | `verdict`: `revision ≥ max` → in `escalate` (graceful, trước khi `max_steps` throw) |

- **(1) + (2) = "đủ rõ để CHẠY"** — đầu vào hợp lệ cho do-verify-loop: không còn câu hỏi treo, và mọi
  tiêu chí xong đều có cách kiểm máy-đo-được.
- **(3) = "hết kiên nhẫn re-plan"** — chặn loop tái sinh vô hạn. `revision` nằm trong DATA (§Plan-as-data
  schema) nên router đọc được và escalate **mềm** (báo user "đã thử N lần"); `max_steps` chỉ là backstop
  cứng khi data-counter hỏng.
- **Khác nhau giữa dừng-thành-công vs dừng-bí**: thoả (1)+(2) **và** do-verify-loop trả `pass` → dừng
  THÀNH CÔNG (→ `record` → DONE). Vi phạm (3), hoặc `open_questions[]` mãi không rỗng → dừng BÍ
  (→ escalate-gate → user). Hai lối thoát, cùng đo bằng field trong plan-as-data.

---

## Tóm tắt cho phase sau

> Phase R chốt *mô hình*; các phase sau *hiện thực*. Bảng dưới: mỗi phase **lấy gì từ brain-model.md**
> + **deliverable** + **điểm bám** trong tài liệu này. (Cross-ref ngược ROADMAP §Các phase.)

| Phase | Lấy gì từ Phase R | Phải hiện thực | Bám section |
|---|---|---|---|
| **P0 — Pattern robustness** | 6 pattern + nhãn router dự kiến + sơ đồ vòng đời node/edge. | 6 fragment `patterns/<name>.json` (node+edge+`when`) chạy mock đúng; nhãn router chuẩn từng pattern; `max_steps` mọi cycle. | §Mô hình B (bảng 6 pattern) + §D (sơ đồ) |
| **P1 — Catalog vai** | 2 vai đầu-não `researcher`/`planner` + ranh giới "một việc" + "Trả ra" mô tả (không shape cứng, C-2). | `catalog/researcher.md` + `catalog/planner.md` (+ vai tay-chân); ranh giới không đè (researcher vs ba, planner vs pm). | §Mô hình A (bảng 2 vai) + §Tension (vì sao tách 2 vai) |
| **P3 — HQ agents** | Plan-as-data schema (6 field) + re-plan-loop 6 bước + ranh giới research/clarify + tiêu chí dừng. | Planner headless *xuất* plan-as-data JSON; COO router phân loại; do-verify + re-plan wiring; escalate khi `revision ≥ max`. | §Plan-as-data schema + §Ranh giới & dừng re-plan |
| **PM — Memory** | Khung store 4 loại (`context/mistakes/patterns/global`) + "đọc-nhiều/ghi-cuối" + bridge nạp memory. | Kho memory có schema theo loại; `researcher`/`planner` đọc đầu vòng; node `record` ghi cuối; bridge chọn memory liên quan nạp `{{key}}`. | §Prior-art #6 + §Mô hình C (cơ chế memory/bridge) |

**Bất biến xuyên phase (Phase R chốt, không lật lại):** topology cố định — re-plan = back-edge về
`planner`, KHÔNG bẻ lái động (§Tension); plan-as-data là *convention agent*, engine không validate shape
(C-2); escalate mềm dựa `revision` trong DATA, `max_steps` chỉ backstop; mọi tiêu chí dừng đo được từ
`{{plan}}` (§Ranh giới). Tất cả diễn đạt trọn bằng engine v2 — **không cần engine mới**.
