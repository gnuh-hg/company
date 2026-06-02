# design.md — Phase H: HQ team-of-agents native (CD-1)

> Spec kiến trúc khoá cho toàn Phase H. Mỗi session H.1–H.10 đọc file này để biết "đang xây gì, tại sao, và đặt ở đâu". Không thay đổi mà không có revision log.

---

## 1. Sơ đồ orchestration — flow ĐỘNG (không DAG)

**Lead** là Claude Code session chính (model: claude-opus-4-8 hoặc sonnet tùy ngữ cảnh). Lead KHÔNG gọi `hq/workflow.json` — lead điều phối bằng reasoning trực tiếp + TeamCreate.

### Khi nào lead spawn team vs tự làm

| Tình huống | Lead làm gì |
|---|---|
| Request mới cần nghiên cứu toàn pipeline | Spawn team đầy đủ: researcher → planner → cto → builder → tester |
| Request đơn giản (clarification, status check) | Lead tự xử, không spawn |
| Fix branch đã có (validate fail) | Spawn builder + tester (bỏ researcher/planner/cto) |
| Cần thêm 1 teammate bất kỳ | TeamCreate với danh sách tối thiểu cần thiết |

**Size team thực tế**: 3–5 teammate. Không spawn nếu lead có thể tự làm trong 1–2 tool call.

### Flow điển hình: build request mới

```
LEAD nhận user_request
  └─► LEAD phân loại (research cần chưa? đơn giản hay phức tạp?)
        ├── phức tạp / multi-file / domain mới
        │     └─► TeamCreate [researcher, planner, cto, builder, tester]
        │           │
        │           ├─► SendMessage → researcher: "gom context về request + memory"
        │           │     └─► researcher trả tóm tắt + open_questions[]
        │           │
        │           ├─► LEAD xét open_questions:
        │           │     ├── còn câu chặn → LEAD hỏi user trực tiếp (clarify động)
        │           │     └── đủ rõ → tiếp
        │           │
        │           ├─► SendMessage → planner: "dựng plan-as-data từ research"
        │           │     └─► planner trả plan JSON (WHAT)
        │           │
        │           ├─► SendMessage → cto: "dựng build-spec từ plan"
        │           │     └─► cto trả build-spec (HOW, chọn vai catalog/)
        │           │
        │           ├─► SendMessage → builder: "build chi nhánh từ spec"
        │           │     └─► builder shell: pwsh run.ps1 autobuild <spec>
        │           │           └─► engine: sandbox → run real → validate → promote
        │           │
        │           ├─► SendMessage → tester: "kiểm tra branch vừa promote"
        │           │     └─► tester shell: pwsh run.ps1 check <branch>
        │           │                        pwsh run.ps1 trial <branch>
        │           │           ├── pass → ghi memory + báo LEAD
        │           │           └── fail → báo LEAD kèm reason máy-đọc-được
        │           │
        │           ├─► LEAD xét verdict:
        │           │     ├── pass → record memory + shutdown team + báo user
        │           │     ├── fail (minor, builder có thể fix) → SendMessage → builder re-fix
        │           │     └── fail (structural) → SendMessage → planner re-plan → loop
        │           │
        │           └─► LEAD shutdown team khi done
        │
        └── đơn giản → LEAD tự trả lời user
```

**Các gate/route cũ tan vào lead reasoning:**

| Gate cũ (workflow.json) | Thay bằng gì trong lead |
|---|---|
| `coo` (router build/fix/unclear) | Lead phân loại bằng reasoning — không cần router riêng |
| `rg_gate` (đủ research chưa) | Lead xét `open_questions[]` từ researcher |
| `clarify_gate` (hỏi user) | Lead hỏi user trực tiếp (native) |
| `escalate_gate` / `escalate_report` | Lead quyết định escalate sau N vòng fail |
| `record` (node ghi memory) | Lead gọi skill `hq-memory` trực tiếp sau verify done |

---

## 2. Roster teammate

### 5 teammate def — `company/.claude/agents/hq-*.md`

| Teammate file | Nguồn (chuyển hoá từ) | Tools | Model | Vai trò |
|---|---|---|---|---|
| `hq-researcher.md` | `hq/agents/researcher.md` | Read, Grep, Glob, WebSearch | claude-sonnet-4-6 | Gom context request + memory → tóm tắt + open_questions[] |
| `hq-planner.md` | `hq/agents/planner.md` | Read | claude-sonnet-4-6 | WHAT — plan-as-data từ research |
| `hq-cto.md` | `hq/agents/cto.md` | Read | claude-sonnet-4-6 | HOW — build-spec, chọn vai catalog/ |
| `hq-builder.md` | `hq/agents/builder.md` | Read, Bash | claude-sonnet-4-6 | Ghi file qua engine autobuild/autofix — KHÔNG Write/Edit trực tiếp |
| `hq-tester.md` | `hq/agents/tester.md` | Read, Bash | claude-sonnet-4-6 | Chạy check/trial engine lấy exit-code + ghi memory |

**Convention tên**: tiền tố `hq-` để tránh nhầm với agent META `.claude/agents/planner.md` (dùng để soạn PLAN/CHECKPOINT cho các phase). Hai agent cùng tên `planner` sẽ gây nhầm lẫn nghiêm trọng.

### 6 thành phần KHÔNG thành teammate + lý do

| Thành phần cũ | Lý do KHÔNG tạo teammate |
|---|---|
| `coo` (router) | Logic phân loại đơn giản — lead reasoning làm tốt hơn mà không cần overhead spawn. Không đủ "công việc" để là một teammate. |
| `rg_gate` (router) | Chỉ đọc dòng cuối output researcher — lead tự xét trivially. |
| `clarify_gate` | Lead hỏi user native (không cần agent trung gian). |
| `escalate_gate` | Lead tự đếm vòng fail và quyết escalate. |
| `escalate_report` | Lead tự báo cáo user khi escalate. Không cần agent viết báo cáo. |
| `record` (node ghi memory) | Thay bằng skill `hq-memory` — lead gọi skill sau verify, không cần teammate riêng. |

---

## 3. Bố cục `.claude/` đích

```
company/.claude/
├── settings.json                    # flag CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 (H.1)
├── settings.local.json              # giữ nguyên
├── agents/
│   ├── planner.md                   # META planner — GIỮ NGUYÊN, không đụng
│   ├── hq-researcher.md             # H.2
│   ├── hq-planner.md                # H.3
│   ├── hq-cto.md                    # H.4
│   ├── hq-builder.md                # H.5
│   └── hq-tester.md                 # H.6
├── skills/
│   ├── plan-long/SKILL.md           # giữ nguyên
│   ├── plan-short/SKILL.md          # giữ nguyên
│   ├── engine-ops/SKILL.md          # H.7 — scaffold/patch/diagnose/run-test
│   └── hq-memory/SKILL.md           # H.8 — đọc/ghi .claude/memory/
├── memory/                          # HQ-team store (tách bạch engine branch)
│   ├── README.md                    # schema: ai đọc/ghi, delimiter, cap N
│   ├── context.md                   # bối cảnh làm việc hiện tại của HQ-team
│   ├── mistakes.md                  # lỗi đã gặp + không lặp lại
│   ├── patterns.md                  # pattern thành công tái dùng
│   └── global.md                    # ghi chú cross-cutting
├── teams/
│   ├── playbook.md                  # H.1 skeleton → H.9 đầy đủ
│   └── team-issues-queue.md         # H.9
└── hq-master.md                     # orchestration doc — flow động + trỏ playbook + roster
```

**Phân biệt engine vs HQ-team:**
- `company/.claude/memory/` — store **làm việc của HQ-team** (đọc/ghi bởi lead + tester qua `hq-memory` skill)
- `company/memory/` — store **engine branch HQ-global** (đọc/ghi bởi engine `memory.ps1` → node `record`)
- `<project>/memory/` — store **per-branch** (engine tạo lúc `Write-MemoryEntry` với type `context`)

---

## 4. Memory 2-store tách bạch

### `.claude/memory/` — HQ-team store

| File | Ai ghi | Ai đọc | Nội dung |
|---|---|---|---|
| `context.md` | Lead / tester (qua hq-memory skill) | Lead đầu task | Bối cảnh làm việc: branch nào đang build, trạng thái, quyết định gần đây |
| `mistakes.md` | Lead / tester | Lead + researcher | Lỗi thực tế đã gặp (builder fail, spec hỏng, engine error) — không tái phạm |
| `patterns.md` | Lead / tester | Lead + cto | Pattern thành công (loại request → cách build hiệu quả) |
| `global.md` | Lead | Lead | Ghi chú cross-cutting: con người, quyết định kiến trúc, phạm vi engine |

**Format entry** (mirror engine memory):
```
## <YYYY-MM-DD HH:MM> — <slug-ngắn>
<nội dung>
```

**Cap N = 10** entry mới nhất được load (cũ hơn vẫn lưu file, chỉ bỏ qua khi đọc).

**Skill đọc**: đọc đầu task (`hq-memory` skill) — team lead thường đọc `context.md` + `mistakes.md` trước khi giao việc.

### `company/memory/` + `<project>/memory/` — engine branch store

- **BẤT BIẾN** — engine `memory.ps1` (`Get-Memory` / `Write-MemoryEntry`) không đổi.
- Ghi bởi node `record` (`memory_write`) trong `hq/workflow.json` (legacy, vẫn chạy được).
- Team HQ-native KHÔNG ghi vào store này — nếu muốn lưu bài học từ chi nhánh, lead ghi vào `.claude/memory/mistakes.md` hoặc `patterns.md`.
- `git diff engine/` RỖNG mọi session Phase H — đây là bất biến kiểm chứng được.

---

## 5. Hợp đồng "engine như tool"

Teammate **chỉ GỌI** engine qua Bash shell — không đọc/sửa `engine/*.ps1`.

### Lệnh teammate được dùng

| Lệnh | Teammate dùng | Mục đích |
|---|---|---|
| `pwsh run.ps1 build <spec-file> [outName]` | builder | Scaffold chi nhánh từ build-spec (deterministic) |
| `pwsh run.ps1 autobuild <proj> "<req>" -Real` | builder | Build + sandbox + run real + validate + promote |
| `pwsh run.ps1 autofix <proj> "<req>" -Seed <br> -Branch <n> -Real` | builder | Fix-loop branch hỏng |
| `pwsh run.ps1 validate <proj>` | builder, tester | Kiểm schema/agent/router/reachability |
| `pwsh run.ps1 check <proj>` | tester | Tầng cấu trúc: validate exit0 + run -Mock done + output_key non-empty |
| `pwsh run.ps1 trial <proj>` | tester | Tầng trial THẬT: assert `trial[]` (đốt token — dùng khi check pass) |
| `pwsh run.ps1 status <proj>` | tester, lead | Xem trạng thái run gần nhất |
| `pwsh run.ps1 graph <proj> -Json` | lead, tester | Lấy graph JSON chuẩn hoá (nodes/edges) để đọc |

**Đường dẫn gọi**: teammate làm việc trong `company/` → gọi `pwsh /home/.../company/engine/run.ps1 ...` hoặc `pwsh engine/run.ps1` tuỳ cwd. Skill `engine-ops` ghi rõ convention cwd.

### Đọc kết quả engine

| Nguồn | Đọc bằng | Ý nghĩa |
|---|---|---|
| **Exit code** | `$LASTEXITCODE` sau lệnh pwsh | 0 = pass; N > 0 = N tiêu chí fail |
| **`Write-CheckResult`** stdout | Parse dòng cuối (reason máy-đọc-được) | Tiêu chí nào fail, vì sao |
| **`Write-E2EResult`** stdout | JSON `{"ok":bool,"errors":[...]}` | autobuild/autofix thành công hay không |
| **`Write-SaveResult`** stdout | JSON `{"ok":bool,"errors":[...]}` | save-graph thành công hay không |
| **`.runs/<runid>/events.ndjson`** | Read file (NDJSON) | Event stream đầy đủ (node_output, awaiting...) |
| **`.runs/<runid>/state.json`** | Read file | Trạng thái run: status, visits, awaiting |
| **`projects/<name>/`** | `run.ps1 status <name>` | Chi nhánh đã promote (sau autobuild thành công) |

**Builder workflow** cụ thể:
1. Nhận build-spec từ CTO (qua Task/SendMessage).
2. Shell `run.ps1 autobuild <spec> -Real` → đọc stdout JSON `{"ok":bool}`.
3. Nếu `ok=false`: đọc `errors[]` → báo lead để re-plan hoặc tự `autofix`.
4. Nếu `ok=true`: chi nhánh đã promote vào `projects/<name>/` — báo tester.
5. Builder KHÔNG tự `Write`/`Edit` file trong `<project>/` — engine sandbox/promote lo.

---

## 6. Quality-gate khách quan

**Nguyên tắc**: không để LLM "phán" pass/fail bằng cảm tính — exit code engine là nguồn sự thật.

### Cơ chế chính: exit-code trong tester body

Tester chạy:
```bash
pwsh run.ps1 check <branch>
# $LASTEXITCODE = 0 → pass, > 0 → fail (số tiêu chí fail)

pwsh run.ps1 trial <branch>
# $LASTEXITCODE = 0 → pass
```

Tester bắt buộc in verdict dạng máy-đọc-được:
```
CHECK_RESULT: pass|fail (N criteria failed)
TRIAL_RESULT: pass|fail
```

Lead đọc verdict từ TaskOutput/SendMessage — nếu fail, lead nhận `reason` từ stdout engine rồi quyết re-plan/re-fix.

### Cơ chế bổ sung: hook `TaskCompleted` (tuỳ chọn, chốt dùng)

**Quyết định**: dùng **convention-trong-body** là đủ cho Phase H (exit-code bắt buộc in verdict). Hook `TaskCompleted`/`TeammateIdle` (exit 2 chặn) là option mạnh hơn — **defer sang Phase I/K** khi cần hardening thêm. Lý do defer: (a) hook chạy shell ngoài → cần thêm config, tăng độ phức tạp H.1; (b) convention đã đủ nếu tester body tuân thủ chặt; (c) Phase H focus vào correctness từng teammate, không hardening flow.

### Escalation sau N vòng fail

Lead tự đếm vòng (soft-escalate sau 2 re-plan, hard-escalate sau 3):
- 2 vòng fail → lead báo user kèm reason, hỏi có muốn tiếp không.
- 3 vòng fail → lead shutdown team, báo cáo tổng hợp lỗi, ghi `mistakes.md`.

---

## 7. Skill inventory

### Ánh xạ `hq/skills.md` → skill project-scope Phase H

| Skill cũ (hq/skills.md) | → Skill project-scope | Session |
|---|---|---|
| scaffold (builder dùng `run.ps1 build`) | `engine-ops` | H.7 |
| patch (builder Write/Edit trực tiếp) | **không còn** — builder H-native dùng engine autobuild, không Write/Edit | — |
| diagnose (đọc reason từ check/trial) | `engine-ops` | H.7 |
| run-test (check + trial) | `engine-ops` | H.7 |
| report (ghi memory) | `hq-memory` | H.8 |

**Tổng: 2 skill project-scope** → 2 session H-C (H.7 + H.8).

### Nội dung từng skill

**`engine-ops`** (`company/.claude/skills/engine-ops/SKILL.md`):
- Bảng 7+ lệnh `run.ps1` (validate/check/trial/build/autobuild/autofix/graph-Json/status)
- Mục "đọc kết quả" (exit code, stdout JSON, events.ndjson, state.json)
- Mục "ranh giới" (chỉ gọi, không sửa engine/*.ps1; cwd convention)
- Mục "lỗi thường gặp" (cwd sai, path spec tương đối vs tuyệt đối)

**`hq-memory`** (`company/.claude/skills/hq-memory/SKILL.md`):
- Đọc đầu task: load `context.md` + `mistakes.md` vào context trước khi bắt đầu
- Ghi cuối task: append entry date-stamped vào file đúng loại (context/mistakes/patterns/global)
- Format delimiter (mirror engine memory `## <YYYY-MM-DD HH:MM> — <slug>`)
- Cảnh báo rõ: KHÔNG nhầm `.claude/memory/` với `company/memory/` (engine store)

---

## 8. Số phận legacy

**Quyết định** (đã chốt user 2026-06-02): `hq/workflow.json` + `hq/agents/*.md` + `examples/hq-*` + `hq-graph-tests` trong selftest — **GIỮ NGUYÊN làm tham chiếu** trong suốt Phase H và toàn đợt hq-v2. Không xoá, không rename.

**Lý do giữ**: nguồn chuyển hoá agent (H-B đọc để viết teammate def); safety net kiểm tra regression; tài liệu kiến trúc cũ.

**Dọn cuối roadmap**: hàng "DỌN legacy (sau Phase L)" đã thêm vào `plan/hq-v2/ROADMAP.md` — làm sau khi toàn bộ hq-v2 (H→L) xong và HQ-native đã proven stable.

---

## 9. Done-gate Phase H + đo token baseline

### Done-gate (checklist — xem PLAN.md Outcome cuối để biết chi tiết)

- [ ] `design.md` chốt đủ 9 mục; mọi "cần làm rõ" ROADMAP §H trả lời
- [ ] Flag `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` bật; CC ≥ v2.1.32 verified
- [ ] 5 teammate def `hq-{researcher,planner,cto,builder,tester}.md`, mỗi cái đạt checklist (a)–(d)
- [ ] 2 skill (`engine-ops` + `hq-memory`), mọi lệnh tham chiếu thật
- [ ] `.claude/memory/` 4 file + store HQ-team tách bạch engine (`git diff engine/` rỗng)
- [ ] `playbook.md` đủ 6 mục + flow động + `team-issues-queue.md`
- [ ] Chạy thật H.10: lead dựng chi nhánh thật qua engine, test qua engine, record memory — hoàn toàn động
- [ ] Báo cáo token: team-native vs HQ-workflow cũ
- [ ] Legacy còn nguyên + hàng "DỌN legacy" trong ROADMAP
- [ ] Regression 3-lệnh PASS session cuối; ROADMAP Phase H → ✅

### Cách đo token baseline (HQ-workflow cũ)

**Ước lượng HQ-workflow cũ** (không chạy thật, tính từ cấu trúc):

| Node | Lượt | Token/lượt (est) | Tổng est |
|---|---|---|---|
| coo (router, haiku) | 1 | ~500 | ~500 |
| researcher (sonnet) | 1 | ~2000 | ~2000 |
| rg_gate (router, haiku) | 1 | ~300 | ~300 |
| clarify_gate (nếu cần) | 0–1 | ~500 | ~0–500 |
| planner (sonnet) | 1 | ~3000 | ~3000 |
| cto (sonnet) | 1 | ~3000 | ~3000 |
| builder (sonnet, nhiều vòng) | 2–4 | ~5000 | ~10000–20000 |
| tester router | 1 | ~500 | ~500 |
| escalate_gate | 0–1 | ~300 | ~0–300 |
| record (ghi memory) | 1 | ~500 | ~500 |
| **Tổng ước** | | | **~20k–30k tokens** (happy path, 1 attempt builder) |

**Ước lượng HQ-native** (H.10 sẽ đo thực tế):
- Bỏ overhead: coo (tan vào lead) + rg_gate + clarify_gate + escalate_gate + escalate_report + record node
- Lead điều phối trực tiếp → ít intermediate step hơn
- Teammate conversation history **không kế thừa** (bắt đầu fresh mỗi spawn) → ít context lặp
- **Kỳ vọng**: tiết kiệm 20–40% so với baseline (chủ yếu nhờ bỏ router nodes + context không tích lũy)

H.10 sẽ ghi `usage` từng teammate (best-effort từ `/usage` hoặc estimate từ API response headers) và so sánh với bảng trên.

---

## Revision log

| Date | Change | Lý do |
|---|---|---|
| 2026-06-02 | Initial (H.0) | Soạn đủ 9 mục theo PLAN.md Phase H.0. Chốt: convention-trong-body cho quality-gate (hook defer I/K); `patch` skill không còn (builder dùng engine); 2 skill project-scope; tên tiền tố `hq-` cho teammate. |
