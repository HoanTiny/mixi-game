# Trước mùa mưa

Game mô phỏng đời sống lấy cảm hứng từ *Nobody: The Turnaround*, bối cảnh phường An Hòa của thành phố hư cấu Bình Giang. An, 27 tuổi, vừa mất việc ở tiệm điện máy. Cả nhà có 30 ngày để dọn khỏi xóm trọ Bờ Me và tìm chỗ ở mới; chơi tiếp 30 ngày nữa ở chỗ mới khi mùa mưa tới và má An về nhà sau mười sáu năm. Thiết kế đầy đủ nằm trong [docs/](docs/README.md).

Làm bằng **Godot 4.7**. Phố dựng bằng nhà ống kiểu Sài Gòn tạo tự động (`scripts/world/tube_house.gd`): ban công lan can sắt, mái hiên tôn, biển hiệu, đồ phơi, bồn nước inox. Người, xe máy, ô tô, xe đẩy, ghe, cây dựng bằng code thành lưới 3D bo tròn (`scripts/world/character.gd`, `scripts/world/props3d.gd`); có file mô hình thật trong `assets/` thì dùng file đó (xem mục *Thêm mô hình thật*).

**Trạng thái:** chơi được **đủ 30 ngày** và **8 kết thúc**: ba tuyến nghề chọn ở ngày 11, tiền mặt tách khỏi tiền phải thu và phải trả, hợp đồng Bến Cạn, chỗ ở (xem, cọc, chốt ngày 26), mưa ngày 15 và 29 (rạch dâng, chỗ trũng ngập, lội nước tốn giờ), chỉ số Mệt, sổ lời hứa, sổ gia đình, quyền tự quyết của Linh. Lát cắt ngày 18–22 vẫn giữ ở màn đầu để thử nhanh một tuyến.

**Chương 2 · Mùa mưa (ngày 31–60):** màn kết ngày 30 có nút **Chơi tiếp**; chỗ ở, tuyến nghề, tiền, độ thân thiết, Linh đi xa hay gần và mọi lựa chọn đi tiếp. Ba nhân vật mới: **má** (cô Hậu) về nhà sau mười sáu năm chỉ về ngày Tết, **ông Ba Lành** hàng xóm sát vách xưa chèo đò ngang, **Kha** thợ sửa điện thoại năm sao trên ứng dụng. Các mạch: đôi mắt của bà (khám, ai quyết lịch mổ, ngày mổ, nhỏ thuốc, tái khám), mùa mưa (mưa ngày 35, 41, 45, 52, 57, đêm triều cường ngày 45, bao cát, sửa máy bơm giá thường hay giá mưa), bí mật cái mỏ lết khắc tên và xấp biên lai gửi "Lê Văn Sáu", má mất việc mà giấu, Linh và cuốn sổ bảo trì, con trai ông Ba tới đón ông, sạp chung với Kha, giỗ ông ngoại tối ngày 60. Gồm 38 cảnh chính và 4 sự kiện tự bật với 133 lựa chọn (nhiều cảnh đổi lời theo chỗ ở, tuyến, lựa chọn cũ), 20 việc mới (ứng dụng Thợ Tới, tổ trưởng ca chiều ở kho, đi lại điện chợ với tổ Trâm, đơn sửa sau mưa, ngồi bàn chú Sáu thứ Bảy, nghe radio và đánh cờ với ông Ba, ăn cơm má nấu, nhỏ thuốc mắt cho bà…), 5 việc nhờ, 32 đoạn thoại và 36 câu chuyện phiếm, **6 kết thúc** K1–K6 và thẻ hậu truyện của má, bà, Linh. Chương 1 có gieo sẵn manh mối: bà nhờ đọc tờ thông báo vì chữ in nhỏ, cái mỏ lết là món duy nhất trong thùng đồ nghề có khắc tên, xấp biên lai kẹp riêng dưới đáy hộp thiếc. Thử nhanh chương 2: thêm `?ch2` vào địa chỉ bản web (máy tự chơi xong chương 1 rồi mở sáng ngày 31, không ghi đè bản lưu thật).

**Chỗ ở trên phố:** Phòng Hẻm Dừa trong hẻm cụt rẽ ra từ đường Chợ, Phòng Cầu Tre bên kia rạch (qua cây cầu tre sau Bến Cạn), nhà dì Năm ở đầu đường An Hòa gần trạm xe. Tới tận nơi để xem phòng hay dắt bà đi thử bậc cửa (đi càng xa càng tốn giờ). Ngày 30, cảnh khép lại diễn ra trước chỗ ở đã chọn: bà Tư, chậu húng dưới mái hiên, Linh có mặt nếu em không đi thực tập xa.

**Map của truyện là khu thật Quận 8, ven kênh Tàu Hủ** (`"map": "q8_tau_hu"` trong `data/config.json`): đường, hẻm, kênh, cầu, nhà lấy từ OpenStreetMap và Open Buildings, nướng sẵn vào `data/maps/q8_tau_hu.json` (4.400 nhà, 415 đoạn đường) nên người chơi không cần mạng. Truyện giữ tên hư cấu: con kênh là rạch Bờ Me, cầu chữ Y là Cầu Nhỏ, đường Phạm Thế Hiển là đường Bờ Me… (bảng `names` trong `data/maps/q8_tau_hu_story.json`). File đặt truyện ghi chỗ của từng địa điểm (game tự tìm đường gần nhất làm mặt tiền, quay cửa ra đường, dọn nhà thật ở lô đó), lời tả địa điểm theo địa hình thật, vùng tìm mèo, tuyến người bán rong, giờ đi bộ mỗi mét. Nhà có số để giao hàng, thùng rác, đèn đường, chỗ ngập ngày mưa (đường sát kênh ngập ngày 15, lan vào trong ngày 29), xe máy và người đi bộ đều tính theo đường thật. Dọc kênh có bờ kè đá, ghe xuồng neo sát bờ và vài chiếc ghe chở hàng trôi qua lại. Bản đồ lớn (phím M) có chấm cho từng nhân vật đang ở đâu, rê chuột tới để xem tên. Khi An đi tới đâu, mặt đường hiện vệt chấm vàng chỉ lối (chấm đi qua rồi thì tắt) và bản đồ vẽ nét vàng đường đang đi; rê chuột lên một địa điểm trên bản đồ lớn thì thấy đường đi tới đó, số mét và số phút đi bộ.

Đường đi bám theo phố, hẻm, vỉa hè, công viên; khe hở giữa các dãy nhà và bãi đất trống vẫn đi được (phím WASD) nhưng tìm đường tính đắt gấp 6 lần nên chỉ chui khe khi không còn lối nào. Nhà nào che An thì hạ nguyên căn xuống thành khối thấp có mặt cắt màu vữa (dải ngay trước mặt An hạ còn chân tường, hai bên hạ ít hơn cho thấy mặt phố), hạ và nâng từ từ; nhà đứng ngang An như chính tiệm An đang đứng trước cửa thì để nguyên; cây chắn trước mặt thì thu tán lại. Quanh các địa điểm có đồ phố Việt: mái hiên tôn, bạt, biển hiệu có chữ (tạp hóa, phở, cơm tấm, sửa xe…), bàn ghế nhựa quán cóc, cột điện bê tông và dây điện võng, dây giăng ngang hẻm, cổng hẻm "khu phố văn hóa", bảng tên đường xanh, xe máy dựng vào lề. Đi qua cầu thì An đứng trên mặt cầu.

**Phố kiểu mô hình sa bàn** (giống các mô hình "khu phố mùa hạ"): nhà sơn trắng, kem, xanh bạc hà, xanh lá non, vàng, cam đào; cửa sổ nhỏ có khung xanh ngọc, trắng, nâu; tầng trên có ban công lan can song sắt, hoa giấy hồng rủ qua lan can, cục nóng máy lạnh; có nhà lợp mái ngói đỏ cam ở đỉnh mặt tiền. Sân thượng có tường lan can, bồn nước nhựa đen và inox, tum cầu thang lợp ngói, giàn hoa giấy, chậu cây. Đường có vỉa hè lát gạch đỏ, vạch vàng giữa đường, vạch trắng mép đường, vạch chia làn; ngã tư đường lớn có vạch qua đường kẻ sọc và đèn giao thông; sân, hẻm láng xi măng chia ô; cây phượng đỏ xen cây xanh. Gần 500 xe máy (tay ga, xe số, nhiều xe chở thêm người ngồi sau; mỗi người một màu áo, mũ cùng màu xe) và ô tô chạy hai chiều theo làn bên phải, quanh chỗ của truyện đông nhất; ngày mưa vắng bớt một nửa. Nút **Toàn cảnh** ở thanh dưới (hay con lăn chuột) lùi máy quay ra xa ngắm cả khu như mô hình; lúc đó nhà không hạ. Ban công, hoa, đồ trên sân thượng nằm trong lưới chi tiết chia ô 100 m, nhìn xa quá 170 m thì khỏi vẽ; nhà chia ô 200 m; xe chạy gom theo cụm tuyến, cụm xa An thì khỏi cập nhật hình.

**Người và đồ vật 3D:** mỗi người là một lưới liền bo tròn gắn khung xương, cử động mềm ở vai, khuỷu, hông, gối: dáng nam, nữ; mặt có mắt, mày, mũi, miệng, tai; tóc ngắn, dài, búi, đuôi ngựa; nón lá, nón kết, mũ bảo hiểm, ba lô, tạp dề; đi, đứng thở, ngồi xe, đẩy xe, gánh hàng. Xe máy tay ga và xe số chạy ngoài đường có người lái đội mũ bảo hiểm, nhiều chiếc chở thêm người ngồi sau (map thật: dòng xe gộp thành MultiMesh, xem `scripts/world/traffic.gd`). Người bán rong: xe bánh mì có tủ kính bày ổ bánh mì, xe chè với hai tầng hũ chè, xe hủ tiếu gõ có nồi nước lèo, xe ve chai chất các-tông và bao tải, chị bán xôi gánh hai thúng trên vai. Trên kênh: ghe chở hàng có mui bạt, mắt ghe, máy đuôi tôm, bao hàng; xuồng có mái chèo. Trên phố: ghế đẩu, bàn nhựa quán cóc, cột điện bê tông tròn có sứ cách điện và bình biến áp, ô tô, xe máy đậu dọc lề, cây tán lồi lõm, cây dừa đầu Hẻm Dừa. Mỗi món dựng một lần rồi dùng chung, màu sơn từng chiếc là tham số; cây, xe đậu chia theo ô 200 m nên chỉ vẽ phần đang thấy.

Nướng thêm khu khác: `Godot --headless --path . -s res://tools/bake_map.gd -- --id=<tên> --bbox=nam,tây,bắc,đông [--osm=<file overpass.json>]`, rồi viết `data/maps/<tên>_story.json` và đổi `"map"` trong config. Đặt `"map": "an_hoa"` (hay chạy với `-- --map=an_hoa`) để chơi lại phường vẽ tay bên dưới.

**Phường An Hòa vẽ tay** (`data/map.json`, dựng bởi `scripts/world/city_map.gd`): không còn là một con phố thẳng mà là một khu ven kênh kiểu Sài Gòn, bố cục dựa theo các xóm hẻm và rạch thật ở TP.HCM:
- **Đường An Hòa** (đường lớn, hai chiều, có trạm xe số 6 và cổng khu công nghiệp ở đầu đường), **đường Chợ Cầu Nhỏ** chạy xuống tới chân cầu (kiểu chợ đầu cầu), **đường Bờ Me** ven rạch có lan can, hàng cây và đèn.
- **Hẻm 42** (cổng "Khu phố 3"), **Hẻm 88** (cổng "Khu phố 4", hẻm ba gác hẹp hơn), hẻm nhánh **42/7** nối ngang hai hẻm, **Hẻm Dừa** là hẻm cụt rẽ từ đường Chợ, đầu hẻm có cây dừa. Dây điện chằng chịt trên hẻm.
- **Rạch Bờ Me** uốn nhẹ, có bờ kè, ghe xuồng; **Cầu Nhỏ** (cầu bê tông) và **Cầu Tre** (cầu ván) bắc sang **Hẻm Bờ Nam**, nhà sàn chân cột quay lưng ra rạch, phía sau là ruộng rau muống.
- Số nhà đánh như thật: số lẻ một bên, chẵn một bên; nhà trong hẻm mang số có gạch chéo theo căn ở đầu hẻm (42/3, 42/7/5…), app Giao Nhanh giao tới đúng các địa chỉ này.
- An đi theo đường thật (tìm đường A* trên lưới 1 m, không xuyên nhà), nhà che khuất An thì tự ẩn. Bản đồ nhỏ góc trên; phím **M** hoặc bấm bản đồ nhỏ mở **bản đồ lớn** có tên đường, bấm chỗ nào thì An đi tới đó.

**Dựng một khu thật ở Việt Nam** (chế độ riêng, ngoài truyện; nút ở màn đầu, hay thêm `?khu` vào địa chỉ bản web). Giao diện kiểu Tiny Map:
- Bên trái là bản đồ nền tối vẽ từ OSM (kéo để dời, con lăn hay +/− để phóng): ô tìm địa điểm (Nominatim), công cụ vẽ khung chữ nhật hay đa giác, nút xóa; vùng vẽ ghi diện tích, tối đa 1,2 km². Nút **Ví dụ Khương Thượng** dựng sẵn một khu.
- Bấm **Dựng mô hình 3D**: thẻ tiến độ bốn bước (OpenStreetMap, Open Buildings, Ghép dữ liệu, Dựng mô hình), hai nguồn đầu tải cùng lúc.
- Bên phải là mô hình thu nhỏ của đúng vùng đã vẽ trên tấm đế đất: kéo chuột trái để xoay, nghiêng; chuột phải (hay Shift) để dời; con lăn để phóng; la bàn ghi hướng và độ nghiêng; nút quay về hướng bắc, tải mô hình về (.glb), toàn màn hình; **Thả An vào đi dạo** để đi bộ trong khu. Vạch giữa hai nửa kéo được.

Trình duyệt tự gọi thẳng ba nguồn miễn phí, không qua máy chủ nào khác:

| Nguồn | Lấy gì |
|---|---|
| OpenStreetMap qua Overpass API | Nhà vẽ tay (số tầng, chiều cao, màu tường, kiểu và màu mái nếu có), đường, sông, hồ, kênh, công viên, cây, đình chùa, di tích, điểm tham quan, tường rào, đường sắt. Hỏi `overpass-api.de` trước; sau 7 giây chưa trả lời (hay báo lỗi) thì hỏi thêm `overpass.private.coffee` và `maps.mail.ru`, máy nào trả trước thì dùng. |
| Open Buildings (Google + Microsoft, bản gộp của VIDA) | Đường viền nhà dò từ ảnh vệ tinh, kèm độ tin cậy: `data.source.coop/vida/google-microsoft-open-buildings/flatgeobuf/by_country/country_iso=VNM/VNM.fgb` (17,5 GB, 68,5 triệu nhà). App chỉ đọc đúng phần byte của vùng đã vẽ qua chỉ mục không gian (khoảng 0,5–1,5 MB cho một khu nửa km²). |
| Nominatim | Tên khu ra tọa độ, khung và mã nước (để biết đọc file Open Buildings nào). |

Ghép nhà: nhà OSM được ưu tiên; nhà Open Buildings bị bỏ nếu độ tin cậy dưới 0,7, trùng chỗ nhà OSM, nằm trên lòng đường hoặc trên mặt nước. Nhà không ghi số tầng lấy 2–5 tầng như nhà ống, một phần nhà thấp lợp ngói đỏ; cao ốc kính; mặt tường có cửa sổ theo tầng (mờ dần khi nhìn xa); sân thượng có bồn nước inox; mái ngói đỏ cam có hàng ngói; chùa, đình mái bốn dốc; vỉa hè lát gạch, vạch kẻ đường, sân láng xi măng; cây ven đường xen cây phượng, ô tô và xe máy đậu dọc đường; nhãn địa danh có chấm cam. Màu nhà, màu mặt đất ghi bằng mã màu sRGB như trong bảng màu. Địa chỉ máy chủ, giờ chờ, ngưỡng tin cậy, bề rộng đường, màu nhà nằm trong `data/realmap.json`. Bản cài trên máy đi qua proxy được (đọc `HTTPS_PROXY`, chứng chỉ gốc ở `SSL_CERT_FILE`).

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
| Con lăn chuột, nút **Toàn cảnh** | Kéo máy quay gần, xa; xa hẳn là nhìn toàn cảnh khu phố |
| Esc | Đóng bảng |
| Nút **Về xóm trọ** | Đi về Bờ Me. Chỉ ngủ được ở đó; 22 giờ chưa về thì ngủ gục ngoài đường, Mệt +15. |

**Thời gian:** đi bộ trên phố tốn giờ (chỉnh bằng `walkHoursPerMeter`). Làm việc thì An vào trong, thanh thời gian chạy (`workSecondsPerHour` giây thật cho mỗi giờ trong game) rồi mới tính kết quả. Làm việc kéo qua 20 giờ thì Mệt tăng thêm. Vào **Xóm trọ Bờ Me** để **Đi ngủ**.

**Tiền và Mệt:** góc phải hiện tiền mặt tiêu được, tách riêng khỏi tiền phải thu (trước và sau ngày 30) và khoản phải trả. Mỗi tối trừ tiền sinh hoạt của cả nhà (`livingCostPerDay`, chưa gồm cơm của An). Mệt từ 70 trở lên là mức cảnh báo; nghỉ ở phòng, ăn cơm với bà, ngồi trà đá giúp giảm Mệt. Nút **Sổ** mở các khoản phải thu, phải trả, sổ lời hứa, sổ gia đình, độ thân thiết và đồ đang mang.

**Nhu cầu cơ thể và Phong độ (kiểu Nobody):** No bụng, Vệ sinh, Quần áo tự giảm theo giờ; việc bẩn (ca kho, rửa bát, lục rác) làm bẩn người và đồ. Cùng độ tỉnh táo (100 − Mệt), chúng gộp thành **Phong độ**: từ 55 trở lên đủ lương, 30–55 chỉ được 70%, dưới 30 chỉ 50% và đi chậm. Nhịn đói tới 0 thì Mệt tăng nhanh. Ăn ở Cơm Hạnh, bánh mì ở chợ Cầu Nhỏ buổi sáng; tắm và giặt đồ ở xóm trọ. Số liệu trong `needs` của `data/config.json`.

**Trò chơi nhỏ khi đi làm (kiểu Nobody):** ca kho ở khu công nghiệp (đi từ bến xe số 6) là xếp đúng loại hàng (thùng mì, lốc nước, bao gạo) lên pallet trong 60 giây; bỏ nhầm loại phải dỡ ra. Ca phụ quán Cơm Hạnh là rửa bát: bấm từng vết bẩn để kỳ cọ (vết to chà hai lần), sạch thì xếp lên giá (phím cách), xếp bát còn bẩn bị trả lại. Đủ chỉ tiêu thì đủ công, thiếu thì tính theo tỉ lệ (thấp nhất 50%), làm khéo được thưởng. Từ lần thứ hai có thể **làm tự động**, lặp lại kết quả lần tự làm gần nhất. Thông số và chữ trên màn trong `minigames` của `data/config.json`.

**Ve chai:** thùng rác dọc vỉa hè, đứng gần bấm **E** để lục (mỗi thùng một lần mỗi ngày): được chai nhựa, lon, bìa giấy nhưng bẩn người. Mang ra sạp của cô Út ở **chợ Cầu Nhỏ** để bán.

**Giao đồ (kiểu Nobody):** bấm **Điện thoại** ở thanh dưới, bật *App Giao Nhanh*. Đơn hiện lên (lấy ở Cơm Hạnh, chợ hay tiệm Sáu, giao tới nhà số mấy, tiền công, hạn giờ), nhận thì tự đi lấy rồi tìm đúng nhà để giao: mũi tên cam chỉ chỗ lấy, xanh chỉ nhà khách. Giao sớm có tip, trễ bị trừ tiền và thêm Mệt. Số liệu trong `delivery` của `data/config.json`.

**Nói chuyện:** người đứng trước cửa (bà Tư, Linh, cô Duyên ở xóm trọ; chị Hạnh, Minh ở Cơm Hạnh; chú Sáu; anh Phúc, Trâm ở Bến Cạn) có nút **Nói chuyện**. Mỗi người có việc riêng theo giờ (`data/schedules.json`) và đi bộ thật trên đường: bà Tư đi chợ sáng, Linh ra bến xe đi học (thứ Hai tới thứ Sáu), Minh chở cơm xuống Bến Cạn, chú Sáu ra chợ trưa, cô Duyên mua cơm tối… Người đang ở đâu thì nói chuyện ở đó; chỗ quen ghi "đi đâu, khoảng mấy giờ về". Người bán rong (bánh mì, xôi buổi sáng, ve chai ban ngày, chè, hủ tiếu gõ buổi tối) đẩy xe vòng qua các hẻm, tiếng rao phát ra từ chính chiếc xe, ngày mưa thì nghỉ. Nói chuyện tốn 30 phút, mỗi người một lần mỗi ngày. Mạch chuyện mở dần theo ngày và độ thân thiết, có lựa chọn ghi vào sổ gia đình. Viết trong `data/talks.json`.

**Việc nhờ (kiểu Nobody):** người trong phố nhờ những việc nhiều bước, có hạn giờ và có lựa chọn. Chỗ có người nhờ hiện dấu **!** vàng; nhận việc thì bảng mục tiêu hiện bước đang làm, dấu **◆** xanh chỉ chỗ cần tới. Lát cắt có 7 việc: sửa quạt của cô bán trái cây (đọc triệu chứng, chọn đúng bệnh, trả trước 18:00), rửa bát đủ chỉ tiêu rồi chở 20 suất cơm xuống Bến Cạn trước khi nguội, gom lon nhôm cho cô Út, tìm mèo của bé Bắp, chậu mới cho cây húng của bà Tư (để bà tự chọn hay chọn thay), in hồ sơ thực tập cho Linh (in đúng bản em gửi hay tự ý sửa), đo lại trước nghiệm thu với Trâm (tuyến B, C). Quá hạn là hỏng việc; làm xong được tiền, thân thiết hoặc ưu đãi (cơm giá quen, ve chai được giá). Viết trong `data/quests.json`.

Ván chơi tự lưu sau mỗi thao tác vào `user://save.json`. Nút **Chơi lại** trong Bảng cân bằng xóa ván đang chơi.

## Cấu trúc thư mục

```
data/
  realmap.json    chế độ Dựng khu thật: địa chỉ các nguồn, giờ chờ, luật lọc nhà, bề rộng đường, màu nhà
  schedules.json  việc riêng theo giờ của 8 nhân vật, tuyến của người bán rong
  maps/           khu thật nướng sẵn (q8_tau_hu.json) và file đặt truyện (q8_tau_hu_story.json)
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
  bake_map.gd     nướng một khu thật thành map của truyện (OSM + Open Buildings, cắt theo khung)
scripts/
  game_logic.gd   toàn bộ luật chơi, không phụ thuộc giao diện
  game_state.gd   autoload GameState: giữ ván chơi, tự lưu
  world/world.gd  phố 3D: địa điểm, nhân vật, rạch và cầu, thùng rác, xe máy, người đi đường, ánh sáng theo giờ
  world/models.gd nạp mô hình, co giãn cho vừa chỗ, phát hoạt cảnh
  world/surfaces.gd    vật liệu texture chiếu theo tọa độ thế giới
  world/audio.gd  âm thanh theo giờ, mưa, tiếng rao có chữ nổi
  world/character.gd   nhân vật 3D liền khối có khung xương: An, 8 nhân vật, người đi đường; đi, đứng, ngồi xe, đẩy xe, gánh
  world/props3d.gd     đồ vật 3D dựng bằng code: xe máy, ô tô, ghế bàn nhựa, xe đẩy bán rong, gánh hàng, ghe, cây, cây dừa
  world/tube_house.gd  dựng nhà ống: mỗi căn một lưới, ngẫu nhiên màu sơn, ban công, biển hiệu
  realmap/realmap.gd     chế độ Dựng khu thật: giao diện hai nửa, tiến độ, camera xoay nghiêng, tải .glb, đi dạo
  realmap/fetcher.gd     gọi Nominatim, Overpass (nhiều máy, chờ 7 s), đọc file theo byte (Range)
  realmap/fgb_reader.gd  đọc FlatGeobuf từ xa theo chỉ mục không gian (Open Buildings)
  realmap/area_data.gd   đọc dữ liệu OSM, ghép và lọc nhà Open Buildings
  realmap/area_builder.gd dựng 3D: nhà, mái, đường, sông hồ, công viên, tường rào, nhãn tên, lưới đi bộ; hạ nhà che An
  realmap/street_dress.gd đồ phố Việt: mái hiên, biển hiệu, ban công hoa giấy, cục nóng, mái ngói mặt tiền, sân thượng (bồn nước, tum, giàn hoa, chậu cây), cột điện, dây điện, cổng hẻm, bảng tên đường, vạch qua đường, đèn giao thông, ghế quán cóc
  realmap/walk_grid.gd   lưới đi bộ 1 m và tìm đường cho khu thật (đường, hẻm rẻ; khe nhà, bãi trống đắt)
  realmap/map_view.gd    bản đồ nền tối: kéo, phóng, tìm, vẽ khung hay đa giác
  world/real_city.gd   map của truyện từ khu thật nướng sẵn: đặt địa điểm, đổi tên đường, nhà có số, thùng rác, chỗ ngập
  world/street_life.gd nhân vật đi việc riêng theo giờ, người bán rong đẩy xe qua hẻm (data/schedules.json)
  world/traffic.gd     dòng xe máy có người lái và ô tô chạy theo làn trên đường thật (MultiMesh theo cụm tuyến)
  world/rain_layer.gd  cảnh ngày mưa: rạch tràn bờ, chỗ ngập, vũng nước, gợn nước, thùng đồ trước xóm trọ theo việc chuẩn bị
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
  realmap_test.gd thử chế độ Dựng khu thật với máy chủ giả (realmap_fixtures/: tạo dữ liệu mẫu, máy chủ có Range)
```

## Texture và ánh sáng tả thực

Mặt đường, vỉa hè, tường nhà ống và nắp cống dùng texture Poly Haven (CC0) trong `assets/textures/` (nguồn từng bộ ghi ở `NGUON.txt`), chiếu theo tọa độ thế giới nên dán lên mọi khối không cần UV (`scripts/world/surfaces.gd`). Ảnh HDRI `assets/hdri/pho_chieu.hdr` dùng cho phản chiếu. Nắng chiếu xiên từ phía sau dãy nhà để bóng đổ dài ra vỉa hè, tông màu vàng ấm như Nobody. Thay texture: chép bộ `<tên>_albedo.jpg`, `_normal.jpg`, `_rough.jpg` cùng tên.

Đồ vật trên phố (thùng rác kim loại, túi rác, thùng nhựa, thùng các-tông, chậu cây, ghế đẩu, tủ điện, bao xi măng, giỏ mây, cột đèn) là mô hình Poly Haven (CC0) trong `assets/models/`, khai báo ở mục `props` của `data/models.json`. Mái hiên và mái tôn dán texture tôn gợn sóng.

## Thêm mô hình thật

Game đọc `data/models.json` để biết mỗi thứ trên phố dùng file mô hình nào. Thiếu file nào thì người, xe máy, cây dùng lưới dựng bằng code (`character.gd`, `props3d.gd`), nhà dùng nhà ống tự tạo, nên có thể thêm dần từng cái.

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
| A · Làm công | E1 · 6,03 tr | E6 · 3,37 tr | E8 · 3,60 tr | E4 · 2,18 tr |
| B · Tổ đội | E2 · 3,82 tr | E4 · 0,33 tr | (khóa B, sang A) | E4 · 2,00 tr |
| C · Dịch vụ riêng | E3 · 4,98 tr | E4 · 1,12 tr | E8 · 1,07 tr | E4 · 1,53 tr |

Chơi tiếp chương 2 (ngày 31–60) từ đúng màn kết ở trên; kết chương 2 và tiền mặt tối ngày 60 sau khi đã đóng tiền nhà tháng sau. "Giấu" giấu chuyện và ép người nhà ở các cảnh gia đình; "Ít việc" mỗi ngày chỉ làm một việc ngắn; "Để má chọn" như lắng nghe nhưng không giữ chỗ cho máy may của má:

| Tuyến | Lắng nghe | Giữ tiếp | Áp đặt | Gồng | Giấu | Ít việc | Để má chọn |
|---|---|---|---|---|---|---|---|
| A | K3 · 7,13 tr | K6 · 3,22 tr | K6 · 11,65 tr | K6 · 1,70 tr | K3 · 4,97 tr | K4 · 0 | K2 · 7,13 tr |
| B | K3 · 8,32 tr | K6 · 1,67 tr | K6 · 11,65 tr | K6 · 3,24 tr | K6 · 5,36 tr | K4 · 0 | K2 · 8,32 tr |
| C | K3 · 10,45 tr | K6 · 3,23 tr | K6 · 12,02 tr | K6 · 4,00 tr | K6 · 7,37 tr | K4 · 0 | K2 · 10,45 tr |

Cách chơi không nghỉ (giữ tiếp, áp đặt, gồng) kiệt sức ở mùa mưa (K6) và má đi lặng lẽ; lắng nghe mà chừa chỗ cho máy may thì má ở lại mở sạp (K3), không chừa thì má quay lại nghề ở xa có hẹn gọi về (K2). K1 (má ở lại, mâm giỗ đủ chén) cần bà chưa mổ hay chưa ai hỏi ý má; K5 bị K6 che trong bảng vì các cách chơi giấu chuyện đều làm quá sức.

- Đọc lại một lượt chơi chương 2 (lựa chọn và sổ tay ngày 31–60): `... -s res://tests/sim.gd -- trace C 0` (tuyến, cách chơi 0–6).
- Chơi thử trên màn phố thật (đi bộ, thanh làm việc, ăn uống, nói chuyện, cảnh chính, việc nhờ, về xóm trọ ngủ đều chạy như người chơi bấm), in nhật ký từng ngày. Bỏ `--full` để chơi lát cắt; `--ch2` thay cho `--full` để chơi tiếp chương 2 tới ngày 60, thêm `--fast1` để chương 1 chạy nhanh không đi bộ:

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s res://tests/playtest.gd -- --demo --full --route=B --talk
```

**Chạy thử nhanh** (thêm vào sau lệnh chạy game, không ghi đè bản lưu thật):

- `-- --demo --demo-full`: vào thẳng ngày 1 của bản 30 ngày.
- `-- --demo-ch2`: máy tự chơi xong chương 1, vào thẳng sáng ngày 31 của chương 2 (bản web: `?ch2`).
- `-- --demo --demo-route=C`: vào thẳng ngày 18 của tuyến C.
- Thêm `--demo-open=ben_can`: mở sẵn một địa điểm.
- Thêm `--demo-end`: tự chơi tới hết ngày 22 để xem bảng tổng kết.

## Khi xuất bản game

Godot không tự đóng gói file `.json`. Trong **Project → Export**, thêm `*.json` vào ô *Filters to export non-resource files*.
