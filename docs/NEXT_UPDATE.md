# Đợt tiếp theo sau bản web 1.4

Ngày chuẩn bị: 28/10/2026. Bản này đưa phố mẫu, nhân vật và xe lên web để xem thử.
Phố mẫu dùng `?street-demo` và không ghi vào save chính. Bản đồ toàn thành phố
chưa được thay hết; chức năng mới của nhân vật/xe dùng chung với bản chơi thường.

## Thứ tự ưu tiên

1. **Tay và thao tác lên xe:** thêm xương/ngón hoặc mesh bàn tay phù hợp để nắm
   tay lái, làm chuyển tiếp lên/xuống xe; giữ tủ đồ, tóc, mũ và các điểm chân/yên.
2. **Xe khi rẽ và qua nền:** tách cụm tay lái/bánh trước, nối tay người theo góc lái;
   thêm phản ứng phuộc nhỏ. Kiểm cả GPU WebGL và batch traffic, không tăng draw
   call theo từng bánh của toàn bộ xe trong thành phố.
3. **Sinh hoạt phố:** ăn cơm, sửa xe và giặt/phơi có động tác tiếp xúc đồ vật;
   rà tránh nhau giữa người chơi, NPC có tên và khách trong phố mẫu.
4. **Mặt tiền và cây:** hoàn thiện cửa, vật liệu cũ, tán cây; sau khi chốt mẫu mới
   nhân rộng sang cụm chợ và các tuyến nối. Theo dõi từng địa điểm đã thay.

## Điều kiện chốt mỗi đợt

- Chụp cùng góc/giờ trên PC và web, kiểm lỗi shader, texture và xuyên vật thể.
- Chơi vòng trọ → cơm → sửa xe → giao hàng → về trọ; kiểm lưu/nạp ở bản thường.
- Đo thời gian tải, khung hình và bộ nhớ trên trình duyệt; không suy từ FPS PC.
- Có bản web gắn mã commit để đối chiếu. Giữ khả năng mở lại bản triển khai trước.

Không bắt đầu thay toàn map hoặc thay rig hàng loạt trong đợt triển khai web này.
Phần tiếp theo sẽ ưu tiên bàn tay/tư thế và cụm lái trên một xe của An trước.
