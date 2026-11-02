# Nguồn âm thanh

Mọi tiếng trong `assets/sounds/` đều tự làm hoặc có giấy phép cho phép đưa vào game. Không có file
nào cắt từ phim, nhạc, video hay bản thu không rõ bản quyền.

## Tự tổng hợp bằng code (thuộc dự án)

Dựng từ toán học (nhiễu lọc, dao động tắt dần), seed cố định, chạy lại script là ra đúng file.
Không dùng bản thu, giọng người thật hay TTS.

| File | Script | Là tiếng gì |
|---|---|---|
| step_1..4.ogg | tools/gen_sounds.py | dép tổ ong trên gạch vỉa hè |
| step_wet_1..4.ogg | tools/gen_sounds.py | bước trên vỉa hè đọng nước (trời mưa) |
| earn.ogg | tools/gen_sounds.py | đếm hai tờ tiền polymer |
| spend.ogg | tools/gen_sounds.py | rút tờ tiền, đặt xuống bàn |
| dialog.ogg | tools/gen_sounds.py | gõ nhẹ mặt bàn gỗ |
| done.ogg | tools/gen_sounds.py | chuông xe đạp "kính coong" |
| neighborhood/dishes.ogg | tools/gen_sounds.py | bát sứ, đũa, thìa ở quán cơm |
| neighborhood/fan.ogg | tools/gen_sounds.py | quạt cây (lặp) |
| neighborhood/screw.ogg | tools/gen_sounds.py | tua vít bánh cóc, va kim loại |
| neighborhood/sweep.ogg | tools/gen_sounds.py | chổi rơm quét sân |
| neighborhood/scooter_pass.ogg | tools/gen_sounds.py | xe số chạy ngang |
| neighborhood/bath.wav | tools/gen_bath_sound.py | xối nước khi tắm |

## Bản thu thật ở Hà Nội (Freesound)

Tải bản preview (không cần đăng nhập) ngày 30/10/2026, cắt một đoạn, đổi về 22 kHz, lọc dải, nối
đầu đuôi cho lặp liền bằng `tools/cut_field_recordings.py`. Bản gốc không để trong repo.

| File trong game | Bản gốc | Tác giả | Giấy phép |
|---|---|---|---|
| pho_ngay.ogg (phố ban ngày, xe máy, còi) | [Traffic In Hanoi](https://freesound.org/people/_Evile/sounds/854365/), giây 8–55 | _Evile | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| dem_ech_de.ogg (ếch nhái, dế về đêm) | [frogs in hanoi.mp3](https://freesound.org/people/bamboopurrs/sounds/136471/), giây 120–162 | bamboopurrs | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| pho_toi.ogg (phố cổ buổi tối, quán vỉa hè) | [SEA_16 Vietnam, Hanoi, Street atmo at Steet restaurant (binaural)](https://freesound.org/people/aUREa/sounds/398655/), giây 60–107 | aUREa | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| mua.ogg (mưa nhỏ đêm Hà Nội) | [20140223 - Hanoi at night light rain.wav](https://freesound.org/people/LG/sounds/345178/), giây 40–82 | LG | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| loa_phuong.ogg (loa phường buổi sáng) | [Hanoi Loudspeakers](https://freesound.org/people/Veridiansunrise/sounds/350722/), giây 0–63 | Veridiansunrise | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |

Các file CC BY 4.0 đã bị cắt, lọc và đổi định dạng. Khi phát hành phải ghi trong phần ghi công
của game, ví dụ:

> Tiếng phố tối: "SEA_16 Vietnam, Hanoi, Street atmo at Steet restaurant" của aUREa; tiếng mưa:
> "Hanoi at night light rain" của LG; loa phường: "Hanoi Loudspeakers" của Veridiansunrise.
> Nguồn freesound.org, giấy phép CC BY 4.0, đã cắt và chỉnh sửa.

## Tiếng rao

Chưa có bản thu; người bán rong chỉ hiện chữ. Cách thu và ghi nguồn: `rao/README.md`.
