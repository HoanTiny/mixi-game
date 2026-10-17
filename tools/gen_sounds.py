"""Tổng hợp âm thanh tạm cho màn phố vào assets/sounds/ (wav 22 kHz, mono, 16 bit).

Đây chỉ là tiếng giả để game có âm thanh ngay. Thay bằng file thu thật cùng tên khi có.
Chạy: python tools/gen_sounds.py   (cần numpy)
Các vòng lặp (traffic, rain, night) tạo bằng nhiễu tuần hoàn nên lặp lại không bị tách tiếng.
"""

import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds")
rng = np.random.default_rng(7)


def save(name, x, peak=0.8):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print(name, f"{len(x) / RATE:.2f}s")


def shaped_noise(seconds, shape):
    """Nhiễu tuần hoàn có phổ theo hàm shape(tần số) -> biên độ. Đầu và cuối nối liền."""
    n = int(seconds * RATE)
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / RATE)
    return np.fft.irfft(spec * shape(np.maximum(f, 1.0)), n)


def env(n, attack, release):
    e = np.ones(n)
    a, r = int(attack * RATE), int(release * RATE)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def add_wrapped(buf, sig, start):
    idx = (np.arange(len(sig)) + start) % len(buf)
    np.add.at(buf, idx, sig)


def ping(freq, seconds, decay):
    t = np.arange(int(seconds * RATE)) / RATE
    return np.sin(2 * np.pi * freq * t) * np.exp(-t / decay)


def traffic():
    # Tiếng ù của phố: nhiễu trầm, cộng tiếng máy xe máy lướt qua (máy nổ 25 đến 40 Hz, có hài).
    secs = 12
    x = shaped_noise(secs, lambda f: 1 / f ** 0.9 * np.exp(-f / 900)) * 3
    n = len(x)
    for _ in range(9):
        dur = rng.uniform(2.5, 4.5)
        m = int(dur * RATE)
        t = np.arange(m) / RATE
        base = rng.uniform(25, 40) * (1 + 0.08 * np.linspace(1, -1, m))  # đổi cao độ khi xe lướt qua
        phase = 2 * np.pi * np.cumsum(base) / RATE
        engine = sum(np.sin(k * phase) / k for k in range(1, 7)) * (1 + 0.3 * np.sin(2 * np.pi * 7 * t))
        bell = np.sin(np.pi * t / dur) ** 2
        add_wrapped(x, engine * bell * rng.uniform(0.3, 0.6), rng.integers(n))
    return x


def rain():
    # Mưa rào trên mái tôn: nhiễu sáng cộng tiếng hạt mưa gõ kim loại.
    secs = 10
    x = shaped_noise(secs, lambda f: np.exp(-((np.log(f) - np.log(2500)) ** 2) / 1.6))
    n = len(x)
    for _ in range(900):
        drop = ping(rng.uniform(1800, 4200), 0.05, 0.008) * rng.uniform(0.2, 1.0)
        add_wrapped(x, drop * 0.25, rng.integers(n))
    return x


def night():
    # Đêm trong hẻm: dế kêu từng tràng, nền rất êm.
    secs = 8
    x = shaped_noise(secs, lambda f: 1 / f * np.exp(-f / 400)) * 0.6
    n = len(x)
    for freq, every in [(4700, 0.9), (5200, 1.3)]:
        start = rng.uniform(0, every)
        while start < secs:
            for k in range(4):
                chirp = ping(freq, 0.03, 0.012)
                add_wrapped(x, chirp * 0.18, int((start + k * 0.045) * RATE))
            start += every * rng.uniform(0.8, 1.2)
    return x


def horn():
    # Còi xe máy: hai sóng vuông lệch nhau, bóp hai lần.
    out = []
    for dur in (0.14, 0.26):
        t = np.arange(int(dur * RATE)) / RATE
        s = np.sign(np.sin(2 * np.pi * 410 * t)) + np.sign(np.sin(2 * np.pi * 515 * t))
        s = np.convolve(s, np.ones(6) / 6, mode="same") * env(len(t), 0.005, 0.03)
        out += [s, np.zeros(int(0.06 * RATE))]
    return np.concatenate(out)


def step():
    n = int(0.09 * RATE)
    s = rng.standard_normal(n) * np.exp(-np.arange(n) / RATE / 0.018)
    return np.convolve(s, np.ones(10) / 10, mode="same")


def earn():
    return np.concatenate([ping(1320, 0.12, 0.05), ping(1760, 0.35, 0.12)])


def spend():
    return np.concatenate([ping(660, 0.12, 0.05), ping(440, 0.3, 0.1)])


def dialog():
    t = np.arange(int(0.16 * RATE)) / RATE
    return np.sin(2 * np.pi * (700 + 500 * t / 0.16) * t) * np.exp(-t / 0.04)


def done():
    return np.concatenate([ping(f, 0.13, 0.08) for f in (523, 659)] + [ping(784, 0.45, 0.18)])


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("traffic.wav", traffic(), 0.6)
    save("rain.wav", rain(), 0.6)
    save("night.wav", night(), 0.5)
    save("horn.wav", horn())
    save("step.wav", step(), 0.6)
    save("earn.wav", earn())
    save("spend.wav", spend())
    save("dialog.wav", dialog(), 0.5)
    save("done.wav", done())
