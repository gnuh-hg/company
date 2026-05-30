# PLAN — Phase R: Nghiên cứu + thiết kế mô hình "đầu-não"

> Sau toàn bộ pipeline: có `plan/hq-build/phase-r/brain-model.md` — tài liệu mô hình đầu-não đã chốt (đủ vai + pattern + cơ chế + **draft JSON schema plan-as-data**), giải quyết căng thẳng "đầu-não động vs workflow cố định", làm khung cho Phase 0/1/3/M.

---

## Context

- **Vì sao chia nhiều session:** Phase R là research + synthesis, không phải code. Phải (1) khảo 6 file prior-art Leafnote, (2) tổng hợp thành mô hình, (3) giải tension + draft schema, (4) chốt ranh giới + done-gate. Mỗi bước cần đọc kỹ + suy nghĩ sâu → vượt 1 chat nếu làm ẩu.
- **Ràng buộc external:** prior-art nằm ở `../leafnote/.claude/` — **CHỈ ĐỌC, không sửa** (leafnote ngoài scope, quy ước bất biến #6). Không port nguyên cơ chế tương tác (⚠ dịch-không-port: Leafnote = agent tương tác/người-trong-vòng-lặp; HQ = headless + workflow-as-data/graph cố định).
- **Quyết định đã chốt (input cho R):**
  - Độ sâu R = **mô hình + schema nháp** plan-as-data (Phase 0/3 chỉ hiện thực, không thiết kế lại).
  - Output đặt tại `plan/hq-build/phase-r/brain-model.md` (theo convention plan-long: co-locate với PLAN/CHECKPOINT).
  - Cross-cutting C-1/C-2/C-3 đã chốt (xem ROADMAP) — R không lật lại, chỉ tham chiếu.
- **Out of scope:** hiện thực pattern (Phase 0), viết catalog vai .md (Phase 1), code agent HQ (Phase 3), code memory store (Phase M). R chỉ ra *mô hình + danh sách + schema*, không sinh artifact runtime.

---

## Pipeline 3 sub-phase / 5 session

```
[R-A] Khảo prior art ───────────► brain-model.md §"Prior-art extraction" (6 ref → 6 phần đầu-não)
                                       │
[R-B] Tổng hợp mô hình ─────────► brain-model.md §"Mô hình đầu-não" (vai + pattern + cơ chế + cross-ref phase)
                                       │
[R-C] Plan-as-data + chốt ──────► brain-model.md §"Plan-as-data schema" + §"Ranh giới & dừng re-plan" + done-gate
                                       │
                                   Phase R done — ROADMAP cập nhật
```

Vòng đời đầu-não cần mô hình hoá: `research → plan(dài→ngắn) → orchestrate(làm/kiểm) → re-plan khi mơ hồ/fail → escalate khi bí → ghi nhớ kết cục`.

---

## Phase R-A — Khảo prior art Leafnote (read-only)

**Mục tiêu**: rút từ 6 file tham khảo *cái GÌ đáng giữ*, rồi *dịch sang CÁCH headless* (routing động → router node; hỏi người → escalate-gate; classify → router). Mỗi ref map về 1 phần của vòng đời đầu-não.

### Session A.1 — Cụm plan (4 file)
- **Scope**: đọc + trích 4 file, map mỗi file về phần đầu-não tương ứng:
  - `../leafnote/.claude/skills/plan-long/SKILL.md` → plan-as-data + `plan-decompose` + vai `planner`.
  - `../leafnote/.claude/skills/plan-short/SKILL.md` → plan dài→ngắn.
  - `../leafnote/.claude/workflows/plan.md` → COO phân loại short/long + Planner (routing).
  - `../leafnote/.claude/agents/helpers/planner.md` → template vai `planner` (classify + sinh PLAN/CHECKPOINT).
- **STOP gate**: `brain-model.md` tồn tại + có §"Prior-art extraction" với **4 mục** (1 mục/file), mỗi mục đủ 3 dòng: `Tham khảo CÁI GÌ` / `Dịch sang CÁCH (router/loop/escalate/...)` / `Map về phần đầu-não nào`.
- **Output artifact**: `plan/hq-build/phase-r/brain-model.md` (mới) — §"Prior-art extraction" với 4/6 mục.

### Session A.2 — Cụm orchestrate + memory (2 nguồn)
- **Scope**: đọc + trích 2 nguồn còn lại:
  - `../leafnote/.claude/workflows/master.md` → cách HQ điều phối (entry + post-task checklist) → orchestrate.
  - `../leafnote/.claude/memory/` (`context.md` / `mistakes.md` / `patterns.md` / `global.md`) → cấu trúc kho trí nhớ (khung Phase M) → ghi nhớ kết cục.
- **STOP gate**: §"Prior-art extraction" đủ **6/6 mục**, mỗi mục đủ 3 dòng như A.1; mục memory liệt kê được các loại file memory + ai-đọc/ai-ghi (sơ bộ).
- **Output artifact**: `brain-model.md` §"Prior-art extraction" hoàn chỉnh 6 mục.

**Phase R-A gate**: 6/6 ref đã trích + dịch sang cách headless; không còn ref nào "port nguyên" (mỗi mục phải có dòng `Dịch sang CÁCH`).

---

## Phase R-B — Tổng hợp mô hình đầu-não

**Mục tiêu**: từ extraction → danh sách chốt *vai + pattern + cơ chế* cần có, cross-ref sang phase sẽ hiện thực.

### Session B.1 — Liệt kê vai + pattern + cơ chế
- **Scope**: viết §"Mô hình đầu-não" gồm:
  - **Vai** (đầu-não): `researcher`, `planner` — định nghĩa "một việc" + "Trả ra" mức mô tả (không shape cứng — C-2). Cross-ref Phase 1.
  - **6 pattern** robustness map vào vòng đời: `research-gather`, `clarify-gate`, `plan-decompose`, `re-plan-loop`, `do-verify-loop`, `escalate-gate` — mỗi pattern: vai trò + nhãn router dự kiến + thuộc phần nào của vòng đời. Cross-ref Phase 0.
  - **Cơ chế**: memory (đọc/ghi), bridge nạp context, `max_steps` cầu dao. Cross-ref Phase M.
- **STOP gate**: §"Mô hình đầu-não" liệt kê **đủ 2 vai + 6 pattern + ≥3 cơ chế**, mỗi mục có 1 dòng cross-ref phase đích (P0/P1/PM). Vòng đời 6 bước được vẽ thành sơ đồ node/edge sơ bộ.
- **Output artifact**: `brain-model.md` §"Mô hình đầu-não".

**Phase R-B gate**: danh sách vai/pattern/cơ chế phủ kín cả 6 bước vòng đời; không bước nào thiếu pattern tương ứng.

---

## Phase R-C — Plan-as-data + ranh giới + done-gate

**Mục tiêu**: giải tension cốt lõi (đầu-não động vs graph cố định) bằng plan-as-data; draft schema; chốt ranh giới + tiêu chí dừng.

### Session C.1 — Giải tension + draft schema plan-as-data
- **Scope**:
  - Viết §"Tension & lời giải": vì sao KHÔNG để agent bẻ lái động; re-plan = **cạnh loop về node `planner`** (graph vẫn cố định, chỉ data plan đổi).
  - Draft §"Plan-as-data schema": JSON schema planner *xuất* (vd `{ goal, steps[], done_criteria, open_questions[] }` — chốt field thật trong session) + 1 ví dụ + mô tả re-plan loop dùng schema này thế nào (planner đọc verdict fail/clarify → sinh plan mới).
  - Kiểm tính khả thi: schema + re-plan loop phải diễn đạt được bằng engine v2 (router + cycle + `max_steps`) — đối chiếu `engine/workflow.ps1` semantics, KHÔNG đòi tính năng engine mới.
- **STOP gate**: §"Plan-as-data schema" có **block JSON schema + ≥1 ví dụ instance + mô tả re-plan loop**; có 1 đoạn xác nhận "diễn đạt được bằng router+cycle+max_steps hiện có, không cần sửa engine" (hoặc nêu rõ engine-gap nếu có).
- **Output artifact**: `brain-model.md` §"Tension & lời giải" + §"Plan-as-data schema".

### Session C.2 — Ranh giới + consolidate + done-gate
- **Scope**:
  - Viết §"Ranh giới & dừng re-plan": phân định **research vs clarify** (research = tự tìm hiểu; clarify = hỏi user qua escalate-gate); tiêu chí **"đủ rõ để ngừng re-plan"** dạng đo được (vd "open_questions[] rỗng" + "done_criteria[] đều có cách verify" + "đã quay re-plan < max").
  - Consolidate: đọc lại toàn `brain-model.md`, thêm §"Tóm tắt cho phase sau" (bảng: Phase 0 cần gì / Phase 1 cần gì / Phase 3 / Phase M).
  - Verify done-gate checklist của Phase R (xem "Outcome cuối").
  - Cập nhật ROADMAP bảng tiến độ: Phase R → ✅, cột Long-plan trỏ `plan/hq-build/phase-r/`.
- **STOP gate**: done-gate checklist **tất cả tick**; §"Tóm tắt cho phase sau" có ≥4 dòng (P0/P1/P3/PM); ROADMAP progress table đã cập nhật.
- **Output artifact**: `brain-model.md` hoàn chỉnh + ROADMAP cập nhật.

**Phase R-C gate** = Outcome cuối.

---

## Outcome cuối

- `plan/hq-build/phase-r/brain-model.md` chốt, gồm 5 section: Prior-art extraction (6 ref) · Mô hình đầu-não (vai+pattern+cơ chế) · Tension & lời giải · Plan-as-data schema (draft + ví dụ) · Ranh giới & dừng re-plan · Tóm tắt cho phase sau.
- **Done-gate (checklist đo được):**
  - [ ] 6/6 ref Leafnote đã trích + dịch sang cách headless (không port nguyên).
  - [ ] Đủ 2 vai + 6 pattern + ≥3 cơ chế, mỗi mục cross-ref phase đích.
  - [ ] Tension đầu-não-vs-graph giải bằng plan-as-data (re-plan = loop edge về planner, không bẻ lái động).
  - [ ] JSON schema plan-as-data có ví dụ + xác nhận diễn đạt được bằng engine v2 (hoặc nêu gap).
  - [ ] Ranh giới research/clarify rõ + tiêu chí "đủ rõ để ngừng re-plan" đo được.
  - [ ] §"Tóm tắt cho phase sau" đủ P0/P1/P3/PM; ROADMAP table cập nhật Phase R ✅.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-05-26 | Initial | Tạo từ ROADMAP Phase R; chốt độ sâu = mô hình+schema nháp, output `plan/hq-build/phase-r/brain-model.md` |
