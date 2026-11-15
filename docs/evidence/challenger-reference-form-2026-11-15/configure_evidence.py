from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
OLD='challenger-continuous-side-2026-11-15';NEW=OUT.name
for name in ['checkpoint.py','retain_final.py','gpu_checks.py']:
    text=(ROOT/'docs/evidence'/OLD/name).read_text().replace(OLD,NEW)
    if name=='checkpoint.py':
        text=text.replace("'scripts/challenger_side_surface.py']","'scripts/challenger_reference_form.py','game/vehicle/super_rally_model.gd']")
        text=text.replace('3 sources','4 sources')
    if name=='retain_final.py':
        text=text.replace("'scripts/challenger_exterior_geometry.py','.git/index'","'scripts/challenger_exterior_geometry.py','game/vehicle/super_rally_model.gd','.git/index'")
        text=text.replace("'baseline.json','candidate.json','side-profile.json'","'baseline.json','candidate.json'")
    if name=='gpu_checks.py':
        text=text.replace('tests=[','tests=[\n (\'opacity-gl\',base+\'opaque.gd\',\'gl_compatibility\',[\'--prepared\',\'--evidence-root=res://../build/'+NEW+'/opacity\']),\n (\'prepared-views-gl\',base+\'capture.gd\',\'gl_compatibility\',[\'--prepared\',\'--stage=final\']),')
    (OUT/name).write_text(text)
