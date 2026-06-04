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
