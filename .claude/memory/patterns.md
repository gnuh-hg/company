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
