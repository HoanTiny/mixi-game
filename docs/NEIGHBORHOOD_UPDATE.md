# Bản 1.6 · Cụm phố và ba ngày đầu

Bố cục phố cổ được dựng lại quanh nhà trọ, tiệm Sơn Sửa, chợ Long Biên và
Cơm Hạnh. Giữ đủ 19 địa điểm cùng ID để các chương sau còn hoạt động; còn
195 nhà nền, 182 địa chỉ giao hàng và 36 điểm nhặt đồ. Phạm vi map là
244 × 210 m. Nhà, nhân vật, lối đi và tốc độ đi bộ 1,7 m/s giữ tỷ lệ hiện có.

## Quãng đường thực đi

Đo bằng đường City.path tới cửa, không dùng khoảng cách thẳng. Mốc so sánh
1.5 là mã nguồn `33d822c`; con số giây là chiều dài / 1,7 m/s, chưa cộng
gia tốc, tránh người, giảm tốc hẻm hoặc khi mang đồ.

| Tuyến | 1.5 | 1.6 |
| --- | ---: | ---: |
| Nhà → tiệm | 128,7 m | 35,3 m |
| Tiệm → chợ | 84,4 m | 24 m |
| Chợ → phòng ngõ Gạch | 428,7 m | 33,6 m |
| Nhà → tiệm → chợ → tiệm → cơm → nhà | 477 m | 148,5 m |

Vòng sinh hoạt giảm 68,9%, từ khoảng 281 xuống 87 giây đi thuần.
Hệ số giờ đi bộ tăng từ 0,001 lên 0,0032 giờ/m: vòng này vẫn tốn khoảng
28,5 phút trong game, gần mức 28,6 phút cũ. Mặt tiền nhà trọ và quán cơm
quay về góc camera chơi; khoảng đệm phía trước bỏ nhà che chân người.
Sân lát/bãi đỗ dùng vật liệu phù hợp thay cho mảng cỏ mặc định.

## Hoạt động và chỉ dẫn

- Ngày 1: được giới thiệu tiệm → có thu nhập đầu → gợi ý ăn → về trao đổi
  với gia đình. Ăn và nghề sửa không bắt buộc; có nhánh đổi việc, thiếu tiền,
  mệt và bỏ đơn.
- Ngày 2: quạt truyện dùng chung bàn sửa với hệ thống StreetLife. Kiểm tra,
  kiếm linh kiện, tháo/lắp, thử máy rồi mang tới chợ trả. Một tiến độ và một
  lần trả thưởng; có ứng linh kiện, trừ khoản ứng đúng một lần khi nhận công.
- Ngày 3: lựa chọn đặt lịch xem phòng dẫn tới địa điểm thật. Chỉ tương tác
  khảo sát tại đó mới ghi đã xem. Lưu/nạp giữa các bước giữ tiến độ.
- HUD, marker trên phố và bản đồ dùng chung QuestGuide. Mục tiêu chính có
  nút đi tới cửa cùng số mét; giờ đóng cửa, hạn hẹn và thiếu tiền có lý do.
- Chuyến xe từ Long Biên tới Ngọc Thụy, hồ Gươm và Tạ Hiện hiện giá/thời gian
  trước khi đi và có chuyến về. Ngọc Thụy/hồ Gươm từ ngày 3, Tạ Hiện từ ngày
  10; người chơi vẫn có thể đi bộ. Giá/giờ là cân bằng game, không là lịch xe thật.
- Đơn giao đầu game lấy món trong 55 m và giao 15–60 m theo đường đi thực.
  Bản lưu cũ được cập nhật địa chỉ đơn khi map đổi, không tự thưởng hoặc phạt.

## Kiểm tra

- `compact_neighborhood`, `city_routes` (387 tuyến), `city_architecture`,
  `story_fronts` (19 cửa), `city_cutaway`, `city_courtyard`.
- `neighborhood_story`: ngày 1–3, nhánh thiếu tiền/lỡ hẹn/bỏ đơn, sửa quạt,
  nhận công một lần, ba lựa chọn phòng, lưu/nạp và tiến tiếp ngày 7.
- `navigation_guidance`, `neighborhood_travel`: mục tiêu thống nhất, giờ/hạn,
  giá xe, chuyến về, chuyển bản lưu và phạm vi đơn giao.
- `neighborhood_world`: đi trọn vòng cửa thật, bảng địa điểm, chuyến xe và
  đặt lại đường đi; chụp GPU tại nhà, quán cơm, điểm xe, Ngọc Thụy.
- Mô phỏng logic `sim.gd` qua 150 ngày. Chưa thay thế cho chơi thủ công mọi
  lựa chọn của năm chương hoặc đo hiệu năng mọi thiết bị.

Đây là đợt sửa nhịp chơi và bố cục. Chưa đạt mức hoàn thiện hình ảnh của
Nobody; không đưa mô hình, texture hoặc nội dung truyện của Nobody vào game.
