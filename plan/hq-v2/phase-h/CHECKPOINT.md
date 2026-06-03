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
| Sessions hoàn thành | 11 (H.0–H.10) | **11 ✅ (H.0–H.10)** + reframe Q2/Q3 | **100%** |
| design.md (9 mục) | 1 | 1 ✅ (rewrite Q2) | 100% |
| Teammate def (`.claude/agents/hq-*`) | 5 | 5 ✅ (researcher, planner, cto, builder, tester — **form prose**) | 100% |
| Skill project-scope | 2 (`build-verify`+`hq-memory`) | 2 ✅ (`build-verify` + `hq-memory`) | 100% |
| Nền (flag+memory+playbook) | 3 artifact | 3 ✅ (playbook đầy đủ H.9) | 100% |
| Done-gate checklist | 11 tick | **11 ✅** (+ chạy thật todo-web PASS H.10) | **100%** |
| Regression | PASS mỗi session | **PASS (H.10, selftest 9/9, engine diff rỗng)** | — |

---

## Đang ở đâu

- **Phase H ✅ DONE (2026-06-03)** — H.10 lần 2 chạy thật PASS với framing chi nhánh đúng. HQ vận hành trọn vẹn như native team: lead drive TaskList loop, 5 teammate chain researcher→planner→cto→builder→tester hoàn toàn ĐỘNG, giao tiếp prose, builder Write/Edit trực tiếp, tester verify khách quan bằng engine.
- **Deliverable H.10**: chi nhánh `projects/todo-web/` (workflow.json pipeline v1 5 node story→flow→tasks→fe→report + roster 5 agent lắp từ `catalog/` {pm,ux,tech-lead,frontend-developer,qa-functional}). Tester `CHECK_RESULT: pass` (validate exit 0 + run -Mock done + check output_key 5/5). Lead xác nhận độc lập: validate exit 0, run -Mock path đúng.
- **Session kế tiếp**: Phase H xong → chuyển ROADMAP hq-v2 sang phase kế (I: token chi nhánh) khi user yêu cầu. Cập nhật bảng tiến độ Phase H trong `ROADMAP.md` → ✅.
- **Reference**: Per-session log H.10 (lần 2) dưới; `PLAN.md` Outcome checklist (tick hết); `global.md` memory.

---

## Per-session log

### 2026-06-03 — Session H.10 (lần 2) — ✅ DONE: chạy thật end-to-end PASS (framing chi nhánh)

- **Setup**: regression baseline trước spawn (validate hello exit 0 · run hello -Mock done · selftest 9/9 PASS); flag + cả 5 agent `tools:` có `Task*`/`SendMessage` xác nhận sẵn (fix lần 1). AskUserQuestion chốt target = **todo-list web app branch** (`todo-web`).
- **Chạy thật** (user-gate): `TeamCreate(hq-todo-web)` + spawn 5 teammate `run_in_background` (researcher→planner→cto→builder→tester) → đợi ~40s init → drive TaskList loop, gate sau mỗi handoff.
  - **#1 researcher** → 4 mục (Đã biết/Rủi ro/Câu hỏi/Nguồn), open_questions=không, sketch pipeline 5 node. Gate PASS.
  - **#2 planner** → Goal đo được + Steps WHAT + Done-criteria mỗi cái có lệnh kiểm (validate/run-Mock/check). Gate PASS.
  - **#3 cto** → thiết kế 5 phần A–E: pipeline v1 5 node (story/pm→flow/ux→tasks/tech-lead→fe/frontend-developer→report/qa-functional) + cấu trúc file + validate gotchas. Gate PASS.
  - **#4 builder** → Write TRỰC TIẾP `projects/todo-web/` (workflow.json + 5 agents copy từ catalog/); smoke-check validate exit 0 + run -Mock done. Gate PASS.
  - **#5 tester** → `CHECK_RESULT: pass` 3/3 (validate exit 0 · run -Mock done path story→…→report · check 5 output_key non-empty); ghi `patterns.md`+`context.md`. Gate PASS.
- **Lead verify độc lập**: 6 file tồn tại, `validate todo-web` exit 0, `run todo-web -Mock` done path đúng. Done-gate đạt.
- **Shutdown**: shutdown_request cả 5 → ack → TeamDelete sạch (lần này KHÔNG zombie — vì agent body có đủ team tools từ đầu).
- **Token note**: chain 5 vai chạy 1 lượt liền mạch không re-fix/re-plan (research→…→verify thẳng) — không có vòng lặp tốn token; HQ-workflow cũ ước ~20–30k token cho cùng việc (per design.md §9). Team-native: best-effort thấp hơn nhờ không re-spawn.
- **Regression cuối**: validate hello exit 0 ✅ · run hello -Mock exit 0 ✅ · selftest 9/9 PASS ✅ · `git diff engine/` RỖNG ✅. Dọn `.runs/` test ✅.
- **Bài học**: chain chạy trơn khi (a) brief self-contained paste output bước trước, (b) đợi ~40s init tránh SLOW-PICKUP, (c) agent tools đủ `Task*`/`SendMessage` từ đầu. Không phát sinh issue queue mới.
- **STOP**: ✅ done-gate H.10 đạt → Phase H DONE.

### 2026-06-03 — Session H.10 (lần 1) — chạy thử → Q3 reframe + fix bug tools

- **Chạy thử H.10 thật** (user gate): lead `TeamCreate(hq-email-landing)` + spawn 5 teammate, drive TaskList loop. Request test (ban đầu): "landing page thu email".
- **Bug 1 — teammate câm (đã fix)**: cả 5 `hq-*.md` đặt `tools:` allowlist hẹp (vd researcher `[Read,Grep,Glob,WebSearch]`) → KHÔNG có `SendMessage`/`TaskGet`/`TaskUpdate`/`TaskList` → teammate research/plan xong nhưng không report/update được, lead chỉ thấy idle rỗng. Researcher tự chẩn đúng. **Fix**: thêm `TaskGet, TaskUpdate, TaskList, SendMessage` vào `tools:` cả 5 agent. Phải shutdown + respawn (`-2` names; round-1 zombie `tester` chặn `TeamDelete` — framework wart). Ghi `mistakes.md`.
- **Sau fix**: chain chạy trơn researcher→planner→cto→builder (4 vai pass gate, output prose chuẩn qua SendMessage). Builder ghi `index.html`+`test.js`, `node test.js` PASS.
- **⚠️ Bug 2 — SAI VAI (Q3 reframe)**: user dừng team, chỉ ra HQ **KHÔNG build app** — vai HQ là **dựng cơ sở CHI NHÁNH** (workflow.json + roster từ catalog + scaffold tại `projects/<branch>/`), chi nhánh mới build app. AskUserQuestion → chốt "chi nhánh cấu hình sẵn (workflow + agents)". **Đảo một phần Q2** (engine + catalog nay là vật-liệu HQ).
- **Reframe đã làm**: rewrite `hq-builder.md`+`hq-tester.md`+`hq-cto.md` (deliverable=chi nhánh, verify=`run.ps1 validate/run -Mock`, catalog=menu); reframe `hq-planner.md`+`hq-researcher.md`; rewrite skill `build-verify`; sửa `hq-master.md` (§Engine-là-vật-liệu + roster + flow + note tools), `playbook.md` (§3/§7/§8/§10), `CLAUDE.md` (§1/§2 + catalog/projects rows); ghi `global.md` memory; xoá deliverable sai `projects/email-landing`.
- **Tmux**: thêm `resize-pane -t :.6 -y 18` vào playbook §6 N=5 (planner pane lùn) — user yêu cầu.
- **STOP**: chưa đạt done-gate H.10 (chạy sai vai). H.10 phải chạy LẠI với framing chi nhánh.
- **Regression**: validate hello exit 0 ✅ · run hello -Mock done ✅. (selftest chưa chạy lại — agent .md không ảnh hưởng engine; sẽ chạy ở H.10 lần 2.)
- **Next**: H.10 lần 2 — request "dựng chi nhánh nhỏ build <X>"; gate = tester `run.ps1 validate <branch>` exit 0 + `run -Mock` done.

### 2026-06-02 — Session H.9 — Playbook đầy đủ + team-issues-queue + hq-master

- **Done**: đổ nội dung đầy đủ `playbook.md` (6 mục) + tạo `team-issues-queue.md` + cập nhật `hq-master.md`.
  - **playbook.md §1 When-to-team**: bảng 5 tình huống (spawn full / tự xử / builder+tester / researcher+planner+cto / tối thiểu) + quy tắc size 3–5 + 4 dấu hiệu cần spawn.
  - **playbook.md §2 Lifecycle**: spawn+brief template (4 field bắt buộc) → ack-cùng-turn → TaskUpdate in_progress→completed → shutdown_request → vòng re-fix/re-plan + escalation sau N vòng fail.
  - **playbook.md §3 Anti-pattern**: bảng 5 lead anti-pattern (lead-DIY / spawn thừa / brief thiếu done-criteria / không chờ ack / tự accept verdict) + bảng 7 teammate anti-pattern (JSON/silent/tự thoát/phán cảm tính/nhầm store/engine-build/stale context) + protocol tránh stale-context khi re-spawn.
  - **playbook.md §4 Issue queue**: trỏ `team-issues-queue.md` + format mỗi issue (date/code/slug + 5 field) + bảng 8 code phân loại (SILENT/STALE/FORM/SCOPE/GATE/STORE/BUILD/OTHER).
  - **playbook.md §5 Build-deliverable contract**: trỏ skill `build-verify` + tóm tắt builder workflow (projects/<name>/, Write/Edit, Bash, KHÔNG engine-build) + tester workflow (exit-code, CHECK_RESULT) + note engine = tool đứng riêng ngoại lệ.
  - **playbook.md §6 Memory protocol**: trỏ skill `hq-memory` + bảng 4 file store HQ-team (ai ghi / khi nào) + cảnh báo KHÔNG nhầm engine store + lệnh đọc cap N=10 + lệnh ghi `>>` (không `>`).
  - **team-issues-queue.md**: tạo file header + comment placeholder (rỗng — chưa có issue).
  - **hq-master.md**: cập nhật toàn bộ — flow động ASCII đầy đủ (classification → spawn → teammate chain → verdict → shutdown) + bảng gate-cũ-tan-vào-lead + bảng roster cập nhật (bỏ cột "Session đẻ") + bảng trỏ tài liệu 6 hàng (playbook / issue-queue / build-verify / hq-memory / memory store / design.md).
- **Output**: `company/.claude/teams/playbook.md` (đầy đủ 6 mục) · `company/.claude/team-issues-queue.md` · `company/.claude/hq-master.md` (cập nhật).
- **STOP gate**:
  - (a) playbook đủ 6 mục, không còn `_TODO H.9_`: ✅ (6/6 mục có nội dung thật)
  - (b) flow request→research→plan→build→test→record mô tả ĐỘNG (không DAG), ánh xạ rõ teammate: ✅ (ASCII flow diagram đầy đủ trong hq-master.md + §1 playbook)
  - (c) build-trực-tiếp + verify-khách-quan nêu trong §5 + §3 anti-pattern: ✅ (nhắc KHÔNG engine-build nhiều chỗ)
  - (d) `team-issues-queue.md` tạo (header + format): ✅
- **Regression**: validate hello exit 0 ✅ · run hello "x" -Mock done ✅ · selftest 9/9 PASS ✅ · `git diff engine/` rỗng ✅. Dọn `.runs/` test ✅
- **Next**: Session H.10 — chạy thật end-to-end (USER-GATE). Cần user xác nhận trước khi đốt token.
- **Notes**: Playbook §2 lifecycle template brief 4-field (user_request / context / done_criteria / output_format) đủ cho mọi teammate dùng ngay. §3 anti-pattern bảng kép (lead + teammate) — tách rõ ai làm gì sai. Code issue queue (SILENT/STALE/FORM/...) giúp track pattern lỗi qua nhiều lần chạy. hq-master.md nay = tài liệu hoàn chỉnh (không còn skeleton), lead đọc là đủ để bắt đầu spawn team.

### 2026-06-02 — Session H.8 — Skill `hq-memory`

- **Done**: soạn `.claude/skills/hq-memory/SKILL.md`.
  - Frontmatter: `name: hq-memory`, description 1 dòng nêu đọc/ghi + cảnh báo store tách bạch.
  - Body 5 mục: §1 Phân biệt 2 store (bảng `.claude/memory/` vs `company/memory/`, quy tắc vàng không trộn) · §2 Đọc memory (khi nào / ai đọc file nào / cap N=10 / lệnh cat + xử lý file rỗng) · §3 Ghi memory (format bắt buộc `## YYYY-MM-DD HH:MM — slug` + bảng vai-trò→file + 2 template ví dụ + lệnh `>>` append + cảnh báo không dùng `>`) · §4 Quick reference (compact 2 block đọc/ghi + 4 dòng rule) · §5 Ranh giới (bảng "không làm" 6 hàng: engine store / per-branch store / Write overwrite / thiếu delimiter / builder ghi / memory thay brief).
  - Điểm đặc trưng: §1 đặt cảnh báo store ở đầu tiên (trước cả quy ước đọc/ghi) — đây là lỗi cao nhất. §3 bảng "Ai ghi gì" map rõ tester-fail→mistakes/tester-pass→patterns/tester-luôn→context/lead→context+global. §5 bảng ranh giới nhấn mạnh `>>` vs `>`.
- **Output**: `.claude/skills/hq-memory/SKILL.md`.
- **Self-review STOP gate**:
  - (a) Frontmatter hợp lệ: name/description đủ, cảnh báo store tách bạch trong description ✅
  - (b) Quy ước đọc (đầu task): §2 có bảng ai-đọc-file-nào + cap N=10 + lệnh cat ✅
  - (c) Quy ước ghi (cuối task, format đo được): §3 có format `## YYYY-MM-DD HH:MM — slug` + bảng vai→file + 2 template + lệnh `>>` ✅
  - (d) Cảnh báo KHÔNG nhầm với `company/memory/`: §1 bảng 2-store + §5 bảng ranh giới ✅
- **Regression**: validate hello exit 0 ✅ · run hello "x" -Mock done ✅ · selftest 9/9 PASS ✅ · `git diff engine/` = 0 byte ✅. Dọn `.runs/` test ✅
- **Next**: Session H.9 — playbook đầy đủ (6 mục) + team-issues-queue.md + cập nhật hq-master.md.
- **Notes**: Skill này mirror schema engine memory (`company/memory/`) về format delimiter + cap N, nhưng store khác hoàn toàn. Cap N=10 là convention đọc (không enforce khi ghi — file giữ toàn bộ lịch sử). Template 2 ví dụ (fail + pass) giúp tester dùng ngay mà không phải nghĩ format. `>>` vs `>` được nhắc 2 lần (§3 + §5) vì đây là lỗi mất data không phục hồi.

### 2026-06-02 — Session H.7 — Skill `build-verify`

- **Done**: soạn `.claude/skills/build-verify/SKILL.md`.
  - Frontmatter: `name: build-verify`, description 1 dòng nêu rõ mục đích (build trực tiếp + verify khách quan) + đối tượng (builder + tester HQ-team).
  - Body 5 mục: §1 Nơi ghi + cấu trúc (`projects/<name>/`, gitignored, bảng cấu trúc theo loại, README bắt buộc) · §2 Builder — workflow 5 bước + anti-patterns · §3 Tester — workflow 5 bước (chạy check, map done-criteria, in `CHECK_RESULT:`) + bảng ví dụ + xử lý khi không có test tự động + anti-patterns · §4 Ranh giới — bảng "KHÔNG làm + lý do" + ngoại lệ engine-tool khi request cụ thể dựng pipeline · §5 Quick reference (2-khối compact cho builder/tester).
  - Điểm đặc trưng: §3 bảng map done-criteria → lệnh → exit-code → pass/fail (nhất quán với hq-tester.md Bước 3); `CHECK_RESULT:` format máy-đọc-được nhắc lại; §4 khẳng định KHÔNG `run.ps1 autobuild/autofix/build` trong bảng cấm.
- **Output**: `.claude/skills/build-verify/SKILL.md`.
- **Self-review STOP gate**:
  - (a) Frontmatter hợp lệ: name/description đủ, không có tools/model (skill không cần) ✅
  - (b) Mục "nơi ghi + cấu trúc": §1 có `projects/<name>/`, gitignored, bảng cấu trúc, README ✅
  - (c) Mục "verify khách quan": §3 có workflow 5 bước + bảng done-criteria + `CHECK_RESULT: pass|fail (...)` ✅
  - (d) Mục "ranh giới": §4 bảng "KHÔNG làm" rõ, KHÔNG tham chiếu engine-build làm đường build ✅
- **Regression**: validate hello exit 0 ✅ · run hello "x" -Mock done ✅ · selftest 9/9 PASS ✅ · `git diff engine/` = 0 byte ✅. Dọn `.runs/` test ✅
- **Next**: Session H.8 — `hq-memory` skill (đọc/ghi `.claude/memory/`).
- **Notes**: Skill được thiết kế để cả builder lẫn tester đọc — §2 dành cho builder, §3 dành cho tester; §4 ranh giới dùng chung. Quick reference §5 compact giúp teammate check nhanh mà không cần đọc lại cả skill. `CHECK_RESULT:` lặp lại từ hq-tester.md — intentional (skill là nguồn sự thật, teammate là consumer).

### 2026-06-02 — Session H.6 — `hq-tester.md` teammate

- **Done**: soạn `.claude/agents/hq-tester.md`.
  - Frontmatter: `name: hq-tester`, `tools: [Read, Bash]` (tester cần đọc file + chạy lệnh test/build/lint — KHÔNG Write/Edit), `model: claude-sonnet-4-6`, description 1 dòng nêu rõ check khách quan + KHÔNG run.ps1 + KHÔNG phán cảm tính.
  - Body: mission 1 câu ("xác nhận deliverable đạt done-criteria bằng bằng chứng khách quan") → Đọc đầu phiên 4 bước → Workflow chính 5 bước (đọc brief / chạy check deliverable / map done-criteria theo bảng / in CHECK_RESULT + ghi memory / báo lead) → Anti-patterns (8 bullet: no-cảm-tính/no-run.ps1/skip-test=fail/ghi-memory-cả-hai/không-đụng-company-memory/tester-không-Write-Edit/CHECK_RESULT-bắt-buộc/map-toàn-bộ-done-criteria) → Output format (template bảng done-criteria + CHECK_RESULT) → Quality gate 7 checkbox → TeamCreate mode đầy đủ (7 bullet: spawn-ack/TaskGet/TaskUpdate/SendMessage/shutdown/brief-thiếu-guard/re-verify-toàn-bộ/verify-done-prior).
  - Điểm đặc trưng tester: Bước 2 có ví dụ lệnh theo từng stack (npm/pytest/go); Bước 3 là bảng map done-criteria → bằng chứng → pass/fail; `CHECK_RESULT:` in đầu verdict (máy đọc được).
- **Output**: `.claude/agents/hq-tester.md`.
- **Self-review checklist (a)–(d)**:
  - (a) frontmatter hợp lệ: name/description/tools (Read+Bash — đúng quyền tester: chạy lệnh được, không ghi file)/model đúng ✅
  - (b) body team agent thực thụ (KHÔNG 5-mục node): mission + Đọc đầu phiên + Workflow chính 5 bước + Anti-patterns + Output format + Quality gate + TeamCreate mode ✅
  - (c) TeamCreate mode ≥6 bullet: spawn-ack · TaskGet · TaskUpdate in_progress→completed · SendMessage khi xong · shutdown_request · verify-done-from-prior-session + re-verify-toàn-bộ-sau-fix (7 bullet) ✅
  - (d) self-review ghi vào CHECKPOINT (mục này) ✅
- **Gate**: (a)–(d) đạt ✅; gate khách quan dựa exit-code/output thật (không cảm tính) nêu nhiều chỗ ✅; KHÔNG `run.ps1 check/trial` nêu trong intro + anti-patterns ✅; đường ghi memory rõ (Bước 4: patterns.md pass / mistakes.md fail / context.md luôn) ✅; `CHECK_RESULT:` format máy đọc được ✅
- **Regression**: validate hello exit 0 ✅ · run hello "x" -Mock done ✅ · selftest 9/9 PASS ✅ · `git diff engine/` = 0 byte ✅. Dọn `.runs/` test ✅
- **Next**: Session H.7 — `build-verify` skill (quy ước build trực tiếp + verify khách quan).
- **Notes**: Tester là teammate read+run-only (không ghi deliverable). `CHECK_RESULT:` là tín hiệu đặc trưng của tester — format máy đọc được giúp lead/automation phân tích verdict mà không cần parse prose. Bảng done-criteria ở Bước 3 là "hợp đồng" giữa builder và tester — toàn bộ done-criteria phải map, không cherry-pick.

### 2026-06-02 — Session H.5 — `hq-builder.md` teammate

- **Done**: soạn `.claude/agents/hq-builder.md`.
  - Frontmatter: `name: hq-builder`, `tools: [Read, Write, Edit, Bash]` (builder cần ghi file + chạy build), `model: claude-sonnet-4-6`, description 1 dòng nêu rõ build trực tiếp + KHÔNG autobuild/workflow.json/engine.
  - Body: mission 1 câu ("biến thiết kế thành file thật") → Đọc đầu phiên 4 bước → Workflow chính 5 bước (đọc brief / chuẩn bị workspace / Write+Edit files / smoke-check / báo tester) → Anti-patterns (9 bullet: no-autobuild/no-workflow.json/no-engine/no-tự-suy-thiết-kế/no-ghi-đè-toàn-bộ/no-thiếu-lệnh-chạy/no-gold-plate/no-engine-store/no-ngoài-scope) → Output format (template "Build xong" với lệnh chạy + done-criteria) → Quality gate 7 checkbox → TeamCreate mode đầy đủ (7 bullet: spawn-ack/TaskGet/TaskUpdate/SendMessage/shutdown/re-fix/verify-done-prior).
  - Điểm đặc trưng builder: Bước 4 smoke-check trước khi báo tester — bắt lỗi syntax/deps sớm; Bước 5 template "cách chạy/kiểm" chi tiết để tester verify khách quan theo done-criteria.
- **Output**: `.claude/agents/hq-builder.md`.
- **Self-review checklist (a)–(d)**:
  - (a) frontmatter hợp lệ: name/description/tools (Read+Write+Edit+Bash — đúng quyền builder)/model đúng ✅
  - (b) body team agent thực thụ (KHÔNG 5-mục node): mission + Đọc đầu phiên + Workflow chính 5 bước + Anti-patterns + Output format + Quality gate + TeamCreate mode ✅
  - (c) TeamCreate mode ≥6 bullet: spawn-ack · TaskGet · TaskUpdate in_progress→completed · SendMessage khi xong · shutdown_request · verify-done-from-prior-session + re-fix-path (7 bullet) ✅
  - (d) self-review ghi vào CHECKPOINT (mục này) ✅
- **Gate**: (a)–(d) đạt ✅; output location `projects/<name>/` nêu rõ nhiều chỗ ✅; khẳng định build trực tiếp (KHÔNG engine-build) cả intro box + Anti-patterns ✅; Bước 5 + Output format có template lệnh chạy + done-criteria để tester verify ✅
- **Regression**: validate hello exit 0 ✅ · run hello "x" -Mock done ✅ · selftest 9/9 PASS ✅ · `git diff engine/` = 0 byte ✅. Dọn `.runs/` test ✅
- **Next**: Session H.6 — `hq-tester.md` teammate (check khách quan + ghi memory).
- **Notes**: Builder là teammate duy nhất có Write+Edit+Bash — tools đủ để build toàn bộ deliverable mà không cần engine-build. Smoke-check (Bước 4) tách khỏi full test (việc của tester) — đúng ranh giới: builder verify syntax/deps, tester verify done-criteria theo plan.

### 2026-06-02 — Session H.4 — `hq-cto.md` teammate

- **Done**: soạn `.claude/agents/hq-cto.md`.
  - Frontmatter: `name: hq-cto`, `tools: [Read]` (read-only — CTO chỉ thiết kế, không ghi file), `model: claude-sonnet-4-6`, description 1 dòng phân biệt rõ vs `catalog/tech-lead.md`.
  - Body: mission 1 câu → Đọc đầu phiên (4 bước có thứ tự) → Workflow chính (4 bước: đọc plan WHAT / thu context kỹ thuật / soạn thiết kế 5 phần A–E / trả lead) → Anti-patterns (9 bullet: no-JSON/no-build-spec/no-catalog-pipeline/no-over-engineer/check-done-criteria...) → Output format (template 5 phần) → Quality gate 6 checkbox → TeamCreate mode đầy đủ.
  - Thiết kế 5 phần: (A) Stack & công nghệ, (B) Cấu trúc file, (C) Cách tiếp cận từng Step, (D) Điểm cần chú ý, (E) Câu hỏi còn chặn.
  - Convention catalog: `catalog/` là tham chiếu kỹ thuật tùy chọn (đọc để hiểu domain), KHÔNG phải menu lắp pipeline.
- **Output**: `.claude/agents/hq-cto.md`.
- **Self-review checklist (a)–(d)**:
  - (a) frontmatter hợp lệ: name/description/tools (Read — read-only)/model đúng ✅
  - (b) body team agent thực thụ (KHÔNG 5-mục node): mission + Đọc đầu phiên + Workflow chính + Anti-patterns + Output format + Quality gate + TeamCreate mode ✅
  - (c) TeamCreate mode ≥6 bullet: spawn-ack · TaskGet · TaskUpdate in_progress→completed · SendMessage khi xong · shutdown_request · verify-done-from-prior-session + brief-thiếu-guard (7 bullet) ✅
  - (d) self-review ghi vào CHECKPOINT (mục này) ✅
- **Gate**: (a)–(d) đạt ✅; thiết kế là văn xuôi cho builder đọc (không JSON ceremony) ✅; nêu rõ builder sẽ Write/Edit trực tiếp theo thiết kế ✅; KHÔNG tham chiếu run.ps1 build/autobuild ✅
- **Regression**: validate hello exit 0 ✅ · run hello "x" -Mock done ✅ · selftest 9/9 PASS ✅ · `git diff engine/` = 0 byte ✅. Dọn `.runs/` test ✅
- **Next**: Session H.5 — `hq-builder.md` teammate (Write/Edit/Bash trực tiếp).
- **Notes**: Catalog được giữ vai trò tham chiếu kỹ thuật (không phải menu lắp workflow) — phù hợp thiết kế Q2. Convention 5-phần A–E đủ để builder không phải đoán cấu trúc hay hướng đi.

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
