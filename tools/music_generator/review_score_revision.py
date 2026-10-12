"""Like-for-like old/new race audition, using the adaptive-music skill's helper."""
from pathlib import Path
import importlib.util
import os
import argparse

ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / ".agents/skills/bmt-adaptive-music/scripts/review_pack.py"
FFMPEG_DIRECTORY = Path.home() / ".local/share/bmt-music-tools"
EVIDENCE = ROOT / "docs/evidence/upbeat-score-2026-10-07"


def main(inputs=None, destination=None):
    os.environ["PATH"] = str(FFMPEG_DIRECTORY) + os.pathsep + os.environ.get("PATH", "")
    spec = importlib.util.spec_from_file_location("bmt_review_pack", SKILL)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    result = helper.build_pack(inputs or [
        ROOT / "docs/evidence/adaptive-score-2026-10-07/horizon-clean-race-v2.wav",
        EVIDENCE / "horizon-clean-race-v3.wav",
    ], destination or EVIDENCE / "comparison-race", target=-22.0, ceiling=-2.0)
    print("MATCHED_REVIEW", result["common_target_lufs"], "LUFS", len(result["candidates"]), "equivalent 90s arrangements")


if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("inputs",nargs="*",type=Path)
    parser.add_argument("--out",type=Path)
    args=parser.parse_args()
    main(args.inputs,args.out)
