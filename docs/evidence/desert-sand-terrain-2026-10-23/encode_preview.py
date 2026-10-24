"""Encode actual native frames losslessly; preserve the native fine-powder motion."""
import base64
import io
import json
import re
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parent
player = """<!doctype html><meta charset="utf-8"><title>Desert sand terrain refinement</title>
<style>body{background:#172129;color:#edf1f3;font:16px system-ui;max-width:1280px;margin:32px auto}img,canvas{width:100%}button{padding:10px}[hidden]{display:none}</style>
<p>Terrain-coloured windblown sand with shorter gaps - actual Godot frames at normal driving zoom; gust then ordinary wind</p>
<img id="view" src="motion.webp"><canvas id="still" hidden></canvas>
<button id="toggle">Pause</button><script>
const view=document.getElementById('view'),still=document.getElementById('still'),toggle=document.getElementById('toggle');
let playing=true;toggle.onclick=()=>{if(playing){still.width=view.naturalWidth;still.height=view.naturalHeight;still.getContext('2d').drawImage(view,0,0);}
playing=!playing;view.hidden=!playing;still.hidden=playing;toggle.textContent=playing?'Pause':'Play';};
</script>"""
for renderer in ("gl_compatibility", "mobile"):
    folder = root / renderer
    source = (folder / "motion.html").read_text(encoding="utf-8")
    match = re.search(r"const frames=(\[.*?\]);let frame=", source)
    if match is None:
        print(renderer, "preview already encoded")
        continue
    frames = json.loads(match.group(1))
    images = [
        Image.open(io.BytesIO(base64.b64decode(frame.split(",", 1)[1]))).convert("RGB")
        for frame in frames
    ]
    images[0].save(
        folder / "motion.webp", save_all=True, append_images=images[1:],
        duration=67, loop=0, lossless=True, method=4,
    )
    (folder / "motion.html").write_text(player, encoding="utf-8")
    print(renderer, len(images), "frames", (folder / "motion.webp").stat().st_size, "bytes")

metadata = {}
for renderer in ("gl_compatibility", "mobile"):
    path = root / renderer / "motion.webp"
    image = Image.open(path)
    duration = 0
    for frame in range(image.n_frames):
        image.seek(frame)
        image.load()
        duration += image.info["duration"]
    metadata[renderer] = {
        "native_frames": 90, "encoded_frames": image.n_frames,
        "duration_ms": duration, "bytes": path.stat().st_size,
    }
(root / "preview-encoding.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
print(json.dumps(metadata))
