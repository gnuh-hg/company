# PLAN — Phase I2: Handoff-by-workspace + model-tiering có nguyên tắc (hq-v2)

> Sau toàn pipeline: node trong engine chi nhánh **không còn nhúng nguyên văn output thượng nguồn** — chúng nhận **chỉ-dẫn "đọc file nào, làm gì"** (kiểu long-plan: workspace + brief) rồi tự `Read` CHỌN LỌC; đồng thời chi phí cố định mỗi call (system-prompt + tool-defs) được **rút xuống tối thiểu** và mỗi node chạy **đúng hạng model theo vai** (không cào bằng xuống loại tệ nhất). Có **báo cáo real-run A/B** chứng minh real input tokens GIẢM (lần này nhắm đúng phần chi phối). Mock-path + regression (validate hello + run -Mock + selftest 12/12) bất biến mọi session; lossless trên path thực.

---

## Context

### Vì sao có phase này (xuất phát từ phát hiện Phase I)
Phase I (DONE 2026-06-05) đã xây đủ 6 hạng mục đo/tối ưu, NHƯNG real-run `token-report.md` cho phát hiện cốt lõi:
- **input_tokens KHÔNG giảm** (28020 → 28074, +0.2% flat) dù mock-proxy `prompt_chars` giảm −15%.
- **Lý do:** input mỗi `claude -p` call bị chi phối bởi **system-prompt (agent `.md`) + tool-definitions (~50–80% input/call)**, KHÔNG phải template `{{key}}` đã resolve. Template-trim (I.B.2) chỉ cắt phần `user_message` nhỏ → real savings ≈ 0.
- **Bẫy đo được (I.D.2):** thêm `allowedTools:[Read]` để dùng artifact-by-reference (`{{key_ref}}`, I.C.1) làm **tool-def cộng token** ăn HẾT phần tiết kiệm của `fe_ref` trên pipeline ngắn.
- **Tin tốt:** prompt-caching XÁC NHẬN tự-hoạt (cache_read 153K–419K) — tiền-tố ổn định được cache.

→ Muốn cắt real input **phải nhắm đúng 3 thành phần**: `user_message` (handoff-by-workspace), `tool_defs` (rút tool-set), `system_prompt` (rút gọn) — KHÔNG chỉ template. Phase I2 làm việc đó.

### Hai đề xuất user (2026-06-05) — nền của phase
1. **Handoff bằng file trung gian kiểu long-plan**: nội dung gửi node sau chỉ là "đọc file X/Y, làm việc Z" thay vì prompt dài; node sau **đọc chọn lọc** (không buộc load cả khối). Xây trên `{{key_ref}}` (I.C.1) — nâng thành **giao thức có cấu trúc**.
2. **Model không cố chấp dùng loại tệ nhất**: map **vai-trò-node → hạng model** (label→Haiku, reasoning/design→Sonnet/Opus); cào bằng Haiku sẽ hạ chất lượng → tốn token sửa (đắt hơn).

### Điều kiện net-thắng của handoff-by-workspace (đã suy từ số I.D.2)
File-handoff CHỈ net-giảm token khi **đồng thời**: (a) output thượng nguồn LỚN, (b) node sau chỉ cần ĐỌC MỘT PHẦN (đọc-toàn-bộ = nội dung vào context qua tool-result y như nhúng + cộng tool-def + 1 lượt tool → TỆ HƠN), (c) pipeline đủ dài để khấu hao chi phí cố định `Read` tool-def, (d) song song rút system-prompt/tool-set. Plan phải **đo A/B thật** để xác nhận, KHÔNG tin giả định.

### Ràng buộc bất biến (6 quy ước `company/CLAUDE.md`)
- Mock-path (`-Mock` + `ENGINE_MOCK_ROUTER`) bất biến mọi session — mọi thay đổi engine ADDITIVE.
- Một surface lệnh `run.ps1`; module dot-source-safe; `workflow.json` chỉ ngữ nghĩa (không toạ độ).
- Chỉ thao tác trong `company/`; engine là code cố định (self-mod chỉ `hq-self-builder` sau gate).
- **Regression chuẩn mỗi session chạm engine:** `./run.ps1 validate hello` exit 0 · `./run.ps1 run hello "x" -Mock` done · `./run.ps1 selftest` PASS (**12/12**). Dọn `.runs/` test sau verify.
- **Reserved keys** (không làm `output_key`): `user_request`, `user_answer`, `engine_run`, `mem_*`, **suffix `_ref` (I.C.1)**, **`_payload` (J)**. Key bridge mới của I2 (vd `_brief`, `workspace`) phải reserved-aware.

### Out of scope
- Tối ưu HQ-team native (CC tự lo prompt-caching/context — CD-1).
- Thay đổi mock-path semantics; tối ưu app (Phase L).
- Đổi executor walk/resume logic ngoài phạm vi handoff/model.

---

## Quyết định cần user chốt (trước/khi approve plan)

> Plan đặt **default đề xuất**; user xác nhận hoặc đổi tại approve. Đánh dấu `[?]`.

- **[?] Q1 — Brief do AI sinh hay engine sinh?** Default đề xuất: **producer agent tự viết brief** (1 khối "## Handoff" cuối output: đọc file gì, làm gì) → giống long-plan tự nhiên + linh hoạt; engine chỉ tách + bơm. (Phương án khác: engine sinh brief tĩnh từ template — rẻ hơn nhưng cứng.)
- **[?] Q2 — Handoff-by-workspace là DEFAULT hay OPT-IN?** Default đề xuất: **opt-in qua field node** (`handoff: workspace`) + guideline khuyến nghị; giữ pipeline cũ chạy y hệt (an toàn). (Phương án khác: default cho mọi node output lớn — mạnh hơn nhưng rủi ro regression.)
- **[?] Q3 — Mức rút system-prompt:** Default đề xuất: **thêm convention "lean system-prompt" + áp cho fixture/catalog mẫu**, KHÔNG viết lại toàn bộ 17 catalog (giữ scope). (Phương án khác: viết lại hết catalog — nhiều việc, defer.)
- **[?] Q4 — Real-run A/B fixture:** Default đề xuất: **web-demo-scale (11 node, artifact lớn)** vì điều kiện net-thắng cần pipeline dài + output lớn (todo-web 5 node của I.D.2 quá ngắn để thấy lợi). User chốt fixture + ngân sách token.

---

## Pipeline 5 sub-phase / 9 session

```
[I2.A] Giải phẫu input (spine)   ──► estimator tách system/tool/user/mem mỗi node + input-anatomy.md
                                       │  (biết ĐÚNG phần nào chi phối trước khi tối ưu)
[I2.B] Handoff-by-workspace      ──► giao thức brief + {{key_ref}} nâng cấp + fixture pipeline dài
                                       │
[I2.C] Rút chi phí cố định       ──► tool-set tối thiểu mỗi agent + lean system-prompt convention
                                       │  (đây là phần CHI PHỐI real input theo I.D.2)
[I2.D] Model-tiering có nguyên tắc──► bảng vai→hạng model + áp catalog/fixture, giữ chất lượng
                                       │
[I2.E] Real-run A/B (user-gate)  ──► token-report-v2.md trước/sau, real input GIẢM + lossless
                                       │
                                     outcome: real input tokens/run giảm rõ, đo được, lossless
```

**Phụ thuộc ngoài:** Phase I (DONE — `{{key_ref}}`, `tokens` harness, `node_usage`, `Test-SingleConsumer`), Phase 5.1 (`model:` frontmatter). Tất cả đã xong.

---

## Phase I2.A — Giải phẫu input (spine: tối ưu sau nhắm theo đây)

**Mục tiêu**: biết ĐÚNG mỗi node tốn input vào đâu (system-prompt / tool-defs / user-message / memory / cache) để tối ưu không mò. Phase I chỉ đo TỔNG; I2.A tách THÀNH PHẦN.

### Session I2.A.1 — Estimator thành phần input (mock, không đốt token)
- **Scope**:
  - Module/lệnh mới `run.ps1 tokens <proj> -Anatomy` (hoặc `engine/anatomy.ps1` thuần, dot-source-safe): với mỗi node ước lượng input breakdown bằng **proxy tĩnh** — `system_chars` (độ dài file `.md` agent, trừ frontmatter), `tool_def_estimate` (bảng tham chiếu token/tool: ước lượng cố định mỗi tool trong `allowedTools`), `user_msg_chars` (template `input` đã resolve mock), `mem_chars` (`{{mem_*}}` nếu có). In bảng %-share mỗi thành phần/node + tổng.
  - Hiệu chỉnh bảng tool-def-estimate dựa trên số real có sẵn (I.D.2 baseline todo-web: 28020 input/5 node; suy ngược ước lượng/calibrate — ghi rõ giả định).
  - Viết `plan/hq-v2/phase-i2/input-anatomy.md`: bảng %-share 3 fixture (loopy / web-demo / tokrep-baseline) → xác định node/thành phần nào chi phối (kỳ vọng: system+tool ≫ user).
- **STOP gate**: `run.ps1 tokens <proj> -Anatomy` in bảng %-share per-node (exit 0); `input-anatomy.md` có số ≥3 fixture + chỉ rõ thành phần chi phối; regression (validate/run -Mock/selftest 12/12) PASS. Mock-path bất biến.
- **Output artifact**: `engine/anatomy.ps1` (hoặc mở rộng `tokens.ps1`) + dispatcher flag + `input-anatomy.md`.

**Phase I2.A gate**: có công cụ tách input + số mốc chỉ rõ "system+tool chi phối"; regression bất biến.

---

## Phase I2.B — Handoff-by-workspace (đề xuất user #1)

**Mục tiêu**: node sau nhận **brief "đọc file gì, làm gì"** thay vì nhúng nguyên văn; tự `Read` chọn lọc trong workspace run-dir. Xây trên `{{key_ref}}` (I.C.1).

### Session I2.B.1 — Thiết kế giao thức brief + schema (design + validate, ít/không code runtime)
- **Scope**:
  - Chốt Q1/Q2 (nếu user chưa). Thiết kế format **"## Handoff"** block (producer agent viết cuối output: danh sách file cần đọc trong workspace + directive ngắn cho successor) + convention workspace = run-dir (đã có `<key>.txt`).
  - Engine: định nghĩa field node `handoff: workspace` (opt-in) + key bridge `{{<key>_brief}}` (tách block "## Handoff" từ output producer, giống `Get-RouterPayload` tách `_payload`) HOẶC `{{workspace}}` (đường dẫn run-dir). Chốt key tại session, đăng ký reserved-aware trong `validate.ps1`.
  - `validate.ps1`: `_brief`/`workspace` reserved-aware; WARN nếu consumer dùng `{{x_brief}}` mà producer `x` không khai `handoff`.
  - CHƯA wire executor nặng — chỉ schema + validate + helper thuần `Get-HandoffBrief` (parse, dot-source-safe) + unit test.
- **STOP gate**: helper `Get-HandoffBrief` parse đúng (unit test); `validate` chấp nhận `handoff: workspace` + chặn reserved key mới; `validate hello/loopy/branchy/web-demo/ref-demo` exit 0; `selftest` 12/12. Mock-path bất biến.
- **Output artifact**: `engine/workflow.ps1` (helper + field) + `engine/validate.ps1` (reserved + warn) + doc giao thức trong `patterns/README.md`.

### Session I2.B.2 — Wire executor + fixture pipeline dài
- **Scope**:
  - Wire (ADDITIVE): node `handoff: workspace` → bridge bơm `{{<key>_brief}}` + `{{<key>_ref}}` (path) vào successor thay vì `{{key}}` full; pre-seed + runtime + resume (bám `_payload`/`_ref`). Node KHÔNG khai `handoff` → hành vi cũ y hệt.
  - Fixture mới `examples/handoff-demo/` (pipeline ≥4 node, ≥1 producer output lớn + consumer dùng brief+ref, agent consumer có `Read`). Mock: consumer "đọc" → engine mock trả deterministic; verify prompt consumer = brief + path (KHÔNG full text).
  - Thêm 1 mục selftest `handoff-demo/done-gate` (12→13) — quyết tại session.
- **STOP gate**: `run handoff-demo -Mock` done; prompt consumer chứa brief + path, KHÔNG full text (grep); graph cũ (no `handoff`) chạy y hệt; `selftest` 12/12 hoặc 13/13; regression PASS.
- **Output artifact**: `engine/workflow.ps1` (wire) + `examples/handoff-demo/` + (nếu thêm) `test-runner.ps1`.

### Session I2.B.3 — Selective-read guideline + đo proxy net-thắng
- **Scope**:
  - Tài liệu hoá **điều kiện net-thắng** (output lớn + đọc-một-phần + pipeline dài + tool-def khấu hao) + anti-pattern "đọc-toàn-bộ = tệ hơn" vào `patterns/README.md` + `catalog/README.md`.
  - Đo proxy (`tokens -Anatomy`) trên `handoff-demo` vs biến thể inline tương đương → ghi delta `user_msg` + cảnh báo tool-def cost vào `input-anatomy.md` (§I2.B). Xác định ngưỡng output-size đáng dùng handoff.
- **STOP gate**: guideline + ngưỡng ghi rõ; proxy delta đo được (user_msg giảm ở consumer dùng brief); `selftest` PASS; regression bất biến.
- **Output artifact**: doc net-thắng + §I2.B trong `input-anatomy.md`.

**Phase I2.B gate**: giao thức handoff-by-workspace chạy được (opt-in, additive, lossless), có fixture + ngưỡng + cảnh báo tool-def; mock-path + regression bất biến.

---

## Phase I2.C — Rút chi phí cố định (phần CHI PHỐI real input — I.D.2)

**Mục tiêu**: cắt `tool_defs` + `system_prompt` — theo I.D.2 đây mới là ~50–80% input. Đây là phần ăn tiền THẬT.

### Session I2.C.1 — Tool-set tối thiểu mỗi agent
- **Scope**:
  - Audit `allowedTools` từng agent fixture + catalog mẫu: chỉ giữ tool node THỰC SỰ dùng. Node chỉ-phát-text → KHÔNG tool. Node handoff-by-workspace → CHỈ `Read` (cân nhắc scope thư mục). Bỏ tool dư.
  - Đo (estimator I2.A): tool-def-estimate giảm bao nhiêu/node. Ghi convention "tool tối thiểu" + cảnh báo "mỗi tool = token cố định mỗi call" vào `catalog/README.md`.
  - Wire `Get-AgentFrontmatter` đã truyền `--allowedTools` (Phase 5.1) — chỉ chỉnh frontmatter, KHÔNG code engine. Mock bỏ qua tool.
- **STOP gate**: ≥2 fixture/catalog agent rút tool-set (git diff frontmatter); `run -Mock` done (mock bất biến); `validate` exit 0; estimator cho thấy tool_def_estimate giảm; `selftest` 12/12.
- **Output artifact**: frontmatter `allowedTools` siết + convention `catalog/README.md` + delta `input-anatomy.md`.

### Session I2.C.2 — Lean system-prompt convention
- **Scope**:
  - Chốt Q3. Viết convention **"lean system-prompt"** (vai + ranh giới cốt lõi, bỏ verbose/lặp; phần ổn định để cache hit) vào `catalog/README.md`. Áp cho fixture/catalog mẫu (≥2–3 agent), đo `system_chars` giảm bằng estimator. GIỮ hành vi (mock output cấu trúc ổn định — mock chỉ echo, nên an toàn).
  - KHÔNG viết lại toàn bộ 17 catalog (giữ scope; ghi "áp dần" vào convention).
- **STOP gate**: ≥2–3 agent lean (git diff `.md`); estimator `system_chars` giảm đo được; `run -Mock` done + `validate` exit 0 + `selftest` 12/12; mock-path bất biến.
- **Output artifact**: convention lean system-prompt + agent `.md` siết + delta `input-anatomy.md`.

**Phase I2.C gate**: tool-set + system-prompt rút trên fixture mẫu; estimator chứng minh phần-chi-phối giảm; regression bất biến.

---

## Phase I2.D — Model-tiering có nguyên tắc (đề xuất user #2)

**Mục tiêu**: mỗi node đúng hạng model theo VAI — không cào bằng xuống loại tệ nhất.

### Session I2.D.1 — Bảng vai→hạng model + áp + giữ chất lượng
- **Scope**:
  - Soạn **bảng tier chuẩn** trong `catalog/README.md`: vai chỉ-phát-nhãn (router/gate) → Haiku; vai IO nhẹ/echo/format → Haiku/Sonnet; vai suy luận/thiết kế/QA-reasoning → Sonnet; vai then-chốt độ-khó-cao → Opus. Nguyên tắc rõ: "rẻ khi output ngắn + quyết định đơn giản; KHÔNG hạ model khi cần suy luận — sai → tốn token sửa = đắt hơn".
  - Áp `model:` frontmatter theo bảng cho catalog/fixture mẫu (mở rộng I.B.1 vốn chỉ làm label-node). Verify `Get-AgentFrontmatter`→`--model` (mock bất biến; real-cờ đúng — đọc code, không đốt token).
  - Ghi watch-item: đo chất-lượng-giữ-nguyên defer real-run I2.E.
- **STOP gate**: bảng tier trong `catalog/README.md`; ≥3 agent có `model:` theo tier (không chỉ Haiku — có cả Sonnet/Opus minh hoạ); `run -Mock` done; `validate` exit 0; `selftest` 12/12.
- **Output artifact**: bảng tier + frontmatter `model:` đa-hạng trên fixture/catalog mẫu.

**Phase I2.D gate**: model-tier có nguyên tắc (đa hạng theo vai), không cào bằng; mock-path + regression bất biến.

---

## Phase I2.E — Real-run A/B (⚠️ đốt token — USER-GATE)

**Mục tiêu**: chứng minh real input tokens GIẢM (lần này nhắm đúng system/tool/user) + lossless + chất-lượng-giữ.

### Session I2.E.1 — REAL-RUN A/B report (STOP chờ user bật đèn xanh)
- **Scope** (chốt Q4 fixture + ngân sách token TRƯỚC khi chạy):
  - Chuẩn cặp đo: BASELINE (cấu hình trước I2 — pipeline dài, vd web-demo-scale 11 node) vs OPT (áp handoff-by-workspace + tool-set tối thiểu + lean system-prompt + model-tier). Cùng `user_request`.
  - Chạy THẬT cả hai (no `-Mock`) → `run.ps1 tokens` + `-Anatomy` thu real + breakdown. **Đo nhiều lần nếu ngân sách cho phép** để giảm nhiễu n=1 (ghi rõ n).
  - Báo cáo `plan/hq-v2/phase-i2/token-report-v2.md`: bảng trước/sau (input/output/cache/cost tổng + per-node + **breakdown system/tool/user**), **% giảm real input** (kỳ vọng GIẢM RÕ vì nhắm đúng phần chi phối; ghi số thực dù khác kỳ vọng — TRUNG THỰC như I.D.2).
  - Verify **lossless + chất-lượng**: output cuối baseline vs opt tương đương chất (không mất info do brief/selective-read/model rẻ).
- **STOP gate**: `token-report-v2.md` có số thật trước/sau + breakdown cho thấy real input GIẢM (hoặc giải thích trung thực nếu không); lossless + chất-lượng xác nhận; regression mock bất biến. **Đây là done-gate Phase I2.**
- **Output artifact**: `token-report-v2.md` + cập nhật `CHECKPOINT.md` + bảng tiến độ `ROADMAP.md`.

**Phase I2.E gate** = **Outcome cuối**.

---

## Outcome cuối

- Engine có giao thức **handoff-by-workspace** (brief + selective read, opt-in, additive, lossless) + estimator giải phẫu input + tool-set tối thiểu + lean system-prompt convention + model-tier có nguyên tắc (đa hạng theo vai).
- **Done-gate:** `token-report-v2.md` trên ≥1 pipeline dài thật cho thấy **real input tokens giảm rõ** (nhắm đúng system/tool/user, khác Phase I) HOẶC giải thích trung thực; mock-path + regression (validate hello + run -Mock + selftest 12/12) bất biến mọi session; lossless + chất-lượng giữ trên path thực.
- Cập nhật `ROADMAP.md` (I2 → ✅ DONE) + `CLAUDE.md` Bản đồ file (`engine/anatomy.ps1`/flag `-Anatomy` + field `handoff` + key `_brief`/`workspace` reserved + `examples/handoff-demo/` + bảng tier catalog + `plan/hq-v2/phase-i2/`).

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-06-05 | Initial | Soạn từ 2 đề xuất user (handoff-by-file + model-tier có nguyên tắc) sau phát hiện real-run Phase I (system-prompt+tool-defs chi phối input, template-trim ≈ 0 real savings). 4 quyết định cần chốt Q1–Q4. |
