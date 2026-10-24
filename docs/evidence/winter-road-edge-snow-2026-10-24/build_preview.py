"""Native Winter captures; no image synthesis or editing."""
from pathlib import Path
import json

E = Path(__file__).resolve().parent
data = {renderer:json.loads((E/renderer/"capture.json").read_text()) for renderer in ["mobile","gl_compatibility"]}
html = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Winter snow starting at road edges</title>
<style>body{background:#18232b;color:#e7edef;font:16px system-ui;max-width:1280px;margin:24px auto;padding:0 14px}h1{font-size:25px;font-weight:550}p{line-height:1.5;color:#c6d1d7}img{width:100%;display:block;border-radius:8px}button,select{font:inherit;background:#2b3b45;color:inherit;border:1px solid #637580;border-radius:5px;padding:8px;margin:8px 6px 16px 0}input{width:100%}</style>
<h1>Winter snow starting at road edges</h1><p>Actual Godot game captures. The existing snow streams, fine grains, colour and motion are retained; their emission windows now begin at the exposed road boundary.</p>
<label>Renderer <select id="renderer"><option value="mobile">Mobile · desktop Vulkan</option><option value="gl_compatibility">Compatibility · desktop OpenGL</option></select></label>
<img id="motion" alt="Native Winter road-edge snow animation"><button id="toggle">Pause</button><span id="time"></span><input id="seek" type="range" min="0" max="119" value="0" aria-label="Animation frame">
<p>Same camera, wind strength and clock:</p><button id="original">Previous starting points</button><button id="edges">Road-edge starting points</button><button id="clear">Without moving snow</button><img id="comparison" alt="Native same-camera comparison">
<p>The camera, wind audio and snow appearance were kept. These are desktop captures; phone/tablet appearance and performance have not been tested.</p>
<script>const data=DATA;let index=0,playing=true,mode='after.png';const renderer=document.getElementById('renderer'),motion=document.getElementById('motion'),comparison=document.getElementById('comparison'),seek=document.getElementById('seek'),button=document.getElementById('toggle');function render(){const folder=renderer.value+'/';motion.src=folder+data[renderer.value].frames[index];comparison.src=folder+mode;seek.value=index;document.getElementById('time').textContent=(index/15).toFixed(1)+' s'}renderer.onchange=()=>{index=0;render()};button.onclick=()=>{playing=!playing;button.textContent=playing?'Pause':'Play'};seek.oninput=()=>{index=Number(seek.value);render()};document.getElementById('original').onclick=()=>{mode='before.png';render()};document.getElementById('edges').onclick=()=>{mode='after.png';render()};document.getElementById('clear').onclick=()=>{mode='without-snow.png';render()};setInterval(()=>{if(playing){index=(index+1)%data[renderer.value].frames.length;render()}},1000/15);render();</script></html>
'''
(E/"preview.html").write_bytes(html.replace("DATA",json.dumps(data)).encode())
print("WINTER_EDGE_PREVIEW: built from native frames")
