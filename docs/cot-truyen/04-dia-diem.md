# 04 · Địa điểm

Bảy nơi trong truyện, và cách đặt chúng lên bản đồ phường An Hòa (`data/map.json`, nội dung từng nơi ở bảng `LOCATIONS` của `scripts/world/world.gd`). Cột **ID mới** là ID đang dùng trong code.

| Nơi trong truyện | Mô tả | ID mới | Thay cho địa điểm cũ |
|---|---|---|---|
| **Xóm trọ Bờ Me** | Tám phòng quanh một khoảng sân, vòi nước chung, dây phơi dưới mái tôn. Trung tâm của gia đình, họp xóm và chuyển nhà. Cô Duyên quản lý. | `xom_bo_me` | `phong_tro` (Dãy trọ cô Sáu) |
| **Cơm Hạnh** | Quán cơm phần cho người làm ca. Tờ giấy ghi ai ăn nợ nằm dưới hũ tăm. Nơi nhận ca phụ, giao cơm, và nghe chuyện dãy quán cần sửa điện. | `com_hanh` | `quan_com` |
| **Tiệm Sáu Sửa** | Tiệm sửa xe có thêm một bàn sửa đồ gia dụng. Chú Sáu muốn bớt việc nặng nhưng chưa biết giao chiếc bàn cho ai. | `tiem_sau` | `tiem_chu_bay` |
| **Chợ Cầu Nhỏ** | Sạp vật tư, hàng đồ cũ, quán nước có bảng tin cho thuê phòng. Giá rẻ thường kèm điều kiện cần hỏi rõ, nhưng không phải món nào cũng là bẫy. | `cho_cau_nho` | `cua_hang`, `tra_da` |
| **Dãy quán Bến Cạn** | Năm hộ kinh doanh chung lối đi và hạ tầng cũ. Làm ở đây phải hỏi lịch từng quán, ghi việc rõ, và có người đủ tay nghề giám sát. Anh Phúc đại diện. | `ben_can` | `cong_trinh` |
| **Bến xe số 6 và trung tâm nghề** | Không gian riêng của Linh: bảng tuyển thực tập, giờ xe, bạn cùng lớp, những lựa chọn không xoay quanh An. | `ben_xe_6` | `trung_tam`, `tram_xe_buyt` |
| **Ba chỗ ở mới** | Phòng Hẻm Dừa gần việc, phòng Cầu Tre xa hơn nhưng thoáng, nhà dì Năm ở tạm. Ưu nhược điểm của từng nơi được báo trước. | `hem_dua`, `cau_tre`, `nha_di_nam` | Mới: Hẻm Dừa, Hẻm Bờ Nam, đường An Hòa |

**Bỏ đi:** `phuong`, `thu_vien`, `nga_tu`, `quan_ca_phe`. Truyện mới không dùng các nơi này. Nếu muốn giữ cho phố đông vui, có thể để làm cảnh nền không tương tác.

## Map khu thật: Quận 8, ven kênh Tàu Hủ

Từ khi có chế độ Dựng khu thật, map chơi là một khu có thật ở Quận 8 (TP.HCM), dọc kênh Tàu Hủ quanh cầu chữ Y, khung khoảng 980 × 860 m. Địa hình, đường, nhà là thật; tên trong truyện vẫn hư cấu để không gán chuyện bịa cho chỗ có thật.

| Trong truyện | Chỗ trên map thật |
|---|---|
| Rạch Bờ Me | Kênh Tàu Hủ |
| Cầu Nhỏ | Cầu chữ Y |
| Đường Bờ Me | Đường dọc bờ nam kênh |
| Xóm trọ Bờ Me | Dãy nhà ven kênh, phía tây cầu |
| Cơm Hạnh, Dãy quán Bến Cạn | Trên đường Bờ Me, giữa xóm trọ và chân cầu |
| Tiệm Sáu Sửa | Miệng hẻm từ xóm trọ ra đường Bờ Me |
| Chợ Cầu Nhỏ | Góc đường Bờ Me và đường Chợ Cầu Nhỏ, ngay chân cầu |
| Hẻm Dừa | Hẻm nhỏ rẽ ra từ đường Bờ Me sát chân cầu, cây dừa ở miệng hẻm |
| Phòng Cầu Tre | Bờ bắc kênh, phải đi vòng qua cầu |
| Bến xe số 6, Nhà dì Năm | Phía tây nam, trên đường lớn |

Đi bộ từ xóm trọ (theo phố và hẻm, không chui khe nhà): Tiệm Sáu 70 m, Cơm Hạnh 112 m, bến xe 141 m, Bến Cạn 155 m, chợ 198 m, nhà dì Năm 211 m, Hẻm Dừa 238 m, Cầu Tre 363 m. Map chỉnh ở `data/maps/q8_tau_hu_story.json`.

## Bản đồ phường An Hòa (vẽ tay, map cũ)

Bố cục lấy theo kiểu một khu ven kênh ở TP.HCM: đường lớn phía bắc, các hẻm chạy xuống rạch, chợ ở đầu cầu, dãy nhà quay lưng ra rạch, bên kia rạch là xóm nhà sàn và ruộng rau. Tọa độ: x tăng về hướng đông, z tăng về hướng nam (camera nhìn về hướng bắc).

```
            Cổng KCN
               │
 ══════════ Đường An Hòa (đường lớn, 2 chiều) ═══════════════════════
  Bến xe 6   Nhà dì Năm      Cơm Hạnh   ┃ Tiệm Sáu Sửa   ┃
               ┃                         ┃                 ┃
   Hẻm Dừa ════╣ đường                   ┣═══ Hẻm 42/7 ════┫
   (hẻm cụt)   ┃ Chợ                   Hẻm 42           Hẻm 88
               ┃                         ┃                 ┃
 ═══════ Chợ Cầu Nhỏ ═══ Đường Bờ Me ═══ Xóm trọ Bờ Me ═══ Dãy quán Bến Cạn ══
 ~~~~~~~~~~~~~~┃~~~~~~~~ Rạch Bờ Me ~~~~~~~~~~~~~~~~~~~~~~~~~~~┃~~~~~~~~
             Cầu Nhỏ                                         Cầu Tre
 ════════════ Hẻm Bờ Nam (nhà sàn) ═══════════════════════ Phòng Cầu Tre
                         ruộng rau muống
```

- **Xóm trọ Bờ Me** ở giữa đường Bờ Me, nhìn ra rạch. Là nơi xuất phát và nơi đi ngủ mỗi tối.
- **Cơm Hạnh** và **Tiệm Sáu Sửa** ở trên đường An Hòa, hai bên Hẻm 42 (Cơm Hạnh phía tây, tiệm Sáu phía đông): từ xóm trọ đi thẳng hẻm lên là tới, An ghé hằng ngày.
- **Chợ Cầu Nhỏ** ở góc đường Chợ và đường Bờ Me, ngay chân Cầu Nhỏ (kiểu chợ đầu cầu). Đường Chợ có sạp hai bên.
- **Dãy quán Bến Cạn** là năm mặt tiền nhỏ liền nhau ở cuối đường Bờ Me, sát Cầu Tre.
- **Bến xe số 6** ở đầu đường An Hòa, cạnh đường vào khu công nghiệp (ca kho đi từ đây).
- **Hẻm Dừa** là hẻm cụt rẽ ra từ đường Chợ, đầu hẻm có cây dừa. **Phòng Cầu Tre** ở Hẻm Bờ Nam, bên kia rạch. **Nhà dì Năm** ở đầu đường An Hòa, gần trạm xe.
- Đường đi từ xóm trọ: chợ khoảng 60 m, Cơm Hạnh 100 m, Cầu Tre 100 m, bến xe 150 m.

**Tham khảo khi vẽ:** cách phân loại hẻm (hẻm chính, hẻm nhánh, hẻm cụt; hẻm ba gác và hẻm xe hơi) và cách đánh số nhà trong hẻm có gạch chéo ở TP.HCM; mô hình phố, chợ, bến và chợ đầu cầu của đô thị Nam Bộ; dãy nhà quay lưng ra kênh rạch, nhà sàn ven rạch; cổng hẻm ghi tên khu phố. Không chép bản đồ một phường cụ thể nào: phường An Hòa là nơi hư cấu, chỉ lấy cách tổ chức không gian.

Ngày 15 và 29, sân xóm trọ và đường ven rạch đọng nước. Đây là chỗ để thể hiện mưa bằng hình ảnh, không chỉ bằng chữ.
