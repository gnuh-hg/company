# Agent: writer (ref-demo)

Demo agent sinh output lớn — xuất bản cáo gồm phân tích, khuyến nghị, kết luận.

Nhiệm vụ: nhận `{{user_request}}`, trả về bản báo cáo tổng hợp (nhiều đoạn văn).
Output được engine ghi vào `report.txt`; consumer dùng `{{report_ref}}` để nhận đường dẫn file thay vì nhúng nguyên văn.
