"""Generate original, deterministic PCM sound effects without external libraries."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RATE = 22050
ROOT.mkdir(parents=True, exist_ok=True)


def save(name, samples):
    values = [max(-0.95, min(0.95, x)) for x in samples]
    with wave.open(str(ROOT / (name + ".wav")), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", round(x * 32767)) for x in values))
    print(name, "seconds", round(len(values) / RATE, 2), "peak", round(max(abs(x) for x in values), 3))


def chirp(name, duration, low, high, volume):
    samples = []
    phase = 0.0
    for i in range(int(RATE * duration)):
        u = i / (RATE * duration)
        phase += math.tau * (low + (high - low) * u) / RATE
        envelope = min(1.0, u * 30) * (1 - u) ** 1.6
        samples.append(volume * envelope * (math.sin(phase) + 0.15 * math.sin(2 * phase)))
    save(name, samples)


chirp("jump", 0.17, 280, 600, 0.30)
chirp("land", 0.12, 130, 65, 0.24)
rng = random.Random(42)
noise = 0.0
splash = []
for i in range(int(RATE * 0.65)):
    u = i / (RATE * 0.65)
    noise = noise * 0.72 + rng.uniform(-1, 1) * 0.28
    splash.append(0.6 * noise * min(1, u * 45) * (1 - u) ** 1.5 + 0.08 * math.sin(i / RATE * math.tau * (95 - 40 * u)) * (1 - u) ** 3)
save("splash", splash)

for name, notes, duration in [("checkpoint", [523.25, 659.25, 783.99], 0.18),
                              ("victory", [523.25, 659.25, 783.99, 1046.5], 0.23)]:
    samples = [0.0] * int(RATE * (len(notes) * duration + 0.5))
    for index, frequency in enumerate(notes):
        for i in range(int(RATE * 0.5)):
            t = i / RATE
            envelope = min(1, t * 120) * math.exp(-t * 8)
            samples[int(index * duration * RATE) + i] += 0.22 * envelope * (math.sin(math.tau * frequency * t) + 0.25 * math.sin(math.tau * frequency * 2 * t))
    save(name, samples)

# Circular smoothing makes a periodic broadband stream instead of a low hum.
count = RATE * 5
raw = [rng.uniform(-1, 1) for _ in range(count)]
samples = []
for i in range(count):
    filtered = sum(raw[(i - k) % count] * (8 - k) for k in range(8)) / 36
    samples.append(0.4 * filtered * (0.82 + 0.18 * math.sin(math.tau * i / count)))
save("river", samples)
