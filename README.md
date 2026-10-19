# Lên Phố: 30 Ngày

Game mô phỏng đời sống lấy cảm hứng từ *Nobody: The Turnaround*, bối cảnh một con phố ở Bình Thạnh, Sài Gòn. Minh từ Hà Tĩnh lên thành phố, có 30 ngày để trả nợ nặng lãi cho gia đình và lo học phí cho em gái.

Làm bằng **Godot 4.7**. Phố dựng bằng nhà ống kiểu Sài Gòn tạo tự động (`scripts/world/tube_house.gd`): ban công lan can sắt, mái hiên tôn, biển hiệu, đồ phơi, bồn nước inox. Người và xe lấy mô hình thật trong `assets/` nếu có, chưa có thì dùng khối hình tạm (xem mục *Thêm mô hình thật*).

## Mở project

1. Mở Godot, chọn **Import**, trỏ tới file `project.godot` trong thư mục này.
2. Bấm **Run** (F5). Màn chính là phố 3D (`scenes/world.tscn`).

**Điều khiển:**

| Thao tác | Tác dụng |
|---|---|
| Chuột trái | Đi tới chỗ bấm |
| Bấm vào cửa tiệm hoặc người | Đi tới và mở việc làm, lớp học ở đó |
| WASD hoặc phím mũi tên | Đi lại |
| E | Vào địa điểm đang đứng gần |
| Esc | Đóng bảng |

**Thời gian:** đi bộ trên phố tốn giờ (chỉnh bằng `walkHoursPerMeter`). Làm việc hay đi học thì Minh vào trong tiệm, thanh thời gian chạy (`workSecondsPerHour` giây thật cho mỗi giờ trong game) rồi mới tính kết quả. Nút **Về phòng trọ** dẫn Minh về nhà, vào phòng trọ để **Đi ngủ**. Tới 22 giờ mà chưa về thì Minh ngủ gục ngoài đường, bị trừ Sức khỏe và Tinh thần (`sleepOutside`).

**Nhu cầu cơ thể và Phong độ (kiểu Nobody):** No bụng, Vệ sinh, Quần áo tự giảm theo giờ; việc bẩn (phụ hồ, rửa bát, lục rác) làm bẩn người và đồ. Cùng Tinh thần, chúng gộp thành **Phong độ**: từ 55 trở lên đủ lương, 30–55 chỉ được 70%, dưới 30 chỉ 50% và đi chậm. Nhịn đói tới 0 thì mất Sức khỏe. Ăn ở quán cơm tấm, cửa hàng 24 giờ, xe bánh mì; tắm và giặt đồ ở phòng trọ. Số liệu trong `needs` của `data/config.json`.

**Ve chai:** thùng rác xanh dọc vỉa hè, đứng gần bấm **E** để lục (mỗi thùng một lần mỗi ngày): được chai nhựa, lon, bìa giấy nhưng bẩn người. Mang ra **Vựa ve chai cô Tám** cuối phố để bán.

**Giao đồ ăn (kiểu Nobody):** bấm **Điện thoại** ở thanh dưới, bật *App Giao Nhanh*. Đơn hiện lên (lấy món ở quán nào, giao tới nhà số mấy, tiền công, hạn giờ), nhận thì tự đi tới quán lấy món rồi tìm đúng nhà để giao: mũi tên cam chỉ quán, xanh chỉ nhà khách, chấm trên bản đồ phố. Giao sớm có tip, trễ bị trừ tiền và mất Tinh thần. Giờ cao điểm 10:00–13:30 và 17:00–21:00 đơn nhiều, ngoài giờ ít. Số liệu trong `delivery` của `data/config.json`.

**Nói chuyện:** vào tiệm có người đứng trước cửa (Cô Sáu, Chú Bảy, Vy, Tuấn, Ông Tư) sẽ thấy nút **Nói chuyện**, tốn 30 phút, mỗi người một lần mỗi ngày. Mỗi người có vài đoạn mạch chuyện mở dần theo độ thân thiết và ngày; kể hết thì tán gẫu, được thêm chút thân thiết. Hội thoại viết trong `data/talks.json`.

**Quận 1:** từ ngày 23, khi Ngoại ngữ đủ 3, trạm xe buýt có việc *Dẫn khách Úc đi chợ Bến Thành*. Nhận việc thì sang màn Quận 1 (`scenes/quan1.tscn`): dẫn ba vị khách qua cổng chợ, sạp lưu niệm, xe bánh xèo, mỗi chỗ một lựa chọn. Xong chuyến thì đón xe buýt về, tiền công và giờ tính lúc đó. Nội dung chuyến đi viết trong `data/tour_ben_thanh.json`.

Ván chơi tự lưu sau mỗi thao tác vào `user://save.json`. Nút **Chơi lại** trong Bảng cân bằng xóa ván đang chơi.

## Cấu trúc thư mục

```
data/
  config.json     số liệu cân bằng: tiền, lương, học phí, xác suất, việc làm và địa điểm của từng việc
  events.json     sự kiện cố định theo ngày, sự kiện ngẫu nhiên, mốc tiền
  story.json      mở đầu, món mang theo, 5 kết thúc, Sổ tay của Minh
  talks.json      hội thoại với nhân vật: mạch chuyện và chuyện phiếm
  models.json     file mô hình cho nhà, người, xe, cây và cách co giãn
  tour_ben_thanh.json  điểm dừng và lựa chọn của chuyến dẫn khách ở Quận 1
  sounds.json     âm nền, tiếng rao, còi xe, tiếng hiệu ứng
assets/           mô hình .glb (chưa có thì dùng khối hình), sounds/ âm thanh
tools/
  gen_sounds.py   tổng hợp âm thanh tạm
scripts/
  game_logic.gd   toàn bộ luật chơi, không phụ thuộc giao diện
  game_state.gd   autoload GameState: giữ ván chơi, tự lưu
  world/world.gd  phố 3D: dựng cảnh, nhân vật, xe máy, người đi đường, ánh sáng theo giờ
  world/models.gd nạp mô hình .glb, co giãn cho vừa chỗ, phát hoạt cảnh đứng, đi, ngồi
  world/audio.gd  âm thanh theo giờ, mưa, tiếng rao có chữ nổi
  world/character.gd   nhân vật có khớp dựng bằng khối: Minh, nhân vật phụ, người đi đường; hoạt cảnh đi, đứng, ngồi xe
  world/tube_house.gd  dựng nhà ống: mỗi căn một lưới, ngẫu nhiên màu sơn, ban công, biển hiệu
  world/street_map.gd  bản đồ phố thu nhỏ, bấm để đi tới
  world/landmarks.gd   địa danh dựng bằng khối (Chợ Bến Thành) có đèn neon
  world/quan1.gd       màn Quận 1: dẫn khách Úc đi chợ Bến Thành
  world/hud.gd    HUD kiểu Nobody: mục tiêu, trạng thái, bảng địa điểm, thanh công cụ
  ui/ui_kit.gd    màu sắc, theme, thẻ hành động dùng chung
  ui/dialog_layer.gd  hộp thoại mở đầu, sự kiện, buổi tối, kết thúc
  board.gd        Bảng cân bằng: chơi bằng nút bấm, thấy hết chỉ số
scenes/
  world.tscn      màn chính
  board.tscn      Bảng cân bằng
  quan1.tscn      màn Quận 1
tests/
  sim.gd          tự chơi 200 ván để kiểm tra cân bằng
  playtest.gd     người chơi máy chơi trên màn phố thật, in nhật ký từng ngày
```

## Texture và ánh sáng tả thực

Mặt đường, vỉa hè, tường nhà ống và nắp cống dùng texture Poly Haven (CC0) trong `assets/textures/` (nguồn từng bộ ghi ở `NGUON.txt`), chiếu theo tọa độ thế giới nên dán lên mọi khối không cần UV (`scripts/world/surfaces.gd`). Ảnh HDRI `assets/hdri/pho_chieu.hdr` dùng cho phản chiếu. Nắng chiếu xiên từ phía sau dãy nhà để bóng đổ dài ra vỉa hè, tông màu vàng ấm như Nobody. Thay texture: chép bộ `<tên>_albedo.jpg`, `_normal.jpg`, `_rough.jpg` cùng tên.

Đồ vật trên phố (thùng rác kim loại, túi rác, thùng nhựa, thùng các-tông, chậu cây, ghế đẩu, tủ điện, bao xi măng, giỏ mây, cột đèn) là mô hình Poly Haven (CC0) trong `assets/models/`, khai báo ở mục `props` của `data/models.json`. Mái hiên và mái tôn dán texture tôn gợn sóng.

## Thêm mô hình thật

Game đọc `data/models.json` để biết mỗi thứ trên phố dùng file mô hình nào. Thiếu file nào thì chỗ đó vẫn là khối hình, nên có thể thêm dần từng cái.

1. Tải các bộ miễn phí (giấy phép CC0, dùng thương mại được):
   - Người: [Kenney Mini Characters](https://kenney.nl/assets/mini-characters), có sẵn hoạt cảnh đứng, đi, ngồi.
   - Nhà: [Kenney City Kit Commercial](https://kenney.nl/assets/city-kit-commercial) và [City Kit Suburban](https://kenney.nl/assets/city-kit-suburban).
   - Xe máy, cây: [Quaternius](https://quaternius.com) (các bộ Vehicles, Nature).
2. Chép file `.glb` vào `assets/characters/`, `assets/buildings/`, `assets/vehicles/`, `assets/props/` đúng tên trong `data/models.json`, hoặc sửa `path` cho khớp tên file của bạn.
3. Mở Godot cho nó nhập file, rồi chạy game.

Không cần chỉnh kích thước bằng tay: `fit` co giãn mô hình cho vừa khung có sẵn. `height` khớp chiều cao người, `length` khớp chiều dài xe, `width` khớp bề ngang mặt tiền. Mô hình bị quay ngược thì sửa `rot` (độ). Tên hoạt cảnh khác bộ Kenney (ví dụ file từ Mixamo) thì khai báo trong `anims`, ví dụ `{"walk": "mixamo.com"}`.

## Âm thanh

`data/sounds.json` khai báo âm nền theo giờ (phố ban ngày, đêm trong hẻm, mưa khi có sự kiện mưa), tiếng rao (bánh mì, xôi, ve chai, chè, hủ tiếu gõ), còi xe, bước chân và tiếng tiền. Thiếu file nào thì chỗ đó im, riêng tiếng rao vẫn hiện chữ nổi trên phố.

Các file `.wav` trong `assets/sounds/` là **tiếng tạm** do `tools/gen_sounds.py` tổng hợp (`python tools/gen_sounds.py`, cần numpy). Thay bằng file thu thật cùng tên khi có:

- Tiếng rao: thu giọng người thật rồi lưu thành `assets/sounds/rao_banh_mi.ogg`, `rao_xoi.ogg`, `rao_ve_chai.ogg`, `rao_che.ogg`, `rao_hu_tieu.ogg` (hiện chưa có file nào, nên chỉ hiện chữ).
- Tiếng phố, mưa trên mái tôn, còi xe: tìm trên [freesound.org](https://freesound.org) với giấy phép CC0.

## Chỉnh cân bằng

- Sửa số trong `data/config.json` rồi chạy lại game. Mỗi việc làm có trường `location` cho biết nó nằm ở tiệm nào ngoài phố.
- Bảng cân bằng (nút **Bảng cân bằng** ở dưới màn phố) cho chơi nhanh bằng nút bấm.
- Chạy mô phỏng 100 ván cho mỗi chiến lược (chỉ làm chân tay, và học nghề):

```bash
"C:/Users/Admin/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s res://tests/sim.gd
```

Kết quả gần nhất: chỉ làm chân tay thì thua cả 100 ván, học nghề điện lạnh thì 86/100 ván đạt kết đẹp.

- Chơi thử trên màn phố thật (đi bộ, thanh làm việc, nói chuyện, về phòng ngủ đều chạy như người chơi bấm), in nhật ký từng ngày. Thêm `--talk` để người chơi máy nói chuyện với nhân vật:

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/playtest.gd -- --demo --talk --seed=1
```

- Chạy `-- --demo` để vào thẳng ngày 1 mà không ghi đè bản lưu; thêm `--demo-open=quan_com` để mở sẵn một địa điểm.

## Khi xuất bản game

Godot không tự đóng gói file `.json`. Trong **Project → Export**, thêm `*.json` vào ô *Filters to export non-resource files*.
