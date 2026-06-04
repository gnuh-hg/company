# PLAN — Phase I: Tối ưu token engine chi nhánh (hq-v2)

> Sau toàn pipeline: mỗi run workflow **chi nhánh** tốn ít token hơn rõ rệt — có **harness đo được trước/sau** (usage thật từ `claude --output-format json`), router/gate chạy model rẻ, template `input` siết gọn, output lớn truyền **by-reference** (path) thay vì nhúng nguyên văn, payload **định-hướng-đích** (chỉ phát phần successor cần), và prompt-caching được xác minh + tận dụng (hoặc ghi nhận giới hạn). Mock-path + regression bất biến; báo cáo giảm token chứng minh trên ≥1 chi nhánh THẬT.

---

## Context

- **Vì sao chia nhiều session:** đụng nhiều lớp engine (`lib/claude.ps1`, `workflow.ps1`, `bridge.ps1`, `validate.ps1`, dispatcher `run.ps1`) + cần đo-trước-tối-ưu-sau (mỗi thay đổi phải có số) + 1 session real-run **đốt token** cần user-gate. Làm dồn 1 chat sẽ mất chất lượng + không tách được nguyên nhân khi token không giảm.
- **Nền đã có (KHÔNG build lại):**
  - `lib/claude.ps1` đã gọi `claude -p --output-format json` — JSON trả `.result` + **`.usage`/cache/cost** nhưng engine hiện **vứt hết trừ `.result`** (claude.ps1 cuối hàm). → I.A chỉ cần *bắt thêm* usage, không đổi cách gọi.
  - `model:` frontmatter đã wire từ Phase 5.1 (`Get-AgentFrontmatter` → `--model`). → model-tiering là **chỉnh cấu hình**, không phải code mới.
  - **Phase J đã tách route-label vs `_payload`** (`Get-RouterPayload` → auto-store `<output_key>_payload`, pre-seed + runtime + resume). → handoff-output (I.C) **xây tiếp trên** nền này, không làm lại giao thức.
  - `Resolve-Prompt` (bridge.ps1) thay `{{key}}` bằng **nguyên văn** giá trị → nguồn token tích luỹ (loop nhúng cả đống).
- **Quyết định user đã chốt (2026-06-04, trước khi soạn):**
  - **D-I1 — Lossy handoff = LAYER CẢ HAI:** artifact-by-reference (lossless) **làm nền**; conditional-trim **chỉ khi** engine xác định single-consumer trên path. (Q1)
  - **D-I2 — Scope = đủ cả 6 hạng mục** kể cả đào sâu prompt-caching (sửa cách gọi CLI nếu khả thi). (Q2)
  - **D-I3 — Real-run burn = user-gate 1 session cuối:** mọi session mock-only; tách RIÊNG 1 session real-run đốt token ở cuối, **STOP chờ user bật đèn xanh** trước khi chạy. (Q3)
- **Ràng buộc bất biến (6 quy ước `company/CLAUDE.md`, áp engine chi nhánh):** mock-path (`-Mock` + `ENGINE_MOCK_ROUTER`) bất biến mọi session; một surface lệnh `run.ps1`; module dot-source-safe; `workflow.json` chỉ ngữ nghĩa (không toạ độ); chỉ thao tác trong `company/`.
- **Reserved keys** (KHÔNG được làm `output_key`): `user_request`, `user_answer`, `engine_run`, `mem_mistakes`, `mem_patterns`, `mem_context`. **Phase I thêm key bridge mới** (vd `*_ref` cho artifact-by-reference) → phải đăng ký reserved + validate chặn.
- **Regression chuẩn mỗi session chạm engine:** `./run.ps1 validate hello` exit 0 · `./run.ps1 run hello "x" -Mock` done · `./run.ps1 selftest` PASS (11/11). Dọn `.runs/` test sau verify.
- **Out of scope:** tối ưu token cho HQ-team native (CC lo prompt-caching/context sẵn — CD-1); thay đổi mock-path semantics; tối ưu app (Phase L); đụng `engine/*.ps1` ngoài phạm vi token (executor walk/resume logic giữ nguyên).

---

## Pipeline 4 sub-phase / 9 session

```
[I.A] Đo lường (spine)        ──► usage thật bắt từ JSON + harness báo cáo token/node/run + baseline
                                    │
[I.B] Cấu hình rẻ tiền        ──► model-tier (router/gate→Haiku) + template input siết gọn
                                    │
[I.C] Cắt token cấu trúc      ──► artifact-by-reference + handoff-output (route+payload đích) + conditional-trim
                                    │
[I.D] Caching + real gate     ──► prompt-caching verify/tận-dụng + REAL-RUN report trước/sau (user-gate)
                                    │
                                  outcome: token/run giảm rõ, đo được, lossless trên path thực
```

**Phụ thuộc ngoài:** Phase J (DONE — `_payload`), Phase J2 (DONE — routing theo cạnh), Phase 5.1 (DONE — `model:` frontmatter). Tất cả đã xong → Phase I không bị chặn.

---

## Phase I.A — Đo lường (spine: mọi tối ưu sau đo dựa vào đây)

**Mục tiêu**: engine bắt được token usage thật mỗi node/run + có lệnh báo cáo; có **proxy mock** (đếm ký tự prompt/output) để so sánh offline không đốt token.

### Session I.A.1 — Bắt usage từ JSON + emit event
- **Scope**:
  - `lib/claude.ps1`: khi parse `--output-format json`, ngoài `.result` **bắt thêm** `.usage` (input/output/cache_creation/cache_read tokens) + `.total_cost_usd` nếu có. Trả về qua kênh phụ KHÔNG phá chữ ký cũ (vd out-param hashtable `-UsageOut [ref]`, hoặc trả object `{result, usage}` + shim giữ string cho caller cũ — chọn cách additive, mock-path trả usage=$null/proxy).
  - `workflow.ps1`: sau `Invoke-Claude`, ghi usage vào event mới `node_usage` (hoặc mở rộng `node_done` thêm field `usage`) trong `events.ndjson`. Giữ 7 loại event cũ bất biến (chỉ THÊM field/loại).
  - **Mock proxy**: mock-path không có usage thật → tính `{ prompt_chars, output_chars }` (proxy token ≈ chars/4) để so sánh offline. Ghi cùng kênh, đánh dấu `mock=true`.
- **STOP gate**: `run.ps1 run hello "x" -Mock` done + `events.ndjson` có entry usage/proxy cho mỗi node (grep `node_usage` hoặc field `usage` ≥1 dòng); `validate hello` exit 0; `selftest` 11/11. `git diff` chữ ký `Invoke-Claude` cũ vẫn callable (không vỡ caller).
- **Output artifact**: `lib/claude.ps1` + `engine/workflow.ps1` + `engine/events.ps1` (nếu thêm loại event) sửa; event usage trong `events.ndjson`.

### Session I.A.2 — Harness báo cáo + baseline
- **Scope**:
  - Lệnh mới `run.ps1 tokens <project> [-Run <runid>]` (alias-safe, qua dispatcher): đọc `events.ndjson` của run gần nhất → bảng **per-node** (agent · input tok · output tok · cache_read · cost) + **tổng run**. Module mới `engine/tokens.ps1` (hàm thuần `Get-RunTokens` + wrapper), dot-source-safe.
  - Đo **baseline mock proxy** trên `examples/loopy` + `examples/branchy` (2-part) + `examples/web-demo` → ghi `plan/hq-v2/phase-i/baseline.md` (bảng số mock proxy mỗi node/run — mốc để I.B/I.C/I.D so).
  - Cập nhật `selftest`? (KHÔNG bắt buộc; nếu thêm 1 mục `tokens-report/smoke` thì 11→12 — quyết tại session, mặc định KHÔNG thêm để giữ selftest gọn).
- **STOP gate**: `run.ps1 tokens loopy` in bảng per-node + tổng (exit 0); `baseline.md` tồn tại có số cho ≥3 fixture; regression (validate/run -Mock/selftest) PASS.
- **Output artifact**: `engine/tokens.ps1` + dispatcher entry `tokens` + `plan/hq-v2/phase-i/baseline.md`.

**Phase I.A gate**: engine bắt + báo cáo token (thật khi real, proxy khi mock); `baseline.md` có số mốc; regression bất biến.

---

## Phase I.B — Cấu hình rẻ tiền (low-hanging, không đụng executor logic)

**Mục tiêu**: cắt token bằng chỉnh **cấu hình agent + template**, không thêm cơ chế engine.

### Session I.B.1 — Model-tiering router/gate
- **Scope**:
  - Audit fixture/chi nhánh: node **branching** (outdeg≥2, J2 — chỉ in nhãn route) + gate → gắn `model: claude-haiku-4-5-20251001` vào frontmatter agent `.md` tương ứng (`examples/loopy/agents/verdict.md`, `examples/branchy/...`, web-demo gate nếu có).
  - Verify `Get-AgentFrontmatter` → `--model` truyền đúng (đã có Phase 5.1; chỉ xác nhận mock-path bất biến + real-mode cờ đúng).
  - Ghi convention vào `catalog/README.md` hoặc `patterns/README.md`: "node chỉ-phát-nhãn → model rẻ".
- **STOP gate**: agent branching/gate có `model:` frontmatter; `run -Mock` done (mock bỏ qua model → output bất biến); `validate` exit 0; `selftest` 11/11. (Đo token thực defer I.D real-run.)
- **Output artifact**: frontmatter `model:` trên ≥2 fixture node branching/gate + ghi convention.

### Session I.B.2 — Siết template `input`
- **Scope**:
  - Audit từng node fixture: template `input` `{{...}}` có key DƯ không (vd loop `build` có cần cả `{{research}}`+`{{plan}}`+`{{verdict}}` mỗi vòng?). Bỏ key không dùng tới ở node đó.
  - Viết **guideline** "tối thiểu-key input" vào `catalog/README.md` (mỗi node chỉ pull output_key thực-sự-cần; tránh nhúng cả lịch sử).
  - KHÔNG đổi engine — chỉ sửa `workflow.json` fixture + doc. `validate` phải vẫn pass (reachability/key tồn tại).
- **STOP gate**: fixture sửa template vẫn `run -Mock` done + `validate` exit 0; `baseline.md` đo lại proxy thấy ký-tự-prompt giảm ở node đã siết (ghi delta); `selftest` 11/11.
- **Output artifact**: `workflow.json` fixture siết + guideline `catalog/README.md` + delta proxy trong `baseline.md`.

**Phase I.B gate**: model-tier + template-siết áp ≥2 fixture; proxy mock giảm đo được ở node siết; regression bất biến.

---

## Phase I.C — Cắt token cấu trúc (cơ chế engine mới — phần nặng nhất)

**Mục tiêu**: layer **artifact-by-reference (nền, lossless)** + **handoff-output đích** + **conditional-trim (single-consumer)** theo D-I1.

### Session I.C.1 — Artifact-by-reference (nền lossless)
- **Scope**:
  - Cơ chế: khi output node > **ngưỡng** (cấu hình, vd 2000 ký tự — chốt số tại session, ghi vào doc) → engine vẫn ghi `<output_key>.txt` như cũ NHƯNG bridge bơm **handle path** qua key phụ `{{<key>_ref}}` (đường dẫn tới `.txt`) thay vì nhúng cả văn bản. Consumer (agent có `Read`) tự đọc chọn lọc.
  - `bridge.ps1`/`workflow.ps1`: thêm `<key>_ref` vào context (pre-seed như `_payload`); template tác giả chọn `{{key}}` (nhúng full) HAY `{{key_ref}}` (path) — opt-in, **không đổi hành vi cũ** node không dùng `_ref`.
  - `validate.ps1`: `*_ref` reserved-aware (không cho làm `output_key`); cảnh báo nếu `{{x_ref}}` mà `x` không phải output_key node nào.
  - Fixture demo: thêm node output lớn + consumer dùng `{{key_ref}}` (mock: agent Read path → engine mock trả path; verify resolve thành path không nhúng full).
- **STOP gate**: graph dùng `{{key_ref}}` → `run -Mock` done, prompt node consumer chứa **path** (không phải full text — proxy chars giảm); graph KHÔNG dùng `_ref` chạy y hệt cũ; `validate` chặn `_ref` làm output_key; `selftest` 11/11 (+ mục mới nếu thêm fixture).
- **Output artifact**: `bridge.ps1`/`workflow.ps1`/`validate.ps1` sửa (additive `_ref`) + fixture `examples/ref-demo/` (hoặc mở rộng fixture sẵn) + doc ngưỡng.

### Session I.C.2 — Handoff-output đích (route + payload shaped-per-successor)
- **Scope**:
  - Xây tiếp Phase J: node branching đã tách `_payload`. Mở rộng để agent **biết successor được-chọn** (engine đã có tập choices từ J `Get-RouterChoices`) → agent phát payload **chỉ cho nhánh đó** (vd `fail_fix` → chỉ-dẫn-sửa cho builder; `pass` → "ok" gọn cho record).
  - Giao thức output 2-phần dùng chung kênh CD-2/J (`_payload`): tài liệu hoá format "dòng route + khối payload"; engine route theo dòng nhãn (J nguyên trạng), payload bơm qua `{{<key>_payload}}` (J nguyên trạng) — Phase I chỉ **làm rõ + demo handoff đích**, có thể KHÔNG cần code engine mới nếu J đủ.
  - Cập nhật agent `.md` fixture branching (vd `loopy/verdict`) hướng dẫn phát payload theo nhánh; mock `ENGINE_MOCK_ROUTER` multi-line (J.4 đã hỗ trợ `_payload` flow).
- **STOP gate**: fixture branching mock → payload nhánh-được-chọn flow đúng qua `{{key_payload}}`; route vẫn đúng; `selftest` branchy/2-part-protocol PASS (#10); regression bất biến. Nếu phát hiện cần code engine → ghi rõ scope thêm vào CHECKPOINT, KHÔNG nhồi quá session.
- **Output artifact**: doc giao thức handoff trong `patterns/README.md` + agent `.md` fixture cập nhật + (nếu cần) sửa nhỏ `workflow.ps1`.

### Session I.C.3 — Conditional-trim (single-consumer trên path)
- **Scope**:
  - Engine xác định `output_key` có **single-consumer** không: quét tập `{{...}}` của mọi node trên graph → key chỉ bị 1 node consume + không re-consume trong loop → đủ điều kiện trim.
  - Khi single-consumer → cho phép trim payload (chỉ giữ phần successor cần, kết hợp handoff I.C.2); multi-consumer (vd `verdict` consume bởi planner/builder/escalate/record) → **giữ full HOẶC artifact-ref** (I.C.1), KHÔNG trim.
  - Helper thuần `Test-SingleConsumer $Graph $OutputKey` (dot-source-safe) + wire vào quyết định trim/keep. **Bảo thủ:** mặc định KHÔNG trim; chỉ trim khi chắc-chắn single-consumer (an toàn > tiết kiệm).
  - Chứng minh **không mất info trên path thực**: test mock graph multi-consumer → key KHÔNG bị trim (full đến mọi consumer).
- **STOP gate**: `Test-SingleConsumer` tồn tại + test: single-consumer key → trim-eligible, multi-consumer key (verdict-style) → giữ full; graph cũ chạy y hệt; `selftest` 11/11; regression bất biến.
- **Output artifact**: `engine/workflow.ps1` (helper + wire) + fixture/test multi-consumer chứng minh lossless.

**Phase I.C gate**: 3 lớp layer đúng D-I1 (artifact-ref nền + handoff đích + trim chỉ single-consumer); mock graph multi-consumer chứng minh lossless; mock-path + regression bất biến.

---

## Phase I.D — Prompt-caching + real-run gate (đốt token cuối)

**Mục tiêu**: xác minh + tận dụng prompt-caching; chứng minh token giảm trên chi nhánh THẬT.

### Session I.D.1 — Prompt-caching: verify + tận dụng (mock-only)
- **Scope**:
  - Verify `claude -p` có set `cache_control` / nhận cache không: đọc `.usage.cache_creation_input_tokens`/`.cache_read_input_tokens` từ JSON (đã bắt I.A.1). Nếu CLI tự cache system-prompt → xác nhận; nếu **expose cờ** (`--cache`...) → wire vào `lib/claude.ps1` (additive); nếu KHÔNG khả thi qua CLI headless → **ghi nhận giới hạn** rõ ràng trong doc.
  - Nếu cache được: bảo đảm system-prompt + tiền-tố ổn định (frontmatter→`--system-prompt-file` đã ổn định) để hit cache (TTL 5'); ghi convention thứ-tự-prompt.
  - Mock-only ở session này (chỉ đọc code CLI + dàn cờ); đo cache thật để I.D.2.
- **STOP gate**: kết luận rõ "cache được/không + cách" ghi `plan/hq-v2/phase-i/caching.md`; nếu wire cờ → `run -Mock` done + mock-path bất biến + `selftest` 11/11; nếu chỉ-document → không đụng code.
- **Output artifact**: `plan/hq-v2/phase-i/caching.md` + (nếu wire) `lib/claude.ps1` sửa additive.

### Session I.D.2 — REAL-RUN token report (⚠️ ĐỐT TOKEN — USER-GATE)
- **Scope** (D-I3: **STOP chờ user bật đèn xanh trước khi chạy real**):
  - Chạy **THẬT** (no `-Mock`) ≥1 chi nhánh có sẵn (vd `projects/todo-web/` hoặc tái dựng `landing-email`) **TRƯỚC** các tối ưu (revert/baseline config) và **SAU** (model-tier + template-siết + artifact-ref + caching áp dụng) → `run.ps1 tokens` thu usage thật.
  - Báo cáo `plan/hq-v2/phase-i/token-report.md`: bảng trước/sau (input/output/cache/cost tổng + per-node), tính **% giảm**.
  - Verify **lossless trên path thực**: output cuối (artifact chi nhánh) trước/sau tương đương về chất (không mất info do trim/ref).
- **STOP gate**: `token-report.md` có số thật trước/sau cho thấy **giảm rõ** (kỳ vọng ≥20% tổng, ghi số thực đo được dù thấp hơn); lossless xác nhận; regression mock bất biến. **Đây là done-gate Phase I.**
- **Output artifact**: `plan/hq-v2/phase-i/token-report.md` (số thật) + cập nhật `CHECKPOINT.md` + bảng tiến độ ROADMAP.

**Phase I.D gate** = **Outcome cuối**.

---

## Outcome cuối

- Engine bắt + báo cáo token thật (`run.ps1 tokens`) + proxy mock offline.
- Router/gate chạy model rẻ; template input siết; output lớn by-reference; payload đích; trim chỉ single-consumer (lossless path thực); prompt-caching tận dụng hoặc giới hạn được ghi nhận.
- **Done-gate (ROADMAP §Phase I):** báo cáo token trước/sau trên ≥1 chi nhánh thật cho thấy giảm rõ; mock-path + regression (validate hello + run hello -Mock + selftest) bất biến mọi session; lossy-trim chứng minh không mất info trên path thực.
- Cập nhật `ROADMAP.md` bảng tiến độ (I → ✅ DONE) + `CLAUDE.md` Bản đồ file (`engine/tokens.ps1` + lệnh `tokens` + key `_ref` reserved + `plan/hq-v2/phase-i/`).

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-06-04 | Initial | Soạn từ ROADMAP §Phase I + 3 quyết định user D-I1/2/3 (layer cả hai · đủ 6 hạng mục · real-run user-gate cuối) |
