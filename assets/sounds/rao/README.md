# Tiếng rao người bán rong

Chưa có bản thu nào: người bán rong chỉ hiện chữ nổi ("♪ Bánh mì nóng giòn đây!") trên đầu khi đi
qua. Câu chữ nằm trong `data/sounds.json` (`calls[].texts`). Giọng tổng hợp bằng code đã thử và bỏ
vì nghe ra giọng máy; giọng đọc máy (TTS) tiếng Việt thì giấy phép không rõ, không dùng.

## Thêm giọng thật

Thu giọng một người Hà Nội (chính mình, người nhà, bạn bè đồng ý cho dùng trong game).
Không cắt tiếng từ phim, YouTube, phóng sự: không có quyền dùng.

1. Thu bằng điện thoại, ra chỗ thoáng (sân, cầu thang) để có chút vang. Rao **to như rao thật**, đừng đọc.
   Chữ đầu ngắn, chữ cuối ngân dài rồi rơi giọng: "Bánh mì nóng giòn đâ-â-ây".
2. Mỗi câu cắt thành một file 2–5 giây, bỏ khoảng lặng đầu đuôi. Lưu `.ogg` mono (~48 kbps là đủ)
   vào thư mục này với tên bên dưới.
3. Trong `data/sounds.json`, thêm vào lời rao của người bán đó
   `"paths": ["res://assets/sounds/rao/rao_banh_mi_1.ogg", "res://assets/sounds/rao/rao_banh_mi_2.ogg"]`,
   cùng thứ tự với `texts`. Tiếng sẽ phát từ chính người bán, đi theo họ, xa quá 45 m thì im.
   Nghe to nhỏ chưa hợp thì chỉnh `volume_db` (độ to khi đứng cách 6 m).
4. Ghi người thu và sự đồng ý vào `assets/sounds/NGUON.md`.
5. Chạy `tests/street_sounds.gd` (`-- --demo --demo-full`) để kiểm tra file nạp được.

| File | Câu rao | Kiểu |
|---|---|---|
| rao_banh_mi_1 | Bánh mì nóng giòn đây! | loa cầm tay |
| rao_banh_mi_2 | Bánh mì đây, bánh mì nóng đây! | loa cầm tay |
| rao_xoi_1 | Xôi đây… ai xôi xéo, xôi lạc không? | gánh, giọng nữ |
| rao_xoi_2 | Xôi… xôi đây! | gánh |
| rao_ve_chai_1 | Ai đồng nát sắt vụn bán đi! | loa phát băng thu sẵn |
| rao_ve_chai_2 | Ai ve chai, đồng nát bán đi! | loa |
| rao_che_1 | Chè đỗ đen, chè bưởi đây! | xe đẩy, giọng nữ |
| rao_che_2 | Ai ăn chè không? | xe đẩy |
| rao_hu_tieu_1 | Phở đây, phở nóng đây! | xe phở đêm |
| rao_kem_1 | Kem đây… ai kem không? | loa |
| rao_kem_2 | Kem Tràng Tiền đây! | loa |
| rao_hoa_qua_1 | Ai mua hoa quả không? | gánh, giọng nữ |
| rao_hoa_qua_2 | Ổi đây, ai ổi không? | gánh |
| rao_hoa_1 | Ai mua hoa không? | xe đạp chở hoa |
| rao_banh_ran_1 | Bánh rán đây! | gánh |
| rao_banh_ran_2 | Ai bánh rán nóng không? | gánh |

Người bán bóng bay không rao.
