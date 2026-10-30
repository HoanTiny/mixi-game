# Nhân vật và xe — 28/10/2026

Đợt này nâng cấp trực tiếp tài nguyên và cách dựng nhân vật/xe trong game.
Mở `play-street-demo.cmd` để xem trong đoạn phố mẫu. Các bộ model/material dùng
chung cũng được dùng khi chơi bản đồ thường; không thay nội dung save hay nhiệm vụ.

## Bổ sung chuyển động và ánh sáng

- Bánh xe của An và xe traffic ở gần quay theo quãng đường/bán kính thực. Chỉ lốp,
  vành, nan và đĩa phanh quay; thân xe, phuộc, cùm phanh giữ nguyên. Tính pha độc lập
  với thời gian shader nên dừng lại là bánh dừng, không bị quay khi xe bị chặn.
  Xe đậu dùng vật liệu riêng và đứng yên. Không thêm lượt vẽ riêng cho từng bánh.
- Hướng quay người dùng thời gian khung hình; nhịp bước và tiếng chân lấy quãng
  đường di chuyển thành công, kể cả đoạn cuối của đường tìm tự động. Người và xe
  cùng nghiêng tối đa khoảng 7° khi rẽ rồi trở về thẳng khi dừng. Vòng chọn vẫn
  nằm phẳng. Đường đi, tốc độ di chuyển và va chạm do hệ thống cũ quyết định.
- Nhịp bước An/NPC tăng giảm mượt, có ngưỡng tránh đổi idle–walk liên tục. An có
  nhịp thở/chuyển vai nhẹ khi đứng; lúc lái, thân và ánh nhìn phản ứng với tốc độ
  và hướng rẽ, sau đó giải lại tay/chân để giữ tiếp xúc. Sửa góc lòng bàn tay
  đang bị xoay theo dáng scan; chưa bổ sung xương ngón tay.
- Xe đang chạy có mặt đèn trước/sau phát sáng về đêm. Xe An có thêm đèn pha chiếu
  xuống mặt đường, bật dần lúc chạng vạng và tắt ngay khi xuống xe. Xe đậu không
  bật đèn. Kính ô tô đổi sang xám xanh trầm; bổ sung cổ nối dưới tay lái xe máy.
- API nguồn: `scripts/vehicles/player_motion.gd`, `Props3D.moving_instance()` /
  `set_vehicle_distance()`, `AnCharacter.set_ride_motion(speed_mps, turn)`.

## Nhân vật

- Giữ model An hiện có (khoảng 17.7k tam giác, 24 xương), texture, đổi màu áo/quần,
  tóc và hoạt cảnh đi. Sửa màu vật liệu, giảm tương phản của họa tiết vải; tư thế
  đứng hạ tay tự nhiên hơn. Đây không phải thay bằng một mesh người hoàn toàn mới.
- Rocketbox giữ texture gốc và xương; vật liệu phân biệt da, vải, tóc. Hạnh mặc
  áo xanh nhạt và tạp dề nâu, thay đầu không có mũ đầu bếp; Minh dùng áo xanh trầm,
  mũ của Sơn chuyển sang xám rêu. Không đổi ID nhân vật/câu chuyện.
- An ngồi xe bằng tư thế xương có mục tiêu tay/chân, bù cổ/đầu để nhìn phía trước.
  Mũ bảo hiểm có viền và quai; kích thước được bù theo đơn vị centimet của rig.
  Nhận đơn giao hàng ẩn mũ đang mặc, đội mũ bảo hiểm; xuống xe khôi phục mũ trong tủ.
- Người lái xe gần có 27 mesh pose được dựng lại từ Rocketbox, giữ tư thế sau khi
  animation cập nhật để tay không quay về đầu gối; có bản riêng xe số/tay ga/người sau.

## Xe

- Xe tay ga ~8.3k, xe số ~8.4k, ô tô ~14.4k tam giác ở mức chi tiết gần. Có lốp,
  vành/nan, phuộc, máy, pô, gương, đèn, yên; ô tô có thân liên tục, vòm bánh mở,
  cột kính, gạt mưa, tay nắm và lưới tản nhiệt.
- Sơn, kim loại, cao su, nhựa và kính dùng phản ứng vật liệu riêng trong một mặt lưới
  cho phần xe. Người lái và mũ dùng các mặt riêng. Bỏ bóng giả đa giác ở xe chạy gần.
- Traffic đổi sang bản chi tiết trong 20 m, giữ tới 24 m để tránh đổi liên tục ở ranh
  giới; xa giữ bản nhẹ. Màu sơn/mũ giảm độ rực. Không đổi quy tắc đi làn hoặc tốc độ.
  Danh sách xe gần được gom liên tục và giới hạn số instance thực sự vẽ, tránh gửi
  mesh chi tiết của xe xa lên GPU dù xe đó đã bị thu nhỏ để ẩn.
- Xe đậu chia ô 24 m, chuyển mức theo khoảng cách camera tại 48 m bằng quan hệ
  phụ thuộc hiển thị của Godot; toàn cảnh dùng bản nhẹ. Không đổi vị trí xe hoặc
  lưới đường đi. Kiểm cả đúng ranh giới để tránh mất xe hoặc vẽ hai xe chồng nhau.

## Nguồn và tái tạo

- `scripts/vehicles/vehicle_kit.gd`: nguồn hình học xe mới, tự dựng trong project.
- `tools/build_vehicles.gd` → `assets/vehicles/*.res` (kiểm normals, winding, bounds,
  mask vật liệu, cache và lưu/nạp lại). Đọc `assets/vehicles/README.md`.
- `tools/bake_traffic_riders.gd` → `assets/rb/riders_detail/*.res`; dùng renderer thật
  để bake sau cập nhật xương, kiểm vị trí cổ tay/cổ chân. Đọc README trong thư mục này.
- Rocketbox giữ giấy phép MIT tại `assets/rb/NGUON.md`; An giữ nguồn đã có trong
  `assets/characters/an/source.json`. Không mua hoặc trích model từ game tham khảo.

## Kiểm tra

- `tests/character_realism.gd`: màu/tóc, idle–walk–sit, tái sử dụng mũ, vị trí tay/chân
  và hướng đầu/lòng bàn tay.
- `tests/traffic_realism.gd`: làn, đổi mức chi tiết, không vẽ trùng, mật độ, vòng tuyến,
  teleport và dựng lại các nhóm xe; dùng Compatibility thực vì headless không cho
  kết quả đọc lại MultiMesh phù hợp.
- `tests/parked_vehicle_lod.gd`: số lượng/vị trí/màu và các mốc 47.99/48.00/48.01 m;
  hai xe thử có 16,648 tam giác ở gần, 576 ở xa/toàn cảnh, đều một lượt vẽ.
- `tests/mobility_gameplay.gd -- --demo --street-demo`: mặc đồ trên cùng rig, cắt tóc,
  nhận/hủy đơn, tư thế lái không biến thành đi bộ, mũ bảo hiểm/mũ thường được phục hồi,
  tiền và trạng thái tủ đồ giữ đúng. Dùng API tủ đồ hiện tại (`wear_item`, `wardrobe`).
- `tests/mobility_review.gd -- --review=mobility-after`: ảnh người, bước đi, An lái xe,
  hai xe máy, ô tô và người lái/người ngồi sau dưới ánh sáng cố định.
- `tests/vehicle_motion.gd`: renderer Compatibility thật; so ảnh bánh quay/thân
  đứng yên, đủ một vòng trở lại đúng hình, dừng không đổi hình, vật liệu riêng và
  đèn ban đêm chỉ bật ở xe chạy.
- `tests/character_motion.gd`: nhịp bước theo thời gian, chân đứng không trượt,
  phản ứng lúc lái, tiếp xúc tay/chân, hướng bàn tay, đầu và reset khi xuống xe.
- `tests/player_motion.gd -- --integration --demo --street-demo`: quay hướng tại
  30/60/120 FPS, đoạn cuối của đường, nghiêng chung, vòng chọn, đèn và lên/xuống xe.
- `tests/mobility_motion_review.gd -- --demo --street-demo`: ảnh thực trong phố
  khi rẽ, dừng và bật đèn đêm (`tests/mobility-motion-*-preview.png`).

Đã kiểm ảnh và sửa lỗi yếm xe xuyên mặt, thân ô tô ghép hộp, bóng giả dưới xe gần,
An bị ẩn do sai đơn vị xương, tóc xuyên mũ và đầu cúi khi lái. Không dựa riêng vào
test headless để kết luận chất lượng hiển thị.

Kiểm tra cuối đạt cả phố mẫu và bản đồ thường bằng `tests/street_prototype.gd`.
Lượt đo sau bổ sung chuyển động, An đang ngồi xe tại quán cơm: GTX 1650,
Compatibility, 1366×800, 180 frame; trung bình 60.11 FPS / 16.64 ms,
p99 19.53 ms, 682 lượt vẽ, 1.38 triệu primitive được gửi.
VSync và tác vụ nền có thể ảnh hưởng mẫu này; không coi là benchmark toàn game.
Báo cáo tại `.godot/street-review-mobility-latest.json`; ảnh phố có tiền tố
`mobility-latest-`. Ảnh kiểm đèn bật/tắt cho thấy 6,228 mẫu ảnh sáng hơn rõ rệt
trong cùng một cảnh đã dừng chuyển động, xác nhận đèn pha tác động lên cảnh thật.

## Giới hạn còn lại

Đây là bản nâng cấp chất lượng của tài nguyên hiện có và xe tự dựng, chưa ngang
độ chi tiết của ảnh tham khảo. Rig An chưa có xương ngón tay nên chưa
khép từng ngón quanh tay nắm. Chưa có đánh lái riêng bánh trước, hệ thống nhún,
nội thất ô tô hay animation lên xe/xuống xe chuyển tiếp; chuyển trạng thái hiện
dùng pose và blend. Chuyển động nghiêng là biểu diễn, chưa phải mô phỏng động lực
học xe. Người/xe ở xa vẫn dùng bản ít chi tiết để giữ hiệu năng.
