# CLI redesign — Phase B.1 proposal (chờ user duyệt tên)

> Deliverable của session **B.1**. Đề xuất bảng **tên cũ → tên mới + nhóm verb + alias + ẩn/phơi** cho 13 lệnh
> (12 hiện có + `test` mới), cơ chế alias, và danh sách caller phải đụng khi đổi tên. **Chưa sửa code** —
> B.2 mới implement sau khi user duyệt bảng này.

---

## Vấn đề cần chữa (ROADMAP §#1)

Đọc README/help **không rõ**:
1. Lệnh nào chạy **HQ** (sinh chi nhánh) vs lệnh nào chạy **project con** vs lệnh **soạn/nội bộ**.
2. Vài tên là jargon viết tắt (`viz`, `e2e`, `e2efix`) — không tự giải thích.
3. Bộ ba `check`/`trial` (kiểm 1 project) dễ lẫn với lệnh `test` mới (chạy bộ test của **engine**).

→ Mục tiêu: **nhóm theo trục HQ/project/author + đổi tên cho lệnh jargon, GIỮ tên đã rõ** + lớp alias để
lệnh cũ vẫn chạy (không vỡ thói quen + ví dụ README cũ + agent HQ runtime).

---

## Nguyên tắc đề xuất

- **Giữ tên đã rõ** (`run`/`resume`/`validate`/`status`/`logs`/`edit`/`build`/`check`/`trial`). Đổi tên-vì-đổi
  làm vỡ trí nhớ cơ bắp + tăng bề mặt alias mà không tăng độ rõ.
- **Chỉ đổi lệnh jargon** (`viz`, `e2e`, `e2efix`) → tên tự-giải-thích.
- **Tên mới cho lệnh mới** (`test`) chọn sao **không lẫn** với `check`/`trial`.
- Bất biến **#4 một surface**: vẫn `run.ps1 <command>`, KHÔNG entry point mới. `build` vẫn nhận `<spec-file>`
  (không phải project) — không gộp nhầm vào nhóm "chạy project".

---

## Bảng đề xuất (13 lệnh)

| # | Tên cũ | **Tên mới (đề xuất)** | Nhóm | Alias giữ | Ẩn khỏi help chính | Lý do đổi / giữ |
|---|---|---|---|---|---|---|
| 1 | `run` | `run` | Project·chạy | — | — | Đã rõ, phổ quát. |
| 2 | `resume` | `resume` | Project·chạy | — | — | Đã rõ. |
| 3 | `viz` | **`graph`** | Project·soi | `viz` | — | `viz` là viết tắt jargon; `graph` nói thẳng "in đồ thị điều khiển + Mermaid". |
| 4 | `validate` | `validate` | Project·soi | — | — | Chuẩn, rõ. |
| 5 | `status` | `status` | Project·soi | — | — | Đã rõ. |
| 6 | `logs` | `logs` | Project·soi | — | — | Đã rõ. |
| 7 | `check` | `check` | Project·kiểm | — | — | Tầng cấu trúc; agent HQ + skills gọi tên này → giữ để khỏi đụng runtime. |
| 8 | `trial` | `trial` | Project·kiểm | — | — | Tầng trial thật; agent HQ gọi tên này → giữ. |
| 9 | `build` | `build` | HQ·dựng | — | — | Rõ; nhận `<spec-file>`. Builder agent gọi tên này runtime → giữ. |
| 10 | `e2e` | **`autobuild`** | HQ·dựng | `e2e` | — | `e2e` là test-jargon gây hiểu nhầm (đây là **sinh+promote chi nhánh thật**, không chỉ test). `autobuild` = HQ tự dựng chi nhánh end-to-end. |
| 11 | `e2efix` | **`autofix`** | HQ·dựng | `e2efix` | — | Biến thể fix-loop của `autobuild`; bỏ jargon dính liền `e2efix`. |
| 12 | `edit` | `edit` | Author | — | — | TUI soạn workflow; đã rõ. |
| 13 | `test` (mới) | **`selftest`** | Dev·nội bộ | `test` | ✅ (mục "advanced") | Lệnh chạy **bộ test của ENGINE** (3 script + 7 stamp + mem-demo). Tên `test` trần dễ lẫn với `check`/`trial` (kiểm *project*). `selftest` = "engine tự kiểm". |

**Tóm tắt thay đổi**: chỉ **3 lệnh đổi tên** (`viz→graph`, `e2e→autobuild`, `e2efix→autofix`) + **1 lệnh mới**
(`selftest`, alias `test`). 9 lệnh còn lại **giữ nguyên**. → bề mặt alias nhỏ, rủi ro hồi quy thấp.

---

## Cấu trúc help mới (Show-Help, đề xuất nhóm theo trục)

```
Workflow Engine — surface lệnh duy nhất.   ./run.ps1 <command> <project> [args]

PROJECT — chạy & soi một workflow (project con hoặc 'hq'):
  run      <proj> "<req>" [-Mock] [-Model m]   Chạy pipeline end-to-end
  resume   <proj> [-Mock] [-Model m]           Tiếp run dở/failed mới nhất
  graph    <proj> [out.mmd]                     In DAG ASCII + xuất Mermaid        (cũ: viz)
  validate <proj>                               Kiểm DAG hợp lệ (exit = số lỗi)
  status   <proj>                               Trạng thái run gần nhất
  logs     <proj> [node]                        Prompt/output từng lượt thăm
  check    <proj>                               Tester tầng cấu trúc (validate+run-Mock+output_key)
  trial    <proj> [-Model m]                    Tester tầng trial THẬT (assert trial[])

BUILD — HQ sinh/sửa chi nhánh:
  build     <spec-file> [<outName>]             Builder deterministic: spec → chi nhánh
  autobuild <proj> "<req>" [-Router s] [-Real]  HQ chạy thật → verify → promote     (cũ: e2e)
  autofix   <proj> "<req>" -Seed <br> -Branch <n> [-Real]   Fix-loop branch hỏng    (cũ: e2efix)

AUTHOR — soạn workflow:
  edit     <proj>                               TUI thêm/xoá/đổi node + agent + deps

Advanced:
  selftest [all]                                Chạy bộ test engine (script+stamp+mem-demo)  (cũ: test)

Không arg / help / -h / --help → in trợ giúp này.
Tương thích: tên cũ (viz/e2e/e2efix/test) vẫn chạy như alias.
```

---

## Cơ chế alias (chốt hướng để B.2 implement)

- **Map tên-cũ → tên-mới** đặt trong `Invoke-Dispatch`, ngay sau khi lấy `$command` (trước allowlist check):
  ```powershell
  $aliasMap = @{ 'viz' = 'graph'; 'e2e' = 'autobuild'; 'e2efix' = 'autofix'; 'test' = 'selftest' }
  if ($aliasMap.ContainsKey($command)) { $command = $aliasMap[$command] }
  ```
  Sau bước này mọi nhánh `switch` chỉ cần biết tên mới. Allowlist mở rộng = **tên mới** (4 mục mới) — tên cũ
  được map trước nên không cần nằm trong allowlist.
- **Im lặng (không in deprecation note) ở Phase B** — lý do:
  - Agent HQ + ví dụ README cũ gọi alias ở runtime; in note mỗi lần = nhiễu output non-interactive (Claude
    parse exit-code, không nên trộn warning).
  - Alias giữ **lâu dài** (không có kế hoạch bỏ), nên không cần thúc người dùng migrate.
  - Tên cũ vẫn được liệt kê ở mục "Tương thích" của help + README (đủ để người đọc biết).
  - *(Nếu user muốn note nhẹ: in 1 dòng ra **stderr** `[deprecated] 'viz' → dùng 'graph'`, không đụng stdout/exit. Để user chốt.)*

---

## Danh sách caller phải đụng khi đổi tên (file:line)

> Vì chỉ đổi 3 tên (`viz/e2e/e2efix`) + thêm `selftest`, và alias giữ tên cũ chạy được, **đa số caller KHÔNG
> bắt buộc sửa** (vẫn chạy qua alias). Cột "Bắt buộc?" = có cần sửa để đúng/không-vỡ, vs chỉ nên-đồng-bộ-doc.

### B.2 — `engine/run.ps1` (bắt buộc, đây là nơi implement)

| Vị trí | Nội dung | Việc B.2 |
|---|---|---|
| `run.ps1:5–11` | Comment header liệt kê command | Cập nhật danh sách + tên mới |
| `run.ps1:32–58` | `Show-Help` text phẳng | Viết lại theo nhóm (xem trên) |
| `run.ps1:120` | `$command = ...ToLower()` | Chèn `$aliasMap` ngay sau |
| `run.ps1:127` | allowlist `@('run','resume','viz',...)` | Thay `viz/e2e/e2efix` → `graph/autobuild/autofix` + thêm `selftest` |
| `run.ps1:195` | nhánh `'viz'` trong switch | Đổi case → `'graph'` |
| `run.ps1:230,245` | nhánh `'e2e'`/`'e2efix'` | Đổi case → `'autobuild'`/`'autofix'` |
| `run.ps1:233,248` | usage-string `"e2e cần..."` / `"e2efix cần..."` | Đổi tên trong message → `autobuild`/`autofix` |
| `run.ps1` (mới) | — | Thêm nhánh `'selftest'` (B.3 implement runner) |

### B.4 — docs (đồng bộ, không phải caller runtime)

| File:line | Nhắc tên cũ | Việc |
|---|---|---|
| `README.md:26–30,38` | quickstart `viz` | → `graph` (B.4 viết lại quickstart) |
| `README.md:53–64` | bảng 12 lệnh | → bảng 13 lệnh tên mới + nhóm |
| `README.md:107,118,153,164,166,224,227,243,310–311` | ví dụ `e2e`/`viz`/`run`/`trial`/`build` | đồng bộ tên mới (giữ vài ví dụ alias ở mục Tương thích) |
| `CLAUDE.md` (bảng Bản đồ file) | mô tả `run.ps1`/`README.md` | cập nhật tên mới + hàng `phase-b/` |

### Caller runtime KHÔNG cần sửa (chạy qua tên-giữ-nguyên hoặc alias)

| File:line | Gọi lệnh | Vì sao không vỡ |
|---|---|---|
| `hq/agents/cto.md:21`, `build-spec.md:103` | `run.ps1 build` | `build` **giữ nguyên** |
| `hq/agents/builder.md:10,12,17,19,21` | `build`, `validate` | cả 2 **giữ nguyên** |
| `hq/agents/tester.md:10`, `skills.md:15,16` | `check`, `trial` | **giữ nguyên** |
| `hq/agents/planner.md:16` | `run.ps1 validate` | **giữ nguyên** |
| `examples/*.ps1`, 7×`p-*/stamp.ps1` | gọi **hàm** (`Invoke-Workflow`/`Test-StructuralGate`/`Invoke-E2E`…) | KHÔNG đi qua command-string |

→ **0 file agent/test bắt buộc sửa.** Đổi tên an toàn nhờ (a) chỉ jargon-command bị đổi, (b) alias, (c) test
gọi hàm trực tiếp.

---

## ✅ User chốt (2026-05-29) — bảng tên DUYỆT

1. **Duyệt cả 3 đổi tên**: `viz→graph`, `e2e→autobuild`, `e2efix→autofix`. (9 lệnh khác giữ nguyên.)
2. **Lệnh mới** = `selftest` (alias `test`).
3. **Alias im lặng** (route thẳng tên-cũ→mới, không in note). Tên cũ liệt kê ở mục "Tương thích" của help/README.
4. Không đổi thêm `check`/`trial` — giữ nguyên.

→ Bảng tên trên là **immutable cho B.2/B.3/B.4**. B.2 implement rename + alias map + Show-Help nhóm.
