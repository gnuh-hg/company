# CHECKPOINT — Phase R: mô hình đầu-não

> Sổ tay tiến độ. Bất kỳ phiên Claude mới nào cũng đọc file này TRƯỚC để biết đang ở đâu.

---

## ⚠️ Constraint reminder (ĐỌC ĐẦU MỖI CHAT)

- Mỗi chat **chỉ làm 1 session** (xem "Đang ở đâu").
- **STOP NGAY** khi đạt STOP gate session đó — không tham làm session kế dù còn quota.
- Prior-art Leafnote (`../leafnote/.claude/`) **CHỈ ĐỌC, KHÔNG SỬA** (quy ước bất biến #6).
- **Không port nguyên cơ chế tương tác** — mỗi extraction phải có dòng `Dịch sang CÁCH headless` (router/loop/escalate).
- **TRƯỚC khi đóng chat**: cập nhật bảng tiến độ + "Đang ở đâu" + thêm 1 entry "Per-session log".

---

## Tiến độ tổng quan

| Hạng mục | Mục tiêu | Hiện tại | % |
| --- | --- | --- | --- |
| Sessions hoàn thành | 5 | 5 | 100% |
| Prior-art ref đã trích | 6 | 6 | 100% |
| Section brain-model.md | 6 | 6 | 100% |
| Done-gate tick | 6 | 6 | 100% |

---

## Đang ở đâu

- **Phase**: ✅ **PHASE R HOÀN THÀNH** (C.2 đã đóng — toàn bộ 6 section brain-model.md chốt, done-gate 6/6 tick, ROADMAP cập nhật Phase R → ✅)
- **Session kế tiếp**: — (không còn session trong Phase R). Bước tiếp theo của HQ build: dựng long-plan cho **Phase 0 (Pattern robustness)** / **Phase 1 (Catalog)** / **PM (Memory)** — đều có thể bắt đầu sau R (xem `ROADMAP.md` §Thứ tự phụ thuộc). Bám `brain-model.md` §Tóm tắt cho phase sau.
- **Blocker**: —
- **Reference**: `brain-model.md` (deliverable chốt) + `ROADMAP.md` §Các phase

---

## Per-session log

### 2026-05-26 — Session A.1
- **Done**: Đọc 4 file cụm plan của Leafnote (plan-long, plan-short, plan.md, planner.md); trích + dịch sang cách headless; tạo `brain-model.md` với khung 6 section + §Prior-art extraction (4 mục).
- **Output**: `plan/hq-build/phase-r/brain-model.md` (mới) — §Prior-art extraction 4/6 mục, mỗi mục đủ 3 dòng (CÁI GÌ / Dịch sang CÁCH headless / Map về phần đầu-não).
- **Gate**: pass — file tồn tại, 4 mục, mỗi mục có dòng `Dịch sang CÁCH headless` (router/loop/escalate/plan-as-data), không port nguyên.
- **Next**: Session A.2 — bổ sung 2 mục còn lại (master.md → orchestrate; memory/ → ghi nhớ kết cục) lên đủ 6/6.
- **Notes**: Mapping chốt — plan-long→plan-as-data+state; plan-short→plan dài→ngắn cùng schema; plan.md→router classify + clarify-gate; planner.md→vai `planner` + đầu mối re-plan-loop. Các điểm "port nguyên cần tránh": "1 chat=1 session", "inline trong response", "hỏi user clarify mặc định".

### 2026-05-26 — Session A.2
- **Done**: Đọc 2 nguồn còn lại (`master.md` + `memory/` 4 file); trích + dịch sang cách headless; bổ sung §Prior-art extraction lên đủ 6/6 mục.
- **Output**: `brain-model.md` §Prior-art extraction mục 5 (master.md→orchestrate) + mục 6 (memory/→ghi nhớ kết cục), mỗi mục đủ 3 dòng; mục 6 liệt kê 4 loại file memory + ai-đọc (mọi task ở BƯỚC 0) / ai-ghi (post-task checklist).
- **Gate**: pass — 6/6 mục, mỗi mục có dòng `Dịch sang CÁCH headless`; không port nguyên (đã loại spawn-team/@, "đọc thủ công", checklist tay → bridge + node + router). Phase R-A gate đạt.
- **Next**: Session B.1 — tổng hợp §"Mô hình đầu-não" (vai + pattern + cơ chế + sơ đồ vòng đời).
- **Notes**: master.md→orchestrate (entry + routing theo nhãn + post-task→memory); memory/→khung store Phase M (4 loại: context/mistakes/patterns/global, đọc-nhiều ghi-cuối). "Port nguyên cần tránh" thêm: spawn team qua `@`, "đọc file TRƯỚC TIÊN" thủ công, checklist người tick tay.

---

### 2026-05-26 — Session B.1
- **Done**: Tổng hợp §"Mô hình đầu-não" từ 6 mục extraction — chốt 2 vai + 6 pattern + 3 cơ chế nền + sơ đồ vòng đời node/edge 6 bước.
- **Output**: `brain-model.md` §"Mô hình đầu-não" gồm: (A) bảng 2 vai `researcher`/`planner` (một-việc + trả-ra mô tả, cross-ref P1/P3); (B) bảng 6 pattern (research-gather/clarify-gate/plan-decompose/re-plan-loop/do-verify-loop/escalate-gate — vai trò + nhãn router + bước vòng đời + →P0); (C) bảng 3 cơ chế (memory/bridge/max_steps →PM/P0); (D) sơ đồ ASCII node/edge map 6 bước vòng đời.
- **Gate**: pass — đủ 2 vai + 6 pattern + ≥3 cơ chế, mỗi mục có dòng/cột cross-ref phase đích; sơ đồ vòng đời 6 bước. Phase R-B gate đạt: 6 bước vòng đời (research/plan/orchestrate/re-plan/escalate/clarify) đều có pattern phủ.
- **Next**: Session C.1 — §"Tension & lời giải" + §"Plan-as-data schema" (draft JSON + ví dụ + đối chiếu engine v2).
- **Notes**: Sơ đồ bám schema engine v2 (nodes+edges+when, đối chiếu `examples/loopy/workflow.json`); shape "Trả ra" để mô tả (C-2, engine không validate output). Field plan-as-data (`goal/steps/done_criteria/open_questions`) mới là nháp — chốt thật ở C.1.

### 2026-05-26 — Session C.1
- **Done**: Viết §"Tension & lời giải" (cố định topology / cho đổi data; re-plan = back-edge cố định về `planner`, không bẻ lái động; bằng chứng `loopy` cùng shape) + §"Plan-as-data schema" (block JSON 6 field đã chốt + bảng vai-trò field + ví dụ instance revision 0 + mô tả re-plan loop 6 bước + bảng xác nhận engine v2).
- **Output**: `brain-model.md` §Tension (đối chiếu `loopy/workflow.json` + `workflow.ps1:303-305`) + §Plan-as-data schema. Field chốt: `goal/revision/prev_verdict/steps[]/done_criteria[]/open_questions[]`.
- **Gate**: pass — có block JSON schema + ví dụ instance + mô tả re-plan loop; bảng xác nhận "diễn đạt được bằng router+cycle+max_steps, không sửa engine" (mỗi dòng trỏ bằng chứng workflow.ps1/loopy). Engine-gap (max_steps throw cứng không route mềm) đã nêu + giải bằng `revision` counter trong data → không phải gap thật.
- **Next**: Session C.2 — §Ranh giới & dừng re-plan + §Tóm tắt cho phase sau + done-gate + cập nhật ROADMAP.
- **Notes**: Quyết định chốt — escalate mềm KHÔNG dựa vào engine đếm; `revision` field mang bộ đếm trong DATA để `verdict` router đọc `{{plan}}.revision ≥ N` → in `escalate`. `max_steps` chỉ là backstop. `done_criteria[].verify` (cách kiểm đo được) là đầu vào do-verify-loop — nối thẳng tiêu chí dừng re-plan của C.2.

### 2026-05-26 — Session C.2 (cuối Phase R)
- **Done**: Viết §"Ranh giới & dừng re-plan" (bảng research vs clarify + 3 tiêu chí dừng đo được từ `{{plan}}`: `open_questions[]` rỗng / mọi `done_criteria[].verify` có / `revision < max`; phân biệt dừng-thành-công vs dừng-bí) + §"Tóm tắt cho phase sau" (bảng 4 dòng P0/P1/P3/PM: lấy-gì/hiện-thực/bám-section + đoạn bất biến xuyên phase). Verify done-gate 6/6. Cập nhật ROADMAP Phase R → ✅.
- **Output**: `brain-model.md` hoàn chỉnh 6 section (2 section cuối điền xong); `ROADMAP.md` progress table Phase R = ✅.
- **Gate**: pass — done-gate checklist 6/6 tick (xem PLAN §Outcome cuối); §Tóm tắt ≥4 dòng (P0/P1/P3/PM đủ); ROADMAP cập nhật. **Phase R-C gate = Outcome cuối đạt → Phase R đóng.**
- **Next**: Hết session Phase R. HQ build tiếp ở Phase 0/1/PM (độc lập sau R).
- **Notes**: Chốt cuối — research-trước-clarify-sau (vét nguồn tự giải trước, chỉ escalate cái user-mới-biết); "đủ rõ" tách 2 nghĩa: (1)+(2) = đủ rõ để CHẠY, (3) = hết kiên nhẫn re-plan. Escalate mềm dựa `revision` trong DATA, `max_steps` chỉ backstop. Mọi tiêu chí dừng đọc thẳng từ plan-as-data → router quyết, không phán cảm tính. Bất biến xuyên phase: topology cố định + plan-as-data convention + engine v2 đủ (không engine mới).

## Lịch sử revision

| Date | Action | By |
| --- | --- | --- |
| 2026-05-26 | Created from `PLAN.md` | planner |
| 2026-05-26 | Session A.1 done — brain-model.md + 4/6 extraction | claude |
| 2026-05-26 | Session A.2 done — extraction 6/6, Phase R-A đóng | claude |
| 2026-05-26 | Session B.1 done — §Mô hình đầu-não (2 vai + 6 pattern + 3 cơ chế + sơ đồ), Phase R-B đóng | claude |
| 2026-05-26 | Session C.1 done — §Tension & lời giải + §Plan-as-data schema (JSON + ví dụ + xác nhận engine v2) | claude |
| 2026-05-26 | Session C.2 done — §Ranh giới & dừng re-plan + §Tóm tắt cho phase sau; done-gate 6/6; **Phase R đóng** | claude |
