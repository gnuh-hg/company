# HQ Team Playbook — SKELETON (đầy đủ ở H.9)

> "Bộ não" điều phối của lead khi chạy HQ như native team (TeamCreate). Skeleton dựng ở
> H.1; nội dung đầy đủ đổ ở Session H.9. Xem `plan/hq-v2/phase-h/design.md` §1, §5, §6.
>
> ⚠️ TRẠNG THÁI: skeleton — mỗi mục mới có ý đồ, chưa đầy đủ.

---

## 1. When to team (khi nào spawn vs lead tự làm)

_TODO H.9._ Bảng quyết định: request phức tạp/multi-file/domain mới → spawn full team
(researcher→planner→cto→builder→tester); request đơn giản (clarify, status) → lead tự xử;
fix branch đã có → spawn builder+tester. Size thực tế 3–5 teammate. (design.md §1)

## 2. Lifecycle teammate (vòng đời)

_TODO H.9._ spawn → assign Task → SendMessage → ack-cùng-turn → TaskUpdate
in_progress→completed → shutdown_response đúng protocol → cleanup. Bài học leafnote:
ack ngay trong turn, KHÔNG silent-complete.

## 3. Anti-pattern

_TODO H.9._ lead-DIY vượt ngưỡng; scope-drift; stale-context. Port mã lỗi từ leafnote
issue-queue.

## 4. Issue queue

_TODO H.9._ File `company/.claude/team-issues-queue.md` (tạo ở H.9) + format mỗi issue
(code · mô tả · teammate · trạng thái).

## 5. Build-deliverable contract (REVISE Q2 — thay "Engine-as-tool")

_TODO H.9._ Trỏ skill `build-verify` (H.7). Builder **Write/Edit file deliverable TRỰC TIẾP**
vào `projects/<name>/` + Bash chạy build/test; tester verify bằng **check khách quan của chính
deliverable** (test/build/lint exit-code → in `CHECK_RESULT: pass|fail`). **KHÔNG engine-build**
(`run.ps1 autobuild/build/check/trial` đã loại khỏi luồng HQ). Engine + app là tool
workflow-chi-nhánh đứng riêng, chỉ gọi nếu request CỤ THỂ là dựng workflow pipeline. (design.md §5/§6)

## 6. Memory protocol

_TODO H.9._ Trỏ skill `hq-memory` (H.8). Đọc `context.md`+`mistakes.md` đầu task; append
entry cuối task. KHÔNG nhầm với engine store `company/memory/`. (design.md §4)
