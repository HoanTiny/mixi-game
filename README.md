# Trước mùa mưa

Game mô phỏng đời sống lấy cảm hứng từ *Nobody: The Turnaround*, bối cảnh phường An Hòa của thành phố hư cấu Bình Giang. An, 27 tuổi, vừa mất việc ở tiệm điện máy. Cả nhà có 30 ngày để dọn khỏi xóm trọ Bờ Me và tìm chỗ ở mới. Thiết kế đầy đủ nằm trong [docs/](docs/README.md).

Làm bằng **Godot 4.7**. Phố dựng bằng nhà ống kiểu Sài Gòn tạo tự động (`scripts/world/tube_house.gd`): ban công lan can sắt, mái hiên tôn, biển hiệu, đồ phơi, bồn nước inox. Người và xe lấy mô hình thật trong `assets/` nếu có, chưa có thì dùng khối hình tạm (xem mục *Thêm mô hình thật*).

**Trạng thái:** đã chơi được **lát cắt ngày 18–22**. Lát cắt có ba tuyến nghề, tiền mặt tách khỏi tiền phải thu và phải trả, chỉ số Mệt, sổ lời hứa, sổ gia đình, và quyền tự quyết của Linh. Ngày 1–17, ngày 23–30 và 8 kết thúc chính chưa làm.

## Mở project

1. Mở Godot, chọn **Import**, trỏ tới file `project.godot` trong thư mục này.
2. Bấm **Run** (F5). Màn chính là phố 3D (`scenes/world.tscn`). Màn đầu cho chọn tuyến nghề A, B hoặc C mà An đã chọn từ ngày 11.

**Điều khiển ở màn phố:**

| Thao tác | Tác dụng |
|---|---|
| Chuột trái | Đi tới chỗ bấm. Đi bộ tốn giờ trong game. |
| Bấm vào cửa tiệm hoặc người | Đi tới và mở việc ở đó |
| WASD hoặc phím mũi tên | Đi lại |
| E | Vào địa điểm đang đứng gần |
| Esc | Đóng bảng |
| Nút **Về xóm trọ** | Đi về Bờ Me. Chỉ ngủ được ở đó; 22 giờ chưa về thì ngủ gục ngoài đường, Mệt +15. |

**Thời gian:** đi bộ trên phố tốn giờ (chỉnh bằng `walkHoursPerMeter`). Làm việc thì An vào trong, thanh thời gian chạy (`workSecondsPerHour` giây thật cho mỗi giờ trong game) rồi mới tính kết quả. Làm việc kéo qua 20 giờ thì Mệt tăng thêm. Vào **Xóm trọ Bờ Me** để **Đi ngủ**.

**Tiền và Mệt:** góc phải hiện tiền mặt tiêu được, tách riêng khỏi tiền phải thu (trước và sau ngày 30) và khoản phải trả. Mỗi tối trừ tiền sinh hoạt của cả nhà (`livingCostPerDay`, chưa gồm cơm của An). Mệt từ 70 trở lên là mức cảnh báo; nghỉ ở phòng, ăn cơm với bà, ngồi trà đá giúp giảm Mệt. Nút **Sổ** mở các khoản phải thu, phải trả, sổ lời hứa, sổ gia đình, độ thân thiết và đồ đang mang.

**Nhu cầu cơ thể và Phong độ (kiểu Nobody):** No bụng, Vệ sinh, Quần áo tự giảm theo giờ; việc bẩn (ca kho, rửa bát, lục rác) làm bẩn người và đồ. Cùng độ tỉnh táo (100 − Mệt), chúng gộp thành **Phong độ**: từ 55 trở lên đủ lương, 30–55 chỉ được 70%, dưới 30 chỉ 50% và đi chậm. Nhịn đói tới 0 thì Mệt tăng nhanh. Ăn ở Cơm Hạnh, bánh mì ở chợ Cầu Nhỏ buổi sáng; tắm và giặt đồ ở xóm trọ. Số liệu trong `needs` của `data/config.json`.

**Trò chơi nhỏ khi đi làm (kiểu Nobody):** ca kho ở khu công nghiệp (đi từ bến xe số 6) là xếp đúng loại hàng (thùng mì, lốc nước, bao gạo) lên pallet trong 60 giây; bỏ nhầm loại phải dỡ ra. Ca phụ quán Cơm Hạnh là rửa bát: bấm từng vết bẩn để kỳ cọ (vết to chà hai lần), sạch thì xếp lên giá (phím cách), xếp bát còn bẩn bị trả lại. Đủ chỉ tiêu thì đủ công, thiếu thì tính theo tỉ lệ (thấp nhất 50%), làm khéo được thưởng. Từ lần thứ hai có thể **làm tự động**, lặp lại kết quả lần tự làm gần nhất. Thông số và chữ trên màn trong `minigames` của `data/config.json`.

**Ve chai:** thùng rác dọc vỉa hè, đứng gần bấm **E** để lục (mỗi thùng một lần mỗi ngày): được chai nhựa, lon, bìa giấy nhưng bẩn người. Mang ra sạp của cô Út ở **chợ Cầu Nhỏ** để bán.

**Giao đồ (kiểu Nobody):** bấm **Điện thoại** ở thanh dưới, bật *App Giao Nhanh*. Đơn hiện lên (lấy ở Cơm Hạnh, chợ hay tiệm Sáu, giao tới nhà số mấy, tiền công, hạn giờ), nhận thì tự đi lấy rồi tìm đúng nhà để giao: mũi tên cam chỉ chỗ lấy, xanh chỉ nhà khách. Giao sớm có tip, trễ bị trừ tiền và thêm Mệt. Số liệu trong `delivery` của `data/config.json`.

**Nói chuyện:** người đứng trước cửa (bà Tư, Linh, cô Duyên ở xóm trọ; chị Hạnh, Minh ở Cơm Hạnh; chú Sáu; anh Phúc, Trâm ở Bến Cạn) có nút **Nói chuyện**, tốn 30 phút, mỗi người một lần mỗi ngày. Mạch chuyện mở dần theo ngày và độ thân thiết, có lựa chọn ghi vào sổ gia đình. Viết trong `data/talks.json`.

**Việc nhờ (kiểu Nobody):** người trong phố nhờ những việc nhiều bước, có hạn giờ và có lựa chọn. Chỗ có người nhờ hiện dấu **!** vàng; nhận việc thì bảng mục tiêu hiện bước đang làm, dấu **◆** xanh chỉ chỗ cần tới. Lát cắt có 7 việc: sửa quạt của cô bán trái cây (đọc triệu chứng, chọn đúng bệnh, trả trước 18:00), rửa bát đủ chỉ tiêu rồi chở 20 suất cơm xuống Bến Cạn trước khi nguội, gom lon nhôm cho cô Út, tìm mèo của bé Bắp, chậu mới cho cây húng của bà Tư (để bà tự chọn hay chọn thay), in hồ sơ thực tập cho Linh (in đúng bản em gửi hay tự ý sửa), đo lại trước nghiệm thu với Trâm (tuyến B, C). Quá hạn là hỏng việc; làm xong được tiền, thân thiết hoặc ưu đãi (cơm giá quen, ve chai được giá). Viết trong `data/quests.json`.

Ván chơi tự lưu sau mỗi thao tác vào `user://save.json`. Nút **Chơi lại** trong Bảng cân bằng xóa ván đang chơi.

## Cấu trúc thư mục

```
data/
  config.json     số liệu: tiền sinh hoạt, Mệt, nhu cầu cơ thể, chỗ ở, điểm xuất phát của 3 tuyến, việc làm, trò chơi nhỏ, giao đồ, ve chai
  events.json     sự kiện ngày 18–22, biến thể theo tuyến, sự kiện hệ thống (nghiệm thu, nợ chưa trả, ngủ gục)
  story.json      lời mở lát cắt, tên nhân vật, thẻ hậu truyện của Linh và bà Tư
  talks.json      hội thoại với nhân vật: mạch chuyện và chuyện phiếm
  quests.json     việc nhờ nhiều bước: người nhờ, hạn, các bước, lựa chọn, phần thưởng
  models.json     file mô hình cho nhà, người, xe, cây, đồ vật và cách co giãn
  sounds.json     âm nền, tiếng rao, còi xe, tiếng hiệu ứng
docs/             tài liệu thiết kế "Trước mùa mưa" (Godot bỏ qua thư mục này)
assets/           texture, HDRI, mô hình đồ vật Poly Haven, âm thanh
prototype/        bản thử HTML đầu tiên (cốt truyện cũ)
tools/
  gen_sounds.py   tổng hợp âm thanh tạm
scripts/
  game_logic.gd   toàn bộ luật chơi, không phụ thuộc giao diện
  game_state.gd   autoload GameState: giữ ván chơi, tự lưu
  world/world.gd  phố 3D: địa điểm, nhân vật, rạch và cầu, thùng rác, xe máy, người đi đường, ánh sáng theo giờ
  world/models.gd nạp mô hình, co giãn cho vừa chỗ, phát hoạt cảnh
  world/surfaces.gd    vật liệu texture chiếu theo tọa độ thế giới
  world/audio.gd  âm thanh theo giờ, mưa, tiếng rao có chữ nổi
  world/character.gd   nhân vật có khớp dựng bằng khối: An, 8 nhân vật, người đi đường; hoạt cảnh đi, đứng, ngồi xe
  world/tube_house.gd  dựng nhà ống: mỗi căn một lưới, ngẫu nhiên màu sơn, ban công, biển hiệu
  world/street_map.gd  bản đồ phố thu nhỏ, bấm để đi tới
  world/hud.gd    HUD kiểu Nobody: mục tiêu, tiền và Mệt, bảng địa điểm, điện thoại, Sổ, Nhật ký, việc nhờ
  ui/ui_kit.gd    màu sắc, theme, thẻ hành động, hai cột tiền, Sổ dạng chữ
  ui/dialog_layer.gd  hộp thoại chọn tuyến, sự kiện, đi ngủ, tổng kết lát cắt
  ui/minigame_bricks.gd  trò chơi nhỏ bưng xếp hàng (ca kho)
  ui/minigame_dishes.gd  trò chơi nhỏ rửa bát (Cơm Hạnh)
  board.gd        Bảng cân bằng: chơi bằng nút bấm, thấy hết dòng tiền và các sổ
scenes/
  world.tscn      màn chính
  board.tscn      Bảng cân bằng
tests/
  sim.gd          tự chơi lát cắt cho 3 tuyến × 3 cách chơi
  playtest.gd     người chơi máy chơi lát cắt trên màn phố thật, in nhật ký từng ngày
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

- Sửa số trong `data/config.json` rồi chạy lại game. Điểm xuất phát của từng tuyến nằm ở `presets`.
- Bảng cân bằng (nút **Bảng cân bằng** ở dưới màn phố) cho chơi nhanh bằng nút bấm.
- Chạy mô phỏng:

```bash
"C:/Users/Admin/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s res://tests/sim.gd
```

Kết quả gần nhất (tiền dự kiến sáng ngày 26, hạn chốt chỗ ở; máy chơi có ăn, tắm, giặt):

| Tuyến | Lắng nghe | Giữ tiếp | Áp đặt |
|---|---|---|---|
| A · Làm công | 6,16 tr · đủ Hẻm Dừa | 6,14 tr · đủ Hẻm Dừa | 6,34 tr · đủ Hẻm Dừa |
| B · Tổ đội | 6,17 tr · đủ Hẻm Dừa | 5,64 tr · đủ Hẻm Dừa | 5,72 tr · đủ Hẻm Dừa |
| C · Dịch vụ riêng | 4,81 tr · đủ Cầu Tre | 4,43 tr · đủ Cầu Tre | 4,33 tr · đủ Cầu Tre |

Cách chơi "áp đặt" luôn dẫn tới thẻ "Tin nhắn chỉ đủ việc" của Linh. Hai cách còn lại cho thẻ "Đi xa, vẫn có đường về".

- Chơi thử trên màn phố thật (đi bộ, thanh làm việc, ăn uống, nói chuyện, về xóm trọ ngủ đều chạy như người chơi bấm), in nhật ký từng ngày:

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/playtest.gd -- --demo --route=B --talk
```

**Chạy thử nhanh** (thêm vào sau lệnh chạy game, không ghi đè bản lưu thật):

- `-- --demo --demo-route=C`: vào thẳng ngày 18 của tuyến C.
- Thêm `--demo-open=ben_can`: mở sẵn một địa điểm.
- Thêm `--demo-end`: tự chơi tới hết ngày 22 để xem bảng tổng kết.

## Khi xuất bản game

Godot không tự đóng gói file `.json`. Trong **Project → Export**, thêm `*.json` vào ô *Filters to export non-resource files*.
