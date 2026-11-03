"""Author the forklift-only catalogue extension; preserve every existing item ID."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
OPTIONS = {'hood': [('stock', 'Original', 'Factory engine cover'),
          ('fork_vent', 'Louvred steel', 'Formed steel lid with an inset cooling bank'),
          ('fork_rib', 'Pressed ribs', 'Pressed stiffeners around a recessed cooling panel'),
          ('fork_twin', 'Twin vent lid', 'Paired inset vents in a single formed lid'),
          ('fork_scoop', 'Rear intake lid', 'Shallow rear cooling inlet in a crowned steel lid'),
          ('fork_louvre', 'Split louvres', 'Two recessed louvre banks with a centre bridge'),
          ('fork_split', 'Service split lid', 'Split panel shoulders and a narrow service channel'),
          ('fork_dome', 'Crowned steel', 'Gently crowned lid with a rear cooling slot'),
          ('fork_fan', 'Screened vent', 'Recessed longitudinal cooling grille'),
          ('fork_cross', 'Service panel lid', 'Two inset cooling panels with a service divider'),
          ('fork_flush', 'Flush service lid', 'Low lid with a flush latch and rear vent'),
          ('fork_armour', 'Reinforced lid', 'Inset cooling bank and protected panel edges'),
          ('fork_channel', 'Channelled steel', 'Four recessed longitudinal cooling channels'),
          ('fork_race', 'Side vent lid', 'Low formed lid with paired cooling channels')],
 'aero': [('stock', 'Original', 'Factory counterweight bumper'),
          ('fork_bar', 'Pressed steel guard', 'Shaped steel impact beam on bolted mounting shoes'),
          ('fork_wrap', 'Corner guard', 'Contoured bumper with replaceable corner buffers'),
          ('fork_twin', 'Twin rail guard', 'Joined upper and lower impact rails'),
          ('fork_low', 'Low impact guard', 'Low rubber-faced counterweight protection'),
          ('fork_bow', 'Swept guard', 'Formed beam following the counterweight corners'),
          ('fork_step', 'Service step guard', 'Recessed anti-slip service step in the bumper'),
          ('fork_mesh', 'Service grille guard', 'Protected recessed service grille'),
          ('fork_roller', 'Dock buffers', 'Paired rubber buffers on a shaped bumper'),
          ('fork_plate', 'Counterweight shield', 'Formed painted shield with a rolled edge'),
          ('fork_cage', 'Box section guard', 'Closed beam with reinforced capped ends'),
          ('fork_arc', 'Rolled tube guard', 'Continuous curved steel protection tube'),
          ('fork_rib', 'Ribbed buffers', 'Replaceable ribbed rubber impact pads'),
          ('fork_tow', 'Clevis guard', 'Supported towing clevis with a captive pin')],
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
          ('fork_rail', 'Tubular guard', 'Continuous bent portals with bolted feet'),
          ('fork_plate', 'Pressed guard', 'Formed pillars with reinforced upper corners'),
          ('fork_twin', 'Channel guard', 'Paired roof channels with linking headers'),
          ('fork_canted', 'Raked guard', 'Gently raked pillars and longitudinal roof bars'),
          ('fork_round', 'Rounded guard', 'Continuous portals with generous upper bends'),
          ('fork_cross', 'Gusset guard', 'Compact upper gussets leave the rear view open'),
          ('fork_canopy', 'Weather canopy', 'Fitted formed steel roof with drip edges'),
          ('fork_lattice', 'Cargo guard', 'Open roof ribs with longitudinal stiffeners'),
          ('fork_arch', 'Crowned guard', 'Shallow formed roof ribs on continuous portals'),
          ('fork_sport', 'Clear-view guard', 'Slim longitudinal roof bars and raked pillars'),
          ('fork_mesh', 'Screen roof guard', 'Close roof grid on continuous steel portals'),
          ('fork_heavy', 'Reinforced guard', 'Substantial portals and replaceable wear inserts'),
          ('fork_safari', 'Sun visor guard', 'Short formed visor over an open protective roof')]}

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
