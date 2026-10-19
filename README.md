# Trước mùa mưa

Game mô phỏng đời sống lấy cảm hứng từ *Nobody: The Turnaround*, bối cảnh phường An Hòa của thành phố hư cấu Bình Giang. An, 27 tuổi, vừa mất việc ở tiệm điện máy. Cả nhà có 30 ngày để dọn khỏi xóm trọ Bờ Me và tìm chỗ ở mới. Thiết kế đầy đủ nằm trong [docs/](docs/README.md).

Làm bằng **Godot 4.7**. Nhà cửa, người và xe hiện là khối hình tạm, sau này sẽ thay bằng mô hình thật.

**Trạng thái:** đã chơi được **lát cắt ngày 18–22**. Lát cắt có ba tuyến nghề, tiền mặt tách khỏi tiền phải thu và phải trả, chỉ số Mệt, sổ lời hứa, sổ gia đình, và quyền tự quyết của Linh. Ngày 1–17, ngày 23–30 và 8 kết thúc chính chưa làm.

## Mở project

1. Mở Godot, chọn **Import**, trỏ tới file `project.godot` trong thư mục này.
2. Bấm **Run** (F5). Màn chính là phố 3D (`scenes/world.tscn`). Màn đầu cho chọn tuyến nghề A, B hoặc C mà An đã chọn từ ngày 11.

**Điều khiển ở màn phố:**

| Thao tác | Tác dụng |
|---|---|
| Chuột trái | Đi tới chỗ bấm. Đi bộ tốn giờ trong game. |
| Bấm vào cửa tiệm hoặc người | Đi tới và mở việc ở đó |
| WASD hoặc phím mũi tên | Đi lại |
| E | Vào địa điểm đang đứng gần |
| Esc | Đóng bảng |
| Nút **Về xóm trọ** | Đi về Bờ Me. Chỉ ngủ được ở đó; 22 giờ chưa về thì ngủ gục ngoài đường, Mệt +15. |

Ván chơi tự lưu sau mỗi thao tác vào `user://save.json`. Nút **Chơi lại** trong Bảng cân bằng xóa ván đang chơi.

## Cấu trúc thư mục

```
data/
  config.json     số liệu: tiền sinh hoạt, Mệt, chỗ ở, điểm xuất phát của 3 tuyến, việc làm và địa điểm của từng việc
  events.json     sự kiện ngày 18–22, biến thể theo tuyến, sự kiện hệ thống (nghiệm thu, nợ chưa trả, ngủ gục)
  story.json      lời mở lát cắt, tên nhân vật, thẻ hậu truyện của Linh và bà Tư
docs/             tài liệu thiết kế "Trước mùa mưa" (Godot bỏ qua thư mục này)
prototype/        bản thử HTML đầu tiên (cốt truyện cũ)
scripts/
  game_logic.gd   toàn bộ luật chơi, không phụ thuộc giao diện
  game_state.gd   autoload GameState: giữ ván chơi, tự lưu
  world/world.gd  phố 3D: địa điểm, nhân vật, rạch và cầu, xe máy, người đi đường, ánh sáng theo giờ
  world/hud.gd    HUD kiểu Nobody: mục tiêu, tiền và Mệt, bảng địa điểm, thanh "đang làm", Sổ, Nhật ký
  ui/ui_kit.gd    màu sắc, theme, thẻ hành động, hai cột tiền, Sổ dạng chữ
  ui/dialog_layer.gd  hộp thoại chọn tuyến, sự kiện, đi ngủ, tổng kết lát cắt
  board.gd        Bảng cân bằng: chơi bằng nút bấm, thấy hết dòng tiền và các sổ
scenes/
  world.tscn      màn chính
  board.tscn      Bảng cân bằng
tests/
  sim.gd          tự chơi lát cắt cho 3 tuyến × 3 cách chơi
```

## Chỉnh cân bằng

- Sửa số trong `data/config.json` rồi chạy lại game. Điểm xuất phát của từng tuyến nằm ở `presets`.
- Bảng cân bằng (nút **Bảng cân bằng** ở dưới màn phố) cho chơi nhanh bằng nút bấm.
- Chạy mô phỏng:

```bash
"C:/Users/Admin/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s res://tests/sim.gd
```

Kết quả gần nhất (tiền dự kiến sáng ngày 26, hạn chốt chỗ ở):

| Tuyến | Lắng nghe | Giữ tiếp | Áp đặt |
|---|---|---|---|
| A · Làm công | 6,36 tr · đủ Hẻm Dừa | 6,39 tr · đủ Hẻm Dừa | 6,39 tr · đủ Hẻm Dừa |
| B · Tổ đội | 6,14 tr · đủ Hẻm Dừa | 5,74 tr · đủ Hẻm Dừa | 5,74 tr · đủ Hẻm Dừa |
| C · Dịch vụ riêng | 4,83 tr · đủ Cầu Tre | 4,43 tr · đủ Cầu Tre | 4,59 tr · đủ Cầu Tre |

Cách chơi "áp đặt" luôn dẫn tới thẻ "Tin nhắn chỉ đủ việc" của Linh. Hai cách còn lại cho thẻ "Đi xa, vẫn có đường về".

**Chạy thử nhanh** (thêm vào sau lệnh chạy game, không ghi đè bản lưu thật):

- `-- --demo --demo-route=C`: vào thẳng ngày 18 của tuyến C.
- Thêm `--demo-open=ben_can`: mở sẵn một địa điểm.
- Thêm `--demo-end`: tự chơi tới hết ngày 22 để xem bảng tổng kết.

## Khi xuất bản game

Godot không tự đóng gói file `.json`. Trong **Project → Export**, thêm `*.json` vào ô *Filters to export non-resource files*.
