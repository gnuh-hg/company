---
name: build-verify
description: "Quy ước build deliverable TRỰC TIẾP (Write/Edit vào projects/<name>/) + verify khách quan (chạy test/build/lint của deliverable, đọc exit-code, in CHECK_RESULT). Dùng chung cho builder và tester trong HQ-team."
---

# Build-Verify — HQ team convention

> Quy ước chung cho **builder** (ghi file trực tiếp) và **tester** (verify khách quan). Không dùng engine-build trong luồng HQ.

---

## 1. Nơi ghi + cấu trúc deliverable

### Output location

```
projects/<name>/        ← mọi file deliverable đặt ở đây
```

- `projects/` gitignored (`company/.gitignore`) — regen-được, không commit.
- `<name>` = tên project ngắn, kebab-case (vd `landing-email`, `auth-api`, `mobile-dashboard`).
- Lead xác nhận tên project khi assign task cho builder; builder KHÔNG tự đặt tên nếu chưa có.

### Cấu trúc điển hình theo loại deliverable

| Loại | Cấu trúc tối thiểu |
|---|---|
| Web frontend | `index.html` + `css/` + `js/` (hoặc framework scaffold) |
| Node/TS backend | `package.json` + `src/` + `tsconfig.json` |
| Python backend | `main.py` hoặc `app/` + `requirements.txt` |
| Full-stack | `frontend/` + `backend/` + `README.md` (cách chạy) |
| Script / CLI | entrypoint + `README.md` (cách chạy + args) |

Cấu trúc thực tế theo thiết kế CTO — đây chỉ là tham chiếu khởi điểm.

### README trong deliverable (bắt buộc nếu cần lệnh để chạy)

Mỗi deliverable có `README.md` hoặc comment inline nêu rõ:
- Cách cài deps (`npm install`, `pip install -r requirements.txt`, v.v.)
- Cách chạy app / start server
- Cách chạy test

Tester cần thông tin này để verify khách quan mà không phải đoán.

---

## 2. Builder — build deliverable trực tiếp

### Nguyên tắc

- **Write/Edit file trực tiếp** vào `projects/<name>/`. Không trung gian qua engine.
- **Bash** để cài deps, build, chạy smoke-check nhanh (không phải full test).
- Không đụng `engine/*.ps1`. Không `run.ps1 autobuild/autofix`. Không tạo `workflow.json` HQ.

### Workflow builder (5 bước)

1. **Đọc brief**: TaskGet → đọc thiết kế CTO (cấu trúc file, công nghệ, cách tiếp cận) + plan planner (done-criteria).
2. **Chuẩn bị workspace**: `mkdir -p projects/<name>/`, kiểm tra deps có sẵn chưa.
3. **Write/Edit files**: theo cấu trúc thiết kế CTO. Ưu tiên Edit khi file đã có; Write khi tạo mới.
4. **Smoke-check**: chạy lệnh nhanh xác nhận không lỗi syntax/deps trước khi báo tester.
   ```bash
   cd projects/<name>
   npm install && npm run build 2>&1 | tail -20   # Node
   python -m py_compile main.py                    # Python
   ```
5. **Báo tester**: SendMessage kèm:
   - Deliverable ở: `projects/<name>/`
   - Cách chạy/kiểm: `<lệnh cụ thể>`
   - Done-criteria cần verify: `<copy từ plan planner>`

### Anti-patterns builder

- Không tự suy thiết kế khi CTO chưa cho — hỏi lead.
- Không ghi đè toàn bộ nếu chỉ cần sửa một phần — dùng Edit.
- Không báo tester khi smoke-check còn lỗi.
- Không để thiếu cách chạy trong báo cáo cho tester.
- Không ghi file ngoài `projects/<name>/` trừ khi lead yêu cầu tường minh.

---

## 3. Tester — verify khách quan

### Nguyên tắc

- **Chạy check của chính deliverable** — test suite, build, lint, hoặc quan sát hành vi nếu không có test.
- **Exit-code / output lệnh là nguồn sự thật** — không phán "trông ổn".
- In **`CHECK_RESULT:` bắt buộc** — format máy-đọc-được cho lead đọc verdict.

### Workflow tester (5 bước)

1. **Nhận brief từ builder**: vị trí deliverable + cách chạy + done-criteria.
2. **Chạy check deliverable**:

   ```bash
   # Node / frontend
   cd projects/<name>
   npm install
   npm test        # exit 0 = pass; khác 0 = fail
   npm run build   # kiểm build prod nếu done-criteria yêu cầu

   # Python
   cd projects/<name>
   pip install -r requirements.txt -q
   pytest          # hoặc python -m pytest

   # Go
   cd projects/<name>
   go test ./...

   # Lint / type-check
   npm run lint
   npx tsc --noEmit
   ```

3. **Map done-criteria → bằng chứng**: mỗi done-criteria từ plan planner → lệnh đã chạy → output → pass/fail.

   | Done-criteria | Lệnh chạy | Kết quả | Pass/Fail |
   |---|---|---|---|
   | Build thành công | `npm run build` | exit 0, thư mục `dist/` tạo ra | ✅ Pass |
   | Tests ≥ 90% pass | `npm test` | 18/20 pass | ❌ Fail |
   | Không lỗi lint | `npm run lint` | 0 warnings | ✅ Pass |

4. **In CHECK_RESULT**:

   ```
   CHECK_RESULT: pass
   ```
   hoặc:
   ```
   CHECK_RESULT: fail (npm test: 2 failures — src/auth.test.js:45 TypeError: token undefined)
   ```

5. **Báo lead**: SendMessage kèm bảng done-criteria + CHECK_RESULT + lý do cụ thể nếu fail.

### Khi deliverable không có test tự động

Tester định nghĩa kiểm-tra quan-sát-được từ done-criteria (vd "mở `index.html` → nhập email hợp lệ → thấy button submit active"). Chạy/quan sát thực tế, ghi rõ "đã kiểm gì + thấy gì". Vẫn cụ thể — không "nhìn có vẻ OK".

### Anti-patterns tester

- Không phán "code trông sạch" mà không chạy lệnh.
- Không bỏ qua done-criteria nào — map toàn bộ, không cherry-pick.
- Không dùng `run.ps1 check/trial` — engine không trong luồng HQ.
- Không sửa file deliverable — tester read+run only.
- CHECK_RESULT phải in dù pass — lead cần confirmation rõ ràng.

---

## 4. Ranh giới — điều HQ-team KHÔNG làm

| Không làm | Lý do |
|---|---|
| `run.ps1 autobuild/autofix/build` | Engine-build là form workflow cũ; HQ build trực tiếp |
| Tạo `workflow.json` cho deliverable HQ | Deliverable là app/code, không phải pipeline engine |
| Đụng `engine/*.ps1` | Engine là tool chi nhánh đứng riêng; HQ không bắt buộc đi qua |
| Builder chạy test đầy đủ | Đó là việc của tester — tránh double-work |
| Tester sửa file deliverable | Tester chỉ đọc + chạy check; sửa là việc của builder |
| Ghi vào `company/memory/` | Đó là engine branch store — HQ-team ghi `.claude/memory/` (xem skill `hq-memory`) |

### Ngoại lệ: khi request CỤ THỂ là "dựng workflow pipeline"

Nếu (và chỉ nếu) user yêu cầu rõ "tạo/sửa workflow engine pipeline", lead/builder có thể gọi:

```bash
cd /path/to/company/engine
./run.ps1 validate <project>
./run.ps1 run <project> "<input>" -Mock
./run.ps1 graph <project>
```

Đây là **ngoại lệ** — không phải đường build mặc định.

---

## 5. Quick reference

```
BUILDER:
  → Write/Edit  : projects/<name>/...
  → Bash (deps) : npm install / pip install / go mod download
  → Bash (smoke): npm run build / python -m py_compile
  → Báo tester  : location + cách chạy + done-criteria

TESTER:
  → Bash (check): npm test / pytest / go test ./... / npm run lint
  → Map criteria: bảng done-criteria → lệnh → exit-code → pass/fail
  → In verdict  : CHECK_RESULT: pass|fail (lý do nếu fail)
  → Báo lead    : bảng + CHECK_RESULT
```
