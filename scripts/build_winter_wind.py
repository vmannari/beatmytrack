"""Master the owner-supplied blizzard recording into faithful, varied Winter loops."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess

import numpy as np
from audio_loop_mastering import crossfade
from build_desert_ambience import level_wind, write

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "game/assets/audio/ambience"
SOURCE = ROOT / "build/winter_owner_wind/sources"
LEVELS = ROOT / "build/winter_owner_wind/levels"
RATE = 44100
SOURCE_HASH = "65f21e931e6ee233972d765fc7f8323c4319bf3067d2e5724577119ea3c171cc"
REGIONS = [("winter_gale_a.wav", 0.3, 17.0), ("winter_gale_b.wav", 2.0, 15.0)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--decode", action="store_true")
    args = parser.parse_args()
    if hashlib.sha256((SOURCE / "blizzard.mp3").read_bytes()).hexdigest() != SOURCE_HASH:
        raise ValueError("Owner blizzard source changed; review before rebuilding")
    if args.decode:
        command = "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/decode_storm_rain_source.gd -TestArgument @('--source-path=res://../build/winter_owner_wind/sources/blizzard')"
        subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command], cwd=ROOT, check=True)
    decode = json.loads((SOURCE / "blizzard.decode.json").read_text())
    raw = (SOURCE / "blizzard.f32").read_bytes()
    if hashlib.sha256(raw).hexdigest() != decode["sha256"]:
        raise ValueError("Decoded blizzard checksum changed")
    source = np.frombuffer(raw, dtype="<f4").astype(np.float64)
    if decode["rate"] != RATE:
        positions = np.arange(round(len(source) * RATE / decode["rate"]), dtype=np.float64) * decode["rate"] / RATE
        source = np.interp(positions, np.arange(len(source), dtype=np.float64), source)
    BANK.mkdir(parents=True, exist_ok=True)
    LEVELS.mkdir(parents=True, exist_ok=True)
    clips = []
    for filename, start, duration in REGIONS:
        if start + duration > len(source) / RATE: raise ValueError("Blizzard region exceeds owner recording")
        region = source[round(start * RATE):round((start + duration) * RATE)].copy()
        loop = crossfade(region, RATE, seconds=1.5)
        loop, gain = level_wind(loop)
        profile = gain.astype("<f4").tobytes()
        (LEVELS / (filename + ".gain.f32")).write_bytes(profile)
        item = write(filename, loop, len(loop) / RATE, -23, peak_db=-5, recorded=True)
        item.update(source_start_seconds=start, source_duration_seconds=duration, overlap_seconds=1.5,
                    levelling=dict(rms_window_seconds=0.75, gain_smoothing_seconds=0.5, minimum_gain=0.45, maximum_gain=4.0,
                                   gain_profile_sha256=hashlib.sha256(profile).hexdigest()))
        clips.append(item)
    manifest = dict(author="Filename attribution: Dragon Studio; owner-supplied recording",
                    origin="Owner-requested local edit; original pitch/tone with no EQ, added wind or synthetic layers",
                    owner_source=dict(filename="dragon-studio-blizzard-wind-463217.mp3", sha256=SOURCE_HASH,
                                      decoded_sha256=decode["sha256"], seconds=decode["source_seconds"],
                                      license="Original licence metadata not supplied; no CC0 licence inferred"),
                    design="Two overlapping recorded regions; mono44.1kHz16-bit PCM; gentle circular RMS levelling/DC/level matching/-5dBFS peak cap/1.5s power-preserving joins/zero-step energy-matched seams. Runtime phase/gain/gust variation retained.",
                    clips=clips, total_bytes=sum(item["bytes"] for item in clips))
    (BANK / "winter_wind_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__": main()
