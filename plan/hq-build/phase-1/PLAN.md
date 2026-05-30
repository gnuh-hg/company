# PLAN — Phase 1: Catalog vai chi nhánh (đúc sẵn)

> Sau toàn bộ pipeline: có `catalog/` chứa **17 vai hand-authored** (mỗi file 5 mục cố định, ~6–10 dòng, khai "Trả ra" mô tả — không shape cứng theo C-2) + `catalog/README.md` (template 5 mục + **ma trận ranh giới chống đè**) + 1 chi nhánh web lắp tay `examples/web-demo/` (workflow.json nối vai từ catalog + agent stub) chạy `validate` exit 0 + `run -Mock` done. Đây là **menu input cho CTO** (Phase 3) — CTO chọn tập con vai, Builder copy vào `workflow.json` chi nhánh.

---

## Context

- **Vì sao chia nhiều session:** 17 vai, mỗi vai phải chốt ranh giới "không làm" để không đè vai khác (đặc biệt researcher↔ba, planner↔pm↔tech-lead) + rút prior-art Leafnote từng vai. Author gộp 1 chat → ranh giới ẩu, đè nhau. Foundation (template + ma trận ranh giới + 2 vai đầu-não khó nhất) phải chốt TRƯỚC khi nhân bản các vai còn lại.
- **Quyết định đã chốt (user 2026-05-27):**
  - **MVP = full catalog incl mobile (17 vai):** đầu-não `researcher`, `planner`; Product `pm`, `ba`; Design `ux`, `ui`; Engineering `tech-lead`, `db-architect`, `api-developer`, `auth-engineer`, `frontend-developer`, `devops`, `mobile-ios`, `mobile-android`, `mobile-flutter`; QA `qa-functional`, `qa-regression`.
  - **Template 5 mục cố định mỗi vai:** (1) **Một việc** — mission 1 câu; (2) **Input** — context/`{{key}}` cần đọc; (3) **Trả ra** — mô tả output (KHÔNG shape cứng, C-2); (4) **Không làm** — ranh giới chống đè vai khác (tường minh, ≥2 dòng); (5) **Handoff** — vai downstream tiêu thụ output. Gộp ý prior-art Leafnote (read-order + "Không làm" + output format) → dạng headless gọn ~6–10 dòng.
  - **Chi nhánh lắp thử tay = `examples/web-demo/` mới** (không đụng demo cũ): `workflow.json` nối vai catalog + agent stub echo, `validate` + `run -Mock`.
- **Đầu vào đã chốt (không thiết kế lại):**
  - `brain-model.md` §Mô hình A = 2 vai đầu-não `researcher`/`planner` + ranh giới "một việc" + "Trả ra" mô tả. §Tension = **vì sao tách researcher↔planner** (re-plan-loop quay về planner, không lặp research tốn kém). §Plan-as-data = `planner` xuất gì.
  - `information/agent-design.md` §Chi nhánh-Catalog = danh sách 17 vai + cột "Trả ra" / "Không làm" gốc + cấu hình theo quy mô + ví dụ pipeline web-full 10-step.
  - **C-2:** engine KHÔNG validate shape output agent → catalog **không** cần shape contract cứng; "Trả ra" chỉ mô tả mức ý nghĩa. Đo bằng trial ở P2, không phải ở P1.
- **Prior-art Leafnote (CHỈ ĐỌC — quy ước bất biến #6, không sửa `leafnote/`):** `.claude/agents/teams/{team-pm,team-tech-lead,team-designer,team-dev,team-db-architect,team-qa}.md` + `.claude/agents/helpers/planner.md`. Rút ý: read-order đầu phiên, "Không làm"/ràng buộc cứng, output format đo được, "DO NOT implement — plan only". **⚠ Dịch-không-port:** Leafnote là agent TƯƠNG TÁC (spawn qua `@`, người duyệt, đọc file thủ công); catalog HQ là **vai headless** nhận context qua bridge `{{key}}`, không spawn sub-agent, không hỏi người (clarify → escalate-gate ở graph, không trong vai). Tham khảo *cái GÌ* (vai chia thế nào, ranh giới ở đâu, trả ra gì), dịch sang *cái CÁCH* headless.
- **Quan hệ vai catalog ↔ engine:** Vai `.md` chỉ là **system prompt + ranh giới** (quy ước bất biến #1 — KHÔNG chứa logic workflow). Wiring (edge/router/bridge) là việc của CTO/Builder ở P3/P4. P1 chỉ giao *menu vai* + chứng minh lắp tay được 1 chi nhánh.
- **Out of scope:** Tester/sandbox/trial đo "Trả ra" (P2); memory store researcher/planner đọc (PM); agent HQ thật + plan-as-data headless (P3); HQ graph (P4); chạy thật end-to-end (P5). P1 chỉ giao *catalog vai .md + ma trận ranh giới + 1 demo lắp tay validate-pass* — vai dùng stub echo khi demo, CTO thay bằng nội dung thật sau.

---

## Pipeline 3 sub-phase / 5 session

```
[1-A] Foundation: template + ma trận ranh giới + 2 vai đầu-não (khó nhất)
      └─ catalog/README.md (5 mục + boundary matrix) + catalog/researcher.md + catalog/planner.md
         (chốt ranh giới researcher↔ba, planner↔pm↔tech-lead TRƯỚC khi nhân bản)
                                    │
[1-B] 15 vai còn lại (theo khối, mỗi vai 5 mục, bám prior-art Leafnote)
      B.1 Product (pm, ba) + Design (ux, ui)                         — 4 vai
      B.2 Engineering core (tech-lead, db-architect, api-developer,
          auth-engineer, frontend-developer, devops)                 — 6 vai
      B.3 Mobile (ios, android, flutter) + QA (functional, regression) — 5 vai
                                    │
[1-C] Lắp thử chi nhánh web tay + done-gate
      └─ examples/web-demo/ (workflow.json nối vai + stub) validate exit 0 + run -Mock done
         + verify ma trận ranh giới đầy đủ + cập nhật ROADMAP/CLAUDE.md
                                    │
                                Phase 1 done
```

---

## Phase 1-A — Foundation: template + ma trận ranh giới + 2 vai đầu-não

**Mục tiêu**: chốt **một lần** template 5 mục + ma trận ranh giới chống đè, hiện thực trên 2 vai đầu-não khó nhất (`researcher`, `planner`) — nơi căng thẳng ranh giới lớn nhất (researcher↔ba, planner↔pm↔tech-lead). Sau session này, 15 vai còn lại chỉ điền template + tra ma trận.

### Session A.1 — README (template + boundary matrix) + researcher + planner
- **Scope**:
  1. Tạo `catalog/README.md`: (a) **Template 5 mục** chuẩn mỗi vai (Một việc / Input / Trả ra / Không làm / Handoff) + quy ước ~6–10 dòng, "Trả ra" mô tả không shape cứng (C-2), vai = system prompt thuần không chứa logic workflow (#1); (b) **Ma trận ranh giới chống đè** — bảng liệt kê các cặp dễ đè + ai làm gì / ai KHÔNG làm gì:
     - `researcher` ↔ `ba`: researcher = gom hiểu biết kỹ thuật/bối cảnh TRƯỚC plan (đọc code/doc/memory, đầu-não, không sinh spec, không hỏi user); `ba` = biến user-story (từ `pm`) thành tech-spec nghiệp vụ + edge case cho chi nhánh. researcher feeds `planner`; ba feeds `tech-lead`.
     - `planner` ↔ `pm` ↔ `tech-lead`: `planner` = đầu-não xuất **plan-as-data** điều phối vòng đời (meta, không quyết product feature, không code); `pm` = product scope chi nhánh (cái GÌ + ưu tiên, không chia task eng); `tech-lead` = chia task kỹ thuật nội bộ + review + quyết merge (làm THẾ NÀO tầng eng, không đặt ưu tiên product, không viết feature code).
     - (c) Bảng index 17 vai theo khối + cấu hình theo quy mô (nhỏ/web-full/mobile — copy từ agent-design, không sửa file vai nào).
  2. Tạo `catalog/researcher.md` theo template: Một việc = thu thập + tổng hợp hiểu biết TRƯỚC plan; Input = task + code/doc/memory + `{{key}}` node trước; Trả ra = bản tóm tắt hiểu biết + `open_questions[]` (cái không tự giải); Không làm = không lập kế hoạch (đó là planner), không hỏi user (đó là escalate-gate), không sinh tech-spec nghiệp vụ (đó là ba); Handoff = `planner` (+ `open_questions[]` → clarify-gate). Bám brain-model §A + §Tension.
  3. Tạo `catalog/planner.md` theo template: Một việc = biến mục tiêu + hiểu biết → plan-as-data, tái sinh khi verdict fail/clarify; Input = `{{research}}` + `{{verdict}}` (vòng re-plan) + memory; Trả ra = JSON plan (`goal/steps[]/done_criteria[]/open_questions[]`) — trỏ brain-model §Plan-as-data, mô tả không ép schema; Không làm = không thực thi (chỉ plan), không quyết product feature (pm), không chia task eng chi tiết (tech-lead); Handoff = builder/tester (qua steps) + back-edge re-plan. Bám prior-art `helpers/planner.md` ("plan only", read-order, không sửa plan cũ trừ khi yêu cầu).
- **STOP gate** (đo được):
  - [ ] `catalog/README.md` tồn tại, có đủ: template 5 mục + ma trận ranh giới (≥2 cặp researcher↔ba, planner↔pm↔tech-lead) + bảng index 17 vai.
  - [ ] `catalog/researcher.md` + `catalog/planner.md` tồn tại, mỗi file đúng 5 mục, mỗi mục không rỗng, mục "Không làm" ≥2 dòng tham chiếu vai bị đè.
  - [ ] Không có mâu thuẫn ranh giới: researcher "Không làm" nhắc planner+ba; planner "Không làm" nhắc pm+tech-lead (đối xứng với ma trận README).
- **Output artifact**: `catalog/README.md`, `catalog/researcher.md`, `catalog/planner.md`.

**Phase 1-A gate**: template 5 mục + ma trận ranh giới chốt; 2 vai đầu-não khó nhất xong làm mẫu — 15 vai còn lại chỉ điền template + tra ma trận.

---

## Phase 1-B — 15 vai còn lại (theo khối)

**Mục tiêu**: hiện thực 15 vai còn lại theo template A.1, mỗi vai bám prior-art Leafnote tương ứng (chỉ đọc) + tra ma trận ranh giới. Chia 3 session theo khối để mỗi session đủ nhỏ + ranh giới trong-khối kiểm cùng lúc.

> **Định nghĩa "done" mỗi vai (áp cho cả 3 session B):** file `catalog/<vai>.md` tồn tại, đúng 5 mục (Một việc / Input / Trả ra / Không làm / Handoff), mỗi mục không rỗng, "Trả ra" mô tả (không shape cứng), "Không làm" ≥1 dòng ranh giới rõ với vai gần kề. Vai nào có prior-art Leafnote → rút ý (đã dịch headless), ghi nguồn tham khảo 1 dòng cuối file.

### Session B.1 — Product (pm, ba) + Design (ux, ui)
- **Scope**:
  - `pm`: xác định tính năng + ưu tiên → user story. Prior-art `team-pm.md` (PRD 4 mục, acceptance criteria đo được, break task). Không làm: không chia task eng (tech-lead), không tự research codebase (researcher). Handoff: `ba`/`ux`.
  - `ba`: phân tích nghiệp vụ → tech-spec + edge case. Prior-art `team-pm.md` (spec phần). Không làm: không quyết ưu tiên product (pm), không gom hiểu biết HQ-level (researcher). Handoff: `tech-lead`/`db-architect`.
  - `ux`: user flow + hành vi tương tác. Prior-art `team-designer.md` (flow/state variants). Không làm: không chọn màu/spacing cụ thể (ui). Handoff: `ui`.
  - `ui`: layout + component visual (chỉ token có sẵn). Prior-art `team-designer.md` (design-system token, checklist). Không làm: không thiết kế flow (ux), không code (frontend-developer). Handoff: `frontend-developer`.
- **STOP gate**:
  - [ ] 4 file `catalog/{pm,ba,ux,ui}.md` tồn tại, mỗi file đúng 5 mục không rỗng.
  - [ ] Ranh giới trong khối rõ: pm↔ba (ưu tiên vs spec), ux↔ui (flow vs visual) — "Không làm" tham chiếu chéo đúng.
- **Output artifact**: `catalog/pm.md`, `catalog/ba.md`, `catalog/ux.md`, `catalog/ui.md`.

### Session B.2 — Engineering core (tech-lead, db-architect, api-developer, auth-engineer, frontend-developer, devops)
- **Scope**: 6 vai engineering, bám `agent-design §Engineering` (cột "Không làm" gốc đã rõ) + prior-art Leafnote.
  - `tech-lead`: chia task + review + quyết merge. Prior-art `team-tech-lead.md` (4-severity review, hot spots). Không làm: viết feature code; đặt ưu tiên product (pm).
  - `db-architect`: schema/migration/index. Prior-art `team-db-architect.md` (PK/FK/index/constraint, migration naming). Không làm: API, UI, auth.
  - `api-developer`: endpoint + handler nghiệp vụ. Prior-art `team-dev.md` (service-first BE). Không làm: schema (db-architect), auth (auth-engineer), UI.
  - `auth-engineer`: xác thực/phân quyền. Không làm: feature nghiệp vụ khác.
  - `frontend-developer`: component + nối API + style. Prior-art `team-dev.md` (service→hook→component, i18n). Không làm: server-side.
  - `devops`: CI/CD, deploy, env, monitoring. Không làm: feature code.
- **STOP gate**:
  - [ ] 6 file `catalog/{tech-lead,db-architect,api-developer,auth-engineer,frontend-developer,devops}.md` tồn tại, mỗi file đúng 5 mục không rỗng.
  - [ ] Ranh giới 3-vai-tách-từ-backend rõ: db-architect (schema) ↔ api-developer (endpoint) ↔ auth-engineer (auth) — không đè nhau (tra ma trận).
- **Output artifact**: 6 file `catalog/*.md` khối Engineering.

### Session B.3 — Mobile (ios, android, flutter) + QA (functional, regression)
- **Scope**:
  - `mobile-ios` / `mobile-android` / `mobile-flutter`: app native/cross-platform. Bám `agent-design §Engineering` (bật cho dự án mobile). Không làm: web frontend (frontend-developer), server-side. Ranh giới giữa 3: ios/android = native từng nền, flutter = cross-platform (chọn 1 trong 3 tuỳ dự án, không đồng thời).
  - `qa-functional`: chạy test case theo spec, báo bug reproduce được. Prior-art `team-qa.md` (5 phase browser test, bằng chứng cụ thể, "test bằng dùng app không đọc code"). Không làm: fix bug.
  - `qa-regression`: kiểm tính năng cũ không vỡ. Không làm: fix bug; test feature mới (qa-functional).
- **STOP gate**:
  - [ ] 5 file `catalog/{mobile-ios,mobile-android,mobile-flutter,qa-functional,qa-regression}.md` tồn tại, mỗi file đúng 5 mục không rỗng.
  - [ ] Ranh giới rõ: 3 mobile (native-từng-nền vs cross-platform, chọn-1); qa-functional↔qa-regression (feature mới vs hồi quy). → **17/17 vai xong.**
- **Output artifact**: 5 file `catalog/*.md` khối Mobile + QA.

**Phase 1-B gate**: 17/17 `catalog/<vai>.md` tồn tại; mỗi file đúng 5 mục không rỗng; mọi cặp dễ đè trong ma trận có "Không làm" tham chiếu chéo; vai có prior-art ghi nguồn.

---

## Phase 1-C — Lắp thử chi nhánh web tay + done-gate

**Mục tiêu**: chứng minh catalog **lắp ráp được** (không chỉ là 17 file rời) — đúng done-gate ROADMAP: "lắp thử 1 chi nhánh web tay từ catalog → validate pass".

### Session C.1 — examples/web-demo/ + done-gate
- **Scope**:
  1. Tạo `examples/web-demo/workflow.json`: pipeline web-full nối vai catalog theo `agent-design §web-full` (pm→ba→ux→ui→tech-lead→db-architect→api-developer→auth-engineer→frontend-developer→devops→qa-functional), `output_key` + `input` `{{key}}` đúng dependency. Dạng `pipeline` v1 (tương thích ngược) HOẶC graph nodes/edges — chốt đầu session (v1 đủ cho demo tuyến tính, ít rủi ro).
  2. Agent stub: `examples/web-demo/agents/*.md` echo cho từng vai dùng trong pipeline (stub demo — nội dung thật là việc CTO/P3; P1 chỉ chứng minh lắp + validate). HOẶC trỏ thẳng `catalog/*.md` nếu engine resolve được path — chốt đầu session theo cách engine load agent.
  3. `./run.ps1 validate web-demo` → exit 0 (mọi agent path tồn tại, mọi `{{key}}` resolve, schema hợp lệ).
  4. `./run.ps1 run web-demo "build a notes web app" -Mock` → status done (đi hết pipeline).
  5. (tuỳ) `./run.ps1 viz web-demo` đọc được.
  6. Verify done-gate checklist (Outcome cuối). Cập nhật `ROADMAP.md` bảng tiến độ (Phase 1 → ✅, cột Long-plan trỏ `plan/hq-build/phase-1/`) + `company/CLAUDE.md` bảng "Bản đồ file" (thêm `catalog/`, `plan/hq-build/phase-1/`, `examples/web-demo/`).
- **STOP gate** (đo được):
  - [ ] `examples/web-demo/workflow.json` + agent stub tồn tại, nối ≥10 vai catalog khối web-full.
  - [ ] `./run.ps1 validate web-demo` → exit 0.
  - [ ] `./run.ps1 run web-demo "..." -Mock` → status done.
  - [ ] Ma trận ranh giới `catalog/README.md` cover đủ cặp dễ đè (researcher↔ba, planner↔pm↔tech-lead, db↔api↔auth, ux↔ui, qa-func↔qa-reg).
  - [ ] Done-gate checklist (Outcome cuối) tick đủ; ROADMAP + CLAUDE.md cập nhật.
- **Output artifact**: `examples/web-demo/` (+ agents); ROADMAP + CLAUDE.md cập nhật.

**Phase 1-C gate** = Outcome cuối.

---

## Outcome cuối

- `catalog/` có **17 vai** (`researcher`, `planner`, `pm`, `ba`, `ux`, `ui`, `tech-lead`, `db-architect`, `api-developer`, `auth-engineer`, `frontend-developer`, `devops`, `mobile-ios`, `mobile-android`, `mobile-flutter`, `qa-functional`, `qa-regression`) + `README.md` (template 5 mục + ma trận ranh giới + index/cấu hình quy mô).
- `examples/web-demo/` — chi nhánh web lắp tay từ catalog, `validate` exit 0 + `run -Mock` done.
- **Done-gate (checklist đo được):**
  - [ ] 17/17 `catalog/<vai>.md` tồn tại, mỗi file đúng 5 mục (Một việc / Input / Trả ra / Không làm / Handoff) không rỗng.
  - [ ] "Trả ra" mô tả mức ý nghĩa, KHÔNG shape cứng (tuân C-2).
  - [ ] Ma trận ranh giới chống đè đủ các cặp: researcher↔ba, planner↔pm↔tech-lead, db-architect↔api-developer↔auth-engineer, ux↔ui, qa-functional↔qa-regression — mỗi cặp "Không làm" tham chiếu chéo.
  - [ ] `examples/web-demo/`: `validate` exit 0 + `run -Mock` done; nối ≥10 vai khối web-full.
  - [ ] ROADMAP bảng tiến độ Phase 1 → ✅; CLAUDE.md bản đồ file cập nhật (`catalog/`, `plan/hq-build/phase-1/`, `examples/web-demo/`).

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-05-27 | Initial | Tạo từ ROADMAP Phase 1 + brain-model §A/§Tension + agent-design §Catalog; chốt (user): MVP = full catalog incl mobile 17 vai; template 5 mục (Một việc/Input/Trả ra/Không làm/Handoff); demo = `examples/web-demo/` mới |
