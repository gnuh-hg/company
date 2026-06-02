# HQ v2 — Roadmap chia phase (team-of-agents + tối ưu token + rẽ nhánh chủ động + HITL hỏi-user + app UX)

> Bản đồ chia đợt **tái thiết kế HQ** thành các phase độc lập; **mỗi phase = 1 long-plan** sẽ soạn riêng khi user yêu cầu (giống `plan/hq-build/ROADMAP.md` + `plan/hq-improve/ROADMAP.md`). File này KHÔNG phải long-plan — chỉ mô tả *cần làm gì* + *cần làm rõ gì* để mỗi lần dựa vào đây dựng PLAN/CHECKPOINT.
>
> **Quy ước thư mục đợt này:** ROADMAP + mọi phase long-plan nằm gọn trong `plan/hq-v2/`. Mỗi phase = `plan/hq-v2/<phase-slug>/PLAN.md` + `CHECKPOINT.md`.
>
> **Nguồn:** 5 vấn đề tồn đọng sau khi đóng `hq-improve` (user nêu 2026-06-02) + giải thích cơ chế rẽ nhánh control-flow/data-flow + 3 quyết định kiến trúc user chốt cùng ngày (xem §Cross-cutting).

---

## ⚠️ ĐẢO CHIỀU một quyết định cũ — đọc trước

`plan/hq-build/ROADMAP.md` §"Quyết định kiến trúc đã chốt" mục 1 ghi: *"Giữ engine ps1 làm substrate — KHÔNG chuyển sang Claude Code team."*

**Đợt này ĐẢO mục đó cho HQ (user chốt 2026-06-02):** HQ chuyển sang **team-of-agents native Claude Code** (subagents + skills, giống leafnote). Engine ps1 **KHÔNG bị bỏ** — nó được **tái định vị thành executor CHỈ-cho-workflow-chi-nhánh**. Lý do user: workflow cho HQ vừa cứng nhắc vừa tốn token (mỗi node = 1 `claude -p` độc lập, re-gửi system prompt + context tích luỹ, không chia sẻ/cache giữa node). "Chỉ cần workflow cho chi nhánh thôi." Xem **CD-1**.

---

## Nền tảng đã có (KHÔNG build lại)

- **Toàn bộ HQ Build DONE** (Phase R/0/1/2/3/4/5/M — `plan/hq-build/ROADMAP.md`): engine v2 (single-cursor walk, router OR, loop + `max_steps`, resume, mock offline), catalog 17 vai, 6 pattern robustness, Tester 2 tầng + sandbox, memory 2 tầng, 6 agent HQ headless, `hq/workflow.json` 11 node, E2E thật (`autobuild`/`autofix`) promote branch thật.
- **Toàn bộ HQ Improve DONE** (Phase A→G — `plan/hq-improve/ROADMAP.md`): 25 finding audit đóng, CLI 13 lệnh tên mới + `selftest` runner, engine HITL (`events.ndjson` 7 loại event full-output + node `approval` pause/resume + `Test-DiffScope`), app web `company/app/` (React+Vite+Tailwind+React Flow+dagre) viewer + live-log SSE + run-control + duyệt + in-app edit graph (`save-graph` validate-gated, coordinate-free).
- **Đây là đợt TÁI THIẾT KẾ** — không phải build mới từ đầu. Chữa 5 vấn đề kiến trúc/UX lộ ra sau khi dùng thật.
- **Ràng buộc bất biến — vẫn giữ 6 quy ước `company/CLAUDE.md`, NHƯNG thu hẹp phạm vi theo CD-1:**
  1. Engine là code cố định; agent `.md` chỉ system prompt — **áp cho ENGINE CHI NHÁNH.** HQ KHÔNG còn chạy qua engine (HQ = `.claude/` config do Claude Code điều phối).
  2. **`workflow.json` chỉ ngữ nghĩa — KHÔNG BAO GIỜ lưu toạ độ.** (App layout lưu riêng `.layout.json` — giữ nguyên từ hq-improve.)
  3. Mock được offline (`-Mock` + `ENGINE_MOCK_ROUTER`) — mọi thay đổi engine giữ mock-path bất biến.
  4. Một surface lệnh duy nhất (`run.ps1`) cho engine chi nhánh.
  5. Module dot-source-safe (guard `InvocationName`/`Line`).
  6. Chỉ thao tác trong `company/`. (Leafnote chỉ đọc tham khảo prior art cho team-of-agents — KHÔNG sửa.)
- **Regression chuẩn mỗi session chạm engine:** `./run.ps1 validate hello` exit 0 · `./run.ps1 run hello "x" -Mock` done · `./run.ps1 selftest` PASS.

---

## Vấn đề khởi phát (5 vấn đề user nêu — 2026-06-02)

1. **HQ không nên là workflow.** Nên là team-of-agents (giống leafnote): orchestrator + subagent + skill đặc thù, mỗi session build 1 agent/skill để đảm bảo chất lượng. Workflow chỉ giữ cho chi nhánh. → **Phase H** (+ CD-1).
2. **Workflow quá tốn token.** Mỗi node = 1 `claude -p` độc lập: re-gửi system prompt (file `.md`) + input template đã resolve (nhúng nguyên văn output thượng nguồn, tích luỹ dần qua loop). Không chia sẻ/cache context giữa node. → **Phase I**.
3. **Mới có node approve, thiếu node để Claude HỎI user khi thiếu thông tin** (clarify mid-task, chờ trả lời free-text). → **Phase K** (+ CD-3).
4. **App UI/UX chưa ổn:** cần workflow bên trái / log bên phải + chỗ nhập input & trả lời câu hỏi (issue 3). → **Phase L**.
5. **Form thêm node khó hiểu:** thêm node lẽ ra dựa trên agent có sẵn của chi nhánh, nhưng form bắt điền `prompt`/field rời rạc. (Thực trạng soi code: ô `prompt` chỉ dùng cho node `approval`, với worker/router là vô dụng + bị nhãn sai "system prompt"; ô `agent` là text tự gõ không phải dropdown catalog; thứ thật-sự-quyết-định-luồng-dữ-liệu là template `input` `{{...}}` thì KHÔNG có trong form.) → **Phase L**.

### Bối cảnh: cơ chế rẽ nhánh hiện tại (control-flow vs data-flow tách rời)
- **Control flow** (đi node nào): node thường → cạnh ra đầu tiên; node `router` → `ConvertTo-RouterLabel(output)` lấy dòng cuối, trim/strip/lower → khớp `when` của cạnh ra → **không khớp = `throw`, run failed** (`engine/workflow.ps1:91-129`). Nhãn `when` trong app = chuỗi engine đem so.
- **Data flow** (node nhận text gì): KHÔNG do cạnh quyết định — do `output_key` + token `{{key}}` trong `input` (`engine/bridge.ps1`). Cạnh A→B *không* khiến B thấy output của A; B chỉ thấy nếu `input` của B chứa `{{<output_key của A>}}`.
- **Điểm yếu user chỉ ra đúng:** nhãn hợp lệ chỉ "biết" qua prose trong `.md` của agent → dễ drift khỏi `edges`; agent in sai chuỗi → chết. → **Phase J** sửa: engine bơm tập nhãn hợp lệ vào prompt lúc chạy (agent không cần hardcode), agent chọn, engine validate + retry.

---

## Cross-cutting — 3 quyết định kiến trúc đã CHỐT (user 2026-06-02, áp mọi phase)

> CD = Core Decision (KHÔNG phải Phase; phase là H–L).

- **CD-1. HQ = team-of-agents native Claude Code.** HQ = orchestrator (lead) + **subagents** (`company/.claude/agents/`) + **skills** (`company/.claude/skills/`), điều phối ĐỘNG bằng reasoning (không DAG cố định). Engine ps1 + app **tái định vị thành CHỈ-lo-workflow-chi-nhánh**; HQ gọi engine như một **tool** (`run.ps1 autobuild/run/...`) để dựng/chạy chi nhánh. `hq/agents/*.md` (headless) + `hq/skills.md` (bảng) là **nguồn để chuyển hoá** sang subagent/skill CC. Router/gate node của HQ (coo/rg_gate/clarify_gate/escalate_gate) **tan vào reasoning của orchestrator** (CC hỏi user / chọn nhánh natively). **Nhịp build: mỗi session = 1 subagent HOẶC 1 skill** (đảm bảo chất lượng — đúng ý user). Lợi token: session chia sẻ + prompt caching thay cho N lần `claude -p` rời rạc.
- **CD-2. Rẽ nhánh = engine bơm choices + chọn-có-validate + retry** (cho engine chi nhánh). Engine đọc cạnh ra của node router → **bơm tập nhãn hợp lệ vào prompt lúc chạy** ("chọn đúng MỘT: { … }") → agent chọn → engine **validate đúng tập cạnh thật** → sai thì **hỏi lại 1 lần** rồi mới fail. Nhãn = nguồn-sự-thật-duy-nhất từ graph, agent KHÔNG hardcode trong `.md` (đúng ý "agent biết node kế, đọc theo code, chủ động chọn"). Mock-path (`ENGINE_MOCK_ROUTER`) bất biến.
- **CD-3. HITL = pause-policy gộp vào node agent.** Mỗi node agent có chính sách dừng `pause: none | always | ask`: `none` chạy thẳng; `always` luôn dừng cho người duyệt (= node `approval` hiện tại, tái dùng hạ tầng `awaiting` Phase D); `ask` = "tùy tình huống" — agent tự quyết lúc chạy có cần hỏi user không, nếu cần → engine pause **`awaiting_input`** (trạng thái MỚI) → chờ **trả lời free-text** → tiêm vào context → chạy tiếp. Dùng chung surface/event với approval; app thêm ô trả lời (Phase L). (Áp cho engine chi nhánh; trong HQ-native, hỏi-user là việc CC làm sẵn.)

**Hệ quả cần nhớ:** sau CD-1, **app + engine phục vụ CHI NHÁNH**, không phải HQ. App default project nên đổi khỏi `hq` (Phase L). Số phận `hq/workflow.json` + `examples/hq-*` + `hq-graph-tests` (legacy workflow HQ): giữ-làm-tham-chiếu hay gỡ — quyết trong Phase H.

---

## Các phase (mỗi phase = 1 long-plan)

### Phase H — HQ thành team-of-agents native (issue 1, CD-1)
- **Mục tiêu:** HQ điều phối động bằng Claude Code subagents + skills, không còn DAG cố định; gọi engine chi nhánh như tool. Mỗi session đẻ 1 subagent hoặc 1 skill chất lượng cao.
- **Xây gì:**
  - **H.0 — Thiết kế orchestration + bố cục `.claude/`** (session đầu, KHÓA reframe trước khi đẻ agent): lead orchestrator điều phối thế nào; map `hq/agents/{coo,researcher,planner,cto,builder,tester,...}` + 5 gate → tập subagent CC + logic orchestrator; map `hq/skills.md` (scaffold/patch/diagnose/run-test/report) → `.claude/skills/<name>/SKILL.md` gọi lệnh engine sẵn có; memory `company/memory/` giữ nguyên hay chuyển `.claude/memory/`; HQ gọi engine ra sao (`autobuild`/`run`/`autofix` + đọc `.runs/`/`events.ndjson`); số phận legacy `hq/workflow.json`.
  - **H.1..H.n — mỗi session 1 subagent/skill:** soạn từng subagent (researcher → planner → cto → builder → tester …) + từng skill, kèm cách tự-kiểm chất lượng (dùng engine `validate`/`check`/`trial` của chi nhánh làm gate khách quan, không để LLM phán cảm tính — giữ tinh thần Tester máy-kiểm-được của hq-build).
- **Cần làm rõ:** orchestrator chạy ở đâu (CC session trong `company/` vs context HQ riêng); subagent có được gọi engine trực tiếp hay chỉ lead gọi; quyền ghi-file của builder-subagent (sandbox/promote như engine hay khác); tham chiếu prior-art leafnote (chỉ đọc) tới mức nào; giữ hay gỡ `hq/workflow.json` + test liên quan trong `selftest`.
- **Phụ thuộc:** không chặn bởi J/K/I (khác lớp). H.0 nên đi TRƯỚC để khoá reframe engine=branch-only mà J/K/L dựa vào.
- **Done-gate:** orchestrator nhận 1 request → research → plan → **dựng + chạy 1 chi nhánh thật qua engine** → test → record, hoàn toàn động (không DAG); so token vs HQ-workflow cũ (kỳ vọng giảm mạnh); mỗi subagent/skill có tiêu chí chất lượng + được 1 lần chạy thử.

### Phase I — Tối ưu token engine chi nhánh (issue 2)
- **Mục tiêu:** giảm token mỗi run workflow chi nhánh, đo được trước/sau.
- **Xây gì:**
  - **Đo lường trước tiên:** harness gom `usage` từ `claude --output-format json` (input/output/cache tokens) → báo cáo token mỗi run/node (baseline để mọi tối ưu có số).
  - **Model-tiering:** router/gate chỉ in 1 nhãn → cho chạy model rẻ (Haiku) qua `model:` frontmatter (đã hỗ trợ từ Phase 5.1, chỉ chỉnh cấu hình).
  - **Siết template `input`:** audit từng node bỏ key dư (vd planner có cần full `{{research}}`+`{{plan}}`+`{{verdict}}` mỗi vòng loop không).
  - **Artifact-by-reference:** output lớn (build/spec) → ghi file, truyền *path/handle* thay vì nhúng nguyên văn; consumer đọc chọn lọc (agent có Read). Lossless, cắt phần nhúng-cả-đống.
  - **Prompt caching:** verify `claude -p` có set `cache_control` không; nếu có → system prompt + tiền-tố ổn định cache qua các call (TTL 5'); nếu không → ghi nhận giới hạn.
  - **⭐ Output định-hướng-đích (handoff-shaped output) — KHOÁ với Phase J** (xuất phát từ câu hỏi user 2026-06-02): vì CD-2 khiến agent **biết node kế là ai**, tách **quyết-định-route** khỏi **payload**, và để agent **chỉ phát phần payload mà successor được-chọn cần** (vd tester route `fail_fix` → chỉ phát chỉ-dẫn-sửa cho builder; route `pass` → phát "ok" gọn cho record) thay vì 1 blob verbose dùng-cho-mọi-nơi. Cắt token tại NGUỒN.
- **Cần làm rõ:** **handoff-output là lossy** — an toàn khi output chỉ nuôi 1 successor ngay sau; RỦI RO khi 1 `output_key` bị nhiều `{{...}}` consume (vd `verdict` consume bởi planner/builder/escalate_gate/escalate_report/record) hoặc re-consume trong loop. → chọn: trim-có-điều-kiện (chỉ khi single-consumer trên path) HAY artifact-by-reference (lossless, consumer pull chi tiết) HAY layer cả hai; cách agent phát "route + payload" (structured 2-phần dùng chung kênh CD-2); ngưỡng kích thước mới ghi-file.
- **Phụ thuộc:** Phase J (handoff-output cần agent-biết-đích của CD-2). Phần còn lại độc lập, có thể đi sớm (đo baseline trước).
- **Done-gate:** báo cáo token trước/sau trên ≥1 chi nhánh thật (vd `landing-email`) cho thấy giảm rõ; mock-path + regression bất biến; lossy-trim (nếu chọn) chứng minh không mất info trên path thực.

### Phase J — Rẽ nhánh chủ động: engine bơm choices + validate + retry (CD-2)
- **Mục tiêu:** router không còn phụ thuộc prose hardcode trong `.md`; sai-form hồi-phục-được thay vì chết; mở khoá handoff-output (Phase I).
- **Xây gì:** `Get-RouterChoices` từ cạnh ra → engine **bơm tập nhãn hợp lệ vào prompt router lúc chạy** (suffix engine-side, KHÔNG sửa `.md` agent); parse lựa chọn (giữ `ConvertTo-RouterLabel` nhưng **validate đúng tập nhãn bơm**); sai → **re-ask 1 lần** với chỉ-dẫn chặt hơn → vẫn sai mới `throw` (giữ hành vi cuối như cũ). Tuỳ chọn: tách "route" khỏi "payload" trong giao thức output (nền cho handoff-output Phase I).
- **Cần làm rõ:** chỗ chứa text bơm (hằng engine vs cấu hình per-node); ngân sách retry (1?); tương tác với `validate` (đã yêu cầu ≥2 cạnh thì mỗi cạnh cần `when`); có thử tool-calling thật không (robust nhất về format nhưng phụ thuộc CLI hỗ trợ forced tool-use headless — verify, có thể defer làm fallback); giữ `ENGINE_MOCK_ROUTER` bất biến (mock trả nhãn, bỏ qua bơm).
- **Phụ thuộc:** engine v2 hiện tại. Độc lập K. Nên trước/cùng I (mở khoá handoff-output).
- **Done-gate:** router với nhãn bơm chọn đúng nhánh; agent in sai → re-ask → phục hồi (demo mock + 1 real); drift prose↔edges không còn vỡ (xoá nhãn khỏi `.md` agent vẫn chạy); mock-path + regression bất biến.

### Phase K — HITL hợp nhất: pause-policy + hỏi-user (issue 3, CD-3)
- **Mục tiêu:** node agent có 3 trạng thái dừng (none/always/ask); thêm khả năng Claude **hỏi user giữa chừng** rồi tiếp tục với câu trả lời.
- **Xây gì:** field `pause: none|always|ask` trên node (hoặc gộp vào schema node sẵn); `always` tái dùng `awaiting` (approval Phase D); `ask` → agent phát tín hiệu có cấu trúc (vd `ASK_USER: <câu hỏi>`) → engine pause trạng thái MỚI **`awaiting_input`** → resume nhận **free-text** → tiêm vào context (key mới, vd `{{user_answer}}`) → chạy tiếp; event mới (`awaiting_input` hoặc `awaiting` + `kind`); `validate` cho `pause`; headless `-AutoApprove` mở rộng (auto-skip ask hoặc fail-rõ).
- **Cần làm rõ:** agent báo "cần hỏi" bằng marker structured vs tool; câu trả lời tiêm vào đâu (re-run node với answer nối thêm vs chạy tiếp); tái dùng event `awaiting` (+`kind: approval|input`) vs event riêng; quy tắc validate `pause` (ask cần agent biết giao thức hỏi).
- **Phụ thuộc:** Phase D infra (awaiting/resume/events — đã có). Độc lập J.
- **Done-gate:** demo mock: node `ask` thiếu info → pause `awaiting_input` → bơm câu trả lời → chạy tới terminal dùng đúng câu trả lời; node `always` vẫn duyệt như approval cũ; node `none`/graph cũ chạy y hệt (regression bất biến).

### Phase L — App UX: layout + I/O + form node (issue 4 + 5)
- **Mục tiêu:** app dễ dùng cho workflow CHI NHÁNH; hỗ trợ hỏi-đáp (Phase K); form thêm node hợp trực giác.
- **Xây gì:**
  - **Layout (issue 4):** chuyển `App.jsx` từ trên-dưới (graph trên / log dưới) sang **trái-phải: graph trái / panel phải** (log + ô request + khu trả lời).
  - **Khu I/O (issue 3+4):** khi `awaiting_input` → hiện câu hỏi + ô free-text → POST câu trả lời (mở rộng `ApprovalPanel`/`/api/decision`); giữ approve/reject cho `always`.
  - **Form node (issue 5):** bỏ ô `prompt` gây hiểu lầm cho worker/router (chỉ giữ cho `approval` = "lời nhắn cho người duyệt"); `agent` → **dropdown từ catalog chi nhánh** (server liệt `catalog/*.md` hoặc `agents/*.md` của project); **phơi luồng dữ liệu** rõ ràng (vd chọn các `output_key` thượng nguồn cần → app biên thành template `{{...}}`) thay vì để trống.
  - **Branch-only:** đổi project mặc định khỏi `hq` (CD-1); phản ánh nhãn route validate-by-engine (Phase J) + trạng thái pause mới (Phase K).
- **Cần làm rõ:** **có ghép data-flow vào control-flow không** — tức nối cạnh A→B có tự-wire `{{A.output_key}}` vào input B (xoá tách-rời gây khó hiểu) hay giữ tách + phơi input rõ; nguồn dropdown agent (catalog chung vs `agents/` của project); mức giữ lại form hiện có.
- **Phụ thuộc:** Phase J + K (UI phản ánh routing + pause mới) + H.0 (biết app là branch-only). Đi sau cùng.
- **Done-gate:** mở app chi nhánh → graph trái / log phải; chạy 1 run có node `ask` → trả lời trong app → chạy tiếp; thêm node = chọn agent từ dropdown + wire data trực quan, Save validate-gated; workflow.json vẫn coordinate-free + luôn hợp lệ.

---

## Thứ tự phụ thuộc (tóm tắt)

```
CD-1 / CD-2 / CD-3 (đã chốt 2026-06-02)
   │
   ├─► Phase H.0 (khoá reframe: engine=branch-only, bố cục .claude/) 
   │      └─► Phase H.1..n (subagent + skill, 1/session)  ───────────────┐
   │                                                                     │
   ├─► Phase J (rẽ nhánh chủ động) ──┬─► Phase I (token: + handoff-output)│
   │                                 │                                   │
   ├─► Phase K (HITL pause/ask) ─────┴───────────────► Phase L (app UX) ◄─┘
   │                                                        ▲
   └────────────────────────────────────────────────────────┘
```

- **H.0 đi đầu** (khoá reframe engine=branch-only mà J/K/L dựa vào). H.1.. (build HQ team) chạy **song song** với engine work J/K/I (khác lớp: `.claude/` vs engine ps1).
- **J trước/cùng I** (handoff-output cần agent-biết-đích của J). Đo token baseline (đầu I) làm sớm được.
- **K độc lập J** (đều build trên Phase D infra).
- **L sau cùng** (cần J+K để phản ánh UI + H.0 để biết branch-only).

---

## Bảng tiến độ

| Phase | Long-plan | Trạng thái |
|---|---|---|
| CD-1/CD-2/CD-3 (cross-cutting) | — | ✅ CHỐT (user 2026-06-02): HQ native team / rẽ-nhánh bơm-choices / HITL pause-policy |
| H — HQ team-of-agents native (#1) | `plan/hq-v2/phase-h/` | 🟡 Long-plan ĐÃ SOẠN (2026-06-02) — 5 sub-phase / 11 session, bắt đầu H.0 (`design.md`). Chốt (user): orchestration=native team TeamCreate · builder ghi-file qua engine sandbox/promote · teammate gọi engine trực tiếp · memory→`.claude/memory/` (tách store engine branch) · legacy giữ tham chiếu + dọn cuối roadmap (xem §Dọn legacy). Chưa thực thi |
| I — Tối ưu token chi nhánh (#2) | `plan/hq-v2/phase-i/` | 📋 Chưa làm — gồm ⭐ handoff-output (khoá với J) |
| J — Rẽ nhánh chủ động (CD-2) | `plan/hq-v2/phase-j/` | 📋 Chưa làm |
| K — HITL pause-policy + hỏi-user (#3, CD-3) | `plan/hq-v2/phase-k/` | 📋 Chưa làm |
| L — App UX layout + I/O + form (#4+#5) | `plan/hq-v2/phase-l/` | 📋 Chưa làm |

---

## Dọn legacy (task cuối đợt — chốt user 2026-06-02)

Sau CD-1, HQ không còn chạy qua `hq/workflow.json`. Trong suốt Phase H–L, các artifact workflow-HQ cũ được **GIỮ làm tham chiếu** (nguồn chuyển hoá agent + đối chiếu). **Cuối roadmap hq-v2** (sau Phase L), làm 1 task DỌN:

- Gỡ `examples/hq-graph-tests.ps1` + `examples/hq-tests.ps1` khỏi `selftest` (giảm mục).
- Archive/xoá `hq/workflow.json` + `hq/workflow.mmd` + `examples/hq-*` (per-agent mock fixtures) khi đã có team-native thay thế.
- Cập nhật `company/CLAUDE.md` bản đồ file (bỏ hàng legacy) + README.

(KHÔNG làm trong Phase H — chỉ ghi nhận để cuối đợt thực thi.)

---

## Cách dùng file này

Mỗi lần build một phase: user trỏ vào phase tương ứng → mình dựng long-plan (`plan/hq-v2/<phase>/PLAN.md` + `CHECKPOINT.md`) theo skill plan-long, **chốt phần "cần làm rõ" của phase đó trước** rồi mới chia session. Cập nhật bảng tiến độ khi một phase xong. Phase H đặc biệt: theo CD-1, **mỗi session = 1 subagent hoặc 1 skill** — H.0 (thiết kế) khoá reframe trước, rồi mỗi session sau đẻ đúng 1 artifact chất lượng cao.
