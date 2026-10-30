# Sau bản 1.5: gom khu sinh hoạt và nối nhiệm vụ

Ưu tiên tiếp theo là sửa bố trí hoạt động và nhịp ngày chơi. Bản 1.5 đã nâng
kiến trúc và giảm tốc đi, nhưng giữ các điểm nhiệm vụ rải trên map 502 × 547 m.
Đi chậm hơn làm lộ rõ những chặng dài ít việc. Kế hoạch dưới đây chưa được áp
dụng vào bản chơi; không phải báo cáo đã thay map.

## Đối chiếu Nobody

Đã đọc dữ liệu đóng gói trong bản Unity IL2CPP người dùng cung cấp, không phải
project Unity có mã nguồn. MapPanel có bản đồ khu phố và nhóm điểm địa chỉ;
CityTrafficMap có bản đồ di chuyển giữa các khu. Các cụm địa chỉ gần nhau gồm:

- Nhà thuê, nhà nghỉ, siêu thị và quán net.
- Khách sạn, quần áo, phòng khám, quán bánh và điểm bưu kiện.
- Khu nhà ở, rửa xe, bãi đỗ và quán cà phê.

Đây là vị trí giao diện bản đồ, không phải mét trong thế giới. Các marker nhiệm
vụ thuộc nhóm tọa độ khác; trạng thái prefab không xác nhận giờ mở cửa hay nội
dung đang mở trong Story Mode. Không dùng chúng để suy ra thời gian đi bộ.

[Trailer được gửi](https://www.youtube.com/watch?v=kfPlDlSvcGQ) cho thấy thuê
phòng ở khoảng 0:30, dịch vụ phố ở 0:37, học/làm/nghỉ ở 0:44–0:58, quan hệ qua
điện thoại ở 0:59, nhiều công việc ở 1:13–1:34 và đời sống khá hơn ở phần cuối.
Đó là các cảnh giới thiệu hệ thống, không xác nhận thứ tự cốt truyện thực tế.
[Trang Steam chính thức](https://store.steampowered.com/app/1810580/Nobody__The_Turnaround/)
phân biệt Story Mode 30 ngày với Sandbox và mô tả việc làm, nhu cầu sinh hoạt,
học kỹ năng, quan hệ. Không coi mọi cảnh trong trailer là nội dung mở sẵn ở đầu
Story Mode.

Áp dụng cho Trên Phố: một thành phố có nhiều khu nhưng đời sống ban đầu tập
trung trong cụm nhỏ; mở rộng địa bàn khi việc làm và chuyện gia đình tạo lý do
để đi. Giữ câu chuyện An, Linh, bà Thoa và hạn chuyển trọ; không đưa asset hoặc
nội dung truyện của Nobody vào bản phát hành.

## Số đo và chỗ đứt mạch hiện tại

Đo 342 tuyến có hướng giữa 19 địa điểm bằng City.path của map chính tại mã
nguồn 33d822c. Thời gian dưới đây = chiều dài đường / 1,7 m/s, chưa tính tăng
tốc, cua, giảm tốc hẻm 0,82 hoặc mang đồ 0,8. Đây là ước lượng khi đi, không
phải bấm giờ một lượt chơi đầy đủ.

| Tuyến | Đường đi | Đi bộ tối thiểu |
| --- | ---: | ---: |
| Nhà → tiệm sửa | 128,7 m | 76 giây |
| Tiệm → chợ | 84,4 m | 50 giây |
| Chợ → quán cơm | 104,8 m | 62 giây |
| Nhà → tiệm → chợ → tiệm → cơm → nhà | 477 m | 4 phút 41 giây |
| Chợ → phòng ngõ Gạch | 428,7 m | 4 phút 12 giây |

- Lời thoại ngày 3 gọi ngõ Gạch là gần chợ, nhưng đường đi thực tế hơn 400 m.
- QuestGuide hướng dẫn đơn StreetLife trên HUD, còn objective_spots chỉ lấy
  scenes_today và quests_active: đơn đó thiếu dấu mục tiêu tương ứng trên map.
- Sau khi giao đơn, hướng dẫn trở về rỗng; lời nhắc ăn nằm trong log.
- Ngày 1 không có đích địa điểm sau hội thoại mở đầu. Ngày 3 xem phòng hiện là
  lựa chọn trừ giờ/ghi cờ đã xem, chưa phải chuyến đến phòng và khảo sát.
- Có ba đường sửa đồ: quest quạt ngày 2, hành động sửa đồ lẻ và đơn StreetLife.
  Cần phân vai hoặc hợp nhất để tránh mục tiêu/thưởng trùng nhau.

Vòng 477 m chỉ trừ 28,6 phút trong game theo hệ số hiện tại, dù cần gần năm
phút ngoài đời chỉ để đi. Khi nén map cần cân lại chi phí thời gian và cơ hội
kiếm tiền, không giữ nguyên kinh tế rồi vô tình cho làm quá nhiều ca trong ngày.

Đoạn xa các cửa chức năng nhất chỉ là phép dò khoảng cách đến 19 cửa đã đặt
tên, không chứng minh đoạn đó hoàn toàn không có đồ nhặt, NPC hay việc khác.
Dữ liệu và đường đo nằm ở build/journey-audit.json và build/journey-map.json
(bản chẩn đoán cục bộ, không đóng gói vào game).

## Bố trí mới cần dựng thử

1. **Cụm khởi đầu Phúc Tân – chợ – tiệm sửa.** Nhà ở phía sau một phố ngắn;
   quán cơm ngay cửa ngõ; tiệm và quầy linh kiện ở hai đầu phố; có lối vòng về
   sân trọ. Ghép điểm ăn, ghế nghỉ, bảng việc và NPC quen vào những nơi đã có
   mục đích. Giảm số dãy nhà nền chen giữa các điểm chơi.
2. **Cụm việc làm mở rộng.** Bốc vác, giao hàng và điểm xe ở mép cụm đầu. Một
   công việc được giới thiệu trước khi phải sang khu mới; hạn chế đơn giao đầu
   tiên trong khu đã quen. Không rải 744 địa chỉ vào danh sách việc ngay đầu.
3. **Các nơi xa có lý do riêng.** Ngõ Gạch phải gần chợ đúng lời thoại; Ngọc
   Thụy vẫn thể hiện đánh đổi tiền nhà và quãng đi làm. Chặng xa có lựa chọn
   xe/điểm chuyển khu, hiển thị giá và thời gian trước khi đi. Cơ chế này phải
   dùng được ngay khi nhiệm vụ bắt buộc đầu tiên cần nó.

Giữ tỷ lệ nhân vật, chiều rộng lối đi và tốc độ 1,7 m/s. Nén khoảng trống giữa
các hoạt động, không co đồng loạt nhà, người và đường hoặc tăng tốc để che lỗi.
Tạo thêm lối tắt chỉ khi cửa, va chạm và đường đi thực sự thông nhau.

**Mục tiêu thiết kế, chưa phải số đo map mới:** chặng sinh hoạt 18–40 m; vòng
sửa có quay lại tiệm 100–160 m (khoảng 59–94 giây đi thuần); các chặng bắt buộc
trong cụm đầu không quá 45 giây khi kiểm ở góc camera chơi thật. Cửa hoạt động
nên xuất hiện sau tối đa khoảng 25 m trên tuyến chính, nhưng không thêm việc
vặt vô nghĩa chỉ để đạt số lượng. Hiệu chỉnh các ngưỡng sau khi chơi thử.

## Ba ngày đầu cần liền mạch

- **Ngày 1:** về sân trọ, biết hạn dọn nhà → được giới thiệu chú Sơn → một
  việc đầu có thu nhập → ăn ở quán Hạnh → về nhà ghi tiền và bàn với gia đình.
  Vẫn cho phép từ chối/chọn sinh kế khác, có lời dẫn tiếp phù hợp.
- **Ngày 2:** quạt hỏng → kiểm tra → chọn mua linh kiện ở chợ hoặc dùng đồ
  tiệm với giá khác → sửa và thử → trả đúng người → nhận tiền/phản hồi. Một
  tiến độ duy nhất nối tương tác bàn sửa, đối thoại, HUD và bản đồ.
- **Ngày 3:** gặp Linh ở bảng tin → chọn lịch xem phòng → tới phòng, xem cửa,
  chỗ phơi và đường đi → về bàn phương án. Chỉ ghi đã xem sau tương tác tại
  điểm đến; không trừ cả thời gian chuyến đi ở menu rồi lại trừ khi đi thật.

Mỗi bước có người giao, lý do, nơi đến, phản hồi sau hành động và bước kế tiếp.
Gợi ý ăn/nghỉ là lựa chọn sinh hoạt, không khóa người chơi vào chuỗi bắt buộc.
Giờ đóng cửa, từ chối, lỡ hẹn, thiếu tiền và bỏ nhiệm vụ phải có nhánh tiếp tục.

## Thứ tự thực hiện và nghiệm thu

1. Dựng bố cục đơn giản của cụm khởi đầu trên nhánh/map thử. Đo lại đường qua
   cửa thật; đi trọn một ngày trước khi thêm vật liệu hay chi tiết kiến trúc.
2. Hợp nhất trạng thái mục tiêu cho HUD, marker, minimap và tự đi. Nối truyện
   ngày 1–3 với việc sửa; chỉ một nơi được phép trả thưởng/chốt hoàn thành.
3. Thêm đi lại giữa khu; tái cân bằng phí và thời gian game. Giữ ID địa điểm,
   chọn nghề, hạn nhà và save; xử lý save đang giữa đơn/đứng trong nhà bị dời.
4. Chơi thử ngày 1–3, rồi ngày 1–7: đường ngắn nhưng còn lựa chọn, thu nhập và
   hạn hẹn hợp lý; không còn chỉ dẫn tới chỗ đóng cửa, mục tiêu mồ côi hoặc
   nhận tiền hai lần. Kiểm cả nhánh thiếu tiền, bỏ lỡ và lưu/nạp giữa bước.
5. Sau khi nhịp chơi đạt yêu cầu mới hoàn thiện sinh hoạt NPC, clip chạy/quay/
   lên xe, vật liệu và mở rộng cụm còn lại. Đo tải lạnh, khung hình, bộ nhớ trên
   web/thiết bị yếu; không suy từ benchmark GPU của một góc phố.

Bản web/Windows tiếp theo chỉ được ghi là đã nén map và nối truyện sau khi
có số đo, lượt chơi và build xác nhận. Hiện chưa phát hành thay đổi này.
