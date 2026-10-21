# 08 · Chuyển sang game

Tài liệu này so "Trước mùa mưa" với game cũ trong project Godot, liệt kê việc cần đổi trong `data/` và `scripts/`, và đề xuất thứ tự làm.

## Tiến độ

- **Đã chốt 5 câu hỏi:** bỏ game over, giữ đồng hồ giờ, bỏ kỹ năng và lớp học của An, gộp thành chỉ số Mệt, bỏ chọn món đồ và suất ăn.
- **Đã làm lát cắt ngày 18–22** (bước 2 và một phần bước 3, 5, 6 của thứ tự bên dưới):
  - Ba điểm xuất phát A/B/C dựng sẵn trong `config.json` (`presets`).
  - Logic mới: tiền mặt / phải thu / phải trả, tiến độ hợp đồng và nghiệm thu, Mệt (có đếm ngày cảnh báo và lần bỏ qua nghỉ), sổ lời hứa, sổ gia đình, Linh tự quyết.
  - Nội dung ngày 18–22 trong `events.json`, có biến thể cho tuyến A ở ngày 18 và 20.
  - Màn phố đổi sang 6 địa điểm mới, có rạch và cầu. HUD mới có hai cột tiền, Mệt và Sổ.
  - Bảng tổng kết lát cắt.
  - `tests/sim.gd` chạy 3 tuyến × 3 cách chơi.
- **Đã gộp vào nhánh `feature/noi-chuyen`** cùng các cơ chế kiểu Nobody: nhu cầu cơ thể (ăn, tắm, giặt) và Phong độ tính theo Mệt, trò chơi nhỏ (xếp hàng ở ca kho, rửa bát ở Cơm Hạnh), app giao đồ, lục ve chai, nói chuyện với 8 nhân vật, việc nhờ nhiều bước.
- **Đã làm đủ 30 ngày** (chọn "Bắt đầu ngày 1" ở màn đầu; lát cắt 18–22 vẫn giữ để thử nhanh):
  - Nội dung ngày 1–30 trong `events.json`, mỗi ngày một cảnh chính với 3 lựa chọn lấy từ `narrative_design.json`, có biến thể theo tuyến (ngày 12, 15, 18, 20, 27) và theo việc đã làm (ngày 13, 16, 17, 24, 26, 29).
  - **Cảnh chính gắn địa điểm** (`loc`, `window`): không bật lên buổi sáng mà chờ An tới nơi (dấu ◆ vàng trên phố, thẻ ◆ ở địa điểm, dòng "Hôm nay" ở bảng mục tiêu). Cảnh không gắn địa điểm (tin nhắn, mưa, ngày 30) vẫn bật buổi sáng.
  - **Nếu bỏ lỡ** (`missed`, `missed_effects`, `missed_choices`): sáng hôm sau có tin "Hôm qua An không tới". Ngày 11 và 26 được chọn lại ở tin này; quá ngày 12 chưa chọn tuyến thì đi đường làm công.
  - **Lương cũ** ngày 4 → 17 → 24 (hai mốc, khép sớm 2,8 triệu, hoặc chưa chốt).
  - **Tuyến nghề ngày 11** tạo các khoản thu chi của hợp đồng theo `contracts` trong `config.json`; nghiệm thu giữa kỳ ngày 20 mở giai đoạn cuối, bàn giao trước ngày 27. Ngày 12 khách tự mua vật tư thì tính lại giá dịch vụ 4,4 triệu và hoàn phần ứng dư.
  - **Chỗ ở thật:** xem phòng (ngày 3 hoặc việc tùy chọn ở chợ), đặt cọc giữ chỗ (ngày 12 lựa chọn dùng tiền ứng), chốt ngày 26, chưa chốt thì hết ngày 30 sang ở nhờ dì Năm.
  - **Mưa ngày 15 và 29:** trời xám, sương mờ, mưa rơi trên phố, đèn đường bật sớm. Thiệt hại tùy việc chuẩn bị ngày 14, 23, 28, không tung xúc xắc.
  - **Mưa trên bản đồ** (`scripts/world/rain_layer.gd`, mức ngập ở `rainFlood` của `config.json`): rạch dâng tràn hai bờ, vũng nước trên đường, gợn nước chỗ mưa rơi, nước bắn quanh chân, An che dù, phố vắng bớt người và xe. Ngày 15 ngập Hẻm Bờ Nam; ngày 29 ngập thêm đường Bờ Me và khúc cuối các hẻm đổ ra rạch (nước đục màu phù sa). Lội chỗ ngập đi chậm hơn và tốn giờ gấp 1,6 lần; bản đồ tô xanh chỗ ngập.
  - Trước xóm trọ thấy ngay kết quả chuẩn bị: đã chuẩn bị thì thùng đồ kê gạch, trùm bạt xanh, đồ phơi đã cất; Linh che giùm thì chỉ phần của em và bà được che; bỏ chuẩn bị thì thùng ướt sẫm màu, thau hứng nước dột, đồ phơi ướt sũng trên dây. Ngày 14 chia việc cho cả xóm thì nhà hàng xóm dọc Bờ Me cũng phủ bạt.
  - **8 kết thúc E1–E8** xét theo thứ tự E8 → E6 → E7 → E5 → E4 → E2 → E3 → E1 (`ending_key()` trong `game_logic.gd`, ngưỡng ở `endings` của `config.json`), màn kết có thẻ Linh, thẻ bà Tư, một thẻ quan hệ nghề và các khoản còn phải xử lý.
  - Việc tùy chọn theo ngày và việc giữ lời hứa (`showIfPromise`) ở các địa điểm; việc nhờ mở từ lựa chọn trong cảnh (sửa quạt ngày 2, giao 12 suất ngày 6, đón Bắp ngày 9).
  - `tests/sim.gd` chạy thêm 30 ngày cho 3 tuyến × 4 cách chơi; `tests/playtest.gd -- --demo --full` cho người chơi máy đi hết 30 ngày trên màn phố thật.
  - Ba chỗ ở dựng trên phố (Hẻm Dừa cạnh chợ, Cầu Tre bên kia rạch, nhà dì Năm đầu đường An Hòa) để xem phòng và dắt bà đi thử tận nơi; ngày 30 cảnh khép lại diễn ra trước chỗ ở đã chọn, có chậu húng dưới mái hiên.
  - Gợi ý cách chơi hiện một lần khi lần đầu gặp từng tình huống (`tips` trong `story.json`).
- **Nhận xét từ mô phỏng 30 ngày:** lắng nghe ra E1/E2/E3 theo tuyến, giữ tiếp ra E4 hoặc E6, áp đặt ra E8, làm quá sức ra E6 hoặc E4. Tiền cuối tháng sau khi trả Hẻm Dừa từ 0,4 đến 6 triệu. Cách chơi "giấu" (làm việc đàng hoàng nhưng giấu chuyện, ép người nhà) ra E5 ở cả ba tuyến. E7 chỉ ra khi thiếu tiền phòng ngày 26 (đã thử riêng); mô phỏng "ít việc" (mỗi ngày một việc ngắn) vẫn vừa đủ Hẻm Dừa, nên cần người thật chơi thử để biết áp lực tiền có đủ không.
- **Đã tự chơi thử một lượt 30 ngày** (tuyến C, người chơi cẩn thận, ra E3) và sửa theo những chỗ vướng:
  - Nói chuyện với 8 nhân vật có mạch chuyện từ ngày 2 (16 đoạn mới cho ngày 2–17, khớp với cảnh chính). Trước đó tới ngày 17 chỉ có câu tán gẫu lặp lại. Câu tán gẫu của Linh đổi sau khi em đã chọn chỗ thực tập. Tán gẫu chỉ còn +1 thân thiết, vì bà Tư lên 100/100 từ ngày 14.
  - Tới sớm bước "tới nơi" của việc nhờ (đón Bắp, lấy cơm) thì ngồi chờ tới giờ như cảnh chính, không bị khóa.
  - Việc có khung giờ báo "Trễ rồi: phải bắt đầu trước HH:MM" thay vì chỉ ghi khung giờ.
  - Ca kho 8 tiếng có suất cơm ca, buổi làm ở Bến Cạn có quán bao cơm trưa, ăn cơm với bà cũng no bụng: trước đó làm xong một ca dài là đói lả, Phong độ tụt còn 70% lương.
  - Bảng mục tiêu: "Ngày 26 chốt chỗ ở" (việc chốt diễn ra ở cảnh ngày 26), kèm số tiền còn thiếu cho chỗ kế tiếp. Đủ buổi cho nghiệm thu giữa kỳ thì ghi rõ làm thêm được tính cho giai đoạn cuối.
  - Ẩn thẻ khóa "Chưa mở" của việc tùy chọn còn chờ lựa chọn trước; ẩn "Xem phòng" khi đã xem ở cảnh ngày 3; ẩn "Đưa bà xem ảnh" khi chưa xem phòng nào; "Kể khoản lãi dự kiến" chỉ hiện sau khi nhận hợp đồng; có cơm giá quen thì ẩn dĩa cơm giá thường.
  - Câu đố sửa quạt không còn lộ đáp án trong gợi ý. Linh nộp hồ sơ chiều thứ Ba (ngày 9) cho khớp cảnh đón Bắp. Ngày 5 đổi thành "Hai cuộc hẹn trùng giờ".
  - Tiền sinh hoạt cả nhà 120.000đ/ngày (trước là 100.000đ): theo mô phỏng, người chơi chịu khó còn 1–6 triệu sau khi vào Hẻm Dừa, người làm ít còn dưới 0,2 triệu và có khi không trả kịp công người phụ (ra E4).
- **Lớp gắn kết người chơi** (để người chơi muốn sang ngày mới và nhớ những gì mình đã chọn):
  - **Sổ tay của An:** mỗi lựa chọn ở cảnh chính (115 dòng, kể cả biến thể theo tuyến) và các đoạn chuyện quan trọng ghi một dòng vào sổ tay bằng giọng của An (khóa `diary` trong `effects`). Tối nào màn "Đi ngủ?" cũng hiện các dòng của hôm nay, rồi một dòng **Ngày mai** hé lộ cảnh kế tiếp (`teasers` trong `story.json`, có biến thể theo tuyến và việc đã làm). Nút Sổ hiện 6 dòng gần nhất; màn kết có nút đọc lại cả tháng.
  - **Mở đầu viết lại** thành một cảnh: chuyến xe đêm, cái quạt hỏng, tờ giấy trên cửa, và câu hỏi "lần này, anh có lo một mình được không?".
  - **Mạch "Cánh tủ có hai cột vạch"** (bà Tư, Linh): Linh đo lại chiều cao của An (ngày 9–15), bà lau cánh tủ (ngày 13–21), ngày 28 chọn tháo cánh tủ mang theo, để bà quyết, hoặc chụp hình rồi bán (`canh_tu`). Tết sau bà đo tiếp, có thêm cột của bé Bắp.
  - **Mạch "Cuộc gọi cho má"**: má An làm xa, An quen gửi tiền thay cho cuộc gọi, đúng điều An đang lặp lại với bà. Bà đưa điện thoại (ngày 2–8), mở hộp thiếc đựng biên lai chuyển tiền (ngày 22–28, cần thân với bà). Kết có ba cách khép tùy An đã nói thật với má tới đâu.
  - **Chào xóm tuần cuối:** mỗi nhân vật một đoạn chia tay, gợi lại việc cũ và để lại một món đồ: túi giữ nhiệt của chị Hạnh, cái mỏ lết khắc tên (chú Sáu, cần thân), hình "nhà mới của chú An" của Bắp, tờ phiếu trắng có tên Trâm, tờ giấy năm chữ ký ở Bến Cạn, tấm bảng "Phòng 4" của cô Duyên, chìa khóa móc con cá của Linh, đêm cuối ngồi hiên với bà.
  - **Món cầm trên tay ngày 30** (`cam_tren_tay`): chậu húng, túi đồ nghề, hoặc món đã giữ được (cánh tủ, tập hồ sơ của Linh, tấm bảng). Chỉ đổi hình ảnh kết, không cộng điểm.
  - **Màn kết** thêm phần "Sau đó" (các mạch riêng khép lại), "Trong thùng đồ cuối cùng" (`keepsakes`), và một dòng cho từng người ở xóm và ở phố (`npcCards` có thêm `extra` theo việc đã làm), thay vì chỉ một người nổi bật nhất.
  - Việc nhỏ cho những khoảng vui: đánh cầu lông với Linh ngoài sân (không có khi trời mưa).
- **Bản đồ phường An Hòa vẽ lại** (trước đây chỉ là một con phố thẳng): khu ven kênh kiểu Sài Gòn trong `data/map.json`, có đường lớn, đường chợ, đường ven rạch, hai hẻm chính có cổng khu phố, hẻm nhánh, hẻm cụt, rạch có bờ kè, hai cây cầu, xóm nhà sàn bên kia rạch. Xem [04-dia-diem.md](04-dia-diem.md).
  - `city_map.gd` chia lô nhà theo mặt tiền từng đường, đánh số nhà kiểu thật (lẻ, chẵn, gạch chéo trong hẻm), dựng lưới đi bộ 1 m và tìm đường A*. Thời gian đi bộ tính theo quãng đường thật (`walkHoursPerMeter` 0,0022), tiền giao hàng theo mét đi thật.
  - Việc nhờ "tìm" dùng vùng chữ nhật trên bản đồ (`area`) thay vì khúc phố theo trục x.
  - Bản đồ lớn (phím M) có tên đường, tên rạch; bấm chỗ nào đi tới chỗ đó.
- **Phố sống theo giờ** (`data/schedules.json`, `scripts/world/street_life.gd`):
  - Mỗi nhân vật có việc riêng: bà Tư đi chợ 6:30–8:30 (ngày mưa ở nhà), Linh đi học ở trung tâm nghề 7:30–11:30 từ thứ Hai tới thứ Sáu (ra bến xe rồi lên xe), Minh chở cơm xuống Bến Cạn, chú Sáu ra chợ trưa, Trâm ra sạp vật tư, anh Phúc qua tiệm Sáu mượn đồ, cô Duyên mua cơm tối. Ở gần An thì đi bộ thật theo đường, ở xa thì đổi chỗ ngay.
  - Người đang ở đâu thì nói chuyện ở đó; ở chỗ quen hiện thẻ "Bà Tư đi chợ Cầu Nhỏ · Vắng, khoảng 08:30 về" để người chơi biết mà hẹn giờ.
  - Người bán rong đẩy xe vòng qua hẻm 42, 42/7, 88, đường Chợ, Hẻm Dừa và Bờ Me theo khung giờ (bánh mì, xôi, ve chai, chè, hủ tiếu gõ), dừng ở đầu hẻm, góc đường. Tiếng rao phát ra từ chính chiếc xe, chữ nổi hiện khi An ở gần.
- **Chế độ Dựng một khu thật** (ngoài truyện, `scripts/realmap/`, `data/realmap.json`): gõ tên khu ở Việt Nam, trình duyệt tự gọi thẳng Nominatim, Overpass (ba máy, hỏi thêm sau 7 giây) và Open Buildings của VIDA (đọc theo byte qua chỉ mục FlatGeobuf), ghép nhà theo luật OSM ưu tiên, bỏ nhà Open Buildings tin cậy dưới 0,7, trùng nhà OSM, trên lòng đường, trên mặt nước; dựng 3D để An đi dạo. Giao diện làm theo Tiny Map: bản đồ nền tối để tìm và vẽ vùng (khung, đa giác), khung 3D có thẻ tiến độ bốn bước, mô hình thu nhỏ cắt theo vùng trên tấm đế, camera xoay nghiêng, la bàn, cây, xe, nhãn địa danh, tải .glb. Đã thử với dữ liệu thật: Hồ Gươm (0,42 km², 793 nhà, 637 cây) và Khương Thượng (0,50 km², 2.885 nhà, đọc 1,3 MB trong file Open Buildings 17,5 GB), và bản web trong Chromium.
- **Map của truyện từ khu thật** (Quận 8, ven kênh Tàu Hủ): `tools/bake_map.gd` nướng dữ liệu OSM và Open Buildings của một khung thành `data/maps/<id>.json`; `scripts/world/real_city.gd` đặt chín địa điểm lên lô thật theo `data/maps/<id>_story.json`, đổi tên đường thật sang tên trong truyện, đánh số nhà, đặt thùng rác, tính chỗ ngập theo khoảng cách tới kênh. Người chơi máy đi đủ 30 ngày trên map thật: tuyến C ra E3, tuyến A ra E1, đi bộ trung bình 1,5–1,6 giờ mỗi ngày, không ngủ ngoài đường.
- **Còn lại:** chỉnh cân bằng thêm sau khi người thật chơi thử.

## Câu hỏi đã chốt

| # | Câu hỏi | Đề xuất |
|---|---|---|
| 1 | **Có giữ "thua thì chơi lại từ đầu" không?** Ý tưởng ban đầu của game là không đủ tiền thì bắt đầu lại. "Trước mùa mưa" cố ý không có game over: thiếu tiền thì ở tạm (E7). | Theo truyện mới, bỏ game over. Thay bằng các kết thúc nặng nề (E4–E8) để người chơi muốn chơi lại, giữ "Sổ tay" như một gợi ý cho lượt sau. |
| 2 | **Thời gian tính bằng giờ hay bằng ô?** Truyện dùng 4 ô mỗi ngày. Game hiện chạy đồng hồ 6:00–22:00, đi bộ tốn giờ (kiểu Nobody). | Giữ đồng hồ giờ. Quy đổi: ca dài 8 giờ, việc ngắn 3–4 giờ, cảnh truyện 1–2 giờ. "Cuối tối" là sau 20:00, làm việc lúc này tăng mệt. |
| 3 | **Bỏ hệ thống kỹ năng và lớp học?** Game hiện có 5 kỹ năng và các khóa học. Trong truyện, An đã có nghề; người đi học là Linh. | Bỏ lớp học của An. Thay bằng "uy tín nghề" và kiểm tra chuyên môn của Trâm. Kỹ năng có thể quay lại ở mùa sau. |
| 4 | **Sức khỏe và Tinh thần, hay chỉ Mệt?** Truyện chỉ dùng một chỉ số mệt, có ngưỡng cảnh báo. | Gộp thành một chỉ số **Mệt** (0–100, cảnh báo từ 70). |
| 5 | **Chọn món đồ đầu game và chọn suất ăn?** Truyện cố định túi đồ nghề, cái quạt hỏng, và tiền sinh hoạt 120.000đ/ngày. | Bỏ cả hai. Tiền sinh hoạt trừ tự động mỗi tối. |

## Cái gì giữ lại

- Engine Godot 4.7, màn phố 3D, đi bộ bằng chuột, đồng hồ trong ngày, thanh "đang làm" (nhánh `feature/thoi-gian-troi`).
- Kiến trúc tách lớp: logic trong `scripts/game_logic.gd`, nội dung trong `data/*.json`, giao diện riêng.
- Hệ thống sự kiện có lựa chọn (`events.json`: `choices`, `require`, `effects`, `variants`, `bonus`). Đủ để chở 90 lựa chọn của 30 ngày, chỉ cần thêm vài loại hiệu ứng và điều kiện.
- Bảng cân bằng (`scenes/board.tscn`) và bản mô phỏng headless (`tests/sim.gd`).

## Cái gì thay

### Nội dung và tên

| Hiện tại ("Lên Phố") | Thay bằng ("Trước mùa mưa") |
|---|---|
| Nhân vật chính Minh, 20 tuổi, từ Hà Tĩnh | **An**, 27 tuổi, thợ sửa điện máy |
| Lan (em gái), cô Sáu (chủ trọ), chú Bảy (thợ điện lạnh), Vy, Tuấn, ông Tư, Hưng Sẹo, Khoa | Linh, bà Tư, chị Hạnh, chú Sáu, Minh (tài xế), cô Duyên, Trâm, anh Phúc |
| Bình Thạnh, Sài Gòn | Phường An Hòa, thành phố hư cấu Bình Giang |
| 3 mốc tiền: lãi ngày 10, học phí ngày 20, nợ gốc ngày 30 | Một hạn cố định: **chốt chỗ ở trước ngày 26–30**, trả chìa khóa ngày 30 |
| 5 kết thúc (Đường tắt, Công lý, Đất lành, Trắng tay, Game over) | 8 kết thúc E1–E8 (xem [06-ket-thuc.md](06-ket-thuc.md)) |
| Sự kiện ngẫu nhiên: móc túi, tai nạn, điện thoại hỏng | Bỏ các biến cố trừng phạt ngẫu nhiên. Mưa cố định ở ngày 15 và 29, báo trước. |

**Lưu ý trùng tên:** "Minh" là nhân vật chính cũ nhưng là tài xế trong truyện mới, còn "Sáu" là cô chủ trọ cũ nhưng là chú thợ sửa xe trong truyện mới. Khi đổi phải thay hết, không để sót tên cũ trong `events.json`, `story.json`, `world.gd`.

### Dữ liệu (`data/`)

**`config.json`**
- `startMoney`: 2.000.000 → **1.200.000**. Thêm `receivables` với khoản lương cũ 3.600.000đ (ngày 17: 1,8tr, ngày 24: 1,8tr, hoặc khép sớm 2,8tr ở ngày 4).
- Bỏ `milestones`, `legalDebt`, `smuggle`, `food`. Thêm `livingCostPerDay: 120000`.
- Thêm `housing`: Hẻm Dừa 5.000.000đ, Cầu Tre 4.200.000đ, dì Năm 500.000đ cho 7 ngày.
- Thêm `contract`: tổng 8.400.000đ, chi 6.400.000đ, lịch 40% / 30% / 30% (ngày 32).
- Viết lại `actions` theo nghề của An: ca phụ quán Hạnh (160.000đ), giao cơm, sửa đồ ở tiệm Sáu, ca làm thường 300.000–360.000đ, việc ngắn 100.000–180.000đ. Mỗi việc gắn `location` mới (xem [04-dia-diem.md](04-dia-diem.md)).
- `random`: bỏ hết hoặc chỉ giữ những sự kiện không trừng phạt, như hàng xóm rủ ăn chè hay bé Bắp ghé chơi.

**`events.json`**
- Viết lại toàn bộ theo 30 ngày. Mỗi ngày có một sự kiện chính với 3 lựa chọn, lấy từ [data/narrative_design.json](../data/narrative_design.json) (`days[].choices`).
- Thêm sự kiện "nếu bỏ lỡ" cho từng ngày (`days[].missed`), hiện vào sáng hôm sau.
- Những ngày tốn 2 ô (15, 22, 29, 30) đặt `hours: 8`.

**`story.json`**
- Thay mở đầu, bỏ `items`, thay `endings` bằng E1–E8 và thêm các thẻ hậu truyện (Linh, bà Tư, quan hệ nghề).

### Logic (`scripts/game_logic.gd`)

Hệ thống mới cần thêm:

| Hệ thống | Mô tả | Dùng cho |
|---|---|---|
| **Tiền mặt / phải thu** | Hai biến riêng. Khoản phải thu có người trả, số tiền, ngày đến hạn, trạng thái. Chỉ thành tiền mặt khi đã xác nhận nhận. | Lương cũ, hợp đồng, ngày 12, 17, 20, 24 |
| **Sổ lời hứa** | Mỗi lời hứa có nội dung, người nhận, hạn, chi phí dự kiến, trạng thái (chưa nhận, đã nhận, hoàn thành, báo trễ, thỏa thuận lại, vi phạm). Báo đổi hẹn khác với im lặng. | Ngày 1, 2, 5, 9, 13, 18, 20 và kết E4, E8 |
| **Nhà ở** | Trạng thái: chưa chọn, đã giữ chỗ, đã ký và đủ điều kiện vào, ở tạm có thời hạn. Đặt cọc khác với thật sự chuyển vào được. | Ngày 3, 21, 26 và kết E7 |
| **Tuyến nghề** | A, B, C chọn ở ngày 11, cho đổi sau khi xử lý cam kết cũ. Mỗi ngày hợp đồng có biến thể riêng cho tuyến A. | Ngày 11–27 và kết E1, E2, E3 |
| **Mệt** | Một chỉ số, kèm đếm số ngày ở mức cảnh báo và số lần bỏ qua cơ hội nghỉ. | Ngày 16 và kết E6 |
| **Sổ gia đình** | Ghi từng sự việc ảnh hưởng tới Linh hoặc bà: ai bị ảnh hưởng, đã nói chưa, đã sửa chưa. Đếm số lần che giấu hoặc ép quyết định. | Ngày 1, 9, 19, 22, 25 và kết E5, hậu truyện |
| **Chuyên môn** | Hạng mục đã được Trâm kiểm tra, lỗi còn mở, có báo sai tình trạng hay không. | Ngày 15, 27 và kết E8 |
| **Mưa** | Ngày 15 và 29 cố định. Thiệt hại tùy việc chuẩn bị ở ngày 14 và 28, không tung xúc xắc. | Ngày 14, 15, 28, 29 |

Hiệu ứng mới cần thêm vào `apply_effects` (ví dụ tên khóa):

```
"cash": -300000                         tiền mặt
"receivable": {"id": "luong_cu", ...}   tạo hoặc cập nhật khoản phải thu
"collect": "luong_cu_dot_1"             nhận một khoản phải thu thành tiền mặt
"promise": {"id": "noi_that_ngay_5", "to": "LINH", "due": 5}
"promise_status": {"id": "...", "status": "done"}
"housing": "hem_dua_reserved"
"route": "B"
"fatigue": 15
"family_mark": {"who": "LINH", "kind": "pressure"}
"false_completion": true
```

Viết lại `_resolve_ending()` theo thứ tự **E8 → E6 → E7 → E5 → E4 → E2 → E3 → E1**, rồi chọn thẻ hậu truyện.

Bỏ: `milestones`, `debt`, `interest_paid`, `smuggle`, `evidence`, `phapLy`, `held` (lương phụ hồ bị quỵt), `sleep_outside` (giữ được nếu muốn, nhưng truyện không có).

### Màn phố 3D (`scripts/world/world.gd`)

- Đổi bảng `LOCATIONS` sang 7 nơi mới (xem bảng ánh xạ ở [04-dia-diem.md](04-dia-diem.md)).
- Thêm con rạch và cây cầu nhỏ cạnh chợ Cầu Nhỏ, năm mặt tiền nhỏ của dãy Bến Cạn, khoảng sân có dây phơi ở xóm Bờ Me.
- Đổi NPC đứng trước cửa: cô Duyên (Bờ Me), chị Hạnh (Cơm Hạnh), chú Sáu (tiệm Sáu), anh Phúc (Bến Cạn), Trâm (đi cùng An khi có hợp đồng), Minh (Cơm Hạnh, giờ giao cơm).
- Ngày 15 và 29: trời tối, mưa, sân và đường ven rạch đọng nước.

### HUD (`scripts/world/hud.gd`)

- Bảng **Mục tiêu quan trọng** đổi thành:
  - Ngày 26 chốt chỗ ở (tiền dự kiến, chỗ đủ tiền, còn thiếu bao nhiêu cho chỗ kế tiếp)
  - Trả chìa khóa ngày 30
  - Lương cũ: đã nhận X / 3.600.000đ
  - Hợp đồng Bến Cạn (nếu đang làm): tiền về trước ngày 30 / sau ngày 30
- Góc phải hiện **hai cột tiền**: tiền mặt và tiền phải thu, không cộng chung.
- Thêm bảng **Sổ lời hứa** (mở bằng nút ở thanh dưới): các lời hứa đến hạn hôm nay hiện lên đầu.
- Trước mỗi lựa chọn hiện: thời gian, khoản chi chắc chắn, người chịu ảnh hưởng (luật ở [02](02-the-gioi-va-luat-choi.md)).

### Mô phỏng (`tests/sim.gd`)

Thay hai chiến lược cũ bằng ba chiến lược theo tuyến A, B, C. Đo:
- Tiền mặt ngày 26 có đủ cho Hẻm Dừa (5tr), Cầu Tre (4,2tr) hay chỉ đủ ở tạm.
- Phân bố kết thúc.
- Số ca làm thực tế trong 120 ô (30 ngày × 4) sau khi trừ cảnh bắt buộc và nghỉ.

## Thứ tự làm đề xuất

1. **Chốt 5 câu hỏi** ở đầu tài liệu.
2. **Lát cắt ngày 18–22** (gợi ý của hồ sơ gốc): dựng ba tuyến nghề, dòng tiền hai cột và quyền tự quyết của Linh, chơi thử trên Bảng cân bằng trước.
3. **Logic nền:** tiền mặt / phải thu, sổ lời hứa, nhà ở, mệt, tuyến nghề, 8 kết thúc. Viết lại `tests/sim.gd`.
4. **Nội dung:** chuyển 30 ngày và 90 lựa chọn vào `events.json`, kèm sự kiện "nếu bỏ lỡ".
5. **Màn phố:** đổi địa điểm, NPC, thêm rạch, cầu và mưa ngày 15, 29.
6. **HUD:** mục tiêu mới, hai cột tiền, sổ lời hứa.
7. **Chơi thử bốn kiểu lượt** như hồ sơ gốc đề nghị: một lượt bình thường, một lượt thiếu tiền, một lượt bỏ nhiệm vụ, một lượt đổi tuyến.

Tài liệu thiết kế cũ của "Lên Phố" (trên Claude Docs) và `README.md` của project cần cập nhật sau khi chốt câu hỏi 1–5.
