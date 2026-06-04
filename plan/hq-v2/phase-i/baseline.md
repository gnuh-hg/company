# Baseline — Mock Proxy Token Measurement (Phase I.A.2)

> **Ngày đo:** 2026-06-04  
> **Phương pháp:** `run.ps1 tokens <fixture>` đọc `events.ndjson`, field `node_usage` (I.A.1).  
> **Mock proxy:** `prompt_chars` + `output_chars` từ `Invoke-Claude -Mock`; `proxy_tokens ≈ (prompt_chars + output_chars) / 4`.  
> **Mục đích:** mốc so sánh cho I.B (model-tier + template-siết) / I.C (artifact-ref + trim) / I.D (real-run).  
> **Lưu ý:** proxy mock ≠ token thật — dùng để phát hiện tương đối "node nào nặng"; số thật đo tại I.D.2.

---

## Fixture 1: `examples/loopy`

**Setup:** `ENGINE_MOCK_ROUTER="verdict:pass"` (router verdict chọn nhánh `pass` → ship terminal)  
**Path:** `build → test → verdict → ship`  

| node    | agent          | prompt_chars | output_chars | proxy_tok |
|---------|---------------|------------:|------------:|----------:|
| build   | build          |           16 |           29 |        11 |
| test    | test           |           29 |           41 |        18 |
| verdict | verdict-router |           41 |            4 |        11 |
| ship    | ship           |           71 |           83 |        38 |
| **TỔNG** |              |      **157** |      **157** |    **78** |

**Nhận xét:** `ship` nặng nhất (proxy_tok=38); verdict (router) nhẹ nhất output (4 chars = nhãn route).

---

## Fixture 2: `examples/branchy`

**Setup:** `ENGINE_MOCK_ROUTER="tier:gt1000"` (router tier chọn nhánh `gt1000` → d5 → output)  
**Path:** `tier → d5 → output`  

| node   | agent       | prompt_chars | output_chars | proxy_tok |
|--------|------------|------------:|------------:|----------:|
| tier   | tier-router |           10 |            6 |         4 |
| d5     | disc        |           13 |           25 |        10 |
| output | output      |           37 |           51 |        22 |
| **TỔNG** |           |       **60** |       **82** |    **36** |

**Nhận xét:** workflow ngắn 3 node (1 path từ 4 nhánh); proxy thấp vì pipeline linear ngắn.

---

## Fixture 3: `examples/web-demo`

**Setup:** không cần ENV (pipeline thuần, không router)  
**Path:** `story → spec → flow → design → tasks → schema → api → auth → fe → deploy → qa` (11 node)  

| node   | agent              | prompt_chars | output_chars | proxy_tok |
|--------|-------------------|------------:|------------:|----------:|
| story  | pm                 |           18 |           28 |        12 |
| spec   | ba                 |           28 |           38 |        16 |
| flow   | ux                 |           38 |           48 |        22 |
| design | ui                 |           48 |           58 |        26 |
| tasks  | tech-lead          |           97 |          114 |        53 |
| schema | db-architect       |          153 |          173 |        82 |
| api    | api-developer      |          212 |          233 |       111 |
| auth   | auth-engineer      |          272 |          293 |       141 |
| fe     | frontend-developer |          292 |          318 |       152 |
| deploy | devops             |          552 |          566 |       280 |
| qa     | qa-functional      |          605 |          626 |       308 |
| **TỔNG** |                |    **2315** |    **2495** |  **1203** |

**Nhận xét:** `deploy` và `qa` chiếm >48% tổng proxy (280+308=588/1203). Input tích lũy rõ rệt: mỗi node nặng hơn node trước do nhúng output_key của các node đầu vào `input` template — đây là cơ hội tối ưu lớn nhất cho I.B (template-siết) và I.C (artifact-ref).

---

## Tóm tắt 3 fixture

| fixture  | nodes | total prompt_chars | total output_chars | total proxy_tok | ghi chú                |
|----------|------:|-------------------:|-------------------:|----------------:|------------------------|
| loopy    |     4 |                157 |                157 |              78 | router 1-step          |
| branchy  |     3 |                 60 |                 82 |              36 | 1 trong 4 nhánh        |
| web-demo |    11 |               2315 |               2495 |            1203 | pipeline tích lũy rõ   |

**Pattern nổi bật:**
- Prompt_chars tăng tuyến tính theo vị trí node trong pipeline → mỗi node bơm output các node trước.
- Router node (verdict, tier) output rất ngắn (4–6 chars = nhãn route) — I.B.1 gắn model rẻ hợp lý.
- web-demo tích lũy: `deploy.prompt_chars = 552` vs `story.prompt_chars = 18` (×30) → I.B.2 siết template + I.C.1 artifact-ref sẽ cắt mạnh nhất ở các node cuối pipeline.

---

## I.B.2 — Sau siết template `input` (2026-06-04)

> **Thay đổi áp dụng:** bỏ key `{{spec}}` khỏi node `schema` (web-demo) + bỏ `{{spec}}` khỏi node `auth` (web-demo) + bỏ `{{test}}` khỏi node `ship` (loopy).
> **Lý do:** các key này KHÔNG thiết yếu tại node đó — upstream artifact đã encode thông tin cần thiết.

### web-demo — sau siết (đo thực tế bằng `run.ps1 tokens web-demo`)

| node   | agent              | prompt_chars (trước) | prompt_chars (sau) | delta    |
|--------|-------------------|---------------------:|-------------------:|---------:|
| story  | pm                 |                   18 |                 18 |        0 |
| spec   | ba                 |                   28 |                 28 |        0 |
| flow   | ux                 |                   38 |                 38 |        0 |
| design | ui                 |                   48 |                 48 |        0 |
| tasks  | tech-lead          |                   97 |                 97 |        0 |
| schema | db-architect       |                  153 |                114 |    **−39** ← trim spec |
| api    | api-developer      |                  212 |                173 |    **−39** ← cascade schema |
| auth   | auth-engineer      |                  272 |                194 |    **−78** ← trim spec + cascade |
| fe     | frontend-developer |                  292 |                253 |    **−39** ← cascade api |
| deploy | devops             |                  552 |                474 |    **−78** ← cascade api+fe |
| qa     | qa-functional      |                  605 |                527 |    **−78** ← cascade deploy |
| **TỔNG** |                | **2315**            | **1964**           | **−351** |

**Giảm: −351 prompt_chars (−15.2%) chỉ từ 2 dòng bỏ khỏi workflow.json.**

> **Cascade effect:** trong mock proxy, output = prefix + prompt → trim 1 key ở node X → output X nhỏ hơn → prompt node X+1 nhỏ hơn → cascade lan đến cuối pipeline. Savings thực tế (real-mode) sẽ khác nhưng pattern tích lũy tương tự.

### loopy — sau siết (tính từ baseline, input chuẩn)

| node    | prompt_chars (trước) | prompt_chars (sau) | delta    |
|---------|---------------------:|-------------------:|---------:|
| build   |                   16 |                 16 |        0 |
| test    |                   29 |                 29 |        0 |
| verdict |                   41 |                 41 |        0 |
| ship    |                   71 |                 29 |  **−42** ← trim test (terminal, verdict:pass đã route) |
| **TỔNG** |              **157** |            **115** |  **−42** |

**Giảm: −42 prompt_chars (−26.8%) ở node ship.**

### Tóm tắt I.B.1 + I.B.2

| Tối ưu | Fixture | Delta |
|---|---|---|
| I.B.1 model-tier | loopy verdict, branchy tier | 0 proxy (model rẻ hơn ở real-run — không đo được offline) |
| I.B.2 siết schema –spec | web-demo | cascade −312 proxy_chars |
| I.B.2 siết auth –spec | web-demo | −39 proxy_chars (không cascade — auth không consumed downstream) |
| I.B.2 siết ship –test | loopy | −42 proxy_chars (terminal, no cascade) |
| **I.B tổng** | | **web-demo −351 (−15.2%) · loopy −42 (−26.8%)** |

---

*Baseline I.A.2 đo 2026-06-04. I.B.2 delta đo 2026-06-04 (web-demo thực tế, loopy tính từ baseline).*
