"""Assemble the offline native captures using an existing FFmpeg installation.

Run with Linux Python and the existing WSL FFmpeg, or supply a native FFmpeg.
No third-party Python packages, downloads, service access or game modifications.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

SHOTS = [
    ("01-hook", 120, "Your track. Your rules."),
    ("02-editor", 210, "Connect the road. Shape the circuit."),
    ("03-biome-pine", 42, "Grass"),
    ("03-biome-desert", 42, "Desert"),
    ("03-biome-night_city", 42, "Night"),
    ("03-biome-winter", 42, "Winter"),
    ("03-biome-storm", 42, "Storm"),
    ("04-garage", 240, "Liveries, body kits, aero and wheels"),
    ("05-challenges", 150, "One-to-one, Group races and 3×3"),
    ("06-finale", 150, "Set the challenge"),
    ("07-end", 120, "Beat My Track"),
]
FPS = 30


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def run(command: list[str], log: Path) -> str:
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    log.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}); see {log}\n{result.stdout[-1500:]}")
    return result.stdout


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    args = parser.parse_args()
    root = args.root.resolve()
    out = (args.output or root / "build/trailer-2026-10-24").resolve()
    if root not in out.parents:
        raise ValueError("Output must be inside the workspace")
    raw = out / "raw"
    frames = out / "timeline"
    delivery = out / "deliverables"
    frames.mkdir(parents=True, exist_ok=True)
    delivery.mkdir(parents=True, exist_ok=True)
    sources: dict[str, dict] = {}
    for mode, expected in [("gameplay", 8), ("editor", 1), ("garage", 1), ("challenge", 1)]:
        manifest = json.loads((raw / f"{mode}-manifest.json").read_text(encoding="utf-8"))
        if len(manifest["shots"]) != expected:
            raise ValueError(f"Incomplete {mode} manifest")
        capture_log = (out / f"{mode}.log").read_text(encoding="utf-8")
        if re.search(r"SCRIPT ERROR|Assertion failed|Parse Error|Failed loading resource|Unable to open file", capture_log):
            raise ValueError(f"Capture error in {mode}.log")
        for item in manifest["shots"]:
            sources[item["id"]] = item

    index = 0
    timeline = []
    for name, count, caption in SHOTS:
        actual = sorted((raw / name).glob("*.jpg"))
        if len(actual) != count or sources[name]["frames"] != count:
            raise ValueError(f"Frame count for {name}: {len(actual)}, expected {count}")
        if [p.name for p in actual] != [f"{i:05d}.jpg" for i in range(count)]:
            raise ValueError(f"Noncontiguous frames in {name}")
        if "start_tick" in sources[name]:
            if sources[name]["end_tick"] - sources[name]["start_tick"] != count * 4:
                raise ValueError(f"Canonical 120 Hz stepping mismatch in {name}")
        timeline.append({"id": name, "start_seconds": index / FPS, "end_seconds": (index + count) / FPS, "caption": caption})
        for original in actual:
            target = frames / f"{index:05d}.jpg"
            if not target.exists():
                os.link(original, target)
            elif not os.path.samefile(original, target):
                raise ValueError(f"Timeline already contains a different frame: {target}")
            index += 1
    if index != 1200:
        raise ValueError(f"Expected 1200 frames, got {index}")

    music = root / "game/assets/audio/score_v1/daybreak_current.ogg"
    video = delivery / "Beat-My-Track-trailer-v1.mp4"
    command = [
        args.ffmpeg, "-nostdin", "-y", "-hide_banner",
        "-framerate", "30", "-i", str(frames / "%05d.jpg"),
        "-stream_loop", "-1", "-i", str(music),
        "-filter_complex", "[0:v]eq=gamma=1.3:brightness=0.01:enable='gte(t,13.8)*lt(t,15.2)',fade=t=in:st=0:d=0.2,fade=t=out:st=39.3:d=0.7,format=yuv420p[v];[1:a]atrim=duration=40,asetpts=PTS-STARTPTS,loudnorm=I=-16:TP=-1.5:LRA=9,afade=t=in:st=0:d=0.35,afade=t=out:st=37.8:d=2.2[a]",
        "-map", "[v]", "-map", "[a]", "-t", "40", "-r", "30",
        "-c:v", "libx264", "-preset", "medium", "-crf", "18",
        "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
        "-movflags", "+faststart", "-metadata", "title=Beat My Track — Build. Customise. Challenge.",
        "-metadata", "comment=Actual native game scenes; offline editorial capture; original project score; first review cut.",
        str(video),
    ]
    print("Encoding 1200 native frames to the 40-second trailer", flush=True)
    run(command, out / "encode.log")
    # Decode every final video/audio packet, checking for corrupt output.
    run([args.ffmpeg, "-nostdin", "-hide_banner", "-v", "error", "-i", str(video), "-f", "null", "-"], out / "decode-check.log")
    metadata = run([args.ffmpeg, "-nostdin", "-hide_banner", "-i", str(video), "-map", "0:v:0", "-c", "copy", "-f", "null", "-"], out / "metadata.log")
    if "1920x1080" not in metadata or "30 fps" not in metadata or "00:00:40.00" not in metadata:
        raise ValueError("Final trailer metadata does not match 1080p / 30 fps / 40 seconds")
    run([args.ffmpeg, "-nostdin", "-hide_banner", "-i", str(video), "-vn", "-af", "ebur128=peak=true", "-f", "null", "-"], out / "audio-levels.log")
    # Contact sheet and poster are taken from the encoded deliverable.
    run([args.ffmpeg, "-nostdin", "-y", "-hide_banner", "-ss", "19", "-i", str(video), "-frames:v", "1", "-q:v", "2", str(delivery / "poster.jpg")], out / "poster.log")
    contact_frames = [60, 315, 350, 392, 434, 476, 518, 570, 690, 900, 1000, 1140]
    selection = "+".join(f"eq(n,{frame})" for frame in contact_frames)
    run([args.ffmpeg, "-nostdin", "-y", "-hide_banner", "-i", str(video), "-vf", f"select='{selection}',scale=480:270,tile=3x4", "-frames:v", "1", "-q:v", "2", str(delivery / "contact-sheet.jpg")], out / "contact-sheet.log")
    report = {
        "requirements": {"TRV01": "40-second landscape trailer with actual gameplay", "TRV02": "Native modular track creation", "TRV03": "Challenge creation formats", "TRV04": "Five biomes and changing native liveries/body kits"},
        "format": {"width": 1920, "height": 1080, "fps": 30, "frames": 1200, "seconds": 40, "video": "H.264 / yuv420p", "audio": "AAC / 48 kHz / stereo"},
        "video": {"path": str(video.relative_to(root)), "bytes": video.stat().st_size, "sha256": digest(video)},
        "timeline": timeline,
        "shots": sources,
        "music": {"path": str(music.relative_to(root)), "sha256": digest(music), "provenance": "Existing original project chamber score. Source recordings VSCO 2 Community Edition, CC0-1.0; game/assets/audio/score_v1/NOTICE.txt and manifest.json. Temporary editorial music choice for owner review."},
        "editorial": {"night_exposure": "Gamma 1.3 and brightness +0.01 in the 1.4-second Night shot to retain car visibility in the video", "transitions": "Hard match cuts between biomes and cosmetics; 0.2-second opening fade and 0.7-second closing fade", "audio": "Music-only first cut; no synthetic engine audio or voice-over"},
        "verification": {"frame_counts": "1200 contiguous JPEG captures; all 11 shot lengths match", "canonical_driving": "Every gameplay shot advances exactly four unmodified simulation ticks per output frame", "metadata": "1920x1080; 30 fps; duration 40.00 seconds", "complete_decode": "All final video and audio decoded without an error", "game_sources": "No runtime source changes required", "device_test": "No phone/tablet attachment check or device test performed"},
        "limitations": ["First creative review cut; owner pacing/music/appearance acceptance remains", "Offline challenge format picker only; no challenge was submitted and no winning result is fabricated", "Native HUD is hidden for editorial gameplay; standard overhead camera is retained", "No APK, installation, deployment, live account/backend mutation, publishing or external media upload", "Captured on Windows desktop Compatibility renderer; no physical device performance claim", "Capture logs retain sandbox certificate-store and engine shutdown resource diagnostics; they do not invalidate successful native frames"],
        "encode_command": command,
    }
    (delivery / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    chapters = "".join(f'<button data-time="{row["start_seconds"]}"><span>{row["start_seconds"]:04.1f}s</span>{row["caption"]}</button>' for row in timeline)
    html = f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Beat My Track — Trailer v1</title>
<style>*{{box-sizing:border-box}}body{{margin:0;background:#0d171c;color:#f4efe5;font:16px system-ui,sans-serif}}main{{max-width:1300px;margin:auto;padding:40px 24px}}small{{letter-spacing:.18em;color:#dbb36d}}h1{{font-weight:600;font-size:36px;margin:12px 0 24px}}video{{display:block;width:100%;background:#000;border:1px solid #344047;border-radius:8px}}p{{color:#bcc6c9;line-height:1.6}}nav{{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:8px;margin-top:24px}}button{{text-align:left;padding:14px;border:1px solid #35434a;border-radius:5px;background:#17252c;color:#eee7db;cursor:pointer}}button:hover{{border-color:#dbb36d}}button span{{display:block;font-size:12px;color:#dbb36d;margin-bottom:5px}}a{{color:#dbb36d}}img{{width:100%;margin-top:24px;border-radius:8px}}</style>
<main><small>FIRST REVIEW CUT · 40 SECONDS · 1080P</small><h1>Beat My Track</h1><video id="trailer" controls playsinline preload="metadata" poster="poster.jpg"><source src="{video.name}" type="video/mp4"></video><p>Build it. Make it yours. Set the challenge.</p><nav>{chapters}</nav><p><a href="{video.name}" download>Download MP4</a> · <a href="report.json">Capture and music credits</a></p><img src="contact-sheet.jpg" alt="Twelve frames from the trailer"></main><script>document.querySelectorAll('button[data-time]').forEach(b=>b.onclick=()=>{{const v=document.getElementById('trailer');v.currentTime=Number(b.dataset.time);v.play()}})</script></html>'''
    (delivery / "preview.html").write_text(html, encoding="utf-8")
    print(json.dumps({"video": str(video), "bytes": video.stat().st_size, "sha256": digest(video), "verified": True}), flush=True)


if __name__ == "__main__":
    main()
