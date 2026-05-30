# Thiết kế hệ thống agent — Company structure

**Thời gian ước tính:** 30–60 ngày
**Mức tự động hoá mục tiêu:** ~80%
**Vị trí:** `/home/gnuh/Documents/company/`

---

## Tổng quan

Hệ thống mô phỏng cấu trúc một công ty phần mềm nhiều chi nhánh. Hai tầng: trụ sở chính (HQ) quyền hạn tối cao, và các chi nhánh dự án hoạt động độc lập bên dưới. HQ build / sửa / kiểm thử các chi nhánh — gồm cả tự sửa khi phát hiện lỗi.

Người dùng chỉ tương tác với HQ. Phần còn lại hệ thống tự xử lý.

**Triết lý cốt lõi:** mỗi file agent là một vai trò **không thể chia nhỏ hơn**. File càng nhỏ và bám sát thì agent càng làm tốt đúng phần của mình. Vấn đề "nhiều file" do `workflow.json` + `bridge` lo — không phải lo của agent.

---

## Cấu trúc thư mục

```
company/
├── hq/
│   ├── agents/
│   │   ├── coo.md
│   │   ├── cto.md
│   │   ├── builder.md
│   │   └── tester.md
│   ├── skills/
│   │   ├── scaffold.md
│   │   ├── patch.md
│   │   ├── diagnose.md
│   │   ├── run-test.md
│   │   └── report.md
│   ├── workflow.json
│   └── CLAUDE.md
│
├── engine/
│   ├── run.ps1
│   ├── workflow.ps1
│   ├── bridge.ps1
│   └── app/
│
└── projects/
    └── <tên-dự-án>/
        ├── agents/        # chọn tập con từ catalog bên dưới
        ├── skills/
        ├── workflow.json
        └── CLAUDE.md
```

---

## Hình dạng chuẩn của một file agent

Mỗi file `.md` chỉ ~6–10 dòng, đúng 5 mục cố định. **Tuyệt đối không chứa logic workflow** — agent không biết ai gọi nó hay nó gọi ai tiếp.

```markdown
# Backend — API Developer

**Vai trò:** Viết HTTP endpoint từ spec đã chốt.
**Nhận:** Spec API (route, method, request/response shape).
**Trả ra:** Code route + handler, không kèm DB schema.
**Không làm:** Thiết kế bảng, auth, UI, deploy.
**Xong khi:** Endpoint khớp đúng spec, có lỗi-path cơ bản.
```

`Nhận` / `Trả ra` mô tả **loại dữ liệu**, không phải tên agent nguồn/đích. Đây là điều giữ file vừa bám sát vừa rời rạc — workflow đổi thứ tự không cần sửa agent.

---

## HQ — Trụ sở chính

HQ không làm sản phẩm. Nhiệm vụ duy nhất: quản trị hệ thống — build, sửa, kiểm thử chi nhánh. Giữ gọn ở tầng meta; CEO/CFO của công ty thật không map vào đây (không có chiến lược/ngân sách trong vòng lặp build–test–fix).

### Agents

| File | Một việc |
|---|---|
| `coo.md` | Điểm vào duy nhất từ user → phân loại yêu cầu (kỹ thuật / cần làm rõ) |
| `cto.md` | Yêu cầu kỹ thuật → spec build (cần file/agent/workflow nào) — không tự viết file |
| `builder.md` | Spec → tạo hoặc sửa file thật trên disk (dùng `scaffold` / `patch`) |
| `tester.md` | Chạy workflow chi nhánh với input giả → pass/fail; fail thì trả Builder fix |

> Pipeline HQ: COO → CTO → Builder → Tester → (fail: Builder) → pass: done

### Skills HQ

| Skill | Làm đúng một việc |
|---|---|
| `scaffold` | Tạo cây thư mục chi nhánh từ template |
| `patch` | Sửa một file theo chỉ dẫn cụ thể |
| `diagnose` | Đọc log lỗi, xác định nguyên nhân |
| `run-test` | Chạy workflow một chi nhánh với input giả |
| `report` | Xuất kết quả test thành văn bản ngắn |

---

## Chi nhánh — Catalog agent (tách hạt tối đa)

Catalog là **menu**. Mỗi `workflow.json` chọn tập con tuỳ dự án. Tách nhỏ không làm phức tạp agent — chỉ thêm/bớt dòng trong pipeline.

### Khối sản phẩm (Product)

| File | Vai trò | Trả ra |
|---|---|---|
| `pm.md` | Xác định tính năng, ưu tiên | User story + thứ tự ưu tiên |
| `ba.md` | Phân tích nghiệp vụ | Tech spec + edge case (Tech Lead đọc là chia task được) |

### Khối thiết kế (Design)

*Org thật có Design và app cần UI — nên đưa vào pipeline (khác bản gốc loại bỏ).*

| File | Vai trò | Trả ra |
|---|---|---|
| `ux-designer.md` | Trải nghiệm, user flow | Flow + prototype + hành vi tương tác |
| `ui-designer.md` | Giao diện | Layout + component visual (chỉ dùng token có sẵn) |

### Khối kỹ thuật (Engineering)

`backend` cũ tách thành 3 vai nhỏ; QA tách theo loại test.

| File | Vai trò | Không làm |
|---|---|---|
| `tech-lead.md` | Chia task, review, quyết merge; xử lý lệch nội bộ trước khi leo HQ | Viết feature code |
| `db-architect.md` | Schema, migration, index | API, UI |
| `api-developer.md` | Endpoint + handler nghiệp vụ | Schema, auth, UI |
| `auth-engineer.md` | Xác thực / phân quyền | Feature khác |
| `frontend-developer.md` | Component + nối API + style | Server-side |
| `mobile-ios.md` | App iOS | *(chỉ bật cho dự án mobile)* |
| `mobile-android.md` | App Android | *(chỉ bật cho dự án mobile)* |
| `mobile-flutter.md` | App cross-platform | *(chỉ bật cho dự án mobile)* |
| `devops.md` | CI/CD, deploy, env, monitoring | Feature code |

### Khối QA

"Test" là nhiều việc khác nhau → tách:

| File | Vai trò | Không làm |
|---|---|---|
| `qa-functional.md` | Chạy test case theo spec, báo bug reproduce được | Fix bug |
| `qa-regression.md` | Kiểm thử tính năng cũ không vỡ *(bật khi cần)* | Fix bug |

### Không nằm trong pipeline code

Sales, Marketing, Customer Support, HR, Kế toán, Pháp lý — không sinh artifact kỹ thuật. Nếu sau này cần (vd Support → bug report), thêm như **agent phụ ngoài luồng build**, không đưa vào `pipeline`.

### Cấu hình theo quy mô dự án

Team size tuỳ dự án — chỉ là chọn ít/nhiều dòng trong `workflow.json`, **không sửa file agent nào**:

- **Dự án nhỏ:** bỏ `ba` (Tech Lead kiêm), bỏ `db-architect` + `auth-engineer` (`api-developer` kiêm), bỏ `devops` (Backend kiêm deploy), bỏ `qa-regression`.
- **Dự án web đầy đủ:** PM → BA → UX → UI → Tech Lead → db-architect → api-developer → auth-engineer → frontend-developer → devops → qa-functional.
- **Dự án mobile:** thêm `mobile-*` tương ứng, bỏ `frontend-developer` nếu thuần app.

---

## Workflow engine

Engine là code cố định (PowerShell). Bạn và HQ cải tiến — không phải agent.

### Cơ chế

```
pwsh → đọc workflow.json → gọi Agent A → nhận output
     → bridge compose context → gọi Agent B → nhận output
     → ... → ghi log → kết thúc
```

`bridge.ps1` giải bài "B và C không biết nhau": engine lấy output A, format thành brief, nhét vào prompt B. B không cần biết A tồn tại. Đây là lý do agent tách nhỏ thoải mái mà không rối.

### Gọi claude

```powershell
# Gọi một agent — xong tự tắt
claude -p $prompt --system-prompt-file $agentFile --output-format json
```

### workflow.json — ví dụ chi nhánh web đầy đủ

```json
{
  "pipeline": [
    { "step": "story",   "agent": "agents/pm.md",                 "input": "{{user_request}}",        "output_key": "story" },
    { "step": "spec",    "agent": "agents/ba.md",                 "input": "{{story}}",               "output_key": "spec" },
    { "step": "ux",      "agent": "agents/ux-designer.md",        "input": "{{spec}}",                "output_key": "flow" },
    { "step": "ui",      "agent": "agents/ui-designer.md",        "input": "{{flow}}",                "output_key": "design" },
    { "step": "schema",  "agent": "agents/db-architect.md",       "input": "{{spec}}",                "output_key": "schema" },
    { "step": "api",     "agent": "agents/api-developer.md",      "input": "{{spec}}\n{{schema}}",    "output_key": "api" },
    { "step": "auth",    "agent": "agents/auth-engineer.md",      "input": "{{spec}}\n{{api}}",       "output_key": "auth" },
    { "step": "ui-impl", "agent": "agents/frontend-developer.md", "input": "{{design}}\n{{api}}",     "output_key": "fe" },
    { "step": "deploy",  "agent": "agents/devops.md",             "input": "{{api}}\n{{fe}}",         "output_key": "deploy" },
    { "step": "qa",      "agent": "agents/qa-functional.md",      "input": "{{spec}}\n{{deploy}}",    "output_key": "report" }
  ]
}
```

Dự án nhỏ: xoá bớt step — agent giữ nguyên.

### App local

Chạy hoàn toàn offline. Hai chức năng:
- **View:** trạng thái pipeline đang chạy, log từng agent
- **Edit:** chỉnh `workflow.json` trực quan

---

## Nguyên tắc

**File nhỏ, một việc.** Agent biết vai trò của mình ở mức không chia nhỏ hơn được. Skill làm đúng một loại tác vụ. Engine lo thứ tự và context.

**Workflow cố định.** Pipeline không đổi theo ý agent. Khi lệch: Tech Lead xử lý tạm, sau đó HQ fix workflow — không phải agent tự quyết.

**HQ vòng lặp build–test–fix.** Tự động, không cần người dùng can thiệp giữa chừng.

**Governance tập trung, execution phân tán.** HQ quyết cấu trúc và chuẩn. Chi nhánh tự vận hành.

---

## Lưu ý triển khai

- Claude Code (`claude` trong PowerShell) phải cài trước mọi bước khác.
- Build HQ trước — vì HQ là công cụ để build chi nhánh tiếp theo.
- Nên có một chi nhánh test nhỏ ngay từ đầu để Tester có thứ chạy thực.
- App local build sau khi engine ổn định — không phải blocker.
- Sales, Marketing, HR, Kế toán, Pháp lý không map vào pipeline code; Design (UI/UX) **có** map và đã đưa vào catalog chi nhánh.
