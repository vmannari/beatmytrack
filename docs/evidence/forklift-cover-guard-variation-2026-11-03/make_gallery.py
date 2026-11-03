from pathlib import Path
import importlib.util, json

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
spec=importlib.util.spec_from_file_location('catalog',ROOT/'scripts/update_forklift_cabin_catalog.py')
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
choices={category:[{'id':i,'name':n,'description':d} for i,n,d in module.OPTIONS[category]] for category in ['hood','aero']}
(OUT/'choices.json').write_text(json.dumps(choices,indent=2)+'\n',encoding='utf-8')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Forklift covers and guards</title>
<style>body{margin:0;background:#101b23;color:#eef2ee;font:16px system-ui}main{max-width:1280px;margin:auto;padding:24px}h1{font-size:28px;margin:0 0 10px}p{color:#b7c6c7}nav,.buttons{display:flex;flex-wrap:wrap;gap:8px;margin:20px 0}button{font:inherit;background:#25363e;color:inherit;border:1px solid #42545c;border-radius:6px;padding:8px 12px;cursor:pointer}button.active{color:#14212a;background:#e9bd59}.compare{position:relative;width:100%;aspect-ratio:4/3}.compare img{position:absolute;inset:0;width:100%}.after{clip-path:inset(0 0 0 50%)}.labels{display:flex;justify-content:space-between;padding:12px 0}input{width:100%;accent-color:#e9bd59}h2{font-size:21px}.overview{margin-top:40px}.overview img{display:block;width:100%}</style>
<main><h1>Forklift engine covers and rear guards</h1><p>Native Garage renders. Select a category and drag the divider to compare the previous part with its new design.</p>
<nav><button id="hood" onclick="category('hood')">Engine covers</button><button id="aero" onclick="category('aero')">Rear guards</button></nav>
<div class="buttons"></div><h2 id="name"></h2><p id="description"></p>
<div class="labels"><span>Previous</span><span>Updated</span></div><div class="compare"><img id="before" alt="Previous part"><img id="after" class="after" alt="Updated part"></div><input aria-label="Before and after divider" type="range" value="50" min="0" max="100" oninput="document.querySelector('.after').style.clipPath='inset(0 0 0 '+this.value+'%)'">
<p><a style="color:#e9bd59" id="detail-link">Additional view</a></p>
<div class="overview"><h2>All updated engine covers</h2><p><a style="color:#e9bd59" href="detail-hood-overview.jpg">Lower profile views</a></p><img src="hood-overview.jpg" alt="Fourteen engine covers side by side"><h2>All updated rear guards</h2><p><a style="color:#e9bd59" href="detail-aero-overview.jpg">Straight rear views</a></p><img src="aero-overview.jpg" alt="Fourteen rear guards side by side"></div></main>
<script>const choices=CHOICES;let current='hood';function category(c){current=c;document.querySelectorAll('nav button').forEach(b=>b.classList.toggle('active',b.id===c));const buttons=document.querySelector('.buttons');buttons.replaceChildren();choices[c].forEach((choice,i)=>{let b=document.createElement('button');b.textContent=choice.name;b.onclick=()=>select(i);buttons.append(b);});select(1);}function select(i){let c=choices[current][i];document.querySelector('#name').textContent=c.name;document.querySelector('#description').textContent=c.description;document.querySelector('#before').src='before-native/'+current+'-'+c.id+'.png';document.querySelector('#after').src='native/'+current+'-'+c.id+'.png';document.querySelector('#detail-link').href='detail/'+current+'-'+c.id+'.png';document.querySelector('#detail-link').textContent=current==='hood'?'Lower profile view':'Straight rear view';document.querySelectorAll('.buttons button').forEach((b,j)=>b.classList.toggle('active',i===j));}category('hood');</script></html>'''
(OUT/'gallery.html').write_text(page.replace('CHOICES',json.dumps(choices)),encoding='utf-8')
print('Comparison gallery generated')
