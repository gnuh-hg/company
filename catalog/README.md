# catalog/ — Menu vai chi nhánh (đúc sẵn)

> 17 vai hand-authored cho HQ chọn lắp pipeline chi nhánh. Mỗi file là **system prompt + ranh giới**
> của một vai headless — **KHÔNG** chứa logic workflow (edge/router/bridge là việc CTO/Builder ở P3/P4,
> quy ước bất biến #1). Đây là **menu input cho CTO** (Phase 3): CTO chọn tập con vai theo quy mô dự án,
> Builder copy nội dung vào `workflow.json` chi nhánh + wiring `{{key}}`.

---

## Template 5 mục (cố định mỗi vai)

Mỗi `catalog/<vai>.md` gồm đúng 5 mục, ~6–10 dòng tổng, mỗi mục không rỗng:

| # | Mục | Nội dung |
|---|---|---|
| 1 | **Một việc** | Mission 1 câu — vai này làm đúng một việc gì. |
| 2 | **Input** | Context / `{{key}}` output node trước mà vai cần đọc. |
| 3 | **Trả ra** | **Mô tả mức ý nghĩa** output — KHÔNG shape/schema cứng (C-2: engine không validate output agent). |
| 4 | **Không làm** | Ranh giới chống đè vai khác — tường minh, ≥1 dòng (vai đầu-não ≥2 dòng), nêu rõ vai bị đè. |
| 5 | **Handoff** | Vai downstream tiêu thụ output. |

**Quy ước viết:**
- Vai headless: nhận context qua bridge `{{key}}`, **không** spawn sub-agent, **không** hỏi user trực tiếp
  (clarify → escalate-gate ở graph, không trong vai). Dịch prior-art Leafnote *cái GÌ* (vai chia sao,
  ranh giới ở đâu, trả ra gì) → *cái CÁCH* headless.
- Vai có prior-art Leafnote → ghi nguồn tham khảo 1 dòng cuối file (`> Prior-art: <file> — <ý rút>`).
- "Trả ra" mô tả, không ép JSON schema (trừ `planner` trỏ brain-model §Plan-as-data như convention agent).

---

## Ma trận ranh giới chống đè

> Các cặp vai dễ đè nhau — chốt ai làm / ai KHÔNG làm để "Không làm" tham chiếu chéo nhất quán.

| Cặp | Vai A làm | Vai B làm | Đường ranh |
|---|---|---|---|
| **researcher ↔ ba** | `researcher`: gom hiểu biết kỹ thuật/bối cảnh **HQ-level TRƯỚC plan** (đọc code/doc/memory; đầu-não; không sinh spec, không hỏi user). | `ba`: biến user-story (từ `pm`) → **tech-spec nghiệp vụ + edge case** cho chi nhánh cụ thể. | researcher feeds `planner`; ba feeds `tech-lead`. researcher = hiểu biết tổng; ba = spec nghiệp vụ chi tiết. |
| **planner ↔ pm** | `planner`: đầu-não xuất **plan-as-data** điều phối vòng đời (meta, không quyết product feature, không code). | `pm`: **product scope** chi nhánh — cái GÌ + ưu tiên (không chia task eng, không research codebase). | planner = THẾ NÀO điều phối; pm = CÁI GÌ build + ưu tiên. |
| **planner ↔ tech-lead** | `planner`: plan-as-data mức vòng đời (research→do→verify→re-plan), agnostic về tầng eng. | `tech-lead`: **chia task kỹ thuật nội bộ** + review + quyết merge (làm THẾ NÀO tầng eng, không đặt ưu tiên product). | planner = meta-điều phối; tech-lead = phân rã kỹ thuật + gác merge. |
| **pm ↔ ba** | `pm`: tính năng + **ưu tiên** → user story. | `ba`: phân tích nghiệp vụ → **tech-spec + edge case**. | pm = ưu tiên (cái gì trước); ba = spec (chi tiết nghiệp vụ). |
| **ux ↔ ui** | `ux`: **user flow** + hành vi tương tác + state variants. | `ui`: **layout + visual** (chỉ token design-system có sẵn). | ux = luồng/hành vi; ui = hình/màu/spacing. |
| **db-architect ↔ api-developer ↔ auth-engineer** | `db-architect`: **schema/migration/index**. | `api-developer`: **endpoint + handler nghiệp vụ**. | `auth-engineer`: **xác thực/phân quyền**. Ba vai tách từ backend — không đè: schema ≠ endpoint ≠ auth. |
| **frontend-developer ↔ ui** | `frontend-developer`: **code** component + nối API + style từ thiết kế. | `ui`: **thiết kế** visual (không code). | ui giao thiết kế; frontend-developer hiện thực. |
| **mobile (ios/android/flutter)** | `mobile-ios`/`mobile-android`: native **từng nền**. | `mobile-flutter`: **cross-platform**. | Chọn **1 trong 3** tuỳ dự án, không đồng thời. Không đụng web (frontend-developer) / server. |
| **qa-functional ↔ qa-regression** | `qa-functional`: chạy test case **feature mới** theo spec, báo bug reproduce được. | `qa-regression`: kiểm **tính năng cũ không vỡ**. | Cả hai **không fix bug** (đó là developer). func = mới; reg = hồi quy. |

---

## Index 17 vai theo khối

| Khối | Vai |
|---|---|
| **Đầu-não** | `researcher`, `planner` |
| **Product** | `pm`, `ba` |
| **Design** | `ux`, `ui` |
| **Engineering** | `tech-lead`, `db-architect`, `api-developer`, `auth-engineer`, `frontend-developer`, `devops` |
| **Mobile** | `mobile-ios`, `mobile-android`, `mobile-flutter` |
| **QA** | `qa-functional`, `qa-regression` |

## Cấu hình theo quy mô (gợi ý cho CTO — copy từ agent-design, không sửa file vai)

| Quy mô | Vai dùng |
|---|---|
| **Nhỏ / prototype** | `researcher`, `planner`, `pm`, `tech-lead`, `api-developer`, `frontend-developer` |
| **Web-full** | + `ba`, `ux`, `ui`, `db-architect`, `auth-engineer`, `devops`, `qa-functional`, `qa-regression` |
| **Mobile** | web-full + **1** trong (`mobile-ios` / `mobile-android` / `mobile-flutter`) |

---

## Convention: model-tiering agent (Phase I.B)

> Gắn vào frontmatter agent `.md` để engine truyền `--model` cho claude CLI (real-mode).
> Mock-path bỏ qua `model:` → output mock BẤT BIẾN.

| Loại node | Model gợi ý | Lý do |
|---|---|---|
| **Branching** (outdeg≥2 — chỉ phát nhãn route, ~4–8 chars) | `claude-haiku-4-5-20251001` | Output cực ngắn; không cần suy luận phức tạp; tiết kiệm token đáng kể |
| **Gate / approval** (in nhãn pass/fail/approve) | `claude-haiku-4-5-20251001` | Tương tự branching — phán quyết ngắn |
| **Worker thông thường** (sinh nội dung dài) | mặc định (sonnet, để trống frontmatter) | Cần chất lượng cao; không override |

**Cú pháp frontmatter:**
```markdown
---
model: claude-haiku-4-5-20251001
---

# Agent: <tên>
...
```

**Quy tắc:** node chỉ-phát-nhãn (branching/gate) → luôn dùng model rẻ; node sinh artifact → dùng model mặc định trừ khi có lý do rõ ràng.

---

## Guideline: tối thiểu-key input (Phase I.B.2)

> Mỗi node chỉ pull `{{output_key}}` mà nó **thực sự cần** — tránh nhúng cả lịch sử pipeline.

**Vấn đề:** `Resolve-Prompt` thay `{{key}}` bằng nguyên văn giá trị → pipeline tích lũy → node cuối nhận prompt rất lớn. Ví dụ: `deploy.prompt_chars = 552 vs story.prompt_chars = 18` (×30) dù deploy chỉ làm 1 việc.

**Quy tắc tối thiểu-key:**

| Tình huống | Key nên pull | Key không cần |
|---|---|---|
| Node downstream đã có upstream chắt lọc thông tin | chỉ upstream gần nhất | spec gốc nếu upstream đã phân tích lại |
| Node terminal sau route (vd ship sau verdict:pass) | artifact cần ship | output test/gate (test đã pass = điều kiện route, không cần nhúng lại) |
| Node auth/security | API definition | spec gốc (nếu API đã encode requirements) |
| Node sinh schema từ tasks | tasks (tech-lead đã phân tích spec+design) | spec gốc |

**Heuristic khi quyết định bỏ key:**
1. **Chuỗi suy diễn:** nếu node A đã xử lý spec → tasks, node B chỉ cần tasks (không cần spec nữa).
2. **Terminal sau route:** nếu node chỉ chạy khi condition đã đảm bảo (vd verdict:pass → ship), condition artifact không cần nhúng lại.
3. **THẬN TRỌNG:** chỉ bỏ key khi chắc chắn node không bị mất thông tin nghiệp vụ thiết yếu. Bảo thủ > tiết kiệm.

**Cascade effect (mock proxy):** mỗi key bỏ ở node X → output X nhỏ hơn → prompt node X+1 nhỏ hơn → cascade đến cuối pipeline. Savings nhân lên theo chiều dài chain còn lại.

**Ví dụ web-demo (Phase I.B.2):**
- `schema`: `{{spec}}\n{{tasks}}` → `{{tasks}}` (tasks = tech-lead đã chắt lọc từ spec+design)
- `auth`: `{{spec}}\n{{api}}` → `{{api}}` (auth engineer làm từ API definition; spec đã encode vào API)
- `loopy/ship`: `{{build}}\n{{test}}` → `{{build}}` (terminal sau verdict:pass; test passing = điều kiện route)
- **Kết quả:** web-demo −351 prompt_chars (−15.2%), loopy −42 (−26.8%).
