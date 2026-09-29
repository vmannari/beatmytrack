#!/usr/bin/env python3
"""Peak-safe constant-gain audition groups. Requires FFmpeg; never overwrites."""
import argparse
import hashlib
import html
import json
import math
import re
import shutil
import subprocess
from pathlib import Path
from urllib.parse import quote

def sha256(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1048576), b""):
            h.update(block)
    return h.hexdigest()

def measure(path):
    result = subprocess.run(["ffmpeg", "-nostdin", "-hide_banner", "-i", str(path),
        "-af", "loudnorm=print_format=json", "-f", "null", "-"],
        capture_output=True, text=True, check=True)
    matches = re.findall(r'\{[^{}]*"input_i"[^{}]*\}', result.stderr, re.S)
    if not matches:
        raise ValueError("No loudness measurement: " + str(path))
    data = json.loads(matches[-1])
    values = float(data["input_i"]), float(data["input_tp"])
    if not all(math.isfinite(v) for v in values):
        raise ValueError("Silent or invalid audio: " + str(path))
    return values

def plan_gains(measurements, target, ceiling):
    if not measurements or not all(math.isfinite(v) for pair in measurements for v in pair):
        raise ValueError("Invalid measurements")
    if not math.isfinite(target) or not math.isfinite(ceiling) or ceiling > 0:
        raise ValueError("Invalid loudness target or peak ceiling")
    common = min(target, *(lufs + ceiling - peak for lufs, peak in measurements))
    return common, [common - lufs for lufs, peak in measurements]

def build_pack(inputs, output, target=-20.0, ceiling=-1.0):
    sources = [Path(p).resolve(strict=True) for p in inputs]
    out = Path(output).resolve()
    if out.exists():
        raise FileExistsError("Use a fresh output directory: " + str(out))
    if not sources or len(set(sources)) != len(sources) or not all(p.is_file() for p in sources):
        raise ValueError("Inputs must be distinct audio files")
    if any(p == out or out in p.parents for p in sources):
        raise ValueError("Output overlaps an input")
    if not shutil.which("ffmpeg"):
        raise RuntimeError("FFmpeg is required; no unmatched fallback copies are produced")
    measurements = [measure(p) for p in sources]
    common, gains = plan_gains(measurements, target, ceiling)
    hashes = [sha256(p) for p in sources]
    out.mkdir(parents=True, exist_ok=False)
    audio = out / "audio"
    audio.mkdir()
    records = []
    for index, (src, measured, gain, original_hash) in enumerate(zip(sources, measurements, gains, hashes), 1):
        dst = audio / (str(index).zfill(2) + ".wav")
        subprocess.run(["ffmpeg", "-nostdin", "-n", "-hide_banner", "-loglevel", "error",
            "-i", str(src), "-map", "0:a:0", "-vn", "-af", f"volume={gain:.9f}dB",
            "-c:a", "pcm_f32le", str(dst)], check=True)
        actual_lufs, actual_peak = measure(dst)
        if actual_peak > ceiling + 0.1 or abs(actual_lufs - common) > 0.2:
            raise ValueError("Export failed loudness/headroom verification; partial pack retained")
        if sha256(src) != original_hash:
            raise ValueError("Source changed during export")
        records.append(dict(id=index, source=str(src), source_sha256=original_hash,
            audition_file=dst.relative_to(out).as_posix(), audition_sha256=sha256(dst),
            source_lufs=measured[0], source_true_peak_db=measured[1], gain_db=gain,
            actual_lufs=actual_lufs, actual_true_peak_db=actual_peak))
    report = dict(common_target_lufs=common, peak_ceiling_db=ceiling, candidates=records)
    (out / "manifest.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    cards = []
    for item in records:
        name = html.escape(Path(item["source"]).name)
        url = quote(item["audition_file"], safe="/")
        cards.append(f'<h2>{item["id"]}: {name}</h2><audio controls src="{url}"></audio>')
    page = '<!doctype html><meta charset="utf-8"><title>Music auditions</title><h1>Music auditions</h1><p>Constant gain; sources preserved. Musical quality awaits listening.</p>' + ''.join(cards)
    (out / "index.html").write_text(page, encoding="utf-8")
    return report

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+")
    parser.add_argument("--out", required=True)
    parser.add_argument("--target-lufs", type=float, default=-20.0)
    parser.add_argument("--peak-ceiling", type=float, default=-1.0)
    args = parser.parse_args()
    build_pack(args.inputs, args.out, args.target_lufs, args.peak_ceiling)
    print(Path(args.out) / "index.html")

if __name__ == "__main__":
    main()
