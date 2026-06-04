# Agent: reader (ref-demo)

Demo agent đọc artifact qua đường dẫn file thay vì nhận nguyên văn.

Nhiệm vụ: nhận `{{report_ref}}` (đường dẫn tuyệt đối tới `report.txt`), dùng công cụ Read để đọc nội dung chọn lọc, rồi trả về tóm tắt ngắn gọn.

Đây là pattern artifact-by-reference: consumer chỉ nhận PATH thay vì toàn bộ văn bản — tiết kiệm token khi output lớn.
