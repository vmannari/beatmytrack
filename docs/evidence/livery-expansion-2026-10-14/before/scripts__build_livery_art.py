"""Original editable vector livery masks and fictional motorsport stickers.

No downloads, reference artwork, fonts, brands, or raster generation. RGB mask
channels identify accent/detail paint; the shader binds the owner's colours.
"""
from pathlib import Path
import json
import math

ROOT = Path(__file__).resolve().parents[1] / 'game/assets/liveries'
ROOT.mkdir(parents=True, exist_ok=True)
R, G = '#ff0000', '#00ff00'

def path(d, colour=R, width=None):
    return f'<path d="{d}" fill="{colour if width is None else "none"}"' + (f' stroke="{colour}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"' if width else '') + '/>'

def rect(x,y,w,h,c=R): return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{c}"/>'
def circle(x,y,r,c=R,width=None): return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c if width is None else "none"}"' + (f' stroke="{c}" stroke-width="{width}"' if width else '') + '/>'
def svg(body,w=512,h=512,view='0 0 512 512'): return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{view}">{body}</svg>\n'

patterns = []
def add(key,title,palette,art): patterns.append(dict(id=key,title=title,colours=palette,art=art))

add('apex_twin','Apex Twin',['203b50','efe5cf','cf6740'], rect(173,0,66,512)+rect(273,0,66,512)+rect(158,0,5,512,G)+rect(349,0,5,512,G))
add('offset_gt','Offset GT',['ebe3d0','193b49','d95d37'],rect(294,0,98,512)+rect(278,0,6,512,G)+rect(402,0,18,512,G)+path('M0 405H230L272 449H0',G))
add('endurance','Endurance',['1e3947','ce533c','eddbc0'],path('M110 0H402L374 512H138Z')+path('M130 0H148L166 512H150Z',G)+path('M370 0H386L362 512H346Z',G)+rect(0,360,512,28,G))
add('rally_blocks','Rally Blocks',['e5dec9','317573','d77d37'],path('M0 0H512V130L0 285Z')+path('M0 360L512 205V238L0 393Z',G)+path('M0 441L512 286V512H0Z'))
add('heritage_sweep','Heritage Sweep',['823d36','e9d5a8','d59946'],path('M-40 520C240 400 180 120 560 -30L540 100C290 224 335 416 55 560Z')+path('M-20 475C170 350 164 114 510 -35',G,9))
add('chevron','Chevron',['304d57','ddc9a0','c86e42'],''.join(path(f'M-10 {y}L256 {y+100}L522 {y}V{y+49}L256 {y+149}L-10 {y+49}Z',R if i%2==0 else G) for i,y in enumerate([-100,85,270,455])))
add('velocity','Velocity',['202e3b','4d9292','f1d399'],''.join(path(f'M-80 {y}L560 {y-220}V{y-154}L-80 {y+66}Z',R if i%3 else G) for i,y in enumerate([45,168,291,414,537,660])))
add('split_grid','Split Grid',['d9d1bc','304b59','bc593a'],rect(256,0,256,512)+''.join(rect(48+i*52,285+j*52,48,48,G if (i+j)%2==0 else '#000000') for i in range(8) for j in range(4))+rect(242,0,8,512,G))
add('contour','Contour',['234442','78a391','d7c48d'],''.join(path(f'M-80 {90+i*23}C70 {245+i*14} 152 {-130+i*33} 320 {50+i*25}S460 {460+i*7} 580 {225+i*23}',R if i%4 else G,7 if i%4 else 13) for i in range(17)))
hexes=''
for y in range(-1,6):
    for x in range(-1,7):
        cx=x*88+(44 if y%2 else 0);cy=y*76
        pts=[(cx+47*math.cos(a*math.pi/3),cy+47*math.sin(a*math.pi/3)) for a in range(6)]
        hexes+=path('M'+'L'.join(f'{a:.1f} {b:.1f}' for a,b in pts)+'Z',R if (x+y)%5 else G,5)
add('forged_hex','Forged Hex',['25323d','758c98','c69c59'],hexes+path('M230 -20L185 532H234L279 -20Z',G))
cam=''
for i in range(38):
    x=(i*137+29)%512;y=(i*83+47)%512
    cam+=path(f'M{x} {y}h56v22h28v44h-28v22h-56v-22h-28v-44h28Z',R if i%3 else G)
add('digital_camo','Digital Camo',['404c48','7e8d73','c4b998'],cam)
add('tiger','Tiger',['c47b3e','263a40','e6c79a'],''.join(path(f'M{-40 if i%2==0 else 552} {y}Q256 {y-70} {360 if i%2==0 else 152} {y+30}Q150 {y+4} {-40 if i%2==0 else 552} {y+91}Z',R if i%4 else G) for i,y in enumerate(range(-15,600,95))))
add('flame','Flame',['213e4e','d76d3f','e5bd70'],path('M0 512V210Q95 380 130 180Q170 75 191 15Q230 120 210 206Q200 255 245 305Q288 232 312 120Q330 223 342 316Q402 260 431 185Q409 403 512 270V512Z')+path('M65 512Q108 351 166 297Q158 417 222 472Q262 371 298 326Q288 448 360 512Z',G))
add('lightning','Lightning',['343b55','e1bf59','e8e1d3'],path('M326 -20L112 259H246L176 540L428 203H292Z')+path('M326 -20L112 259H246L176 540',G,9))
add('orbit','Orbit',['233b54','7b95a6','d9a15c'],''.join(f'<ellipse cx="190" cy="240" rx="{r}" ry="{r*1.55}" transform="rotate(34 190 240)" fill="none" stroke="{R if i%3 else G}" stroke-width="{12 if i%3 else 20}"/>' for i,r in enumerate([60,112,166,220,278]))+circle(190,240,21,G))
add('prism','Prism',['33465a','89b4b2','d6ae74'],path('M0 0H342L142 250Z')+path('M342 0H512V305L142 250Z',G)+path('M0 0L142 250L0 512Z',G)+path('M142 250L512 305V512H220Z')+path('M142 250L220 512H0Z', '#000000')+path('M142 250L342 0M142 250L512 305M142 250L220 512',G,5))
add('sunburst','Sunburst',['8f4d3d','d7a15c','efe1bc'],''.join(path('M256 150L'+'L'.join(f'{256+720*math.cos(a):.1f} {150+720*math.sin(a):.1f}' for a in [i*math.pi/9,(i+.46)*math.pi/9])+'Z',R if i%3 else G) for i in range(18))+circle(256,150,42,G)+circle(256,150,27,'#000000'))
add('scallop','Scallop',['254941','b8c5a3','dba967'],''.join(path(f'M{x-85} {y}Q{x} {y-110} {x+85} {y}',R if row%3 else G,11) for row,y in enumerate(range(-10,650,82)) for x in range(-80+(42 if row%2 else 0),650,170)))
add('herringbone','Herringbone',['303e49','b7a990','d07b4f'],''.join(path(f'M{x} {y}l70 -54v42l-70 54Z M{x+76} {y-54}l70 54v42l-70 -54Z',R if (x+y)%3 else G) for x in [-38,114,266,418] for y in range(-40,640,86)))
add('circuit','Circuit',['e4ddc8','30676d','c98343'],''.join(path(f'M{x} -20V{y}L{x+48} {y+48}V532',R if i%2 else G,13 if i%2 else 7)+circle(x,y-22,13,R,5) for i,(x,y) in enumerate([(65,110),(144,220),(216,140),(300,300),(379,180),(459,260)])))

catalog=[]
for p in patterns:
    body=rect(0,0,512,512,'#000000')+p['art']
    (ROOT/(p['id']+'.svg')).write_text(svg(body),encoding='utf-8')
    preview=body.replace('#000000','#'+p['colours'][0]).replace(R,'#'+p['colours'][1]).replace(G,'#'+p['colours'][2])
    (ROOT/(p['id']+'_preview.svg')).write_text(svg(preview,160,96),encoding='utf-8')
    catalog.append({k:v for k,v in p.items() if k!='art'})
(ROOT/'catalog.json').write_text(json.dumps(catalog,indent=2)+'\n',encoding='utf-8')

# All emblems are hand-authored paths; no text rendering/font dependency.
N,C,A,W='#172c3b','#eeddbb','#d1a25b','#f6f1e6'
shield=path('M128 18L214 48V124Q208 187 128 235Q48 187 42 124V48Z',W)+path('M128 31L202 57V123Q194 181 128 219Q61 177 54 123V57Z',N)
star=lambda x,y,r: path('M'+'L'.join(f'{x+(r if i%2==0 else r*.44)*math.sin(i*math.pi/5):.2f} {y-(r if i%2==0 else r*.44)*math.cos(i*math.pi/5):.2f}' for i in range(10))+'Z',A)
stickers=[
('crest','BMT Crest',shield+path('M75 83H113V106H95V122H117V145H75Z M125 83H143L159 107L175 83H192V145H173V117L159 138L143 117V145H125Z',C)+path('M77 159H178L164 177H92Z',A)+star(128,192,12)),
('roundel','Race 07',circle(128,128,108,W)+circle(128,128,96,N)+circle(128,128,86,C)+path('M62 82H108V170H62Z M75 99V153H95V99Z',N)+path('M119 82H192V102L153 170H131L168 102H119Z',N)+path('M68 191H185',A,7)),
('compass','Compass',circle(128,128,109,W)+circle(128,128,98,N)+circle(128,128,82,C,3)+path('M128 32L148 108L224 128L148 148L128 224L108 148L32 128L108 108Z',C)+path('M128 32L128 128L148 108Z M128 128L32 128L108 148Z',A)+circle(128,128,12,N)),
('summit','Summit',path('M128 20L240 224H16Z',W)+path('M128 42L221 212H35Z',N)+path('M53 193L108 88L133 131L158 100L203 193Z',C)+path('M108 88L92 121L110 115L123 121Z',A)+path('M158 100L139 137L162 128L176 136Z',A)+path('M62 201H196',A,5)),
('bolt','High Voltage',shield+path('M141 50L79 139H122L107 202L179 109H137Z',A)+path('M141 50L79 139H122',C,4)),
('phoenix','Phoenix',path('M128 228Q57 171 20 41L97 95L81 28L128 78L175 28L159 95L236 41Q199 171 128 228Z',W)+path('M128 213L44 70L109 114L101 58L128 94L155 58L147 114L212 70Z',N)+path('M128 176L78 101L118 131L128 104L138 131L178 101Z',A)+path('M117 88H139L128 112Z',C)),
('skull','Ghost Rider',path('M62 202L194 55M62 55L194 202',W,22)+path('M47 184L66 203M47 70L66 51M190 203L210 183M190 51L210 71',W,15)+path('M128 32C40 32 41 129 69 151L88 169V208H168V169L187 151C215 129 216 32 128 32Z',W)+path('M70 112Q87 81 112 111L107 140H84Z M144 111Q169 81 186 112L172 140H149Z M128 130L117 155H139Z',N)+path('M105 176V200M128 174V203M151 176V200',N,8)),
('orbital','Orbital',circle(128,128,96,W)+circle(128,128,86,N)+circle(128,128,52,A)+f'<ellipse cx="128" cy="128" rx="116" ry="34" transform="rotate(-28 128 128)" fill="none" stroke="{W}" stroke-width="12"/>'+star(183,66,16)+circle(109,110,13,C)),
('laurel','Laurel',circle(128,128,75,N)+star(128,118,41)+path('M103 179H153',C,7)+''.join(f'<ellipse cx="{128+s*(72-0.15*(y-126))}" cy="{y}" rx="11" ry="23" transform="rotate({s*38} {128+s*(72-0.15*(y-126))} {y})" fill="{C}" stroke="{N}" stroke-width="4"/>' for s in [-1,1] for y in [57,88,119,150,181])+path('M116 224Q48 191 54 63M140 224Q208 191 202 63',A,6)),
('piston','Piston Club',circle(128,128,110,W)+circle(128,128,99,N)+path('M86 44H170V114H86Z',C)+path('M80 64H176M80 83H176M80 102H176',N,7)+path('M114 115H142V174H114Z',A)+circle(128,187,31,C)+circle(128,187,16,N)+path('M96 52H160',A,5)),
('checker','Checkered Flag',path('M40 218L73 32',W,14)+path('M78 40Q132 16 175 42Q205 61 232 47L215 153Q185 167 159 149Q110 126 61 151Z',W)+''.join(rect(78+i*29,48+j*29,28,28,N) for i in range(5) for j in range(3) if (i+j)%2==0)+path('M78 40Q132 16 175 42Q205 61 232 47L215 153Q185 167 159 149Q110 126 61 151Z',A,5)),
('sun','Desert Sun',circle(128,128,99,N)+''.join(path(f'M{128+78*math.sin(i*math.pi/8):.1f} {128-78*math.cos(i*math.pi/8):.1f}L{128+109*math.sin(i*math.pi/8):.1f} {128-109*math.cos(i*math.pi/8):.1f}',C,9) for i in range(16))+circle(128,128,61,A)+path('M69 148Q128 97 188 148M79 170Q128 139 178 170',N,8)),
]
atlas=''
for i,(key,title,art) in enumerate(stickers):
    # 16px gutters avoid neighbouring emblems bleeding through mip levels.
    atlas+=f'<g transform="translate({i%4*256+16} {i//4*256+16}) scale(.875)">{art}</g>'
    (ROOT/(key+'_sticker.svg')).write_text(svg(art,128,128,'0 0 256 256'),encoding='utf-8')
(ROOT/'stickers.svg').write_text(svg(atlas,1024,768,'0 0 1024 768'),encoding='utf-8')
(ROOT/'stickers.json').write_text(json.dumps([{'id':k,'title':t} for k,t,_ in stickers],indent=2)+'\n',encoding='utf-8')
print(f'Authored {len(patterns)} livery masks/previews and {len(stickers)} fictional stickers.')
