"""Author the forklift-only catalogue extension; preserve every existing item ID."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
OPTIONS = {'hood': [('stock', 'Original', 'Factory engine cover'),
          ('fork_vent', 'Louvre cassette', 'Broad recessed cooling cassette in a folded steel shell'),
          ('fork_rib', 'Cast fin cover', 'Nine integral cooling fins in a cast alloy shell'),
          ('fork_twin', 'Butterfly cover', 'Independent curved service doors with a central joint'),
          ('fork_scoop', 'Raised rear intake', 'Rising formed shell with a wide recessed rear intake'),
          ('fork_louvre', 'Herringbone louvres', 'Opposed diagonal vanes beneath a folded centre ridge'),
          ('fork_split', 'Two-piece service cover', 'Painted hinge shell and a separate graphite lift-out panel'),
          ('fork_dome', 'Barrel cover', 'Broad curved crown with narrow shoulder cooling banks'),
          ('fork_fan', 'Circular filter cover', 'Round filter cassette with a rolled rim and captive screws'),
          ('fork_cross', 'Captive service hatch', 'Chamfered removable hatch with six captive fasteners'),
          ('fork_flush', 'Flush cover', 'Clean low shell with a narrow rear breathing slot'),
          ('fork_armour', 'Protected shoulders', 'Formed cover with bolted shoulder wear plates'),
          ('fork_channel', 'Pressed flutes', 'Four deep longitudinal pressings in a continuous shell'),
          ('fork_race', 'Folded side vents', 'Creased centre crown and recessed shoulder intakes')],
 'aero': [('stock', 'Original', 'Factory counterweight bumper'),
          ('fork_bar', 'Pressed impact beam', 'Folded steel beam with a rolled return and end cheeks'),
          ('fork_wrap', 'Wraparound guard', 'Continuous painted corner returns and replaceable buffers'),
          ('fork_twin', 'Twin tube rails', 'Separated round impact rails on substantial mounting webs'),
          ('fork_low', 'Low rubber shoe', 'Low moulded rubber impact shoe on a steel backing'),
          ('fork_bow', 'Swept wing guard', 'Continuous rising wing beam with protected outer ends'),
          ('fork_step', 'Recessed step guard', 'Raised impact wings around a recessed cast-tread step'),
          ('fork_mesh', 'Open service grille', 'Open vertical vanes within a welded steel frame'),
          ('fork_roller', 'Dock roller guard', 'Rubber dock rollers on captive axles and supported brackets'),
          ('fork_plate', 'Counterweight shield', 'Faceted painted shield with a replaceable lower rubber face'),
          ('fork_cage', 'Braced box guard', 'Open box frame with diagonal braces and corner pads'),
          ('fork_arc', 'Rolled steel tube', 'Broad curved round tube held by mounting saddles'),
          ('fork_rib', 'Triple dock buffers', 'Three moulded ribbed pads on a recessed carrier rail'),
          ('fork_tow', 'Clevis towing guard', 'Bored twin clevis ears and a captive vertical towing pin')],
 'rims': [('stock', 'Original', 'Factory pressed steel wheel'),
          ('fork_disc', 'Pressed steel', 'Dished steel face with a raised hub and rolled lip'),
          ('fork_ring', 'Rolled rim', 'Formed outer rim surrounding the factory hub'),
          ('fork_spoke', 'Six vent steel', 'Six cooling apertures in a dished steel face'),
          ('fork_three', 'Three vent cast', 'Three broad openings in a substantial cast face'),
          ('fork_four', 'Four vent cast', 'Four rounded openings in a cast wheel face'),
          ('fork_five', 'Five vent cast', 'Five rounded openings around a bolted hub'),
          ('fork_eight', 'Eight vent steel', 'Eight narrow cooling apertures in pressed steel'),
          ('fork_turbine', 'Cooling vent steel', 'Ten cooling apertures with a rolled outer flange'),
          ('fork_mesh', 'Perforated steel', 'Twelve small ventilation openings'),
          ('fork_dish', 'Recessed steel', 'Recessed dish with a raised bolted hub'),
          ('fork_bolt', 'Split rim', 'Bolted split rim with a visible flange seam'),
          ('fork_slots', 'Oval vent steel', 'Eight broad oval cooling apertures'),
          ('fork_star', 'Five rib cast', 'Five compact openings in a reinforced cast face')],
 'body': [('stock', 'Original', 'Factory overhead guard'),
          ('fork_rail', 'Round hoop frame', 'Round transverse hoops joined by slim roof ties'),
          ('fork_plate', 'Pressed pillar frame', 'Broad tapered rear pillars and painted roof blades'),
          ('fork_twin', 'Rear cantilever frame', 'Twin rear goosenecks carry an open-front roof'),
          ('fork_canted', 'Swept frame', 'Rearward-swept pillars and a sloping longitudinal roof'),
          ('fork_round', 'Barrel roof frame', 'Long curved side arches carry a rounded barrel roof'),
          ('fork_cross', 'Crossbeam frame', 'Low roof with crossed braces and painted corner haunches'),
          ('fork_canopy', 'Weather canopy', 'Full overhanging painted roof with deep rain gutters'),
          ('fork_lattice', 'Diamond roof frame', 'Slim straight pillars beneath an open diamond roof lattice'),
          ('fork_arch', 'Vaulted frame', 'High transverse roof arches above low side rails'),
          ('fork_sport', 'Wedge frame', 'Tapered wedge roof with three broad longitudinal slats'),
          ('fork_mesh', 'Screen roof frame', 'Fine metal roof screen on a light alloy-coloured frame'),
          ('fork_heavy', 'Heavy duty frame', 'Deep painted roof rails and broad rear pillar haunches'),
          ('fork_safari', 'Sun shade frame', 'Extended pale front shade above an open rear roof')]}

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
