# 04 · Địa điểm

Bảy nơi trong truyện, và cách đặt chúng lên con phố 3D đang có (`scripts/world/world.gd`, bảng `LOCATIONS`). Cột **ID mới** là tên đề xuất khi viết lại code.

| Nơi trong truyện | Mô tả | ID mới | Thay cho địa điểm cũ |
|---|---|---|---|
| **Xóm trọ Bờ Me** | Tám phòng quanh một khoảng sân, vòi nước chung, dây phơi dưới mái tôn. Trung tâm của gia đình, họp xóm và chuyển nhà. Cô Duyên quản lý. | `xom_bo_me` | `phong_tro` (Dãy trọ cô Sáu) |
| **Cơm Hạnh** | Quán cơm phần cho người làm ca. Tờ giấy ghi ai ăn nợ nằm dưới hũ tăm. Nơi nhận ca phụ, giao cơm, và nghe chuyện dãy quán cần sửa điện. | `com_hanh` | `quan_com` |
| **Tiệm Sáu Sửa** | Tiệm sửa xe có thêm một bàn sửa đồ gia dụng. Chú Sáu muốn bớt việc nặng nhưng chưa biết giao chiếc bàn cho ai. | `tiem_sau` | `tiem_chu_bay` |
| **Chợ Cầu Nhỏ** | Sạp vật tư, hàng đồ cũ, quán nước có bảng tin cho thuê phòng. Giá rẻ thường kèm điều kiện cần hỏi rõ, nhưng không phải món nào cũng là bẫy. | `cho_cau_nho` | `cua_hang`, `tra_da` |
| **Dãy quán Bến Cạn** | Năm hộ kinh doanh chung lối đi và hạ tầng cũ. Làm ở đây phải hỏi lịch từng quán, ghi việc rõ, và có người đủ tay nghề giám sát. Anh Phúc đại diện. | `ben_can` | `cong_trinh` |
| **Bến xe số 6 và trung tâm nghề** | Không gian riêng của Linh: bảng tuyển thực tập, giờ xe, bạn cùng lớp, những lựa chọn không xoay quanh An. | `ben_xe_6` | `trung_tam`, `tram_xe_buyt` |
| **Ba chỗ ở mới** | Phòng Hẻm Dừa gần việc, phòng Cầu Tre xa hơn nhưng thoáng, nhà dì Năm ở tạm. Ưu nhược điểm của từng nơi được báo trước. | `hem_dua`, `cau_tre`, `nha_di_nam` | Mới, đặt ở hai đầu phố hoặc đi bằng xe |

**Bỏ đi:** `phuong`, `thu_vien`, `nga_tu`, `quan_ca_phe`. Truyện mới không dùng các nơi này. Nếu muốn giữ cho phố đông vui, có thể để làm cảnh nền không tương tác.

## Gợi ý bố cục phố

- **Xóm trọ Bờ Me** đặt ở giữa phố, là nơi xuất phát và nơi đi ngủ mỗi tối.
- **Cơm Hạnh** và **Tiệm Sáu Sửa** đặt gần xóm trọ vì An ghé hằng ngày.
- **Chợ Cầu Nhỏ** đặt cạnh một cây cầu nhỏ bắc qua con rạch, chi tiết nhận diện của phường An Hòa.
- **Dãy quán Bến Cạn** là năm mặt tiền nhỏ liền nhau ở một đầu phố, bên bờ rạch.
- **Bến xe số 6** ở đầu phố còn lại. Từ đây đi được tới trung tâm nghề và tới Cầu Tre, mất thêm thời gian di chuyển.
- **Hẻm Dừa** là một con hẻm rẽ ra từ phố chính, gần chợ. **Nhà dì Năm** ở hẻm khác, chỉ mở sau khi đã hỏi ở ngày 3.

Ngày 15 và 29, sân xóm trọ và đường ven rạch đọng nước. Đây là chỗ để thể hiện mưa bằng hình ảnh, không chỉ bằng chữ.
