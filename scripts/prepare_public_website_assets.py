"""Optimise existing, cleared project images for the public website.

Run with the existing .tools/review Python environment (Pillow). No new art or
runtime dependency is introduced. Preserve source framing and record provenance.
"""
import hashlib
import json
from pathlib import Path
from shutil import copyfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "backend/bmt_backend/public_ui"
SOURCES = {
    "forest-drive-v1.webp": "game/assets/menu/challenges/entry-find-play-v3.png",
    "winter-race-v1.webp": "docs/evidence/winter-road-edge-snow-2026-10-24/mobile/after.png",
    "track-editor-v1.webp": "docs/evidence/editor-visual-review-2026-10-16/mobile/02-track-1280.png",
    "garage-v1.webp": "docs/evidence/garage-parts-focus-2026-10-25/test_customisation_carousel-gl_compatibility-focus/app-kits-1280.png",
    "worlds-v1.webp": "game/assets/menu/discovery-biomes.png",
}
FONTS = {
    "Barlow-Regular.ttf": "game/assets/fonts/Barlow-Regular.ttf",
    "BarlowCondensed-SemiBold.ttf": "game/assets/fonts/BarlowCondensed-SemiBold.ttf",
    "font-license.txt": "game/assets/fonts/OFL.txt",
}


def fingerprint(path):
    return {"path": path.relative_to(ROOT).as_posix(), "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    DESTINATION.mkdir(parents=True, exist_ok=True)
    records = []
    for filename, source in SOURCES.items():
        original, output = ROOT / source, DESTINATION / filename
        with Image.open(original) as picture:
            picture.convert("RGB").save(output, "WEBP", quality=82, method=6)
            records.append({"source": fingerprint(original), "output": fingerprint(output),
                            "size": picture.size, "processing": "WebP quality=82 method=6; no crop or resize"})
    for filename, source in FONTS.items():
        original, output = ROOT / source, DESTINATION / filename
        copyfile(original, output)
        records.append({"source": fingerprint(original), "output": fingerprint(output),
                        "processing": "Unmodified copy; SIL Open Font License 1.1 included"})
    report = ROOT / "docs/evidence/game-website-2026-10-25/assets.json"
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps({"pillow_version": Image.__version__, "assets": records}, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"images": len(SOURCES), "fonts_and_license": len(FONTS),
                      "total_bytes": sum(record["output"]["bytes"] for record in records)}))


if __name__ == "__main__":
    main()
