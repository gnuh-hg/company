# Caching Analysis — Phase I.D.1 (2026-06-04)

> **Mục tiêu:** Xác minh prompt-caching khả thi qua `claude -p` headless không, và nếu có thì cách
> tận dụng. Session này **mock-only** (KHÔNG đốt token) — đọc code + CLI help. Đo thực tế ở I.D.2.

---

## Kết quả phân tích CLI

### Cờ liên quan tìm được (`claude --help`)

| Cờ | Mô tả | Áp dụng cho ta? |
|---|---|---|
| `--exclude-dynamic-system-prompt-sections` | "Move per-machine sections (cwd, env info, memory paths, git status)... **Improves cross-user prompt-cache reuse.** Only applies with the **default system prompt** (ignored with --system-prompt)." | **KHÔNG** — bị ignored khi dùng `--system-prompt-file` |
| `--betas <betas...>` | "Beta headers to include in API requests (**API key users only**)" | Điều kiện: phải dùng API key (không phải OAuth) |
| `--system-prompt-file` | Đọc system prompt từ file .md (cách ta dùng, Phase 5.1) | Có (core của engine) |
| Không có `--cache` flag | Không có cờ tường minh enable/disable caching | — |

### Gọi hiện tại trong engine (`lib/claude.ps1` line 103)

```powershell
$claudeArgs = @('-p', '--system-prompt-file', $SystemPromptFile, '--output-format', 'json')
```

Thứ tự tham số:
1. `-p` (print/headless mode)
2. `--system-prompt-file <agents/xxx.md>` → **STABLE** per agent type
3. `--output-format json` → đọc `.result` + `.usage` (I.A.1)
4. (optional) `--model`, `--allowedTools`, `--permission-mode`
5. User prompt qua stdin: resolved template → **VARIABLE** per run

---

## Kết luận: Cache được/không + cách

### ✅ Caching KHUYẾN NGHỊ có thể xảy ra tự động

Claude Code (`claude -p`) giao tiếp với Anthropic API — và Anthropic API đã hỗ trợ prompt-caching
cho system prompt từ 2024. Dựa trên phân tích:

1. **System prompt** (`--system-prompt-file agents/xxx.md`) = ổn định per agent type → đủ điều kiện
   cho cache hit nếu cùng agent được gọi nhiều lần trong TTL (5 phút).
2. **User prompt** (resolved template) = biến thiên mỗi run → KHÔNG cache được (quá dynamic).
3. Flag `--exclude-dynamic-system-prompt-sections` cho thấy Claude Code CÓ cơ chế caching nội bộ.
   Tuy nhiên flag đó chỉ cho default system prompt (ta dùng custom → bị ignored).

### ⚠️ Giới hạn xác định

| Giới hạn | Chi tiết |
|---|---|
| **Không có `--cache` flag tường minh** | Không thể bật/tắt caching theo cờ CLI trực tiếp |
| **`--betas` cho API-key users only** | Nếu dùng OAuth → `--betas prompt-caching-2024-07-31` không có tác dụng hoặc lỗi |
| **`--exclude-dynamic-system-prompt-sections` bị ignored** | Flag cải thiện caching chỉ cho default system prompt, không cho `--system-prompt-file` |
| **Cache TTL = 5 phút** | Chỉ nodes gọi cùng agent trong 5 phút liên tiếp mới hit cache |
| **Ngưỡng tối thiểu = 1024 tokens** | System prompt < 1024 tokens → KHÔNG cache được |
| **Mỗi node = 1 CLI process riêng** | Không share context giữa các invocation → mỗi call là fresh |
| **Không biết caching tự-bật chưa** | Cần I.D.2 real-run để xác nhận (xem `cache_read_input_tokens > 0`) |

### Tình huống cache hit khả thi

Caching HIT khi:
- Cùng agent file (`agents/xxx.md`) được gọi ≥2 lần trong 5 phút
- Ví dụ: `loopy` (build–test–verdict lặp lại) → build/test agent có thể hit cache ở iter 2+
- Ví dụ: `web-demo` linear pipeline trong 1 run — các agent KHÁC nhau → KHÔNG hit nhau

Caching MISS:
- Mỗi node có agent riêng (web-demo 11 agents = 11 system prompts khác nhau)
- Agent chỉ gọi 1 lần per run (linear pipeline)

---

## Cách tận dụng caching (nếu có)

### Convention thứ-tự-prompt tối ưu (HIỆN ĐÃ ĐẠT)

```
System prompt (--system-prompt-file agents/xxx.md)  ← STABLE prefix, cache-eligible
├── Agent role/identity          (fixed)
├── Task description              (fixed)
└── Output format instructions    (fixed)

User prompt (stdin, template resolved)              ← VARIABLE suffix, không cache
├── {{user_request}}              (biến thiên)
├── {{previous_output}}           (biến thiên)
└── ...
```

**Engine hiện tại đã đúng thứ tự:** stable trước (system prompt), variable sau (user prompt).
Không cần thay đổi cấu trúc.

### Điều kiện tối ưu cache hit

1. **System prompt ổn định**: Không nhúng `{{key}}` dynamic vào agent `.md` files (đã đúng — agents .md là text tĩnh).
2. **Cùng agent, nhiều lần trong 5'**: Pipeline có vòng lặp (loopy) → build/test agent được gọi nhiều lần → BEST candidate cho cache savings.
3. **System prompt > 1024 tokens**: Chỉ agent có system prompt đủ dài mới được cache. Stub agents ngắn (~10-20 lines) có thể dưới ngưỡng.
4. **Haiku cho branching** (đã có từ I.B.1): Haiku cũng hỗ trợ prompt-caching → tiết kiệm token trên nhánh nhỏ.

### Nếu caching chưa tự-bật (kết quả I.D.2 cho thấy `cache_read = 0`)

**Option A: `--betas prompt-caching-2024-07-31`** (cho API-key users)
- Wire vào `lib/claude.ps1`: thêm param `[string]$Betas` + `if ($Betas) { $claudeArgs += @('--betas', $Betas) }`
- Caller truyền khi muốn enable: `Invoke-Claude ... -Betas 'prompt-caching-2024-07-31'`
- Risk: lỗi nếu OAuth user; không biết nếu còn cần (có thể đã GA)

**Option B: Chấp nhận caching tự-động**
- Nếu API đã tự cache system prompt → không cần làm gì thêm
- I.D.2 sẽ confirm: `cache_creation_input_tokens > 0` ở call đầu, `cache_read_input_tokens > 0` ở call sau

**Recommendation (chờ I.D.2):** KHÔNG wire code mới trước khi có data thực tế. I.D.2 sẽ reveal.

---

## Cách đo tại I.D.2 (real-run gate)

I.A.1 đã wire kênh đọc cache metrics từ `--output-format json`:

```powershell
# lib/claude.ps1 lines 162-163 — đã có:
if ($pu.PSObject.Properties.Name -contains 'cache_creation_input_tokens') { $u.cache_creation = [int]$pu.cache_creation_input_tokens }
if ($pu.PSObject.Properties.Name -contains 'cache_read_input_tokens')     { $u.cache_read     = [int]$pu.cache_read_input_tokens }
```

**Lệnh đo tại I.D.2:**
```powershell
# Chạy real (không -Mock) — ĐỐT TOKEN, USER-GATE
./run.ps1 run loopy "build a web feature" 
./run.ps1 tokens loopy
# → xem cột cache_creation / cache_read per node
```

**Diễn giải kết quả:**
| cache_creation > 0 | cache_read > 0 | Ý nghĩa |
|---|---|---|
| ✓ | 0 (call đầu) | Cache được tạo; lần tiếp theo trong 5' sẽ hit |
| ✓ | ✓ (call sau) | **CACHE HIT** — tiết kiệm input tokens (đọc từ cache, rẻ hơn) |
| 0 | 0 | Caching KHÔNG xảy ra; kiểm tra Option A (`--betas`) |

**Fixture tốt nhất để đo cache:** `loopy` — build/test agent lặp nhiều vòng → best chance for cache_read > 0.

---

## Tóm tắt hành động

| Hạng mục | Trạng thái | Ghi chú |
|---|---|---|
| CLI không có `--cache` flag | ✅ Ghi nhận | Document trong caching.md |
| `--exclude-dynamic-system-prompt-sections` | ✅ Ghi nhận | Ignored khi dùng `--system-prompt-file` |
| Convention thứ-tự-prompt | ✅ ĐÃ ĐẠT | Engine hiện tại đúng thứ tự; không cần thay đổi |
| Wire `--betas` | ⏳ DEFER đến I.D.2 | Chỉ wire nếu I.D.2 cho thấy cache_read = 0 |
| Kênh đo cache | ✅ ĐÃ CÓ (I.A.1) | `cache_creation_input_tokens` / `cache_read_input_tokens` |
| Xác nhận cache thực tế | ⏳ I.D.2 | Real-run + `run.ps1 tokens` xem số thật |

---

*Phân tích bởi hq-self-builder, session I.D.1, 2026-06-04.*
*Dữ liệu: `claude --help` output + `engine/lib/claude.ps1` code read.*
