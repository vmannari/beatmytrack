"""Review the native game frames against their simultaneously recorded wind."""
from pathlib import Path
import json
import wave
import numpy as np

E = Path(__file__).resolve().parent
data = {}
analysis = {}
for renderer in ("mobile", "gl_compatibility"):
    folder = E / renderer
    data[renderer] = json.loads((folder / "sync.json").read_text())
    with wave.open(str(folder / "wind-sync.wav")) as audio:
        rate = audio.getframerate()
        pcm = np.frombuffer(audio.readframes(audio.getnframes()), dtype="<i2").reshape(-1, audio.getnchannels()).astype(float) / 32768
    samples = [row for row in data[renderer]["samples"] if 2 < row["seconds"] < 15.7]
    rms = [float(np.sqrt(np.mean(pcm[max(0, int((row['seconds']-.175)*rate)):min(len(pcm), int((row['seconds']+.175)*rate))] ** 2))) for row in samples]
    analysis[renderer] = {"seconds":len(pcm)/rate, "frames":len(data[renderer]["samples"]),
                          "rms_to_lift_correlation":float(np.corrcoef(rms, [row['lift'] for row in samples])[0, 1]),
                          "note":"350 ms RMS of actual mixed wind and dune-sand recording; opening excluded. This is a local mixer check, not a device/acoustic timing measurement."}
(E / "audio-analysis.json").write_text(json.dumps(analysis, indent=2) + "\n")
html = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>More dune edges with lifted sand — native game preview</title>
<style>body{background:#172026;color:#e9e3d5;font:16px system-ui;max-width:1280px;margin:24px auto;padding:0 16px}h1{font-size:24px;font-weight:550}img{width:100%;display:block;border-radius:8px}audio{width:100%;margin:16px 0}select{font:inherit;background:#29353c;color:inherit;padding:8px;border:1px solid #738087;border-radius:5px}canvas{width:100%;height:90px}p{line-height:1.5;color:#c9d0d1}a{color:#b3d4e3}.legend{display:flex;gap:24px}b{font-weight:500}</style>
<h1>Sand rising from more dune edges</h1>
<p>Actual Godot game frames and simultaneously recorded wind. Press play to hear the gusts and watch the sand. The audio controls keep the picture and sound together when seeking.</p>
<label>Renderer <select id="renderer"><option value="mobile">Mobile · desktop Vulkan</option><option value="gl_compatibility">Compatibility · desktop OpenGL</option></select></label>
<p id="status"></p><img id="view" alt="Native Desert game frame"><audio id="sound" controls preload="metadata"></audio>
<div class="legend"><b style="color:#e5bb78">Wind lift at dune roots</b><b style="color:#a9cbd8">Wind sound gain</b></div><canvas id="plot" width="1280" height="90"></canvas>
<p>Normal game camera, original terrain colour, up to twelve edge sites and 96 particle quads. This fixed-position preview isolates weather; the <a id="drive">moving-camera capture</a> comes from a separate ordinary-driving check. Phone/tablet appearance and performance have not been tested.</p>
<p>Same camera and wind, with the previous six-site placement:</p><img id="oldPlaces" alt="Before: six sand source sites">
<p>With the expanded placement:</p><img id="newPlaces" alt="After: twelve sand source sites">
<script>const data=DATA;const select=document.getElementById('renderer'),view=document.getElementById('view'),sound=document.getElementById('sound'),status=document.getElementById('status'),plot=document.getElementById('plot'),ctx=plot.getContext('2d');let rows=[],folder='',last='';
function comparisons(){document.getElementById('oldPlaces').src=folder+'places-before.png';document.getElementById('newPlaces').src=folder+'places-after.png'}
function setup(){sound.pause();folder=select.value+'/';rows=data[select.value].samples;sound.src=folder+'wind-sync.wav';document.getElementById('drive').href=folder+'sand-in-race.png';comparisons();last='';update()}
function update(){let t=sound.currentTime||0;let row=rows[0];for(const next of rows){if(next.seconds>t)break;row=next}if(row.frame!==last){view.src=folder+row.frame;last=row.frame}status.textContent=t.toFixed(1)+' s · Wind recording '+(data[select.value].variant+1)+' · '+data[select.value].wraps+' loop crossings checked';ctx.clearRect(0,0,1280,90);ctx.fillStyle='#26343b';ctx.fillRect(0,0,1280,90);for(const [key,color,scale]of [['lift','#e5bb78',1],['wind_gain','#a9cbd8',1.7]]){ctx.strokeStyle=color;ctx.lineWidth=2;ctx.beginPath();rows.forEach((r,i)=>{const x=r.seconds/16*1280,y=85-r[key]*scale*75;i?ctx.lineTo(x,y):ctx.moveTo(x,y)});ctx.stroke()}ctx.strokeStyle='#fff';ctx.beginPath();ctx.moveTo(t/16*1280,0);ctx.lineTo(t/16*1280,90);ctx.stroke();requestAnimationFrame(update)}
select.addEventListener('change',()=>{sound.pause();folder=select.value+'/';rows=data[select.value].samples;sound.src=folder+'wind-sync.wav';document.getElementById('drive').href=folder+'sand-in-race.png';comparisons();last=''});setup();</script></html>'''
(E / "preview.html").write_bytes((html.replace("DATA", json.dumps(data)) + "\n").encode())
print(json.dumps(analysis, indent=2))
