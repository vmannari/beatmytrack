"""Bake original periodic motor tones; no recordings, providers or dependencies."""
import hashlib
import json
import math
import wave
from array import array
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "game/assets/audio/vehicles"


def main():
    outputs = []
    for band, frequency in enumerate((120, 480, 960)):
        for mode in ("load", "coast"):
            # Integral cycles at every partial make each one-second loop seamless.
            harmonics = ((1, .48), (2, .18), (3, .07), (7, .018))
            gain = .42 if mode == "load" else .24
            pcm = array("h")
            for index in range(44100):
                phase = math.tau * frequency * index / 44100
                value = sum(amplitude * math.sin(partial * phase) for partial, amplitude in harmonics)
                pcm.append(round(value * gain * 32767))
            path = ROOT / f"electric_{band}_{mode}.wav"
            with wave.open(str(path), "wb") as output:
                output.setparams((1, 2, 44100, 0, "NONE", "not compressed"))
                output.writeframes(pcm.tobytes())
            peak = max(abs(value) for value in pcm) / 32767
            outputs.append({"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                            "peak_dbfs": round(20 * math.log10(peak), 3)})
    (ROOT / "electric_manifest.json").write_text(json.dumps({
        "provenance": "Original procedural synthesis for Beat my track; no external recordings.",
        "generator": "scripts/build_electric_audio.py", "outputs": outputs,
    }, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
