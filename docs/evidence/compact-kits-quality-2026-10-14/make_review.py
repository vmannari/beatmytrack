"""Offline gallery of actual native kit photographs and production Garage views."""
from pathlib import Path
import json
import re

here = Path(__file__).resolve().parent
root = here.parents[2]
source = (root / "game/vehicle/vehicle_customisation.gd").read_text()
options = {}
for category in ["hood", "aero", "rims", "body"]:
    start = source.index('"' + category + '":[') + len(category) + 3
    depth = 0
    end = start
    for index in range(start, len(source)):
        if source[index] == "[": depth += 1
        if source[index] == "]": depth -= 1
        if depth == 0:
            end = index + 1
            break
    options[category] = re.findall(r'\["([a-z_]+)","([^"]+)"\]', source[start:end])
assert [len(options[key]) for key in options] == [10, 13, 10, 10]

html = r'''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Compact kits · native model review</title>
<style>
:root{color-scheme:dark;font:16px system-ui;background:#101b23;color:#edf1f3}*{box-sizing:border-box}
body{margin:0;padding:24px;max-width:1700px;margin-inline:auto}h1{font-size:26px;margin:0 0 8px}
p{color:#a6b1b8;margin:0 0 20px}button,select,a{font:inherit}button,select{background:#24333e;color:#edf1f3;border:1px solid #455766;border-radius:8px;padding:10px 16px;cursor:pointer}
button[aria-pressed=true]{border-color:#bbcbd6;background:#435565}nav{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:16px}
main{display:grid;grid-template-columns:minmax(480px,2fr) minmax(320px,1fr);gap:20px;align-items:start}
.viewer{position:sticky;top:16px;border:1px solid #35434e;border-radius:12px;overflow:hidden;background:#172129}
.viewer img{display:block;width:100%;aspect-ratio:1.6;object-fit:contain;background:#101820}
.bar{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;padding:16px}
.views{display:flex;gap:6px;flex-wrap:wrap}.views button{padding:7px 12px}.cards{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.card{padding:0;overflow:hidden;text-align:center;border-radius:10px}.card img{width:100%;display:block;aspect-ratio:3.43;object-fit:contain;background:#15232e}.card span{display:block;padding:10px 6px}
.footer{padding:14px 16px;font-size:14px;color:#a6b1b8;border-top:1px solid #35434e}.footer a{color:#d0dbe3}
@media(max-width:920px){body{padding:16px}main{grid-template-columns:1fr}.viewer{position:static}.cards{grid-template-columns:repeat(auto-fill,minmax(160px,1fr))}}
</style>
<h1>Compact kits · native model review</h1>
<p>43 choices, photographed from the actual models. Select a kit to inspect its full car, rear and close-up views.</p>
<nav id="categories" aria-label="Part category"></nav>
<main><section class="viewer"><img id="hero" alt="Actual compact in the Garage"><div class="bar"><strong id="name"></strong><select id="renderer" aria-label="Renderer"><option value="compatibility">Compatibility</option><option value="mobile">Mobile / Vulkan</option></select></div><nav class="views bar" id="views" aria-label="Camera view"></nav><div class="footer"><a id="full" target="_blank">Open full-size photograph</a> · These are desktop native captures. Owner and physical-phone quality review remain.</div></section><section id="cards" class="cards" aria-label="Available kits"></section></main>
<script>
const options = OPTIONS_JSON;
const labels={hood:'Hoods',aero:'Spoilers & rear wings',rims:'Rims',body:'Body kits'};
let category='body',selected='endurance',view='front';
const byId=id=>document.getElementById(id);
function updateHero(){const renderer=byId('renderer').value;const path=`${renderer}/${category}/${selected}-${view}.png`;byId('hero').src=path;byId('full').href=path;byId('name').textContent=options[category].find(x=>x[0]===selected)[1];
byId('views').replaceChildren();for(const [key,label] of [['front','Full car'],['rear','Rear'],['detail','Detail'],...(category==='body'?[['diffuser','Lower rear']]:[])]){const button=document.createElement('button');button.textContent=label;button.setAttribute('aria-pressed',view===key);button.onclick=()=>{view=key;updateHero()};byId('views').append(button)}}
function render(){for(const button of byId('categories').children)button.setAttribute('aria-pressed',button.dataset.category===category);byId('cards').replaceChildren();const renderer=byId('renderer').value==='compatibility'?'gl_compatibility':'mobile';
for(const [id,name] of options[category]){const button=document.createElement('button');button.className='card';button.setAttribute('aria-pressed',selected===id);const photo=document.createElement('img');photo.src=`../../../game/assets/vehicles/compact_kits_v1/previews/${renderer}/${category}_${id}.png`;photo.alt='Native photograph: '+name;const label=document.createElement('span');label.textContent=name;button.append(photo,label);button.onclick=()=>{selected=id;render()};byId('cards').append(button)}updateHero()}
for(const [key,label] of Object.entries(labels)){const button=document.createElement('button');button.textContent=label;button.dataset.category=key;button.onclick=()=>{category=key;selected=options[key][0][0];view='front';render()};byId('categories').append(button)}
byId('renderer').onchange=render;render();
</script></html>
'''
(here / "review.html").write_text(html.replace("OPTIONS_JSON", json.dumps(options)), encoding="utf-8", newline="\n")
print("Review gallery: 43 choices, both native renderers")
