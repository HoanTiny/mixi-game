# Quan hệ NPC và kinh tế buôn bán

Bản này làm theo tài liệu thiết kế tham khảo, gồm hai phần:

- **Phần 2 (Hệ thống NPC & Cốt truyện):** thành hệ thống quan hệ.
- **Phần 3 mục 4 (Kinh tế & Mô phỏng kinh doanh):** thành bán hàng rong và livestream Shippy.

Cả hai viết theo cùng khuôn với `survival`, `attributes` và `careers`:

| Thành phần | Quan hệ | Kinh tế |
|---|---|---|
| Dữ liệu | `data/systems/relationships.json` | `data/systems/commerce.json` |
| Luật | `scripts/systems/relationships.gd` | `scripts/systems/commerce.gd` |
| Kiểu dữ liệu (TypeScript) | `docs/schema/relationships.d.ts` | `docs/schema/commerce.d.ts` |
| Phần lưu trong save | `s.rel` | `s.biz` |
| Giao diện | app Tin nhắn, thẻ nói chuyện ở xe hoa, bảng Nhân vật | app Shippy, thẻ ở chợ/kho/điểm bán, màn `scripts/ui/live_session.gd` |
| Kiểm thử | `tests/relationships_commerce.gd` | (cùng file) |

`GameLogic` nối hai hệ thống vào game ở các chỗ sau:

- **Nạp dữ liệu:** `Commerce.register()` sinh việc từ dữ liệu.
- **`migrate_save()`:** save cũ tự có `s.rel` và `s.biz`.
- **`_commit()`:** gọi `Commerce.tick()` và `Relationships.tick()`.
- **`apply_effects()`:** xử lý các khóa hiệu ứng `rel_status.X`, `rel_unlock`, `biz`.
- **`check()`:** xử lý các điều kiện `rel_status.X`, `has_item`, `rain_today`, `biz_*`.
- **`add_rep()`:** điểm tăng thì tính là đã gặp người đó, để không bị phai nhạt.
- **`_tick_needs()` (khóa `regen.X`):** trạng thái tốt hồi nhu cầu đều mỗi giờ.
- **`add_fatigue()` (khóa `fatigue.rate`):** trạng thái tốt làm mệt tăng chậm hơn.

## 1. Quan hệ NPC

Điểm thân thiết 0–100 vẫn là `s.rep`, nên nội dung các chương cũ chạy như trước. Phần mới:

- **Bậc quan hệ:** mặc định là Có hiềm khích, Xa cách, Quen, Thân thiết, Tri kỷ. Từng người đặt bậc riêng được: tuyến tình cảm của Hân là Người lạ, Quen mặt, Bạn, Hơn cả bạn, Người thương.
- **Mốc:** lần đầu điểm qua mức `at` (và thỏa `when`) thì mở khóa tin nhắn, đẩy một cảnh truyện (`events_pho.json`) vào hàng chờ, chạy `effects`. Mỗi mốc chỉ chạy một lần.
- **Trạng thái quan hệ:** ví dụ "Cặp đôi". Trạng thái gắn với một trạng thái sinh tồn (`survival.json` → `cap_doi`), nên buff đi qua đường có sẵn:
  - Tâm trạng hồi +1,5 mỗi giờ (`regen.mood`);
  - mệt tăng chậm hơn 15% (`fatigue.rate`);
  - hiện trong bảng Nhân vật như mọi trạng thái khác.
  - Điểm tụt dưới `breakBelow` (60) thì mất trạng thái và chạy `breakEvent`.
- **Tin nhắn (app Tin nhắn trên điện thoại):**
  - Tin tới máy khi thỏa `when`, hoặc khi được mốc mở khóa (`unlockOnly`), và chỉ sau giờ `after`.
  - Mỗi tin có các câu trả lời chọn được, chạy `effects` của lựa chọn đó, cộng `replyRep` và tính là đã gặp.
  - App hiện số tin chưa đọc.
- **Phai nhạt:** người có `decays` (Hân, chị Vy, anh Dũng) không gặp quá 3 ngày thì mỗi ngày tụt 2 điểm, không xuống dưới 30. Nhà và xóm không phai, để giữ cân bằng các chương cũ.

### Nội dung

- **Hân, bán hoa xe đạp** (tuyến tình cảm chính, tương ứng tuyến Hân chủ tiệm hoa trong tài liệu):
  - Đứng ở xe hàng rong `vendor:hoa` từ 6 đến 11 giờ, bắt đầu ở 20 điểm.
  - Tương tác: nói chuyện (có hai đoạn truyện), phụ bó hoa, mời cà phê muối, tặng gấu bông lấy ở trò ném vòng.
  - 35 điểm: Hân cho số, tin nhắn đầu tiên.
  - 50 điểm: cảnh bắt chuột ở kho hoa dưới gầm cầu thang Hàng Lược.
  - 65 điểm: cảnh côn đồ đòi "phí đứng đường".
  - 82 điểm, sau cảnh côn đồ: bún ốc ngõ Hàng Chai, rồi lời hỏi ở bờ hồ. Nói thật lòng thì thành Cặp đôi.
  - Nguội lạnh thì có cảnh "Tin nhắn không trả lời".
- **Chị Vy:** 60 điểm thì có cảnh chị dạy livestream. Học xong thì mở khóa Shippy; nếu chưa học, vẫn có thể nhờ chị sau ở shop.
- **Tin nhắn của người nhà và người quen:**
  - Chị Hạnh mách mối áo mưa sỉ ở chợ Long Biên, giá nhập áo mưa rẻ hơn 10%.
  - Linh hỏi chuyện chị bán hoa.
  - Bà nhờ Linh nhắn hỏi "con ăn cơm chưa".

## 2. Kinh tế buôn bán

### Bán hàng rong

Quy trình theo tài liệu thiết kế: xem giá, nhập sỉ, chở về, chọn chỗ và giờ.

- **5 mặt hàng:**
  - hoa hồng: héo sau 2 ngày, chạy buổi tối;
  - áo mưa giấy: ngày mưa cầu ×3,5, ngày khô ×0,35;
  - đồ chơi trẻ em: cuối tuần ×2;
  - quạt mini cầm tay;
  - áo phông in phố cổ.
- **Giá thị trường:**
  - Mỗi ngày, giá từng món đi theo xu hướng có quán tính, dao động theo `volatility`, kéo dần về mức gốc và kẹp trong khoảng 0,7–1,5.
  - Có sự kiện thị trường: trời mưa thì áo mưa sỉ lên giá; ngày rằm thì hoa lên giá và người mua cũng đông; cuối tuần đồ chơi đắt hàng; quạt mini lên xu hướng mạng.
  - Giá bán lẻ biến động chậm hơn giá sỉ.
- **Xe đẩy và kho:**
  - Xe đẩy chứa 60 món, thêm 15 món mỗi cấp Thể chất.
  - Kho chung ngõ chợ Long Biên: thuê 7 ngày một lần, chứa 300 món.
  - Kho chưa lắp quạt hút ẩm thì hàng vải mốc dần: 8% mỗi ngày mưa, 2% mỗi ngày khô.
  - Hết hạn thuê thì hàng trong kho bị khóa tới khi gia hạn.
- **4 điểm bán:**
  - bờ hồ Gươm: đông buổi tối;
  - phố bia Tạ Hiện;
  - điểm xe buýt Long Biên: đông giờ tan tầm;
  - lối vào chợ Long Biên: được phép bán, nộp vé chợ 10.000đ.
  - Mỗi điểm có lượng khách theo khung giờ và hệ số cầu riêng cho từng món.
- **Bày bán 2 giờ, tính từng giờ:**
  - Khách mua = khách qua × phần để ý × cầu (món × điểm × giờ × thời tiết × thị trường) × tỷ lệ chốt.
  - Tỷ lệ chốt phụ thuộc mức giá (bán rẻ, giá chợ, hét giá), Nhạy bén (+6% mỗi cấp) và Tâm trạng (dưới 30 thì ×0,7). Có khóa `biz.close` sẵn cho buff sau này (xem bói, cây kỹ năng Mặt dày tiếp thị).
- **Trật tự đô thị:**
  - Điểm không được phép bán có xác suất bị bắt mỗi giờ trong giờ đi tuần; Nhạy bén giảm xác suất này.
  - Bị bắt thì mất một nửa hàng trên xe, phạt 150.000đ, Tâm trạng −10, và dừng bán luôn.

### Livestream Shippy

- **Điều kiện mở:**
  - đã học chị Vy, Nhạy bén cấp 2, đã thuê kho;
  - còn hàng bán live được;
  - kênh không bị khóa.
  - Lên sóng ở phòng trọ hoặc quán net.
- **Chuẩn bị buổi live:**
  - Chọn kịch bản:
    - Kể chuyện phố cổ;
    - Xả kho giá sốc: chốt ×1,5 nhưng hoàn ×1,8 và dễ bị khóa kênh;
    - Review thật thà: hoàn ×0,45.
  - Thuê người chốt đơn (thêm 6 đơn mỗi nhịp) và người đóng gói (thêm 25 đơn); trả công sau buổi.
- **Trong buổi live (12 nhịp, 60 giây):**
  - Người xem tăng dần, đông nhất ở một nhịp ngẫu nhiên giữa buổi, nhân theo uy tín shop.
  - Tung voucher: dùng một lần, giảm 10%, chốt ×1,5, gấp đôi nếu bấm lúc đông người xem nhất.
  - Deal chớp nhoáng: chốt ×1,8, phải chờ hồi lại, mỗi lần bấm có rủi ro nói hớ bị khóa kênh 2 ngày.
  - Trả lời bình luận: người xem tăng.
  - Đổi món đang giới thiệu.
- **Quản trị rủi ro:**
  - Đơn vượt sức đóng gói thì bị giao trễ.
  - Sau 2 ngày, mỗi món trong đơn hoặc được nhận (tiền về sau phí sàn 8%, uy tín +0,15) hoặc bị hoàn: mất ship hai chiều, hàng về kho, uy tín −0,8.
  - Xác suất hoàn = gốc 12% × kịch bản, cộng 18% nếu giao trễ, trừ phần uy tín bảo vệ.

### Số đo từ `tests/relationships_commerce.gd`

| Phép thử | Kết quả |
|---|---|
| Một tối bán 50 bông hồng ở bờ hồ | bán khoảng 28 bông, lãi khoảng 170.000đ |
| 40 tối bán ở bờ hồ | bị trật tự đô thị bắt 7 lần, thu trung bình 242.000đ một tối |
| Áo mưa ở điểm xe buýt lúc tan tầm | ngày khô bán 5 chiếc, ngày mưa bán 29 chiếc |
| Voucher | bấm lúc đông người xem: 15 đơn; bấm lúc mở sóng: 10 đơn |
| Tỷ lệ hoàn theo kịch bản | xả kho 28%, review 2% |
| Tỷ lệ hoàn theo giao hàng | giao trễ 17%, đúng hẹn 7% |
| Kho không quạt hút ẩm, 5 ngày mưa | còn 6/10 áo |

## Mở rộng

- **Thêm người:** thêm một mục `npcs.X` vào `relationships.json`. Không cần sửa mã, trừ khi người đó đứng ở chỗ mới; khi đó đặt `anchor`.
- **Thêm món hay điểm bán:** thêm vào `commerce.json` (`goods`, `spots`). Việc nhập, bán và lên sóng tự sinh ra.
- **Buff bán hàng (xem bói, kỹ năng):** cho một trạng thái hay thuộc tính cộng mod `biz.close`.
