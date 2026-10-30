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

# Second collection: deliberately different silhouettes and restrained race palettes.
add('monza_fan','Monza Fan',['ece2c8','922f36','283c4c'],path('M256 512L50 0H146Z M256 512L366 0H462Z')+path('M256 512L201 0H227Z M256 512L285 0H311Z',G))
add('nightfall','Nightfall',['1a2737','647a93','c39564'],path('M0 0H512V142Q266 386 0 241Z')+path('M0 261Q266 406 512 162V185Q266 429 0 286Z',G)+path('M0 416Q238 541 512 340V512H0Z'))
add('crossfire','Crossfire',['c5c9bc','2b4549','bb613e'],path('M0 0H116L512 396V512H396L0 116Z M396 0H512V116L116 512H0V396Z')+path('M0 49L463 512M49 0L512 463',G,7))
add('coastal_wave','Coastal Wave',['e3e1cf','377d83','d6ac62'],path('M-10 460C50 70 230 490 270 155S435 295 530 20V512H-10Z')+path('M-10 430C55 35 211 452 249 119S420 259 530 -10',G,12))
add('topo_rally','Topo Rally',['9eaa96','2b4e48','e9d7ad'],''.join(f'<ellipse cx="360" cy="145" rx="{55+i*31}" ry="{45+i*26}" transform="rotate(-24 360 145)" fill="none" stroke="{R if i%3 else G}" stroke-width="6"/>' for i in range(12))+path('M70 -10H116L217 522H171Z')+path('M58 -10L159 522',G,5))
add('saber','Saber',['24313f','be7046','e9d4b5'],path('M0 512L143 126L245 0H290L211 185L179 512Z M512 512L369 126L267 0H222L301 185L333 512Z')+path('M0 512L153 172L127 512Z M512 512L359 172L385 512Z',G))
add('checker_fade','Checker Fade',['eee3cc','28434b','bc5541'],''.join(rect(x*64,y*64,64,64,R if y<5 else G) for y in range(8) for x in range(8) if (x+y)%2==0 and (y<4 or x in range(y-4,12-y)))+rect(0,254,512,5,G))
add('pinstripe_club','Pinstripe Club',['563b49','dcc8a2','9b7b69'],''.join(rect(x,0,3,512,R) for x in range(12,512,22))+path('M154 0H358L395 512H117Z','#000000')+path('M154 0L117 512M358 0L395 512',G,7)+rect(211,0,90,512))
add('delta_wing','Delta Wing',['29434d','dfd6bb','c47146'],path('M0 0L256 340L512 0H404L256 182L108 0Z')+path('M0 175L256 512L512 175V247L312 512H200L0 247Z',G)+path('M0 405L82 512H0Z M512 405L430 512H512Z'))
add('fracture','Fracture',['686f80','253644','d7b88c'],path('M0 0H290L213 143L350 219L237 331L304 512H0Z')+path('M290 0L213 143L350 219L237 331L304 512',G,13)+path('M512 24L412 141L492 277L405 406L459 512H512Z'))
add('pulse','Pulse',['264844','96b4a0','ddbe82'],''.join(path(f'M-20 {y}H111L166 {y-48}L215 {y+42}L270 {y-71}L329 {y+21}L383 {y}H532',R if i%2 else G,12 if i%2 else 6) for i,y in enumerate([90,244,398])))
add('aero_cut','Aero Cut',['d4cfbf','37495d','b77748'],path('M0 0H512V84L0 241Z M0 332L512 175V251L0 408Z M0 472L512 315V512H0Z')+path('M0 254L512 97V107L0 264Z M0 421L512 264V274L0 431Z',G))

# Original abstract tribal graphics: sweeping hooks, carved negative space and
# substantial paint shapes. These do not reproduce cultural or sacred symbols.
def bilateral(art):
    return art+f'<g transform="translate(512 0) scale(-1 1)">{art}</g>'

fang=path('M244 -20C124 10 74 115 122 194C136 218 146 244 134 277L34 219C61 307 113 318 147 341L79 414C170 388 191 420 194 540H246C256 417 215 348 184 312C221 273 187 227 165 182C134 116 170 58 244 -20Z')
fang+=path('M230 40C164 109 154 148 180 191L198 170C180 132 188 82 230 40Z M166 347L139 386L184 369Z',G)
add('tribal_fang','Tribal Fang',['ded5bd','24333c','b65840'],bilateral(fang))

flow=path('M-36 452C43 327 151 466 199 354C250 235 82 197 73 129C65 68 142 33 221 1C88 0 7 75 35 152C60 220 237 272 156 344C126 370 31 287 -36 379Z')
flow+=path('M178 512C137 451 220 420 256 454C209 400 218 368 271 330C331 287 302 245 241 225C391 231 389 318 331 364C264 417 296 469 336 512Z')
flow+=path('M315 -16C363 110 476 84 435 190C408 252 462 319 548 312C502 278 469 260 483 216C536 83 395 132 367 -16Z')
flow+=path('M-15 419C46 324 139 439 177 355M397 20C423 93 495 124 463 190',G,7)
add('tribal_flow','Tribal Flow',['233d41','c6d3bb','bc9858'],flow)

wing=path('M253 34C164 42 80 115 -16 128C78 157 139 122 175 109C155 169 94 192 23 196C97 231 151 211 179 191C166 245 98 281 29 280C105 318 165 289 194 271C184 329 139 365 79 370C135 407 179 385 211 362C198 424 205 477 254 527C231 404 250 331 253 34Z')
wing+=path('M223 101C166 163 113 178 73 179M228 205C175 268 132 284 90 287M230 314C212 360 186 389 154 403',G,6)
add('tribal_wing','Tribal Wing',['593c4b','e1cfa9','a47352'],bilateral(wing))

thorn=path('M230 -10C112 79 193 144 174 218C150 259 66 213 -25 197C54 281 115 291 175 280C140 377 185 421 170 522H241C258 419 203 362 230 304C255 253 214 181 223 128L252 178C274 98 191 84 230 -10Z')
thorn+=path('M180 121L82 37C99 117 136 146 178 162Z M185 373L88 344C116 394 149 414 181 410Z M234 262L190 287L230 321Z',G)
add('tribal_thorn','Tribal Thorn',['263b37','9fb89d','e1c99c'],bilateral(thorn))

crest=path('M256 9C209 49 184 112 198 168L157 141C137 167 139 195 155 218L57 147C67 218 101 260 153 283L80 297C110 352 145 378 207 391C207 445 228 487 256 524C284 487 305 445 305 391C367 378 402 352 432 297L359 283C411 260 445 218 455 147L357 218C373 195 375 167 355 141L314 168C328 112 303 49 256 9Z')
crest+=path('M256 63L230 123L256 108L282 123Z M181 240L256 278L331 240L300 312L256 296L212 312Z M222 356L256 402L290 356L256 370Z',G)
crest+=path('M223 187Q256 160 289 187L273 231H239Z','#000000')
add('tribal_crest','Tribal Crest',['d5cdb9','34424b','ab6745'],crest)

surge=path('M-24 91C108 3 190 67 150 149L93 243C154 205 172 261 238 229C300 196 277 98 364 87L433 90C346 118 361 186 336 221L406 210C390 295 315 290 279 307C223 334 286 415 221 457C177 485 112 459 46 546H-26C39 423 130 428 167 418C213 405 192 362 201 324L114 366C124 294 55 300 54 254C53 192 170 73 53 118Z')
surge+=path('M341 424L412 374L382 359C420 310 469 275 531 296V362C480 327 459 365 452 412L405 434L431 449L394 500Z')
surge+=path('M29 466C82 414 155 473 198 410M289 214C321 164 334 125 382 113',G,9)
add('tribal_surge','Tribal Surge',['273345','b5bec5','b95d49'],surge)

# Different graphic families, rather than colour variations on stripe recipes.
brush=''
for i,(x,y,tilt) in enumerate([(25,65,-24),(137,140,-18),(235,227,-25),(319,345,-17),(405,461,-23)]):
    stroke=path('M-82 0L-61 6L-45 -5L-22 4L2 -3L132 5L166 20L145 24L154 35L110 37L105 48L58 42L37 51L-13 44L-54 49L-70 34L-94 26Z',R if i%2==0 else G)
    brush+=f'<g transform="translate({x} {y}) rotate({tilt})">{stroke}</g>'
add('ink_brush','Ink Brush',['e8dfca','30444c','ad6650'],brush)

splash=path('M91 132L83 62L110 101L124 55L134 112L174 86L159 130L203 142L156 155L183 202L143 177L132 235L116 180L67 218L88 169L34 151Z')
splash+=path('M363 317L336 261L361 287L378 225L390 289L450 255L425 309L483 327L428 340L451 397L402 369L393 425L374 374L320 414L343 359L288 339Z',G)
for i in range(26):
    x=(i*131+41)%512; y=(i*179+23)%512
    splash+=circle(x,y,4+(i*7)%14,R if i%3 else G)
add('paint_splash','Paint Splash',['30494a','d7c38e','b46f4d'],splash)

deco=''
for cx,cy in [(128,160),(384,160),(0,416),(256,416),(512,416)]:
    for i in range(5):
        radius=29+i*24
        deco+=path(f'M{cx-radius} {cy}A{radius} {radius} 0 0 1 {cx+radius} {cy}M{cx-radius} {cy}L{cx} {cy+128}L{cx+radius} {cy}',R if i%2 else G,5)
add('art_deco','Art Deco',['273c49','bf9e5f','e4d4b0'],deco)

optical=''
for row in range(-1,9):
    for col in range(-1,9):
        x=col*70+(35 if row%2 else 0);y=row*64
        optical+=path(f'M{x} {y}q35 -25 70 0q-35 60 -70 0Z',R if (row+col)%4 else G)
add('op_art','Op Art',['ded9c8','2c434f','ac8356'],optical)

def paisley_shape(colour):
    return path('M51 5C6 20 -4 77 23 100C55 125 103 89 78 58C63 40 53 48 46 61C34 49 37 26 51 5Z',colour)+path('M49 31C20 52 18 79 38 91C61 104 80 77 63 66C50 58 43 78 52 80',G if colour==R else R,5)+circle(39,73,5,'#000000')
paisley=''
for row in range(-1,5):
    for col in range(-1,5):
        paisley+=f'<g transform="translate({col*128+(64 if row%2 else 0)} {row*137}) rotate({-30 if (col+row)%2 else 25} 45 60)">{paisley_shape(R if col%2 else G)}</g>'
add('paisley_drift','Paisley Drift',['573e49','d3b68f','ad7f62'],paisley)

weave=''.join(rect(x,0,27,512,R) for x in range(22,512,80))
weave+=''.join(rect(0,y,512,27,G) for y in range(25,512,80))
weave+=''.join(rect(x,y,27,27,R) for ix,x in enumerate(range(22,512,80)) for iy,y in enumerate(range(25,512,80)) if (ix+iy)%2==0)
add('ribbon_weave','Ribbon Weave',['c9c4b1','3e666c','99714e'],weave)

scales=''
for row in range(-1,8):
    for x in range(-48+(48 if row%2 else 0),610,96):
        y=row*76
        scales+=path(f'M{x-45} {y}Q{x} {y-44} {x+45} {y}Q{x+32} {y+42} {x} {y+66}Q{x-32} {y+42} {x-45} {y}Z',R if row%3 else G)
        scales+=path(f'M{x-26} {y+7}Q{x} {y-18} {x+26} {y+7}Q{x+12} {y+29} {x} {y+40}Z','#000000')
add('scale_shift','Scale Shift',['263f3e','6f9e89','c6a76d'],scales)

petals=''
for i,(cx,cy) in enumerate([(68,65),(368,142),(147,337),(449,453)]):
    for angle in range(0,360,60):
        petals+=f'<g transform="translate({cx} {cy}) rotate({angle})">'+path('M0 -7C-41 -24 -43 -85 0 -110C43 -85 41 -24 0 -7Z',R if i%2 else G)+path('M0 -29V-78','#000000',5)+'</g>'
    petals+=circle(cx,cy,20,R if i%2==0 else G)+circle(cx,cy,9,'#000000')
add('petal_drift','Petal Drift',['dad3bb','436a60','bb8657'],petals)

halftone=''
for y in range(16,512,32):
    for x in range(16,512,32):
        phase=(x+y)/1024
        radius=3+10*(0.5+0.5*math.sin(phase*math.pi*3))
        halftone+=circle(x,y,round(radius,2),R if x+y<550 else G)
add('halftone','Halftone',['e3d8bd','334856','ba6747'],halftone)

graffiti=path('M-25 132L284 -36L245 40L351 3L293 97L521 35L398 150L446 141L332 231L529 187L424 304L259 340L313 282L129 346L197 246L30 299L108 211L-25 244Z')
graffiti+=path('M-12 425L154 365L101 428L292 375L224 457L427 384L364 462L548 430L487 525H-12Z',G)
graffiti+=path('M84 210L223 140L205 189L351 117M160 447L273 417',G,9)
add('graffiti_slash','Graffiti Slash',['343747','b48469','d9c9a6'],graffiti)

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
# Original geometric lettering paths: no installed-font or third-party logo dependency.
LETTERS = {
    'A':'M0 10L3 0L6 10M1 6H5','B':'M0 10V0H4L6 2V3L4 5H0M4 5L6 7V8L4 10H0',
    'C':'M6 1L5 0H1L0 1V9L1 10H5L6 9','D':'M0 10V0H3L6 3V7L3 10Z',
    'E':'M6 0H0V10H6M0 5H5','F':'M6 0H0V10M0 5H5','G':'M6 2V1L5 0H1L0 1V9L1 10H5L6 9V5H3',
    'H':'M0 0V10M6 0V10M0 5H6','I':'M0 0H6M3 0V10M0 10H6','J':'M0 8V9L1 10H5L6 9V0',
    'K':'M0 0V10M6 0L0 5L6 10','L':'M0 0V10H6','M':'M0 10V0L3 5L6 0V10',
    'N':'M0 10V0L6 10V0','O':'M1 0H5L6 1V9L5 10H1L0 9V1Z','P':'M0 10V0H5L6 1V4L5 5H0',
    'Q':'M1 0H5L6 1V8L4 10H1L0 9V1ZM3 7L7 11','R':'M0 10V0H5L6 1V4L5 5H0M3 5L6 10',
    'S':'M6 1L5 0H1L0 1V4L1 5H5L6 6V9L5 10H1L0 9','T':'M0 0H6M3 0V10',
    'U':'M0 0V9L1 10H5L6 9V0','V':'M0 0L3 10L6 0','W':'M0 0L1 10L3 5L5 10L6 0',
    'X':'M0 0L6 10M6 0L0 10','Y':'M0 0L3 5L6 0M3 5V10','Z':'M0 0H6L0 10H6',
}
def wordmark(word,y,width=210,colour=W):
    scale=width/(len(word)*8-2)
    return f'<g transform="translate({(256-width)/2:.2f} {y}) scale({scale:.3f})">'+''.join(
        f'<g transform="translate({i*8} 0)">{path(LETTERS[c],colour,.95)}</g>' for i,c in enumerate(word))+'</g>'

# Invented BMT-universe sponsors, each with its own symbol, colour and industry.
SPONSORS = [
    ('zelvora','Zelvora Dynamics','DYNAMICS','#598f9e',path('M72 32H184L133 80H182L85 128H126L173 83H122Z',W)),
    ('vorqen','Vorqen Fuels','FUELS','#c57a43',path('M128 28C112 59 86 76 86 97A42 42 0 0 0 170 97C170 76 145 56 128 28Z',W)+path('M129 63L109 95H132L120 117L149 85H128Z',N)),
    ('talvexa','Talvexa Tyres','TYRES','#a24643',circle(128,78,46,W)+circle(128,78,27,N)+path('M97 42L112 61M139 95L157 115M85 75L104 82M153 75L172 82M143 40L138 59M116 98L111 117',N,6)),
    ('orynth','Orynth Labs','LABS','#668b73',path('M100 32H156M111 32V63L77 111Q74 124 89 124H167Q182 124 179 111L145 63V32',W,7)+path('M91 98H165L176 116H80Z',W)+circle(128,79,6,W)),
    ('keldrift','Keldrift Tools','TOOLS','#b59752',path('M92 30H121V59L103 77L121 95V124H92V97L74 77L92 57Z M151 30H180V57L198 77L180 97V124H151V95L169 77L151 59Z',W)),
    ('velqor','Velqor Audio','AUDIO','#7a718e',path('M57 94V61H80L111 38V117L80 94Z',W)+path('M133 54Q163 78 133 101M155 35Q203 78 155 119',W,7)),
    ('myrvanta','Myrvanta Oil','OIL','#ad6948',path('M128 27L181 57V104L128 132L75 104V57Z',W)+path('M93 100V60L111 78L128 51L145 78L163 60V100H147V87L128 111L109 87V100Z',N)),
    ('quorven','Quorven Racing','RACING','#517d99',circle(128,77,45,W,10)+path('M132 79L183 124M139 79L192 112',W,10)+path('M80 49H145L113 88H158',W,6)),
    ('draxelle','Draxelle Parts','PARTS','#8d565c',path('M80 30H132L183 77L132 124H80L124 77Z',W)+path('M94 45H127L161 77L127 109H94L124 77Z',N)),
    ('selyth','Selyth Aero','AERO','#688c86',path('M32 50L113 64L128 25L143 64L224 50L155 90L146 120L128 107L110 120L101 90Z',W)+path('M128 50V92',N,6)),
    ('auvrion','Auvrion Energy','ENERGY','#b49a50',circle(128,77,46,W,6)+path('M139 29L96 85H123L116 126L160 69H132Z',W)),
    ('rhexori','Rhexori Works','WORKS','#6d7f92',path('M78 41L128 22L178 41V111L128 132L78 111Z',W)+path('M98 107V49H139L155 63V78L140 89L158 108H133L117 86V107Z',N)+path('M117 62H135V74H117Z',W)),
]
for key,title,industry,colour,symbol in SPONSORS:
    plate=f'<rect x="11" y="15" width="234" height="226" rx="16" fill="{N}" stroke="{W}" stroke-width="5"/>'
    plate+=f'<rect x="17" y="21" width="222" height="113" rx="11" fill="{colour}"/>'+symbol
    plate+=wordmark(key.upper(),151,208)+wordmark(industry,202,104,colour)
    stickers.append((key,title,plate))

atlas=''
for i,(key,title,art) in enumerate(stickers):
    # 16px gutters avoid neighbouring emblems bleeding through mip levels.
    atlas+=f'<g transform="translate({i%4*256+16} {i//4*256+16}) scale(.875)">{art}</g>'
    (ROOT/(key+'_sticker.svg')).write_text(svg(art,128,128,'0 0 256 256'),encoding='utf-8')
height=math.ceil(len(stickers)/4)*256
(ROOT/'stickers.svg').write_text(svg(atlas,1024,height,f'0 0 1024 {height}'),encoding='utf-8')
(ROOT/'stickers.json').write_text(json.dumps([{'id':k,'title':t,'category':'sponsors' if i>=12 else 'emblems'} for i,(k,t,_) in enumerate(stickers)],indent=2)+'\n',encoding='utf-8')
print(f'Authored {len(patterns)} livery masks/previews and {len(stickers)} fictional stickers.')
