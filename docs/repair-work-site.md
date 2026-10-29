# Ca sửa đồ tại Tiệm Chú Sơn

Triển khai trong `scripts/work/work_site.gd` (mini-game `repair`). Bàn kéo thả của nhiệm vụ sửa quạt dùng cảnh riêng, không bị đổi quy trình.

- E lấy máy ở quầy, E đặt máy lên bàn. Máy chiếm hai tay.
- Giữ E 2 giây tại bàn để kiểm tra. Chỉ sau đó mới hiện linh kiện cần thay; triệu chứng khách mô tả vẫn được hiển thị ở quầy.
- Lấy tối đa hai linh kiện ở kệ. Món lấy cuối là món được thử lắp trước.
- Q bỏ món cuối và cập nhật tay/UI ngay. Linh kiện được hoàn trả, không tạo vật rơi hay collider trên sàn. E tại khay hoàn trả cạnh kệ trả toàn bộ đồ trên tay. Nếu bỏ máy khách, máy được đặt lại quầy để đơn không bị mất.
- Đúng linh kiện: giữ E 3 giây tại bàn để lắp. Chỉ tiêu hao một linh kiện khi hoàn thành, sau đó lấy máy trả khách để nhận công như trước.
- Sai linh kiện: thông báo nổi, trừ 5 giây, giữ nguyên món sai để người chơi bỏ bằng Q. Key repeat không tự trừ thêm thời gian; mỗi lần thử mới là một lần phạt.
- Thả E, di chuyển, rời tầm bàn, mất focus, khách bỏ đi hoặc hết ca đều hủy tiến trình đang giữ. Linh kiện chưa lắp xong không bị mất. Phải giữ lại từ đầu; không tự chuyển sang bước tiếp theo.
- Có nút giữ thao tác và nút bỏ món cuối cho chuột/chạm.

## Kiểm tra

`tests/repair_work_site.gd` kiểm tra giới hạn tay, Q theo thứ tự lấy, trả khay, khôi phục máy tại quầy, chẩn đoán 2 giây, lắp 3 giây, hủy thao tác, sai linh kiện/phạt một lần, khách bỏ đi, hết giờ và trả thưởng một lần. Chạy với `-- --demo --demo-full` để không ghi đè save người chơi; thêm `--repair-visual` khi dùng renderer để xuất ảnh vào `build/repair-flow/`.

Bộ test mini-game chung tại thời điểm thay đổi còn 8 assertion cũ về tiền công (giới hạn lương trước bản 1.13). Chạy lại với `work_site.gd` từ HEAD `9bf7a43` cho cùng 8 lỗi; thay đổi này không sửa cân bằng lương.
