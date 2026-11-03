"""Deterministic synthetic water-pour foley; no external audio dependency."""
from pathlib import Path
import math
import random
import struct
import wave

rng = random.Random(304)
rate = 22050
duration = 1.45
samples = []
low = 0.0
for i in range(int(rate * duration)):
    t = i / rate
    noise = rng.uniform(-1, 1)
    low = low * .82 + noise * .18
    envelope = min(1, t / .1) * min(1, (duration - t) / .25)
    pours = .65 + .35 * math.sin(t * 8) ** 2
    value = envelope * pours * (.32 * low + .045 * noise)
    samples.append(struct.pack('<h', int(value * 32767)))
target = Path(__file__).resolve().parents[1] / 'assets/sounds/neighborhood/bath.wav'
with wave.open(str(target), 'wb') as out:
    out.setnchannels(1)
    out.setsampwidth(2)
    out.setframerate(rate)
    out.writeframes(b''.join(samples))
