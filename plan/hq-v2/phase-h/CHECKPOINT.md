# CHECKPOINT — Phase H: HQ team-of-agents native

> Sổ tay tiến độ dài hạn. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu. Đọc kèm `PLAN.md` (immutable) cùng thư mục.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu"). CD-1: **1 session = 1 teammate HOẶC 1 skill** (chất lượng).
- **STOP NGAY** khi đạt STOP gate của session đó — không tham làm session kế dù còn quota.
- **⚠️ REFRAME Q2 (2026-06-02) — ĐỌC `design.md` §Revise + `PLAN.md` §Revise.** Teammate KHÔNG xuất JSON/plan-as-data/build-spec (lậm form workflow cũ); giao tiếp **văn xuôi**. Builder build **TRỰC TIẾP** (Write/Edit vào `projects/<name>/`), KHÔNG engine-build. Tester verify bằng check khách quan của chính deliverable. Legacy `hq/`+`examples/hq-*`+2 test script ĐÃ XÓA.
- **H KHÔNG sửa engine EXECUTOR.** Mọi session: trước khi đóng chạy regression — `./run.ps1 validate hello` exit 0 · `./run.ps1 run hello "x" -Mock` done · `./run.ps1 selftest` PASS (**nay 10/10**) · `git diff engine/` RỖNG. **Ngoại lệ:** session reframe Q2 CÓ sửa `engine/test-runner.ps1` (de-wire) + `engine/spec.ps1` (comment) — executor (workflow/bridge/graph/validate) không đụng; session sau `git diff engine/` rỗng lại.
- **Mock-first.** KHÔNG spawn team thật / KHÔNG chạy engine real cho tới H.10 (đốt token, user-gate). H.0–H.9 = authoring + mock regression.
- **Memory 2 store tách bạch:** `.claude/memory/` = HQ-team; `company/memory/`+`<project>/memory/` = engine branch (BẤT BIẾN). Đừng trộn.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log". Dọn `.runs/` test sau verify.

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 11 (H.0–H.10) | 4 (H.0–H.3) + reframe Q2 | ~36% |
| design.md (9 mục) | 1 | 1 ✅ (rewrite Q2) | 100% |
| Teammate def (`.claude/agents/hq-*`) | 5 | 2 ✅ (researcher, planner — **soạn lại form prose Q2**) | 40% |
| Skill project-scope | 2 (`build-verify`+`hq-memory`) | 0 | 0% |
| Nền (flag+memory+playbook) | 3 artifact | 3 ✅ (cập nhật Q2) | 100% |
| Done-gate checklist | 11 tick | 4 (design.md + flag/CC-ver + memory-store + researcher+planner prose) | 36% |
| Regression | PASS mỗi session | **PASS (reframe Q2, selftest 10/10)** | — |

---

## Đang ở đâu

- **Phase**: H-B (Teammate — mỗi session 1 agent). **Vừa xong reframe Q2** (giữa H-B): xóa legacy + sửa toàn bộ plan/doc + soạn lại researcher+planner form prose.
- **Session kế tiếp**: H.4 — soạn `.claude/agents/hq-cto.md` (HOW — **thiết kế kỹ thuật VĂN XUÔI**: cấu trúc file/cách tiếp cận/công nghệ; tham khảo `catalog/` tùy chọn; **KHÔNG build-spec JSON, KHÔNG lắp workflow.json**); đầu ra prose đủ để builder Write/Edit trực tiếp; đạt checklist (a)–(d) trong PLAN.md §H-B (đã rewrite Q2).
- **Blocker**: KHÔNG còn
- **Reference**: `PLAN.md` Phase H-B → Session H.4 (đã rewrite Q2); `design.md` §1/§2/§5 (flow + roster `hq-cto` prose). KHÔNG còn `hq/build-spec.md` (đã xóa).

---

## Per-session log

### 2026-06-02 — REFRAME Q2 (giữa H-B, không phải session đẻ thường)

- **Trigger (user)**: teammate đang build **lậm form workflow cũ** — vd `hq-planner.md` xuất JSON plan-as-data "để làm gì" (không engine nào parse trong team native). Yêu cầu: xóa file cũ liên quan hq-workflow + sửa roadmap/plan + soạn lại phần bị ảnh hưởng.
- **3 quyết định user chốt (AskUserQuestion)**:
  - Q1 **Xóa sạch + de-wire selftest**: gỡ toàn bộ `hq/` + `examples/hq-*` + `hq-tests.ps1` + `hq-graph-tests.ps1`; de-wire 2 script khỏi selftest (12→10).
  - Q2 **Bỏ engine-build cho HQ**: builder Write/Edit deliverable TRỰC TIẾP; KHÔNG build-spec/workflow.json/`autobuild`; engine thành tool đứng riêng. (Đảo clause "builder qua engine" của CD-1.)
  - Q3 **Soạn lại ngay session này**: re-author researcher+planner + sửa hết plan.
- **Done**:
  - **Xóa** (git rm): `hq/` (workflow.json/mmd, 11 agents, build-spec.md, skills.md) + `examples/hq-{coo,cto,planner,tester}/` + `examples/hq-tests.ps1` + `examples/hq-graph-tests.ps1` (+ untracked `hq/.layout.json`).
  - **Engine (chỉ test/comment, KHÔNG executor)**: `test-runner.ps1` de-wire 2 script (12→10) + sửa header; `e2e-harness-tests.ps1` repoint fixture `hq/`→`examples/loopy` (router `verdict`→terminal `ship`; bỏ sub-test Invoke-E2E vì hardcode `'record'`; neutralize `hq/agents/evil.md`→`outside/`); `spec.ps1` sửa 2 comment dangling `hq/build-spec.md`.
  - **Re-author**: `hq-planner.md` (BỎ JSON plan-as-data → kế hoạch markdown Goal/Steps/Done-criteria + guard "teammate không phải node") · `hq-researcher.md` (bỏ trỏ `hq/build-spec.md` + framing engine-build, thêm guard prose).
  - **Plan/doc**: `design.md` (rewrite §1/§2/§5/§6/§7/§8/§9 + §Revise) · `PLAN.md` (intro + locked-decisions + H.3–H.7 + H.9/H.10 + Outcome + regression invariant + revision log) · `ROADMAP.md` (AMEND CD-1 + §Hệ-quả + §Dọn-legacy now-done + bảng tiến độ Phase H) · `hq-master.md` (roster + flow + skill refs) · `playbook.md` §5 (engine→build-direct) · `CLAUDE.md` (gỡ 5 hàng legacy, update test-runner/e2e/spec/catalog/phase-3/4/H rows).
- **Gate**: legacy xóa sạch ✅ · researcher+planner KHÔNG còn JSON ceremony ✅ · plan/doc đồng bộ Q2 ✅
- **Regression**: validate hello exit 0 ✅ · run hello "x" -Mock done ✅ · **selftest 10/10 PASS** ✅ · `git diff engine/` = chỉ test-runner.ps1 + spec.ps1 (comment), executor RỖNG ✅. Dọn `.runs/` test ✅
- **Next**: Session H.4 — `hq-cto.md` teammate (thiết kế kỹ thuật VĂN XUÔI, không build-spec).
- **Notes**: `engine/e2e.ps1` (`autobuild`/`autofix`) hardcode `'record'` → vestigial sau Q2 (giữ code, không đụng executor; candidate dọn sau). App `hq` special-case nay là nhánh chết vô hại (default fallback `list[0]`) — dọn chính thức Phase L.

### 2026-06-02 — Session H.3 — `hq-planner.md` teammate (⚠️ ĐÃ SOẠN LẠI ở reframe Q2 — entry dưới là bản gốc form-JSON, không còn đúng)

- **Done**: soạn `.claude/agents/hq-planner.md` từ `hq/agents/planner.md`.
  - Frontmatter: `name: hq-planner`, `tools: [Read]` (read-only — planner không shell engine, không ghi file), `model: claude-sonnet-4-6`, description 1 dòng phân biệt rõ vs `catalog/planner.md`.
  - Body: mission 1 câu → Đọc đầu phiên (4 bước có thứ tự) → Workflow chính (4 bước: classify vòng/re-plan, soạn plan-as-data 6 field, self-check, trả lead) → Anti-patterns → Output format (template JSON plan-as-data) → Quality gate → TeamCreate mode.
  - Giao thức re-plan động (không loop-edge): planner nhận `prev_verdict` + lý do fail → sửa đúng step/criterion → tăng `revision`. Khi `revision ≥ max` → không plan thêm, escalate lead.
  - 7 bullet TeamCreate mode: spawn-ack · TaskGet · TaskUpdate in_progress → completed · SendMessage khi xong · escalate path revision≥max · shutdown_request · verify-done-from-prior-session.
- **Output**: `.claude/agents/hq-planner.md`.
- **Self-review checklist (a)–(d)**:
  - (a) frontmatter hợp lệ: name/description/tools (Read — read-only)/model đúng ✅
  - (b) body team agent thực thụ (KHÔNG 5-mục node): mission + Đọc đầu phiên + Workflow chính 4 bước + Anti-patterns + Output format + Quality gate + TeamCreate mode ✅
  - (c) TeamCreate mode ≥6 bullet: spawn-ack · TaskGet · TaskUpdate in_progress→completed · SendMessage khi xong · escalate revision≥max · shutdown_request · verify-done-from-prior-session (7 bullet) ✅
  - (d) self-review ghi vào CHECKPOINT (mục này) ✅
- **Gate**: (a)–(d) đạt ✅; giao thức re-plan động (không loop-edge) nêu rõ ✅; escalate khi revision≥max ✅
- **Regression**: validate hello exit 0 ✅ · run hello "x" -Mock done ✅ · selftest 12/12 PASS ✅ · `git diff engine/` = 0 byte ✅. Dọn `.runs/` test ✅
- **Next**: Session H.4 — `hq-cto.md` teammate.
- **Notes**: Planner read-only đúng thiết kế (không cần Bash — không gọi engine, không ghi file chi nhánh). Re-plan là ĐỘNG (planner nhận verdict qua Task/SendMessage, không cần loop-edge workflow). Escalate path khi revision≥max tách bạch với path thường. Format plan-as-data giữ nguyên 6 field (goal/revision/prev_verdict/steps/done_criteria/open_questions) từ brain-model để `run.ps1 build` (qua cto) ăn được.

### 2026-06-02 — Session H.2 — `hq-researcher.md` teammate

- **Done**: soạn `.claude/agents/hq-researcher.md` từ `hq/agents/researcher.md`.
  - Frontmatter: `name: hq-researcher`, `tools: [Read, Grep, Glob, WebSearch]`, `model: claude-sonnet-4-6`, description 1 dòng.
  - Body template 5-mục (Một việc/Input/Trả ra/Không làm/Handoff) chuyển hoá sang ngữ cảnh team: bỏ `{{mem_*}}` bridge, đọc `.claude/memory/` trực tiếp; bỏ nhãn `enough`/`need_clarify` (lead xét `open_questions[]` natively); bảng nguồn đọc ưu tiên.
  - 4 bullet giao thức team: ack-cùng-turn · TaskUpdate in_progress→completed · shutdown-response · không-leo-scope.
  - Ghi chú phân biệt `hq-researcher` vs `catalog/researcher.md`.
- **Output**: `.claude/agents/hq-researcher.md`.
- **Self-review checklist (a)–(d)** (sau khi sửa lại theo format leafnote team agent):
  - (a) frontmatter hợp lệ: name/description/tools/model đúng theo design.md §2 ✅
  - (b) body team agent thực thụ (KHÔNG 5-mục node): mission + Đọc đầu phiên + Workflow chính (4 bước) + Anti-patterns + Output format (template) + Quality gate + TeamCreate mode ✅
  - (c) TeamCreate mode ≥6 bullet: spawn-ack · TaskGet · TaskUpdate in_progress → completed · SendMessage khi xong · shutdown_request · verify-done-from-prior-session ✅
  - (d) self-review ghi vào CHECKPOINT (mục này) ✅
- **Gate**: tiêu chí (a)–(d) đạt ✅; frontmatter YAML hợp lệ ✅; PLAN.md tiêu chí (b) đã cập nhật bỏ 5-mục ✅
- **Regression**: validate hello exit 0 ✅ · run hello "x" -Mock done ✅ · selftest 12/12 PASS ✅ · `git diff engine/` = 0 byte ✅. Dọn `.runs/` test ✅
- **Next**: Session H.3 — `hq-planner.md` teammate.
- **Notes**: Researcher không ghi memory (read-only). Rewrite lần 2 sau khi user chỉ ra format 5-mục node là sai — teammate phải viết như leafnote team agent (mission + workflow steps + output format + anti-patterns + quality gate + TeamCreate mode chi tiết). PLAN.md tiêu chí (b) cũng cập nhật theo. Các session H.3–H.6 dùng format này làm chuẩn.

### 2026-06-02 — Session H.1 — Nền team (flag + memory + playbook skeleton)

- **Done**:
  - Verify `claude --version` = **2.1.160 ≥ 2.1.32** ✅ → KHÔNG còn blocker; pwsh `/snap/.../pwsh` present.
  - Bật flag: thêm `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"` vào `company/.claude/settings.json` (giữ block `worktree`).
  - Scaffold `company/.claude/memory/`: 4 file leafnote-style (`context/mistakes/patterns/global.md`, header rỗng + comment marker) + `README.md` (schema 2-store, bảng ai-đọc-ghi, delimiter `## <date> — <slug>`, cap N=10, cảnh báo TÁCH engine store).
  - `company/.claude/teams/playbook.md` skeleton — 6 heading (When-to-team · Lifecycle · Anti-pattern · Issue-queue · Engine-as-tool · Memory-protocol), mỗi mục có `_TODO H.9_` + trỏ design.md.
  - `company/.claude/hq-master.md` orchestration doc skeleton — flow động 1 dòng + bảng roster 5 teammate + trỏ playbook/skill/memory/design.
  - (Chốt vị trí orchestration doc = `hq-master.md` riêng, KHÔNG nhồi vào CLAUDE.md.)
- **Output**: `.claude/settings.json` (flag), `.claude/memory/{context,mistakes,patterns,global,README}.md` (5 file), `.claude/teams/playbook.md` (skeleton 6 heading), `.claude/hq-master.md`.
- **Gate**: settings.json có flag ✅ · 4 memory file + README tồn tại ✅ · playbook skeleton ≥5 heading (có 6) ✅ · `agents/planner.md` META KHÔNG đụng ✅
- **Regression**: validate hello exit 0 ✅ · run hello "x" -Mock done ✅ · **selftest 12/12 PASS** ✅ · `git diff engine/` = RỖNG ✅. Dọn `.runs/` test sau verify.
- **Next**: Session H.2 — `hq-researcher.md` teammate (H-B mở màn).
- **Notes**: CC version vượt xa ngưỡng (2.1.160). Memory store HQ-team đặt `company/.claude/memory/`, hoàn toàn tách `company/memory/` (engine). Orchestration doc dùng file riêng `hq-master.md` thay vì §CLAUDE.md (gọn, dễ trỏ).

### 2026-06-02 — Session H.0 — Viết design.md

- **Done**: viết `plan/hq-v2/phase-h/design.md` đủ 9 mục theo PLAN.md H.0. Chốt: (1) flow orchestration ĐỘNG (prose, không DAG) + gate cũ tan vào lead; (2) roster 5 teammate `hq-*` + 6 thành phần không-thành-teammate có lý do; (3) bố cục `.claude/` cây đích; (4) memory 2-store tách bạch (engine `memory.ps1` bất biến); (5) hợp đồng engine-as-tool (7 lệnh + cách đọc kết quả); (6) quality-gate convention-trong-body, hook defer I/K; (7) skill inventory 2 skill (engine-ops + hq-memory) — `patch` không còn (builder dùng autobuild); (8) legacy giữ tham chiếu; (9) done-gate checklist + token baseline ước tính ~20–30k tokens HQ-workflow cũ.
- **Output**: `plan/hq-v2/phase-h/design.md`.
- **Gate**: design.md tồn tại + 9 mục đủ + mỗi mục có quyết định cụ thể (không TBD) + roster 5 teammate đúng + bố cục cây + memory khẳng định engine bất biến ✅
- **Regression**: validate hello exit 0 ✅ · run hello -Mock done ✅ · `git diff engine/` = 0 byte ✅ (selftest defer — chưa thay đổi gì)
- **Next**: Session H.1 — bật flag, scaffold `.claude/memory/` + `teams/playbook.md` + `hq-master.md`.
- **Notes**: Convention tên `hq-` tiền tố để tránh nhầm META planner. `patch` skill bỏ (builder H-native không Write/Edit trực tiếp). Hook quality-gate defer Phase I/K.

### 2026-06-02 — Phase H long-plan tạo (chưa phải session H.0)
- **Done**: soạn `PLAN.md` + `CHECKPOINT.md`; chốt 5 quyết định kiến trúc với user (orchestration native team · builder qua engine · teammate gọi engine trực tiếp · memory→`.claude/memory/` tách store · legacy giữ+dọn-cuối-roadmap); đọc docs agent-teams chính thức.
- **Output**: `plan/hq-v2/phase-h/{PLAN,CHECKPOINT}.md`.
- **Gate**: n/a (planning).
- **Next**: Session H.0 — viết `design.md`.
- **Notes**: Agent teams experimental (flag + CC ≥2.1.32). Teammate skills frontmatter bị bỏ qua → skill phải project-scope. Quality-gate có thể dùng hook `TaskCompleted`/`TeammateIdle` chạy `run.ps1 check` — chốt cơ chế ở H.0 mục 6.

---

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-06-02 | Created from `PLAN.md` | @planner |
