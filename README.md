# Lên Phố: 30 Ngày

Game mô phỏng đời sống lấy cảm hứng từ *Nobody: The Turnaround*, bối cảnh một con phố ở Bình Thạnh, Sài Gòn. Minh từ Hà Tĩnh lên thành phố, có 30 ngày để trả nợ nặng lãi cho gia đình và lo học phí cho em gái.

Làm bằng **Godot 4.7**. Nhà cửa, người và xe hiện là khối hình tạm, sau này sẽ thay bằng mô hình thật.

## Mở project

1. Mở Godot, chọn **Import**, trỏ tới file `project.godot` trong thư mục này.
2. Bấm **Run** (F5). Màn chính là phố 3D (`scenes/world.tscn`).

**Điều khiển:**

| Thao tác | Tác dụng |
|---|---|
| Chuột trái | Đi tới chỗ bấm |
| Bấm vào cửa tiệm hoặc người | Đi tới và mở việc làm, lớp học ở đó |
| WASD hoặc phím mũi tên | Đi lại |
| E | Vào địa điểm đang đứng gần |
| Esc | Đóng bảng |

Ván chơi tự lưu sau mỗi thao tác vào `user://save.json`. Nút **Chơi lại** trong Bảng cân bằng xóa ván đang chơi.

## Cấu trúc thư mục

```
data/
  config.json     số liệu cân bằng: tiền, lương, học phí, xác suất, việc làm và địa điểm của từng việc
  events.json     sự kiện cố định theo ngày, sự kiện ngẫu nhiên, mốc tiền
  story.json      mở đầu, món mang theo, 5 kết thúc, Sổ tay của Minh
scripts/
  game_logic.gd   toàn bộ luật chơi, không phụ thuộc giao diện
  game_state.gd   autoload GameState: giữ ván chơi, tự lưu
  world/world.gd  phố 3D: dựng cảnh, nhân vật, xe máy, người đi đường, ánh sáng theo giờ
  world/hud.gd    HUD kiểu Nobody: mục tiêu, trạng thái, bảng địa điểm, thanh công cụ
  ui/ui_kit.gd    màu sắc, theme, thẻ hành động dùng chung
  ui/dialog_layer.gd  hộp thoại mở đầu, sự kiện, buổi tối, kết thúc
  board.gd        Bảng cân bằng: chơi bằng nút bấm, thấy hết chỉ số
scenes/
  world.tscn      màn chính
  board.tscn      Bảng cân bằng
tests/
  sim.gd          tự chơi 200 ván để kiểm tra cân bằng
```

## Chỉnh cân bằng

- Sửa số trong `data/config.json` rồi chạy lại game. Mỗi việc làm có trường `location` cho biết nó nằm ở tiệm nào ngoài phố.
- Bảng cân bằng (nút **Bảng cân bằng** ở dưới màn phố) cho chơi nhanh bằng nút bấm.
- Chạy mô phỏng 100 ván cho mỗi chiến lược (chỉ làm chân tay, và học nghề):

```bash
"C:/Users/Admin/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s res://tests/sim.gd
```

Kết quả gần nhất: chỉ làm chân tay thì thua cả 100 ván, học nghề điện lạnh thì 86/100 ván đạt kết đẹp.

- Chạy `-- --demo` để vào thẳng ngày 1 mà không ghi đè bản lưu; thêm `--demo-open=quan_com` để mở sẵn một địa điểm.

## Khi xuất bản game

Godot không tự đóng gói file `.json`. Trong **Project → Export**, thêm `*.json` vào ô *Filters to export non-resource files*.
