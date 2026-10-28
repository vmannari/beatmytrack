"""Author five original Storm circuits; no random placement or runtime generation.

Run from the repository root, then run generate_storm_road_parts.gd through
scripts/dev.ps1. Only the native road-parts authoring path writes final sources.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "build/storm-driving-variety-2026-10-26/seeds"
EVIDENCE = ROOT / "docs/evidence/storm-driving-variety-2026-10-26"


def add(a, b): return (a[0] + b[0], a[1] + b[1])
def sub(a, b): return (a[0] - b[0], a[1] - b[1])
def mul(a, v): return (a[0] * v, a[1] * v)
def length(a): return math.hypot(*a)
def unit(a): return mul(a, 1 / length(a))
def cross(a, b): return a[0] * b[1] - a[1] * b[0]
def normal(a): return (-a[1], a[0])
def rounded(a): return [round(v, 4) for v in a]


SPECS = [
    dict(id="storm_freight", name="Thunder Freight", width=8.5,
         zones=[("container", [(-23,-29),(-13,-29),(-3,-29),(7,-29)], 0, "Aligned loading row with open working apron"),
                ("container", [(-23,-24),(-13,-24)], 0, "Second dock row, paired with the loading lane"),
                ("shed", [(38,-29)], 0, "Freight operations building"),
                ("pallet", [(29,-27),(29,-30),(33,-27)], 0, "Stacking bay beside the operations building"),
                ("crate", [(30,-23),(32,-23)], 0, "Crated freight in the same stacking bay"),
                ("van", [(46,-30)], 0, "Delivery vehicle parked parallel to the loading row"),
                ("broadleaf", [(-28,30),(-22,35),(-18,27)], 0, "Sheltered planted island inside the northern return")]),
    dict(id="storm_switchyard", name="Blackout Switchyard", width=8.0,
         zones=[("shed", [(-13,24),(-2,24)], 0, "Paired maintenance buildings sharing a service yard"),
                ("container", [(-13,36),(-3,36),(7,36)], 0, "Parallel stores along the rear service boundary"),
                ("barrel", [(-16,16),(-14,16),(-12,16)], 0, "Service drums grouped beside maintenance"),
                ("pallet", [(-5,16),(-2,16)], 0, "Parts delivery bay clear of the racing lane"),
                ("van", [(5,25)], 90, "Service van in the depot parking bay"),
                ("broadleaf", [(-15,-28),(-5,-28),(5,-28),(15,-28)], 0, "Planted strip between perimeter road and service road")]),
    dict(id="storm_timber", name="Rainbreak Ridge", width=8.0,
         zones=[("tree", [(-22,-17),(-15,-15),(-9,-19),(-3,-14),(3,-19),(11,-18)], 0, "Southern woodland follows the access road"),
                ("tree", [(21,-5),(23,4),(29,10),(34,15)], 0, "Woodland edge outside the exposed ridge bends"),
                ("tree", [(-37,26),(-30,30),(-26,36)], 0, "Stand of pines inside the western return"),
                ("log", [(-21,-5),(-21,-2),(-21,1)], 0, "Three aligned cut logs in a forestry lay-by"),
                ("shed", [(-11,1)], 0, "Forestry equipment shelter beside the log bay"),
                ("parked_car", [(-11,9)], 0, "Worker parking outside the shelter"),
                ("boulder", [(27,-29),(30,-26)], 0, "Rock outcrop below the southern ridge"),
                ("bush", [(-28,-10),(-25,8),(-2,4),(5,5)], 0, "Understory on the same woodland margins")]),
    dict(id="storm_quarry", name="Slatewater Quarry", width=8.5,
         zones=[("cliff", [(-7,41),(4,41),(15,41)], 0, "Continuous quarry cut across the north infield"),
                ("slate", [(-15,35),(-10,31),(-2,35)], 15, "Layered stone below the quarry face"),
                ("boulder", [(0,4),(7,4),(15,6)], 0, "Rock pile at the toe of the cut"),
                ("shed", [(-35,-28)], 0, "Quarry maintenance office"),
                ("container", [(-21,-38),(-10,-38),(1,-38)], 0, "Aligned equipment stores behind the maintenance lane"),
                ("barrel", [(-37,-20),(-35,-20)], 0, "Maintenance supplies beside the office"),
                ("pebbles", [(-7,28),(1,29),(8,33),(18,35),(24,35)], 0, "Scree below the same quarry face")]),
    dict(id="storm_floodgate", name="Eye of the Storm", width=7.8,
         zones=[("water", [(-13,30)], 0, "Storm-water holding basin inside the protected service loop"),
                ("shed", [(-34,-25)], 0, "Flood-control maintenance building"),
                ("container", [(-22,-32),(-12,-32)], 0, "Emergency equipment stores beside maintenance"),
                ("van", [(-33,-16)], 0, "Maintenance parking beside the building"),
                ("pallet", [(-25,-22),(-23,-22)], 0, "Emergency supplies in the service yard"),
                ("broadleaf", [(-18,44),(-9,45),(0,46)], 0, "Planted outer bank above the basin"),
                ("boulder", [(6,-6),(8,-2)], 0, "Rock reinforcement on the inner basin bank")]),
]

# Deliberate corner programmes: the site equipment above stays in its approved
# working yards. Radii, approach lengths and reversals now have distinct roles.
REDESIGNS = {
    "storm_freight": dict(
        description="Heavy braking at the end of the loading straight; a tight dock hook opens into a fast, linked northern sector and an offset return.",
        points=[(-60,-44),(87,-44),(94,-15),(79,13),(51,33),(23,15),(50,-10),(10,-10),(-13,15),(16,46),(-3,70),(-40,62),(-62,37),(-43,13),(-70,-1),(-82,-24)],
        radii=[15,6.5,29,34,13,14,6.5,13,24,26,9,32,23,7,17,25],
        widths=[9.5,8.1,9.7,9.7,8.4,8.2,7.4,7.6,8.3,9.2,7.6,9.6,9.2,7.4,8.1,9.1],
        curvature={3:.1,4:-.1,9:.1,12:-.1}),
    "storm_switchyard": dict(
        description="Stop-start depot racing: a tight east hairpin, short acceleration zones, an offset chicane and a broad final sweep.",
        points=[(-58,-44),(81,-44),(81,-7),(26,-7),(25,14),(72,14),(77,43),(40,66),(-42,66),(-79,39),(-79,8),(-37,8),(-36,-12),(-67,-12)],
        radii=[24,10,16,6,6,7,25,32,30,27,9,6,6,10],
        widths=[9.3,8.5,8.5,7.4,7.4,8.1,9,9.2,9.2,9.5,8.1,7.4,7.4,8.5],
        chicanes={8:(8,48,-1,10)},curvature={6:-.1,9:.1}),
    "storm_timber": dict(
        description="Momentum circuit: wide fast sweeps link directly through the ridge, then a much slower forestry hairpin punishes an overcommitted entry.",
        points=[(-58,-36),(16,-36),(42,-62),(78,-43),(62,-11),(81,21),(53,64),(15,64),(-7,29),(-17,57),(-52,62),(-77,31),(-36,1),(-65,-14)],
        radii=[22,30,13,30,35,34,38,21,6,17,35,29,6.2,15],
        widths=[9,9.5,8.3,9.3,9.3,9.3,9.6,8.5,7.4,8.1,9.6,9.1,7.4,8.5],
        curvature={3:.25,4:-.24,5:.24,6:-.25,10:.2}),
    "storm_quarry": dict(
        description="A long opening pull ends in a tightening bowl; the rock-cut switchback contrasts with a wide double-apex northern return.",
        points=[(-56,-44),(64,-44),(91,-20),(77,12),(34,5),(12,-23),(-10,-22),(-21,0),(10,21),(64,20),(78,48),(44,76),(-34,76),(-80,43),(-78,5),(-44,-10)],
        radii=[14,33,28,7,30,6,8,12,31,7,15,37,44,35,23,6.5],
        widths=[9.6,10.2,9.6,7.5,9.2,7.4,7.4,8.3,9.8,7.4,8.5,10.2,10.2,9.8,9.4,7.4],
        curvature={1:.28,2:-.28,8:.25,11:.27,12:-.27,13:.22}),
    "storm_floodgate": dict(
        description="Technical finale: a fast exposed approach, tight pump-house reversal, linked basin esses and an outside-bank chicane before the final braking turn.",
        points=[(-60,-42),(34,-42),(79,-25),(88,11),(56,36),(19,2),(28,-20),(-1,-22),(-18,-3),(1,19),(28,41),(16,72),(-46,72),(-72,41),(-46,13),(-79,-7)],
        radii=[14,38,31,25,8,6,6,8,25,26,8,14,32,10,9,22],
        widths=[9.2,9.8,9.8,9.4,7.5,7.4,7.4,7.8,8.5,8.5,7.4,8.3,9.4,7.5,8,8.7],
        chicanes={12:(6.5,50,-1,6)},curvature={2:.1,3:-.1,8:.1,9:-.1}),
}
for spec in SPECS:
    spec.update(REDESIGNS[spec["id"]])
    spec["curvature"]={i:math.copysign(min(abs(v),.1),v) for i,v in spec.get("curvature",{}).items()}


def fillets(spec):
    vertices, radii = spec["points"], spec["radii"]
    arcs = []
    for i, p in enumerate(vertices):
        prev, nxt = vertices[i-1], vertices[(i+1) % len(vertices)]
        incoming, outgoing = unit(sub(p, prev)), unit(sub(nxt, p))
        turn = math.atan2(cross(incoming, outgoing), sum(a*b for a,b in zip(incoming,outgoing)))
        distance = min(radii[i]*math.tan(abs(turn)/2), length(sub(p,prev))*.45, length(sub(nxt,p))*.45)
        radius = distance / math.tan(abs(turn)/2)
        start, end = sub(p, mul(incoming,distance)), add(p,mul(outgoing,distance))
        side = 1 if turn > 0 else -1
        center = add(start,mul(normal(incoming),side*radius))
        arcs.append(dict(start=start,end=end,center=center,turn=turn,radius=radius,incoming=incoming,outgoing=outgoing))
    # Start halfway down the long straight: no turn, prop or hazard at spawn.
    # Keep the approved officials' station and start/finish location.
    original = json.loads((ROOT / "scripts/storm_track_sites.json").read_text(encoding="utf-8"))[spec["id"]]
    start = tuple(original["start_line"]["position"])
    result = [start]
    for i in list(range(1,len(arcs)))+[0]:
        arc = arcs[i]
        previous=result[-1]
        n=max(1,math.ceil(length(sub(arc["start"],previous))))
        for j in range(1,n+1): result.append(add(previous,mul(sub(arc["start"],previous),j/n)))
        n = max(2,math.ceil(abs(arc["turn"])*arc["radius"]))
        a = math.atan2(*(sub(arc["start"],arc["center"])[::-1]))
        for j in range(1,n+1):
            angle = a+arc["turn"]*j/n
            result.append(add(arc["center"],(math.cos(angle)*arc["radius"],math.sin(angle)*arc["radius"])))
    # Uniform knots avoid Catmull-Rom overshoot where a long straight meets
    # closely spaced arc nodes. Fit the current 96-node authoring contract.
    result.append(start)
    cumulative=[0.0]
    for a,b in zip(result,result[1:]): cumulative.append(cumulative[-1]+length(sub(b,a)))
    samples=[]
    segment=0
    for i in range(94):
        target=cumulative[-1]*i/94
        while cumulative[segment+1]<target: segment+=1
        t=(target-cumulative[segment])/(cumulative[segment+1]-cumulative[segment])
        samples.append(add(result[segment],mul(sub(result[segment+1],result[segment]),t)))
    assert min(length(sub(p,samples[i-1])) for i,p in enumerate(samples))>2
    return samples, arcs


def make(spec):
    points, arcs = fillets(spec)
    widths = [spec["width"] for _ in points]
    # Widen genuine braking/turn-in areas gently; retain narrower technical exits.
    for i,p in enumerate(points):
        if p[1] < -32: widths[i] += .8
    doc = dict(schema="creator-track-v5",id=spec["id"],name=spec["name"],creator="Beat my track",theme="storm",
               width=spec["width"],surface="asphalt",points=[rounded(p) for p in points],widths=widths,
               corners=["smooth"]*len(points),objects=[],layout={},paint=[],base_track="",route_override=True,pieces=[],automatic_scenery=False)
    # The map is made exclusively from the same Straight and Curve parts as
    # the editor palette. Route points below are only a seed; Godot regenerates
    # them from this closed chain before saving an importable document.
    current = points[0]
    def piece(kind, position, heading, radius=16.0, distance=0.0, turn=0.0, width=None):
        value=dict(kind=kind,position=list(position),heading=heading%360,
                   length=distance,radius=radius,width=spec["width"] if width is None else width,flip=turn<0)
        if kind=="curve": value["angle"]=abs(math.degrees(turn))
        doc["pieces"].append(value)
    for index in list(range(1,len(arcs)))+[0]:
        arc=arcs[index]
        edge=sub(arc["start"],current)
        distance=length(edge)
        assert distance>=2.0, (spec["id"],index,distance)
        heading=math.degrees(math.atan2(edge[1],edge[0]))
        wide=spec["widths"][index]
        chicane=spec.get("chicanes",{}).get(index)
        if chicane:
            r,angle,sign,link=chicane
            a=math.radians(angle)
            excursion=4*r*math.sin(a)+2*link*math.cos(a)
            lead=(distance-excursion)*.5
            assert lead>=2, (spec["id"],index,"chicane needs space",distance,excursion)
            direction=unit(edge)
            cursor=add(current,mul(direction,lead))
            piece("straight",current,heading,distance=lead,width=wide)
            turn_heading=heading
            for j,bend in enumerate([sign,-sign,-sign,sign]):
                piece("curve",cursor,turn_heading,radius=r,turn=bend*a,width=7.4)
                h=math.radians(turn_heading)
                delta=(r*math.sin(a),bend*r*(1-math.cos(a)))
                cursor=add(cursor,(delta[0]*math.cos(h)-delta[1]*math.sin(h),delta[0]*math.sin(h)+delta[1]*math.cos(h)))
                turn_heading+=bend*angle
                if j in [0,2]:
                    piece("straight",cursor,turn_heading,distance=link,width=7.4)
                    cursor=add(cursor,mul((math.cos(math.radians(turn_heading)),math.sin(math.radians(turn_heading))),link))
            piece("straight",cursor,heading,distance=lead,width=wide)
        else:
            piece("straight",current,heading,distance=distance,width=min(wide,spec["width"]+.8) if index==1 else wide)
        heading=math.degrees(math.atan2(arc["incoming"][1],arc["incoming"][0]))
        wide=spec["widths"][index]
        piece("curve",arc["start"],heading,radius=arc["radius"],turn=arc["turn"],width=wide)
        if index in spec.get("curvature",{}): doc["pieces"][-1]["curvature"]=spec["curvature"][index]
        current=arc["end"]
    closing=sub(points[0],current)
    piece("straight",current,math.degrees(math.atan2(closing[1],closing[0])),distance=length(closing),width=spec["width"]+.8)
    doc["start_line"]={"position":list(points[0]),"heading":0.0}
    purposes = []
    def obj(kind,p,rotation=0,purpose="",**kw):
        doc["objects"].append(dict(kind=kind,position=rounded(p),rotation=round(rotation%360,4),**kw))
        purposes.append(purpose)
    # Clearly marked start and officials' station on the main straight.
    spawn=points[0]
    obj("gantry",spawn,90,"Start/finish gantry over the main straight")
    obj("hut",add(spawn,(0,-10)),0,"Start officials outside the road and runoff")
    obj("light",add(spawn,(-5,-10)),0,"Lighting for the officials' station")
    obj("flag",add(spawn,(5,-9)),0,"Start station flag")
    for kind,positions,rotation,purpose in spec["zones"]:
        for j,p in enumerate(positions):
            extra = {"color":["#455e68","#7d493d","#77775e"][j%3]} if kind=="container" else ({"scale":2.5} if kind=="water" else {})
            obj(kind,p,rotation,purpose,**extra)
    # Working yards have deliberate gravel aprons, not equipment on grass.
    aprons={
        "storm_freight":[[(-29,-35),(51,-35),(51,-20),(-29,-20)]],
        "storm_switchyard":[[(-23,11),(12,11),(12,42),(-23,42)]],
        "storm_timber":[[(-25,-9),(-6,-9),(-6,13),(-25,13)]],
        "storm_quarry":[[(-42,-41),(6,-41),(6,-16),(-42,-16)], [(-19,28),(25,28),(25,45),(-19,45)]],
        "storm_floodgate":[[(-40,-36),(-7,-36),(-7,-27),(-20,-27),(-20,-13),(-40,-13)]],
    }
    for polygon in aprons[spec["id"]]:
        doc["paint"].append(dict(surface=2,width=1.0,shape="square",mode="area",protect_road=True,points=polygon))
    if spec["id"]=="storm_floodgate":
        for x in [-23,-13]: obj("guardrail",(x,20),0,"Guarded south bank of the holding basin",length=9.5)
        for x in [-18,-8]: obj("guardrail",(x,40),0,"Guarded north bank of the holding basin",length=9.5)
        obj("guardrail",(-.5,32),90,"Basin bank protection beside the technical esses, with a setback at turn-in",length=11)
    if spec["id"]=="storm_freight":
        for x in [-22,-4,14,42]: obj("wire_fence",(x,-37),0,"Fence separates stored freight from the main racing lane; service gaps remain",length=15)
    if spec["id"]=="storm_switchyard":
        for y in [25,38]: obj("wire_fence",(11.5,y),90,"Fence separates the maintenance yard from its perimeter road",length=11)
    if spec["id"]=="storm_timber":
        for x in [-22,-14]: obj("fence",(x,15),0,"Timber boundary of the forestry lay-by",length=7)
    # Safety equipment follows selected genuine corners; open recovery gaps remain.
    for i,arc in enumerate(arcs):
        if i==0 or i%3==1:
            radial=unit(sub(mul(add(arc["start"],arc["end"]),.5),arc["center"]))
            sweep=math.atan2(radial[1],radial[0])
            for offset in [-.25,.25]:
                direction=(math.cos(sweep+offset),math.sin(sweep+offset))
                setback=spec["widths"][i]*.5+2.8+arc["radius"]*abs(spec.get("curvature",{}).get(i,0))
                p=add(arc["center"],mul(direction,arc["radius"]+setback))
                obj("guardrail",p,math.degrees(sweep+offset)+90,"Outside-corner protection following the road arc",length=5.5)
        if abs(math.degrees(arc["turn"]))>78 and i%2==0:
            side = -1 if arc["turn"]>0 else 1
            p=add(sub(arc["start"],mul(arc["incoming"],7)),mul(normal(arc["incoming"]),side*(max(spec["widths"])*.5+3)))
            facing=math.degrees(math.atan2(arc["incoming"][1],arc["incoming"][0]))+(90 if arc["turn"]>0 else -90)
            obj("chevron",p,facing,"Turn-direction marker before the tight corner, facing approaching cars")
    # The wet shoulder collects water; no full-width surprise hazards.
    for i in [2,len(arcs)-3]:
        arc=arcs[i]
        p=add(arc["start"],mul(normal(arc["incoming"]),spec["width"]*.5-1))
        obj("puddle",p,math.degrees(math.atan2(arc["incoming"][1],arc["incoming"][0])),"Partial-width standing water at the road's low shoulder",scale=.5)
    # Site scenery is immutable; only roadside protection/markers are refitted
    # to the new road, with the same deliberate outside-corner placement rule.
    approved=json.loads((ROOT/"scripts/storm_track_sites.json").read_text(encoding="utf-8"))[spec["id"]]
    site_kinds={"guardrail","chevron","puddle"}
    old_site=[o for o in approved["objects"] if o["kind"] not in site_kinds]
    new_site=[o for o in doc["objects"] if o["kind"] not in site_kinds]
    assert old_site==new_site, spec["id"]+" approved site scenery moved"
    if spec["id"]=="storm_floodgate":
        assert [o for o in doc["objects"] if o["kind"]=="guardrail"][:5]==[o for o in approved["objects"] if o["kind"]=="guardrail"][:5]
    assert approved["paint"]==json.loads(json.dumps(doc["paint"]))
    doc["paint"]=approved["paint"]
    return doc,dict(id=spec["id"],name=spec["name"],design=spec["description"],road_parts=len(doc["pieces"]),corner_radii=[round(a["radius"],2) for a in arcs],widths=spec["widths"],chicanes=spec.get("chicanes",{}),object_purposes=purposes)


def main():
    DEST.mkdir(parents=True,exist_ok=True)
    EVIDENCE.mkdir(parents=True,exist_ok=True)
    rows=[]
    for spec in SPECS:
        doc,row=make(spec)
        (DEST/(spec["id"]+".json")).write_text(json.dumps(doc,indent=2)+"\n",encoding="utf-8")
        rows.append(row)
        print(spec["name"],len(doc["pieces"]),"normal road parts",len(doc["objects"]),"objects")
    (EVIDENCE/"design.json").write_text(json.dumps(dict(requirements=["ST01 five original Storm tracks","ST02 demanding wet layouts","ST03 purposeful scenery"],tracks=rows),indent=2)+"\n",encoding="utf-8")


if __name__=="__main__": main()
