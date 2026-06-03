# HQ Team Playbook

> "Bộ não" điều phối của lead khi vận hành HQ như native team (TeamCreate). Đọc file này cùng
> `hq-master.md` (flow + roster) + `plan/hq-v2/phase-h/design.md` (spec kiến trúc đầy đủ).
>
> **Nguyên tắc xuyên suốt:** teammate giao tiếp **văn xuôi**, build **trực tiếp** (Write/Edit),
> gate = **kết quả khách quan** của deliverable. KHÔNG JSON ceremony. KHÔNG engine-build.

---

## 1. When to team (khi nào spawn vs lead tự làm)

| Tình huống | Lead làm gì |
|---|---|
| Request mới cần xây thật, multi-file / domain mới | Spawn full team: researcher → planner → cto → builder → tester |
| Request đơn giản (clarification, status check) | Lead tự xử — không spawn |
| Sửa deliverable đã có | Spawn builder + tester (bỏ researcher/planner/cto) |
| Chỉ cần thiết kế (chưa build) | Spawn researcher + planner + cto |
| Cần 1 teammate bất kỳ | TeamCreate với danh sách tối thiểu |

**Quy tắc size:** 3–5 teammate. **Không spawn nếu lead tự làm được trong 1–2 tool call** — overhead TeamCreate không đáng cho task nhỏ.

**Dấu hiệu cần spawn** (bất kỳ 1 trong các cái này):
- Deliverable > 3 file hoặc > 1 stack/domain
- Cần research context trước khi plan
- Cần thiết kế kỹ thuật trước khi code
- Tester verify cần chạy lệnh build/test thật

---

## 2. Lifecycle teammate (vòng đời)

### Spawn và giao brief

```
LEAD → TeamCreate([...teammates])
     → TaskCreate cho mỗi teammate (title + body = brief đầy đủ)
     → SendMessage(to: "teammate", body: "Brief ngắn + trỏ TaskId")
     → Chờ ack từng teammate
```

**Brief tối thiểu** (không thiếu, không thừa):
```
user_request: <yêu cầu gốc>
context: <tóm tắt research / thiết kế / plan — tuỳ teammate nhận>
done_criteria: <danh sách cụ thể, đo được>
output_format: <lead expect nhận lại gì>
```

### Làm việc và cập nhật

Mỗi teammate khi nhận brief:
1. **Ack ngay trong turn đầu** (`TaskUpdate in_progress`) — không silent-start.
2. Làm việc.
3. **Báo lead khi xong** (`TaskUpdate completed` + `SendMessage` kết quả).
4. Chờ `shutdown_request` — không tự thoát.

### Shutdown

```
LEAD nhận kết quả từ tất cả teammate cần thiết
→ LEAD quyết định: done / re-fix / re-plan
→ LEAD SendMessage(to: "all", body: "shutdown_request")
→ Teammates respond ack shutdown
→ LEAD cleanup (đọc TaskOutput nếu cần)
```

### Vòng re-fix / re-plan

```
tester fail → LEAD đọc lý do cụ thể (output lệnh, dòng lỗi)
            ├── sửa được (bug nhỏ) → SendMessage builder re-fix
            ├── cần thay đổi plan → SendMessage planner re-plan → loop
            └── fail lần 3 → shutdown team, báo user, ghi mistakes.md
```

**Escalation**: sau 2 vòng fail → lead báo user kèm lý do, hỏi tiếp không. Sau 3 vòng → shutdown + báo cáo tổng hợp.

---

## 3. Anti-pattern (những gì KHÔNG làm)

### Lead anti-pattern

| Anti-pattern | Vì sao sai | Thay bằng |
|---|---|---|
| **Lead-DIY vượt ngưỡng** | Lead tự build/code khi request phức tạp | Spawn builder |
| **Spawn thừa teammate** | Overhead tốn token, context bị loãng | Spawn tối thiểu cần thiết |
| **Brief thiếu done-criteria** | Tester không biết kiểm gì → phán cảm tính | Luôn ghi done_criteria đo được trong brief |
| **Không chờ ack** | Không biết teammate đã nhận brief chưa | Chờ ack (`in_progress`) trước khi tiếp |
| **Tự accept verdict** | Lead tự bảo "có vẻ ổn" không qua tester | Luôn để tester chạy check khách quan |

### Teammate anti-pattern

| Anti-pattern | Vai | Vì sao sai |
|---|---|---|
| **Xuất JSON / build-spec** | Planner/CTO | Không có engine nào parse — vô nghĩa |
| **Silent-complete** | Mọi vai | Lead không biết xong, team bị treo |
| **Tự thoát không chờ shutdown** | Mọi vai | Mất kết quả cuối, lead mất sync |
| **Phán "có vẻ pass"** | Tester | Gate phải từ exit-code/output thật |
| **Ghi vào `company/memory/`** | Tester/Lead | Nhầm store — engine store, không phải HQ-team |
| **Build qua run.ps1 autobuild** | Builder | Engine-build đã loại khỏi luồng HQ |
| **Stale context** | Mọi vai | Từ prior session không đọc lại memory/brief mới |

### Stale-context — protocol tránh

Khi lead re-spawn team (vòng mới sau re-plan), **gửi lại brief đầy đủ** trong SendMessage — teammate KHÔNG kế thừa history từ lượt trước. Mọi context cần thiết phải nằm trong brief.

---

## 4. Issue queue

File theo dõi issue phát sinh trong quá trình chạy team: `company/.claude/team-issues-queue.md`.

### Format mỗi issue

```markdown
## <YYYY-MM-DD HH:MM> — <code> — <slug ngắn>

- **Teammate**: hq-<vai>
- **Triệu chứng**: <mô tả cụ thể — output lệnh / hành vi sai>
- **Root cause**: <nguyên nhân nếu đã biết>
- **Trạng thái**: open | investigating | resolved
- **Fix**: <hành động đã làm / ghi chú>
```

### Code phân loại issue

| Code | Ý nghĩa |
|---|---|
| `SILENT` | Teammate không ack / không báo xong |
| `STALE` | Teammate dùng context cũ / không đọc brief mới |
| `FORM` | Teammate xuất JSON / build-spec thay vì văn xuôi |
| `SCOPE` | Teammate làm ngoài scope brief |
| `GATE` | Tester phán cảm tính thay vì exit-code thật |
| `STORE` | Nhầm memory store (ghi vào engine branch) |
| `BUILD` | Builder đi qua engine-build thay vì Write/Edit trực tiếp |
| `OTHER` | Khác — mô tả trong slug |

---

## 5. Build-deliverable contract

> Chi tiết đầy đủ: skill `build-verify` tại `company/.claude/skills/build-verify/SKILL.md`.

### Builder (Write/Edit trực tiếp)

- Output location: **`projects/<name>/`** (gitignored, regen-được — không commit).
- Dùng **Write + Edit + Bash** — ghi file trực tiếp, cài deps, chạy build.
- **KHÔNG** `run.ps1 autobuild/autofix/build`. **KHÔNG** tạo `workflow.json` HQ. **KHÔNG** đụng `engine/*.ps1`.
- Khi xong: báo tester kèm cách chạy + done-criteria để tester verify.

### Tester (check khách quan)

- Chạy **check của chính deliverable**: `npm test`, `npm run build`, `pytest`, `go test`, lint, quan sát hành vi.
- Nguồn sự thật = **exit-code + output lệnh** — không phán "trông ổn".
- In verdict: `CHECK_RESULT: pass|fail (<lý do/output nếu fail>)`.
- Ghi memory sau verify (xem §6).

### Engine = tool đứng riêng (KHÔNG trong luồng HQ build mặc định)

`run.ps1` + app là công cụ workflow-chi-nhánh. Lead/builder CÓ THỂ gọi `run.ps1 validate/run/graph` nhưng chỉ khi request **cụ thể là dựng/sửa workflow pipeline** — đó là ngoại lệ. Luồng build mặc định = trực tiếp.

---

## 6. Memory protocol

> Chi tiết đầy đủ: skill `hq-memory` tại `company/.claude/skills/hq-memory/SKILL.md`.

### Store HQ-team: `company/.claude/memory/`

| File | Ai ghi | Khi nào |
|---|---|---|
| `context.md` | Lead / tester | Cuối mỗi task — trạng thái, quyết định, deliverable đang build |
| `mistakes.md` | Lead / tester | Khi fail thực sự — build fail, thiết kế hỏng, lỗi tái phạm |
| `patterns.md` | Lead / tester | Khi pass — pattern thành công, cách build hiệu quả |
| `global.md` | Lead | Cross-cutting: quyết định kiến trúc, con người, quy ước chung |

**⚠️ KHÔNG nhầm với engine branch store** (`company/memory/` + `<project>/memory/`). Engine store do `memory.ps1` quản lý — HQ-team KHÔNG ghi vào đó.

### Đọc đầu phiên (lead + relevant teammate)

```bash
cat company/.claude/memory/context.md
cat company/.claude/memory/mistakes.md    # nếu build mới
cat company/.claude/memory/patterns.md   # nếu cto/planner cần
```

Cap đọc N=10 entry mới nhất (file giữ toàn bộ lịch sử).

### Ghi cuối task (tester sau verify / lead sau record)

Format bắt buộc:
```
## <YYYY-MM-DD HH:MM> — <slug>
<nội dung>
```

Dùng `>>` (append) — **không bao giờ `>`** (overwrite mất toàn bộ lịch sử).
