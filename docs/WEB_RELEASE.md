# Triển khai bản web 1.4

Nguồn nằm ở nhánh `feature/noi-chuyen`, website GitHub Pages lấy nhánh `gh-pages`.
Giữ lịch sử của cả hai nhánh, không force-push. Gộp các thay đổi mới trên remote
trước khi xuất. Đợt này đã giữ bản 1.3.2 (giao diện tối và tránh người đi bộ).

## Đóng gói

Engine Web đang triển khai là Godot 4.7.2, single-thread, Compatibility. Dùng đúng
bản 4.7.2 để `--export-pack Web build/web/index.pck`; tái sử dụng bộ engine Web
cùng phiên bản trên `gh-pages`. Không cần tải template của mọi nền tảng.

- Tạo `build/.gdignore` trước khi export để Godot không quét thư mục staging.
- Khi chạy trong sandbox, trỏ `APPDATA`, `LOCALAPPDATA`, `TEMP`, `TMP` vào các
  thư mục tạm ghi được dưới `build/` để `project.binary` không bị xuất rỗng.
- Kiểm log export và khởi động trực tiếp PCK bằng `--main-pack` trước khi phát hành.
- Dựng lại cây site từ commit `origin/gh-pages` hiện tại vào thư mục staging.
- Chạy `node tools/prepare_web_release.mjs build/pages build/web/index.pck SOURCE_SHA`.
  Công cụ ghi HTML từ `web/shell.html`, tên PCK theo SHA-256 và `version.json`.
- Thử cả trang chính và `?street-demo` trên trình duyệt. Demo truyền các cờ
  `--demo --no-title --street-demo --map=hn_pho_co`, giữ `_persist=false`.
- Chỉ đưa các file site vào commit `gh-pages`, với parent là bản triển khai mới nhất.
  Giữ file tải Windows hiện có; không ghi đè bản Windows bằng gói chưa kiểm.
- Sau push, đối chiếu `version.json` public với source SHA và kiểm màn hình game.

Tên PCK theo nội dung tránh cache ghép HTML mới với dữ liệu cũ. Gói cũ vẫn còn
trong lịch sử Git để phục hồi. `version.json` cho biết bản Windows đi kèm là 1.3.2.

## Đợt kế tiếp

Ưu tiên và điều kiện kiểm tra ở [NEXT_UPDATE.md](NEXT_UPDATE.md). Không xem bản
web được tải thành công là bằng chứng đã kiểm mọi chương/save hoặc mọi thiết bị.
