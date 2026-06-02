# design.md — Phase H: HQ team-of-agents native (CD-1)

> Spec kiến trúc khoá cho toàn Phase H. Mỗi session H.1–H.10 đọc file này để biết "đang xây gì, tại sao, và đặt ở đâu". Không thay đổi mà không có revision log.

> **⚠️ REVISE 2026-06-02 (reframe Q2):** bản H.0 đầu chốt "builder ghi file QUA engine `autobuild`/`autofix` (sandbox→promote)" + "planner xuất plan-as-data JSON" + "CTO xuất build-spec JSON cho `run.ps1 build`". User chỉ ra đây là **lậm form workflow cũ** — teammate là agent đọc/viết văn xuôi, KHÔNG có engine nào parse JSON đó. **Quyết mới (user chốt):** HQ team **build deliverable TRỰC TIẾP** (builder Write/Edit), giao tiếp giữa teammate bằng **văn xuôi tự nhiên**, KHÔNG build-spec / workflow.json / engine-build trong luồng HQ. Engine (`run.ps1` + app) là **tool đứng riêng** cho workflow-chi-nhánh, HQ không bắt buộc đi qua. Legacy `hq/` đã **XÓA** (xem §8). Các mục dưới đã viết lại theo quyết định này.

---

## 1. Sơ đồ orchestration — flow ĐỘNG (không DAG)

**Lead** là Claude Code session chính (model: claude-opus-4-8 hoặc sonnet tùy ngữ cảnh). Lead điều phối bằng reasoning trực tiếp + TeamCreate. KHÔNG có `workflow.json` HQ.

### Khi nào lead spawn team vs tự làm

| Tình huống | Lead làm gì |
|---|---|
| Request mới cần xây thật, multi-file / domain mới | Spawn team: researcher → planner → cto → builder → tester |
| Request đơn giản (clarification, status check) | Lead tự xử, không spawn |
| Sửa deliverable đã có | Spawn builder + tester (bỏ researcher/planner/cto) |
| Cần thêm 1 teammate bất kỳ | TeamCreate với danh sách tối thiểu cần thiết |

**Size team thực tế**: 3–5 teammate. Không spawn nếu lead tự làm được trong 1–2 tool call.

### Flow điển hình: build request mới

```
LEAD nhận user_request
  └─► LEAD phân loại (đơn giản hay cần team?)
        ├── phức tạp / multi-file / domain mới
        │     └─► TeamCreate [researcher, planner, cto, builder, tester]
        │           │
        │           ├─► researcher: "gom context về request + memory"
        │           │     └─► trả tóm tắt + câu hỏi còn chặn (VĂN XUÔI)
        │           │
        │           ├─► LEAD xét câu hỏi còn chặn:
        │           │     ├── còn câu chặn → LEAD hỏi user trực tiếp (clarify động)
        │           │     └── đủ rõ → tiếp
        │           │
        │           ├─► planner: "lập kế hoạch WHAT từ research"
        │           │     └─► trả plan markdown (Goal/Steps/Done-criteria) — KHÔNG JSON
        │           │
        │           ├─► cto: "thiết kế HOW từ plan"
        │           │     └─► trả thiết kế kỹ thuật VĂN XUÔI (cấu trúc file, cách tiếp cận,
        │           │          công nghệ; tham khảo catalog/ nếu hữu ích) — KHÔNG build-spec JSON
        │           │
        │           ├─► builder: "build deliverable theo thiết kế"
        │           │     └─► Write/Edit file TRỰC TIẾP vào projects/<name>/ + Bash chạy build/cài
        │           │          (KHÔNG qua run.ps1 autobuild; KHÔNG workflow.json)
        │           │
        │           ├─► tester: "kiểm deliverable vừa build"
        │           │     └─► chạy CHECK KHÁCH QUAN của chính deliverable (test suite / build /
        │           │          lint / quan sát hành vi) → lấy exit-code/kết quả
        │           │          ├── pass → ghi memory + báo LEAD
        │           │          └── fail → báo LEAD kèm lý do cụ thể (output lệnh, dòng lỗi)
        │           │
        │           ├─► LEAD xét verdict:
        │           │     ├── pass → record memory + shutdown team + báo user
        │           │     ├── fail (builder sửa được) → builder re-fix
        │           │     └── fail (structural) → planner re-plan → loop
        │           │
        │           └─► LEAD shutdown team khi done
        │
        └── đơn giản → LEAD tự trả lời user
```

**Các gate/route cũ tan vào lead reasoning:**

| Gate cũ (workflow.json) | Thay bằng gì trong lead |
|---|---|
| `coo` (router build/fix/unclear) | Lead phân loại bằng reasoning |
| `rg_gate` (đủ research chưa) | Lead xét câu-hỏi-còn-chặn từ researcher |
| `clarify_gate` (hỏi user) | Lead hỏi user trực tiếp (native) |
| `escalate_gate` / `escalate_report` | Lead quyết escalate sau N vòng fail |
| `record` (node ghi memory) | Lead gọi skill `hq-memory` sau verify done |

---

## 2. Roster teammate

### 5 teammate def — `company/.claude/agents/hq-*.md`

| Teammate file | Tools | Model | Vai trò |
|---|---|---|---|
| `hq-researcher.md` | Read, Grep, Glob, WebSearch | claude-sonnet-4-6 | Gom context request + memory → tóm tắt + câu hỏi còn chặn (VĂN XUÔI) |
| `hq-planner.md` | Read | claude-sonnet-4-6 | WHAT — kế hoạch markdown (Goal/Steps/Done-criteria), KHÔNG JSON |
| `hq-cto.md` | Read | claude-sonnet-4-6 | HOW — thiết kế kỹ thuật VĂN XUÔI; tham khảo `catalog/` tùy chọn; KHÔNG build-spec |
| `hq-builder.md` | Read, **Write, Edit, Bash** | claude-sonnet-4-6 | Ghi file deliverable TRỰC TIẾP vào `projects/<name>/`; Bash chạy build/test; KHÔNG run.ps1 autobuild |
| `hq-tester.md` | Read, Bash | claude-sonnet-4-6 | Chạy check KHÁCH QUAN của deliverable (test/build/lint exit-code) + báo verdict; ghi memory |

**Convention tên**: tiền tố `hq-` để tránh nhầm với agent META `.claude/agents/planner.md` (soạn PLAN/CHECKPOINT cho các phase). Hai agent cùng tên `planner` sẽ gây nhầm lẫn nghiêm trọng.

**Nguyên tắc xuyên suốt 5 teammate (chống lậm form cũ):**
- Giao tiếp giữa teammate = **văn xuôi markdown tự nhiên** cho người/agent đọc. KHÔNG JSON schema, KHÔNG "plan-as-data", KHÔNG build-spec, KHÔNG ép field cứng.
- Chỉ builder có quyền ghi file (Write/Edit). researcher/planner/cto/tester read-only (tester thêm Bash để CHẠY check, không sửa file).
- Quality-gate = **kết quả khách quan của chính deliverable** (test/build/lint), không để LLM phán cảm tính.

### 6 thành phần KHÔNG thành teammate + lý do

| Thành phần cũ | Lý do KHÔNG tạo teammate |
|---|---|
| `coo` (router) | Phân loại đơn giản — lead reasoning làm tốt hơn, không cần overhead spawn. |
| `rg_gate` (router) | Chỉ xét câu-hỏi-còn-chặn của researcher — lead tự làm trivially. |
| `clarify_gate` | Lead hỏi user native. |
| `escalate_gate` | Lead tự đếm vòng fail và quyết escalate. |
| `escalate_report` | Lead tự báo cáo user khi escalate. |
| `record` (node ghi memory) | Thay bằng skill `hq-memory` — lead gọi sau verify. |

---

## 3. Bố cục `.claude/` đích

```
company/.claude/
├── settings.json                    # flag CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 (H.1)
├── settings.local.json              # giữ nguyên
├── agents/
│   ├── planner.md                   # META planner — GIỮ NGUYÊN, không đụng
│   ├── hq-researcher.md             # H.2 (đã soạn lại form prose 2026-06-02)
│   ├── hq-planner.md                # H.3 (đã soạn lại form prose 2026-06-02)
│   ├── hq-cto.md                    # H.4
│   ├── hq-builder.md                # H.5
│   └── hq-tester.md                 # H.6
├── skills/
│   ├── plan-long/SKILL.md           # giữ nguyên
│   ├── plan-short/SKILL.md          # giữ nguyên
│   ├── build-verify/SKILL.md        # H.7 — quy ước build deliverable trực tiếp + verify khách quan
│   └── hq-memory/SKILL.md           # H.8 — đọc/ghi .claude/memory/
├── memory/                          # HQ-team store (tách bạch engine branch)
│   ├── README.md
│   ├── context.md
│   ├── mistakes.md
│   ├── patterns.md
│   └── global.md
├── teams/
│   ├── playbook.md                  # H.1 skeleton → H.9 đầy đủ
│   └── team-issues-queue.md         # H.9
└── hq-master.md                     # orchestration doc — flow động + trỏ playbook + roster
```

**Phân biệt 3 store:**
- `company/.claude/memory/` — store **làm việc của HQ-team** (lead + tester ghi qua `hq-memory` skill).
- `company/memory/` — store **engine branch HQ-global** (engine `memory.ps1`; nay HQ-team KHÔNG ghi).
- `<project>/memory/` — store **per-branch** (engine tạo khi node `record` ghi `context`).

---

## 4. Memory 2-store tách bạch

### `.claude/memory/` — HQ-team store

| File | Ai ghi | Ai đọc | Nội dung |
|---|---|---|---|
| `context.md` | Lead / tester (qua hq-memory) | Lead đầu task | Đang build gì, trạng thái, quyết định gần đây |
| `mistakes.md` | Lead / tester | Lead + researcher | Lỗi thực tế đã gặp (build fail, thiết kế hỏng) — không tái phạm |
| `patterns.md` | Lead / tester | Lead + cto | Pattern thành công (loại request → cách build hiệu quả) |
| `global.md` | Lead | Lead | Ghi chú cross-cutting: con người, quyết định kiến trúc |

**Format entry**:
```
## <YYYY-MM-DD HH:MM> — <slug-ngắn>
<nội dung>
```

**Cap N = 10** entry mới nhất được load (cũ hơn vẫn lưu file).

### `company/memory/` + `<project>/memory/` — engine branch store

- **BẤT BIẾN** — engine `memory.ps1` không đổi. HQ-team KHÔNG ghi vào đây.
- `git diff engine/` chỉ thay đổi ở session reframe này (de-wire selftest + comment) — sau đó rỗng lại.

---

## 5. Hợp đồng "build deliverable trực tiếp" (thay "engine như tool")

> **REVISE Q2:** bản cũ ghi "teammate gọi engine `run.ps1 autobuild/check/trial` để build/test". Quyết mới: HQ team build TRỰC TIẾP, KHÔNG đi qua engine.

### Builder workflow

1. Nhận thiết kế (văn xuôi) từ CTO + plan từ planner (qua Task/SendMessage).
2. **Write/Edit file deliverable trực tiếp** vào `projects/<name>/` (output location chuẩn; gitignored, regen-được).
3. **Bash** để cài deps / build / chạy app khi cần (vd `npm install`, `npm run build`).
4. Báo tester khi deliverable sẵn sàng, kèm cách chạy/kiểm.
5. KHÔNG dùng `run.ps1 autobuild/autofix/build`; KHÔNG tạo `workflow.json` HQ; KHÔNG đụng `engine/*.ps1`.

### Tester workflow — quality-gate khách quan

1. Chạy **check của chính deliverable**: test suite (`npm test`/`pytest`/...), build (`npm run build`), lint, hoặc quan sát hành vi nếu không có test tự động.
2. Đọc **exit-code / output** làm nguồn sự thật — KHÔNG phán "trông ổn".
3. In verdict máy-đọc-được:
   ```
   CHECK_RESULT: pass|fail (<lý do/output lệnh nếu fail>)
   ```
4. Báo lead. Fail → lead nhận lý do cụ thể rồi quyết re-fix/re-plan.

### Engine = tool đứng riêng (tùy chọn, không trong luồng HQ build)

`run.ps1` + app vẫn tồn tại như **công cụ workflow-chi-nhánh độc lập**. Nếu (và chỉ nếu) request CỤ THỂ là "dựng/sửa một workflow pipeline" thì lead/builder có thể gọi `run.ps1 validate/run/graph` — nhưng đó là ngoại lệ, không phải đường build mặc định. Mặc định: build trực tiếp.

---

## 6. Quality-gate khách quan

**Nguyên tắc**: không để LLM "phán" pass/fail cảm tính — kết quả lệnh của chính deliverable là nguồn sự thật.

### Cơ chế chính: tester chạy check của deliverable

```bash
# ví dụ — tùy loại deliverable
npm test        # $? = 0 → pass
npm run build   # $? = 0 → build ok
```

Tester bắt buộc in `CHECK_RESULT: pass|fail (...)`. Lead đọc verdict từ TaskOutput/SendMessage.

### Khi deliverable KHÔNG có test tự động

Tester định nghĩa **kiểm-tra quan sát-được** từ done-criteria của planner (vd "mở trang → nhập email sai → thấy báo lỗi") và chạy/quan sát, ghi rõ đã kiểm gì + kết quả. Vẫn cụ thể, không cảm tính.

### Cơ chế bổ sung: hook (defer)

Hook `TaskCompleted`/`TeammateIdle` (exit 2 chặn) là option mạnh hơn — **defer Phase I/K**. Phase H đủ với convention-trong-body (tester bắt buộc in `CHECK_RESULT`).

### Escalation sau N vòng fail

Lead tự đếm vòng: 2 vòng fail → báo user kèm lý do, hỏi tiếp không; 3 vòng → shutdown team, báo cáo tổng hợp, ghi `mistakes.md`.

---

## 7. Skill inventory

### 2 skill project-scope (vì frontmatter `skills` của teammate bị bỏ qua → phải project-scope)

| Skill | Session | Nội dung |
|---|---|---|
| `build-verify` | H.7 | Quy ước build deliverable TRỰC TIẾP: nơi ghi (`projects/<name>/`), cách cấu trúc, cách tester verify khách quan (chạy test/build/lint của deliverable, đọc exit-code, in `CHECK_RESULT`). Ranh giới: builder không đụng `engine/*.ps1`. |
| `hq-memory` | H.8 | Đọc `context.md`+`mistakes.md` đầu task; append entry date-stamped cuối task (delimiter `## <date> — <slug>`, cap N=10). Cảnh báo: KHÔNG nhầm `.claude/memory/` với `company/memory/` (engine store). |

> **Bỏ skill `engine-ops` (bản cũ)**: bản H.0 cũ dự định `engine-ops` gói cách gọi `run.ps1 build/autobuild/check/trial`. Sau Q2, builder/tester KHÔNG đi qua engine → skill đó vô nghĩa. Thay bằng `build-verify` (quy ước build trực tiếp + verify). Vẫn **2 skill / 2 session** (H.7 + H.8).

---

## 8. Số phận legacy — ĐÃ XÓA (reframe 2026-06-02)

> **REVISE Q2:** bản cũ chốt "giữ legacy làm tham chiếu, dọn cuối roadmap". User quyết XÓA NGAY trong session reframe này (legacy là nguồn gây lậm form cũ).

**Đã xóa (git rm, 2026-06-02):**
- `hq/workflow.json` + `hq/workflow.mmd` (DAG HQ cũ)
- `hq/agents/*.md` (11 node prompt — nguồn lậm form)
- `hq/build-spec.md` + `hq/skills.md` (doc workflow HQ)
- `examples/hq-coo|hq-cto|hq-planner|hq-tester/` (per-agent mock fixtures)
- `examples/hq-tests.ps1` + `examples/hq-graph-tests.ps1` (test workflow HQ)

**De-wire selftest**: `engine/test-runner.ps1` gỡ `hq-tests`+`hq-graph-tests` khỏi vòng script → **12 mục còn 10**. `e2e-harness-tests` GIỮ (repoint fixture `hq/` → `examples/loopy`).

**Engine giữ nguyên code, nhưng lưu ý vestigial:** `engine/e2e.ps1` (`Invoke-E2E`/`Invoke-E2EFix` = `autobuild`/`autofix`) hardcode terminal `'record'` — build riêng cho graph HQ. Sau Q2 HQ không dùng → 2 hàm này **vestigial** (engine code còn, không có consumer trong luồng HQ). KHÔNG xóa trong session này (đụng engine executor); ghi nhận candidate dọn ở §Dọn-legacy ROADMAP nếu sau này xác nhận standalone-engine cũng không cần.

---

## 9. Done-gate Phase H + đo token baseline

### Done-gate (checklist)

- [ ] `design.md` chốt đủ 9 mục theo quyết định Q2; mọi "cần làm rõ" ROADMAP §H trả lời
- [ ] Flag `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` bật; CC ≥ v2.1.32 verified
- [ ] 5 teammate def `hq-{researcher,planner,cto,builder,tester}.md` form prose (KHÔNG JSON ceremony), mỗi cái đạt checklist (a)–(d)
- [ ] 2 skill (`build-verify` + `hq-memory`), mọi lệnh/quy ước tham chiếu thật
- [ ] `.claude/memory/` 4 file + store HQ-team tách bạch engine
- [ ] `playbook.md` đủ 6 mục + flow động + `team-issues-queue.md`
- [ ] Chạy thật H.10: lead dựng + verify 1 deliverable trực tiếp (KHÔNG engine-build), tester check khách quan, record memory — hoàn toàn động
- [ ] Báo cáo token: team-native vs HQ-workflow cũ
- [ ] Legacy đã xóa + ghi nhận trong ROADMAP §Dọn-legacy
- [ ] Regression (validate hello + run hello -Mock + selftest 10/10) PASS session cuối; ROADMAP Phase H → ✅

### Token baseline (HQ-workflow cũ — ước lượng từ cấu trúc, để so ở H.10)

| Node | Lượt | Token/lượt (est) | Tổng est |
|---|---|---|---|
| coo (router) | 1 | ~500 | ~500 |
| researcher | 1 | ~2000 | ~2000 |
| rg_gate / clarify_gate / escalate_gate (routers) | 1–3 | ~300–500 | ~0.5–1.5k |
| planner | 1 | ~3000 | ~3000 |
| cto | 1 | ~3000 | ~3000 |
| builder (nhiều vòng) | 2–4 | ~5000 | ~10–20k |
| tester / record | 2 | ~500 | ~1000 |
| **Tổng ước** | | | **~20k–30k tokens** (happy path) |

**HQ-native kỳ vọng giảm 20–40%**: bỏ router nodes (tan vào lead) + bỏ overhead build-spec/workflow.json round-trip + giao tiếp prose gọn hơn JSON ceremony + teammate context không tích lũy. H.10 đo `usage` thực tế từng teammate.

---

## Revision log

| Date | Change | Lý do |
|---|---|---|
| 2026-06-02 | Initial (H.0) | Soạn đủ 9 mục theo PLAN.md Phase H.0. |
| 2026-06-02 | **REVISE Q2 (reframe)** | User chỉ ra teammate lậm form workflow cũ (planner xuất JSON vô nghĩa). Đảo: builder build TRỰC TIẾP (Write/Edit, KHÔNG engine-build); giao tiếp prose; bỏ build-spec/workflow.json/plan-as-data khỏi luồng HQ; engine thành tool đứng riêng. Legacy `hq/` + `examples/hq-*` + 2 test script XÓA; selftest 12→10; `engine-ops` skill → `build-verify`. Soạn lại `hq-researcher`+`hq-planner` form prose. |
