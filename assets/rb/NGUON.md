# Người thật: Microsoft Rocketbox

Nhân vật trong game (An, các nhân vật phụ, người đi đường, người lái xe máy, người làm chung ở chỗ làm) là avatar của bộ
**Microsoft Rocketbox** (https://github.com/microsoft/Microsoft-Rocketbox), giấy phép MIT (chép nguyên văn bên dưới).

- Mỗi thư mục `<Tên>/`: `<Tên>.fbx` (lưới có xương Biped, xuất từ `Assets/Avatars/.../Export/`), ảnh màu thân, đầu,
  tóc và mi (`body_color.jpg`, `head_color.jpg`, `opacity_color.png`, thu về 512 px), ảnh pháp tuyến cho nhân vật chính.
- `anims/`: bốn động tác của Rocketbox (đứng, đi, ngồi ghế, nói chuyện; bản nam và nữ), đã bỏ phần trôi theo mặt đất.
- `crowd/`: tư thế nướng sẵn thành lưới nhẹ cho đám đông và người lái xe (`tools/bake_people.gd`).

Ai là ai: An `Male_Adult_09`, Linh `Female_Adult_12`, má `Female_Adult_11`, bà Tư `Female_Adult_02`, chị Hạnh
`Chef_Female_01`, chú Sáu `Male_Adult_14`, ông Ba `Gardener_Male_01`, Minh `Male_Adult_10`, Trâm `Female_Adult_03`, Kha
`Male_Adult_17`, anh Phúc `Business_Male_02`, cô Duyên `Female_Adult_05`, anh Quân `Male_Adult_02`, chị Mai
`Medical_Female_01`, thầy Phong `Male_Adult_05`, Tín `Male_Child_01`, chị Lụa `Female_Adult_14`; người đi đường
`Male_Adult_01`, `Male_Adult_07`, `Delivery_Male_01`, `Construction_Male_02`, `Female_Adult_08`, `Female_Adult_07`.

---

MIT License

Copyright (c) 2020 Microsoft

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
