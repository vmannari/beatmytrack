"""Browse unretouched native captures with a matched-view comparison slider."""
from pathlib import Path
import json
import sys

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from update_forklift_cabin_catalog import OPTIONS

data = {category: [{"id": ident, "name": name, "description": description} for ident, name, description in rows] for category, rows in OPTIONS.items()}
html = r'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Forklift kits — before and after</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#101b23;color:#edf0ec;font:16px/1.5 system-ui,sans-serif}main{max-width:1160px;margin:auto;padding:28px 24px 48px}h1{font-size:clamp(26px,4vw,42px);margin:0 0 8px}p{color:#b6c3c8;max-width:900px}.controls{display:flex;gap:18px;flex-wrap:wrap;margin:24px 0}label{display:grid;gap:6px;font-size:14px}select{background:#1c2b34;color:#f0f1ec;border:1px solid #60717b;border-radius:6px;padding:10px;font:inherit;min-width:240px}.compare{position:relative;aspect-ratio:4/3;background:#17232b;overflow:hidden;border-radius:8px}.compare img{position:absolute;inset:0;width:100%;height:100%;object-fit:contain}#before{clip-path:inset(0 50% 0 0)}#divider{position:absolute;top:0;bottom:0;left:50%;width:2px;background:#ffdb51;pointer-events:none}.badge{position:absolute;top:14px;background:#101b23d9;padding:5px 12px;border-radius:5px;font-weight:650}.old{left:14px}.new{right:14px;color:#ffdb51}.slider{display:block;width:100%;margin-top:14px;accent-color:#ffdb51}.description{min-height:2em;color:#edf0ec}button{background:#1c2b34;color:#edf0ec;border:1px solid #60717b;border-radius:6px;padding:9px 18px;font:inherit;cursor:pointer}.steps{display:flex;justify-content:space-between;margin:12px 0}a{color:#ffdb51}.note{font-size:14px;color:#9bafb7}details{margin-top:22px;color:#b6c3c8}summary{cursor:pointer;color:#edf0ec}
</style><main><h1>Forklift kits: before and after</h1>
<p>Every option, rendered in Godot from the same camera with the same Garage lighting. Drag the slider to compare. The earlier version is reconstructed from the saved task-start builders inside an isolated review process.</p>
<div class="controls"><label>Category<select id="category"><option value="hood">Engine covers</option><option value="aero">Rear guards</option><option value="rims">Wheel centres</option><option value="body">Cabin frames</option></select></label><label>Option<select id="option"></select></label></div>
<div class="compare"><img id="after" alt="Reworked kit"><img id="before" alt="Previous kit"><div id="divider"></div><span class="badge old">Before</span><span class="badge new">After</span></div>
<label>Before / after<input class="slider" id="slider" type="range" min="0" max="100" value="50"></label>
<div class="steps"><button id="previous">Previous option</button><button id="next">Next option</button></div><p class="description" id="description"></p>
<p class="note">All fourteen choices remain in each category. Existing item IDs, ownership and saved selections are retained. These desktop captures do not certify phone performance or owner appearance acceptance.</p>
<details open><summary>What changed</summary><ul><li>Whole formed engine lids replace the stacked add-ons. Vents are recessed into the panel, with hinges, a gasket and a flush latch.</li><li>Dished steel and cast wheel centres replace the stick spokes. Real apertures, rolled flanges, barrels and bolted hubs sit inside the tyre envelope.</li><li>Rear bumpers replace the factory part and attach through mounting shoes. The fence-like guards and unsupported rollers are gone.</li><li>Cabin frames use continuous bent portals, fitted feet, supported fixtures and practical roof structures. Decorative racks and crosses across the rear view are gone.</li></ul></details>
<p><a href="../../FORKLIFT_KIT_REFINEMENT_2026_11_02.md">Implementation and validation</a></p>
<script>const data=__DATA__;
const category=document.getElementById('category'),option=document.getElementById('option'),before=document.getElementById('before'),after=document.getElementById('after'),slider=document.getElementById('slider'),divider=document.getElementById('divider');
function show(){const row=data[category.value][Number(option.value)];before.src='before-review-gl/'+category.value+'-'+row.id+'.png';after.src='review-edge-final/'+category.value+'-'+row.id+'.png';document.getElementById('description').textContent=row.name+' — '+row.description;before.alt='Before: '+row.name;after.alt='After: '+row.name}
function populate(){option.replaceChildren();data[category.value].forEach((row,i)=>{const entry=document.createElement('option');entry.value=i;entry.textContent=row.name;option.append(entry)});option.value='1';show()}
category.onchange=populate;option.onchange=show;slider.oninput=()=>{before.style.clipPath='inset(0 '+(100-Number(slider.value))+'% 0 0)';divider.style.left=slider.value+'%'};
document.getElementById('previous').onclick=()=>{option.value=(Number(option.value)+13)%14;show()};document.getElementById('next').onclick=()=>{option.value=(Number(option.value)+1)%14;show()};populate();
</script></main></html>'''
(OUT / "gallery.html").write_text(html.replace("__DATA__", json.dumps(data, ensure_ascii=False)), encoding="utf-8")
print("Wrote matched native comparison gallery")
