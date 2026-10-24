"""Record a scoped source checkpoint and copy small trailer evidence locally."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil
import subprocess


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    out = root / "build/trailer-2026-10-24"
    delivery = out / "deliverables"
    evidence = root / "docs/evidence/game-trailer-2026-10-24"
    evidence.mkdir(parents=True, exist_ok=True)
    report = json.loads((delivery / "report.json").read_text(encoding="utf-8"))
    checksums = [row.rsplit(",", 1)[-1].strip() for row in (out / "frame-checksums.txt").read_text(encoding="utf-8").splitlines() if row and not row.startswith("#")]
    if len(checksums) != 1200:
        raise ValueError(f"Encoded frame count mismatch: {len(checksums)}")
    moving_shots = {}
    for row in report["timeline"]:
        if "start_tick" not in report["shots"][row["id"]]:
            continue
        first, last = round(row["start_seconds"] * 30), round(row["end_seconds"] * 30)
        unique = len(set(checksums[first:last]))
        if unique < (last - first) * 0.9:
            raise ValueError(f"Unexpected duplicate gameplay frames in {row['id']}")
        moving_shots[row["id"]] = {"decoded_frames": last - first, "unique_frame_checksums": unique}
    report["source_files_added"] = [str(p.relative_to(root)).replace("\\", "/") for p in sorted((root / "tools/trailer").glob("*")) if p.is_file()]
    report["actual_commands"] = [
        "Pinned Godot --version: 4.7.2.stable.official.ed1daf0bf",
        *[f"powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/trailer/capture.ps1 -Mode {mode}" for mode in ["gameplay", "editor", "garage", "challenge"]],
        "Pinned Godot --headless --editor --path game --import --log-file build/trailer-2026-10-24/import.log",
        "wsl.exe -e python3 '/mnt/c/Codes/Godot/Beat my track/tools/trailer/assemble.py' --ffmpeg /home/ville/.local/share/bmt-music-tools/ffmpeg",
        "python -m py_compile tools/trailer/assemble.py tools/trailer/checkpoint.py",
        "PowerShell System.Management.Automation.Language.Parser.ParseFile(capture.ps1): no errors",
        "FFmpeg final full-stream decode to null: exit 0, empty error log",
        "FFmpeg ebur128=peak=true: -16.2 LUFS integrated; -1.5 dBFS true peak",
        "FFmpeg select twelve feature frames from final MP4, scale 480x270, tile 3x4",
        "FFmpeg -map 0:v:0 -f framemd5 build/trailer-2026-10-24/frame-checksums.txt: 1200 decoded video frames",
    ]
    report["verification"]["final_audio"] = "-16.2 LUFS integrated; -1.5 dBFS true peak after AAC encoding"
    report["verification"]["encoded_video_frame_count"] = "1200 frames, counted from FFmpeg decoded-frame checksums"
    report["verification"]["moving_gameplay_frames"] = moving_shots
    report["verification"]["visual_review"] = "Native gameplay, Desert, Night, Garage, editor completion and 3×3 frames inspected; final encoded twelve-frame contact sheet inspected"
    report["corrections"] = [
        "Initial smoke capture rejected a newly added dictionary creator key. Use an explicit String key so the current strict document validator accepts it. Final smoke captures and all gameplay captures succeed.",
        "First editor capture placed part of the circuit behind the bottom tool palette. The final capture uses wider editor framing and an upper caption, preserving normal gameplay framing.",
        "Initial challenge capture could not load the concurrently added three-by-three-v5 texture import. Retained initial-challenge-import.log; refreshed the local asset import cache and recaptured. Final challenge log has no resource loading or script errors.",
        "Moved the challenge trailer caption into the gap above the rule/action panel; final capture cycles duel, group and three selections.",
    ]
    report["remaining_acceptance"] = ["Owner creative review of pacing, captions and temporary music", "Optional later gameplay sound mix or platform-specific derivatives"]
    report["source_hashes_at_delivery"] = {}
    paths = report["source_files_added"] + [
        "game/core/game.gd", "game/core/app.gd", "game/editor/track_document.gd", "game/editor/editor_canvas.gd",
        "game/vehicle/car_visual.gd", "game/vehicle/vehicle_livery.gd", "game/vehicle/vehicle_customisation.gd",
        "game/ui/car_showroom.gd", "game/ui/challenge_create.gd", "game/assets/audio/score_v1/NOTICE.txt",
    ]
    for relative in paths:
        path = root / relative
        report["source_hashes_at_delivery"][relative] = {"bytes": path.stat().st_size, "sha256": sha256(path)}
    report["source_hash_scope"] = "Source hashes describe the shared workspace at delivery. Other tasks were concurrent; no whole-workspace immutable build or physical-device certification is claimed. This task adds tools and evidence only."
    for name in ["gameplay.log", "editor.log", "garage.log", "challenge.log", "import.log", "metadata.log", "decode-check.log", "frame-checksums.txt"]:
        shutil.copyfile(out / name, evidence / name)
    for name in ["poster.jpg", "contact-sheet.jpg"]:
        shutil.copyfile(delivery / name, evidence / name)
    (evidence / "audio-levels-summary.txt").write_text("Final AAC audio: integrated -16.2 LUFS; loudness range 2.8 LU; true peak -1.5 dBFS. Full FFmpeg ebur128 log retained in build/trailer-2026-10-24/audio-levels.log.\n", encoding="utf-8")
    patch = bytearray()
    for relative in report["source_files_added"]:
        result = subprocess.run(["git", "diff", "--no-index", "--no-ext-diff", "--", "NUL", relative], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 1:
            raise RuntimeError(result.stderr.decode("utf-8", errors="replace"))
        patch.extend(result.stdout)
    patch_path = evidence / "source-checkpoint.patch"
    patch_path.write_bytes(patch)
    check = subprocess.run(["git", "apply", "--check", "--reverse", str(patch_path)], cwd=root, capture_output=True, text=True)
    if check.returncode:
        raise RuntimeError(check.stderr)
    report["source_checkpoint"] = {"path": str(patch_path.relative_to(root)).replace("\\", "/"), "sha256": sha256(patch_path), "validation": "git apply --check --reverse passes against the exact new tool files; branch and index untouched"}
    for target in [evidence / "report.json", delivery / "report.json"]:
        target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"evidence": str(evidence), "video_sha256": report["video"]["sha256"], "source_checkpoint_check": "passed"}))


if __name__ == "__main__":
    main()
