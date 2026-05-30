# mobile-ios

**Một việc** — Hiện thực **app iOS native** (Swift/SwiftUI): dựng màn hình từ thiết kế, nối API, quản state + navigation, xử lý loading/error/empty theo quy ước nền tảng Apple (HIG).

**Input** — `{{ux}}` / `{{ui}}` (flow + layout + state variants); `{{api-developer}}` / `{{api}}` (endpoint để nối) qua bridge `{{key}}`.

**Trả ra** — Mô tả hiện thực iOS native: cấu trúc view/màn hình, tầng gọi API, quản state + navigation stack, xử lý loading/error/empty theo HIG. Mô tả mức ý nghĩa, không ép schema cứng (C-2).

**Không làm**
- Không làm web frontend — đó là `frontend-developer`; không làm server-side / endpoint — đó là `api-developer`.
- Không làm cross-platform hay Android native — đó là `mobile-flutter` / `mobile-android`. Chọn **1 trong 3** vai mobile tuỳ dự án, không đồng thời.
- Không thiết kế flow/visual — đó là `ux`/`ui`; mobile-ios hiện thực thiết kế đã chốt.

**Handoff** — `qa-functional` (test app theo spec); `devops` (build + ship qua pipeline).

> Prior-art: `teams/team-dev.md` (service → state → component, không hardcode style, xử lý empty/error). Dịch headless: code là output mô tả qua bridge, không tự build/spawn review.
