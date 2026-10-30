# Kế hoạch nâng cấp kiến trúc và map

Ngày lập: 28/10/2026. Trạng thái: đã triển khai bản đầu của giai đoạn 0–2;
giai đoạn 3–5 chưa hoàn thành. Chi tiết bản chạy và kiểm tra trong
[STREET_PROTOTYPE.md](STREET_PROTOTYPE.md).

## Tiến độ bản cập nhật đầu tiên

- Đã có 9 scene kiến trúc, mesh có UV/normal/tangent; ba mẫu chính và sáu biến thể nhà dân.
- Đã dựng phố mẫu 64 m với ba địa điểm, năm nhà phụ, hẻm rộng 3 m và sân rộng 7 m.
- Đã có sáu người nền dùng các animation ngồi/đứng/trò chuyện sẵn có, xuất hiện theo giờ.
- Đã tách tầng, mái và tường cánh trước nhà trọ để camera mở sân mà không kéo méo nhà.
- Đã kiểm đường đi, click sàn hẻm/sân, tương tác cửa, toàn cảnh; chụp ngày/đêm/mưa.
- Chưa thay toàn bộ nhà nền, cây, nhân vật hoặc animation nghề. Bản web và các save
  nhiều chương chưa được kiểm lại đầy đủ. Chất lượng nghệ thuật cần tiếp tục rà trước
  khi nhân rộng; số lượng scene không đồng nghĩa đã đạt mức hoàn thiện của game tham khảo.

## Mục tiêu và phạm vi

Đưa map từ cảm giác sa bàn khối hộp sang khu phố đời thường có chiều sâu kiến trúc,
địa điểm dễ nhận ra và hoạt động có chủ đích. Tham khảo cách tổ chức hình ảnh của
Nobody: The Turnaround, giữ bối cảnh và câu chuyện Hà Nội của project hiện tại.

Phạm vi hoàn thành là toàn bộ map câu chuyện `hn_pho_co`: tất cả địa điểm tương tác,
các tuyến đi lại nối chúng và nhà nền xuất hiện từ các tuyến này. Ba mặt tiền hiện có
là bản thử ban đầu, chưa phải bộ kiến trúc đạt chuẩn để nhân rộng.

Giả định làm việc: tiếp tục Godot 4.7, renderer Compatibility, ưu tiên asset đã có;
giữ khả năng zoom gần/xa và toàn cảnh mà người chơi chủ động sử dụng. Mốc hiệu năng
được kiểm trên PC trước, sau đó bản web theo cấu hình xuất hiện có. Chưa có ngân sách
mua asset, vì vậy kế hoạch không phụ thuộc vào việc mua bộ model trả phí.

## Hiện trạng trước bản cập nhật

- `area_builder.gd` dựng phần lớn nhà bằng cách đùn đường viền. Cửa sổ/cửa tầng trệt
  chủ yếu là shader. Texture mới cải thiện bề mặt nhưng không tạo chiều sâu hình học.
- `street_prototype.gd` mới thay ba mặt tiền; kết cấu vẫn đơn giản dù đã có đồ vật quét.
- `real_city.gd` quản lý địa điểm, lưới đi bộ, nhà giao hàng và các vùng nhiệm vụ.
- `walk_grid.gd` dùng ô đi bộ 1 m. Hẻm và cửa mới phải thiết kế cùng collision/lưới này.
- Đã có vật liệu tường, tôn, nền và nhiều đồ vật Poly Haven trong `assets/ph`;
  đã có người có texture và rig. Chưa có bộ kiến trúc phố và cây tả thực đồng bộ.
- Lượt trước đã chỉnh vật liệu/ánh sáng toàn map và ba mặt tiền. Chưa thay toàn bộ
  hình dáng nhà, cấu trúc phố hay animation nhân vật.

## Hướng thiết kế

Nhà phải đọc được ở góc chơi thực tế: độ dày tường, cửa có khoảng lùi, bậc thềm,
cửa cuốn, mái hiên, ban công, cột và ống kỹ thuật có hình học riêng. Sơn cũ, bụi và
ẩm đi theo vị trí có lý do; không phủ cùng một vết bẩn lên mọi bề mặt.

Mỗi cụm phố có một hoạt động chính và một dấu hiệu nhận biết: bàn ăn/quầy cơm,
xe đang sửa, sân giặt phơi, sạp hàng, điểm chờ xe. Bố trí khoảng trống cho người
đi lại, thay đổi độ lùi và chiều cao giữa các căn, xen hẻm/sân để phá dãy nhà lặp.
Không cần dựng toàn bộ nội thất của mọi căn; chỉ làm phần nhìn thấy và phần phục vụ
gameplay. Các nhà xa vẫn có thể dùng phiên bản đơn giản.

Nguồn quan sát: [trailer chính thức](https://www.youtube.com/watch?v=kfPlDlSvcGQ),
đặc biệt 0:17, 0:24, 1:14, 1:39. Những nhận xét ở đây dựa trên cảnh nhìn thấy;
không suy đoán công cụ hay kỹ thuật nội bộ của nhà phát triển.

## Các giai đoạn theo thứ tự

| Giai đoạn | Công việc và sản phẩm | Điều kiện chuyển tiếp |
|---|---|---|
| 0. Chốt chuẩn hình ảnh và đo hiện trạng | Chụp cùng tọa độ/góc máy/giờ của 3 cửa, 1 góc phố, 1 hẻm và toàn cảnh; đo FPS, thời gian khung hình và tải map. Lập bảng asset có sẵn/cần làm. | Có bộ ảnh đối chiếu, thông số máy và danh sách thiếu; xác định được vì sao từng mẫu nhà chưa đạt. |
| 1. Làm bộ kiến trúc | Tạo bộ module GLB/scene có UV, vật liệu, tỷ lệ và điểm ghép nhất quán. Làm 3 mẫu nhà hoàn chỉnh trước. | Tắt biển tên vẫn phân biệt được quán cơm, tiệm sửa xe, cửa hẻm trọ; cửa/hiên/ban công có chiều sâu thật từ ít nhất 2 góc nhìn. |
| 2. Dựng đoạn phố đạt chất lượng mục tiêu | Dựng khoảng 50–70 m gồm 3 địa điểm chính, 4–6 căn phụ, một hẻm/sân và góc chuyển hướng. Bổ sung hoạt động NPC có mục đích. | Đi hết vòng trọ → ăn → sửa xe → về trọ; không kẹt, không xuyên tường, không bị nhà che mất người/cửa; ảnh ngày và đêm cùng đạt chuẩn. |
| 3. Đưa kiến trúc mới vào hệ thống map | Tách phần hình ảnh của nhà khỏi dữ liệu địa điểm/đường đi. Cho từng lô chọn mẫu, biến thể, cửa, vùng va chạm và phần bị cắt khi che camera. | Chuyển qua lại map cũ/mới để so sánh; dữ liệu nhiệm vụ và save vẫn dùng được. Mái/tầng bị hạ không kéo méo model hoặc để đồ treo lơ lửng. |
| 4. Thay dần toàn map | Nâng cấp theo cụm sinh hoạt, rồi các tuyến nối cụm; ghi danh sách lô/địa điểm đã thay. Thay cây dễ thấy và giảm nhà nền lặp. | Tất cả địa điểm trong story và các tuyến chính đã được rà; không chỉ 3 căn mẫu đẹp còn phần lớn tuyến chơi giữ khối cũ. |
| 5. Đồng bộ nhân vật và hoàn thiện | Rà tỷ lệ người/cửa/xe, chất liệu da/quần áo, bước chân, tư thế đứng/ngồi/làm việc; tối ưu LOD, vật liệu, ánh sáng và kiểm thử hồi quy. | Nhân vật không trượt chân hoặc xuyên ghế ở các hoạt động mới; các tuyến nghề, giao hàng, ngày/đêm/mưa và save qua mốc truyện vẫn chạy. |

## Bộ asset cần chuẩn bị

Làm hình học trong công cụ dựng model hoặc dùng bộ model phù hợp đã kiểm nguồn gốc;
không tiếp tục giải quyết kiến trúc chính bằng cách chồng thêm hộp rồi dán ảnh.

| Nhóm | Đợt đầu cần có | Cách kiểm |
|---|---|---|
| Kết cấu | Module tường thẳng/góc, tường có cửa, tầng trên và cạnh hồi; khoảng 8–12 module nền | Đơn vị mét, pivot/điểm ghép thống nhất; ghép không hở và không trùng mặt |
| Mặt tiền | 3 mẫu chính: quán cơm, tiệm sửa xe, nhà trọ; sau đó mở rộng 6 kiểu gồm chợ, tiện ích và nhà dân | Ít nhất 2 biến thể mỗi kiểu qua bố cục/hình dáng, không chỉ đổi màu |
| Chi tiết | Cửa cuốn, cửa sắt, cửa kính, mái hiên, ban công, lan can, bậc thềm, đường ống | Đọc được ở camera chơi; tránh chi tiết quá nhỏ nhưng tốn nhiều lượt vẽ |
| Vật liệu | Vữa sơn, gạch, bê tông, tôn, sắt sơn, kính, gỗ | UV/độ lớn vân nhất quán; roughness/normal đúng; không kéo giãn hoặc bóng như nhựa |
| Môi trường | Một cây phố và một cây/chậu nhỏ phù hợp, nền có rãnh/miệng cống, đồ bám tường | Hình bóng cây tự nhiên, tán không che điểm tương tác; có phiên bản xa |
| Sinh hoạt | Ăn/ngồi chờ, sửa đồ, giặt/phơi hoặc trò chuyện; tái dùng props hiện có | Tư thế, tay và vị trí tiếp xúc phù hợp; không đặt người diễn hoạt ở giữa lối đi |

Mỗi asset cần ghi: nguồn/license, người tạo, tỷ lệ, số vật liệu, collision, LOD,
trạng thái đã kiểm trong renderer của game. Nếu cần asset trả phí, lập danh sách
và giá cụ thể trước khi quyết định mua; không coi ảnh concept là model đã sẵn sàng.

## Thay toàn map và giữ gameplay

Thứ tự phủ map: cụm trọ → cụm ăn uống/sửa xe → chợ/bốc vác → dịch vụ/giải trí →
bến xe và tuyến nối → nhà nền/ven sông. Giữ landmark và dấu hiệu định hướng riêng
cho từng cụm; không ép mọi đường thành một dãy mặt tiền giống nhau.

Giữ khóa địa điểm (`com_hanh`, `tiem_sau`, `xom_bo_me`, ...), khóa nhiệm vụ và nhân vật.
Khi cần di chuyển cửa hoặc thu ngắn đường, cập nhật đồng thời vị trí NPC, điểm click,
collision, đường đi, địa chỉ giao hàng, vùng tìm đồ và thời gian di chuyển trong game.
Mọi thay đổi quãng đường phải được kiểm với hạn giờ nhiệm vụ; map gọn hơn không được
vô tình làm hỏng cân bằng một ngày chơi. Không lưu chỉ số lô nhà dễ đổi làm định danh mới.

Với module mới, tách tầng/mái/đồ gắn tầng thành nhóm có thể ẩn. Cơ chế hạ nguyên
khối hiện tại phù hợp nhà nền nhưng không nên áp trực tiếp lên mesh chi tiết.
Hẻm có thể đi vào cần lưới đi bộ và vật cản thật; một cửa tối có chiều sâu thị giác
không được tính là hẻm chơi được.

## Phần mã dự kiến liên quan

| Khu vực | Trách nhiệm dự kiến |
|---|---|
| `assets/architecture/`, `scenes/architecture/` (mới) | Bộ module, mẫu nhà, vật liệu và LOD |
| `data/architecture.json` (mới) | Khai báo mẫu/biến thể/điểm cửa/collision/cutaway |
| `scripts/world/street_prototype.gd` | Bản thử tham chiếu, chuyển dần sang scene/module hoàn chỉnh |
| `scripts/realmap/area_builder.gd` | Giữ đường/nền/nhà xa; tích hợp hình ảnh nhà mới theo từng lô |
| `scripts/world/real_city.gd`, `scripts/realmap/walk_grid.gd` | Điểm đến, footprint, lưới đi bộ và địa chỉ ổn định |
| `data/maps/hn_pho_co_story.json`, `tools/gen_phocu_map.py` | Bố cục và nguồn sinh dữ liệu nhất quán; sinh lại map không mất các chỉnh tay |
| `scripts/world/world.gd`, `street_life.gd`, `crowd.gd` | Hiển thị, che khuất, NPC theo sinh hoạt và giờ |
| `tests/` | Route/collision/địa điểm/save, ảnh cùng góc máy và ghi hiệu năng |

## Kiểm tra hoàn thành

1. Ảnh so sánh trước/sau dùng cùng giờ, ánh sáng, vị trí, độ zoom và độ phân giải;
   có ảnh nguyên game với HUD, không chỉ một góc chụp đẹp đã giấu vật cản.
2. Rà cả khi đi sát cửa, đứng trong hẻm, đi qua góc phố và zoom toàn cảnh.
3. Kiểm click cửa/NPC và phím E; mọi nơi có đường đi thực tế tới vùng tương tác.
4. Chạy ngày làm việc mẫu gồm ăn, đi làm, giao hàng, về trọ; kiểm thêm mưa/đêm
   và save của các chương vì nhiều địa điểm được dùng lại.
5. Đo trên cùng máy/độ phân giải. Mục tiêu thử ban đầu là 60 FPS ở 1366×800 trên
   GTX 1650 đã dùng kiểm trước đây, đồng thời ghi 1% low, RAM/VRAM và thời gian tải.
   Đây là mục tiêu cần đo, không phải hiệu năng hiện tại đã được chứng minh.
6. Không có lỗi script/shader, texture thiếu; mở lại project và sinh lại dữ liệu
   vẫn giữ được kiến trúc mới. Bản web được kiểm riêng, không suy từ PC.

## Chia việc và mốc triển khai đầu tiên

Có thể dùng bốn luồng: kiến trúc/asset; bố cục/đường đi; nhân vật/sinh hoạt;
tích hợp/QA. Phân quyền theo file, chốt kích thước/điểm cửa trước khi làm song song.
Một đầu mối tích hợp, đo và rà ảnh; agent không thay thế việc kiểm model bằng mắt.

Đợt triển khai đầu tiên chỉ hoàn thành giai đoạn 0–2: bộ kiến trúc thật + đoạn phố
50–70 m chơi được. Chưa nhân rộng toàn map khi mẫu còn cảm giác khối hộp.
Đầu ra cần có là cảnh chạy được, ảnh đối chiếu, danh sách asset, kết quả route và
đo hiệu năng. Dựa trên số module cần bổ sung và thời gian làm một căn đạt chuẩn,
mới ước lượng lịch thay toàn map; hiện chưa đủ dữ liệu để hứa số ngày chính xác.
