# patterns — HQ-team

> Pattern thành công tái dùng (loại request → cách build hiệu quả).
> Format entry: `## <YYYY-MM-DD HH:MM> — <slug>`. Cap N=10 khi đọc. Xem `README.md`.

<!-- entries below, mới nhất ở cuối -->

## 2026-06-03 15:39 — todo-web-branch-pass

Chi nhánh todo-web (pipeline v1, 5 node: story→flow→tasks→fe→report) validate exit 0 + run -Mock done (5 lượt, terminal=report) + check exit 0 (5 output_key non-empty). Cấu trúc: workflow.json + agents/{pm,ux,tech-lead,frontend-developer,qa-functional}.md. Verify pattern: chạy 3 lệnh tuần tự (validate→run -Mock→check) từ company/engine/, đọc exit-code + output thực tế.

## 2026-06-03 20:35 — J.1-get-router-choices

Session J.1: engine/workflow.ps1 thêm `Get-RouterChoices` (line 131, hàm thuần trả tập `when` labels đã normalize) + wire suffix bơm choices vào prompt router real-mode (line 536, guard `if ($node.type -eq 'router' -and -not $Mock)`). Mock-path xác nhận bất biến (branchy -Mock với `ENGINE_MOCK_ROUTER="tier:gt1000"` → exit 0). selftest 9/9, validate hello/loopy exit 0, run hello/branchy -Mock done.

## 2026-06-03 20:45 — J.2-write-route-issue

Session J.2: engine/workflow.ps1 thêm `Write-RouteIssue` (line 156 — ghi NDJSON vào company/issues/route-issues.ndjson, fields: ts/run_id/node/raw_output/valid_choices/label_extracted, deterministic không gọi model) + validate site (line 622–631, guard `if ($node.type -eq 'router' -and -not $Mock)` → fail-fast throw sau Write-RouteIssue, throw text giữ nguyên). Mock-path bất biến (branchy -Mock exit 0). Unit test: dot-source + call Write-RouteIssue → parse NDJSON OK. selftest 9/9, validate hello/branchy exit 0, run hello/branchy -Mock done.

## 2026-06-03 20:53 — J.3-get-router-payload

Session J.3: engine/workflow.ps1 thêm `Get-RouterPayload` (line 196 — tách payload từ router output 2-phần, trả "" nếu chỉ 1 dòng) + pre-seed `<k>_payload=""` trong Initialize-Context + restore resume loop line 394 + wire store line 678–680 (`if type=router` — cả Mock+real). ConvertTo-RouterLabel giữ nguyên. Unit test 3 case: multi-line→payload OK, single-label→"", empty→"". Backward-compat: loopy -Mock done. selftest 9/9, validate hello/branchy/loopy exit 0.

## 2026-06-03 21:06 — J.4-branchy-2part-selftest10

Session J.4: engine/test-runner.ps1 thêm mục #10 `branchy/2-part-protocol` (selftest 9→10). engine/validate.ps1 thêm WARN khi `{{<key>_payload}}` dùng nhưng không có router output_key=<key> (additive, exit vẫn 0). examples/branchy/{workflow.json, agents/tier-router.md, agents/output.md} cập nhật stub 2-phần. selftest 10/10, validate hello/branchy/loopy/approval-demo exit 0, run -Mock done. WARN fires đúng với fixture sai, không fires với hello/branchy.

## 2026-06-03 21:17 — J.5-docs-closeout

Session J.5 (final close-out): README.md thêm §"Router choices auto-inject" + §"Giao thức 2-phần: payload + nhãn route". CLAUDE.md sửa 4 hàng: workflow.ps1 (3 hàm J), test-runner.ps1 (10 mục), validate.ps1 (_payload warn), phase-j (✅ DONE 2026-06-03). ROADMAP Phase J = ✅ DONE. CHECKPOINT 5/5 sessions done + 5 log entries. selftest 10/10, validate hello/branchy/loopy exit 0, run -Mock done. Phase J hoàn thành.

## 2026-06-04 01:06 — J2.1-edge-routing-pass

Session J2.1: engine/workflow.ps1 thêm `Test-NodeBranches $Graph $NodeId` (line ~70, outdeg≥2, dot-source-safe) + thay 6 chỗ `$node.type -eq 'router'` → `Test-NodeBranches` (pre-seed _payload, Select-NextNode, resume restore, bơm choices, validate-nhãn, store _payload). validate.ps1 rewrite luật out-edge (outdeg-based, TẠM tolerate type:router). Migrate gỡ `type:"router"` khỏi 6 patterns/*.json + examples/{loopy,branchy,edit-demo,p-brain}/workflow.json. selftest 10/10, validate hello/branchy/loopy/edit-demo/approval-demo exit 0, run branchy -Mock (tier:gt1000) + loopy -Mock (verdict:pass) done, grep type:router rỗng. Test-NodeBranches count=9 (≥7 yêu cầu).

## 2026-06-04 02:05 — J2.2-reject-viz-pass

Session J2.2: engine/validate.ps1 thêm REJECT type:"router" (lỗi: "type 'router' đã bỏ (J2) — node có ≥2 cạnh ra tự là điểm rẽ; xoá field type") + type lạ khác worker/approval → error. engine/viz.ps1 diamond/branch tag theo outdeg≥2 thay type (ASCII `(branch)` thay `(router)`). engine/graph.ps1 tag `branch` theo outdeg. README/CLAUDE.md/ROADMAP/CHECKPOINT cập nhật docs. Reject-proof: fixture scratch type:router → validate exit=6 + lỗi đúng. grep type:router rỗng. selftest 10/10, validate hello/branchy/loopy/edit-demo/p-brain/approval-demo exit 0.

## 2026-06-04 02:10 — K.1-pause-enum-pass

Session K.1: engine/validate.ps1 thêm $script:PauseValues = @('none','always','ask') + guard kiểm tra pause trên approval node (REJECT) + enum check (line 192-200). engine/workflow.ps1 Initialize-Context pre-seed user_answer='' (line 51-53). examples/ask-demo/ fixture 3 node (clarify pause:ask → build → terminal). Ca âm validate: pause:bogus → exit=1 lỗi rõ. selftest 10/10, validate ask-demo/hello exit 0, run -Mock done. Fixture bất biến (ca âm dùng /tmp copy).

## 2026-06-04 02:15 — K.2-ask-pause-executor-pass

Session K.2: engine/workflow.ps1 thêm Get-AskRequest (line 225 — parse marker ASK_USER: case-insensitive, trả text sau marker hoặc $null). Pause-path K.2 (line 722-742): sau node_output event, trước output_key write. pause:ask + marker → state.status='awaiting_input' + awaiting.kind='input' + event awaiting kind=input + return early (NO output_key). approval-demo/D.3 PASS bất biến. selftest 10/10. Verify method: ENGINE_MOCK_ROUTER="clarify:ASK_USER:..." → check state.json + events.ndjson + ls rundir (spec.txt absent).

## 2026-06-04 09:20 — K.3-resume-answer-pass

Session K.3: engine/workflow.ps1 Invoke-Workflow thêm [string]$Answer='' param (line 397) + nhánh awaiting_input resume (line 460-482): tiêm $context['user_answer']=$Answer, cursor=awaitInputNode (re-run), đưa lượt awaiting→done. Guard D.3: `if (-not $awaitingInputResume -and $state.status -eq 'awaiting')` (line 484) — hai nhánh MUTUALLY EXCLUSIVE. engine/run.ps1 thêm -Answer flag + truyền vào resume. Verify method: run1 (mock marker) → awaiting_input; resume -Answer "dùng màu xanh" → check 2-clarify.prompt.txt chứa answer + state.done + result.txt + event resumed kind=input. approval-demo D.3 PASS. selftest 10/10.

## 2026-06-04 09:28 — K.4-always-autoapprove-pass

Session K.4: engine/workflow.ps1 pause:always (line 807) — check SAU output_key write (line 784): output_key ghi TRƯỚC pause. awaiting state reuse D.3 (kind='approval'). AutoApprove+always → skip/fall-through. AutoApprove+ask+ASK_USER → throw "headless không thể tự trả lời" exit=1. examples/always-demo/ fixture 2 node (work pause:always → report). Verify: run→awaiting(kind=approval, work_out.txt exists); resume -Decision approve → done+result.txt; AutoApprove→done; AutoApprove ask→fail exit=1. approval-demo/D.3 bất biến. selftest 10/10.

## 2026-06-04 09:35 — K.5-surface-selftest11-pass

Session K.5: run.ps1 return 4 khi awaiting_input + in "⏸ Run dừng — node ... cần câu trả lời:" + câu hỏi + hint "-Answer". status.ps1 awaiting_input: in "Hỏi:", "Câu hỏi:", "Resume: ./run.ps1 resume <proj> -Answer". events.ps1 comment only (kind=approval|input), không loại mới. test-runner.ps1 selftest 10→11 mục: mục #11 "ask-demo/done-gate" inline (run1→awaiting_input, resume -Answer→done, assert answer-in-prompt). selftest 11/11 PASS. Baseline selftest từ K.5 = 11/11.

## 2026-06-04 09:50 — K.6-docs-viz-done-gate-pass

Session K.6 (Phase K final): engine/viz.ps1 thêm tag ASCII `(⏸ask)` / `(⏸always)` trên node worker có pause:ask/always (approval hexagon bất biến). Docs: CLAUDE.md invariant #2 thêm pause+user_answer reserved; bảng file-map 6 rows Phase K; ask-demo/always-demo entries. README §HITL pause-policy. ROADMAP K ✅ DONE. Done-gate 4/4 + git status scope-clean. Phase K pattern: (1) validate K.1 + (2) executor K.2 + (3) resume K.3 + (4) always K.4 + (5) surface K.5 + (6) docs/viz K.6 = hoàn chỉnh pipeline HITL pause-policy. selftest 11/11 baseline từ K.5.

## 2026-06-04 10:25 — I.A.1-usage-capture-pass

Session I.A.1: engine/lib/claude.ps1 thêm [ref]$UsageOut out-param (guard ContainsKey → backward-compat: callers không truyền -UsageOut nhận string như cũ). Mock-path: proxy {prompt_chars, output_chars, mock=true} trả trước return. Real-path: parse .usage JSON từ --output-format json. engine/workflow.ps1 bắt -UsageOut per node + emit event node_usage sau node_output (seq n+1). engine/events.ps1 thêm 'node_usage' vào $script:EventTypes. Verify: events.ndjson hello run có 2 node_usage entries (node a: prompt_chars=1 output_chars=15, node b: prompt_chars=17 output_chars=31, mock=true, non-zero). selftest 11/11, validate hello exit 0, run -Mock done. Không đụng .claude/agents/*.md → không cần re-spawn smoke. Vòng 1.

## 2026-06-04 10:39 — I.A.2-tokens-command-baseline-pass

Session I.A.2: engine/tokens.ps1 (NEW) hàm thuần Get-RunTokens đọc events.ndjson → bảng per-node (agent/prompt_chars/output_chars/proxy_tok) + TỔNG. Direct-run guard: `if ($MyInvocation.InvocationName -ne '.')`. engine/run.ps1 dot-source tokens.ps1 + dispatch 'tokens' (allowlist + case) + -Run flag + help entry. plan/hq-v2/phase-i/baseline.md: 3 fixture (loopy/branchy/web-demo) với số proxy mock làm mốc. Verify: tokens loopy → bảng 4 node + TỔNG exit 0; no-project → exit 2 graceful + help; dot-source → exit 0 no exec; direct-run → bảng đúng; baseline.md 3 sections. selftest 11/11, validate hello exit 0, run -Mock done. Không đụng .claude/agents/*.md → no re-spawn smoke. Vòng 1.

## 2026-06-04 15:02 — I.B.1-model-tier-haiku-pass

Session I.B.1: examples/loopy/agents/verdict-router.md + examples/branchy/agents/tier-router.md thêm `model: claude-haiku-4-5-20251001` frontmatter. catalog/README.md thêm §Convention model-tiering (bảng branching/gate→Haiku, worker→default). Wire: Get-AgentFrontmatter → $nodeModel → Invoke-Claude -Model; comment "Mock-path KHÔNG dùng các cờ này → output mock bất biến." (workflow.ps1 line 697). selftest 11/11, validate hello/loopy/branchy exit 0, run hello/loopy/branchy -Mock done. grep model:haiku = 2 file fixture. Không đụng .claude/agents/*.md → no re-spawn smoke. .runs/ đã dọn. Vòng 1.

## 2026-06-04 15:44 — I.B.2-template-trim-pass

Session I.B.2: bỏ {{spec}} khỏi schema+auth (web-demo), bỏ {{test}} khỏi ship (loopy) trong workflow.json. catalog/README.md §Guideline tối thiểu-key. baseline.md §I.B.2 trước/sau. Kết quả: web-demo TỔNG prompt_chars=1403 < 2315 baseline ✓; loopy TỔNG=59 < 157 baseline ✓. Cascade logic xác nhận: trim schema→cascade api→auth→fe→deploy→qa. Sanity: schema cần tasks (tech-lead chắt lọc spec+design); auth cần api (encode spec); ship sau verdict:pass không cần test log. selftest 11/11, validate 4 fixture exit 0, run -Mock done. Không đụng .claude/agents/*.md → no re-spawn smoke. .runs/ đã dọn. Vòng 1.

## 2026-06-04 16:06 — I.C.1-artifact-by-ref-pass

Session I.C.1: engine/workflow.ps1 thêm _ref pre-seed + post-node path-set + resume restore. engine/validate.ps1 block output_key suffix `_ref` + WARN {{x_ref}} không có x output_key. engine/test-runner.ps1 selftest 11→12 (ref-demo/done-gate, `.Contains` bug fix). examples/ref-demo/ (NEW). Bằng chứng cốt lõi: 2-reader.prompt.txt = PATH thuần (`.../report.txt`), không chứa `[MOCK:writer]`. selftest: path-in-prompt=True, fulltext-in-prompt=False. validate block: exit=2 "suffix reserved cho artifact-by-reference". Additive: hello/loopy/branchy/web-demo không dùng _ref → path+done y hệt. selftest 12/12, validate 5 fixture exit 0. .runs/ + /tmp/test-ref-block đã dọn. Không đụng .claude/agents/*.md → no re-spawn smoke. Vòng 1.

## 2026-06-04 16:36 — I.C.2-handoff-payload-pass

Session I.C.2: examples/loopy/agents/verdict-router.md định dạng 2-phần shaped (fail→FIX:..., pass→gọn). examples/loopy/agents/build.md dùng {{verdict_payload}}. examples/loopy/workflow.json build input {{verdict_payload}} thay {{verdict}}. patterns/README.md §Giao thức 2-phần. Bằng chứng: 4-build.prompt.txt = "x\nFIX: error on line 42" — payload đích, KHÔNG có nhãn "fail". 2-loop route đúng: build→test→verdict(fail)→build(iter2)→test→verdict(pass)→ship. selftest 12/12, validate 5 fixture exit 0. Engine KHÔNG đổi — chỉ fixture+doc. Không đụng .claude/agents/*.md → no re-spawn smoke. .runs/ đã dọn. Vòng 1.

## 2026-06-04 16:49 — I.C.3-single-consumer-pass

Session I.C.3: engine/workflow.ps1 thêm Test-SingleConsumer (~55 dòng) — helper thuần dot-source-safe, trả True khi key có đúng 1 consumer KHÔNG trên cycle. Runtime KHÔNG tự-trim (keep-full by default; trim = opt-in). 9 cases: hello-a=True, hello-b=False(0 consumer), web-demo-spec=False(3 consumer), web-demo-tasks=True, branchy-tier=True, ref-demo-report=True, loopy-build/verdict/test=False(cycle). Điểm quyết định comment line 878-879. Lossless: 5 graph cũ path+done y hệt. selftest 12/12, validate 5 fixture exit 0. dot-source: không self-exec + Test-SingleConsumer available. .runs/ đã dọn. Không đụng .claude/agents/*.md → no re-spawn smoke. Vòng 1.

## 2026-06-04 17:16 — I.D.1-caching-doc-pass

Session I.D.1 (doc-only): caching.md NEW tại plan/hq-v2/phase-i/. Kết luận rõ: (1) không có --cache flag tường minh; (2) --exclude-dynamic-system-prompt-sections bị ignored với --system-prompt-file; (3) --betas defer đến I.D.2 (API-key only); (4) engine hiện tại đúng thứ tự stable-then-variable; (5) cách đo I.D.2 qua cache_creation/cache_read_input_tokens (đã wire I.A.1). Engine không đổi (git status plan/: chỉ caching.md+CHECKPOINT.md). selftest 12/12, validate hello exit 0, run -Mock done. Không đụng .claude/agents/*.md → no re-spawn smoke. .runs/ đã dọn. Vòng 1.
