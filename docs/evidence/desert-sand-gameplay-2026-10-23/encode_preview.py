"""Package actual native frames for review; measurements use retained PNGs."""
import base64
import io
import json
import re
from pathlib import Path

from PIL import Image, ImageSequence

root = Path(__file__).resolve().parent
metadata = {}
for renderer in ["gl_compatibility", "mobile", "focused/gl_compatibility", "focused/mobile"]:
    folder = root / renderer
    path = folder / "motion.html"
    source = path.read_text(encoding="utf-8")
    match = re.search(r"const frames=(\[.*?\]);let frame=", source)
    if match is not None:
        frames = json.loads(match[1])
        images = [Image.open(io.BytesIO(base64.b64decode(frame.split(",", 1)[1]))).convert("RGB") for frame in frames]
    else:
        with Image.open(folder / "motion.webp") as previous:
            images = [frame.convert("RGB").copy() for frame in ImageSequence.Iterator(previous)]
    compact = folder / "motion.compact.webp"
    images[0].save(compact, save_all=True, append_images=images[1:], duration=67, loop=0, lossless=False, quality=90, method=0)
    compact.replace(folder / "motion.webp")
    if match is not None:
        title = "Actual game presentation: moving driving camera and normal seeded wind; scripted route at 50 km/h" if not renderer.startswith("focused/") else "Fixed driving camera: gust then ordinary wind; focused material fixture"
        path.write_text("""<!doctype html><meta charset="utf-8"><title>Desert sand during driving</title>
<style>body{background:#172129;color:#edf1f3;font:16px system-ui;max-width:1280px;margin:32px auto}img,canvas{width:100%}button{padding:10px}[hidden]{display:none}</style>
<p>""" + title + """</p><img id="view" src="motion.webp"><canvas id="still" hidden></canvas>
<button id="toggle">Pause</button><script>
const view=document.getElementById('view'),still=document.getElementById('still'),toggle=document.getElementById('toggle');
let playing=true;toggle.onclick=()=>{if(playing){still.width=view.naturalWidth;still.height=view.naturalHeight;still.getContext('2d').drawImage(view,0,0);}
playing=!playing;view.hidden=!playing;still.hidden=playing;toggle.textContent=playing?'Pause':'Play';};</script>""", encoding="utf-8")
    animation = Image.open(folder / "motion.webp")
    duration = 0
    for frame in range(animation.n_frames):
        animation.seek(frame)
        animation.load()
        duration += animation.info["duration"]
    metadata[renderer] = {"native_frames": 90 if renderer.startswith("focused/") else 270,
                          "encoded_frames": animation.n_frames, "duration_ms": duration,
                          "bytes": (folder / "motion.webp").stat().st_size, "compression": "WebP quality90 from native JPEG94 frames"}
    print(renderer, metadata[renderer], flush=True)
(root / "preview-encoding.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
