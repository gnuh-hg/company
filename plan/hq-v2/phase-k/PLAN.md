# PLAN — Phase K: HITL hợp nhất (pause-policy + hỏi-user, CD-3)

> Sau toàn bộ pipeline: node agent của workflow chi nhánh có chính sách dừng `pause: none|always|ask`
> — `none` chạy thẳng (bất biến), `always` chạy agent XONG rồi dừng cho người duyệt output, `ask` cho
> agent **tự quyết hỏi user giữa chừng** bằng marker `ASK_USER:` → engine pause trạng thái MỚI
> `awaiting_input` → người trả lời free-text → engine tiêm `{{user_answer}}` → **chạy lại đúng node đó**
> tới khi hoàn thành. `type:approval` cũ + graph không-pause chạy y hệt.

---

## Context

- **Vì sao chia nhiều session:** đụng **engine executor** (`workflow.ps1` — vùng nhạy cảm nhất, quy
  ước "engine cố định") + 5 module phụ (validate/status/events/run/test-runner) + fixture + docs. Mỗi
  thay đổi executor phải chạy regression (validate hello + run -Mock + selftest) NGAY → tách session để
  mỗi bước có STOP gate đo được, giữ context sạch.
- **Nền đã có (Phase D — KHÔNG build lại):** trạng thái `awaiting` + `state.awaiting:{node,prompt,choices}`
  + `Resume-Workflow -Decision` resolve decision→cursor (`workflow.ps1:434-507`) + event `awaiting`/`resumed`
  (`events.ps1:17-20`) + `-AutoApprove` happy-path (`workflow.ps1:585-603`) + surface `status`/`run.ps1 resume`.
  Phase K **mở rộng** hạ tầng này, KHÔNG dựng mới.
- **4 quyết định đã CHỐT (user 2026-06-04)** — xem §Quyết định. Long-plan này dựa trên 4 lựa chọn ĐỀ XUẤT.
- **Ràng buộc bất biến (company/CLAUDE.md):** engine là code cố định (sửa ở HÀM THUẦN, không nhồi nhánh
  direct-run); `workflow.json` chỉ ngữ nghĩa; **mock-path bất biến** (`-Mock` + `ENGINE_MOCK_ROUTER` cho
  output xác định); một surface lệnh `run.ps1`; module dot-source-safe; chỉ thao tác trong `company/`.
- **Regression chuẩn mỗi session:** `./run.ps1 validate hello` exit 0 · `./run.ps1 run hello "x" -Mock`
  done · `./run.ps1 selftest` PASS (số mục hiện tại; K.5 nâng 10→11).
- **Out of scope:** App UI cho awaiting_input (ô câu hỏi + ô trả lời) = **Phase L** — Phase K chỉ đảm bảo
  engine phát đủ event (`awaiting` kind=input + question) + server-surface qua `state.json`/`run.ps1`.
  Forced tool-use (thay marker) = defer (xem D-K1). HQ-native hỏi-user = việc Claude Code làm sẵn, KHÔNG
  qua engine (CD-3).

---

## Quyết định đã CHỐT (user 2026-06-04)

| # | Quyết định | Hệ quả thiết kế |
|---|---|---|
| **D-K1** | Tín hiệu `ask` = **marker văn bản** `ASK_USER: <câu hỏi>` (KHÔNG forced tool-use) | Helper `Get-AskRequest` parse marker (cùng họ `ConvertTo-RouterLabel`/`Get-RouterPayload`). Mock-được qua `ENGINE_MOCK_ROUTER` keyed-by-node. Forced tool-use defer. |
| **D-K2** | Tiêm answer = **re-run node đã hỏi** với `{{user_answer}}` | Node ask thiếu info → bơm `user_answer` vào context → cursor giữ nguyên node đó, chạy lại tới khi không còn `ASK_USER:`. Output_key của node ask chỉ ghi khi node HOÀN THÀNH (không ask). |
| **D-K3** | Pause-policy **đầy đủ** `pause: none\|always\|ask` trên node worker; `type:approval` cũ GIỮ NGUYÊN | `always` = chạy agent XONG → pause kind=approval (khác approval-node: approval không gọi model). `ask` = runtime-decided. `none` = bất biến. |
| **D-K4** | State **mới** `awaiting_input` + **reuse** event `awaiting` + field `kind: approval\|input` | `state.status='awaiting_input'`; event vẫn `type='awaiting'` thêm `kind`. KHÔNG thêm loại event mới → app/SSE Phase L phân biệt qua `kind`. |

---

## Pipeline 3 sub-phase / 6 session

```
[K.A Foundation]  K.1 schema+validate+fixture ─────► pause enum validate + user_answer reserved + ask-demo
                  K.2 ask-pause executor      ─────► Get-AskRequest + awaiting_input pause + event kind=input
                                                          │
[K.B Resume+Always] K.3 resume -Answer (re-run)  ──────► tiêm user_answer + cursor=node ask + event resumed kind=input
                  K.4 pause:always (run-then-gate) ────► worker always → run agent → awaiting kind=approval
                                                          │
[K.C Surface]     K.5 dispatcher+status+selftest ─────► run.ps1 -Answer + status question/hint + selftest #11 (→11)
                  K.6 docs+viz+done-gate         ─────► viz pause marker + CLAUDE.md/README/ROADMAP + done-gate 4/4
```

---

## Phase K.A — Foundation: schema + state ngôn ngữ

**Mục tiêu**: khai báo `pause` + reserved key `user_answer` + fixture demo; engine NHẬN BIẾT pause:ask và
pause khi chạy (chưa cần resume) — pause `awaiting_input` thành hiện thực.

### Session K.1 — Schema `pause` + validate + reserved key + fixture skeleton
- **Scope**:
  - `engine/validate.ps1`: chấp nhận field `pause` trên node, enum `none|always|ask` (vắng = `none`).
    Lỗi rõ nếu giá trị lạ. Luật: `pause` chỉ áp node worker (type vắng/`work`/`worker`); node `type:approval`
    có `pause` → lỗi (approval đã là gate, không gộp). Thêm `user_answer` vào `$script:ReservedKeys`
    (để `{{user_answer}}` resolve được như `user_request`).
  - `engine/workflow.ps1` → `Initialize-Context`: pre-seed `$ctx['user_answer'] = ''` (như `engine_run`).
  - Fixture `examples/ask-demo/`: graph 3 node — `clarify` (worker, `pause: ask`, input chứa
    `{{user_request}}` + `{{user_answer}}`, output_key `spec`) → `build` (worker, input `{{spec}}`,
    output_key `result`) → terminal. + 2 agent stub (`agents/clarify.md`, `agents/build.md`).
  - KHÔNG đụng executor pause-logic ở session này (chỉ schema/validate/context/fixture).
- **STOP gate**: `./run.ps1 validate ../examples/ask-demo` exit 0; `./run.ps1 validate hello` exit 0;
  `./run.ps1 run hello "x" -Mock` done; `./run.ps1 selftest` PASS (số mục hiện tại); 1 ca validate âm
  tay (node có `pause: bogus` → exit ≥1) xác nhận enum bắt lỗi.
- **Output artifact**: `validate.ps1` (pause enum + user_answer reserved) + `workflow.ps1` Initialize-Context
  (pre-seed user_answer) + `examples/ask-demo/` (workflow.json + 2 agent stub).

### Session K.2 — Executor: `pause: ask` → `ASK_USER:` → `awaiting_input`
- **Scope**:
  - `engine/workflow.ps1`: helper thuần `Get-AskRequest [string]$Output` → trả câu hỏi (text sau
    `ASK_USER:`) nếu output có marker, ngược lại `$null` (dot-source-safe, mock-an-toàn).
  - Executor: SAU khi node worker chạy agent, NẾU `pause:ask` + `Get-AskRequest` ≠ $null →
    pause: `visit.status='awaiting'`; `state.status='awaiting_input'`; `state.awaiting =
    {node, kind:'input', question, prompt}`; `latest.json status='awaiting_input'`; event
    `Write-Event 'awaiting' @{node;kind='input';question;step}`; **KHÔNG ghi output_key** (node chưa
    xong); `return $runDir`. Nếu KHÔNG có marker → node hoàn thành bình thường (ghi output_key, đi tiếp).
  - Mock: dùng `ENGINE_MOCK_ROUTER` keyed-by-node để `clarify` trả `ASK_USER: ...` ở lần gọi 1.
- **STOP gate**: chạy `examples/ask-demo` mock (mock spec cho `clarify` trả `ASK_USER:`) → `state.status
  == 'awaiting_input'` + `state.awaiting.kind == 'input'` + `events.ndjson` có dòng `type:awaiting`
  `kind:input`; `output_key` `spec` CHƯA ghi ra đĩa. Regression: validate hello + run hello -Mock done +
  selftest PASS.
- **Output artifact**: `workflow.ps1` (Get-AskRequest + pause:ask pause-path).

**Phase K.A gate**: `pause:ask` node dừng đúng `awaiting_input` với question; graph cũ + approval-node
chạy y hệt; mock-path bất biến.

## Phase K.B — Resume + always-gate

**Mục tiêu**: hoàn tất vòng hỏi-đáp (resume `-Answer` re-run node) + thêm `pause:always` (run-then-gate).

### Session K.3 — Resume `-Answer` → tiêm `user_answer` → re-run node
- **Scope**:
  - `engine/workflow.ps1` → `Invoke-Workflow`: param mới `[string]$Answer = ''`. Khi resume gặp
    `state.status == 'awaiting_input'`: tiêm `$context['user_answer'] = $Answer`; **cursor = node đã hỏi**
    (re-run, KHÔNG advance); lượt awaiting cũ đưa vào visits status 'done' (đã xử lý) hoặc bỏ qua hợp lý
    để re-run sinh visit mới (iter+1); xoá field `awaiting`; reset status='running'; event
    `Write-Event 'resumed' @{node;kind='input';answer}`. Re-run lại đi qua pause-path K.2 → nếu agent
    còn `ASK_USER:` → pause lại (max_steps là cầu dao chống loop hỏi vô hạn).
  - Tách rõ nhánh `awaiting_input` resume KHỎI nhánh `awaiting` (approval) resume hiện có (đừng phá D.3).
- **STOP gate**: `examples/ask-demo` mock — run → `awaiting_input` → `resume -Answer "dùng màu xanh"
  -Mock` → `state.status == 'done'`; file prompt re-run của `clarify` (`<seq>-clarify.prompt.txt`) CHỨA
  chuỗi `dùng màu xanh` (chứng minh `{{user_answer}}` tiêm thật); terminal `result.txt` tồn tại.
  Regression chuẩn PASS.
- **Output artifact**: `workflow.ps1` (Invoke-Workflow `-Answer` + awaiting_input resume re-run).

### Session K.4 — `pause: always` (run-then-gate)
- **Scope**:
  - `engine/workflow.ps1`: node worker `pause:always` → chạy agent XONG (ghi output_key) → pause
    `state.status='awaiting'` (reuse trạng thái approval) `state.awaiting={node,kind:'approval',prompt,choices}`
    + event `awaiting` kind=approval; resume `-Decision` advance theo cạnh ra (reuse logic D.3
    Select-NextNode / awaiting resume). Khác `type:approval`: always CÓ gọi model + CÓ output_key.
  - `-AutoApprove`: mở rộng để auto-skip `pause:always` (happy-path) như approval node hiện tại; với
    `pause:ask` → fail-rõ (headless không có người trả lời) HOẶC auto-skip với answer rỗng — chọn
    **fail-rõ** mặc định (đồng nhất D.4 "headless default fail-rõ"); ghi rõ trong log/throw.
- **STOP gate**: fixture (mở rộng ask-demo hoặc node phụ) — node `pause:always` chạy agent → status
  `awaiting` kind=approval → `resume -Decision approve` → done, output_key của node always ĐÃ ghi
  trước khi pause. `-AutoApprove` qua always = không dừng; qua ask = fail-rõ. Regression PASS.
- **Output artifact**: `workflow.ps1` (pause:always run-then-gate + AutoApprove mở rộng).

**Phase K.B gate**: vòng ask đầy-đủ (pause→answer→re-run→done) + always (run→gate→advance) chạy mock;
`-AutoApprove` xử lý đúng cả hai; mock-path + regression bất biến.

## Phase K.C — Surface + polish

**Mục tiêu**: phơi awaiting_input qua CLI + status; selftest tự verify; docs + viz; done-gate tổng.

### Session K.5 — Dispatcher `-Answer` + status + selftest #11
- **Scope**:
  - `engine/run.ps1`: parse flag `-Answer <text>` (như `-Decision`); `resume` truyền `-Answer`; surface
    `awaiting_input` (return code riêng / hint `./run.ps1 resume <proj> -Answer "<trả lời>"` + in question).
    Cập nhật help dòng `resume`.
  - `engine/status.ps1` → `Show-Status`: khi `status == 'awaiting_input'` in question + resume hint
    `-Answer` (song song nhánh approval hiện có). `Get-StatusColor`/`Get-VisitMark` thêm `awaiting_input`.
  - `engine/test-runner.ps1`: selftest item MỚI `ask-demo/done-gate` — inline mock: run → assert
    `awaiting_input` → `resume -Answer` → assert `done` + prompt re-run chứa answer. **10 → 11 mục.**
    Cập nhật header comment + dòng tổng kết.
  - (tuỳ) `engine/events.ps1`: comment ghi rõ `awaiting` mang `kind` (approval|input) — KHÔNG thêm loại.
- **STOP gate**: `./run.ps1 run ../examples/ask-demo "x" -Mock` (mock ask) in hint `-Answer` + return
  code awaiting_input; `./run.ps1 resume ../examples/ask-demo -Answer "xanh" -Mock` → done; `./run.ps1
  status ../examples/ask-demo` hiển thị question khi awaiting_input; `./run.ps1 selftest` = **11/11 PASS**.
  Regression hello PASS.
- **Output artifact**: `run.ps1` (-Answer) + `status.ps1` (awaiting_input surface) + `test-runner.ps1`
  (selftest #11).

### Session K.6 — viz pause marker + docs + done-gate tổng
- **Scope**:
  - `engine/viz.ps1` (tuỳ chọn nhẹ): node `pause:always`/`pause:ask` có tag ASCII (vd `⏸ask`/`⏸always`)
    + Mermaid marker; KHÔNG phá render hiện có (approval hexagon bất biến).
  - Docs: `company/CLAUDE.md` bảng file-map (ghi chú workflow.ps1 Phase K + ask-demo) + Quy ước bất biến
    #2 (thêm `pause` + `user_answer` reserved); `README.md` (mục HITL: pause-policy + awaiting_input +
    `resume -Answer`); `plan/hq-v2/ROADMAP.md` bảng tiến độ (Phase K ✅).
  - Dọn `.runs/` test; `git diff` xác nhận chỉ đụng file trong scope.
- **STOP gate (done-gate tổng 4/4)**:
  1. `ask` mock: thiếu info → `awaiting_input` → `resume -Answer` → terminal dùng đúng câu trả lời
     (prompt re-run chứa answer).
  2. `always` mock: chạy agent → `awaiting` kind=approval → `resume -Decision approve` → done.
  3. `none`/graph cũ + `approval-demo` + `branchy`: chạy y hệt (regression bất biến) — selftest 11/11.
  4. validate hello exit 0 + run hello -Mock done; `git diff` chỉ trong file scope Phase K; docs phản ánh.
- **Output artifact**: `viz.ps1` (pause marker) + docs cập nhật + ROADMAP ✅.

**Phase K.C gate**: = done-gate tổng (4/4) + selftest 11/11.

## Outcome cuối

- Engine chi nhánh có HITL hợp nhất: `pause: none|always|ask` + trạng thái `awaiting_input` +
  `resume -Answer` (re-run node) + event `awaiting` kind=input/approval — nền cho Phase L (app UX hỏi-đáp).
- Mock-path + graph cũ + approval-node bất biến; selftest 11/11; engine sửa ở hàm thuần.
- **Gate đo lường:** done-gate 4/4 ở K.6 + selftest 11/11.

---

## Rủi ro / lưu ý

- **Loop hỏi vô hạn**: agent `ask` luôn in `ASK_USER:` → re-run mãi. Cầu dao = `max_steps` (mỗi re-run
  +1 seq). KHÔNG thêm guard riêng (giữ engine gọn) — ghi chú trong docs.
- **Đừng phá D.3**: nhánh resume `awaiting` (approval) hiện có rất tinh tế (visits/iter/cursor). K.3 phải
  TÁCH nhánh `awaiting_input` riêng, không sửa đè nhánh approval. Regression `approval-demo` mỗi session.
- **output_key của node ask**: chỉ ghi khi node HOÀN THÀNH (không marker). Pause giữa chừng KHÔNG ghi →
  tránh consumer thượng nguồn đọc giá trị dở. Re-run thành công mới ghi.
- **Mock marker**: `ENGINE_MOCK_ROUTER` trả chuỗi cố định (không resolve template) → done-gate chứng minh
  tiêm `user_answer` qua **prompt file re-run** (chứa answer), KHÔNG qua output mock.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-06-04 | Initial | Soạn từ `plan/hq-v2/ROADMAP.md` Phase K + 4 quyết định user chốt (D-K1..D-K4) |
