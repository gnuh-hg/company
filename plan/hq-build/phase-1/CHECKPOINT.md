# CHECKPOINT — Phase 1: Catalog vai chi nhánh

> Sổ tay tiến độ dài hạn. Bất kỳ phiên Claude nào mới mở đều đọc file này TRƯỚC để biết đang ở đâu.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ được làm 1 session** (xem mục "Đang ở đâu" để biết session nào).
- **STOP NGAY** khi đạt STOP gate của session đó — không tham làm session kế tiếp dù còn quota.
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry vào "Per-session log".
- **Quy ước bất biến #6**: chỉ thao tác trong `company/`. Prior-art `leafnote/` **CHỈ ĐỌC**, không sửa.
- **C-2**: "Trả ra" mỗi vai chỉ mô tả mức ý nghĩa — KHÔNG viết shape/schema cứng (engine không validate output agent).
- **Quy ước #1**: vai `.md` = system prompt + ranh giới, KHÔNG chứa logic workflow (edge/router là việc P3/P4).

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 5 | 5 | 100% ✅ |
| Vai catalog đúc xong | 17 | 17 | 100% ✅ |
| Ma trận ranh giới | đủ 5 cặp | 9 cặp (đủ 5 cặp bắt buộc) ✅ | 100% |
| examples/web-demo validate+run | pass | validate exit 0 + run -Mock done (11 vai) ✅ | 100% |

---

## Đang ở đâu

- **Phase**: 1-C — ✅ **DONE** (= Phase 1 done-gate đạt đủ)
- **Session kế tiếp**: — (Phase 1 hoàn tất. Phase kế = Phase 2 Tester/sandbox HOẶC Phase M memory — chờ user trỏ phase + soạn long-plan mới)
- **Blocker**: —
- **Reference**: `plan/hq-build/ROADMAP.md` (Phase 2 / M / 3 chưa có long-plan)

---

## Quyết định đã chốt (user 2026-05-27)

- **MVP scope**: full catalog incl mobile = **17 vai** (researcher, planner, pm, ba, ux, ui, tech-lead, db-architect, api-developer, auth-engineer, frontend-developer, devops, mobile-ios, mobile-android, mobile-flutter, qa-functional, qa-regression).
- **Template 5 mục**: Một việc / Input / Trả ra / Không làm / Handoff (~6–10 dòng/vai).
- **Demo lắp tay**: `examples/web-demo/` mới (không đụng demo cũ).

---

## Per-session log

### A.1 — 2026-05-27 — Foundation (template + ma trận + 2 vai đầu-não) ✅
- **Làm**: Tạo `catalog/README.md` (template 5 mục + ma trận ranh giới 9 cặp + index 17 vai + cấu hình quy mô) + `catalog/researcher.md` + `catalog/planner.md`.
- **STOP gate**: README đủ template + ma trận (5 cặp bắt buộc + 4 cặp thêm) + index 17 vai ✅; 2 vai đầu-não đúng 5 mục, "Không làm" ≥2 dòng ✅; boundary symmetry: researcher↔(planner,ba), planner↔(pm,tech-lead) khớp ma trận ✅.
- **Nguồn**: brain-model §A/§Tension/§Plan-as-data; prior-art `helpers/planner.md` + `workflows/plan.md`.
- **Note B.1**: 15 vai còn lại chỉ điền template + tra ma trận README. Bắt đầu khối Product+Design.

### B.1 — 2026-05-27 — Product (pm, ba) + Design (ux, ui) ✅
- **Làm**: Tạo `catalog/{pm,ba,ux,ui}.md` theo template 5 mục, bám prior-art `team-pm.md` (pm/ba) + `team-designer.md` (ux/ui), dịch headless (không spawn/TaskCreate).
- **STOP gate**: 4 file tồn tại, mỗi file đúng 5 mục không rỗng ✅; ranh giới chéo khớp ma trận README: pm↔ba (ưu tiên vs spec), ux↔ui (flow vs visual) ✅; mỗi file có dòng nguồn prior-art ✅.
- **Note B.2**: còn 11 vai. Tiếp Engineering core 6 vai — chú ý tách db-architect↔api-developer↔auth-engineer (tra ma trận README cặp 3-vai-backend).

### B.2 — 2026-05-27 — Engineering core (tech-lead, db-architect, api-developer, auth-engineer, frontend-developer, devops) ✅
- **Làm**: Tạo `catalog/{tech-lead,db-architect,api-developer,auth-engineer,frontend-developer,devops}.md` theo template 5 mục. Bám prior-art `team-tech-lead.md` (tech-lead/auth security), `team-db-architect.md` (db/devops migration), `team-dev.md` (api/frontend service-first). Dependency `{{key}}` khớp agent-design §web-full (db←spec, api←spec+schema, auth←api, fe←design+api, devops←api+fe).
- **STOP gate**: 6 file tồn tại, mỗi file đúng 5 mục không rỗng ✅; ranh giới 3-vai-backend rõ + đối xứng — db-architect↔api-developer↔auth-engineer mỗi "Không làm" tham chiếu chéo 2 vai còn lại (schema≠endpoint≠auth) khớp ma trận README ✅; mỗi file có dòng nguồn prior-art ✅.
- **Note B.3**: còn 5 vai (Mobile 3 + QA 2) → 17/17. Mobile: ranh giới chọn-1 (native vs cross-platform), không đụng web/server. QA: func (feature mới) vs reg (hồi quy), cả hai không fix bug.

---

### B.3 — 2026-05-27 — Mobile (mobile-ios, mobile-android, mobile-flutter) + QA (qa-functional, qa-regression) ✅
- **Làm**: Tạo `catalog/{mobile-ios,mobile-android,mobile-flutter,qa-functional,qa-regression}.md` theo template 5 mục. Mobile bám prior-art `team-dev.md` (service→state→component, không hardcode style); QA bám `team-qa.md` (5-phase, "test bằng dùng app không đọc code", mỗi assertion có bằng chứng console/network/screenshot). Dependency `{{key}}` khớp agent-design §Engineering/§QA (mobile←ux/ui+api; qa←spec/ba+artifact).
- **STOP gate**: 5 file tồn tại, mỗi file đúng 5 mục không rỗng ✅; ranh giới rõ + đối xứng — 3 mobile mỗi "Không làm" tham chiếu 2 vai mobile còn lại + chọn-1, không đụng web/server; qa-functional↔qa-regression tham chiếu chéo (feature mới vs hồi quy), cả hai không fix bug — khớp ma trận README ✅; mỗi file có dòng nguồn prior-art ✅. → **17/17 vai xong.**
- **Note C.1**: 17 vai đủ. Tiếp Phase 1-C: lắp `examples/web-demo/` (pipeline web-full nối ≥10 vai + agent stub) → validate exit 0 + run -Mock done; chốt đầu session: pipeline v1 hay graph, agent stub echo hay trỏ catalog path (theo cách engine load agent). Cập nhật ROADMAP + CLAUDE.md.

### C.1 — 2026-05-27 — Lắp thử chi nhánh web tay `examples/web-demo/` + done-gate ✅
- **Làm**: Tạo `examples/web-demo/workflow.json` (pipeline v1 — chốt đầu session: tuyến tính, ít rủi ro nhất) nối 11 vai web-full pm→ba→ux→ui→tech-lead→db-architect→api-developer→auth-engineer→frontend-developer→devops→qa-functional, `{{key}}` dependency bám agent-design §web-full. Agent stub echo `agents/*.md` (11 file — chốt đầu session: echo stub thay vì trỏ catalog path, đồng nhất với `examples/hello`; nội dung thật là việc CTO/P3). Cập nhật ROADMAP (Phase 1 → ✅) + `company/CLAUDE.md` bản đồ file (thêm `catalog/`, `examples/web-demo/`, đánh dấu phase-1 DONE).
- **STOP gate**: `workflow.json` + 11 agent stub tồn tại, nối 11 vai (≥10) ✅; `./run.ps1 validate web-demo` → exit 0 ✅; `./run.ps1 run web-demo "build a notes web app" -Mock` → done, 11 lượt thăm trọn path ✅; ma trận ranh giới `catalog/README.md` cover đủ 5 cặp bắt buộc (researcher↔ba, planner↔pm↔tech-lead, db↔api↔auth, ux↔ui, qa-func↔qa-reg) ✅; ROADMAP + CLAUDE.md cập nhật ✅. `.runs/` test đã dọn. → **Phase 1 done-gate đạt đủ.**
- **Nguồn**: agent-design §web-full (pipeline 10-step mẫu, mở thêm tech-lead = 11); engine loader `examples/hello` (pipeline v1 + agent path tương đối).

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-27 | Created from `PLAN.md` | @planner |
| 2026-05-27 | Session A.1 done — README + researcher + planner | Claude |
| 2026-05-27 | Session B.1 done — pm + ba + ux + ui | Claude |
| 2026-05-27 | Session B.2 done — tech-lead + db-architect + api-developer + auth-engineer + frontend-developer + devops | Claude |
| 2026-05-27 | Session B.3 done — mobile-ios + mobile-android + mobile-flutter + qa-functional + qa-regression → 17/17 vai | Claude |
| 2026-05-27 | Session C.1 done — examples/web-demo (11 vai, validate exit 0 + run -Mock done) + ROADMAP/CLAUDE.md → **Phase 1 DONE** | Claude |
