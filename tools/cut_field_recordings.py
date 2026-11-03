"""Cắt bản thu thật ở Hà Nội (Freesound, CC0 / CC-BY) thành tiếng nền lặp liền cho màn phố.

Bản gốc không để trong repo (nặng). Tải bản preview về một thư mục riêng, đặt tên fs_<id>.mp3
(id là số trong link freesound.org/people/<tác giả>/sounds/<id>/), rồi chạy:
    python tools/cut_field_recordings.py <thư mục chứa fs_<id>.mp3>
Ra assets/sounds/*.ogg (22 kHz). Nguồn, tác giả, giấy phép từng file: assets/sounds/NGUON.md.
Cần numpy, soundfile.
"""

import os
import sys

import numpy as np
import soundfile as sf

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds")

# Tiếng nền lặp: (file ra, id nguồn, giây bắt đầu, dài, nổi giây, stereo, độ to RMS dBFS, dải lọc Hz).
BEDS = [
    ("pho_ngay.ogg", 854365, 8.0, 45.0, 2.5, True, -21, (40, 9000)),
    ("pho_toi.ogg", 398655, 60.0, 45.0, 2.5, True, -21, (40, 9000)),
    ("mua.ogg", 345178, 40.0, 40.0, 2.5, True, -20, (60, 10000)),
    ("dem_ech_de.ogg", 136471, 120.0, 40.0, 2.5, True, -24, (150, 9000)),
    ("loa_phuong.ogg", 350722, 0.0, 60.0, 3.0, False, -22, (250, 3800)),
]


def load(src, ident):
    x, sr = sf.read(os.path.join(src, f"fs_{ident}.mp3"), always_2d=True)
    return x, sr


def resample(x, sr):
    """Đổi tần số mẫu bằng FFT từng kênh (cắt bớt dải trên Nyquist mới)."""
    n = len(x)
    m = int(round(n * RATE / sr))
    out = []
    for ch in x.T:
        spec = np.fft.rfft(ch)
        spec = spec[: m // 2 + 1]
        out.append(np.fft.irfft(spec, m) * m / n)
    return np.stack(out, 1)


def band(x, lo, hi):
    f = np.maximum(np.fft.rfftfreq(len(x), 1 / RATE), 1.0)
    shape = 1 / (1 + (lo / f) ** 4) / (1 + (f / hi) ** 4)
    return np.stack([np.fft.irfft(np.fft.rfft(ch) * shape, len(x)) for ch in x.T], 1)


def loop(x, cross):
    """Lặp liền: phần thừa ở cuối hòa dần vào đầu (công suất đều), nên điểm nối không nghe ra."""
    c = int(cross * RATE)
    body = x[:-c].copy()
    t = np.linspace(0, np.pi / 2, c)[:, None]
    body[:c] = x[:c] * np.sin(t) + x[-c:] * np.cos(t)
    return body


def level(x, rms_db):
    rms = np.sqrt(np.mean(x ** 2))
    x = x * (10 ** (rms_db / 20) / (rms + 1e-9))
    peak = np.max(np.abs(x))
    return x * (0.95 / peak) if peak > 0.95 else x


def write(name, x, quality=0.55):
    # Ghi từng khúc nhỏ: libsndfile trên Windows tràn stack khi mã hóa Vorbis cả khối dài một lần.
    x = np.ascontiguousarray(x, dtype=np.float32)
    with sf.SoundFile(os.path.join(OUT, name), "w", RATE, x.shape[1], format="OGG", subtype="VORBIS",
                      compression_level=quality) as f:
        for i in range(0, len(x), 4096):
            f.write(x[i:i + 4096])
    print(name, f"{len(x) / RATE:.1f}s", f"{os.path.getsize(os.path.join(OUT, name)) // 1024} KB")


def beds(src):
    for name, ident, start, dur, cross, stereo, rms_db, (lo, hi) in BEDS:
        x, sr = load(src, ident)
        x = x[int(start * sr): int((start + dur + cross) * sr)]
        if not stereo or x.shape[1] == 1:
            x = x.mean(1, keepdims=True)
        x = band(resample(x, sr), lo, hi)
        write(name, level(loop(x, cross), rms_db), 0.6 if stereo else 0.7)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    beds(sys.argv[1])
