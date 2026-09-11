"""Rebuild the precise reference-based framing mockup. Requires Pillow.
Run from any directory: python technical/tools/rebuild_camera_reference.py
This is image calibration, not a Godot render or a production art generator.
"""
from pathlib import Path
from PIL import Image
import json
ROOT = Path(__file__).resolve().parents[2]
UI = ROOT / "ui"
meta = json.loads((UI / "assets/camera_calibration.json").read_text())
source = Image.open(UI / meta["source"]).convert("RGB")
clean = source.copy()
for box, dy in [((20, 759, 126, 794), -40), ((1524, 758, 1658, 795), 42)]:
    x0, y0, x1, y1 = box
    clean.paste(source.crop((x0, y0 + dy, x1, y1 + dy)), (x0, y0))
result = clean.transform(source.size, Image.Transform.EXTENT,
                         tuple(meta["source_crop_px"]),
                         resample=Image.Resampling.BICUBIC)
result.save(UI / meta["derived"])
print("Rebuilt 1.15x whole-scene framing mockup; original reference unchanged.")
