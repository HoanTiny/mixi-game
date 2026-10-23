# Tài liệu thiết kế: Trước mùa mưa

"Trước mùa mưa" là cốt truyện chính mới của game, thay cho cốt truyện "Lên Phố" cũ (Minh trả nợ nặng lãi, lo học phí cho Lan). Bộ tài liệu này viết lại hồ sơ cốt truyện bản 1.0 thành từng phần để đội làm game tra cứu và chuyển dần vào code.

Trạng thái: **chơi được đủ 30 ngày và 8 kết thúc**, kèm lát cắt ngày 18–22 để thử nhanh. Màn kết ngày 30 có nút **Chơi tiếp** sang **Chương 2 · Mùa mưa** (ngày 31–60, 6 kết thúc), mọi lựa chọn của chương 1 đi tiếp; màn kết ngày 60 chơi tiếp **Chương 3 · Tháng Bảy mưa ngâu** (ngày 61–90, 6 kết thúc), màn kết ngày 90 chơi tiếp **Chương 4 · Tháng Tám trăng tròn** (ngày 91–120, 6 kết thúc). Tiến độ chi tiết và việc còn lại nằm ở [08-chuyen-sang-game.md](cot-truyen/08-chuyen-sang-game.md).

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
| [09 · Chương 2 · Mùa mưa](cot-truyen/09-chuong-2-mua-mua.md) | Ngày 31–60 ở chỗ mới: má về, đôi mắt của bà, mùa mưa và đêm triều cường, bí mật cái mỏ lết, ông Ba và Kha, giỗ ông; 6 kết thúc K1–K6 |
| [10 · Chương 3 · Tháng Bảy mưa ngâu](cot-truyen/10-chuong-3-thang-bay.md) | Ngày 61–90, tháng cô hồn: tiệm Sáu sang tay, thằng Tín và chị Lụa, kè kênh và cái hiên của ông Ba, Linh hết thực tập, má, bà về quê; 6 kết thúc L1–L6 |
| [11 · Chương 4 · Tháng Tám trăng tròn](cot-truyen/11-chuong-4-thang-tam.md) | Ngày 91–120: tháng đầu của tiệm, đơn quạt của trường, lời mời của anh Quân, Tín đòi nghỉ học, rằm Trung thu, chú Sáu về Bến Tre; 6 kết thúc M1–M6 |

Dữ liệu gốc dạng JSON (nhân vật, 30 ngày, kết thúc, nhánh) nằm ở [data/narrative_design.json](data/narrative_design.json), dùng làm nguồn khi chuyển nội dung sang `data/events.json`.

## Con số chính

- **Quy mô:** 9 nhân vật · 30 ngày · 90 lựa chọn · 8 kết thúc chính · 4 hậu truyện của Linh · 3 hậu truyện của bà Tư.
- **Chương 2:** thêm 3 nhân vật (má, ông Ba, Kha) · 30 ngày · 38 cảnh chính · 133 lựa chọn · 20 việc mới · 5 việc nhờ · 32 đoạn thoại · 6 kết thúc · thẻ hậu truyện của má, bà, Linh.
- **Chương 3:** thêm 2 nhân vật (Tín, chị Lụa) · 30 ngày · 35 cảnh chính · 140 lựa chọn · 6 việc mới · 5 việc nhờ · 28 đoạn thoại · 6 kết thúc · sáu thẻ hậu truyện (Tín, ông Ba, Linh, bà Tư, má, chú Sáu).
- **Chương 4:** thêm 2 nhân vật (anh Quân, cô Mai) · 30 ngày · 37 cảnh chính · 119 lựa chọn · 6 việc mới · 4 việc nhờ · 21 đoạn thoại · 6 kết thúc · bảy thẻ hậu truyện.
- **Mốc cố định:** mưa sớm ngày 15, mưa lớn ngày 29, trả chìa khóa ngày 30.
- **Tiền khởi đầu:** 1,2 triệu tiền mặt, cộng 3,6 triệu lương cũ còn phải thu.

Mọi con số tiền và thời gian là giả định để cân bằng, chưa được chơi thử, và không phải mức lương hay giá thuê thực tế ở Việt Nam.
