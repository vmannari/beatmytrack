from pathlib import Path
import html, importlib.util, json, shutil

evidence=Path(__file__).resolve().parent
root=evidence.parents[2]
spec=importlib.util.spec_from_file_location('forklift_catalog',root/'scripts/update_forklift_cabin_catalog.py')
catalog=importlib.util.module_from_spec(spec)
spec.loader.exec_module(catalog)
choices=[{'id':i,'name':n,'description':d} for i,n,d in catalog.OPTIONS['body']]
(evidence/'choices.json').write_text(json.dumps(choices,indent=2)+'\n',encoding='utf-8')
before=evidence/'previous'
before.mkdir(exist_ok=True)
for row in choices:
    image='body-'+row['id']+'.png'
    shutil.copy2(root/'docs/evidence/forklift-kit-refinement-2026-11-02/review-edge-final'/image,before/image)
buttons=''.join(f'<button onclick="select({idx})">{html.escape(row["name"])}</button>' for idx,row in enumerate(choices))
page='''<!doctype html><html lang="en"><meta charset="utf-8"><title>Forklift cabin frame comparison</title>
<style>body{margin:0;background:#101b23;color:#eef2ee;font:16px system-ui}main{max-width:1280px;margin:auto;padding:24px}h1{font-size:28px;margin:0 0 10px}p{color:#b7c6c7}.buttons{display:flex;flex-wrap:wrap;gap:8px;margin:20px 0}button{font:inherit;background:#25363e;color:inherit;border:1px solid #42545c;border-radius:6px;padding:8px 12px;cursor:pointer}button.active{color:#14212a;background:#e9bd59}.compare{position:relative;width:100%;aspect-ratio:4/3}img{display:block;width:100%}.compare img{position:absolute;inset:0}.after{clip-path:inset(0 0 0 50%)}.labels{display:flex;justify-content:space-between;padding:12px 0}input{width:100%;accent-color:#e9bd59}h2{font-size:21px}.overview{margin-top:40px}</style>
<main><h1>Forklift cabin frames</h1><p>Native Garage views. Drag the slider to compare the previous frame with the new construction.</p>
<div class="buttons">BUTTONS</div><h2 id="name"></h2><p id="description"></p>
<div class="labels"><span>Previous</span><span>Updated</span></div><div class="compare"><img id="before" alt="Previous frame"><img id="after" class="after" alt="Updated frame"></div><input aria-label="Before and after divider" type="range" value="50" min="0" max="100" oninput="document.querySelector('.after').style.clipPath='inset(0 0 0 '+this.value+'%)'">
<p>Updated frame: <a style="color:#e9bd59" id="front-link">Front view</a> · <a style="color:#e9bd59" id="side-link">Side view</a></p>
<div class="overview"><h2>All updated frames</h2><p><a style="color:#e9bd59" href="front-overview.jpg">Front overview</a> · <a style="color:#e9bd59" href="side-overview.jpg">Side overview</a></p><img src="cabin-overview.jpg" alt="All fourteen cabin frames side by side"></div></main>
<script>const choices=CHOICES;function select(i){let c=choices[i];document.querySelector('#name').textContent=c.name;document.querySelector('#description').textContent=c.description;document.querySelector('#before').src='previous/body-'+c.id+'.png';document.querySelector('#after').src='native/body-'+c.id+'.png';document.querySelector('#front-link').href='front/body-'+c.id+'.png';document.querySelector('#side-link').href='side/body-'+c.id+'.png';document.querySelectorAll('button').forEach((b,j)=>b.classList.toggle('active',i===j));}select(3);</script></html>'''
(evidence/'gallery.html').write_text(page.replace('BUTTONS',buttons).replace('CHOICES',json.dumps(choices)),encoding='utf-8')
print('Gallery and baseline captures ready')
