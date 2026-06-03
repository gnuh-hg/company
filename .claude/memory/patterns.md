# patterns — HQ-team

> Pattern thành công tái dùng (loại request → cách build hiệu quả).
> Format entry: `## <YYYY-MM-DD HH:MM> — <slug>`. Cap N=10 khi đọc. Xem `README.md`.

<!-- entries below, mới nhất ở cuối -->

## 2026-06-03 15:39 — todo-web-branch-pass

Chi nhánh todo-web (pipeline v1, 5 node: story→flow→tasks→fe→report) validate exit 0 + run -Mock done (5 lượt, terminal=report) + check exit 0 (5 output_key non-empty). Cấu trúc: workflow.json + agents/{pm,ux,tech-lead,frontend-developer,qa-functional}.md. Verify pattern: chạy 3 lệnh tuần tự (validate→run -Mock→check) từ company/engine/, đọc exit-code + output thực tế.
