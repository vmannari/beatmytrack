"""Reuse the qualified front-review workflow for the owner's lamp-style feedback."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def adapt(text):
    return text.replace('rally-front-2026-11-15','rally-lamp-style-2026-11-15').replace('rally_front','rally_lamp_style')
for name in ('run','start','refresh','artwork','qualify','record','close','checkpoint'):
    path=root/'scripts'/f'{name}_rally_front.py'
    text=adapt(path.read_text())
    if name=='record':
        text=text.replace("modified=['game/vehicle/compact_grille.gd','game/vehicle/compact_front_lamps.gd']", "modified=['game/vehicle/compact_front_lamps.gd']")
        begin=text.index("added=['game/assets/vehicles/car_detail_v1/compact_front_lens.gdshader']")
        end=text.index('files={',begin)
        text=text[:begin]+"added=['game/'+name.removeprefix('res://') for name in json.loads((OUT/'recipe-migration.json').read_text())]\n"+text[end:]
    if name=='close':
        text=text.replace("'game/vehicle/compact_front_lamps.gd','game/vehicle/compact_grille.gd'", "'game/vehicle/compact_front_lamps.gd'")
        text=text.replace(",'snapshot-fixture-repair'",'').replace(",'snapshot-uniforms'",'')
        text=text.replace('Only Rally front geometry/finish is authored.', 'Only Rally lamp geometry/style is authored; grille and glazing are retained.')
    if name=='checkpoint':
        text=text.replace("RALLY-FRONT-20261115","RALLY-LAMP-STYLE-20261115").replace('RALLY_FRONT_REFINEMENT_2026_11_15','RALLY_LAMP_STYLE_2026_11_15')
        text=text.replace(",'scripts/archive_rally_draft_recipes.py'",'')
        text=text.replace('Two Rally front builders, scoped optic shader, two exact recipe migrations', 'Rally lamp builder and two exact recipe migrations')
    (root/'scripts'/f'{name}_rally_lamp_style.py').write_text(text)
for name in ('survey','stage','test','capture','test_app','test_legacy','bake_header','check_snapshots'):
    original={'test_app':'test_rally_front_app.gd','test_legacy':'test_rally_front_legacy.gd','bake_header':'bake_rally_front_header.gd','check_snapshots':'check_rally_front_snapshots.gd'}.get(name,f'{name}_rally_front.gd')
    target=original.replace('rally_front','rally_lamp_style')
    text=adapt((root/'game/tests'/original).read_text())
    if name in ('survey','stage'):
        text=text.replace('str(part.name).begins_with("FrontLamp") or str(part.name).begins_with("FrontGrille")','str(part.name).begins_with("FrontLamp")')
    if name=='survey':
        helper=(root/'game/tests/capture_car15_baseline.gd').read_text()
        function=helper[helper.index('func detach_snapshot'):helper.index('func capture_detail_baseline')]
        text=text.replace('func survey_front() -> void:',function+'\nfunc survey_front() -> void:')
        start=text.index('\t\t\t\tvar holder:=Node3D.new()')
        end=text.index('\t\t\t\tvar packed:=PackedScene.new()',start)
        text=text[:start]+'''\t\t\t\tvar holder: Node3D=detach_snapshot(car)
\t\t\t\troot.add_child(holder)
\t\t\t\tassert(holder.transform==car.transform and signature(holder)==masters[id+"_"+mode],"Exact detached before fixture")
'''+text[end:]
    if name=='test':
        text=text.replace('measured.triangles==15861,"reviewed front saves exactly 792 stock triangles"','measured.triangles==16213,"classic optics retain approximately fifteen percent from the restored baseline"')
    (root/'game/tests'/target).write_text(text)
(root/'scripts/import_rally_lamp_style_images.py').write_text(adapt((root/'scripts/import_rally_front_images.py').read_text()))
print('RALLY_LAMP_STYLE_TOOLS adapted isolated workflow; immutable before fixtures preserve original root transforms')
