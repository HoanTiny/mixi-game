# Triển khai bản web 1.11

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
