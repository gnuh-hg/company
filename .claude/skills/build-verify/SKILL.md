---
name: build-verify
description: "Quy ước dựng CƠ SỞ CHI NHÁNH TRỰC TIẾP (Write/Edit workflow.json + agents từ catalog/ + scaffold vào projects/<branch>/) + verify khách quan bằng engine (run.ps1 validate exit 0 + run -Mock done + check). Dùng chung cho builder và tester HQ-team."
---

# Build-Verify — HQ team convention

> Quy ước chung cho **builder** (dựng chi nhánh) và **tester** (verify bằng engine).
>
> ⚠️ **HQ build CHI NHÁNH, KHÔNG build app.** Deliverable HQ = cơ sở một chi nhánh chạy được (`workflow.json` + `agents/*.md` + scaffold); chi nhánh ấy sau này mới build app/web. Builder tự viết `workflow.json` + agents bằng Write/Edit (KHÔNG `run.ps1 autobuild` — đã xóa); engine `run.ps1 validate/run/check` dùng để **kiểm chi nhánh vừa dựng**.

---

## 1. Nơi ghi + cấu trúc chi nhánh

### Output location
```
projects/<branch>/      ← mọi file chi nhánh đặt ở đây
```
- `projects/` gitignored — regen-được, không commit.
- `<branch>` = tên ngắn kebab-case (vd `landing-branch`, `crud-api-branch`). Lead xác nhận tên; builder KHÔNG tự đặt nếu chưa có.

### Cấu trúc một chi nhánh
```
projects/<branch>/
├── workflow.json       # pipeline engine: nodes/edges/entry/max_steps (hoặc pipeline v1)
├── agents/
│   ├── <role>.md       # roster: 1 file/node, phỏng theo catalog/<role>.md
│   └── ...
└── <scaffold>          # README cách chạy, file cấu hình chi nhánh nếu cần
```
- `workflow.json`: chỉ ngữ nghĩa — KHÔNG toạ độ. Graph: mỗi node có `id`/`agent`/`input`/`output_key`; `edges` tường minh (router ≥2 cạnh phải có `when`); `entry`; `max_steps`. Hoặc pipeline v1 (mảng tuần tự).
- `agents/<role>.md`: frontmatter (`name`, model nếu cần) + system prompt. Lấy gốc từ `catalog/<role>.md` rồi chỉnh cho domain chi nhánh.
- Tham khảo mẫu: `examples/web-demo/` (chi nhánh lắp tay từ catalog), `examples/loopy/` (router + loop + max_steps).

---

## 2. Builder — dựng chi nhánh trực tiếp

### Nguyên tắc
- **Write/Edit trực tiếp** `workflow.json` + `agents/*.md` + scaffold vào `projects/<branch>/`.
- **KHÔNG `run.ps1 autobuild/autofix`** (đã xóa). Tự viết workflow.json bằng tay.
- **KHÔNG đụng `engine/*.ps1`** — chỉ GỌI `run.ps1 validate/run` để smoke-check.
- **KHÔNG build app** (index.html app, src/ app...) — đó là việc chi nhánh làm sau.

### Workflow builder (5 bước)
1. **Đọc brief**: TaskGet → thiết kế CTO (pipeline + roster + cấu trúc file) + plan (done-criteria) + tên chi nhánh.
2. **Chuẩn bị**: kiểm `projects/<branch>/` đã có chưa (Write tự tạo path).
3. **Write/Edit**: agents `projects/<branch>/agents/<role>.md` (từ catalog) → `projects/<branch>/workflow.json` (node trỏ agent) → scaffold.
4. **Smoke-check bằng engine** (từ `company/engine/`):
   ```bash
   cd /home/gnuh/Documents/company/engine
   pwsh ./run.ps1 validate <branch>            # exit 0 = workflow hợp lệ
   pwsh ./run.ps1 run <branch> "smoke" -Mock   # done, đi tới terminal
   ```
   Lỗi → sửa ngay, chưa báo tester cho tới khi cả hai pass.
5. **Báo tester**: SendMessage kèm cấu trúc file + lệnh engine tester chạy + done-criteria.

### Anti-patterns builder
- Build app trực tiếp thay vì dựng chi nhánh (workflow + agents).
- Gọi `run.ps1 autobuild` (không còn tồn tại) thay vì Write/Edit workflow.json.
- Lưu toạ độ trong workflow.json; router thiếu `when`; quên `entry`/`max_steps`.
- Báo tester khi `validate`/`run -Mock` chưa pass.
- Ghi ngoài `projects/<branch>/` (đụng engine/catalog/examples).

---

## 3. Tester — verify chi nhánh bằng engine

### Nguyên tắc
- **Verify chi nhánh bằng engine** — `run.ps1 validate/run/check`, KHÔNG verify như app (không npm test/pytest trên chi nhánh).
- **Exit-code / output engine là nguồn sự thật** — không "trông ổn".
- **`-Mock`** — verify offline, không đốt token. Real-run chỉ khi lead chỉ định.
- In **`CHECK_RESULT:` bắt buộc**.

### Workflow tester (5 bước)
1. **Nhận brief**: tên chi nhánh + done-criteria + lệnh engine từ builder.
2. **Chạy engine verify** (từ `company/engine/`):
   ```bash
   cd /home/gnuh/Documents/company/engine
   pwsh ./run.ps1 validate <branch>; echo "exit=$?"            # exit 0
   pwsh ./run.ps1 run <branch> "verify" -Mock; echo "exit=$?"  # done
   pwsh ./run.ps1 check <branch>; echo "exit=$?"               # output_keys non-empty (nếu cần)
   ```
3. **Map done-criteria → bằng chứng**:

   | Done-criteria | Lệnh engine | Kết quả | Pass/Fail |
   |---|---|---|---|
   | workflow hợp lệ | `run.ps1 validate <branch>` | exit 0 | ✅ |
   | chạy tới terminal | `run.ps1 run <branch> "x" -Mock` | done, path a→…→ship | ✅ |
   | output_keys đầy đủ | `run.ps1 check <branch>` | exit 0 | ✅ |

4. **In CHECK_RESULT**:
   ```
   CHECK_RESULT: pass
   ```
   hoặc `CHECK_RESULT: fail (validate: router node 'x' thiếu when / run -Mock: node 'y' treo)`.
5. **Báo lead**: bảng done-criteria + CHECK_RESULT + lỗi cụ thể nếu fail.

### Anti-patterns tester
- Verify chi nhánh như app (npm test/pytest) thay vì `run.ps1 validate/run/check`.
- Phán cảm tính không chạy engine.
- Quên `-Mock` (đốt token) / sửa `engine/*.ps1`.
- Bỏ qua done-criteria; không in CHECK_RESULT.
- Sửa file chi nhánh (tester read+run only).

---

## 4. Ranh giới — engine VÀ HQ

| Điều | Vị thế dưới framing chi nhánh |
|---|---|
| `run.ps1 validate/run/check/graph` | **Công cụ verify CHÍNH** của HQ (chi nhánh = workflow engine) — builder smoke-check, tester gate |
| `workflow.json` trong `projects/<branch>/` | **LÀ deliverable** (cơ sở chi nhánh) — builder Write/Edit trực tiếp |
| `catalog/*.md` | **Menu vai** để lắp roster chi nhánh — CTO chọn, builder phỏng theo |
| `run.ps1 autobuild/autofix` | KHÔNG tồn tại (đã xóa) — builder tự viết workflow.json bằng tay |
| Sửa `engine/*.ps1` | KHÔNG — engine là code cố định; chỉ GỌI `run.ps1` |
| Build app/web (`projects/<branch>/` chứa app code) | KHÔNG — đó là việc CHI NHÁNH làm sau, không phải HQ |
| `company/memory/` + `<branch>/memory/` | Engine branch store (engine tự quản) — HQ-team ghi `.claude/memory/` (skill `hq-memory`) |

---

## 5. Quick reference
```
BUILDER (dựng chi nhánh):
  → Write/Edit : projects/<branch>/agents/<role>.md  (từ catalog/)
  → Write/Edit : projects/<branch>/workflow.json     (node trỏ agent; router có when)
  → smoke (cd company/engine): run.ps1 validate <branch> + run <branch> "x" -Mock
  → Báo tester : cấu trúc + lệnh engine + done-criteria

TESTER (verify chi nhánh):
  → engine (cd company/engine): run.ps1 validate / run -Mock / check
  → Map criteria: done-criteria → lệnh engine → exit-code → pass/fail
  → In verdict  : CHECK_RESULT: pass|fail (lý do nếu fail)
  → Báo lead    : bảng + CHECK_RESULT
```
