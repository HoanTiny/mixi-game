# Sau bản 1.18

Chơi thử 1.17 bằng người chơi máy đủ 30 ngày ba tuyến A, B, C, cộng một lượt chơi tay trên web tới sáng ngày 1. Kinh tế chương 1 và các lỗi giao diện tìm được đã sửa ở 1.18 (xem [WEB_RELEASE.md](WEB_RELEASE.md)).

Ưu tiên tiếp theo:

1. **Kết kiệt sức không còn đạt được.** Từ khi có Tâm trạng (chạm đáy thì không đi làm được), làm không nghỉ bị chặn trước khi Mệt đủ cao. Mô phỏng không còn lượt nào ra E6, K6, L6, M6; chỉ N6 còn. Cần chọn một trong hai:
   - tính những ngày Tâm trạng chạm đáy vào điều kiện kiệt sức;
   - hoặc chấp nhận kiệt sức giờ thể hiện bằng Tâm trạng và sửa điều kiện các kết đó.

   Phần chuyển tiếp tiền chương 1 → 2–5 cho các cách chơi có nghỉ đã cân ở 1.18 (sinh hoạt chương 2–5 bỏ tiền ăn của An).
2. **Chơi thử bằng người thật từ ngày 1 đến ngày 7.** Lượt máy đi bộ, làm việc, nói chuyện như người chơi bấm, nhưng không thay được cảm nhận. Ghi:
   - thời gian tới mục tiêu;
   - chỗ phải mở bản đồ;
   - số lần thiếu tiền trọ hay linh kiện;
   - lần bỏ dở vì không biết làm gì.
3. **Cho người chơi máy dùng các hệ thống mới.** Hiện nó không học trường đêm, không học cây tài năng, không bán hàng rong, không livestream, không nhận việc thưởng nóng, và không tán gẫu (Hân chỉ được 20 điểm thân thiết). Thêm các cách chơi này vào `tests/playtest.gd` hoặc `tests/sim.gd` rồi đo lại.
4. **Trường đêm ở chương 1:**
   - học phí 1,5–1,8 triệu, việc có bằng chỉ hơn việc thường khoảng 80k mỗi ca, phải 20–25 ca mới hoàn vốn, nên trong 30 ngày đầu là cái bẫy;
   - hoặc khóa tới chương 2, hoặc thêm gợi ý rõ;
   - giờ học 18–21h trùng ca tối thưởng nóng là đánh đổi hay, nên nói ra cho người chơi.
5. **Đoạn mở đầu dài:** khoảng 20 lần bấm (3 tin nhắn, 6 dòng hướng dẫn, 9 dòng cảnh) mới được đi. Có thể dời hướng dẫn vào lúc đi bộ.
6. **Lỗi nhỏ còn lại:**
   - mũi tên vàng chỉ nhiệm vụ có lúc đè lên biển "Hẻm trọ · Phúc Tân";
   - trình duyệt chưa từng chơi vẫn hiện "Chơi tiếp · Đã tới màn kết";
   - một khoản thu 500.000đ trong dữ liệu truyện chưa có nhãn (`cash` không kèm `cash_label`).
7. **Đo tải, bộ nhớ và khung hình trên web/thiết bị yếu.** Lọc màu, viền mực và khoảng 480 vết bẩn từ 1.13 chưa được đo trên điện thoại thật.

Không tăng mật độ nhà chỉ để lấp khoảng trống; kiểm đường đi, mặt tiền và tầm nhìn ở góc camera chơi trước khi thêm chi tiết.
