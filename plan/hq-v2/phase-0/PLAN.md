# PLAN — Phase 0: Dọn sạch hq-workflow

> Sau khi xong Phase 0, `company/` chỉ còn **(a) HQ native team** (`.claude/`) và **(b) engine branch-workflow GENERIC** — không còn lệnh / harness / spec nào gắn chặt với DAG HQ cũ.

---

## Context

**Vì sao tách thành phase riêng:**
- Phần đầu (xóa `hq/` + `examples/hq-*` + test script HQ + de-wire selftest 12→10) đã xong trong chat reframe Q2 (2026-06-02).
- Phần còn lại đụng **engine dispatcher + 2 module engine** (`e2e.ps1`, `spec.ps1`) + app + docs — nhiều file, không làm inline vào session H.4 được.

**Nguyên tắc xuyên suốt — CHỈ xóa những gì gắn chặt với HQ:**
- `catalog/` (17 vai) → **GIỮ**: thư viện vai tham khảo cho chi nhánh + `hq-cto` tra cứu domain.
- `patterns/` + `engine/pattern.ps1` → **GIỮ**: selftest còn chạy 7 `p-*/stamp.ps1`; authoring tool generic.
- `engine/sandbox.ps1` → **GIỮ**: `Copy-ToSandbox`/`Invoke-Trial` là generic branch tester.
- Toàn bộ executor, validate, graph, check, save-graph, edit → **BẤT BIẾN**.

**Scope ngoài plan này:**
- Phase H.4+ (soạn tiếp hq-cto, builder, tester…) — chạy song song với Phase 0, khác lớp.
- Phase I/J/K/L (tối ưu token / rẽ nhánh chủ động / HITL / app UX) — sau Phase 0.

---

## ⚠️ Cross-cutting: Rủi ro catalog "lậm" vào hq-cto (ghi nhớ cho H.4)

`catalog/` được giữ lại → khi soạn `hq-cto.md` (Session H.4), **PHẢI** viết tường minh:

> "catalog/ = tham khảo domain/chuyên môn (KHÔNG phải menu lắp role vào pipeline).  
> hq-cto KHÔNG xuất build-spec JSON, KHÔNG lắp workflow.json từ catalog.  
> Thiết kế kỹ thuật = văn xuôi: cấu trúc file / cách tiếp cận / công nghệ → builder Write/Edit trực tiếp."

Đây là anti-pattern guard bắt buộc, tương tự guard "KHÔNG xuất JSON plan-as-data" đã thêm vào `hq-planner.md`.

---

## Pipeline 2 session

```
[Session 0.1] Engine + dispatcher cleanup ──► e2e.ps1/spec.ps1 xóa; run.ps1/test-runner gọn
                                                 │
[Session 0.2] App + docs cleanup          ──► server.mjs/App.jsx sạch hq; README/CLAUDE.md đúng
```

---

## Session 0.1 — Engine + dispatcher cleanup

**Mục tiêu**: Xóa 2 module engine HQ-specific (`e2e.ps1`, `spec.ps1`); làm sạch dispatcher `run.ps1` (bỏ 3 lệnh HQ + alias liên quan); bỏ test + fixture HQ khỏi `examples/`.

### Việc cần làm

**A. Xóa `engine/e2e.ps1`**
- File này chứa: `Invoke-E2E`/`Invoke-E2EFix` (hardcode terminal `'record'`) + `Get-ProjectsRoot` + `Test-DryRunGate` + `Find-GeneratedBranch`/`Promote-Branch` + `Get-SandboxSnapshot`/`Test-DiffScope` + `Write-E2EResult` — toàn bộ là HQ build/fix-loop.
- `Test-DiffScope`: chỉ dùng trong `Invoke-E2E/Fix` → xóa cùng, không tách.
- `Test-DryRunGate`: generic về mặt logic nhưng là infrastructure của HQ harness → xóa cùng; nếu cần sau này tách sang `check.ps1`/`sandbox.ps1` trong Phase J.

**B. Xóa `engine/spec.ps1`**
- `Test-PlanSchema`/`Test-BuildSpec`/`Invoke-BuildSpec` là data-contract HQ-CTO (build-spec JSON → `workflow.json`).
- HQ Q2 không còn dùng (builder build TRỰC TIẾP).

**C. Cập nhật `engine/run.ps1`**
- Xóa khỏi `Show-Help`: hàng `build`, `autobuild`, `autofix`.
- Xóa khỏi aliasMap: `e2e→autobuild`, `e2efix→autofix`.
- Xóa khỏi comment header (dòng 11–13): `build`, `autobuild`, `autofix`.
- Xóa khỏi allowlist (dòng 175): `'build'`, `'autobuild'`, `'autofix'`.
- Xóa branch xử lý `'build'` (lines ~193–205) + `'autobuild'` (lines ~329–343) + `'autofix'` (lines ~344–360).
- Xóa note alias tương thích `e2e/e2efix` ở dòng 17.

**D. Cập nhật `engine/test-runner.ps1`**
- Xóa `e2e-harness-tests` khỏi danh sách script tests (mục 1/10 → selftest **10→9 mục**).
- Cập nhật header comment (bây giờ: "9 mục").
- Xóa luôn `examples/e2e-harness-tests.ps1` (dot-source `e2e.ps1` — sẽ crash sau khi e2e.ps1 bị xóa).

**E. Xóa `examples/broken-web/`**
- Chỉ phục vụ `Invoke-E2EFix` seed — không còn cần.

### STOP gate

```powershell
# Từ company/engine/
./run.ps1 selftest   # phải PASS, số mục = 9 (không phải 10)
./run.ps1 validate hello   # exit 0
./run.ps1 run hello "x" -Mock   # done

# Grep sạch (chạy từ company/)
grep -ri "Invoke-E2E\|autobuild\|autofix\|Invoke-BuildSpec\|build-spec" engine/ --include="*.ps1"
# → rỗng (ngoại trừ plan/ lịch sử)

grep -ri "e2e-harness\|broken-web" engine/ examples/ --include="*.ps1"
# → rỗng
```

### Output artifact

- `engine/e2e.ps1` — ĐÃ XÓA (git rm)
- `engine/spec.ps1` — ĐÃ XÓA (git rm)
- `engine/run.ps1` — đã bỏ 3 lệnh HQ + alias
- `engine/test-runner.ps1` — selftest 10→9, header cập nhật
- `examples/e2e-harness-tests.ps1` — ĐÃ XÓA (git rm)
- `examples/broken-web/` — ĐÃ XÓA (git rm -r)

---

## Session 0.2 — App + docs cleanup

**Mục tiêu**: Gỡ `hq` hard-code trong app (nhánh chết sau khi `hq/workflow.json` đã xóa); cập nhật README + CLAUDE.md phản ánh surface mới; fold §Dọn-legacy trong ROADMAP.

### Việc cần làm

**A. `app/server.mjs`**
- Line 117: xóa `if (existsSync(join(COMPANY, 'hq', 'workflow.json')) && !seen.has('hq')) seen.set('hq', 'hq');`
- Lines 127–128: xóa branch `if (name === 'hq') { ... }` trong `resolveProjectDir`.
- Giữ fallback logic chung — app default về `list[0]` (già này đã là behavior sau khi `hq/` bị xóa).
- Comment block dòng 27–28 (giải thích cwd issue với `hq`) → cũng xóa vì không còn liên quan.

**B. `app/src/App.jsx`**
- Line 39: `const def = list.find(p => p.name === 'hq') ?? list[0]` → sửa thành `const def = list[0]` (bỏ hẳn `find('hq')`, fallback `list[0]` đã đủ).
- Line 226: `{p.source !== 'hq' ? ` (${p.source})` : ''}` → sửa thành `{p.source ? ` (${p.source})` : ''}` (loại bỏ special-case `hq`).

**C. `README.md`**
- Xóa hoặc rewrite mục "3 luồng quickstart" — bỏ luồng HQ (`autobuild`/`autofix`/`build`).
- Bảng 13 lệnh → bảng ~9–10 lệnh: bỏ hàng `build`/`autobuild`/`autofix`.
- Xóa mọi mention build-spec format/schema.
- Giữ: run/resume/validate/graph/check/trial/edit/save-graph/status/logs/selftest + alias tương thích còn lại.

**D. `CLAUDE.md`**
- Bảng "Bản đồ file": cập nhật hàng `engine/e2e.ps1` → đánh dấu `~~ĐÃ XÓA~~` + lý do ngắn.
- Hàng `engine/spec.ps1` → đánh dấu `~~ĐÃ XÓA~~`.
- Hàng `examples/broken-web/` → đánh dấu `~~ĐÃ XÓA~~`.
- Hàng `engine/test-runner.ps1` → cập nhật "9 mục" (bỏ `e2e-harness-tests`).
- Hàng `examples/e2e-harness-tests.ps1` → đánh dấu `~~ĐÃ XÓA~~` (nếu có hàng riêng).

**E. `plan/hq-v2/ROADMAP.md`**
- Bảng tiến độ: Phase 0 → `✅ DONE`.
- §Dọn-legacy: fold lại, trỏ sang Phase 0 CHECKPOINT.
- §Các phase → Phase 0 block: cập nhật trạng thái + done-gate đạt.

### STOP gate

```powershell
# App không còn hq special-case
grep -n '"hq"' app/server.mjs app/src/App.jsx
# → 0 kết quả (ngoài comment lịch sử nếu có)

# Regression app vẫn start được
cd app && npm run build  # exit 0 (hoặc kiểm tra dev server không crash)
```

```powershell
# Engine regression
./run.ps1 validate hello   # exit 0
./run.ps1 run hello "x" -Mock   # done
./run.ps1 selftest   # PASS (9/9)

# README/CLAUDE.md không còn mention autobuild/autofix/build-spec
grep -i "autobuild\|autofix\|build-spec" README.md CLAUDE.md
# → rỗng (trừ hàng ~~ĐÃ XÓA~~)
```

### Output artifact

- `app/server.mjs` — bỏ `hq` hard-code (3 chỗ)
- `app/src/App.jsx` — bỏ `find('hq')` + `source !== 'hq'`
- `README.md` — rewrite bỏ HQ quickstart/lệnh HQ
- `CLAUDE.md` — cập nhật bảng file-map
- `plan/hq-v2/ROADMAP.md` — Phase 0 = DONE, §Dọn-legacy fold

---

## Outcome cuối

- `run.ps1` chỉ còn lệnh generic: run/resume/validate/graph/check/trial/edit/save-graph/status/logs/selftest (9 lệnh thực + alias viz→graph, test→selftest).
- Engine surface gọn → Phase I/J/K/L tối ưu/sửa trên surface không còn noise HQ.
- App project picker không còn nhánh chết `hq`.
- README/CLAUDE.md phản ánh đúng.
- `grep -ri 'Invoke-E2E\|autobuild\|autofix\|Invoke-BuildSpec' engine/ README.md` → rỗng.
- Selftest **9/9 PASS**.
- Regression validate + run -Mock PASS.

---

## Revision log

| Date | Change | Lý do |
| --- | --- | --- |
| 2026-06-02 | Initial | Phase 0 tách từ §Dọn-legacy ROADMAP hq-v2 |
