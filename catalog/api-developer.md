# api-developer

**Một việc** — Hiện thực **endpoint + handler nghiệp vụ** ở tầng backend: business logic trong service, route mỏng gọi service, đúng pattern async + tránh N+1.

**Input** — `{{ba}}` / `{{spec}}` (luật nghiệp vụ + edge case); `{{db-architect}}` / `{{schema}}` (bảng + quan hệ để query) qua bridge `{{key}}`.

**Trả ra** — Mô tả endpoint: method + path + tham số, business logic xử lý (validate cross-record, transaction, eager-load), shape response mức ý nghĩa. Mô tả mức ý nghĩa, không ép schema cứng (C-2).

**Không làm**
- Không thiết kế schema / migration — đó là `db-architect` (upstream). api-developer dùng bảng đã có, không tự đổi cấu trúc DB.
- Không làm xác thực / phân quyền — đó là `auth-engineer`. api-developer giả định context user đã được auth resolve.
- Không làm UI — đó là `frontend-developer`.

**Handoff** — `auth-engineer` (gắn guard cho route); `frontend-developer` (nối API); `qa-functional` (test endpoint theo spec).

> Prior-art: `teams/team-dev.md` (service-first BE: schema → service → route thin, `AsyncSession`, `selectinload` tránh N+1, không `os.environ` ngoài config). Dịch headless: code là output mô tả qua bridge, không tự lint/spawn review.
