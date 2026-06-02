# PLAN — Phase H: HQ thành team-of-agents native Claude Code (CD-1)

> Sau toàn bộ pipeline: HQ không còn chạy qua `hq/workflow.json` (DAG cố định). HQ = **một team native Claude Code** — lead orchestrator điều phối ĐỘNG bằng reasoning + spawn teammate (`.claude/agents/*.md`) qua tính năng **agent teams** (TeamCreate), teammate giao tiếp SendMessage + Task queue chung bằng **văn xuôi tự nhiên**, builder **build deliverable TRỰC TIẾP** (Write/Edit). Engine ps1 + app là **tool workflow-chi-nhánh đứng riêng**, HQ KHÔNG bắt buộc đi qua. Done = 1 request thật chạy trọn research→plan→build→test→record hoàn toàn động, đo token giảm so với HQ-workflow cũ.
>
> **⚠️ REVISE 2026-06-02 (Q2 reframe):** bản đầu chốt "builder ghi file QUA engine `autobuild`/`autofix`" + "planner plan-as-data JSON" + "cto build-spec cho `run.ps1 build`". User chỉ ra teammate **lậm form workflow cũ** (xuất JSON cho engine parse trong khi không engine nào parse). **Đảo:** build TRỰC TIẾP, giao tiếp prose, bỏ build-spec/workflow.json/plan-as-data khỏi luồng HQ. Legacy `hq/` + `examples/hq-*` + 2 test script **đã XÓA**; selftest 12→10. Các session H.4–H.6 + skill H.7 viết lại theo đây. Xem `design.md` §Revise + §5/§7/§8.

---

## Context

- **Vì sao chia nhiều session:** đây là tái thiết kế kiến trúc, không phải patch. Phải (1) khoá reframe + bố cục `.claude/` trước khi đẻ agent (H.0), (2) dựng nền team (flag + memory + playbook + hooks), (3) **mỗi teammate/skill = 1 session** (ràng buộc chất lượng CD-1 — "mỗi session đẻ 1 agent/skill"), (4) hợp nhất + chạy thật end-to-end. Gộp lại sẽ ẩu + mất chất lượng từng agent.
- **Quyết định đã chốt (user 2026-06-02, input cho H):**
  - **Orchestration = native team (TeamCreate)** kiểu leafnote — lead + teammate bền vững + SendMessage + Task queue + `teams/playbook.md` (vòng đời + anti-pattern + issue queue). KHÔNG dùng subagent one-shot.
  - **~~Builder ghi file = qua engine~~ → REVISE Q2: Builder build TRỰC TIẾP** — builder teammate Write/Edit file deliverable vào `projects/<name>/` + Bash chạy build/test. KHÔNG `run.ps1 autobuild/autofix`, KHÔNG workflow.json. (Lý do đảo: engine-build là form workflow cũ; HQ team là team code thực thụ, build trực tiếp.)
  - **~~Teammate gọi engine trực tiếp~~ → REVISE Q2: HQ KHÔNG đi qua engine để build.** Engine `run.ps1` + app là tool workflow-chi-nhánh đứng riêng; chỉ gọi nếu request CỤ THỂ là dựng/sửa workflow pipeline (ngoại lệ). Tester verify bằng check của chính deliverable (test/build/lint exit-code), KHÔNG `run.ps1 check/trial`.
  - **Memory → `.claude/memory/`** kiểu leafnote (`context/mistakes/patterns/global.md`) cho memory của HQ-team. Engine branch store `company/memory/` + `<project>/memory/` **GIỮ NGUYÊN** (engine `memory.ps1` bất biến). `.claude/memory/` là store *làm việc của HQ-team* (tách bạch).
  - **~~Legacy giữ làm tham chiếu~~ → REVISE Q2: Legacy ĐÃ XÓA** (`hq/` + `examples/hq-*` + `hq-tests.ps1` + `hq-graph-tests.ps1`, git rm 2026-06-02) vì là nguồn lậm form. `engine/test-runner.ps1` de-wire 2 script (selftest 12→10), `e2e-harness-tests` repoint `loopy`. `engine/e2e.ps1` (autobuild/autofix) giữ code nhưng vestigial (hardcode 'record', HQ không dùng).
- **Ràng buộc external / tiền đề kỹ thuật:**
  - Agent teams **experimental** — bật bằng `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (settings.json `env`), cần Claude Code **≥ v2.1.32** (verify đầu H.1; nếu thiếu → blocker, báo user nâng cấp).
  - Teammate def = subagent `.claude/agents/<name>.md`: frontmatter `tools`+`model` được honor, body nối vào system prompt. **`skills`+`mcpServers` trong frontmatter teammate BỊ BỎ QUA** → skill phải đặt project-scope `.claude/skills/` (dùng chung mọi teammate). Teammate đọc CLAUDE.md + project context, KHÔNG kế thừa history lead.
  - Limitations: 1 team/lúc · no nested team (chỉ lead spawn) · permission set lúc spawn (teammate kế thừa lead) · no resume in-process teammate. Plan phải sống với các giới hạn này.
- **Out of scope (phase khác trong hq-v2):** tối ưu token engine chi nhánh + handoff-output (Phase I), rẽ-nhánh bơm-choices (Phase J), HITL pause/ask engine (Phase K), app UX branch-only (Phase L). H KHÔNG đụng engine **executor** (`engine/workflow.ps1`/`bridge.ps1`/`graph.ps1`/...). Mọi sửa engine logic để dành J/K.
- **Regression mỗi session chạm filesystem:** `./run.ps1 validate hello` exit 0 · `./run.ps1 run hello "x" -Mock` done · `./run.ps1 selftest` PASS (**nay 10/10** sau de-wire). **Ngoại lệ engine-diff (chỉ session reframe Q2 2026-06-02):** session này CÓ sửa `engine/test-runner.ps1` (de-wire 2 script) + `engine/spec.ps1` (2 comment dangling) — executor (`workflow/bridge/graph/validate/...`) KHÔNG đụng. Các session H sau: `git diff engine/` RỖNG lại.

---

## Pipeline 5 sub-phase / 11 session

```
[H.0] Thiết kế + khoá reframe ───────► design.md (orchestration spec + roster + .claude/ layout)
                                           │
[H-A] Nền team ──────────────────────► flag + .claude/{memory,agents,skills} + playbook skeleton   (H.1)
                                           │
[H-B] Teammate (1/session) ──────────► researcher·planner·cto·builder·tester .claude/agents/*.md   (H.2–H.6)
                                           │
[H-C] Skill (1/session) ─────────────► engine-ops skill + memory skill .claude/skills/*/SKILL.md    (H.7–H.8)
                                           │
[H-D] Lead + chạy thật ──────────────► orchestration playbook (H.9) → done-gate REAL end-to-end (H.10)
                                           │
                                       Phase H done — ROADMAP hq-v2 cập nhật
```

Vòng đời HQ-native cần điều phối ĐỘNG (không DAG): `request → research → plan → (cto thiết kế) → build chi nhánh qua engine → test qua engine → record memory`; các gate/route cũ (coo/rg_gate/clarify_gate/escalate_gate) **tan vào reasoning của lead** (lead hỏi user / chọn nhánh natively).

---

## Phase H.0 — Thiết kế orchestration + khoá reframe

**Mục tiêu**: chốt MỌI quyết định kiến trúc thành 1 spec đọc-được trước khi đẻ bất kỳ agent nào; khoá reframe "engine = branch-only" mà H-B..D + Phase J/K/L dựa vào.

### Session H.0 — Viết `design.md`
- **Scope**: soạn `plan/hq-v2/phase-h/design.md` gồm các mục bắt buộc:
  1. **Sơ đồ orchestration**: lead (= coo + 5 gate cũ tan vào reasoning) điều phối thế nào; khi nào spawn team vs lead tự làm; flow request→research→plan→build→test→record dạng prose động (KHÔNG DAG).
  2. **Roster teammate**: map `hq/agents/{researcher,planner,cto,builder,tester}` → 5 teammate def `.claude/agents/*.md`; nêu rõ `coo/rg_gate/clarify_gate/escalate_gate/escalate_report/record` KHÔNG thành teammate (lead/skill đảm nhận) + lý do từng cái.
  3. **Bố cục `.claude/`**: cây thư mục đích (`agents/`, `skills/`, `memory/`, orchestration doc, `teams/playbook.md`); chỗ đặt từng artifact.
  4. **Memory 2-store tách bạch**: `.claude/memory/` (HQ-team, leafnote-style 4 file) vs `company/memory/`+`<project>/memory/` (engine branch, BẤT BIẾN); ai đọc/ghi store nào; engine `memory.ps1` KHÔNG đổi.
  5. **Hợp đồng "engine như tool"**: lệnh teammate được gọi (`run.ps1 autobuild/autofix/run/check/trial/validate`), đọc kết quả ở đâu (`.runs/`, `events.ndjson`, exit code, `Write-*Result` JSON), builder dùng `autobuild`→sandbox→promote.
  6. **Quality-gate khách quan**: cơ chế "không để LLM phán cảm tính" — teammate tester chạy engine `check`/`trial` lấy exit code; PLUS tuỳ chọn hook `TaskCompleted`/`TeammateIdle` (exit 2 chặn) chạy `run.ps1 check`. Chốt dùng hook hay convention-trong-body (hoặc cả hai) ở mục này.
  7. **Skill inventory**: map `hq/skills.md` (scaffold/patch/diagnose/run-test/report) → tập skill project-scope tối thiểu (đề xuất: `engine-ops` gộp scaffold/patch/diagnose/run-test + `hq-memory` cho report/read). Chốt số skill = số session H-C.
  8. **Số phận legacy** (đã chốt: giữ tham chiếu + dọn cuối roadmap) — ghi 1 dòng + thêm hàng "DỌN legacy" vào §ghi-chú ROADMAP để Phase L/cuối làm.
  9. **Done-gate restated** (xem Outcome cuối) + cách đo token baseline (HQ-workflow cũ tốn bao nhiêu — ước lượng từ số node × prompt, để so ở H.10).
- **STOP gate**: `design.md` tồn tại + có **đủ 9 mục trên**, mỗi mục ≥1 quyết định cụ thể (không để "TBD"); roster liệt đúng 5 teammate + nêu rõ thành phần tan-vào-lead; bố cục `.claude/` vẽ thành cây; mục memory khẳng định engine `memory.ps1` bất biến. Chạy regression 3-lệnh (chưa sửa gì → phải pass) ghi vào CHECKPOINT.
- **Output artifact**: `plan/hq-v2/phase-h/design.md`.

**Phase H.0 gate**: design.md chốt; mọi "cần làm rõ" còn lại của ROADMAP §Phase H được trả lời trong design.md; KHÔNG còn quyết định mở chặn H.1.

---

## Phase H-A — Nền team

**Mục tiêu**: dựng khung `.claude/` + bật flag + seed memory + skeleton playbook, để H-B chỉ việc đổ nội dung agent.

### Session H.1 — Bật flag + scaffold `.claude/` + memory + playbook skeleton
- **Scope**:
  - Verify `claude --version` ≥ 2.1.32 (blocker nếu thiếu → dừng, báo user).
  - Thêm `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"` vào `company/.claude/settings.json` (giữ block `worktree` cũ).
  - Tạo cây `.claude/`: `agents/` (đã có `planner.md` META — KHÔNG đụng, đặt agent HQ tên khác để tránh nhầm, vd `hq-researcher.md` — chốt convention tên ở H.0/H.1), `skills/` (đã có plan-long/plan-short — giữ), `memory/` với 4 file leafnote-style (`context.md`/`mistakes.md`/`patterns.md`/`global.md`) seed header rỗng + README ghi schema (ai đọc/ghi, delimiter, cap).
  - Tạo `company/.claude/teams/playbook.md` **skeleton** (mục: When-to-team · Lifecycle teammate · Anti-pattern · Issue queue · Engine-as-tool contract) — nội dung đầy đủ để H.9.
  - Tạo orchestration doc skeleton (vd `company/.claude/hq-master.md` hoặc cập nhật `company/CLAUDE.md` §HQ-native — chốt vị trí ở H.0).
- **STOP gate**: `settings.json` có flag; `.claude/memory/{context,mistakes,patterns,global}.md` + `README.md` tồn tại; `.claude/teams/playbook.md` skeleton tồn tại (≥5 heading); **regression 3-lệnh PASS** (engine chưa đụng → `git diff engine/` rỗng).
- **Output artifact**: `.claude/settings.json` (flag), `.claude/memory/*` (5 file), `.claude/teams/playbook.md` skeleton, orchestration doc skeleton.

**Phase H-A gate**: flag bật + khung thư mục đủ chỗ cho 5 teammate + 2 skill + playbook; regression nguyên trạng.

---

## Phase H-B — Teammate (mỗi session 1 agent)

**Mục tiêu**: viết từng teammate def chất lượng cao theo **format team agent thực thụ** (tham chiếu leafnote `.claude/agents/teams/`). Vai trò + ranh giới định nghĩa ở `design.md` §2 (KHÔNG còn nguồn `hq/agents/*` — đã xóa). **Nguyên tắc chống lậm form cũ:** teammate giao tiếp **văn xuôi tự nhiên** — KHÔNG JSON/plan-as-data/build-spec; chỉ builder ghi file (Write/Edit), build TRỰC TIẾP không qua engine.

> **Tiêu chí chất lượng chung mỗi teammate (STOP gate từng session phải đạt):**
> (a) frontmatter hợp lệ: `name`, `description`, `tools` (đúng quyền — read-only cho researcher/planner/cto/tester; builder thêm Bash để shell engine), `model` (tier hợp lý); (b) body viết như **team agent thực thụ** — KHÔNG dùng template 5-mục node (Một việc/Input/Trả ra/Không làm/Handoff): phải có (1) mission 1 câu, (2) "Đọc đầu phiên" có thứ tự, (3) "Workflow chính" các bước cụ thể, (4) "Anti-patterns", (5) "Output format" template trả lead, (6) "Quality gate" self-check, (7) **"Trong TeamCreate mode"** đầy đủ (spawn-ack · TaskGet · TaskUpdate in_progress → completed · SendMessage khi xong · shutdown_request · verify-done-from-prior-session); (c) TeamCreate mode section có ≥6 bullet covering toàn bộ lifecycle (spawn/brief/work/done/shutdown/verify); (d) self-review checklist tick trong CHECKPOINT. **Chưa spawn thật ở H-B** (spawn = đốt token, dồn về H.10) — gate H-B = authored + đạt checklist.

### Session H.2 — `researcher` teammate
- Scope: soạn `.claude/agents/hq-researcher.md` từ `hq/agents/researcher.md` (gom request + memory → tóm tắt + open_questions; read-only). Tools read-only (Read/Grep/Glob + WebSearch nếu cần) + đọc `.claude/memory/`.
- STOP gate: tiêu chí chất lượng chung (a)–(d) đạt; file pass `claude` parse (frontmatter YAML hợp lệ — verify bằng đọc lại, không cần spawn).
- Output: `.claude/agents/hq-researcher.md`.

### Session H.3 — `planner` teammate ✅ (đã soạn lại form prose 2026-06-02)
- Scope: `.claude/agents/hq-planner.md` (WHAT — kế hoạch **văn xuôi markdown** Goal/Steps/Done-criteria; **KHÔNG plan-as-data JSON**; re-plan khi tester fail). Đọc memory + research qua SendMessage/Task.
- STOP gate: (a)–(d) đạt; giao thức nhận verdict fail → re-plan (động, không loop-edge); done-criteria có cách kiểm khách quan.
- Output: `.claude/agents/hq-planner.md`.

### Session H.4 — `cto` teammate
- Scope: soạn `.claude/agents/hq-cto.md` (HOW — **thiết kế kỹ thuật văn xuôi**: cấu trúc file, cách tiếp cận, công nghệ; tham khảo `catalog/` TÙY CHỌN). Read-only; **KHÔNG build-spec JSON, KHÔNG lắp workflow.json**. Đầu ra cho builder = thiết kế prose đủ để builder ghi file.
- STOP gate: (a)–(d) đạt; thiết kế là văn xuôi cho builder đọc (không JSON ceremony); nêu rõ builder sẽ Write/Edit trực tiếp theo thiết kế.
- Output: `.claude/agents/hq-cto.md`.

### Session H.5 — `builder` teammate (build TRỰC TIẾP)
- Scope: soạn `.claude/agents/hq-builder.md`. **Ghi file deliverable TRỰC TIẾP**: nhận thiết kế CTO → Write/Edit file vào `projects/<name>/` + Bash chạy build/cài deps. Tools = Read + **Write + Edit + Bash**. **KHÔNG `run.ps1 autobuild/autofix/build`, KHÔNG workflow.json**. Ranh giới: không đụng `engine/*.ps1`.
- STOP gate: (a)–(d) đạt; quy ước output location (`projects/<name>/`); khẳng định build trực tiếp (không engine-build); báo tester cách chạy/kiểm khi xong.
- Output: `.claude/agents/hq-builder.md`.

### Session H.6 — `tester` teammate (check khách quan của deliverable + ghi memory)
- Scope: soạn `.claude/agents/hq-tester.md`. Chạy **check của chính deliverable** (test suite / build / lint / quan sát hành vi) lấy exit-code/kết quả (gate khách quan); in `CHECK_RESULT: pass|fail (...)`; ghi bài học vào `.claude/memory/` (qua skill `hq-memory` H.8). Tools = Read + Bash. **KHÔNG `run.ps1 check/trial`** (engine không trong luồng HQ).
- STOP gate: (a)–(d) đạt; gate khách quan dựa exit-code/output của deliverable (không phán cảm tính); đường ghi memory rõ.
- Output: `.claude/agents/hq-tester.md`.

**Phase H-B gate**: 5 teammate def tồn tại, mỗi cái đạt checklist (a)–(d); `git diff engine/` rỗng; regression 3-lệnh PASS.

---

## Phase H-C — Skill (mỗi session 1 skill)

**Mục tiêu**: đóng gói "cách gọi engine" + "đọc/ghi memory" thành skill project-scope dùng chung (vì frontmatter `skills` của teammate bị bỏ qua → phải project-scope).

### Session H.7 — Skill `build-verify` (thay `engine-ops`)
- Scope: `.claude/skills/build-verify/SKILL.md` — quy ước **build deliverable TRỰC TIẾP + verify khách quan** (thay `engine-ops` cũ vốn gói cách-gọi-engine, vô nghĩa sau Q2): nơi ghi (`projects/<name>/`, gitignored regen-được), cách cấu trúc deliverable, cách tester verify khách quan (chạy test/build/lint của deliverable, đọc exit-code, in `CHECK_RESULT: pass|fail`). Ranh giới: builder Write/Edit trực tiếp, KHÔNG đụng `engine/*.ps1`, KHÔNG `run.ps1 build/autobuild`.
- STOP gate: SKILL.md frontmatter hợp lệ + mục "nơi ghi + cấu trúc" + mục "verify khách quan" + mục "ranh giới"; KHÔNG tham chiếu lệnh engine-build (đã loại khỏi luồng HQ).
- Output: `.claude/skills/build-verify/SKILL.md`.

### Session H.8 — Skill `hq-memory`
- Scope: `.claude/skills/hq-memory/SKILL.md` cho report/read: đọc `.claude/memory/{context,mistakes,patterns,global}.md` đầu task + append bài học cuối task (delimiter date-stamped, cap N — mirror schema engine memory nhưng cho store HQ-team). Phân biệt rõ với engine branch memory (`company/memory/`).
- STOP gate: SKILL.md frontmatter hợp lệ + quy ước đọc (đầu task) + ghi (cuối task, format đo được) + cảnh báo KHÔNG nhầm với `company/memory/` engine store.
- Output: `.claude/skills/hq-memory/SKILL.md`.

**Phase H-C gate**: 2 skill tồn tại, project-scope, mọi lệnh tham chiếu đều thật; regression PASS.

---

## Phase H-D — Lead orchestration + chạy thật

**Mục tiêu**: viết "bộ não" lead (playbook đầy đủ) rồi chứng minh end-to-end thật.

### Session H.9 — Orchestration playbook đầy đủ
- Scope: đổ nội dung `company/.claude/teams/playbook.md` (từ skeleton H.1): (1) When-to-team (khi nào lead spawn vs tự làm; size 3-5 teammate); (2) Lifecycle (spawn→assign Task→SendMessage→shutdown_response→cleanup; bài học leafnote: ack-cùng-turn, không silent-complete); (3) Anti-pattern (lead-DIY vượt ngưỡng, scope-drift, stale-context — port từ leafnote queue codes); (4) Issue-queue (file `company/.claude/team-issues-queue.md` + format); (5) Build-deliverable contract (trỏ skill `build-verify`; builder Write/Edit trực tiếp, tester verify khách quan; **KHÔNG engine-build**); (6) Memory protocol (trỏ skill `hq-memory`). Cập nhật orchestration doc (`hq-master.md`) trỏ playbook + roster + flow động.
- STOP gate: playbook đủ 6 mục; flow request→research→plan→build→test→record mô tả ĐỘNG (không DAG) + ánh xạ rõ teammate nào làm bước nào + build-trực-tiếp ở build/verify-khách-quan ở test; `team-issues-queue.md` tạo (header + format). Regression PASS.
- Output: `playbook.md` đầy đủ + `team-issues-queue.md` + orchestration doc.

### Session H.10 — Done-gate: chạy thật end-to-end (USER-GATE, ĐỐT TOKEN)
- Scope: với 1 request thật nhỏ (vd "landing page thu email"), lead bật team → research → plan → cto (thiết kế prose) → builder **Write/Edit dựng deliverable TRỰC TIẾP** vào `projects/<name>/` → tester chạy **check khách quan của deliverable** (test/build/lint) → record `.claude/memory/`, **hoàn toàn động** (không workflow.json, không engine-build). Thu `usage` token mỗi teammate (best-effort) + so sánh với HQ-workflow cũ (baseline ước lượng H.0). Ghi kết quả + 1 vòng "chạy thử" xác nhận từng teammate/skill hoạt động.
- STOP gate = **Outcome cuối** (checklist done-gate tất cả tick). **User gate trước khi chạy** (đốt token — xác nhận như D-C1/Phase 5).
- Output: branch thật trong `projects/` + báo cáo token trước/sau + memory entry + CHECKPOINT done.

**Phase H-D gate** = Outcome cuối.

---

## Outcome cuối

- HQ chạy như **native team**: 1 request → lead điều phối động → research/plan/cto/build/test/record qua teammate + skill, build TRỰC TIẾP (KHÔNG engine-build, KHÔNG `hq/workflow.json`).
- **Done-gate (checklist đo được):**
  - [ ] `design.md` chốt đủ 9 mục theo Q2; mọi "cần làm rõ" ROADMAP §H trả lời.
  - [ ] Flag `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` bật; CC ≥ v2.1.32 verified.
  - [ ] 5 teammate def `.claude/agents/hq-{researcher,planner,cto,builder,tester}.md` **form prose (KHÔNG JSON ceremony)**, mỗi cái đạt checklist (a)–(d).
  - [ ] 2 skill project-scope (`build-verify` + `hq-memory`), mọi quy ước/lệnh tham chiếu thật.
  - [ ] `.claude/memory/` 4 file + store HQ-team tách bạch `company/memory/` (engine `memory.ps1` BẤT BIẾN).
  - [ ] `playbook.md` đủ 6 mục + flow động + `team-issues-queue.md`.
  - [ ] **Chạy thật**: lead dựng + verify 1 deliverable TRỰC TIẾP (builder Write/Edit, tester check khách quan của deliverable), record memory — hoàn toàn động.
  - [ ] Báo cáo token: team-native vs HQ-workflow cũ cho thấy giảm (hoặc giải thích nếu không).
  - [ ] Legacy `hq/` + `examples/hq-*` + 2 test script **đã XÓA**; selftest 10/10; ghi nhận §Dọn-legacy ROADMAP.
  - [ ] Regression (validate hello + run hello -Mock + selftest 10/10) PASS ở session cuối; ROADMAP hq-v2 bảng tiến độ Phase H → ✅.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-06-02 | Initial | Tạo từ ROADMAP hq-v2 Phase H. Chốt (user): orchestration=native team TeamCreate · builder ghi-file qua engine sandbox/promote · teammate gọi engine trực tiếp · memory→`.claude/memory/` (tách store engine branch) · legacy giữ tham chiếu + dọn cuối roadmap. Nền tài liệu: code.claude.com/docs agent-teams (flag experimental, teammate=subagent def, skills project-scope, hooks gate). |
| 2026-06-02 | **REVISE Q2 (reframe giữa H-B)** | User chỉ ra teammate lậm form workflow cũ (hq-planner xuất JSON plan-as-data vô nghĩa). Đảo 3 quyết định cũ: (1) builder build TRỰC TIẾP Write/Edit, KHÔNG engine-build; (2) teammate giao tiếp prose, KHÔNG JSON/build-spec; (3) legacy `hq/`+`examples/hq-*`+2 test script XÓA (không giữ tham chiếu). Sửa: intro · Context locked-decisions · §H-B intro + H.3–H.6 · §H-C H.7 (`engine-ops`→`build-verify`) · H.9/H.10 · Outcome checklist · regression invariant (selftest 12→10, engine-diff ngoại lệ session này). Soạn lại `hq-researcher`+`hq-planner` form prose. Xem `design.md` §Revise. |
