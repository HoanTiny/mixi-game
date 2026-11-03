# Nhịp di chuyển — cập nhật toàn phố

Ngày 28/10/2026. Mục tiêu: đi bộ có nhịp gần người đi đường, tăng/giảm tốc rõ,
và không dùng tốc độ di chuyển cao để bù cho đường dài.

| Chế độ | Trước | Hiện tại |
|---|---:|---:|
| Đi bộ bình thường | 6,0 m/s | 1,7 m/s |
| Giữ Shift / nút Chạy | 9,9 m/s | 3,15 m/s |
| Xe máy giao hàng | 10,8 m/s | 4,8 m/s |

Ngõ hẹp, lội nước, mệt và đang mang đồ vẫn áp dụng hệ số giảm tốc của gameplay.
Đi bộ tăng tốc trong khoảng 0,32 giây; buông phím dừng sau khoảng 0,20 giây,
đi thêm tối đa 0,17 m ở tốc độ chuẩn. Xe tăng tốc lâu hơn và phanh trong khoảng
0,60 giây, đi thêm tối đa 1,44 m. UI chặn điều khiển, tới đích hoặc đổi trạng thái
lên/xuống xe xóa vận tốc tích lũy. Chạm người/tường không giữ lại tốc độ để bật vọt
khi thoát vật cản.

Nhân vật xoay hướng chậm hơn và giảm tốc ngắn khi đổi hướng. Bước cuối của đường
click đi qua cùng xử lý va chạm/người/đồng hồ với các bước khác, không dịch chuyển
thẳng tọa độ tới đích. Tốc độ đổi theo thời gian thực; quãng đường tăng/giảm tốc
được tích phân để không phụ thuộc 30, 60 hay 120 FPS.

An nhận vận tốc thực theo mét/giây để đặt nhịp clip. Đi chậm bằng joystick không
còn bị ép nhịp bước tối thiểu quá cao. Tiếng bước chân và vòng bánh cũng theo
quãng đường thực, kể cả đoạn tới đích cuối cùng. Chưa có clip chạy nhẹ/quay tại chỗ
mới; khi giữ Shift vẫn dùng clip bước hiện có tăng nhịp.

Chi phí giờ, thể lực, đi xe và lội nước vẫn tính theo mét như trước; không đổi hạn
nhiệm vụ hoặc save. Đi xa mất nhiều giây thực hơn; Shift và đường tự đi theo click
vẫn có sẵn. Chưa thêm dịch chuyển nhanh hoặc tự tua thời gian.

Kiểm tra: `tests/locomotion_pacing.gd` kiểm tốc độ, bắt đầu/dừng theo 30/60/120 FPS,
đích ngắn 0,005–12 m, không vượt đích và reset khi bị chặn. `tests/player_motion.gd`
với `--integration` kiểm bước cuối thực, thời gian theo mét, vòng bánh, tư thế,
đèn và chuyển lên/xuống xe. `tests/character_motion.gd` kiểm cadence và rig.
