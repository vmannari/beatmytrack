"""Build a local visual review gallery from completed native captures."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/diablo-liveries-2026-11-15'
CATALOG = json.loads((ROOT/'game/assets/liveries/diablo_v3/catalog.json').read_text(encoding='utf-8'))
FONT = ROOT/'game/assets/fonts/BarlowCondensed-SemiBold.ttf'
BODY = ROOT/'game/assets/fonts/Barlow-Regular.ttf'
VEHICLES = {'compact':'RALLY','kart':'KART','forklift':'FORKLIFT','electric':'VOLT','hovercraft':'HOVER','super_rally':'SUPER RALLY'}
LANGUAGES = {'compact':'Coast roads, mountain passes & rainforest','kart':'Flames, street music & lightning','forklift':'Ports, furnaces & polished machinery','electric':'Neon cities, moonlight & tropical sunrise','hovercraft':'Pacific surf, volcanoes & Caribbean bays','super_rally':'Fire, engines & desert storms'}

sheet = Image.new('RGB',(1800,6*506+130),'#111b23')
d = ImageDraw.Draw(sheet)
d.text((28,17),'PANAMA CUSTOM PAINT 03',font=ImageFont.truetype(str(FONT),44),fill='#e8dfcf')
d.text((29,76),'18 original designs / three per car / native Godot renders',font=ImageFont.truetype(str(BODY),23),fill='#acb8bd')
for row,(vehicle,name) in enumerate(VEHICLES.items()):
    y=130+row*506
    d.text((28,y+8),name,font=ImageFont.truetype(str(FONT),30),fill='#c9ae79')
    d.text((280,y+15),LANGUAGES[vehicle],font=ImageFont.truetype(str(BODY),20),fill='#aab7bd')
    for col,item in enumerate(i for i in CATALOG if i['vehicle']==vehicle):
        image=Image.open(OUT/'gl_compatibility'/f"{item['id']}-hero.png").convert('RGB')
        image.thumbnail((592,416),Image.Resampling.LANCZOS)
        x=col*600+4
        sheet.paste(image,(x,y+51))
        d.text((x+17,y+466),item['title'],font=ImageFont.truetype(str(FONT),25),fill='#e8dfcf')
        for i,c in enumerate(item['colours']):
            d.rounded_rectangle((x+478+i*30,y+469,x+498+i*30,y+489),radius=4,fill='#'+c)
sheet.save(OUT/'collection.png')

html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Panama Custom Paint 03 - Beat my track</title><style>
@font-face{font-family:Barlow;src:url('../../../game/assets/fonts/Barlow-Regular.ttf')}@font-face{font-family:Condensed;src:url('../../../game/assets/fonts/BarlowCondensed-SemiBold.ttf')}
*{box-sizing:border-box}body{margin:0;background:#101a22;color:#e7e3da;font-family:Barlow,system-ui,sans-serif}header,main{max-width:1640px;margin:auto;padding:36px}header{border-bottom:1px solid #34424c}.eyebrow{color:#cbb082;letter-spacing:.2em;font-size:13px}h1{font:64px/1.03 Condensed,sans-serif;margin:15px 0}header p{max-width:780px;color:#b4c0c6;line-height:1.6}nav{display:flex;gap:9px;flex-wrap:wrap;margin-top:27px}button{border:1px solid #44505a;background:#172630;color:#d8e1e5;padding:11px 17px;border-radius:5px;cursor:pointer;font:inherit}button:hover,button.active{border-color:#bca06b;background:#2a353a;color:#efe3c8}section{margin-bottom:48px}h2{font:32px Condensed,sans-serif;margin:4px 0}h2 span{font:16px Barlow,sans-serif;color:#a7b6bd;margin-left:18px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:18px}.card{overflow:hidden;background:#192731;border:1px solid #34444e;border-radius:8px}.picture{width:100%;display:block;aspect-ratio:1280/900;object-fit:cover;cursor:zoom-in}.copy{padding:19px 20px 22px}.title{display:flex;justify-content:space-between;gap:15px;align-items:center}h3{font:28px Condensed;margin:0}.swatches{display:flex;gap:5px}.swatches i{width:15px;height:15px;border-radius:50%;border:1px solid #ffffff30}.copy p{font-size:14px;color:#adbdc5;line-height:1.55;min-height:65px}.views{display:flex;flex-wrap:wrap;gap:6px}.views button{font-size:12px;padding:7px 10px}footer{color:#a2b1b8;padding:20px 36px 45px;max-width:1640px;margin:auto;border-top:1px solid #34424c;font-size:13px;line-height:1.7}dialog{background:#131f28;border:1px solid #67737a;border-radius:8px;color:#eee;width:min(1400px,96vw);padding:0}dialog::backdrop{background:#070c11e8}dialog img{width:100%;display:block}dialog .toolbar{padding:15px;display:flex;justify-content:space-between;align-items:center;gap:12px}dialog strong{font:25px Condensed}@media(max-width:1050px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}h1{font-size:48px}}@media(max-width:680px){header,main{padding:22px}.grid{grid-template-columns:1fr}h2 span{display:block;margin:6px 0 15px}.copy p{min-height:0}}
</style><header><div class="eyebrow">BEAT MY TRACK / PANAMA CUSTOM PAINT 03</div><h1>Six cars.<br>Eighteen artworks.</h1><p>Three custom-painted wraps per car, inspired by Panama’s vividly decorated buses. Airbrushed scenery, hand-painted-style lettering and ornate candy-colour borders. No portraits. Every design is rendered on the actual game model; use the view buttons to inspect each side, the original artwork and the stock paint.</p><nav id="filters"></nav></header><main id="gallery"></main><footer>Original portrait-free custom-paint designs created with the built-in imagegen tool, using bus photographs only as style references. Scenery, instruments and machinery give each car its own identity. Original geometry and physical paint finishes are retained. Earlier collections remain archived. Real-money products and Garage availability remain a separate release step.<br>Every view here is a native Compatibility render. Desktop Mobile captures and check reports are retained alongside this gallery. Physical-device and owner visual acceptance remain.</footer><dialog id="lightbox"><div class="toolbar"><strong></strong><button onclick="document.querySelector('dialog').close()">Close ×</button></div><img alt=""></dialog><script>
const designs=__DATA__,vehicles=__VEHICLES__,directions=__DIRECTIONS__;
const views={hero:'Front 3/4',rear:'Rear 3/4',left:'Left',right:'Right',deck:'Overhead',stock:'Stock paint',artwork:'Artwork'};
function frameSrc(item,key){return key==='stock'?'gl_compatibility/'+item.vehicle+'-stock-hero.png':key==='artwork'?'../../../game/assets/liveries/'+item.source:'gl_compatibility/'+item.id+'-'+key+'.png'}
const gallery=document.querySelector('#gallery'),nav=document.querySelector('#filters');
function filter(id){document.querySelectorAll('section').forEach(s=>s.hidden=id!=='all'&&s.dataset.vehicle!==id);nav.querySelectorAll('button').forEach(b=>b.classList.toggle('active',b.dataset.id===id))}
for(const [id,name]of [['all','All cars'],...Object.entries(vehicles)]){const b=document.createElement('button');b.textContent=name;b.dataset.id=id;b.onclick=()=>filter(id);nav.append(b)}
function show(item,key){const dialog=document.querySelector('dialog');dialog.querySelector('strong').textContent=item.title+' / '+views[key];const im=dialog.querySelector('img');im.src=frameSrc(item,key);im.alt=item.title+' — '+views[key];dialog.showModal()}
for(const [id,name]of Object.entries(vehicles)){const section=document.createElement('section');section.dataset.vehicle=id;section.innerHTML='<h2>'+name+'<span>'+directions[id]+'</span></h2><div class="grid"></div>';gallery.append(section);for(const item of designs.filter(d=>d.vehicle===id)){const card=document.createElement('article');card.className='card';card.innerHTML='<img class="picture" loading="lazy" src="gl_compatibility/'+item.id+'-hero.png" alt="'+item.title+'"><div class="copy"><div class="title"><h3>'+item.title+'</h3><div class="swatches">'+item.colours.map(c=>'<i style="background:#'+c+'" title="#'+c+'"></i>').join('')+'</div></div><p>'+item.concept+'</p><div class="views"></div></div>';section.querySelector('.grid').append(card);let selected='hero';card.querySelector('.picture').onclick=()=>show(item,selected);for(const [key,label]of Object.entries(views)){const b=document.createElement('button');b.textContent=label;b.classList.toggle('active',key===selected);b.onclick=()=>{selected=key;card.querySelector('.picture').src=frameSrc(item,key);card.querySelector('.picture').style.objectFit=key==='artwork'?'contain':'cover';card.querySelector('.picture').alt=item.title+' — '+label;card.querySelectorAll('.views button').forEach(o=>o.classList.toggle('active',o===b))};card.querySelector('.views').append(b)}}}
document.querySelector('dialog').addEventListener('click',e=>{if(e.target===e.currentTarget)e.currentTarget.close()});filter('all');
</script></html>'''
html=html.replace('__DATA__',json.dumps(CATALOG)).replace('__VEHICLES__',json.dumps(VEHICLES)).replace('__DIRECTIONS__',json.dumps(LANGUAGES))
(OUT/'collection.html').write_text(html,encoding='utf-8')
print('DIABLO_PRESENTATION: collection.html / collection.png / 18 designs x 5 selectable views')
