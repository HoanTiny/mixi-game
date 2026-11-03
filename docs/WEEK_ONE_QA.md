# Kiểm tra tuần đầu và thời gian dựng phố — 1.16

## Thay đổi

- Lưu sẵn 19 cụm hình học mặt tiền trong `assets/architecture/baked` (khoảng 1,36 MB tổng). Biển hiệu, đồ dùng động, NPC, cửa tương tác và collider vẫn do runtime dựng. Cache kiểm phiên bản, kích thước lô và seed; không khớp thì dùng builder cũ. Sau khi sửa `street_kit.gd` hoặc `story_fronts.gd`, chạy `tools/bake_story_fronts.gd` và `tests/front_cache.gd`; bump `FrontCache.VERSION` khi đổi định dạng. Không có cache tự sinh trong save của người chơi.
- `--profile-world` in thời gian từng giai đoạn và từng mặt tiền; `--no-front-cache` cho phép đối chiếu builder cũ.
- Ca ngày 5 hiển thị công khoán trả lúc bàn giao; màn kết ca không báo thưởng/tiền đã nhận. Tách mức chỉ tiêu thực khỏi lương sàn ca thường: phục vụ 0 bàn không thể đạt 50%.
- Thẻ nhiệm vụ vàng tương phản rõ, tự giãn theo văn bản. Thẻ hành động hiện đủ điều kiện, mục tiêu thu gọn ưu tiên bước đang cần làm. Rút ngắn tên ba nhiệm vụ ngày 5.
- Sổ tiền tách ví và quỹ cọc, liệt kê cọc còn thiếu và toàn bộ tiền còn phải trả để vào ở từng phương án nhà.
- Trong ngày 1–7, đói dưới 30 được gợi ý bữa cơm gia đình; mệt từ 75 có một lần nghỉ sân trọ miễn phí mỗi ngày, không miễn tiền giường. Hướng dẫn kiểm tra khả dụng thật trước khi đề xuất.

## Bằng chứng

- `tests/front_cache.gd`: đối chiếu cả 19 lô giữa mesh dựng trực tiếp và bản lưu; bounds, số surface, blockers, chiều cao và node cutaway khớp; thay kích thước lô phải từ chối cache. Đã đạt.
- `tests/week_one_visual.gd`: mở thẻ ca từ HUD, phục vụ các đơn khách trong cảnh thật, bấm kết ca, quay lại thẻ bàn giao, lấy/giao phần cơm ngày 6. Xác nhận không trả công trước bàn giao. Có ảnh 1280×800 và 900×650 trong `build/week-one-preview`. Đây là tự động hóa tích hợp, không thay thế thử nghiệm với người mới hoặc đi bộ toàn tuyến.
- Đo headless trước cache: khoảng 120.480 ms tổng, 88.509 ms mặt tiền. Sau cache: 50.953 ms tổng, 34.379 ms mặt tiền. Lần native GL tiếp theo: 18.867 ms tổng. Các lượt có mức cache đĩa khác nhau; không coi số này là SLA, FPS hay thời gian tải web.
- Báo cáo lấy mẫu native nằm ở `build/week-one-preview/performance.json`; số đo web cần ghi riêng.
- Lượt native cuối: dựng thế giới 21.617 ms, mẫu đứng trước quán cơm ở 900×650 khoảng 53,6 FPS; không suy ra FPS web từ số này.
- Web 1.16 đóng gói 60.569.380 byte: Chrome tải được phố, NPC hoạt động và phím E mở tương tác nhà trọ. Công cụ trình duyệt từng timeout trong lúc tải; sau tải điều khiển được. Console chỉ ghi cảnh báo UID texture tủ đồ nghề có đường dẫn dự phòng, không ghi lỗi script trong lượt kiểm tra này. Chưa đo thời gian tải lạnh hoặc chơi đủ bảy ngày trên web.

## Mô phỏng kinh tế 7 ngày

`tests/week_one_budget.gd` chạy chín lịch: một ca/ngày, ba mức chỉ tiêu, mua sáng nếu đủ tiền, trả trọ, ăn cùng bà, nghỉ, tắm và giặt tiệm. Không cộng truyện, lương cũ hoặc xóa nhu cầu mỗi ngày. Đây là kiểm tra áp lực, không phải người chơi tối ưu hay cân bằng 30 ngày.

| Ca | Ví cuối tuần: 100% | 70% | 40% |
|---|---:|---:|---:|
| Phụ quán | 661.000đ | 261.000đ | 16.000đ |
| Kho | 1.481.000đ | 851.000đ | 221.000đ |
| Sửa đồ lẻ | 421.000đ | 101.000đ | 21.000đ |

Quỹ cọc 1,4 triệu vẫn riêng. Nhánh sửa 40% thiếu hai đêm trọ; các nhánh thu nhập thấp phải bỏ một số bữa mua/giặt tiệm. Do đó bổ sung đường hồi sức miễn phí có giới hạn và chỉ dẫn bữa ở nhà, chưa tăng lương hàng loạt. Thu hồi nợ trọ của hardship, cân bằng hợp đồng sửa độc lập và ma trận lương cũ còn cần kiểm tiếp.

## Chưa nghiệm thu

5–8 người mới tự chơi vòng đầu trong 15 phút; FPS web trên máy tham chiếu; đầy đủ nhánh truyện ngày 1–7 bằng người chơi; ma trận 30 ngày ba nghề/ba hiệu suất/ba cách thu lương. Không tuyên bố các cổng này đã đạt chỉ từ test tự động.
