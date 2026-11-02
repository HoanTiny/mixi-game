"""Tổng hợp tiếng động màn phố vào assets/sounds/ (ogg vorbis 22 kHz, mono).

Tiếng tự tổng hợp bằng code, không dùng bản thu của ai. Mỗi tiếng dựng theo vật thật ở phố cổ:
dép tổ ong gõ xuống gạch vỉa hè, tờ tiền polymer búng, chuông xe đạp "kính coong",
bát sứ và đũa ở quán cơm, quạt cây, xe số chạy qua. Tiếng nền (phố, mưa, đêm, loa phường) là bản thu thật ở Hà Nội,
cắt bằng tools/cut_field_recordings.py; còi xe đã có trong bản thu đó. Xem assets/sounds/NGUON.md.
Chạy: python tools/gen_sounds.py   (cần numpy, soundfile)
"""

import os

import numpy as np
import soundfile as sf

RATE = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds")
rng = np.random.default_rng(7)


def save(name, x, peak=0.8):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    path = os.path.join(ROOT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sf.write(path, x.astype(np.float32), RATE, format="OGG", subtype="VORBIS")
    print(name, f"{len(x) / RATE:.2f}s")


def secs(s):
    return np.arange(int(s * RATE)) / RATE


def band(x, lo, hi):
    """Lọc dải bằng FFT (sườn mềm bậc 4)."""
    spec = np.fft.rfft(x)
    f = np.maximum(np.fft.rfftfreq(len(x), 1 / RATE), 1.0)
    return np.fft.irfft(spec / (1 + (lo / f) ** 4) / (1 + (f / hi) ** 4), len(x))


def noise(s, lo=20, hi=10000):
    return band(rng.standard_normal(int(s * RATE)), lo, hi)


def modes(freqs, decays, amps, s):
    """Tiếng vật rắn bị gõ: tổng các mode dao động tắt dần."""
    t = secs(s)
    return sum(a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / d) for f, d, a in zip(freqs, decays, amps))


def place(buf, sig, at):
    i = int(at * RATE)
    sig = sig[: max(0, len(buf) - i)]
    buf[i:i + len(sig)] += sig
    return buf


def fade(x, a=0.003, r=0.02):
    n = len(x)
    e = np.ones(n)
    ka, kr = int(a * RATE), int(r * RATE)
    if ka:
        e[:ka] = np.linspace(0, 1, ka)
    if kr:
        e[-kr:] *= np.linspace(1, 0, kr)
    return x * e


# ------------------------------------------------------------- bước chân

def step(k):
    """Dép tổ ong trên gạch vỉa hè: gót chạm (trầm, khô), đế dép đập lại vào gót, lạo xạo cát."""
    r = np.random.default_rng(100 + k)
    out = np.zeros(int(0.24 * RATE))
    t = secs(0.05)
    heel = band(r.standard_normal(len(t)), 60, 420) * np.exp(-t / 0.012) * 1.4
    heel += np.sin(2 * np.pi * r.uniform(85, 110) * t) * np.exp(-t / 0.018) * 0.7
    place(out, heel, 0.0)
    t = secs(0.03)
    slap = band(r.standard_normal(len(t)), 900, 4200) * np.exp(-t / r.uniform(0.004, 0.007))
    place(out, slap * r.uniform(0.5, 0.8), r.uniform(0.07, 0.11))
    t = secs(0.07)
    grit = band(r.standard_normal(len(t)), 2500, 7500) * np.exp(-t / 0.02) * 0.12
    place(out, grit, 0.01)
    return fade(out, 0.001, 0.03)


def step_wet(k):
    """Bước trên vỉa hè đọng nước: tiếng lép nhép, vài giọt bắn."""
    r = np.random.default_rng(200 + k)
    out = np.zeros(int(0.3 * RATE))
    t = secs(0.16)
    splash = band(r.standard_normal(len(t)), 500, 5000) * np.exp(-t / 0.045) * (1 - np.exp(-t / 0.004))
    place(out, splash, 0.0)
    place(out, band(r.standard_normal(int(0.05 * RATE)), 80, 400) * np.exp(-secs(0.05) / 0.012), 0.0)
    for _ in range(5):
        f = r.uniform(1400, 3200)
        drop = np.sin(2 * np.pi * f * (1 + 0.6 * secs(0.04)) * secs(0.04)) * np.exp(-secs(0.04) / 0.008)
        place(out, drop * r.uniform(0.1, 0.3), r.uniform(0.02, 0.2))
    return fade(out, 0.001, 0.04)


# ------------------------------------------------------------- xe máy

def scooter_pass():
    """Xe số 110 phân chạy ngang: xung nổ ống xả qua cộng hưởng ống, tiếng lốp trên nhựa, Doppler."""
    s = 5.0
    t = secs(s)
    n = len(t)
    closeness = np.exp(-((t - 2.4) / 0.95) ** 2)
    doppler = 1.0 + 0.055 * np.tanh(-(t - 2.4) / 0.35)
    fire = 36.0 * doppler * (1 + 0.02 * np.sin(2 * np.pi * 0.7 * t))
    ph = np.cumsum(fire) / RATE
    pulses = np.zeros(n)
    idx = np.nonzero(np.diff(np.floor(ph)) > 0)[0]
    pulses[idx] = 1.0 + 0.25 * rng.standard_normal(len(idx))
    ti = secs(0.06)
    ir = sum(a * np.sin(2 * np.pi * f * ti) * np.exp(-ti / d) for f, a, d in ((115, 1.0, 0.018), (340, 0.6, 0.01), (820, 0.35, 0.006)))
    ir += band(rng.standard_normal(len(ti)), 600, 3000) * np.exp(-ti / 0.004) * 0.4
    exhaust = np.fft.irfft(np.fft.rfft(pulses, n + len(ti)) * np.fft.rfft(ir, n + len(ti)), n + len(ti))[:n]
    tyre = noise(s, 250, 1800) * 0.25
    mech = noise(s, 1500, 4500) * 0.06 * (1 + 0.5 * np.sin(2 * np.pi * fire * 2 * t))
    x = (exhaust / (np.max(np.abs(exhaust)) + 1e-9) + tyre + mech) * (0.08 + closeness)
    # Xa thì mất tiếng cao: trộn bản lọc trầm theo khoảng cách.
    far = band(x, 30, 900)
    x = far + (x - far) * closeness
    return fade(x, 0.4, 0.6)


# ------------------------------------------------------------- tiền

def flick(r, at, buf, amp=1.0):
    """Búng một tờ polymer: tiếng tách giòn rồi rung phành phạch tắt nhanh."""
    t = secs(0.012)
    snap = band(r.standard_normal(len(t)), 1800, 9000) * np.exp(-t / 0.0025)
    place(buf, snap * amp, at)
    k = r.integers(6, 11)
    for j in range(k):
        t = secs(0.006)
        c = band(r.standard_normal(len(t)), 2500, 9500) * np.exp(-t / 0.0015)
        place(buf, c * amp * 0.5 * (1 - j / k), at + 0.012 + j * r.uniform(0.006, 0.011))


def earn():
    """Nhận tiền: đếm hai tờ, tờ sau giòn hơn."""
    r = np.random.default_rng(31)
    buf = np.zeros(int(0.42 * RATE))
    rub = band(r.standard_normal(int(0.12 * RATE)), 1200, 6000) * np.sin(np.pi * secs(0.12) / 0.12) * 0.15
    place(buf, rub, 0.0)
    flick(r, 0.1, buf, 0.8)
    flick(r, 0.24, buf, 1.0)
    return fade(buf, 0.002, 0.05)


def spend():
    """Trả tiền: rút tờ tiền khỏi xấp (miết), đặt xuống mặt bàn."""
    r = np.random.default_rng(37)
    buf = np.zeros(int(0.4 * RATE))
    t = secs(0.16)
    slide = band(r.standard_normal(len(t)), 900, 5000) * np.sin(np.pi * t / 0.16) ** 2 * 0.35
    place(buf, slide, 0.0)
    flick(r, 0.15, buf, 0.55)
    t = secs(0.05)
    place(buf, band(r.standard_normal(len(t)), 150, 1200) * np.exp(-t / 0.01) * 0.35, 0.26)
    return fade(buf, 0.002, 0.05)


# ------------------------------------------------------------- giao diện

def dialog():
    """Mở lời thoại: tiếng gõ gỗ nhỏ, khô như gõ mặt bàn gỗ ở quán."""
    x = modes((760, 1980, 3150), (0.03, 0.012, 0.006), (1.0, 0.45, 0.2), 0.12)
    x += band(rng.standard_normal(len(x)), 2000, 8000) * np.exp(-secs(0.12) / 0.002) * 0.4
    return fade(x, 0.0005, 0.02)


def bell_strike(f0, s):
    """Một tiếng chuông xe đạp: chuông đồng mỏng, mỗi mode là một cặp lệch nhau chút để có tiếng ngân rung."""
    ratios, amps, decays = (1.0, 2.04, 2.77, 3.95, 5.3), (1.0, 0.55, 0.4, 0.22, 0.12), (0.9, 0.55, 0.38, 0.22, 0.12)
    t = secs(s)
    x = np.zeros(len(t))
    for r, a, d in zip(ratios, amps, decays):
        for det in (1.0, 1.0035):
            x += a * np.sin(2 * np.pi * f0 * r * det * t) * np.exp(-t / d)
    x += band(rng.standard_normal(len(t)), 3000, 9000) * np.exp(-t / 0.002) * 0.6
    return x


def done():
    """Xong việc: chuông xe đạp 'kính coong', gạt hai lần."""
    buf = np.zeros(int(1.3 * RATE))
    place(buf, bell_strike(2240, 1.1), 0.0)
    place(buf, bell_strike(2240, 1.1) * 0.8, 0.16)
    return fade(buf, 0.001, 0.2)


# ------------------------------------------------------------- xóm

def dishes():
    """Quán cơm giờ ăn: bát sứ chạm nhau, đũa gõ vào bát, thìa nhôm khua."""
    r = np.random.default_rng(53)
    buf = np.zeros(int(1.6 * RATE))
    at = 0.02
    while at < 1.3:
        kind = r.choice(["bowl", "chopstick", "spoon"], p=[0.45, 0.35, 0.2])
        if kind == "bowl":
            f = r.uniform(1500, 2600)
            s = modes((f, f * 2.6, f * 4.1), (0.09, 0.05, 0.025), (1, 0.5, 0.25), 0.35)
        elif kind == "chopstick":
            f = r.uniform(2500, 3600)
            s = modes((f, f * 1.9), (0.012, 0.006), (1, 0.4), 0.06) + band(r.standard_normal(int(0.06 * RATE)), 3000, 9000) * np.exp(-secs(0.06) / 0.002) * 0.3
        else:
            f = r.uniform(3200, 4200)
            s = modes((f, f * 1.47, f * 2.3), (0.05, 0.03, 0.02), (1, 0.6, 0.3), 0.2)
        place(buf, s * r.uniform(0.3, 1.0), at)
        at += r.uniform(0.07, 0.28)
    return fade(buf, 0.001, 0.15)


def fan():
    """Quạt cây số 3: động cơ ù 100 Hz, ba cánh quạt quạt gió (60 Hz), lồng quạt rung lạch xạch. Lặp liền 4 s."""
    s = 4.0
    t = secs(s)
    n = len(t)
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.maximum(np.fft.rfftfreq(n, 1 / RATE), 1.0)
    air = np.fft.irfft(spec / (1 + (f / 1300) ** 2) / (1 + (120 / f) ** 2), n)
    air = air / np.std(air)
    blade = 1 + 0.35 * np.sin(2 * np.pi * 60 * t) + 0.15 * np.sin(2 * np.pi * 20 * t)
    hum = 0.25 * np.sin(2 * np.pi * 100 * t) + 0.08 * np.sin(2 * np.pi * 200 * t) + 0.03 * np.sin(2 * np.pi * 300 * t)
    rattle = band(rng.standard_normal(n), 1500, 4000) * 0.05 * (np.sin(2 * np.pi * 7 * t) > 0.92)
    return air * blade * 0.5 + hum + rattle


def screw():
    """Vặn ốc trên bàn sửa đồ: tua vít kêu tách tách theo bánh cóc, va kim loại nhỏ."""
    r = np.random.default_rng(61)
    buf = np.zeros(int(0.5 * RATE))
    for j in range(5):
        c = modes((r.uniform(2800, 3400), r.uniform(5000, 6000)), (0.008, 0.004), (1, 0.5), 0.03)
        place(buf, c * (0.6 + 0.4 * r.random()), 0.03 + j * 0.055)
    place(buf, modes((1650, 3900, 6100), (0.12, 0.06, 0.03), (0.7, 0.4, 0.2), 0.25), 0.3)
    return fade(buf, 0.001, 0.05)


def sweep():
    """Chổi rơm quét sân gạch: hai nhát quét, xào xạc."""
    s = 1.3
    t = secs(s)
    out = np.zeros(len(t))
    for start, dur in ((0.0, 0.55), (0.65, 0.6)):
        k = secs(dur)
        stroke = band(rng.standard_normal(len(k)), 1800, 8000) * np.sin(np.pi * k / dur) ** 1.5
        stroke *= 1 + 0.6 * (rng.random(len(k)) < 0.02)
        place(out, stroke, start)
    return out


if __name__ == "__main__":
    for k in range(4):
        save(f"step_{k + 1}.ogg", step(k), 0.6)
        save(f"step_wet_{k + 1}.ogg", step_wet(k), 0.6)
    save("earn.ogg", earn())
    save("spend.ogg", spend())
    save("dialog.ogg", dialog(), 0.5)
    save("done.ogg", done(), 0.7)
    save("neighborhood/dishes.ogg", dishes(), 0.6)
    save("neighborhood/fan.ogg", fan(), 0.5)
    save("neighborhood/screw.ogg", screw(), 0.6)
    save("neighborhood/sweep.ogg", sweep(), 0.5)
    save("neighborhood/scooter_pass.ogg", scooter_pass(), 0.6)
