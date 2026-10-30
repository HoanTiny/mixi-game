# Tuần đầu: hợp đồng truyện và lưu game

Đợt triển khai sau rà soát thiết kế, trên nền 1.15. Không phải nghiệm thu toàn bộ 30 ngày.

## Quyết định kinh tế

Giữ mô hình đã phát hành: 46.000đ tiền mặt và 1.400.000đ quỹ cọc riêng, 60.000đ tiền trọ/đêm; không thu thêm sinh hoạt gia đình tự động ở chương 1. Đây là thay đổi có chủ ý so với bản thiết kế nền 1.6 (1,2 triệu tiền mặt và 120.000đ sinh hoạt). `economy.json` cung cấp tiền khởi đầu, tiền trọ và sinh hoạt cho hệ hardship, tránh hai bộ số độc lập. Lời thoại đọc tiền thực, quỹ cọc và tiền trọ từ logic.

Tiền công ca thường chụp hệ số phong độ trước khi trôi thời gian ca. Đơn sửa đã nhận giữ nguyên báo giá cũ. Hợp đồng ngày 5 là công khoán cố định 130k/160k nếu đạt tối thiểu 50% chỉ tiêu; không có thưởng nóng hoặc thưởng thành tích cộng thêm. Ca thử chưa đạt không trả công, có thể thử lại trong thời hạn. Các ca thường vẫn mở như phương án kiếm sống khác.

## Nhiệm vụ ngày 5–6

- Ngày 5, đi với bà: tới Ngõ Gạch xem phòng rồi về nhà trao đổi. Ghi nhận đã xem khi tới bước tương tác, không tự đặt cọc.
- Ngày 5, nhờ Linh: thực hiện mini-game phụ quán rồi báo chị Hạnh để nhận công khoán đã trừ tiền xe.
- Ngày 5, nhận cả hai: làm ca, tới xem phòng muộn rồi quay lại nhận công. Hậu quả gia đình chỉ ghi khi hoàn thành, chưa mô phỏng NPC bà đi cùng.
- Hạn các việc ngày 5 là 18h ngày hôm sau để còn đường hẹn lại/thử lại; không tự đổi ngày các sự kiện khác.
- Ngày 6, chia tuyến hoặc nhận phần gần: lấy món nhiệm vụ ở quán, mang tới Tạ Hiện/chợ Long Biên, tương tác giao đủ rồi nhận 70k/60k. Hạn giao 90 phút game sau khi lấy. Quá hạn thu hồi món nhiệm vụ, không trả công.
- Nhánh giao toàn bộ 12 suất giữ nhiệm vụ hiện có.

Các nhánh dùng máy trạng thái quest hiện có và guide hiện có. Hội thoại chỉ mở quest; reward chỉ chạy khi hoàn thành. Ca riêng chỉ xuất hiện đúng bước và không hỗ trợ tự động. Tiến độ, vật phẩm, thời hạn lưu trong quest; save cũ đã giải quyết hội thoại không bị mở lại hay trả tiền lại. Chưa thay toàn bộ nghề bằng JobSpec/JobResult.

## Save

Ghi `.tmp`, flush/đóng và kiểm tra JSON, sao lưu bản chính hợp lệ sang `.bak`, sau đó rename tệp tạm. Nếu bản chính hỏng/mất thì đọc backup. Không ghi đè backup hợp lệ bằng bản chính hỏng. Bổ sung `schemaVersion=2` và `worldLayoutVersion` vào trạng thái đã khởi tạo. Web vẫn phụ thuộc cơ chế lưu bộ nhớ trình duyệt của Godot; cần kiểm tra riêng mất điện/đóng tab thực tế trước nghiệm thu phát hành.

## Kiểm tra và giới hạn

`tests/story_week_one.gd`: năm nhánh, nhận lời không trả tiền, ca không tự động, thử lại, giao nhận/nhận công một lần, tải giữa nhiệm vụ, giao muộn và khôi phục backup.

`tests/economy_relationships.gd`: thay benchmark không quỹ cọc lỗi thời bằng cấu hình sinh tồn đang dùng; trả tiền trọ trước nghỉ, giặt tiệm có trả tiền, kiểm tra có thể đạt cọc trước ngày 26. Đây là một lịch mẫu, chưa thay cho ma trận ba nghề × ba hiệu suất × ba phương án lương cũ.

Đã chạy đạt: `story_week_one`, `economy_relationships`, `phuc_tan_economy`, `service_minigame`, `neighborhood_story`. Test truyện cũ cấp 200k trong fixture để kiểm tra riêng tuyến mua linh kiện ở tiệm giá 50k; các bài kinh tế vẫn kiểm đúng 46k mở đầu, và các nhánh thiếu tiền vẫn đặt ví về 0. Mô phỏng ca kho đủ chỉ tiêu đạt quỹ cọc ở ngày 2, chưa phải trả đủ chi phí thuê nhà.

Còn phải nghiệm thu: chơi trực tiếp UI ngày 5–6, 5–8 người mới thử tuần đầu, chuỗi ngày 8–30 và bốn thẻ kết quả, chuyển chương/đổi nhà, hiệu năng web. Không có thay đổi mỹ thuật hoặc bản đồ trong đợt này.
