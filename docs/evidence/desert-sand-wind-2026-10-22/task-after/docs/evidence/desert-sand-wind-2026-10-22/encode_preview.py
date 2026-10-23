"""Encode the test's actual JPEG frames as a compact animated WebP preview."""
import base64
import io
import json
import re
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parent
for renderer in ("gl_compatibility", "mobile"):
    folder = root / renderer
    source = (folder / "motion.html").read_text(encoding="utf-8")
    frames = json.loads(re.search(r"const frames=(\[.*?\]);let frame=", source).group(1))
    images = [
        Image.open(io.BytesIO(base64.b64decode(frame.split(",", 1)[1]))).convert("RGB")
        for frame in frames
    ]
    images[0].save(
        folder / "motion.webp", save_all=True, append_images=images[1:],
        duration=33, loop=0, quality=80, method=4,
    )
    print(renderer, len(images), "frames", (folder / "motion.webp").stat().st_size, "bytes")
