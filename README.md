# Trước mùa mưa

Game mô phỏng đời sống lấy cảm hứng từ *Nobody: The Turnaround*, bối cảnh phường An Hòa của thành phố hư cấu Bình Giang. An, 27 tuổi, vừa mất việc ở tiệm điện máy. Cả nhà có 30 ngày để dọn khỏi xóm trọ Bờ Me và tìm chỗ ở mới. Thiết kế đầy đủ nằm trong [docs/](docs/README.md).

Làm bằng **Godot 4.7**. Nhà cửa được dựng theo từng gian, dùng vật liệu tường ảnh; nhân vật có hình học cơ thể, trang phục và khớp tay chân. Phần mỹ thuật vẫn đang được hoàn thiện.

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
| Con lăn chuột trên cảnh phố | Phóng gần / thu xa để xem nhân vật và nhà cửa |
| Nút **Về xóm trọ** | Đi về Bờ Me. Chỉ ngủ được ở đó; 22 giờ chưa về thì ngủ gục ngoài đường, Mệt +15. |

**Thời gian:** đi bộ, chờ ca làm và hội thoại đều tiêu hao No bụng và Vệ sinh. Làm việc khi đói tăng Mệt; tinh thần thấp khiến ca làm nặng hơn. Về xóm trọ trước 22:00 để ngủ. Ngủ ngoài đường không hồi sức như ngủ trên giường.

Ván chơi tự lưu sau mỗi thao tác vào `user://save.json`. Nút **Chơi lại** trong Bảng cân bằng xóa ván đang chơi.

## Cấu trúc thư mục

```
data/
  config.json     số liệu: tiền sinh hoạt, Mệt, chỗ ở, điểm xuất phát của 3 tuyến, việc làm và địa điểm của từng việc
  events.json     sự kiện ngày 18–22, biến thể theo tuyến, sự kiện hệ thống (nghiệm thu, nợ chưa trả, ngủ gục)
  story.json      lời mở lát cắt, tên nhân vật, thẻ hậu truyện của Linh và bà Tư
docs/             tài liệu thiết kế "Trước mùa mưa" (Godot bỏ qua thư mục này)
prototype/        bản thử HTML đầu tiên (cốt truyện cũ)
scripts/
  game_logic.gd   toàn bộ luật chơi, không phụ thuộc giao diện
  game_state.gd   autoload GameState: giữ ván chơi, tự lưu
  world/world.gd  phố 3D: địa điểm, nhân vật, rạch và cầu, xe máy, người đi đường, ánh sáng theo giờ
  world/citizen.gd  tỷ lệ cơ thể, trang phục theo nhân vật, khớp tay/chân, dáng đi và tư thế ngồi xe
  world/neighborhood.gd  nhà chia gian, cửa có chiều sâu, ban công, mái tôn; gộp hình học theo vật liệu
  world/hud.gd    HUD kiểu Nobody: mục tiêu, tiền và Mệt, bảng địa điểm, thanh "đang làm", Sổ, Nhật ký
  ui/ui_kit.gd    màu sắc, theme, thẻ hành động, hai cột tiền, Sổ dạng chữ
  ui/dialog_layer.gd  hộp thoại chọn tuyến, sự kiện, đi ngủ, tổng kết lát cắt
  board.gd        Bảng cân bằng: chơi bằng nút bấm, thấy hết dòng tiền và các sổ
scenes/
  world.tscn      màn chính
  board.tscn      Bảng cân bằng
tests/
  sim.gd          tự chơi lát cắt cho 3 tuyến × 3 cách chơi
```

## Chỉnh cân bằng

### Sinh hoạt hằng ngày (bước 1)

- Màn phố vẫn là lát cắt ngày 18–22. Thêm **No bụng, Vệ sinh, Tinh thần** bên cạnh Mệt.
- **Cơm Hạnh:** cơm phần 35k / nửa giờ. **Chợ Cầu Nhỏ:** bánh mì 15k / 15 phút.
- **Xóm trọ:** cơm nhà 20k, nghỉ một giờ, ngủ trưa (11–16 giờ), tắm và thay đồ, ngủ sang sáng hôm sau. Cuộn bảng địa điểm để xem hết hành động.
- Phí sinh hoạt chung giảm xuống **60k/ngày**, không gồm bữa ăn của An. Dự kiến tiền nhà có dự trù thêm 60k/ngày cho ăn uống; chỉ mua món mới trừ tiền ăn thật.
- Nhu cầu giảm theo giờ thức. Đói dưới 20 làm tăng Mệt; tinh thần dưới 25 làm ca làm tăng Mệt. Đói hoặc vệ sinh thấp giảm hồi sức khi ngủ. Tắm đã gồm trong phí chung, luôn dùng được khi hết tiền.
- Bản lưu cũ tự bổ sung ba chỉ số mới, giữ nguyên tiền và tiến độ. Tên project nội bộ được giữ để không đổi thư mục lưu.
- HUD màu than / vàng nhạt, vật liệu bề mặt, mái tôn, cửa sổ, điều hòa, vỉa hè, cống và góc máy chéo đã được cập nhật. Nhân vật và cảnh vẫn dùng mô hình dựng bằng code, chưa phải asset chân thực hoàn chỉnh.
- Kiểm tra logic: chạy Godot với `--headless --path . -s res://tests/daily_life.gd`.
- Kiểm tra HUD và xuất ảnh từ renderer: `--path . -s res://tests/capture_world.gd -- --demo --demo-route=A --demo-open=xom_bo_me`. Ảnh tại `tests/daily-life-preview.png`; chế độ demo không ghi đè bản lưu.
- Kiểm tra mỹ thuật và di chuyển: `--path . -s res://tests/capture_art.gd -- --demo --demo-route=A`. Xuất ba ảnh `neighborhood-preview.png`, `character-preview.png`, `shop-preview.png` trong `tests/`.
- Vật liệu tường: `assets/materials/aged-plaster.png`, tạo bằng ImageGen tích hợp; prompt và nguồn lưu trong `assets/materials/source.json`. Các mô hình được dựng trong dự án, không lấy asset từ Nobody.

- Sửa số trong `data/config.json` rồi chạy lại game. Điểm xuất phát của từng tuyến nằm ở `presets`.
- Bảng cân bằng (nút **Bảng cân bằng** ở dưới màn phố) cho chơi nhanh bằng nút bấm.
- Chạy mô phỏng:

```bash
"C:/Users/Admin/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s res://tests/sim.gd
```

Các số cân bằng cũ đã thay đổi khi thêm nhu cầu sinh hoạt; chạy lại tests/sim.gd để xem kết quả hiện tại.

**Chạy thử nhanh** (thêm vào sau lệnh chạy game, không ghi đè bản lưu thật):

- `-- --demo --demo-route=C`: vào thẳng ngày 18 của tuyến C.
- Thêm `--demo-open=ben_can`: mở sẵn một địa điểm.
- Thêm `--demo-end`: tự chơi tới hết ngày 22 để xem bảng tổng kết.

## Khi xuất bản game

Godot không tự đóng gói file `.json`. Trong **Project → Export**, thêm `*.json,*.glb` vào ô *Filters to export non-resource files* (An đọc GLB gốc bằng GLTFDocument khi khởi tạo).

## An: model có xương và ngoại hình

- An dùng `assets/characters/an/an-rigged.glb`: rig 24 xương, hoạt ảnh Casual Walk. Hướng +Z, chân ở mặt đất, cao 1,75 m. NPC vẫn dùng mô hình hiện tại.
- `scripts/world/an_character.gd` tạo clip đứng thở nhẹ, chuyển mềm sang đi bộ và loại bỏ dịch chuyển ngang ở xương hông để vị trí luôn do gameplay quản lý.
- `an_material.gdshader` bỏ metallic, tăng roughness, giảm normal strength và giữ chi tiết vải khi đổi màu. Mặt nạ màu suy ra từ vị trí đỉnh ở tư thế gốc và màu texture; mép cổ áo/tóc có thể cần chỉnh tay nếu thay model khác.
- Nút **Nhân vật / Túi đồ** mở túi bên trái, An 3D ở giữa, trang bị và chỉ số bên phải. Chọn món đã sở hữu rồi bấm **Mặc món đã chọn**; thay đồ không tốn tiền. Chợ Cầu Nhỏ bán 3 màu áo caro và 2 màu jeans (85.000–160.000đ, 15 phút/lần).
- Tiệm tóc đầu ngõ ở phía trái bến xe: cắt/tỉa 40.000đ (30 phút), nhuộm 80.000–100.000đ (1 giờ). Cửa hàng mở 08:00–19:00. Kiểu tự nhiên và cắt gọn hiện là hai biến thể đỉnh tóc của model, chưa phải bộ tóc thay rời. Quần áo hiện là biến thể màu của cùng dáng áo/jeans.
- Inventory, trang bị, màu tóc và kiểu tóc được lưu cùng ván chơi (save v3); bản lưu cũ giữ nguyên màu đang mặc. Không trừ tiền khi thiếu tiền, hết giờ, sai cửa hàng, mua trùng hoặc đang có sự kiện chờ.
- Kiểm tra: `-s tests/an_integration.gd -- --demo` kiểm tra kinh tế, dịch vụ tóc, nút mặc đồ, lưu/đọc JSON, migration và đứng/đi; `--headless -s tests/daily_life.gd -- --demo` kiểm tra sinh hoạt. Không ghi đè save người chơi.
- Rig lần đầu bị lỗi do model gốc quay +X; bản lỗi giữ ở `an-rig-rejected.glb`. `tests/prepare_an_rig.cjs` tạo đầu vào chuẩn hóa cho lần rig đạt kiểm tra. Hai lần rig tốn tổng 16 credit; số dư sau thực hiện 122.

## Bản chơi thử ngày 1–5: nghề và khu phố

Ở màn bắt đầu, chọn **Bắt đầu ngày 1–5**. Bản lưu đang chơi tiếp tục được giữ cho tới khi người chơi chủ động chơi lại. Để thử độc lập, chạy `-- --demo --pilot`; chế độ này không ghi bản lưu thật. Các lựa chọn A/B/C ngày 18–22 vẫn ở màn bắt đầu.

- Bắt đầu với 180.000đ, mục tiêu còn 500.000đ sau chi phí đêm thứ năm. Sổ giữ tiền phải thu/phải trả; nhật ký giải thích thu, chi và quyết định của người quen.
- Tiệm Sáu (08–18h): mỗi ngày một khách; nhận → đo kiểm → chọn nguồn linh kiện → chọn cách sửa → chạy thử → trả món. Hai loại lỗi: tụ quạt và cầu chì nhiệt của ấm. Thao tác sai mất thời gian, không hoàn tất đơn. Có thể xin trả lại món với uy tín −3.
- Mỗi đơn hẹn 17h ngày hôm sau. Trả muộn nhận 80% tiền công và uy tín −3. Trả đúng giờ tăng uy tín. Đơn đang làm được lưu và tiếp tục hôm sau.
- Chợ (07–19h): mỗi linh kiện hai món/ngày; mua rẻ hơn dùng linh kiện tiệm 20.000đ. Đồng hồ đo 180.000đ bán ngày lẻ, giảm thời gian đo còn 15 phút.
- Hai món hoàn thành mở lỗi ấm điện; ba món mở sửa nhanh. Có thể chọn làm độc lập sau ba món và uy tín Sáu ≥55, không còn lời hứa chưa giải quyết; đơn mới tăng 10% tiền công. Các hợp đồng lớn A/B/C vẫn thuộc lát cắt cũ.
- Quán cơm: ca phụ 10–14h, 2 giờ/130.000đ; giao cơm 11–14h, 1 giờ/70.000đ. Chưa có minigame phục vụ hay điều khiển từng chuyến giao.
- Bà Tư đi chợ sáng; Sáu mở tiệm ban ngày; Hạnh ở quán trưa/tối; Linh ở bến xe trong giờ đi học, về trọ sau 17h. NPC đi bộ theo đường A* quanh vật cản trên phố; chỉ đổi điểm đến khi lịch sinh hoạt đổi. Bấm vào NPC đang đi sẽ báo nơi họ tới.
- Hỏi Linh khi em về, giúp bà đóng đồ buổi tối; Linh tự nộp hồ sơ ngày 3. Tin nhắn và giấy báo ngày 4 vào nhật ký. Thiếu tiền dưới 30.000đ có thể mượn bà một lần, khoản phải trả được ghi vào Sổ.
- Sau khi lấy linh kiện, chọn **Mở bàn sửa 3D**: kéo món hỏng sang khay, kéo linh kiện mới vào ổ lắp, bấm hai vít, rồi chạy thử. Chuột phải xoay góc nhìn, con lăn phóng; Esc rời bàn và giữ tiến độ. Quạt và ấm có bàn/linh kiện khác nhau. Sửa nhanh vẫn dành cho tay nghề đã thành thạo.

Kiểm tra: `--headless -s tests/street_life.gd -- --demo` (kinh tế, đơn, tiến triển, 5 ngày), `-s tests/pilot_ui.gd -- --demo --pilot` (giao diện và NPC), cùng `tests/daily_life.gd`, `tests/sim.gd`, `tests/an_integration.gd` để kiểm tra hồi quy.

### Bàn sửa và đường đi NPC

- `scripts/world/repair_bench.gd`: scene bàn sửa dựng bằng mesh 3D, chuột được chiếu lên mặt bàn để kéo thả; nhận biết sai linh kiện/vị trí, vít đã siết chuyển xanh, quạt quay khi chạy thử đạt. Đây là mô hình tương tác đơn giản, chưa phải mô phỏng tháo lắp từng chi tiết điện thực tế.
- `Street.bench_action` kiểm tra lại đơn, giờ mở cửa, thời gian và mệt ở từng bước. Thao tác trung gian lưu vào `job.bench`; chỉ khi đủ hai vít mới trừ 45 phút và Mệt +8. Không mua hoặc tiêu hao linh kiện lần hai. Đóng bàn giữa chừng giữ tiến độ; thả sai trả món về chỗ cũ.
- `scripts/world/resident_routes.gd`: lưới A* có vùng cấm cho bàn, thùng và cột điện; tốc độ 1,65 m/s (bà Tư 1,15 m/s), xoay người và hoạt ảnh đi bộ. Điểm đến đổi giữa đường thì tính lại tuyến từ vị trí hiện tại. Vị trí được giữ trong bản lưu cùng các lần lưu gameplay; khởi tạo ván mới đặt NPC tại địa điểm phù hợp giờ bắt đầu.
- Hội thoại với Linh/bà Tư ở nhà đợi họ tới nơi. Đường đi tạm dừng khi mở cửa sổ tương tác như bàn sửa hoặc túi đồ. An, NPC có tên và người đi đường dùng chung va chạm trên mặt đất; chọn phía tránh, chờ hoặc lùi nhường ở lối hẹp.
- Kiểm tra mới: `-s tests/bench_routes.gd -- --demo --pilot`. Test phát sự kiện chuột qua cửa sổ thực: sai ổ lắp, sai loại, hai loại đơn, đổi góc nhìn, đóng/mở, lưu tiến độ, tính thời gian một lần; kiểm tra đường đi tại sáu mốc giờ và khôi phục vị trí.


### Bản thử khu phố: va chạm và nhiệm vụ đầu tiên

Chạy `play-street-demo.cmd` trên máy hiện tại, hoặc Godot với `--path . -- --demo --pilot --street-demo`. Bản thử bắt đầu 08:00 trước Tiệm Sáu, NPC đi từ vị trí buổi sáng tới nơi làm việc. Không ghi đè bản lưu thật. Tệp CMD có đường dẫn Godot của máy phát triển; sửa đường dẫn nếu chuyển máy.

- An và 17 người đi bộ dùng chung vùng va chạm tròn trên mặt đất (bán kính 0,32m, thêm khoảng cách nhỏ). Đây là bộ giải chuyển động riêng, không phải mô phỏng đẩy ngã/ragdoll. Mỗi đoạn di chuyển kiểm tra theo bước tối đa 10cm để ngăn xuyên người khi khung hình dài.
- NPC ưu tiên tránh bên phải, lùi nhường theo thứ tự ổn định khi tắc lối; người đi đường đổi ý nếu đích đứng bị chặn. NPC theo lịch tìm lại tuyến quanh người, chọn điểm đứng riêng trước cửa tiệm. Người đứng yên không bị đẩy đi. Xe máy chưa tham gia hệ va chạm người đi bộ.
- Bấm để An đi tới cửa tiệm dùng đường tìm trên vỉa hè; WASD vẫn do người chơi điều khiển và trượt khi gặp vật cản. Thời gian đi bộ và hoạt ảnh dựa trên quãng đường thực sự đi được.
- Nhiệm vụ đầu tiên lấy tiến độ trực tiếp từ đơn sửa: nhận → đo → chọn linh kiện → bàn sửa → chạy thử → trả khách. Có dấu ! tại nơi cần tới và thông báo nhận/trả việc, không tạo tiền công lần hai.
- Camera gần và thấp hơn; HUD chỉ hiện thanh nhu cầu khi cần chú ý, các giá trị bình thường gộp một dòng. Giao diện đầy đủ nằm trong Nhân vật / Túi đồ. Bảng cân bằng dành cho phát triển bật bằng `--debug-ui`. Đây là bước thử chuyển động và cách trình bày; tài sản 3D cao cấp và trò ném vòng chưa nằm trong bản thay đổi này.
- Kiểm tra mới: `tests/crowd_motion.gd` (đối đầu, An đứng chắn, khung hình dài, hành lang hẹp), `tests/crowd_world.gd` (An đi tới/lui giữa tiệm và nhà trong cả đám đông), cùng `tests/bench_routes.gd` và `tests/pilot_ui.gd`.
