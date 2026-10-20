# Tài liệu thiết kế: Trước mùa mưa

"Trước mùa mưa" là cốt truyện chính mới của game, thay cho cốt truyện "Lên Phố" cũ (Minh trả nợ nặng lãi, lo học phí cho Lan). Bộ tài liệu này viết lại hồ sơ cốt truyện bản 1.0 thành từng phần để đội làm game tra cứu và chuyển dần vào code.

Trạng thái: **đã chơi được lát cắt ngày 18–22**. Các ngày còn lại và 8 kết thúc chưa làm. Tiến độ chi tiết và việc còn lại nằm ở [08-chuyen-sang-game.md](cot-truyen/08-chuyen-sang-game.md).

## Đọc theo thứ tự

| Phần | Nội dung |
|---|---|
| [01 · Tổng quan](cot-truyen/01-tong-quan.md) | Tiền đề, câu hỏi trung tâm, giọng kể, mạch truyện xuyên suốt, 6 hồi |
| [02 · Thế giới và luật chơi](cot-truyen/02-the-gioi-va-luat-choi.md) | Bối cảnh, thời gian, tiền, chỗ ở, hợp đồng, ba tuyến nghề, mưa, trạng thái cần lưu |
| [03 · Nhân vật](cot-truyen/03-nhan-vat.md) | 9 nhân vật: mong muốn, điểm yếu, tiến triển, giọng nói, giới hạn quyền của người chơi |
| [04 · Địa điểm](cot-truyen/04-dia-diem.md) | 7 nơi trong truyện và cách đặt lên con phố 3D |
| [05 · 30 ngày](cot-truyen/05-30-ngay/) | Mỗi ngày: cảnh, nhiệm vụ chính, 3 lựa chọn, việc tùy chọn, nếu bỏ lỡ, lời thoại |
| [06 · Kết thúc](cot-truyen/06-ket-thuc.md) | 8 kết thúc chính, thứ tự xét, hậu truyện của Linh và bà Tư, quan hệ xóm và nghề |
| [07 · Hội thoại mẫu](cot-truyen/07-hoi-thoai-mau.md) | 4 cảnh mẫu ngày 1, 20, 22, 30 |
| [08 · Chuyển sang game](cot-truyen/08-chuyen-sang-game.md) | So với game hiện tại, việc cần đổi trong data và code, thứ tự làm |

Dữ liệu gốc dạng JSON (nhân vật, 30 ngày, kết thúc, nhánh) nằm ở [data/narrative_design.json](data/narrative_design.json), dùng làm nguồn khi chuyển nội dung sang `data/events.json`.

## Con số chính

- **Quy mô:** 9 nhân vật · 30 ngày · 90 lựa chọn · 8 kết thúc chính · 4 hậu truyện của Linh · 3 hậu truyện của bà Tư.
- **Mốc cố định:** mưa sớm ngày 15, mưa lớn ngày 29, trả chìa khóa ngày 30.
- **Tiền khởi đầu:** 1,2 triệu tiền mặt, cộng 3,6 triệu lương cũ còn phải thu.

Mọi con số tiền và thời gian là giả định để cân bằng, chưa được chơi thử, và không phải mức lương hay giá thuê thực tế ở Việt Nam.
