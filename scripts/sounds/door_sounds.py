"""Synthesize the oven door's sound (original work, no samples): the closing thud. (A hinge
creak was tried and removed at the owner's request, 2026-11-03.)

    python3 scripts/sounds/door_sounds.py

Writes 48 kHz mono 16-bit WAVs into Packages/ClocheKit/Sources/Services/Resources/Sounds/:
  door-thud.wav   ~0.45 s: the door meeting the oven body. A low body thump (75 Hz falling to
                  55 Hz) with a short felt-damped attack, a soft latch click, and a brief rattle.
Stdlib only, seeded, so every run writes the same files.
"""
import math
import os
import random
import struct
import wave

RATE = 48000
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "Packages", "ClocheKit", "Sources", "Services",
                   "Resources", "Sounds")


def write(name, samples, peak=0.8):
    top = max(abs(s) for s in samples) or 1.0
    path = os.path.abspath(os.path.join(OUT, name))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s / top * peak * 32767)) for s in samples))
    print(f"[sounds] {os.path.relpath(path)} {len(samples) / RATE:.2f} s")


def resonator(signal, freq, decay, gain=1.0):
    """Two-pole resonant filter: rings at `freq` Hz, `decay` seconds to fall by ~60 dB."""
    r = math.exp(-6.9 / (decay * RATE))
    c = 2 * r * math.cos(2 * math.pi * freq / RATE)
    y1 = y2 = 0.0
    out = []
    for x in signal:
        y = x * gain + c * y1 - r * r * y2
        out.append(y)
        y2, y1 = y1, y
    return out


def mix(*signals):
    n = max(len(s) for s in signals)
    return [sum(s[i] for s in signals if i < len(s)) for i in range(n)]


def thud(seed=11):
    rng = random.Random(seed)
    dur = 0.45
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        f = 55 + 20 * math.exp(-t * 18)                  # the body's pitch sags as it settles
        env = (1 - math.exp(-t * 900)) * math.exp(-t * 11)
        out.append(math.sin(2 * math.pi * f * t) * env + 0.35 * math.sin(2 * math.pi * 2.03 * f * t) * env * math.exp(-t * 20))
    # Felt-damped impact: a short low noise burst.
    hit = resonator([rng.uniform(-1, 1) * math.exp(-i / RATE * 140) for i in range(n)], 180, 0.03, 0.25)
    # The latch: a soft metallic click 25 ms in, and a tiny rattle after.
    click = [0.0] * n
    for start, amp in ((0.025, 0.5), (0.052, 0.18), (0.071, 0.08)):
        i0 = int(start * RATE)
        for k in range(40):
            if i0 + k < n:
                click[i0 + k] += amp * rng.uniform(-1, 1) * (1 - k / 40)
    latch = mix(resonator(click, 2900, 0.03, 0.5), resonator(click, 4600, 0.02, 0.3))
    return [a + b + 0.6 * c for a, b, c in zip(out, hit, latch)]


if __name__ == "__main__":
    write("door-thud.wav", thud(), peak=0.85)
