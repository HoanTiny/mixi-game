# Bản 1.5 — phố cổ và nhịp sống

Phạm vi: toàn bản đồ chơi chính `hn_pho_co`. Các map cũ vẫn giữ kiến trúc riêng.
Mẫu ba địa điểm của 1.4 đã được mở rộng; đây chưa phải thay toàn bộ asset thành
mô hình quét thực tế hoặc đạt mức hình ảnh của Nobody: The Turnaround.

## Kiến trúc và tầm nhìn

- Cả 19 địa điểm truyện có mặt tiền theo công năng: trọ, quán cơm, sửa xe, chợ,
  bến xe, bốc vác, quán net, cầm đồ, quần áo, bi-a, tóc, hồ và dãy quán bia.
- 1.355 lô nền được phân loại: 1.268 nhà hướng phố với 1.371 mặt tiền, 80 nhà
  bên trong cụm, một công trình đặc biệt, sáu khối thấp. 491 nhà ống cao được hạ
  phần nhìn thấy; footprint, số nhà giao hàng và dữ liệu chiều cao gốc giữ nguyên.
- Mặt tiền có 1.674 cửa ra vào và 2.262 cửa sổ dựng có độ sâu, ban công, cửa cuốn,
  vữa cũ và chân tường ẩm. Chi tiết được gom thành 102 cụm theo ô bản đồ.
- Cây đổi sang tán lệch có cành, màu trầm; số cây thực tế phụ thuộc vùng giữ
  thoáng quanh địa điểm (lần dựng map thường có 839 cây).
- Tầng trên, mái và vách che người được cắt riêng. Sân trọ có nền đi được và
  hành lang vào sân. Biển quay lưng hoặc bị cắt có nhãn tên địa điểm thay thế.
- Góc gần, đèn, vòng chọn và tên NPC áp dụng trên cả phố cổ; vẫn thu nhỏ để xem
  toàn thành phố được, không coi kích thước người ở chế độ toàn cảnh là lỗi.

## Di chuyển và câu chuyện

[Trailer người dùng gửi](https://www.youtube.com/watch?v=kfPlDlSvcGQ) được phân
tích theo cảnh; đã đối chiếu trực tiếp cảnh phố/sân và căn phòng. Trailer gợi
nhịp tìm nơi ở → gặp người → làm việc → nghỉ ngơi → cải thiện đời sống. Nó không
đủ để kết luận toàn bộ cốt truyện hoặc đo chính xác tốc độ nhân vật của game đó.

Game giữ câu chuyện An, gia đình và hạn dọn trọ hiện có. 19 địa điểm có lời dẫn
nguyên bản theo sáng/trưa/tối và trời mưa trong chương đầu; chương sau giữ mô tả
theo tiến triển truyện. Hướng dẫn có khoảng nghỉ 14 giây sau khi đóng, chờ bảng
địa điểm/hội thoại đóng rồi mới hiện tiếp.

Đi bộ 1,7 m/s; Shift chạy nhẹ 3,15 m/s; xe giao hàng 4,8 m/s. Thêm quãng tăng/
giảm tốc và nhịp hoạt ảnh theo vận tốc thật, xử lý va chạm cả bước cuối đường
tự đi. Chi phí thời gian/thể lực vẫn theo mét. Chi tiết và giới hạn hoạt ảnh ở
[LOCOMOTION_UPDATE.md](LOCOMOTION_UPDATE.md).

Đường tự đi dùng kiểm tra mọi ô lưới đoạn đường đi qua, sửa cắt góc nhà và nối
sai điểm cuối do cache. Sân trọ có trọng số đường phù hợp để không bị kéo đích
ra ngoài phố. Kiểm 426 tuyến gồm mọi cặp 19 địa điểm, 74 địa chỉ giao hàng trên
26 tuyến phố và đường trong sân; giữ đủ 744 địa chỉ.

## Kiểm tra và giới hạn

- `city_architecture.gd`, `story_fronts.gd`, `city_routes.gd`: độ phủ, hình học,
  nhóm cắt tường, cửa và đường đi.
- `locomotion_pacing.gd`, `player_motion.gd --integration`: tốc độ, hãm ở
  30/60/120 FPS, đoạn cuối, thời gian theo mét, xe và đèn.
- `city_upgrade_review.gd`: ảnh GPU của 19 địa điểm, sân, đêm, mưa và toàn cảnh.
  Số liệu lưu trong `build/city-review.json`; mẫu khung hình ngắn trên GTX 1650
  không đại diện cho mọi góc map hoặc điện thoại.
- Lượt GPU cuối: dựng phố 8,46 giây khi cache đã ấm; mẫu 180 khung hình ở quán
  cơm trung bình 16,67 ms, p99 16,92 ms. Lần tải lạnh đầu tiên lâu hơn rõ rệt.
- `city_cutaway.gd` kiểm cắt 21 vật che ở 19 điểm; `city_courtyard.gd` kiểm
  click nền sân qua các vách đã ẩn và phục hồi vách khi thu nhỏ toàn cảnh.
- Chưa có clip chạy/quay tại chỗ/lên xe mới; Shift tăng nhịp clip đi hiện có.
  Chưa viết lại các chương truyện, minigame hoặc toàn bộ lịch sinh hoạt NPC.

Web xem thử cả map dùng `?city-demo` và không ghi save chính; phố mẫu ba điểm
cũ vẫn có ở `?street-demo`. Bản tải Windows hiện vẫn là 1.3.2.
