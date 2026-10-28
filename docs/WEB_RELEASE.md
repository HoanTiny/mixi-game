# Triển khai bản web và Windows 1.6

Nguồn ở nhánh `feature/noi-chuyen`, GitHub Pages ở `gh-pages`. Giữ lịch sử
cả hai nhánh, không force-push; fetch bản remote mới nhất trước khi đóng gói.

1. Dùng Godot 4.7.2 Compatibility. Tạo `build/.gdignore`; trỏ `APPDATA`,
   `LOCALAPPDATA`, `TEMP`, `TMP` vào thư mục ghi được trong `build/`.
2. Xuất `--export-pack Web build/web/index.pck` và
   `--export-release Windows build/windows-1.6/TrenPho.exe`. Kiểm log và
   khởi động PCK/EXE. Windows x64 nhúng PCK; kèm giấy phép và hướng dẫn.
3. Dựng staging từ `origin/gh-pages` mới nhất, tái sử dụng engine Web 4.7.2
   single-thread. Chạy:
   `node tools/prepare_web_release.mjs SITE_DIR WEB_PCK SOURCE_SHA 1.6 1.6`.
   Script ghi shell, tên PCK theo SHA-256 và `version.json`.
4. Đặt ZIP Windows đã kiểm tại `download/TruocMuaMua-Windows.zip` để giữ
   đường dẫn tải cũ. ZIP chứa `TrenPho.exe`, hướng dẫn, giấy phép và manifest.
5. Kiểm trên trình duyệt trang chính và `?neighborhood-demo`. Demo mới chạy
   ngày 1 với `--demo --demo-full --no-title --map=hn_pho_co`, không ghi save
   chính. `?city-demo` và `?street-demo` vẫn dùng được với bố cục mới.
6. Commit cây site với parent là `origin/gh-pages`; push source và Pages,
   kiểm `version.json` public, hash PCK và màn hình game sau triển khai.

Tên PCK theo nội dung tránh cache ghép HTML mới với dữ liệu cũ. Save Windows
và web riêng nhau. Bản cập nhật tự chuyển tiến độ cũ; xem
[NEIGHBORHOOD_UPDATE.md](NEIGHBORHOOD_UPDATE.md) về phạm vi và kiểm tra.
