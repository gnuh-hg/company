# HQ Team Playbook

> "Bộ não" thao tác của lead khi vận hành HQ như native Claude Code team (Agent Teams).
> Đọc cùng `hq-master.md` (flow + roster + ranh giới engine). Spec kiến trúc: `plan/hq-v2/phase-h/design.md`.
>
> **Nguyên tắc xuyên suốt:** lead **điều phối** (không tự build cho task lớn) · teammate giao tiếp
> **văn xuôi** · builder ghi file **trực tiếp** (Write/Edit) · gate = **kết quả khách quan** của
> deliverable · lead **drive TaskList loop** (giao → chờ → gate → task kế). KHÔNG JSON ceremony.
> KHÔNG engine-build. (Engine `run.ps1`/`app` = công cụ chi-nhánh, ngoài luồng HQ — xem hq-master.)

---

## 1. Khi nào lập team (vs lead tự làm)

Lập team **không phải mặc định** — tốn token + tăng coordination overhead. Lead chỉ lập khi:

| Tình huống | Lead làm gì |
|---|---|
| Request mới cần xây chi nhánh thật, multi-file / domain mới | Spawn full chain: researcher → planner → cto → builder → tester |
| **Sửa chi nhánh đã có theo yêu cầu user mới** (hạng nhất, ≠ re-fix) | Spawn planner (light) + builder + tester (bỏ researcher/cto) |
| **Tự sửa HQ (self-mod)** — sửa `.claude/`, `engine/`, `CLAUDE.md`... | Spawn planner (light) + [cto nếu phức tạp] + **self-builder + self-tester**; user-approval bắt buộc |
| Chỉ cần thiết kế (chưa build) | Spawn researcher + planner + cto |
| Yêu cầu rõ, nhỏ, 1 stack | Spawn planner + builder + tester |
| Request đơn giản (hỏi, status, đọc file) | Lead tự xử — KHÔNG spawn |

> **Sửa chi nhánh đã có** là loại request hạng nhất — user yêu cầu thay đổi một chi nhánh đang tồn
> tại trong `projects/<branch>/` (thêm/bớt node, đổi roster, sửa agent). KHÁC **re-fix từ verdict**
> (tester báo fail trong vòng build → builder vá bug, không có user-request mới). Loại này cần
> **planner light** chốt WHAT thay đổi (delta, không re-plan toàn bộ); builder **đọc file hiện có
> TRƯỚC**, Edit phẫu thuật, KHÔNG ghi đè toàn bộ.

**Dấu hiệu cần spawn** (bất kỳ 1):
- Deliverable > 3 file hoặc > 1 stack/domain.
- Cần research context trước khi plan, hoặc thiết kế kỹ thuật trước khi code.
- Tester verify cần chạy lệnh build/test thật.

**KHÔNG lập team khi**: fix typo / rename local / 1 file nhỏ < 10 dòng + scope rõ; câu hỏi
"X là gì" / đọc file; lead làm được trong 1–2 tool call.

**Quy tắc size:** 3–5 teammate cho branch-build (full chain = 5); self-mod chain = 4
(planner→cto→self-builder→self-tester). Spawn tối thiểu cần thiết — over-staffing là anti-pattern
#1. Roster có 7 agent nhưng **không trộn branch-build + self-mod chung 1 session** (D-S4).

---

## 2. TeamCreate workflow — recipe 7 bước

```
1. TeamCreate(team_name="hq-<slug-task>")
2. Spawn teammate cần dùng:
     Agent(team_name="hq-<slug>", name="<role>", subagent_type="hq-<role>", run_in_background=true)
   - name  = tên gọi ngắn dùng trong SendMessage: "researcher" / "planner" / "cto" / "builder" / "tester" (self-mod: "self-builder" / "self-tester")
   - subagent_type = file agent: "hq-researcher" / "hq-planner" / "hq-cto" / "hq-builder" / "hq-tester" (self-mod: "hq-self-builder" / "hq-self-tester")
   - Spawn SONG SONG (cùng 1 response block) các teammate độc lập; tuần tự nếu có dependency.
3. ⏱️ ĐỢI ≥30–45s — teammate đọc memory + agent body trước khi ack. SendMessage sớm = SLOW-PICKUP.
4. TaskCreate(title="...", description="<brief đầy đủ self-contained>", owner="<role>")
5. SendMessage(to="<role>", message="Task #N ready — chạy TaskGet(N) đọc brief rồi bắt đầu.")
6. Chờ teammate SendMessage report → gate output → handoff kế hoặc re-fix.
7. Xong tất cả task: SendMessage shutdown_request mỗi teammate → chờ ack → TeamDelete.
```

**Khi nào TeamCreate vs Agent one-shot:**

| | TeamCreate | Agent one-shot |
|---|---|---|
| Turn count | Multi-turn, nhiều round | 1 shot, không follow-up |
| Wake lại khi idle | SendMessage | Không áp dụng |
| Dùng khi | Cả chain build–test–fix, cần gate giữa bước | Research/check nhanh 1 lần |

---

## 3. Spawn prompt template (Quy trình làm việc BẮT BUỘC)

Khi spawn, lead nhắc lại **vai + ai-là-đồng-đội + quy trình BẮT BUỘC** trong message wake đầu
tiên (agent body đã có chi tiết, nhưng nhắc giúp teammate vào guồng đúng loop). Format:

```
Bạn là <role> của team hq-<slug>. Teammate khác đang online: <list role khác>.
Quy trình làm việc BẮT BUỘC:
1. Nhận task qua SendMessage (kèm "task #N") → TaskGet(N) đọc brief + TaskUpdate(in_progress) NGAY trong turn này.
2. Làm đúng scope brief. KHÔNG tự lấy task khác từ TaskList khi chưa được giao.
3. Xong → TaskUpdate(completed) RỒI SendMessage(to="team-lead", <paste TOÀN BỘ output theo format>).
4. Chờ task kế hoặc shutdown_request. KHÔNG tự thoát, KHÔNG peer-DM teammate khác.
```

### Brief tối thiểu (trong `TaskCreate.description`)

Mọi brief phải có 4 phần — **Context + Input + Scope + STOP gate (done-criteria đo được)**.
Self-contained, không reference history (teammate load context riêng từ file).

```
user_request: <yêu cầu gốc nguyên văn>
context:      <tóm tắt research / plan / thiết kế — tuỳ teammate nhận; path tuyệt đối nếu dài>
scope:        <làm gì, KHÔNG làm gì>
done_criteria: <danh sách cụ thể, đo được — file tồn tại / lệnh exit 0 / hành vi quan sát được>
output_format: <lead expect nhận lại gì — trỏ "Output format" trong agent body>
```

> 📋 **Brief quality gate (lead tự check TRƯỚC spawn):** brief < 5 dòng hoặc STOP gate không
> đo được → viết lại, KHÔNG spawn. Brief mơ hồ = SCOPE-DRIFT guaranteed.

### Per-role brief (điền vào `description`)

**researcher** — `user_request` + gợi ý nguồn cần đọc. STOP: trả 4 mục (Đã biết / Rủi ro /
Câu hỏi còn chặn / Nguồn), `open_questions[]` chỉ câu thực sự chặn.

**planner** — `user_request` + research output (paste) + verdict trước (nếu re-plan). STOP:
Goal 1 câu đo được + mỗi Done-criteria có cách kiểm khách quan + Steps là WHAT không HOW.

**cto** — plan markdown (paste) + research. STOP: pipeline (node/edge/when) + roster lắp từ
`catalog/` + cấu trúc file `projects/<branch>/` (workflow.json + agents/), đủ để builder không phải đoán.

**builder** — plan + thiết kế CTO (paste) + tên chi nhánh `<branch>`. STOP: `workflow.json` +
`agents/*.md` ghi vào `projects/<branch>/`, smoke-check `run.ps1 validate <branch>` exit 0 +
`run -Mock` done, báo tester kèm lệnh engine + done-criteria.
> **Khi SỬA chi nhánh đã có** (loại hạng nhất, không phải xây mới): builder **đọc
> `projects/<branch>/` hiện có TRƯỚC** (workflow.json + agents/), Edit **phẫu thuật** đúng phần
> delta theo plan light, **KHÔNG ghi đè toàn bộ** file. Brief phải kèm `<branch>` đang tồn tại +
> mô tả thay đổi cụ thể.

**tester** — done-criteria (từ plan) + tên chi nhánh + lệnh engine (từ builder). STOP: chạy
`run.ps1 validate <branch>` + `run <branch> "x" -Mock` thật, in `CHECK_RESULT: pass|fail` kèm
bảng criterion|evidence, ghi bài học memory.

**self-builder** — WHAT self-mod (từ planner, prose) + HOW cụ thể (file cần đổi, delta rõ) + done-criteria. STOP: mọi file đổi trong scope cho phép; regression gate xanh (`selftest` PASS + `validate hello` exit 0 + `run -Mock` done); re-spawn smoke PASS nếu đụng `.claude/agents/*.md`; KHÔNG auto-commit. Brief BẮT BUỘC kèm danh sách file + delta cụ thể — brief thiếu HOW → self-builder sẽ hỏi lại.
> **Khi spawn self-builder**: đảm bảo KHÔNG có run pipeline đang chạy song song (caveat B). Brief phải ghi rõ đây là self-mod task (không phải branch-build) để tránh nhầm mode (D-S4).

**self-tester** — danh sách file đã đổi + delta (từ self-builder) + done-criteria. STOP: chạy regression gate độc lập (`selftest`+`validate hello`+`run -Mock`), in `SELF_CHECK_RESULT: pass|fail`, báo lead re-spawn smoke nếu đụng `.claude/agents/*.md`, ghi memory + chuẩn bị changelog draft.
> ⚠️ Gate xanh ≠ "done" — tester báo SELF_CHECK_RESULT pass, rồi **lead trình `git diff` cho user duyệt** (D-S2). Tester KHÔNG tự kết luận "hoàn tất".

---

## 4. Lifecycle teammate + SendMessage protocol

### Vòng giao việc chuẩn

```
TaskUpdate(owner=<role>) + SendMessage wake
  └── chờ teammate SendMessage report (output đầy đủ trong message, KHÔNG "xem task")
        ├── PASS gate → handoff kế / task kế
        └── FAIL gate → feedback diff-style + re-spawn cùng task (tối đa 2 lần, lần 3 escalate)
```

### SendMessage protocol

- **Lead ↔ teammate**: path chính. Lead wake; teammate report về `team-lead`.
- **KHÔNG peer-DM**: teammate không tự DM teammate khác trừ khi lead chỉ định trong brief.
- **Format wake**: luôn include `task #N` để teammate biết `TaskGet(N)` ngay. KHÔNG paste full
  brief vào message — brief nằm trong Task.

### Idle state là bình thường

Teammate idle sau mỗi turn = đang chờ tín hiệu kế, KHÔNG phải bug. Wake lại bằng SendMessage.

### Feedback khi FAIL (diff-style, không mơ hồ)

```
FAIL — re-do với fix:
[FAIL] <criteria>
Hiện tại: <quote dòng/section output>
Expected: <kết quả mong muốn>
Action: <bullet cụ thể teammate cần làm>
```

Không feedback kiểu "làm tốt hơn" / "thiếu chi tiết" — point đến output cụ thể + expected fix.

### Stale-context — protocol tránh

Khi lead re-spawn team (vòng mới sau re-plan), **gửi lại brief đầy đủ** trong SendMessage —
teammate KHÔNG kế thừa history lượt trước. Mọi context cần thiết phải nằm trong brief.

---

## 5. Khi teammate không phản hồi (failure modes)

Debug theo thứ tự — đây là gotcha thường gặp nhất:

1. **Check task status**: `TaskGet(N)`. `pending` → chưa pickup; `in_progress` → đang làm/kẹt;
   `completed` nhưng silent → quên SendMessage report.
2. **Resend với action steps cụ thể**: `SendMessage(to="<role>", message="Task #N — chạy: 1)
   TaskGet(N) 2) TaskUpdate in_progress 3) work 4) TaskUpdate completed + SendMessage report.
   Bắt đầu ngay.")`. Tránh message mơ hồ ("ổn không?", "tiến độ?").
3. **First-spawn delay**: agent đọc đầu phiên trước khi ack — đợi ≥30–45s sau spawn rồi mới
   SendMessage task đầu. Gửi sớm → queue đè → silent.
4. **Verify-already-done**: brief kiểu "deliverable đã có sẵn" → teammate có thể silent vì
   không biết làm gì. Brief phải dặn "nếu verify pass từ trước → vẫn TaskUpdate completed +
   SendMessage 'verified done, no changes' kèm evidence". (Agent body đã có bullet này.)
5. **Escalate**: 2 lần resend không lay → `SendMessage({type: "shutdown_request"})` + re-spawn
   fresh, hoặc lead tự làm inline cho task ngắn (ghi `LEAD-DIY` vào queue).

Mapping triệu chứng → code queue (xem §9): không ack/báo xong = `SILENT`; cần resend =
`SLOW-PICKUP`; quên TaskUpdate = `FORGOT-TASKUPDATE`; làm ngoài scope = `SCOPE`.

---

## 6. Terminal Layout (chia vùng tmux)

Sau `TeamCreate` + spawn N teammate, dùng tmux để sắp pane (tmux tự tạo pane khi spawn agent).
Chạy từ pane lead (pane `1`). Tested Ubuntu + tmux 3.x. Block 1 = setup mới; Block 2 = sau khi
kill 1 pane (renumber + re-layout).

### N=2 — main + 2 pane (stack dọc phải)

```
┌──────────────┬────────────┐
│              │ tm1 (p2)   │
│  main (p1)   ├────────────┤
│              │ tm2 (p3)   │
└──────────────┴────────────┘
```
```bash
# Block 1
tmux select-layout main-vertical
# Block 2 (sau kill 1 pane)
tmux move-window -r -s 1:1 && tmux select-layout main-vertical
```

### N=3 — main + 3 pane (stack dọc phải)

```
┌──────────────┬────────────┐
│              │ tm1 (p2)   │
│  main (p1)   ├────────────┤
│              │ tm2 (p3)   │
│              ├────────────┤
│              │ tm3 (p4)   │
└──────────────┴────────────┘
```
```bash
tmux select-layout main-vertical                                   # Block 1
tmux move-window -r -s 1:1 && tmux select-layout main-vertical     # Block 2
```

### N=4 — main + 2×2 grid

```
┌──────────────┬──────────┬──────────┐
│              │ tm1 (p2) │ tm2 (p3) │
│  main (p1)   ├──────────┼──────────┤
│              │ tm3 (p4) │ tm4 (p5) │
└──────────────┴──────────┴──────────┘
```
```bash
# Block 1
tmux select-layout main-vertical && tmux join-pane -h -s :.3 -t :.2 && tmux join-pane -h -s :.5 -t :.4
# Block 2
tmux move-window -r -s 1:1 && tmux select-layout main-vertical && tmux join-pane -h -s :.3 -t :.2 && tmux join-pane -h -s :.5 -t :.4
```

### N=5 — full chain (main + 2+2+1)

```
┌──────────────┬──────────┬──────────┐
│              │ tm1 (p2) │ tm2 (p3) │
│  main (p1)   ├──────────┼──────────┤
│              │ tm3 (p4) │ tm4 (p5) │
│              ├──────────┴──────────┤
│              │      tm5 (p6)       │
└──────────────┴─────────────────────┘
```
```bash
# Block 1 (pane 6 full-width row 3) — resize-pane cuối nâng chiều cao tm5 (mặc định bị lùn)
tmux select-layout main-vertical && tmux join-pane -h -s :.3 -t :.2 && tmux join-pane -h -s :.5 -t :.4 && tmux resize-pane -t :.6 -y 18
# Block 2
tmux move-window -r -s 1:1 && tmux select-layout main-vertical && tmux join-pane -h -s :.3 -t :.2 && tmux join-pane -h -s :.5 -t :.4 && tmux resize-pane -t :.6 -y 18
```

### N=6 — main + 3×2 grid

```
┌──────────────┬──────────┬──────────┐
│              │ tm1 (p2) │ tm2 (p3) │
│  main (p1)   ├──────────┼──────────┤
│              │ tm3 (p4) │ tm4 (p5) │
│              ├──────────┼──────────┤
│              │ tm5 (p6) │ tm6 (p7) │
└──────────────┴──────────┴──────────┘
```
```bash
# Block 1 — nối từng cặp dòng (mở rộng pattern N=4: thêm 1 join cho row 3)
tmux select-layout main-vertical && tmux join-pane -h -s :.3 -t :.2 && tmux join-pane -h -s :.5 -t :.4 && tmux join-pane -h -s :.7 -t :.6
# Block 2
tmux move-window -r -s 1:1 && tmux select-layout main-vertical && tmux join-pane -h -s :.3 -t :.2 && tmux join-pane -h -s :.5 -t :.4 && tmux join-pane -h -s :.7 -t :.6
```

### N=7 — max roster (main + 3×2 + 1)

```
┌──────────────┬──────────┬──────────┐
│              │ tm1 (p2) │ tm2 (p3) │
│  main (p1)   ├──────────┼──────────┤
│              │ tm3 (p4) │ tm4 (p5) │
│              ├──────────┼──────────┤
│              │ tm5 (p6) │ tm6 (p7) │
│              ├──────────┴──────────┤
│              │      tm7 (p8)       │
└──────────────┴─────────────────────┘
```
```bash
# Block 1 (pane 8 full-width row 4) — resize cuối nâng chiều cao tm7 (như N=5)
tmux select-layout main-vertical && tmux join-pane -h -s :.3 -t :.2 && tmux join-pane -h -s :.5 -t :.4 && tmux join-pane -h -s :.7 -t :.6 && tmux resize-pane -t :.8 -y 18
# Block 2
tmux move-window -r -s 1:1 && tmux select-layout main-vertical && tmux join-pane -h -s :.3 -t :.2 && tmux join-pane -h -s :.5 -t :.4 && tmux join-pane -h -s :.7 -t :.6 && tmux resize-pane -t :.8 -y 18
```

> ⚠️ **N=6/N=7 trên thực tế không xảy ra trong 1 session** vì mode-separation (D-S4): branch-build
> dùng tối đa 5 vai (full chain), self-mod dùng 4 vai (planner→cto→self-builder→self-tester) — KHÔNG
> trộn chung session. Hai layout này là dự phòng/future-proof. N=6/N=7 mở rộng đúng pattern N=4/N=5
> (chưa chạy thử live tmux — nếu index lệch sau renumber, dùng `tmux select-layout tiled` làm fallback).

**Spawn order = pane index**: spawn theo thứ tự vai trong chain để pane `2..N+1` khớp vai. Pane `1`
luôn là lead.
- Branch full chain: researcher → planner → cto → builder → tester (pane `2..6`).
- Self-mod chain: planner → cto → self-builder → self-tester (pane `2..5`).

Zellij/Windows: adapt thủ công.

---

## 7. Plan-approval mode (PASS criteria mỗi vai)

Lead **không accept thẳng** output teammate — mọi handoff qua gate:

| Vai | PASS khi |
|---|---|
| researcher | 4 mục đầy đủ; "Đã biết" nêu mục tiêu cụ thể; rủi ro có bằng chứng; `open_questions[]` chỉ câu thực chặn |
| planner | Goal 1 câu đo được; mỗi Done-criteria có cách kiểm khách quan; Steps = WHAT; là markdown KHÔNG JSON |
| cto | Pipeline (node/edge/when) + roster từ `catalog/`; cấu trúc file `projects/<branch>/`; văn xuôi KHÔNG build-spec |
| builder | `workflow.json`+`agents/*.md` ghi `projects/<branch>/`; `run.ps1 validate` exit 0 + `run -Mock` done; báo lệnh engine + done-criteria |
| tester | `CHECK_RESULT` rõ; evidence = exit-code/output `run.ps1 validate/run -Mock` (KHÔNG cảm tính); đã ghi memory |
| **self-builder** | Files đổi nằm trong scope cho phép; regression gate PASS (`selftest`+`validate hello`+`run -Mock`); re-spawn smoke PASS (nếu đụng `.claude/agents/*.md`); output nêu danh sách file + delta + gate evidence; KHÔNG auto-commit |
| **self-tester** | `SELF_CHECK_RESULT: pass\|fail` đúng format; bảng done-criteria có evidence thực tế; memory ghi (patterns/mistakes/context); changelog draft chuẩn bị (khi pass) — KHÔNG tự append `global.md` |

FAIL bất kỳ → feedback diff-style (§4) + re-spawn. Tối đa 2 vòng, lần 3 → escalate user.

---

## 8. Anti-patterns

**Lead:**
1. **Chạy 1 lượt linear rồi quên** — đúng phải drive TaskList loop, gate sau mỗi handoff, lặp tới khi TaskList rỗng.
2. **Spawn thừa teammate** — bug fix nhỏ không cần đủ 5 vai. Áp rubric §1 trước spawn.
3. **Brief thiếu done-criteria** — tester không biết kiểm gì → phán cảm tính. Luôn ghi done_criteria đo được.
4. **Không chờ ack / không gate** — tiếp bước kế khi chưa có report → mất sync.
5. **Tự accept verdict** ("trông ổn") — luôn để tester chạy check khách quan.
6. **Lead-DIY vượt ngưỡng** — tự build/code task phức tạp. Exception: trivial < 10 dòng + ≤ 3 file + scope rõ (ghi `LEAD-DIY` queue).
7. **Spawn parallel khi có dependency** — tester không chạy khi builder chưa report (test sai version). Sequential khi output bước trước là input bước sau.

**Teammate:**
8. **Trao đổi build-spec / plan-as-data JSON giữa teammate** (planner/cto) — tàn dư cũ; giao tiếp prose. (Builder ghi `workflow.json` là artifact chi nhánh — KHÁC, hợp lệ.)
8b. **Build app trực tiếp** (builder) — index.html/src app... SAI vai. HQ dựng CHI NHÁNH (workflow.json + agents); app là việc chi nhánh.
9. **Silent-complete** — xong không SendMessage → team treo.
10. **Tự thoát không chờ shutdown** — mất kết quả cuối.
11. **Phán "có vẻ pass"** (tester) — gate phải từ exit-code/output thật.
12. **Gọi `run.ps1 autobuild`** (builder) — không còn tồn tại (đã xóa); tự viết `workflow.json` bằng Write/Edit, smoke-check bằng `run.ps1 validate`. **Sửa `engine/*.ps1`** — engine cố định, chỉ GỌI (ngoại lệ: `hq-self-builder` sau gate đầy đủ).
13. **Ghi vào `company/memory/`** — nhầm engine store; HQ-team ghi `.claude/memory/`.
14. **Mode-separation vi phạm** (self-builder) — chạy self-mod chung session với branch-build; đụng `projects/` (vùng branch). Vi phạm D-S4.
15. **Recursion không kiểm soát** (self-builder) — tự đề xuất + áp self-mod liên tục không có user-request tường minh. Self-mod chỉ theo yêu cầu user, gate mỗi lần.
16. **Auto-commit sau self-mod** (lead/self-builder) — vi phạm D-S2. Luồng đúng: gate xanh → `git diff` cho user → user duyệt → commit. Lead trình diff, KHÔNG commit ngầm.
17. **Branch-builder tự cho phép mình sửa `engine/`** — nới bất biến CHỈ áp cho `hq-self-builder` sau gate. `hq-builder` TUYỆT ĐỐI cấm đụng `engine/` và `.claude/`.

---

## 9. Issue queue (hành vi teammate)

File: `company/issues/team-issues-queue.md` (gom cùng các loại issue khác trong `company/issues/` —
xem `company/issues/README.md`). Khác `mistakes.md` (code bug) / `patterns.md` (code pattern):
queue chỉ về **cách agent behave** trong coordination.

### Format
```markdown
## <YYYY-MM-DD HH:MM> — <CODE> — <slug ngắn>
- **Teammate**: hq-<vai>
- **Triệu chứng**: <output lệnh / hành vi sai>
- **Root cause**: <nếu biết>
- **Trạng thái**: open | investigating | resolved
- **Fix**: <hành động / target sửa: agent body / playbook / brief template>
```

### Codes
`SILENT` (không ack/báo xong) · `SLOW-PICKUP` (cần resend) · `FORGOT-TASKUPDATE` · `STALE`
(context cũ) · `FORM` (JSON/build-spec thay vì văn xuôi) · `SCOPE` (ngoài brief) · `GATE`
(tester phán cảm tính) · `STORE` (nhầm memory store) · `BUILD` (engine-build) · `LEAD-DIY` ·
`NO-SHUTDOWN-RESP` · `OTHER`.

### Trigger review
Soft: mỗi debrief lead scan + append. Hard: ≥5 entry open, hoặc ≥3 cùng (agent, code), hoặc 1
code lặp >1 trong session. Resolved entry: prefix `[RESOLVED YYYY-MM-DD edit:<target>]`, KHÔNG
xóa (track recurrence). Hard trigger → đề xuất fix vào agent body (user-approve) hoặc playbook
(lead tự gate).

---

## 10. Build-deliverable contract — HQ dựng CHI NHÁNH

> Chi tiết: skill `build-verify` (`.claude/skills/build-verify/SKILL.md`).
>
> ⚠️ **Deliverable HQ = một CHI NHÁNH, KHÔNG phải app.** HQ ghi `workflow.json` + `agents/*.md`
> (từ `catalog/`) + scaffold vào `projects/<branch>/`. Chi nhánh ấy sau này mới build app/web.

**Builder** — output `projects/<branch>/` (gitignored, regen-được): `workflow.json` (pipeline) +
`agents/<role>.md` (roster từ `catalog/`) + scaffold. Write/Edit TRỰC TIẾP (KHÔNG `run.ps1
autobuild` — đã xóa). Smoke-check: `cd company/engine && pwsh ./run.ps1 validate <branch>` exit 0
+ `run <branch> "x" -Mock` done. KHÔNG sửa `engine/*.ps1`. KHÔNG build app trực tiếp. Xong → báo
tester kèm lệnh engine + done-criteria.

**Tester** — verify chi nhánh bằng engine: `pwsh ./run.ps1 validate <branch>` (exit 0) +
`run <branch> "x" -Mock` (done) + (nếu cần) `check` (output_keys non-empty). Nguồn sự thật =
exit-code + output engine. `-Mock` (offline, không token). In `CHECK_RESULT: pass|fail`. Ghi memory.

**Engine = vật liệu + công cụ verify của HQ** — vì chi nhánh CHÍNH LÀ workflow engine, `run.ps1
validate/run/check` là đường verify mặc định (không còn "ngoại lệ"). Engine là code cố định: chỉ
GỌI `run.ps1`, KHÔNG sửa `engine/*.ps1`. _(Ngoại lệ: `hq-self-builder` được sửa sau gate — xem §Ranh giới nới bất biến trong `hq-master.md`.)_

**Self-mod deliverable contract** (khi lead spawn self-mod chain):

- **`hq-self-builder`** — Write/Edit file HQ trong scope cho phép (`.claude/`, `engine/`, `catalog/`, `CLAUDE.md`, `README.md`, `app/`). KHÔNG đụng `projects/` (vùng branch). Chạy regression gate: `selftest` PASS + `validate hello` exit 0 + `run hello -Mock` done. Nếu đụng `.claude/agents/*.md`: báo lead chạy re-spawn smoke. KHÔNG auto-commit. Xong → báo `hq-self-tester`.
- **`hq-self-tester`** — verify bằng regression gate độc lập (chạy lại, không tin builder), map từng done-criteria vào bằng chứng thực tế, in `SELF_CHECK_RESULT: pass|fail`, ghi memory, chuẩn bị changelog entry. Nếu đụng `.claude/agents/*.md`: báo lead chạy re-spawn smoke + chờ kết quả.
- **Lead sau SELF_CHECK_RESULT pass**: trình `git diff` cho user → chờ user duyệt → commit (hoặc user tự commit). Append changelog entry vào `.claude/memory/global.md` sau khi user approve.
- **Gate fail**: self-tester báo lead → lead quyết định `git checkout --` restore hoặc brief lại self-builder. KHÔNG tự proceed.

---

## 11. Memory protocol

> Chi tiết: skill `hq-memory` (`.claude/skills/hq-memory/SKILL.md`).

### Store HQ-team: `.claude/memory/`

| File | Ai ghi | Khi nào |
|---|---|---|
| `context.md` | Lead / tester | Cuối task — trạng thái, quyết định, deliverable đang build |
| `mistakes.md` | Lead / tester | Khi fail thật — build fail, thiết kế hỏng, lỗi tái phạm |
| `patterns.md` | Lead / tester | Khi pass — pattern thành công, cách build hiệu quả |
| `global.md` | Lead | Cross-cutting — quyết định kiến trúc, quy ước chung |

**⚠️ KHÔNG nhầm với engine branch store** (`company/memory/` + `<project>/memory/` do
`memory.ps1` quản). HQ-team KHÔNG ghi vào đó.

### Đọc đầu phiên (lead + relevant teammate)
```bash
cat .claude/memory/context.md
cat .claude/memory/mistakes.md    # nếu build mới
cat .claude/memory/patterns.md    # nếu cto/planner cần
```
Cap N=10 entry mới nhất (file giữ toàn bộ lịch sử).

### Ghi cuối task — format bắt buộc
```
## <YYYY-MM-DD HH:MM> — <slug>
<nội dung>
```
Dùng `>>` (append) — **KHÔNG BAO GIỜ `>`** (overwrite mất lịch sử).

### Changelog self-mod — `.claude/memory/global.md`

Mỗi lần self-mod hoàn tất (user duyệt + commit), lead append 1 entry vào `global.md`:

```markdown
## <YYYY-MM-DD HH:MM> — self-mod/<slug-ngắn>

**What**: <1-2 dòng: files thay đổi và tính chất>
**Why**: <lý do / yêu cầu user>
**Files**: `<file1>`, `<file2>`, ...
**Gate result**: selftest PASS • validate hello exit 0 • run -Mock done [• re-spawn smoke PASS]
**Commit**: <commit hash>
```

`hq-self-tester` chuẩn bị draft → lead append sau khi user approve (KHÔNG auto-append trước đó).

---

## Tham chiếu nhanh

- Agent Teams cần `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (đã set trong `.claude/settings.json`) + Claude Code v2.1.32+.
- Flow + roster + ranh giới engine: `hq-master.md`.
- Agent body (self-contained, lead không cần repeat protocol): `.claude/agents/hq-*.md`.
- Tool: `TeamCreate` / `TeamDelete` / `Agent` / `SendMessage` / `TaskCreate` / `TaskUpdate` / `TaskGet` / `TaskList` / `TaskOutput` / `TaskStop`.
