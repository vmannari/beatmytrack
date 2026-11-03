"""Author the forklift-only catalogue extension; preserve every existing item ID."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
OPTIONS = {
    "hood": [("stock", "Original", "Factory finish"), ("fork_vent", "Vent cover", "Raised slotted engine cover"), ("fork_rib", "Ribbed cover", "Longitudinal engine ribs"), ("fork_twin", "Twin intake", "Paired engine intakes"),
             ("fork_scoop", "Raised scoop", "Broad intake with a recessed mouth"), ("fork_louvre", "Split louvres", "Two banks of angled cooling slats"), ("fork_split", "Split cover", "Twin raised shoulders around a centre channel"), ("fork_dome", "Domed cover", "Low rounded engine blister"), ("fork_fan", "Fan grille", "Circular cooling grille with radial ribs"), ("fork_cross", "Cross ribs", "Cross-braced engine cover"), ("fork_flush", "Inset panel", "Low inset panel with perimeter trim"), ("fork_armour", "Armoured cover", "Three overlapping protective panels"), ("fork_channel", "Cooling channels", "Four deep longitudinal cooling channels"), ("fork_race", "Swept intakes", "Swept paired intakes with a centre spine")],
    "aero": [("stock", "Original", "Factory finish"), ("fork_bar", "Steel bar", "Polished rear protection bar"), ("fork_wrap", "Wraparound guard", "Guard wrapping the rear corners"), ("fork_twin", "Twin bar", "Two rear protection bars"),
             ("fork_low", "Low guard", "Low wide protection rail"), ("fork_bow", "Chevron guard", "Angled rear rail with a raised centre"), ("fork_step", "Step guard", "Rear guard with a ribbed centre step"), ("fork_mesh", "Grille guard", "Framed guard with an open bar grille"), ("fork_roller", "Roller guard", "Three rounded protective rollers"), ("fork_plate", "Shield guard", "Broad painted rear shield"), ("fork_cage", "Cross brace guard", "Twin rails with diagonal braces"), ("fork_arc", "Curved guard", "Segmented curved rear protection rail"), ("fork_rib", "Ribbed guard", "Wide rear beam with vertical buffers"), ("fork_tow", "Tow guard", "Split protection rails around a towing eye")],
    "rims": [("stock", "Original", "Factory finish"), ("fork_disc", "Solid disc", "Smooth wheel covers"), ("fork_ring", "Bright ring", "Polished outer rings"), ("fork_spoke", "Six spoke", "Six spoke wheel covers"),
             ("fork_three", "Three spoke", "Three broad open spokes"), ("fork_four", "Four spoke", "Four square-section open spokes"), ("fork_five", "Five spoke", "Five tapered open spokes"), ("fork_eight", "Eight spoke", "Eight narrow open spokes"), ("fork_turbine", "Turbine cover", "Nine swept cooling blades"), ("fork_mesh", "Cross mesh cover", "Crossed paired spokes"), ("fork_dish", "Deep dish cover", "Recessed dish with a raised outer lip"), ("fork_bolt", "Bolted cover", "Solid face with eight raised fasteners"), ("fork_slots", "Slotted cover", "Recessed dark radial slots"), ("fork_star", "Star cover", "Five paired star spokes")],
    "body": [("stock", "Original", "Factory cabin frame"), ("fork_rail", "Tubular frame", "Round posts and open roof rails"), ("fork_plate", "Pressed frame", "Wide pressed pillars and a slotted roof"), ("fork_twin", "Twin hoop frame", "Paired overhead hoops with linking rails"),
             ("fork_canted", "Canted frame", "Swept front pillars and a tapered roof"), ("fork_round", "Rounded frame", "Rounded upper corners with tubular pillars"), ("fork_cross", "Cross brace frame", "Open roof with diagonal rear bracing"), ("fork_canopy", "Canopy frame", "Solid painted sun canopy on slim pillars"), ("fork_lattice", "Lattice frame", "Open lattice roof on reinforced posts"), ("fork_arch", "Arched frame", "Raised curved roof ribs on four posts"), ("fork_sport", "Sport frame", "Angled pillars and a split centre roof spine"), ("fork_mesh", "Grid frame", "Protective roof grid with close cross rails"), ("fork_heavy", "Heavy duty frame", "Deep corner posts and reinforced roof beams"), ("fork_safari", "Safari frame", "Raised perimeter rack and open roof slats")],
}

def main():
    path = ROOT / "game/vehicle/vehicle_customisation.gd"
    text = path.read_text(encoding="utf-8")
    start = text.index("const FORKLIFT_LABELS:")
    end = text.index("const HOVER_LABELS:", start)
    block = 'const FORKLIFT_LABELS: Dictionary = {"hood":"Engine cover", "aero":"Rear guard", "rims":"Wheel covers", "body":"Cabin frame"}\n'
    block += 'const FORKLIFT_OPTIONS: Dictionary = {\n'
    block += ',\n'.join('\t'+json.dumps(c)+':'+json.dumps([[i,n] for i,n,_ in rows],separators=(',',':')) for c,rows in OPTIONS.items())+'}\n'
    block += 'const FORKLIFT_DESCRIPTIONS: Dictionary = {\n'
    block += ',\n'.join('\t'+json.dumps(c)+':'+json.dumps([d for _,_,d in rows],separators=(',',':')) for c,rows in OPTIONS.items())+'}\n'
    path.write_text(text[:start]+block+text[end:],encoding="utf-8",newline="\n")
    path = ROOT / "backend/bmt_backend/vehicle_appearance_catalog.json"
    text = path.read_text(encoding="utf-8")
    catalog = json.loads(text)
    catalog["forklift_parts"] = {c:[i for i,_,_ in rows] for c,rows in OPTIONS.items()}
    path.write_text(json.dumps(catalog,indent=2,ensure_ascii=False)+'\n',encoding="utf-8",newline="\n")

if __name__ == "__main__":
    main()
