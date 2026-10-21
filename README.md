# Trước mùa mưa

Game mô phỏng đời sống lấy cảm hứng từ *Nobody: The Turnaround*, bối cảnh phường An Hòa của thành phố hư cấu Bình Giang. An, 27 tuổi, vừa mất việc ở tiệm điện máy. Cả nhà có 30 ngày để dọn khỏi xóm trọ Bờ Me và tìm chỗ ở mới. Thiết kế đầy đủ nằm trong [docs/](docs/README.md).

Làm bằng **Godot 4.7**. Phố dựng bằng nhà ống kiểu Sài Gòn tạo tự động (`scripts/world/tube_house.gd`): ban công lan can sắt, mái hiên tôn, biển hiệu, đồ phơi, bồn nước inox. Người và xe lấy mô hình thật trong `assets/` nếu có, chưa có thì dùng khối hình tạm (xem mục *Thêm mô hình thật*).

**Trạng thái:** chơi được **đủ 30 ngày** và **8 kết thúc**: ba tuyến nghề chọn ở ngày 11, tiền mặt tách khỏi tiền phải thu và phải trả, hợp đồng Bến Cạn, chỗ ở (xem, cọc, chốt ngày 26), mưa ngày 15 và 29, chỉ số Mệt, sổ lời hứa, sổ gia đình, quyền tự quyết của Linh. Lát cắt ngày 18–22 vẫn giữ ở màn đầu để thử nhanh một tuyến.

**Chỗ ở trên phố:** Phòng Hẻm Dừa trong hẻm cụt rẽ ra từ đường Chợ, Phòng Cầu Tre bên kia rạch (qua cây cầu tre sau Bến Cạn), nhà dì Năm ở đầu đường An Hòa gần trạm xe. Tới tận nơi để xem phòng hay dắt bà đi thử bậc cửa (đi càng xa càng tốn giờ). Ngày 30, cảnh khép lại diễn ra trước chỗ ở đã chọn: bà Tư, chậu húng dưới mái hiên, Linh có mặt nếu em không đi thực tập xa.

**Bản đồ phường An Hòa** (`data/map.json`, dựng bởi `scripts/world/city_map.gd`): không còn là một con phố thẳng mà là một khu ven kênh kiểu Sài Gòn, bố cục dựa theo các xóm hẻm và rạch thật ở TP.HCM:
- **Đường An Hòa** (đường lớn, hai chiều, có trạm xe số 6 và cổng khu công nghiệp ở đầu đường), **đường Chợ Cầu Nhỏ** chạy xuống tới chân cầu (kiểu chợ đầu cầu), **đường Bờ Me** ven rạch có lan can, hàng cây và đèn.
- **Hẻm 42** (cổng "Khu phố 3"), **Hẻm 88** (cổng "Khu phố 4", hẻm ba gác hẹp hơn), hẻm nhánh **42/7** nối ngang hai hẻm, **Hẻm Dừa** là hẻm cụt rẽ từ đường Chợ, đầu hẻm có cây dừa. Dây điện chằng chịt trên hẻm.
- **Rạch Bờ Me** uốn nhẹ, có bờ kè, ghe xuồng; **Cầu Nhỏ** (cầu bê tông) và **Cầu Tre** (cầu ván) bắc sang **Hẻm Bờ Nam**, nhà sàn chân cột quay lưng ra rạch, phía sau là ruộng rau muống.
- Số nhà đánh như thật: số lẻ một bên, chẵn một bên; nhà trong hẻm mang số có gạch chéo theo căn ở đầu hẻm (42/3, 42/7/5…), app Giao Nhanh giao tới đúng các địa chỉ này.
- An đi theo đường thật (tìm đường A* trên lưới 1 m, không xuyên nhà), nhà che khuất An thì tự ẩn. Bản đồ nhỏ góc trên; phím **M** hoặc bấm bản đồ nhỏ mở **bản đồ lớn** có tên đường, bấm chỗ nào thì An đi tới đó.

**Gợi ý cách chơi:** lần đầu gặp chuyện gì (có cảnh chính, đói, bẩn, Mệt lên, có người nhờ việc, đứng cạnh thùng rác, sau 20 giờ…) thì ô Gợi ý ở góc trái hiện một lần. Nội dung ở mục `tips` của `data/story.json`.

**Cảnh chính mỗi ngày:** bảng mục tiêu ghi "Hôm nay: …" kèm nơi và khung giờ, trên phố có dấu ◆ vàng. Tới nơi bấm thẻ ◆ để vào cảnh, chọn một trong ba cách. Bỏ lỡ thì sáng hôm sau có tin kể lại, việc không tự xong. Tin nhắn, mưa và ngày 30 tự bật buổi sáng.

## Mở project

1. Mở Godot, chọn **Import**, trỏ tới file `project.godot` trong thư mục này.
2. Bấm **Run** (F5). Màn chính là phố 3D (`scenes/world.tscn`). Màn đầu có **Bắt đầu ngày 1** (đủ 30 ngày) hoặc thử nhanh lát cắt ngày 18–22 với tuyến A, B, C.

**Điều khiển ở màn phố:**

| Thao tác | Tác dụng |
|---|---|
| Chuột trái | Đi tới chỗ bấm. Đi bộ tốn giờ trong game. |
| Bấm vào cửa tiệm hoặc người | Đi tới và mở việc ở đó |
| WASD hoặc phím mũi tên | Đi lại |
| E | Vào địa điểm đang đứng gần |
| M | Mở/đóng bản đồ lớn; bấm một chỗ trên bản đồ để đi tới |
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
  map.json        bản đồ phường An Hòa: đường, hẻm, rạch, cầu, cổng hẻm, chỗ đặt từng địa điểm
  config.json     số liệu: tiền sinh hoạt, Mệt, nhu cầu cơ thể, chỗ ở, điểm xuất phát của 3 tuyến, việc làm, trò chơi nhỏ, giao đồ, ve chai
  events.json     cảnh chính ngày 1–30 (địa điểm, khung giờ, lựa chọn, nếu bỏ lỡ), biến thể theo tuyến, sự kiện hệ thống
  story.json      lời mở đầu, tên nhân vật, 8 kết thúc, thẻ hậu truyện của Linh, bà Tư và quan hệ nghề
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
  world/city_map.gd    đọc data/map.json: đường, hẻm, rạch, chia lô mặt tiền, đánh số nhà, lưới đi bộ và tìm đường
  world/street_map.gd  bản đồ nhỏ và bản đồ lớn (phím M), bấm để đi tới
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

Kết quả gần nhất của bản 30 ngày (bỏ qua đường đi bộ; kết thúc và tiền mặt cuối tháng sau khi đã trả chỗ ở):

| Tuyến | Lắng nghe | Giữ tiếp | Áp đặt | Gồng (làm 3 việc, không nghỉ) |
|---|---|---|---|---|
| A · Làm công | E1 · 5,96 tr | E6 · 3,65 tr | E8 · 3,27 tr | E4 · 2,69 tr |
| B · Tổ đội | E2 · 4,09 tr | E4 · 0,38 tr | (khóa B, sang A) | E4 · 1,99 tr |
| C · Dịch vụ riêng | E3 · 4,96 tr | E4 · 1,58 tr | E8 · 1,23 tr | E6 · 1,71 tr |

- Chơi thử trên màn phố thật (đi bộ, thanh làm việc, ăn uống, nói chuyện, cảnh chính, việc nhờ, về xóm trọ ngủ đều chạy như người chơi bấm), in nhật ký từng ngày. Bỏ `--full` để chơi lát cắt:

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/playtest.gd -- --demo --full --route=B --talk
```

**Chạy thử nhanh** (thêm vào sau lệnh chạy game, không ghi đè bản lưu thật):

- `-- --demo --demo-full`: vào thẳng ngày 1 của bản 30 ngày.
- `-- --demo --demo-route=C`: vào thẳng ngày 18 của tuyến C.
- Thêm `--demo-open=ben_can`: mở sẵn một địa điểm.
- Thêm `--demo-end`: tự chơi tới hết ngày 22 để xem bảng tổng kết.

## Khi xuất bản game

Godot không tự đóng gói file `.json`. Trong **Project → Export**, thêm `*.json` vào ô *Filters to export non-resource files*.
