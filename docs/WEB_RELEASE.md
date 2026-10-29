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
