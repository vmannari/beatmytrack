"""PL01-PL03: original, car-specific five-panel vector livery collection.

Authoring only: fontTools outlines the repository's OFL Barlow fonts. No font,
Python package, raster reference, real sponsor or generated artwork at runtime.
Run with fontTools available (or PYTHONPATH=build/premium-livery-authoring-lib).
"""
from pathlib import Path
import json
import math
import re

from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/assets/liveries/premium_v1"
OUT.mkdir(parents=True, exist_ok=True)
B, A, D = "#000000", "#ff0000", "#00ff00"
FONT = TTFont(ROOT / "game/assets/fonts/BarlowCondensed-SemiBold.ttf")
GLYPHS, CMAP = FONT.getGlyphSet(), FONT.getBestCmap()
UPM = FONT["head"].unitsPerEm


def path(d, c=A, w=0):
    return (f'<path d="{d}" fill="none" stroke="{c}" stroke-width="{w}" '
            'stroke-linecap="round" stroke-linejoin="round"/>' if w else f'<path d="{d}" fill="{c}"/>')


def rect(x, y, w, h, c=A):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{c}"/>'


def circle(x, y, r, c=A, w=0):
    return (f'<circle cx="{x}" cy="{y}" r="{r}" fill="none" stroke="{c}" stroke-width="{w}"/>'
            if w else f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}"/>')


def text(label, x, y, size, c=D, align="middle", spacing=0.06):
    scale = size / UPM
    advance = sum(FONT["hmtx"][CMAP[ord(ch)]][0] for ch in label) * scale
    advance += max(0, len(label) - 1) * size * spacing
    cursor = x - advance * (0.5 if align == "middle" else 1 if align == "end" else 0)
    result = ""
    for ch in label:
        name = CMAP[ord(ch)]
        pen = SVGPathPen(GLYPHS)
        GLYPHS[name].draw(pen)
        result += f'<path d="{pen.getCommands()}" transform="translate({cursor:.3f} {y}) scale({scale:.6f} {-scale:.6f})" fill="{c}"/>'
        cursor += FONT["hmtx"][name][0] * scale + size * spacing
    return f'<g data-text-x="{x}" data-text-y="{y-size*0.35}">{result}</g>'


def badge(n, x, y, r=83, ink=D, field=A, aspect=1):
    art = circle(x, y, r, field) + circle(x, y, r - 8, B, 3) + text(n, x, y + r * 0.42, r * 1.35, ink, spacing=0)
    return f'<g transform="translate({x} 0) scale({aspect} 1) translate({-x} 0)">{art}</g>'


def label_box(main, sub, x=510, y=540, ink=D, w=295):
    return (path(f'M{x-w/2} {y-31}V{y-55}H{x+w/2}V{y-31}M{x-w/2} {y+27}V{y+48}H{x+w/2}V{y+27}', ink, 3)
            + text(main, x, y + 10, 48, ink) + text(sub, x, y + 38, 15, ink, spacing=0.12))


def mirror(art):
    return '<g transform="translate(1024 0) scale(-1 1)">' + art + '</g>'


def crest(x, y, ink=D, size=1):
    return f'<g transform="translate({x} {y}) scale({size})">' + path('M0 -54L43 -30V13L0 50L-43 13V-30Z', ink, 4) + path('M-26 14L0 -31L26 14H14L0 -10L-14 14Z', ink) + '</g>'


def compass(x, y, r=96, ink=D):
    art = circle(x, y, r, ink, 3) + circle(x, y, r-12, ink, 2)
    for i in range(16):
        a = i * math.tau / 16
        p1, p2 = r-14, r-29 if i % 4 else r-39
        art += path(f'M{x+math.sin(a)*p1:.2f} {y+math.cos(a)*p1:.2f}L{x+math.sin(a)*p2:.2f} {y+math.cos(a)*p2:.2f}', ink, 3)
    art += path(f'M{x} {y-r+34}L{x+16} {y+20}L{x} {y+8}L{x-16} {y+20}Z', ink)
    return art


CATALOG = []


def add(vehicle, key, title, colours, concept, top, left, right=None, front="", rear="", finish="Satin pigment / gloss coachline"):
    # Geometry is mirrored; typography is separately positioned and remains readable.
    if right is None:
        corrected = re.sub(r'<g data-text-x="([0-9.]+)" data-text-y="[0-9.]+">',
                           lambda m: f'<g transform="translate({float(m[1])*2} 0) scale(-1 1)">', left)
        right = mirror(corrected)
    # Bonnet/deck lettering is read from the nose, with its panel position retained.
    top = re.sub(r'<g data-text-x="([0-9.]+)" data-text-y="([0-9.]+)">',
                 lambda m: f'<g transform="translate({float(m[1])*2} {float(m[2])*2}) scale(-1 -1)">', top)
    panels = [top, left, right, front, rear, ""]
    body = ""
    for i, art in enumerate(panels):
        x, y = (i % 3)*1024, (i // 3)*1024
        body += f'<g transform="translate({x} {y})"><g clip-path="url(#panel)">' + rect(0,0,1024,1024,B) + art + '</g></g>'
    # Import at 1536x1024, with a full mip chain. Original path precision is retained.
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="1536" height="1024" viewBox="0 0 3072 2048"><defs><clipPath id="panel"><rect width="1024" height="1024"/></clipPath></defs>' + body + '</svg>\n'
    (OUT / f'{key}.svg').write_text(svg, encoding="utf-8")
    CATALOG.append(dict(id=key, title=title, vehicle=vehicle, colours=colours, concept=concept,
                        finish_direction=finish, layout="five_panel_atlas", release_state="art_review",
                        source=f'{key}.svg', edition="Collection 01"))


# RALLY: analogue rally heritage. Circular race IDs, sweeping shoulder graphics.
t = rect(350,0,123,1024) + rect(551,0,123,1024) + rect(332,0,5,1024,D) + rect(687,0,5,1024,D)
t += badge('73',512,219,49,A,B,2.375) + text('MONTE ROSSO',512,891,41,A) + text('SCUDERIA / RALLY',512,925,17,A)
shape = path('M0 720V651C261 654 320 588 505 588H1024V751H0Z') + path('M0 638C260 642 326 575 505 575H1024',D,6)
s = shape + badge('73',493,565,77,D,A,0.364) + text('MONTE ROSSO',493,690,33,D) + text('RALLYE  /  1973',493,718,13,D)
add('compact','rally_monte_rosso','Monte Rosso 73',['e6dfc8','702a32','d3ac69'],
    'Ivory coachwork, oxblood twin bonnet lanes, gold shoulder sweep and a hand-set 73 roundel.',t,s,
    front=rect(350,300,123,724)+rect(551,300,123,724)+rect(332,300,5,724,D)+rect(687,300,5,724,D),
    rear=rect(0,630,1024,130)+text('MONTE ROSSO',512,715,47,D))

t = path('M80 0H367L944 1024H667Z') + path('M389 0H405L982 1024H966Z',D)
t += path('M80 95H944M80 109H944',D,3)+label_box('09','NORDIC WORKS',527,216,D,194)
shape = path('M0 731V578H420L622 459H1024V740Z') + path('M0 560H409L612 441H1024',D,11)
s = shape + rect(432,495,94,128,B) + text('09',479,605,101,A,spacing=0) + text('NORDIC',550,676,40,B)+text('WORKS / RALLY TEAM',550,704,14,B)
add('compact','rally_nordic_works','Nordic Works 09',['e4e8e0','214e66','d97a3d'],
    'Glacier-white field, broken petrol-blue Scandinavian cross and precise copper route markers.',t,s,
    front=rect(0,590,1024,150)+path('M80 571H944',D,9),rear=rect(0,560,1024,190)+text('NORDIC WORKS',512,674,60,B))

t = path('M95 0C192 190 295 273 376 1024H572C405 347 367 159 350 0Z')
t += path('M372 0C383 193 425 357 595 1024',D,9)+compass(696,241,91,D)+text('MISTRAL',512,906,57,A)
shape = path('M0 715C329 707 495 632 1024 395V602C582 765 344 803 0 794Z')+path('M0 694C329 686 495 611 1024 374',D,7)
s = shape+label_box('26','MISTRAL / TOURING',491,541,D,206)+text('MISTRAL',526,720,34,B)
add('compact','rally_mistral_tour','Mistral Tour 26',['173e39','e6dfc8','c4a568'],
    'Evergreen touring lacquer with an ivory sail sweeping through the rear quarter and a navigation crest.',t,s,
    front=path('M0 650H1024V775H0Z')+path('M0 632H1024',D,6),rear=rect(0,650,1024,112)+text('MISTRAL',512,737,58,B))

# KART: large, legible graphics on its actual narrow nose and sidepods.
t = path('M350 0H674L621 434H403Z') + path('M115 382H283L294 812H123ZM741 382H909L901 812H730Z')
t += path('M320 0L379 457M704 0L645 457',D,13)+text('21',512,238,164,B,spacing=0)
t += text('CORSA',206,570,55,B)+text('CORSA',818,570,55,B)
s = path('M0 455H1024V716H0Z')+path('M0 731H1024',D,12)+text('21',505,650,172,B,spacing=0)+text('OFFICINA CORSA',795,562,36,B)
add('kart','kart_officina_corsa','Officina Corsa 21',['d5d2c4','a92f2e','222c34'],
    'Factory kart scarlet, ivory nose plate and oversized 21s laid out for the separate sidepods.',t,s,
    front=rect(0,430,1024,330)+text('21',512,677,184,B,spacing=0),rear=rect(0,490,1024,270)+text('CORSA',512,656,92,B))

t = path('M512 0L789 370L649 431L512 190L375 431L235 370Z')+path('M512 45L736 354',D,14)
t += path('M80 354L269 441L279 813L164 766ZM944 354L755 441L745 813L860 766Z',D)
t += text('08',512,299,121,B,spacing=0)+text('APEX',206,608,55,B)+text('APEX',818,608,55,B)
s=path('M0 760L251 421H538L304 760Z')+path('M333 760L572 421H618L379 760Z',D)+text('08',733,638,149,D,spacing=0)+text('APEX DIVISION',744,691,26,D)
add('kart','kart_apex_division','Apex Division 08',['243d9b','c3d159','dfe5df'],
    'Cobalt and sharp citron aero wedges; white precision cuts and an oversized nose race plate.',t,s,
    front=path('M0 430H1024V740H0Z')+text('APEX',512,648,133,B),rear=text('08',512,649,160,D))

t = path('M386 0H638L603 414H421Z')+path('M140 361H267V822H140ZM757 361H884V822H757Z')
for x in [153,172,244,263,761,780,852,871]: t+=path(f'M{x} 387V793',D,8)
t+=text('88',512,249,150,B,spacing=0)+crest(512,328,D,0.62)
s=rect(0,458,1024,267)+path('M0 440H1024M0 741H1024',D,8)+text('ROYALE',650,607,84,B)+text('88',266,646,153,B,spacing=0)+text('KARTING CLUB',650,650,21,B)
add('kart','kart_pocket_royale','Pocket Royale 88',['352b42','d1b57a','e9e0d1'],
    'Midnight-plum club racer with champagne pod inlays, outlined pinstripes and a bespoke shield.',t,s,
    front=rect(0,459,1024,265)+text('ROYALE',512,643,115,B),rear=text('88',512,650,151,A))

# FORKLIFT: invented industrial identities; paint follows the low counterweight.
t=rect(65,0,215,1024)+rect(744,0,215,1024)+text('04',512,804,168,D,spacing=0)
shape=path('M0 536H1024V657H0Z')+path('M0 674H1024V703H0Z',D)
s=shape+text('FOUNDRY',512,612,79,B)+text('04',794,763,108,D,spacing=0)+text('HEAVY DIVISION',484,750,26,D)
r=rect(0,489,1024,283)+text('04',512,694,177,B,spacing=0)+text('FOUNDRY',512,748,33,B)
add('forklift','forklift_foundry','Foundry No.04',['263b47','be6639','d5c9ad'],
    'Blue-steel counterweight, oxide-orange load stripe and an original foundry inspection identity.',t,s,front=shape,rear=r)

t=path('M0 629H1024V792H0Z')
for x in range(-200,1200,160): t+=path(f'M{x} 629L{x+100} 792H{x+170}L{x+70} 629Z',D)
shape=rect(0,570,1024,123)
for x in range(-200,1200,150):shape+=path(f'M{x} 570L{x+92} 693H{x+147}L{x+55} 570Z',D)
s=shape+text('SIGNAL',535,543,60,A)+text('12',789,773,116,A,spacing=0)+text('LOAD / CONTROL',465,754,23,A)
r=rect(0,500,1024,270)+text('12',512,695,164,D,spacing=0)+text('SIGNAL',512,750,42,D)
add('forklift','forklift_signal','Signal / 12',['dfd9c9','30393d','c7a83f'],
    'Warm porcelain counterweight, measured graphite safety bar and amber diagonal load marks.',t,s,front=shape,rear=r)

t=path('M80 0H125V1024H80ZM899 0H944V1024H899Z')+crest(512,804,D,1.3)
shape=path('M0 707L302 543H1024V600H321L115 707Z')+path('M144 728L347 621H1024',D,7)
s=shape+text('NIGHT SHIFT',615,708,55,D)+text('06',797,562,101,B,spacing=0)+text('PRECISION MATERIAL HANDLING',615,748,17,D)
r=path('M0 680L512 455L1024 680V750L512 525L0 750Z')+text('06',512,705,110,D,spacing=0)
add('forklift','forklift_night_shift','Night Shift 06',['164c4d','b89862','e0e5dc'],
    'Deep petroleum enamel, rising machined-brass geometry and restrained technical stencil lettering.',t,s,front=shape,rear=r)

# VOLT: quiet luxury, precision light and fluid surface linework; no racing numbers.
t=path('M676 0H860L492 1024H403Z')+path('M646 0L372 1024',D,7)+crest(518,238,A,0.68)
shape=path('M0 790C465 772 683 669 1024 532V637C719 760 420 810 0 828Z')+path('M0 773C465 755 683 652 1024 515',D,6)
s=shape+label_box('ION','ATELIER / ELECTRIC',515,548,A,195)
add('electric','volt_ion_atelier','Ion Atelier',['e1e3d8','263b42','b57b58'],
    'Pearl porcelain with a single graphite ribbon, copper hairline and discreet geometric atelier crest.',t,s,
    front=path('M0 725Q512 640 1024 725',D,7),rear=path('M0 708H1024',D,6)+text('ION',512,672,54,A))

t=''
for i in range(7):
    inset=86+i*26
    t+=path(f'M{inset} 0V189Q{inset} {306-i*14} 512 {390-i*24}Q{1024-inset} {306-i*14} {1024-inset} 189V0',A if i%3 else D,5 if i%3 else 9)
t+=path('M457 810L512 740L567 810L512 880Z',D,4)+text('POLAR',512,945,42,A)
shape=path('M0 772C303 767 446 725 604 620L775 490H1024',D,6)
for i in range(4):shape+=path(f'M0 {793+i*14}C303 {788+i*14} 446 {746+i*14} 621 {638+i*14}L800 {508+i*14}H1024',A,4)
s=shape+text('POLAR',548,547,49,D)+text('VECTOR / ELECTRIC',548,580,16,D)
add('electric','volt_polar_vector','Polar Vector',['142b40','a8c5c9','75b9c3'],
    'Midnight blue, nested glacier contours and a single cyan vector carried from bonnet to shoulder.',t,s,
    front=path('M0 753Q512 617 1024 753M0 780Q512 644 1024 780',A,5),rear=text('POLAR',512,717,48,D))

t=''
for i in range(8):t+=path(f'M{117+i*27} 0C{897-i*21} 121 {66+i*24} 229 {864-i*29} 400',A if i in [2,5] else D,18 if i in [2,5] else 4)
t+=label_box('ORCHID','CIRCUIT / VOLT',512,848,D,258)
shape=''
for i in range(6):shape+=path(f'M0 {801-i*15}C{478+i*21} {793-i*19} {402+i*37} {539-i*17} 1024 {490-i*17}',A if i in [0,5] else D,12 if i in [0,5] else 4)
s=shape+text('ORCHID',548,556,51,A)+text('C I R C U I T',548,591,17,D)
add('electric','volt_orchid_circuit','Orchid Circuit',['3b2c40','ddd5cd','ba8c79'],
    'Aubergine lacquer and copper parallel curves, finished with an ivory atelier wordmark.',t,s,
    front=path('M0 742Q512 655 1024 742',D,5),rear=text('ORCHID',512,714,43,A))

# HOVER: nautical/survey identity composed around its large deck and twin fans.
t=path('M102 0H329L427 1024H161ZM695 0H922L863 1024H597Z')+path('M351 0L449 1024M673 0L575 1024',D,7)
t+='<g transform="translate(512 0) scale(1.836 1) translate(-512 0)">'+compass(512,141,65,D)+'</g>'
shape=path('M0 651Q423 704 1024 482V629Q432 825 0 776Z')+path('M0 633Q423 686 1024 464',D,7)
s=shape+text('PELAGIC',509,718,71,B)+text('07',833,597,101,B,spacing=0)
add('hovercraft','hover_pelagic','Pelagic 07',['173644','d5d4bd','bb8d59'],
    'Deep marine blue, ivory hull wakes and a bespoke compass rose on the open forward deck.',t,s,
    front=rect(0,550,1024,210)+text('07',512,699,126,B,spacing=0),rear=text('PELAGIC',512,706,49,A))

t=''
for i in range(13):
    x=70+i*21;y=70+i*24
    t+=path(f'M{x} 0C{x-90} {y+160} {980-i*23} {y+35} {970-i*18} {y+220}S{510+i*4} {820-i*9} {900-i*16} 1024',A if i%4 else D,4 if i%4 else 7)
t+=label_box('ABYSSAL','HYDROGRAPHIC / 300',270,245,D,258)
shape=''
for i in range(8):shape+=path(f'M0 {530+i*28}Q295 {452+i*21} 502 {571+i*20}T1024 {550+i*27}',A if i%3 else D,4 if i%3 else 6)
s=shape+rect(383,591,300,91,B)+text('ABYSSAL',534,645,59,D)+text('SURVEY / 300',534,674,17,D)
add('hovercraft','hover_abyssal_survey','Abyssal Survey',['214a49','6e9990','d8cfab'],
    'Bathymetric chart contours wrap the broad deck and hull, with a purpose-made hydrographic title block.',t,s,
    front=shape,rear=text('ABYSSAL',512,706,56,D))

t=path('M512 0L884 429L671 380L512 1024L353 380L140 429Z')+path('M512 30L820 393',D,12)
t+=text('SOLARIS',512,250,64,B)+text('REGATTA',512,292,23,B)+path('M112 710L374 813M912 710L650 813',D,18)
shape=path('M0 793L337 601L636 601L1024 420V620L669 748H370L205 832Z')+path('M0 768L325 578H629L1024 394',D,9)
s=shape+text('SOLARIS',512,701,75,B)+text('REGATTA / 27',512,737,21,B)
add('hovercraft','hover_solaris_regatta','Solaris Regatta',['e5dfcb','b54534','223d4b'],
    'Warm ivory racing launch with a vermilion sail-arrow on deck and deep-navy regatta keylines.',t,s,
    front=rect(0,565,1024,188)+text('SOLARIS',512,690,81,B),rear=text('27',512,707,122,A,spacing=0))

# SUPER RALLY: long-bonnet muscle car. Coachbuilt pinlines and powerful flanks.
t=path('M400 0H624L596 1024H428Z')+path('M378 0L405 1024M646 0L619 1024',D,5)
t+=crest(512,205,D,1.05)+text('OBSIDIAN',512,881,47,D)+text('COACHWORKS',512,913,17,D)
shape=path('M0 527C354 514 583 484 1024 436L974 514C539 549 347 573 0 586Z')+path('M0 510C354 497 583 467 1024 419',D,4)+path('M0 603C354 590 583 560 974 531',D,3)
s=shape+label_box('OBSIDIAN','COACHWORKS / GRAND TOURING',529,638,D,306)
add('super_rally','super_obsidian','Obsidian Coachworks',['222b31','424950','c0a36e'],
    'Obsidian graphite with champagne double pinlines, a long bonnet blade and coachbuilt shield.',t,s,
    front=rect(400,300,224,724)+path('M378 300V1024M646 300V1024',D,5),rear=path('M0 574H1024M0 590H1024',D,4)+text('OBSIDIAN',512,705,49,D))

t=path('M112 0H303L453 1024H324ZM721 0H912L700 1024H571Z')+path('M91 0L301 1024M933 0L723 1024',D,7)
t+=label_box('68','DOMINION',512,242,D,176)
shape=path('M0 482H360L479 558H741L889 448H1024V679H841L718 716H435L314 636H0Z')+path('M0 463H370L490 539H732L881 429H1024',D,7)
s=shape+text('DOMINION',586,640,65,D)+text('68',790,438,78,D,spacing=0)
add('super_rally','super_crimson_dominion','Crimson Dominion',['732c32','242b31','d2c9ad'],
    'Claret muscle-car lacquer, deep charcoal shoulder blocks and a fine ivory tracing around the haunch.',t,s,
    front=rect(110,500,194,524)+rect(720,500,194,524),rear=rect(0,524,1024,196)+text('DOMINION',512,652,70,D))

t=path('M534 0H703L678 1024H534Z')+path('M508 0V1024',D,12)+path('M724 0L699 1024',D,5)
t+=text('SPECTRE',305,217,46,A)+text('GT / 92',305,250,18,A)
shape=path('M0 702C369 685 565 581 1024 384V526C628 716 359 803 0 818Z')+path('M0 682C369 665 565 561 1024 364',D,9)
for i in range(5):shape+=path(f'M{762+i*39} {395-i*17}L{685+i*39} {530-i*17}',D,7)
s=shape+text('SPECTRE',525,657,66,B)+text('GRAND TOURING / 92',525,692,18,B)
add('super_rally','super_silver_spectre','Silver Spectre',['b9c3c1','244652','c17b48'],
    'Brushed-silver colour direction, a petrol-blue rear-quarter surge and copper gill signatures.',t,s,
    front=rect(534,320,169,704)+path('M508 320V1024',D,12),rear=rect(0,578,1024,156)+text('SPECTRE',512,683,66,B))

assert len(CATALOG) == 18
assert len({item['id'] for item in CATALOG}) == 18
for vehicle in ['compact','kart','forklift','electric','hovercraft','super_rally']:
    assert sum(item['vehicle']==vehicle for item in CATALOG) == 3
(OUT / 'catalog.json').write_text(json.dumps(CATALOG, indent=2)+'\n', encoding='utf-8')
(OUT / 'NOTICE.txt').write_text(
    'Beat my track / Premium Collection 01\n'
    'Original vector livery artwork authored for this project on 2026-11-15.\n'
    'Lettering outlined from repository Barlow Condensed SemiBold, SIL OFL 1.1; see ../../fonts/OFL.txt.\n'
    'All names, insignia and race-team graphics are original fictional design elements.\n'
    'No reference images, external logos, sponsors or generated raster artwork used.\n'
    'Colour names describe art direction; metallic foil and material variation are not implemented.\n'
    'Art-review collection: no SKU, price, entitlement grant or payment flow is defined.\n', encoding='utf-8')
print('PREMIUM_ART: 18 distinct five-panel masks / 6 car identities / outlined original typography')
