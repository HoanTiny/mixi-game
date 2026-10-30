# Đợt cập nhật phố mẫu — 28/10/2026

Đã có lượt nâng cấp nhân vật, xe và tư thế lái tiếp theo; xem [MOBILITY_UPGRADE.md](MOBILITY_UPGRADE.md).

## Lượt tinh chỉnh theo ảnh tham khảo

Đã chỉnh tiếp trực tiếp đoạn mẫu dựa trên ảnh đường phố người dùng gửi:

- Camera gần nhìn xuống thêm để đọc vỉa hè, ngưỡng cửa và hoạt động mặt phố;
  phạm vi zoom xa/toàn cảnh giữ nguyên. Chỉ preset gần của phố mẫu thay đổi.
- Ánh nắng yếu hơn, bóng mềm hơn và có ánh sáng hắt để thấy chất liệu trong vùng tối.
  Phố mẫu dùng hai vùng bóng định hướng để giảm lượt vẽ khi tăng chi tiết kiến trúc.
- Thay vỉa hè sọc bằng tấm bê tông lớn có khe và góc sứt; thêm bó vỉa xám, rãnh,
  ba miệng cống và nắp ga. Nhựa đường dùng nhiều tỷ lệ texture, giảm lặp vết nứt,
  có lớp bẩn nhẹ quanh tiệm sửa và hòa mép vào đường hiện có.
- Chân tường có dải bẩn mờ dần, vữa/gạch lộ cục bộ, hộp điện, ống dây và cục nóng.
  Các vết cũ được kiểm lại qua ảnh để bỏ kiểu đốm tròn lặp. Sân/xưởng dùng bê tông
  có biến thiên lớn hơn, quán giữ gạch cũ với màu dịu hơn.
- Biển kim loại cũ nhỏ hơn, chữ sơn nhận ánh sáng; giảm nhãn lơ lửng trùng biển thật
  và vòng cửa nổi bật ở góc gần. Nhãn người vẫn hiện khi tới gần, HUD tương tác giữ nguyên.
- Thêm xe đẩy phục vụ với nồi/bát trên kệ, hơi nước nhẹ theo giờ/khoảng cách;
  thùng dụng cụ, ống hơi, khay dầu và bao bì đặt thành cụm sát mép nhà.
- Sân trọ có bồn rửa rỗng và vòi nước, quần/áo phơi có hình dáng và nếp gấp.

Nguồn mới: `scripts/world/pilot_ground.gd`, `scripts/world/pilot_details.gd`;
kiến trúc tiếp tục dùng `scripts/architecture/street_kit.gd`. Không thêm asset mua
hoặc tải từ game tham khảo. Model người/xe hiện có vẫn là giới hạn lớn của hình ảnh;
lượt này chưa thay toàn bộ chúng hoặc toàn bộ bản đồ.

Ảnh lượt tinh chỉnh dùng tiền tố `refined-` trong `tests/`, gồm quán cơm, tiệm sửa,
nhà trọ, sân, toàn cảnh, đêm và mưa. File đo riêng:
`.godot/street-review-refined.json`. Các con số ở phần dưới là bản cập nhật đầu,
không đại diện cho lượt thêm chi tiết này. Kiểm đường đi/click/tương tác và cutaway
vẫn đạt với góc camera mới; shader được kiểm bằng renderer Compatibility thực tế.

Lượt chụp cuối: 1366×800, GTX 1650, Compatibility, 180 frame tại quán cơm:
trung bình 60.0 FPS / 16.67 ms, p99 18.33 ms, 644 draw calls. Đây là mẫu ngắn
có thể bị giới hạn bởi VSync, không phải benchmark toàn game. Đã xem lại ngày,
đêm và mưa; sửa chuyển đổi màu nhựa đường cho Compatibility để không bị đen.
Kiểm `street_prototype.gd` đạt cả chế độ phố mẫu và bản đồ thường; `git diff --check` sạch.

## Chạy bản mới

Mở `play-street-demo.cmd`, hoặc kéo Godot `.exe` vào file đó. Lệnh tương đương:

```text
godot --path . -- --demo --no-title --map=hn_pho_co --street-demo
```

Xuất phát tại Xóm trọ Phúc Tân. Đi sang trái tới tiệm Sơn Sửa, tiếp tục sang trái
đến Cơm Hạnh. Click nền trong cửa hẻm để đi vào sân, dùng WASD hoặc click để đi lại.
Zoom gần/xa và nút toàn cảnh được giữ nguyên. `--demo` không ghi save thật.

Khi chạy game bình thường, ba địa điểm có kiến trúc mới nhưng giữ vị trí câu chuyện.
Phố 64 m, năm nhà phụ, sân đi được và sáu người sinh hoạt chỉ bật trong `--street-demo`.
**Chưa thay toàn bộ map.**

## Những phần đã thực hiện

- Kiến trúc: cửa có độ sâu và khoảng mở thật, cửa chớp, ban công sắt, gờ tường,
  đầu hồi, mái tôn, ống thoát nước; quán cơm, xưởng sửa và nhà trọ có kết cấu khác nhau.
- Bộ dựng dùng mesh theo bề mặt vật liệu, UV theo mét, normals/tangents; có 9 scene
  lưu sẵn (3 mẫu chính, 6 nhà dân) và 28 mesh nhỏ, không dùng model trích từ game khác.
  Runtime dùng cùng nguồn dựng để khớp kích thước từng lô. Xem `data/architecture.json`
  và `assets/architecture/README.md` để tái tạo và kiểm nguồn tài nguyên.
- `data/street_pilot.json` khai báo vị trí/chiều rộng/seed của phố 64 m và năm nhà phụ.
  Dọn nhà nền trước khi dựng lưới đi bộ; không thay file bản đồ câu chuyện gốc.
- Hẻm trọ rộng 3 m mở vào sân rộng 7 m. Navigation chặn từng cánh nhà;
  mặt sàn cao 0.14 m có vùng click riêng. Khi đứng trong sân, tường trước/tầng/mái
  được ẩn theo nhóm, để thấy người, chậu cây, bồn rửa và dây phơi. Nhà trở lại khi ra ngoài
  hoặc bật toàn cảnh; các phòng vẫn bị chặn trong lưới đi bộ.
- Có 2 người ngồi ăn ở quán, 2 người trao đổi/chờ tại bàn sửa và 2 người trò chuyện
  ở sân trọ. Dùng clip `sit`, `idle`, `talk` sẵn có; chưa tạo animation ăn/sửa/giặt mới.
  Hoạt động theo giờ; animation chạy gần người chơi và trong khung nhìn.
- Cây lớn và cột đèn trong đoạn mẫu được đặt tránh các cửa. Biển hiệu được đưa ra
  phía trước mái hiên/cửa cuốn để đọc được từ góc camera chơi.
- Các vật liệu/ánh sáng toàn map và góc camera gần từ lượt trước vẫn được giữ;
  đợt này không lấy kích thước nhân vật trong ảnh toàn cảnh làm lý do thay tỷ lệ người.

## Kiểm tra

Godot 4.7.2, renderer Compatibility, GTX 1650, 1366×800.

```text
godot --headless --path . -s res://tools/build_architecture.gd
godot --headless --path . -s res://tests/pilot_layout.gd -- --demo --street-demo
godot --headless --path . -s res://tests/pilot_layout.gd -- --demo
godot --headless --path . -s res://tests/pilot_life.gd -- --demo
godot --headless --path . -s res://tests/pilot_day.gd -- --demo --street-demo
godot --headless --path . -s res://tests/street_prototype.gd -- --demo --street-demo --midday
godot --headless --path . -s res://tests/street_prototype.gd -- --demo --midday
godot --path . --rendering-method gl_compatibility -s res://tests/street_upgrade_review.gd -- --demo --street-demo --review=after
```

Đã đạt:

- Tải lại 9 scene; mesh winding, UV, normals/tangents; 18 trường hợp nhà hẹp
  3.2–3.6 m; không tự nới nhà vượt chiều rộng lô.
- 9 waypoint hợp lệ, đường đi không tự đổi đích. Vòng trọ → cơm → sửa → sân trái/phải → trọ
  không xuyên vùng cấm; chuyển động theo đường thực tế trong world cũng đến đích.
- Click qua cửa hẻm và phần sân vừa lộ ra không bị hộp collision của nhà chặn.
  Ba bảng địa điểm mở được; camera phục hồi tầng/mái/tường trong chế độ toàn cảnh.
- 6 rig nhân vật, tư thế ngồi khớp ghế, lịch giờ, luân phiên nói/nghe, giới hạn animation
  theo khoảng cách; reservation giữ đám đông tránh chỗ ngồi/đứng.
- Các vị trí câu chuyện trên map thường giữ nguyên; dựng cảnh thường không lỗi script.
- Ảnh chạy thật với HUD ở 13:00, 19:30 và trời mưa đã được xem lại.
- Kiểm logic với dữ liệu hiện tại: ăn cơm trừ đúng tiền/tăng độ no, sửa đồ trả công,
  tắm/nghỉ phục hồi chỉ số; demo không sửa save trong thư mục kiểm tra. Dùng kết quả
  công việc mặc định, chưa phải chơi minigame thủ công hay kiểm save thật.

Ảnh tự tạo trong `tests/`: `baseline-com_hanh-preview.png`,
`after-com_hanh-preview.png`, `after-tiem_sau-preview.png`,
`after-xom_bo_me-preview.png`, `after-courtyard-preview.png`,
`after-pilot-overview-preview.png`, `after-night-preview.png`, `after-rain-preview.png`.
Ảnh/log được gitignore; các script kiểm tra được lưu trong project.

Thông số mẫu nằm trong `.godot/street-review-baseline.json` và
`.godot/street-review-after.json`. Mẫu ngắn 180 frame tại quán cơm cho khoảng
58–60 FPS trước và khoảng 60 FPS sau trên máy kiểm tra. Đây không phải benchmark
chơi liên tục hay bản web; có vsync/cache. Draw calls tăng từ khoảng 409 lên 527
khi thêm nhà và người; cần kiểm thêm khi nhân rộng toàn map. Không dùng thời gian
load giữa các lượt để kết luận nhanh hơn vì cache đã ấm.

`tests/daily_life.gd` đã viết lại theo dữ liệu hiện tại (`an_com`, `tam_rua`, `s.needs`,
chuyển khu tới ca kho); các ý kiểm tra cũ giữ nguyên.

## Phần còn lại

Chưa thay toàn bộ nhà nền, cây hoặc xe thấp chi tiết; các nhà dân phụ chưa có
nội thất/chức năng mới. Chưa kiểm toàn bộ nghề/giao hàng/save nhiều chương, chưa
benchmark trình duyệt. Sáu biến thể kiến trúc là nền để tiếp tục làm cụm phố,
không phải kết luận đã đạt chất lượng mỹ thuật của Nobody: The Turnaround.

Nguồn quan sát vẫn là [launch trailer Thermite Games](https://www.youtube.com/watch?v=kfPlDlSvcGQ):
0:17 sân sinh hoạt, 0:24 mặt tiền lõm và đồ sát tường, 1:14 bàn sửa, 1:39 cụm bàn quán ăn.
Các chi tiết áp dụng là bố cục và nhịp sinh hoạt quan sát được, không suy đoán mã nguồn
hay dùng tài nguyên của game tham khảo. Kế hoạch tiếp theo ở `MAP_UPGRADE_PLAN.md`.
