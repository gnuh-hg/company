# HQ Build — Roadmap chia phase

> Bản đồ chia HQ thành các phase độc lập; **mỗi phase = 1 long-plan** sẽ soạn riêng khi user yêu cầu. File này KHÔNG phải long-plan — chỉ mô tả *cần làm gì* + *cần làm rõ gì* để mỗi lần dựa vào đây dựng PLAN/CHECKPOINT.

---

## Nền tảng đã có (không build lại)

- **Engine v1+v2 xong**: single-cursor walk trên graph, router OR (agent quyết nhãn), loop (cycle), `max_steps` cầu dao, mock offline, `validate`/`viz`/`status`/`logs`/`resume`. Tương thích ngược `pipeline` v1.
  - ✅ **Giới hạn mock (đã giải ở P0-C):** `ENGINE_MOCK_ROUTER` nay nhận **đa-spec** ngăn bởi `;` (`"a:l1,l2;b:l3"`) — mỗi router steer độc lập trên cùng path. Thay đổi testing-only, additive trong `lib/claude.ps1` (1 spec không-`;` vẫn chạy y cũ). p-brain (P0) mock-drive trọn ≥3 path bằng cách này; P4 (HQ graph) tái dùng.
- **Quyết định kiến trúc đã chốt** (đọc trước mỗi phase):
  1. **Giữ engine ps1** làm substrate — KHÔNG chuyển sang Claude Code team. Linh hồn: workflow-as-data, cố định, governed, test-được-trước-khi-chạy.
  2. **Mô hình lắp ráp**: Catalog = vai đúc sẵn hand-authored. HQ = thợ lắp (chọn vai + nối `workflow.json` + scaffold), KHÔNG tự rèn agent.
  3. **Tester máy-kiểm-được**: pass = `validate` exit 0 + mọi `output_key` ra + đúng shape khai trong "Trả ra" + mock run done. Không để LLM phán cảm tính.
  4. **Chất lượng = graph giàu tầng robustness**, không phải agent đặc biệt. Mọi tầng (làm rõ / plan / kiểm) đều là router+loop — engine v2 đã đủ diễn đạt.
- **Ràng buộc bất biến**: chỉ thao tác trong `company/`, không đụng `leafnote/`. Leafnote agent team (`team-pm`/`dev`/`designer`/`db`/`qa`/`tech-lead` + `plan-long`/`plan-short`) chỉ **đọc tham khảo** làm prior art khi rút vai/pattern.

---

## Cross-cutting — cần làm rõ TRƯỚC phase 0 (chốt 1 lần, áp mọi phase)

Các quyết định này không thuộc riêng phase nào nhưng định hình tất cả:

- **C-1. Pattern lưu thế nào?** → **CHỐT: copy-convention + helper stamp.** Runtime `workflow.json` luôn explicit (không include/expand ẩn lúc chạy — giữ "thấy gì chạy nấy", test-được-trước-khi-chạy). Pattern lưu `patterns/<name>.json` (fragment node+edge, id placeholder `__P__x`). Builder đóng dấu vào workflow.json; optional helper `Expand-Pattern $fragment $prefix` cho Builder làm programmatic. Trùng lặp giữa branch OK vì branch là sinh-ra (regen được). Loại engine-include vì expand ẩn phá test-trước-khi-chạy + thêm phức tạp.
- **C-2. "Shape" output kiểm thế nào?** → **CHỐT (user): thử công việc thực tế trong sandbox cô lập.** Tester 2 tầng: (1) gate cấu trúc `validate` exit0 + mock done (nhanh, free); (2) trial hành vi — chạy việc thật trong `company/sandbox/` (gitignore), xem ra sản phẩm chạy được. Thay LLM-phán bằng thử-thật. Hệ quả: catalog (P1) KHÔNG cần shape contract cứng; cần cơ chế sandbox isolation (bổ sung P2); trial tốn token + non-deterministic (đổi lấy chất lượng).
- **C-3. Spec CTO dạng gì?** → **CHỐT: build-spec JSON schema cố định.** `{ name, roles[] (từ catalog), patterns[] (stamp P0), edges[], entry, max_steps, trial[] (việc thật cho Tester) }`. LLM-judgment dồn ở CTO; Builder gần deterministic (copy role + stamp pattern + nối edge + scaffold) → cô lập phần mờ (design) khỏi phần nguy hiểm (ghi file). Validate spec bằng schema trước khi Builder hành động.

---

## Các phase (mỗi phase = 1 long-plan)

### Phase R — Nghiên cứu + thiết kế mô hình "đầu-não"
- **Mục tiêu:** chốt mô hình đầu-não chống "rắn mất đầu" TRƯỚC khi build mù pattern/catalog. Đầu-não = `research → plan(dài→ngắn) → orchestrate(làm/kiểm) → re-plan khi mơ hồ/fail → escalate khi bí → ghi nhớ kết cục`.
- **Xây gì:** khảo prior art Leafnote (**chỉ đọc, không sửa**) — bộ tham khảo đã ghim, map theo phần đầu-não:
  - `.claude/skills/plan-long/SKILL.md` (PLAN+CHECKPOINT, 1 chat=1 session, STOP gate) → plan-as-data + `plan-decompose` + vai `planner`.
  - `.claude/skills/plan-short/SKILL.md` (plan ngắn inline + gate) → plan dài→ngắn.
  - `.claude/workflows/plan.md` (classifier short/long + routing) → COO phân loại + Planner.
  - `.claude/agents/helpers/planner.md` (classify + sinh PLAN/CHECKPOINT) → template vai `planner` + agent Planner HQ (Phase 3).
  - `.claude/memory/` (context/mistakes/patterns) → cấu trúc kho trí nhớ (Phase M).
  - `.claude/workflows/master.md` (entry + post-task checklist) → cách HQ điều phối.
  Rút ra: vai/pattern/cơ chế thật cần + plan-as-data trông thế nào. Output = tài liệu mô hình đầu-não, khung cho Phase 0/1/3/M.
- **⚠ Cảnh báo dịch-không-port:** Leafnote là agent TƯƠNG TÁC (routing bằng reasoning động + người trong vòng lặp). HQ là HEADLESS + workflow-as-data (graph cố định). **Tham khảo cái GÌ** (plan chứa gì, STOP gate, kỷ luật 1-session, cấu trúc memory), **dịch sang cái CÁCH** (routing động → router node; hỏi người giữa chừng → escalate-gate trong graph). KHÔNG port nguyên cơ chế tương tác.
- **Cần làm rõ:** plan-as-data format (planner xuất plan dưới dạng dữ liệu, graph cố định, re-plan = cạnh loop về node planner — KHÔNG để agent bẻ lái động); ranh giới research vs clarify; tiêu chí "đủ rõ để ngừng re-plan".
- **Phụ thuộc:** engine v2 (đã có).
- **Done-gate:** tài liệu mô hình đầu-não chốt — liệt kê đủ vai + pattern + cơ chế cần, giải quyết căng thẳng "đầu-não vs workflow cố định" bằng plan-as-data.

### Phase 0 — Thư viện pattern robustness
- **Mục tiêu:** graph fragment tái dùng làm nền chất lượng cho mọi workflow — hiện thực tầng đầu-não từ Phase R.
- **Xây gì:** 6 pattern = cụm node+edge (router+loop) + agent stub + demo mock (`ENGINE_MOCK_ROUTER`): `research-gather`, `clarify-gate`, `plan-decompose` (dài→ngắn), `re-plan-loop` (verify/clarify fail → quay về planner), `do-verify-loop`, `escalate-gate` (bí/chạm trần → thoát báo user). Lưu `patterns/<name>.json` (C-1, id placeholder).
- **Cần làm rõ:** ranh giới mỗi pattern; nhãn router chuẩn từng pattern (vd verify: `đạt`/`chưa`; escalate: `tiếp`/`bí`); helper `Expand-Pattern` (C-1).
- **Phụ thuộc:** Phase R (mô hình).
- **Done-gate:** 6 pattern demo chạy mock đúng — research→plan→do/verify chạy thuận, mơ hồ → re-plan loop, bí → escalate thoát; tất cả có `max_steps`.

### Phase 1 — Catalog vai chi nhánh (đúc sẵn)
- **Mục tiêu:** menu vai hand-authored, bám sát, không chồng lấn — input của CTO.
- **Xây gì:** `catalog/` chứa từng vai .md (5 mục cố định, ~6–10 dòng): **đầu-não** (`researcher`, `planner` — từ Phase R), Product (pm, ba), Design (ux, ui), Engineering (tech-lead, db-architect, api-developer, auth-engineer, frontend-developer, devops, mobile-*), QA (qa-functional, qa-regression). Mỗi vai khai "Trả ra" (mô tả, không còn shape cứng — C-2 đo bằng trial).
- **Cần làm rõ:** MVP đủ vai nào trước (core subset hay full)? Ranh giới "không làm" của từng vai để không đè nhau (đặc biệt researcher vs ba, planner vs pm vs tech-lead). Rút prior art từ Leafnote team (chỉ đọc).
- **Phụ thuộc:** Phase R (vai researcher/planner), C-2.
- **Done-gate:** catalog đủ vai MVP, ranh giới không đè nhau; lắp thử 1 chi nhánh web tay từ catalog → `validate` pass.

### Phase 2 — Tiêu chí Tester máy-kiểm-được + fixture ✅ DONE
- **Mục tiêu:** Tester 2 tầng (C-2) — gate cấu trúc + trial thực tế trong sandbox cô lập, + fixture bootstrap.
- **Xây gì (đã giao):** (1) `engine/check.ps1` `Test-StructuralGate` — gate cấu trúc: `validate` exit0 → `run -Mock` done → mọi `output_key` non-empty (lệnh `run.ps1 check`). (2) `engine/sandbox.ps1` — `Copy-ToSandbox`/`Remove-Sandbox` (copy project trừ `.runs/` vào `company/sandbox/<runid>/`, teardown an toàn) + `Get-Trials`/`Test-TrialExpect`/`Invoke-Trial` chạy project **THẬT** (no -Mock) → assert `trial[]` trên artifact (lệnh `run.ps1 trial` 2 tầng). `company/.gitignore` thêm `sandbox/`.
- **Đã chốt (user):** sandbox = **copy thư mục** (không worktree — `company/` chưa là git repo); fixture = **tái dùng `loopy`** (phục vụ cả 2 tầng: mock cho cấu trúc, real cho trial); "trial đạt" = run real `done` + assert `trial[]` `{ observe, expect{kind: non-empty|contains|matches, value} }` trên `output_key` shipped.
- **Phụ thuộc:** Phase 1 (catalog), C-2, C-3 (định nghĩa `trial[]`).
- **Done-gate (đạt):** `check loopy`+`check hello` exit 0; 3 mutation (bad-agent/router-mismatch/missing-key) fail đúng tầng + reason máy-đọc-được; `trial loopy` cấu trúc pass → trial real `done` + 2 assertion pass (`result` non-empty + chứa "Ship"); isolation xác nhận (artifact trong sandbox, gốc sạch, teardown).

### Phase M — Cơ chế trí nhớ (#5)
- **Mục tiêu:** chất lượng tích luỹ qua các lần run — HQ không lặp lại lỗi cũ.
- **Xây gì:** kho memory (mistakes / patterns / context) như Leafnote `.claude/memory`; quy ước agent **đọc** (researcher/planner đọc trước khi làm) + HQ **ghi** (Tester/report ghi kết cục, lỗi đã gặp). Cơ chế nạp memory liên quan vào prompt qua bridge.
- **Cần làm rõ:** lưu ở đâu (per-branch vs HQ-global vs cả hai); ai được ghi (chỉ HQ hay cả branch agent); cách bridge chọn memory liên quan để nạp (tránh phình prompt).
- **Phụ thuộc:** Phase R (mô hình đầu-não định nghĩa memory dùng ở đâu).
- **Done-gate:** một lỗi ghi vào memory ở run trước → run sau researcher/planner đọc được + tránh lặp; demo bằng mock.

### Phase 3 — HQ agents lắp ráp (COO/Planner/CTO/Builder/Tester) + skills — ✅ DONE
- **Mục tiêu:** **5 agent HQ** + skills (scaffold/patch/diagnose/run-test/report) — bộ lắp ráp có đầu-não.
- **Xây gì:** COO (router phân loại build/fix/unclear), **Planner (plan build dài→ngắn cho chi nhánh phức tạp, đọc memory)**, CTO (plan→build-spec JSON C-3: chọn vai catalog + pattern + nối edge + `trial[]`), Builder (spec→copy vai + stamp pattern + sinh `workflow.json` + scaffold, `allowedTools`/`permission_mode` — chỉ Builder được Write/Edit), Tester (dùng checker Phase 2 + ghi memory).
- **Cần làm rõ:** C-3 (format spec CTO); ranh giới Planner vs CTO (plan vs spec); nhãn phân loại COO; phạm vi quyền file Builder; Builder copy vai + stamp pattern thế nào.
- **Phụ thuộc:** Phase 0 (pattern stamp), Phase 1 (catalog), Phase 2 (checker), Phase M (memory), C-3.
- **Done-gate:** mỗi agent test đơn lẻ bằng mock — Planner ra plan dài→ngắn, CTO ra spec parse được, Builder sinh đúng cây + `workflow.json` validate pass, Tester gọi checker + ghi memory đúng.

### Phase 4 — HQ workflow graph (lắp v2 router+loop + pattern Phase 0) — ✅ DONE
- **Deliverable:** `hq/agents/researcher.md` (agent thứ 6 HQ-level) + `hq/workflow.json` (11 node, 17 cạnh, entry=coo, max_steps=40, trial[] cấu trúc) + `hq/workflow.mmd` + `examples/hq-graph-tests.ps1` (8 path mock-drive: 6 path coverage + 2 loop-bounding). Done-gate 5/5 pass: validate exit 0; mock đúng build/fix/unclear; do-verify-fix + re-plan loop dừng đúng; re-plan escalate khi revision≥max (soft) + max_steps=40 backstop (hard); viz `.mmd` có back-edge. HQ graph hand-authored (KHÔNG Expand-Pattern); trial real defer P5.
- **Mục tiêu:** `hq/workflow.json` nối toàn bộ thành graph có robustness.
- **Xây gì:** COO(router)→[clarify-gate]→Planner→CTO→Builder→Tester(router); Tester fail→Builder (do-verify loop); Tester/Builder bí→[escalate-gate]→thoát báo user; plan mơ hồ→[re-plan-loop] về Planner; pass→done. `max_steps` cầu dao. Dùng pattern Phase 0 (#4 escalate nằm ở đây).
- **Cần làm rõ:** chèn clarify-gate/escalate-gate ở đâu; `max_steps` HQ bao nhiêu; nhánh fix vs build-new tách ở COO hay Planner.
- **Phụ thuộc:** Phase 0 (pattern), Phase 3 (agents).
- **Done-gate:** `validate hq` pass; mock đi đúng nhánh build/fix/unclear; loop fix lặp rồi dừng đúng; re-plan loop + escalate thoát đúng; `viz` đọc được.

### Phase 5 — Build-test-fix chạy thật end-to-end ✅ DONE (2026-05-28)
- **Mục tiêu:** HQ build thật 1 chi nhánh nhỏ từ request user, Tester chạy, vòng fix hoạt động — headless thật (không mock).
- **Đã xây:** wire frontmatter→CLI (`workflow.ps1` `Get-AgentFrontmatter` + `model:` 11 agent) + `engine/e2e.ps1` (`Invoke-E2E` build + `Invoke-E2EFix` fix-loop: dry-run gate → sandbox → run real → verify validate/check → promote) + lệnh `run.ps1 e2e`/`e2efix`. Happy-path: branch **`landing-email`** (real, promote). Fix-loop: fixture hỏng `examples/broken-web` → Builder patch thật → `validate` 3→0 → promote **`projects/broken-web`**.
- **Done-gate 5/5 ✅:** mock regression xanh + frontmatter parse; harness sandbox round-trip + promote; real happy-path done→validate exit 0→promote; real fix-loop Builder patch thật→validate fail→pass; gốc `hq/` sạch + doc cập nhật.
- **Deliverable:** `plan/hq-build/phase-5/PLAN.md`+`CHECKPOINT.md` (chi tiết 4 session + watch-item builder non-determinism).

### Phase 6 (tuỳ chọn, sau cùng) — App local view/edit
- **Mục tiêu:** GUI offline xem pipeline đang chạy + sửa `workflow.json` trực quan.
- **Lưu ý:** design doc nói "build sau khi engine ổn định — không blocker". Để cuối, không chặn Phase 0–5.

---

## Thứ tự phụ thuộc (tóm tắt)

```
Cross-cutting C-1/C-2/C-3 (đã chốt)
   │
   ▼
Phase R (research + mô hình đầu-não)   ← khung cho mọi phase sau
   │
   ▼
Phase 0 (pattern) ─┐
Phase 1 (catalog) ─┤
Phase 2 (Tester)  ─┼─► Phase 3 (HQ agents) ─► Phase 4 (HQ graph) ─► Phase 5 (E2E thật)
Phase M (memory)  ─┘                                                      │
                                                              Phase 6 (app, tuỳ chọn)
```

R trước tất cả (de-risk). Phase 0/1/2/M độc lập tương đối sau R; 3 cần 0+1+2+M; 4 cần 0+3; 5 cần 4 (+M tích luỹ). Escalate (#4) là pattern trong P0, wiring ở P4/P5.

---

## Cách dùng file này

Mỗi lần build một phase: user trỏ vào phase tương ứng → mình dựng long-plan (PLAN.md + CHECKPOINT.md trong `plan/<phase-slug>/`) theo plan-long, **chốt phần "cần làm rõ" của phase đó trước** rồi mới chia session. Cập nhật bảng tiến độ dưới đây khi một phase xong.

| Phase | Long-plan | Trạng thái |
|---|---|---|
| Cross-cutting C-1/C-2/C-3 | — | ✅ chốt (C-2 user; C-1/C-3 đề xuất) |
| R — Research + mô hình đầu-não | `plan/hq-build/phase-r/` | ✅ (brain-model.md chốt) |
| 0 — Pattern robustness (6 pattern) | `plan/hq-build/phase-0/` | ✅ (6 fragment + `engine/pattern.ps1` + 6 demo + `p-brain` integration; done-gate 6/6) |
| 1 — Catalog vai (+researcher/planner) | `plan/hq-build/phase-1/` | ✅ (17/17 vai `catalog/*.md` + `catalog/README.md` ma trận ranh giới; `examples/web-demo/` lắp tay nối 11 vai web-full → validate exit 0 + run -Mock done) |
| 2 — Tester + sandbox + fixture | `plan/hq-build/phase-2/` | ✅ DONE (4 session — `engine/check.ps1` + `engine/sandbox.ps1` + lệnh `check`/`trial`; gate 2 tầng pass trên loopy, 3 mutation fail đúng tầng) |
| M — Cơ chế trí nhớ | `plan/hq-build/phase-m/` | ✅ (store 2 tầng `company/memory/` + per-branch `context.md`; `engine/memory.ps1` Get-Memory/Write-MemoryEntry by-type+cap N; bridge nạp `{{mem_*}}`; node `record` `memory_write`; `examples/mem-demo` done-gate 2-run) |
| 3 — HQ agents (5: +Planner) | `plan/hq-build/phase-3/` | ✅ DONE — `hq/build-spec.md` + `engine/spec.ps1` (Test-PlanSchema/Test-BuildSpec/Invoke-BuildSpec + `run.ps1 build`) + `hq/agents/{coo,planner,cto,builder,tester}.md` (Builder-only Write/Edit) + `hq/skills.md` + per-agent mock test `examples/hq-tests.ps1` (5 fixture `examples/hq-{coo,tester,planner,cto}`) pass |
| 4 — HQ graph (+re-plan/escalate) | `plan/hq-build/phase-4/` | ✅ DONE — `hq/agents/researcher.md` (agent thứ 6) + `hq/workflow.json` (11 node robustness đủ tầng, max_steps=40) + `hq/workflow.mmd` + `examples/hq-graph-tests.ps1` (8 path: 6 coverage + re-plan escalate soft + max_steps backstop hard) exit 0; done-gate 5/5 |
| 5 — E2E thật | `plan/hq-build/phase-5/` | ✅ DONE (4/4 session, done-gate 5/5). Wire frontmatter→CLI + `engine/e2e.ps1` (`Invoke-E2E`/`Invoke-E2EFix`) + `run.ps1 e2e`/`e2efix`. Real: branch `landing-email` (build) + `broken-web` (fix-loop patch thật). Watch: builder non-determinism (prompt-hardened, không guard cứng) |
| 6 — App local (tuỳ chọn) | — | ⬜ |
