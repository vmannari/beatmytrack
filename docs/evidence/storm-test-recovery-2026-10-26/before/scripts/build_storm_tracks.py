"""Author five original Storm circuits; no random placement or runtime generation.

Run from the repository root. Creator JSON files are editable/importable sources.
Object purpose and corner design stay in the evidence manifest, outside the game.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "game/resources/storm_tracks"
EVIDENCE = ROOT / "docs/evidence/storm-five-tracks-2026-10-25"


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
         description="Fast loading lane, tightening dock loop and offset infield esses.",
         points=[(-60,-44),(54,-44),(68,-28),(68,6),(46,24),(22,8),(24,-7),(7,-14),(-7,6),(12,35),(-3,53),(-40,53),(-61,29),(-47,7),(-67,-11)],
         radii=[14,13,15,13,10,8,8,10,12,10,12,16,12,9,12],
         zones=[("container", [(-23,-29),(-13,-29),(-3,-29),(7,-29)], 0, "Aligned loading row with open working apron"),
                ("container", [(-23,-24),(-13,-24)], 0, "Second dock row, paired with the loading lane"),
                ("shed", [(38,-29)], 0, "Freight operations building"),
                ("pallet", [(29,-27),(29,-30),(33,-27)], 0, "Stacking bay beside the operations building"),
                ("crate", [(30,-23),(32,-23)], 0, "Crated freight in the same stacking bay"),
                ("van", [(46,-30)], 0, "Delivery vehicle parked parallel to the loading row"),
                ("broadleaf", [(-28,30),(-22,35),(-18,27)], 0, "Sheltered planted island inside the northern return")]),
    dict(id="storm_switchyard", name="Blackout Switchyard", width=8.0,
         description="Two slow reversals interrupt a long wet perimeter run; exit placement matters.",
         points=[(-58,-44),(50,-44),(65,-29),(65,-8),(18,-8),(18,15),(58,15),(58,43),(33,52),(-51,52),(-65,33),(-65,12),(-32,12),(-32,-11),(-64,-11)],
         radii=[12,12,13,10,8,8,9,10,14,13,12,9,8,8,10],
         zones=[("shed", [(-13,24),(-2,24)], 0, "Paired maintenance buildings sharing a service yard"),
                ("container", [(-13,36),(-3,36),(7,36)], 0, "Parallel stores along the rear service boundary"),
                ("barrel", [(-16,16),(-14,16),(-12,16)], 0, "Service drums grouped beside maintenance"),
                ("pallet", [(-5,16),(-2,16)], 0, "Parts delivery bay clear of the racing lane"),
                ("van", [(5,25)], 90, "Service van in the depot parking bay"),
                ("broadleaf", [(-15,-28),(-5,-28),(5,-28),(15,-28)], 0, "Planted strip between perimeter road and service road")]),
    dict(id="storm_timber", name="Rainbreak Ridge", width=8.0,
         description="Alternating forest bends, a deceptive tightening right and a late braking hairpin.",
         points=[(-58,-36),(18,-36),(40,-53),(60,-35),(43,-8),(60,16),(42,45),(16,45),(-7,22),(-18,46),(-46,48),(-62,24),(-38,3),(-57,-14)],
         radii=[13,12,10,13,10,14,14,13,8,10,14,11,9,10],
         zones=[("tree", [(-22,-17),(-15,-15),(-9,-19),(-3,-14),(3,-19),(11,-18)], 0, "Southern woodland follows the access road"),
                ("tree", [(21,-5),(23,4),(29,10),(34,15)], 0, "Woodland edge outside the exposed ridge bends"),
                ("tree", [(-37,26),(-30,30),(-26,36)], 0, "Stand of pines inside the western return"),
                ("log", [(-21,-5),(-21,-2),(-21,1)], 0, "Three aligned cut logs in a forestry lay-by"),
                ("shed", [(-11,1)], 0, "Forestry equipment shelter beside the log bay"),
                ("parked_car", [(-11,9)], 0, "Worker parking outside the shelter"),
                ("boulder", [(27,-29),(30,-26)], 0, "Rock outcrop below the southern ridge"),
                ("bush", [(-28,-10),(-25,8),(-2,4),(5,5)], 0, "Understory on the same woodland margins")]),
    dict(id="storm_quarry", name="Slatewater Quarry", width=8.5,
         description="Fast outer sweep feeds a compact rock-cut infield and an awkward double apex.",
         points=[(-56,-44),(42,-44),(64,-26),(54,0),(24,-6),(10,-26),(-12,-24),(-20,-2),(8,22),(52,20),(62,42),(40,56),(-38,56),(-62,32),(-60,8),(-40,-10)],
         radii=[13,16,15,10,10,8,9,12,15,10,10,15,19,16,12,11],
         zones=[("cliff", [(-7,41),(4,41),(15,41)], 0, "Continuous quarry cut across the north infield"),
                ("slate", [(-15,35),(-10,31),(-2,35)], 15, "Layered stone below the quarry face"),
                ("boulder", [(0,4),(7,4),(15,6)], 0, "Rock pile at the toe of the cut"),
                ("shed", [(-35,-28)], 0, "Quarry maintenance office"),
                ("container", [(-21,-38),(-10,-38),(1,-38)], 0, "Aligned equipment stores behind the maintenance lane"),
                ("barrel", [(-37,-20),(-35,-20)], 0, "Maintenance supplies beside the office"),
                ("pebbles", [(-7,28),(1,29),(8,33),(18,35),(24,35)], 0, "Scree below the same quarry face")]),
    dict(id="storm_floodgate", name="Eye of the Storm", width=7.8,
         description="The hardest circuit: narrowing esses, three braking zones and a tightening basin return.",
         points=[(-60,-42),(26,-42),(54,-26),(62,0),(43,18),(18,0),(24,-20),(-2,-22),(-16,-4),(0,18),(22,38),(10,56),(-32,56),(-58,36),(-42,12),(-66,-4)],
         radii=[13,17,15,14,12,8,8,10,10,13,9,12,16,12,8,12],
         zones=[("water", [(-13,30)], 0, "Storm-water holding basin inside the protected service loop"),
                ("shed", [(-34,-25)], 0, "Flood-control maintenance building"),
                ("container", [(-22,-32),(-12,-32)], 0, "Emergency equipment stores beside maintenance"),
                ("van", [(-33,-16)], 0, "Maintenance parking beside the building"),
                ("pallet", [(-25,-22),(-23,-22)], 0, "Emergency supplies in the service yard"),
                ("broadleaf", [(-18,44),(-9,45),(0,46)], 0, "Planted outer bank above the basin"),
                ("boulder", [(6,-6),(8,-2)], 0, "Rock reinforcement on the inner basin bank")]),
]


def fillets(spec):
    vertices, radii = spec["points"], spec["radii"]
    arcs = []
    for i, p in enumerate(vertices):
        prev, nxt = vertices[i-1], vertices[(i+1) % len(vertices)]
        incoming, outgoing = unit(sub(p, prev)), unit(sub(nxt, p))
        turn = math.atan2(cross(incoming, outgoing), sum(a*b for a,b in zip(incoming,outgoing)))
        distance = min(radii[i]*math.tan(abs(turn)/2), length(sub(p,prev))*.40, length(sub(nxt,p))*.40)
        radius = distance / math.tan(abs(turn)/2)
        start, end = sub(p, mul(incoming,distance)), add(p,mul(outgoing,distance))
        side = 1 if turn > 0 else -1
        center = add(start,mul(normal(incoming),side*radius))
        arcs.append(dict(start=start,end=end,center=center,turn=turn,radius=radius,incoming=incoming,outgoing=outgoing))
    # Start halfway down the long straight: no turn, prop or hazard at spawn.
    start = mul(add(arcs[0]["end"],arcs[1]["start"]),.5)
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
    doc["layout"] = {k:doc[k] for k in ("points","widths","corners","surface")}
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
                p=add(arc["center"],mul(direction,arc["radius"]+spec["width"]*.5+2.2))
                obj("guardrail",p,math.degrees(sweep+offset)+90,"Outside-corner protection following the road arc",length=5.5)
        if abs(math.degrees(arc["turn"]))>78 and i%2==0:
            side = -1 if arc["turn"]>0 else 1
            p=add(sub(arc["start"],mul(arc["incoming"],7)),mul(normal(arc["incoming"]),side*(spec["width"]*.5+2)))
            facing=math.degrees(math.atan2(arc["incoming"][1],arc["incoming"][0]))+(90 if arc["turn"]>0 else -90)
            obj("chevron",p,facing,"Turn-direction marker before the tight corner, facing approaching cars")
    # The wet shoulder collects water; no full-width surprise hazards.
    for i in [2,len(arcs)-3]:
        arc=arcs[i]
        p=add(arc["start"],mul(normal(arc["incoming"]),spec["width"]*.5-1))
        obj("puddle",p,math.degrees(math.atan2(arc["incoming"][1],arc["incoming"][0])),"Partial-width standing water at the road's low shoulder",scale=.5)
    return doc,dict(id=spec["id"],name=spec["name"],design=spec["description"],corner_radii=[round(a["radius"],2) for a in arcs],object_purposes=purposes)


def main():
    DEST.mkdir(parents=True,exist_ok=True)
    EVIDENCE.mkdir(parents=True,exist_ok=True)
    rows=[]
    for spec in SPECS:
        doc,row=make(spec)
        (DEST/(spec["id"]+".json")).write_text(json.dumps(doc,indent=2)+"\n",encoding="utf-8")
        rows.append(row)
        print(spec["name"],len(doc["points"]),"nodes",len(doc["objects"]),"objects")
    (EVIDENCE/"design.json").write_text(json.dumps(dict(requirements=["ST01 five original Storm tracks","ST02 demanding wet layouts","ST03 purposeful scenery"],tracks=rows),indent=2)+"\n",encoding="utf-8")


if __name__=="__main__": main()
