# hq/skills — Bảng ánh xạ skill → lệnh engine có sẵn

> 5 "skill" mà agent HQ dùng. **KHÔNG phải engine code mới** — mỗi skill là một **convention**: agent gọi
> lệnh `run.ps1` / cơ chế engine đã có (Phase 0–M). Giữ bất biến #4 (một surface lệnh `run.ps1`) + #1
> (engine cố định, agent chỉ prompt). Bảng này là tham chiếu chung cho `coo/planner/cto/builder/tester`.

---

## Bảng ánh xạ

| Skill | Ai dùng | Ánh xạ vào (lệnh / cơ chế có sẵn) | Ghi chú |
|---|---|---|---|
| **scaffold** | `builder` | `pwsh "<ENGINE_RUN>" build <spec-file> projects/<name>` (`ENGINE_RUN` = đường tuyệt đối tới `run.ps1`, lấy từ input) → `Invoke-BuildSpec` (copy `catalog/<role>.md`→`agents/<id>.md` + `Expand-Pattern` stamp pattern + nối `edges[]` + sinh `workflow.json`). | Validate-trước-khi-ghi: `Test-BuildSpec` chạy trong `Invoke-BuildSpec`, spec hỏng → throw không chạm filesystem. Deterministic. **outName dạng `projects/<name>` (có `/`)** → engine ghi tương đối cwd → branch rơi vào workspace hiện tại (sandbox khi real-E2E), không rò ra `company/projects` gốc. |
| **patch** | `builder` | `Write`/`Edit` trực tiếp trong `<project>/` (agents + workflow.json). | Chỉ `builder` có `allowedTools: [Write,Edit]` + `permission_mode: acceptEdits`. Không đụng `engine/*.ps1`. |
| **diagnose** | `tester`, `planner` | Đọc reason máy-đọc-được từ output `run.ps1 check` (tầng cấu trúc, exit = số tiêu chí fail) + `run.ps1 trial` (tầng trial, assert `trial[]`). | Reason chỉ đúng tiêu chí/tầng fail → planner re-plan đúng chỗ, builder patch đúng chỗ. |
| **run-test** | `tester` | `run.ps1 check <project>` (Test-StructuralGate) + `run.ps1 trial <project>` (Copy-ToSandbox → Invoke-Trial real → teardown). | 2 tầng: cấu trúc-mock → trial-real (Phase 2). Verdict `pass`/`fail`. |
| **report** | `tester` | Node `record` (`memory_write: mistakes\|patterns\|context`) → `Write-MemoryEntry $ProjectDir $Type $Content` (append block date-stamped đúng tầng). | Memory 2 tầng Phase M: HQ-global (`company/memory/`) + per-branch (`<project>/memory/context.md`). Đọc lại qua `{{mem_*}}`. |

---

## Ranh giới skill ↔ engine

- Skill **không** thêm khả năng mới cho engine — chỉ đặt tên cho việc "agent X gọi lệnh Y". Mọi lệnh ở bảng đều đã tồn tại (Phase 0–M).
- Phần **ghi file** duy nhất an toàn: `scaffold` (engine `Invoke-BuildSpec` deterministic) + `patch` (`builder` Write/Edit). Các agent khác read-only.
- `diagnose`/`run-test`/`report` đều **read-only về code** — chỉ chạy lệnh kiểm + đọc reason + append memory (không sửa source chi nhánh).

## Liên quan

- Lệnh engine: [`../README.md`](../README.md) (surface `run.ps1`).
- Build-spec + Builder engine: [`build-spec.md`](build-spec.md) + `engine/spec.ps1` (`Invoke-BuildSpec`).
- Tester: `engine/check.ps1` + `engine/sandbox.ps1` (Phase 2). Memory: `engine/memory.ps1` (Phase M).
- Agent dùng bảng này: [`agents/`](agents/) (`coo/planner/cto/builder/tester`).
