## Bản 1.20

Âm thanh phố cổ làm lại: tiếng nền phố ngày, phố tối, loa phường (6–7h), ếch nhái, mưa là bản thu thật ở Hà Nội trên Freesound (CC0, CC BY 4.0; ghi công trong màn Giới thiệu, nguồn ở `assets/sounds/NGUON.md`). Tiếng động tổng hợp lại theo vật thật (dép trên vỉa hè, bước ướt khi mưa, tiền polymer, chuông xe đạp, bát đũa), cân lại độ to, bỏ còi rời. Tiếng rao chưa có bản thu nên chỉ hiện chữ trên đầu người bán. Kiểm bằng `tests/street_sounds.gd`. Web 1.20 giữ gói Windows 1.13.

## Bản 1.19

Làm theo đối chiếu tài liệu Nobody:
- **Kiệt sức:** `exhausted()` tính cả những ngày gục vì Trầm cảm (`burnoutDays`).
- **Màn xám:** `post_fx` gloom theo Tâm trạng và hiệu ứng `shock`, cập nhật mỗi khung.
- **Lịch sự kiện:** thêm trường `until_day`, `requires_flag`; ba cạm bẫy, mạch chú Thìn (`events_and_jobs.json`).
- **Trò cho việc cần bằng:** `weld_bead`, `ledger_check`, `ac_charge`, dạng `attach` gắn vào việc trong `careers.json`.
- **Ba trò giải trí:** `xiangqi`, `karaoke`, `claw`.

Kiểm bằng `tests/hardship.gd`, `tests/cert_minigames.gd`, `tests/leisure_minigames.gd`. Web 1.19 giữ gói Windows 1.13.

## Bản 1.18.1

"Sinh hoạt cả nhà" chương 2–5: 140.000đ → 110.000đ/ngày, má đi 120.000đ → 90.000đ, vì An tự trả từng bữa. `tests/sim.gd -- trace <tuyến> <cách chơi> <chương> why` in thu, chi theo khoản và lý do việc không làm được.

## Bản 1.18

Cân lại kinh tế chương 1 sau lượt người chơi máy chơi đủ 30 ngày:
- Trần lương 28.000đ/giờ chỉ miễn cho việc thưởng nóng của đúng hôm đó.
- Thưởng nóng ×1,5.
- Góp sinh hoạt gia đình 20.000đ mỗi tối.

Sửa giao diện:
- Phông ○ ● ở màn chọn độ khó.
- Tiền mở đầu ở màn chọn truyện.
- Thanh mục tiêu cọc phòng và dự báo ngày 26 khớp nhau.
- Thông báo 06:00 không che HUD và bản đồ.
- Vòng tâm trạng ẩn khi mở hết khung mục tiêu.

Kiểm bằng `tests/hardship.gd`; `tests/playtest.gd` in thêm thu, chi theo khoản. Web 1.18 giữ gói Windows 1.13; `export_presets.cfg` đã đặt 1.18.0.0 cho lần đóng gói Windows sau.

## Bản 1.17

Học nghề buổi tối ở trung tâm nghề cạnh điểm xe buýt Long Biên (lớp hàn điện, kế toán sơ cấp; thi lấy chứng chỉ, lớp điện lạnh chương 5 đổi thành chứng chỉ), ba việc chỉ nhận khi có bằng, cây kỹ năng sáu ô trong bảng Nhân vật (`scripts/systems/careers.gd`). Giữ Shift chạy 4 m/s, chạy được trong ngõ; hết hơi phải nghỉ, thanh hơi trên đầu An (`scripts/world/stamina.gd`). Sửa các test headless cũ; việc cần bằng không bị trần lương chương 1. Kiểm bằng `tests/careers.gd`, `tests/stamina.gd`, `tests/locomotion_pacing.gd`. Web 1.17 giữ gói Windows 1.13.

## Bản 1.16

Bàn giao tuần đầu: các nhánh ngày 5–6 chạy bằng máy trạng thái quest (xem phòng với bà, công khoán phụ quán, chia tuyến giao cơm); lưu game qua tệp tạm và `.bak`. Nướng sẵn hình học các mặt tiền (`assets/architecture/baked/`) để dựng phố nhanh hơn. Chi tiết ở `docs/WEEK_ONE_IMPLEMENTATION.md`, kiểm bằng `tests/story_week_one.gd`. Web 1.16 giữ gói Windows 1.13.

## Bản 1.15

Ca sửa Tiệm Chú Sơn: Q bỏ món cuối, khay hoàn trả, tối đa hai linh kiện; giữ E 2 giây để kiểm tra và 3 giây để lắp, sai linh kiện trừ 5 giây. Khung hành động phố mặc định thu gọn, mở bằng E/chạm, đóng bằng Esc hoặc khi đi tiếp; không liệt kê NPC có anchor trống ở giữa đường. Kiểm tra bằng `tests/repair_work_site.gd` và `tests/prompt_declutter.gd`, bao gồm ảnh 3D. Web 1.15 giữ gói Windows 1.13.

## Bản 1.14

Ghép nền 1.13 (đồ họa, tổng kết ngày, thưởng nóng, scheduler, buôn bán và quan hệ) với Balo, chuyển khu, QTE quán bia và phản hồi Phúc Tân. Ví mở đầu 46.000đ, quỹ cọc khóa 1.400.000đ. Hai nút trả trọ dùng chung `today.rent_paid`; vòng thu tiền đêm giữ Hardship để không thu hai lần. Giá việc làm do 1.13/scheduler công bố được giữ nguyên; QTE bia có bảng thưởng riêng. Kiểm thêm inventory, phuc_tan_economy, phuc_tan_visual, map_zones và service_minigame. Bản web 1.14 giữ gói Windows 1.13 hiện có.

# Triển khai bản web và Windows 1.13

Bản 1.13: đồ họa kiểu Nobody (post_fx.gd, ink.gd, street_grit.gd, mặt đất mới trong area_builder.gd), áp lực sinh tồn
ngày 1 (hardship.json), tổng kết cuối ngày, thông báo 06:00, game juice (juice.gd). Xem docs/NOBODY_STYLE.md. Kiểm
tra thêm `tests/hardship.gd`. Staging dùng phiên bản web/Windows `1.13 1.13`, quy trình như 1.12 bên dưới.

## Quy trình 1.12

Bản 1.12 thêm EventSchedulerSystem: thưởng nóng lúc 06:00, chợ đêm
18:00–23:00 và sự kiện theo ngày/giờ/bốn Zone. Kiểm tra bằng
`tests/event_scheduler.gd`, `tests/event_scheduler_world.gd` và
`tests/relationships_commerce.gd`. Dữ liệu tiền trong events_and_jobs.json
dùng money_unit_vnd=1000. Phát tờ rơi và mascot hiện là ca tự động.

Xuất Windows bằng preset Windows (PCK nhúng trong EXE); đóng gói cùng
licenses và hướng dẫn vào ZIP. Khi staging dùng phiên bản web/Windows
`1.12 1.12`, thay ZIP tải về bằng bản mới và giữ nguyên các PCK cũ.

## Quy trình và lịch sử 1.11

Bản 1.11 ghép asset mới với toàn bộ cập nhật đến 1.10.1. Windows tiếp tục
ở 1.6; giữ nguyên ZIP hiện có trên Pages. Gói web kiểm bằng
`tools/verify_asset_pack.gd`, sau đó thử tải và di chuyển trên trình duyệt.

Nguồn ở nhánh `feature/noi-chuyen`, GitHub Pages ở `gh-pages`. Giữ lịch sử
cả hai nhánh, không force-push; fetch bản remote mới nhất trước khi đóng gói.

1. Dùng Godot 4.7.2 Compatibility. Tạo `build/.gdignore`; trỏ `APPDATA`,
   `LOCALAPPDATA`, `TEMP`, `TMP` vào thư mục ghi được trong `build/`.
2. Xuất `--export-pack Web build/web/index.pck`. Kiểm log và khởi động PCK
   với script kiểm tra bên ngoài; dùng `--demo` để không ghi bản lưu thật.
3. Dựng staging từ `origin/gh-pages` mới nhất, tái sử dụng engine Web 4.7.2
   single-thread. Chạy:
   `node tools/prepare_web_release.mjs SITE_DIR WEB_PCK SOURCE_SHA 1.11 1.6`.
   Script ghi shell, tên PCK theo SHA-256 và `version.json`.
4. Giữ ZIP Windows hiện có tại `download/TruocMuaMua-Windows.zip` và tên
   các PCK đã phát hành, tránh làm hỏng trang đang mở trong cache.
5. Kiểm trên trình duyệt trang chính và `?neighborhood-demo`. Demo mới chạy
   ngày 1 với `--demo --demo-full --no-title --map=hn_pho_co`, không ghi save
   chính. `?city-demo` và `?street-demo` vẫn dùng được với bố cục mới.
6. Commit cây site với parent là `origin/gh-pages`; push source và Pages,
   kiểm `version.json` public, hash PCK và màn hình game sau triển khai.

Tên PCK theo nội dung tránh cache ghép HTML mới với dữ liệu cũ. Save Windows
và web riêng nhau. Bản cập nhật tự chuyển tiến độ cũ; xem
[NEIGHBORHOOD_UPDATE.md](NEIGHBORHOOD_UPDATE.md) về phạm vi và kiểm tra.

## Dựng lại asset của 1.11

Các đầu vào được giữ trong `art/higgsfield/source-3d/`; `art/.gdignore`
loại chúng khỏi game. Cài công cụ bằng
`npm install --prefix build/asset-tools @gltf-transform/cli@4.5.1 --no-audit --no-fund`.
Chạy lần lượt `node tools/prepare_higgsfield_hanh.mjs`,
`node tools/bind_hanh_to_verified_rig.mjs`, `node tools/prepare_higgsfield_cart.mjs`.
Sau khi Godot nhập lại tài nguyên, chạy `tests/higgsfield_assets.gd`.
Ba mô-đun nhà được sinh lại bằng `tools/build_architecture.gd -- --demo --hero-only`.
