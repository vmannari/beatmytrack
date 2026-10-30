"""Build original periodic fan/motor loops; no external recordings or services."""
import math
import random
import re
import struct
import wave
from pathlib import Path


def build(destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    rate, count = 44100, 88200
    for band, frequency in enumerate((42, 88, 140)):
        for mode in ("coast", "load"):
            rng = random.Random(8100 + band)
            noise = [rng.uniform(-1, 1) for _ in range(count)]
            filtered, memory = [], 0.0
            # Warm one complete noise period so the filter has a periodic boundary.
            for iteration in range(2):
                for value in noise:
                    memory += (value - memory) * 0.22
                    if iteration:
                        filtered.append(memory)
            samples = []
            for index in range(count):
                t = index / rate
                motor = sum(math.sin(math.tau * frequency * harmonic * t + harmonic * 0.37) / harmonic
                            for harmonic in range(1, 7))
                blade = math.sin(math.tau * frequency * 5 * t) * 0.14
                samples.append(motor * (0.19 if mode == "load" else 0.13)
                               + blade + filtered[index] * (0.65 if mode == "load" else 0.50))
            scale = 0.78 / max(abs(value) for value in samples)
            data = b"".join(struct.pack("<h", round(value * scale * 32767)) for value in samples)
            target = destination / f"hovercraft_{band}_{mode}.wav"
            with wave.open(str(target), "wb") as output:
                output.setparams((1, 2, rate, count, "NONE", "not compressed"))
                output.writeframes(data)
            settings = target.with_suffix(".wav.import")
            if settings.exists():
                settings.write_text(re.sub(r"compress/mode=\d+", "compress/mode=0", settings.read_text()), encoding="utf-8")
            else:
                settings.write_text('[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\ncompress/mode=0\n', encoding="utf-8")
            print(target.name, len(data), "PCM bytes")


if __name__ == "__main__":
    build(Path(__file__).resolve().parents[1] / "game/assets/audio/vehicles")
