"""CST01-CST04: isolated next ten-percent step, preserving earlier receipts."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
if (root/'scripts/run_car_step10.py').exists():raise RuntimeError('Bootstrap already completed; use the reviewed step10 tools directly.')
def adapt(text):return text.replace('car15-2026-11-15','car-step10-2026-11-15').replace('car15','car_step10')
for name in ('run_car15.py','check_car15_geometry.py','remesh_car15.py','car15_contacts.py'):
    text=adapt((root/'scripts'/name).read_text())
    if name in ('remesh_car15.py','car15_contacts.py'):
        text=text.replace("('compact','kart','electric','hovercraft')","('compact','kart','forklift','electric','hovercraft')")
    (root/'scripts'/name.replace('car15','car_step10')).write_text(text)
for folder,name in [('game/tests/support','car15_source.gd'),('game/tests/support','car15_showroom.gd')]+[
    ('game/tests',name) for name in ('survey_car15.gd','export_car15_proof.gd','export_car15_retessellation.gd','install_car15_remeshed.gd','stage_car15.gd','capture_car15.gd')]:
    text=adapt((root/folder/name).read_text())
    if name=='survey_car15.gd':
        text=text.replace('"blend_shapes":part.mesh.get_blend_shape_count()', '"authored":part.mesh.has_meta("car_authored_far"),"guide_locked":part.mesh.has_meta("car_surface_guide_locked"),"blend_shapes":part.mesh.get_blend_shape_count()')
    if name=='stage_car15.gd':text=text.replace('_step15_','_step10_')
    (root/folder/name.replace('car15','car_step10')).write_text(text)
# Use the complete qualified detached snapshot helper, including root transform.
text=(root/'game/tests/capture_car15_baseline.gd').read_text().replace('car15-2026-11-15','car-step10-2026-11-15')
text=text.replace('for id: String in VehicleCatalog.IDS:', 'for id: String in ["compact","kart","forklift","electric","hovercraft","super_rally"]:').replace('\t\tif id=="super_rally": continue\n','')
(root/'game/tests/capture_car_step10_baseline.gd').write_text(text)
text=(root/'scripts/start_rally_front.py').read_text().replace('run_rally_front','run_car_step10')
text=text.replace("'game/vehicle/compact_headlamp.gdshader',", "'game/vehicle/compact_headlamp.gdshader','game/vehicle/electric_reference_body.gd','game/vehicle/electric_reference_details.gd','game/vehicle/electric_reference_mesh.gd',")
(root/'scripts/start_car_step10.py').write_text(text)
print('CAR_STEP10_TOOLS fresh evidence/profile namespace; previous source and native controls preserved')
