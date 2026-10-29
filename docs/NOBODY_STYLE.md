# Bản 1.13 · Phố bụi bặm, ngày khắc nghiệt

Đây là lượt nâng cấp đồ họa và vòng chơi theo hướng "Nobody: The Turnaround". Game là 3D, nên các yêu cầu viết theo 2D được làm bằng cách tương đương trong 3D:
- Sprite → mesh;
- `PointLight2D` → `OmniLight3D` kèm quầng sáng;
- Decal → mặt phẳng trong suốt, vì renderer Compatibility của bản web không có node `Decal`.

Từng phần bật tắt được trong `data/config.json` → `look` (`postFx`, `ink`, `sun45`, `grit`).

## Đồ họa

| Hạng mục | Cách làm | File |
|---|---|---|
| Lọc màu Gritty Urban | `CanvasLayer` (layer 0, dưới HUD) đọc texture màn hình: bão hòa 0,8, tương phản 1,15, ám vàng bụi ấm, tối góc, hạt nhiễu nhẹ. Ban đêm bớt tương phản và tối góc để phố vẫn đọc được. Môi trường để trung tính cho khỏi lọc hai lần. | `scripts/world/post_fx.gd` |
| Nắng 45°, bóng đậm | `DirectionalLight3D`: `shadow_opacity = 0.75`, blur 1, cao 45° (lệch vài độ theo giờ), bóng đổ chéo xuống phải màn hình. | `world.gd` `_update_lighting` |
| Bóng chân | Mặt phẳng hình elip dưới chân, dựng lại trong không gian thế giới nên nhân vật xoay mà bóng vẫn đổ cùng hướng nắng. Có cho An, người quen, cư dân, người đi bộ có xương, hàng rong, đồ phố (MultiMesh bóng). | `scripts/world/ink.gd` (blob) |
| Viền đen inverted hull | Vẽ lại mặt sau lưới, đẩy ra 1,8 px tính theo màn hình (`material_overlay`) cho người, xe, đồ vật. Nhà và cây dùng pass phụ `next_pass` chung logic hạ nhà quanh An, nên phần nhà đã hạ không còn viền lơ lửng. Điện thoại yếu bỏ viền nhà. | `ink.gd` |
| Cel-shading 3 cấp | Hàm `light()` (sáng / nửa tối / tối, ranh giới mềm) trong shader da, vải của An và cư dân; vật liệu `StandardMaterial3D` của người thì đổi sang `DIFFUSE_TOON`. | `an_material.gdshader`, `fabric.gdshader`, `ink.gd` |
| Đèn đường từ 18:00 | `OmniLight3D` bật lúc 18:00 (ngày mưa 16:00), thêm quầng sáng vàng quanh bóng đèn, vầng sáng trên mặt đường. | `world.gd` `_lamp` |
| Vỉa hè, lòng đường | Gạch lục giác 25 cm, gạch vuông 40 cm đỏ đất xen xám, vân bẩn (loang ố, vết nứt chân chim, kẹo cao su). Nhựa đường có mảng vá, đá dăm, nứt. Rãnh biên tối màu. Bó vỉa cao 15 cm, có cả ở phố hẹp có vỉa hè. Phố 4,5–6 m có vạch trắng đứt ở tim đường. | `scripts/realmap/area_builder.gd` (GROUND_SHADER) |
| Vết bẩn, đồ phố | Khoảng 480 vết: vũng nước, lá rơi, vết dầu, rác vụn, vết nứt lớn. Đồ phố dọc mép trong vỉa hè: thùng rác xanh, biển quảng cáo đứng chữ A (có chữ CƠM BÌNH DÂN, SỬA XE…), hàng xe máy dựng, bàn ghế nhựa, xe hàng rong; cột điện, dây điện vẫn do `street_dress.gd` dựng. | `scripts/world/street_grit.gd` |

## Độ cuốn

- **Phản hồi** (`scripts/world/juice.gd`):
  - Chữ nổi xếp chồng, nảy lên rồi bay lên mờ dần, cho tiền, No bụng, Vệ sinh, Tâm trạng, Thể lực mỗi khi một thao tác làm số đổi.
  - Xong trò chơi nhỏ thì rung máy quay, hạt vàng bung và có chữ khen. Live Shippy xong cũng vậy.
- **Trạng thái trên người An:**
  - Độ no hoặc Tâm trạng dưới 30: đi chậm còn 82%, lưng khom, vai rũ (`SkeletonModifier3D` trong `an_character.gd`), mây đen có mưa lơ lửng trên đầu.
  - Vệ sinh dưới 30: hơi bốc mùi xanh vàng bay lên, người đi ngang hiện câu né ("Eo…", "Mùi gì thế?"), người đi bộ né xa gấp 1,8 lần.
- **Áp lực sinh tồn ngày 1** (`data/systems/hardship.json`, `scripts/systems/hardship.gd`; chỉ khi chơi đủ 30 ngày, ở chương 1):
  - **Tiền khởi đầu:** ngày 1 An còn 50.000đ. Lời truyện ngày 1 đã sửa theo.
  - **Tiền trọ:** 60.000đ mỗi đêm, trả cô Duyên mới ngủ và nghỉ ở phòng được. Hết ngày mà đủ tiền thì tự trừ; thiếu tiền thì nợ một đêm (cô Duyên −4, Tâm trạng −8, Mệt +6). Bỏ khoản trừ 120.000đ sinh hoạt cả nhà mỗi tối; ăn uống giờ tự trả từng bữa.
  - **Tắm:** vòi chung chỉ +40 Vệ sinh, 25% cảm lạnh (Tâm trạng −6, tụt nhanh hơn, đi chậm 20 giờ). Nhà tắm nước nóng 25.000đ thì +100 và khỏi cảm.
  - **Giặt:** cần xà phòng (15.000đ được 3 lần, mua ở chợ Long Biên) hoặc gửi tiệm giặt 20.000đ.
  - **Việc thưởng nóng:** mỗi sáng một việc trả lương ×2.
  - **Mục tiêu ngắn hạn trên HUD:** cọc phòng Ngọc Thụy 1.800.000đ, rồi smartphone 1.500.000đ ở tiệm cầm đồ. Có smartphone thì đơn Giao Nhanh tới nhanh hơn 30%, người xem live đông hơn 20%.
- **Tổng kết cuối ngày** (`scripts/ui/day_summary.gd`): thu, chi, tiền còn (số chạy), từng khoản, nhu cầu đổi so với sáng, tiền trọ, thanh mục tiêu, sổ tay, hé lộ ngày mai; trả tiền trọ hay xin ghi nợ ngay trong màn này.
- **Điện thoại 06:00:** thông báo trượt xuống báo việc thưởng nóng, tin nhắn mới, lời nhắc tiền trọ; bấm để mở điện thoại.
- **HUD:**
  - Thêm thanh Vệ sinh dưới Độ no, các dòng tiền trọ đêm nay, việc thưởng nóng và thanh mục tiêu.
  - Bảng chỉ số và khung "Mục tiêu quan trọng" có nền đậm 0,85.

## Kiểm tra

- **Bài kiểm thử:** `tests/hardship.gd` mới, đạt hết. Các bài `relationships_commerce`, `day23`, `neighborhood_story`, `opening_slice`, `survival_attributes`, `minigames`, `event_scheduler`, `event_scheduler_world` đều đạt.
- **Mô phỏng 30 ngày:** vẫn ra đủ các kết như trước. Cả tháng dễ thở hơn một chút vì 60.000đ tiền trọ thấp hơn 120.000đ sinh hoạt cũ. Kết E4 (cách chơi "ít việc") không còn xuất hiện.
- **Bài đang hỏng:** `location_panel_layout` và `neighborhood_world` hỏng y như trên code trước khi sửa (chuyện ghi save của bản demo), không do lượt này.
