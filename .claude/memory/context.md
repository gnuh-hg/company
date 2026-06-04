# context — HQ-team

> Bối cảnh làm việc hiện tại của HQ-team: branch nào đang build, trạng thái, quyết định gần đây.
> Format entry: `## <YYYY-MM-DD HH:MM> — <slug>`. Cap N=10 khi đọc. Xem `README.md`.

<!-- entries below, mới nhất ở cuối -->

## 2026-06-03 15:39 — todo-web-verify-pass

Branch: todo-web, vòng 1. Verdict: PASS. validate exit 0, run -Mock done (path story→flow→tasks→fe→report), check exit 0 (5/5 output_key non-empty).

## 2026-06-03 20:35 — J.1-verify-pass

Self-mod J.1 verify. File đổi: engine/workflow.ps1. Verdict: PASS. selftest 9/9, validate hello/loopy exit 0, run hello -Mock done, run branchy -Mock done (ENV `tier:gt1000`). Get-RouterChoices @ line 131 + wire @ line 536 guard if(!Mock). Vòng 1.

## 2026-06-03 20:45 — J.2-verify-pass

Self-mod J.2 verify. File đổi: engine/workflow.ps1. Verdict: PASS. selftest 9/9, validate hello/branchy exit 0, run -Mock done (mock bất biến), Write-RouteIssue unit-test ghi+parse OK, guard if(!Mock) line 622, throw text nguyên line 629. Test entry đã dọn.

## 2026-06-03 20:53 — J.3-verify-pass

Self-mod J.3 verify. File đổi: engine/workflow.ps1. Verdict: PASS. selftest 9/9, validate hello/branchy/loopy exit 0, run hello/branchy/loopy -Mock done, Get-RouterPayload unit test 3 case OK, ConvertTo-RouterLabel nguyên vẹn (last non-blank line). Wire line 678 guard if(type=router) không Mock-gated (payload="" cho mock 1-dòng → bất biến). Vòng 1.

## 2026-06-03 21:06 — J.4-verify-pass

Self-mod J.4 verify. Files đổi: engine/validate.ps1, engine/test-runner.ps1, examples/branchy/workflow.json + agents/. Verdict: PASS. selftest 10/10 (mục #10 branchy/2-part-protocol PASS, payload-in-result=True), validate hello/branchy/loopy/approval-demo exit 0 sạch. WARN additive: {{foo_payload}} không có router foo → WARN + exit 0; hello/branchy không WARN. Vòng 1.

## 2026-06-03 21:17 — J.5-final-verify-pass

Self-mod J.5 (final) verify. Files đổi: README.md, CLAUDE.md, plan/hq-v2/ROADMAP.md, plan/hq-v2/phase-j/CHECKPOINT.md. Verdict: PASS. selftest 10/10, validate hello/branchy/loopy exit 0, run -Mock done. Docs: README có auto-inject + 2-phần; CLAUDE.md 4 rows cập nhật; ROADMAP Phase J ✅ DONE; CHECKPOINT 5/5 + 5 log entries. Phase J toàn bộ verified. Changelog draft gửi lead.

## 2026-06-04 01:06 — J2.1-verify-pass

Self-mod J2.1 verify. Files đổi: engine/workflow.ps1, engine/validate.ps1, 6 patterns/*.json, examples/{loopy,branchy,edit-demo,p-brain}/workflow.json. Verdict: PASS. selftest 10/10, validate hello/branchy/loopy/edit-demo/approval-demo exit 0, run branchy (tier:gt1000) + loopy (verdict:pass) -Mock done. grep type:router rỗng trong patterns+fixtures. Test-NodeBranches 9 occurrences. validate.ps1 tolerate type:router đúng thiết kế S1 (REJECT defer S2). .runs/ đã dọn. Vòng 1.

## 2026-06-04 02:05 — J2.2-verify-pass

Self-mod J2.2 verify. Files đổi: engine/validate.ps1, engine/viz.ps1, engine/graph.ps1, README.md, CLAUDE.md, plan/hq-v2/ROADMAP.md, plan/hq-v2/phase-j2/CHECKPOINT.md. Verdict: PASS. selftest 10/10, validate hello/branchy/loopy/edit-demo/p-brain/approval-demo exit 0, viz branchy (tier=branch) + loopy (verdict=branch) đúng diamond. Reject proof: fixture scratch type:router → exit=6 "type 'router' đã bỏ (J2)" + fixture đã xoá. grep type:router rỗng trong patterns/examples. Docs: ROADMAP J2 ✅ DONE; CLAUDE.md row validate.ps1/viz.ps1 cập nhật. Vòng 1. Không đụng .claude/agents → không cần re-spawn smoke.

## 2026-06-04 02:10 — K.1-verify-pass

Self-mod K.1 verify. Files đổi: engine/validate.ps1 (pause enum none|always|ask + user_answer ReservedKeys), engine/workflow.ps1 Initialize-Context (pre-seed user_answer=''), examples/ask-demo/ (workflow.json + agents/clarify.md + agents/build.md). Verdict: PASS. selftest 10/10, validate ask-demo exit 0, validate hello exit 0, run hello -Mock done. Ca âm: pause:bogus → exit=1 + lỗi đúng "không hợp lệ (chỉ chấp nhận: none, always, ask)". ReservedKeys + pre-seed xác nhận bằng đọc file (line 37 validate.ps1 + line 53 workflow.ps1). .runs/ đã dọn. Không đụng .claude/agents → không cần re-spawn smoke. Vòng 1.

## 2026-06-04 02:15 — K.2-verify-pass

Self-mod K.2 verify. Files đổi: engine/workflow.ps1 (Get-AskRequest hàm thuần + pause:ask pause-path), engine/graph.ps1 (pause field passthrough). Verdict: PASS. state.status='awaiting_input', awaiting.kind='input', awaiting.question='Bạn muốn màu sắc gì?'. events.ndjson: type:awaiting kind:input seq=3. spec.txt CHƯA ghi (output_key không write khi pause). Thứ tự: node_output (line 720) → pause:ask check (line 722) → return early trước output_key (line 748). approval-demo PASS (D.3 bất biến). selftest 10/10. .runs/ đã dọn. Vòng 1.

## 2026-06-04 09:20 — K.3-verify-pass

Self-mod K.3 verify. Files đổi: engine/workflow.ps1 (Invoke-Workflow -Answer param + awaiting_input resume nhánh TÁCH riêng D.3), engine/run.ps1 (-Answer flag + resume truyền -Answer). Verdict: PASS. Round-trip: run1→awaiting_input; resume -Answer "dùng màu xanh" → state.done, spec.txt+result.txt tồn tại, 2-clarify.prompt.txt chứa "dùng màu xanh", event resumed kind=input answer="dùng màu xanh". D.3 bất biến: approval-demo selftest PASS. Tách nhánh K.3/D.3 xác nhận: guard `if (-not $awaitingInputResume -and $state.status -eq 'awaiting')` line 484. selftest 10/10. .runs/ đã dọn. Vòng 1.

## 2026-06-04 09:28 — K.4-verify-pass

Self-mod K.4 verify. Files đổi: engine/workflow.ps1 (pause:always run-then-gate + AutoApprove skip always + fail-rõ ask), examples/always-demo/ (workflow.json + agents). Verdict: PASS. always-demo: run→state.status='awaiting', awaiting.kind='approval', work_out.txt tồn tại TRƯỚC pause (line 784 trước line 807). resume -Decision approve → done + result.txt. AutoApprove+always → skip (not pause) exit=0. AutoApprove+ask+marker → fail-rõ exit=1 "headless không thể tự trả lời". approval-demo D.3 PASS. selftest 10/10. .runs/ đã dọn. Vòng 1.

## 2026-06-04 09:35 — K.5-verify-pass

Self-mod K.5 verify. Files đổi: engine/run.ps1 (exit=4 + hint -Answer + câu hỏi khi awaiting_input), engine/status.ps1 (surface awaiting_input: in question + hint -Answer), engine/events.ps1 (comment kind=approval|input, không thêm loại mới), engine/test-runner.ps1 (selftest #11 ask-demo/done-gate, 10→11 mục). Verdict: PASS. run ask-demo mock → exit=4, in câu hỏi+hint. resume -Answer "xanh" → done. status surface awaiting_input đúng. selftest 11/11 (mục mới ask-demo/done-gate: run1=awaiting_input run2=done answer-in-prompt=True). approval-demo D.3 + branchy J.4 PASS. .runs/ đã dọn. Vòng 1.

## 2026-06-04 09:50 — K.6-final-verify-pass

Self-mod K.6 verify (CUỐI Phase K). Files đổi K.6: engine/viz.ps1 (pause marker), CLAUDE.md, README.md, ROADMAP.md. Done-gate tổng 4/4: (1) ask mock→awaiting_input→resume→done+prompt-xanh; (2) always mock→awaiting kind=approval+work_out.txt pre-pause→resume→done; (3) selftest 11/11 PASS; (4) validate hello/run hello + graph ask-demo(⏸ask)+always-demo(⏸always) không lỗi. Git status: engine/*.ps1 + ask-demo + always-demo + docs — KHÔNG đụng projects/ hay .claude/agents/. CLAUDE.md invariant #2 có pause+user_answer reserved. ROADMAP Phase K ✅ DONE. Phase K hoàn toàn verified. Vòng 1.

## 2026-06-04 10:25 — I.A.1-verify-pass

Self-mod I.A.1 verify. Files đổi: engine/lib/claude.ps1 ([ref]$UsageOut + mock proxy + real usage parse), engine/workflow.ps1 ($nodeUsage + -UsageOut + node_usage event), engine/events.ps1 ('node_usage' in EventTypes). Verdict: PASS. selftest 11/11, validate hello exit 0, run -Mock done. events.ndjson: 2 node_usage entries (node a: prompt_chars=1/output_chars=15; node b: prompt_chars=17/output_chars=31; mock=true). Backward-compat: PSBoundParameters.ContainsKey('UsageOut') guard → callers không truyền -UsageOut nhận string như cũ (selftest+run PASS chứng minh). Không đụng .claude/agents/*.md → no re-spawn smoke. .runs/ đã dọn. Vòng 1.

## 2026-06-04 10:39 — I.A.2-verify-pass

Self-mod I.A.2 verify. Files đổi: engine/tokens.ps1 (NEW: Get-RunTokens/Show-RunTokens + direct-run guard), engine/run.ps1 (dot-source + 'tokens' dispatch + -Run flag + help), plan/hq-v2/phase-i/baseline.md (NEW: 3 fixtures). Verdict: PASS. selftest 11/11, validate hello exit 0, run -Mock done. tokens loopy → 4 node table + TỔNG exit 0 (build:4/15, test:15/27, verdict:27/4, ship:43/55). no-project → exit 2 graceful. dot-source → exit 0 no exec. direct-run → bảng đúng. baseline.md 3 sections (loopy/branchy/web-demo). Không đụng .claude/agents/*.md. .runs/ đã dọn. Vòng 1.

## 2026-06-04 15:02 — I.B.1-verify-pass

Self-mod I.B.1 verify. Files đổi: examples/loopy/agents/verdict-router.md, examples/branchy/agents/tier-router.md, catalog/README.md, plan/hq-v2/phase-i/CHECKPOINT.md. Verdict: PASS. selftest 11/11, validate hello/loopy/branchy exit 0, run -Mock done (verdict-router:pass + tier-router:gt1000). grep model:haiku = 2 fixture. Convention catalog/README.md §model-tiering tồn tại. Wire code-confirmed: Get-AgentFrontmatter→$nodeModel→Invoke-Claude, mock-path skip. Không đụng .claude/agents/*.md → no re-spawn smoke. .runs/ đã dọn. Vòng 1.

## 2026-06-04 15:44 — I.B.2-verify-pass

Self-mod I.B.2 verify. Files đổi: examples/web-demo/workflow.json (schema bỏ {{spec}}, auth bỏ {{spec}}), examples/loopy/workflow.json+agents/ship.md (ship bỏ {{test}}), catalog/README.md (§Guideline tối thiểu-key), baseline.md (§I.B.2), CHECKPOINT.md. Verdict: PASS. selftest 11/11, validate hello/web-demo/loopy/branchy exit 0, run web-demo-Mock 11-node done + run loopy-Mock done. tokens web-demo TỔNG=1403 < 2315 ✓; tokens loopy TỔNG=59 < 157 ✓. Guideline + baseline.md §I.B.2 tồn tại. Sanity trim hợp lý. .runs/ đã dọn. Vòng 1.

## 2026-06-04 16:06 — I.C.1-verify-pass

Self-mod I.C.1 verify. Files đổi: engine/workflow.ps1 (_ref pre-seed+path-set+resume), engine/validate.ps1 (block _ref suffix + WARN), engine/test-runner.ps1 (12 mục, .Contains fix), examples/ref-demo/ (NEW). Verdict: PASS. 2-reader.prompt.txt = path thuần (.../report.txt), không chứa [MOCK:writer]. selftest 12/12 (path-in-prompt=True, fulltext-in-prompt=False). validate block exit=2 + lỗi rõ. Additive: 4 graph cũ path+done bất biến. validate 5 fixture exit 0. .runs/ đã dọn. Vòng 1. Baseline selftest từ I.C.1 = 12/12.

## 2026-06-04 16:36 — I.C.2-verify-pass

Self-mod I.C.2 verify. Files đổi: examples/loopy/agents/verdict-router.md (2-phần shaped), examples/loopy/agents/build.md (verdict_payload), examples/loopy/workflow.json (build input), patterns/README.md (§Giao thức 2-phần), CHECKPOINT.md. Verdict: PASS. 4-build.prompt.txt = "x\nFIX: error on line 42" (payload đích, không có "fail"). 2-loop path: build→test→verdict→build(iter2)→test→verdict→ship. selftest 12/12, validate 5 exit 0. Engine không đổi (fixture+doc only). .runs/ đã dọn. Vòng 1.

## 2026-06-04 16:49 — I.C.3-verify-pass

Self-mod I.C.3 verify. Files đổi: engine/workflow.ps1 (Test-SingleConsumer + comment điểm quyết định line 878), CHECKPOINT.md. Verdict: PASS. 9/9 case đúng (True/False per spec). Lossless: 5 graph -Mock done, output chars y hệt. dot-source: no self-exec + function available. selftest 12/12, validate 5 exit 0. Runtime KHÔNG đổi (keep-full by design). .runs/ đã dọn. Vòng 1.

## 2026-06-04 17:16 — I.D.1-verify-pass

Self-mod I.D.1 verify. Files đổi: plan/hq-v2/phase-i/caching.md (NEW), plan/hq-v2/phase-i/CHECKPOINT.md. Verdict: PASS. caching.md: kết luận rõ (no --cache flag; --exclude-dynamic bị ignored; --betas defer; structure OK; cách đo I.D.2 qua cache_creation/read). Engine không đổi (git status plan/ chỉ 2 file plan; engine changes = từ sessions I.A-I.C). selftest 12/12, validate hello exit 0, run -Mock done. .runs/ đã dọn. Vòng 1. I.D.1 = last session trước real-run gate (I.D.2 user-gate).
