"""Qualify native fallback rendering while shared prepared inputs are changing."""
from pathlib import Path
import hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
PREFIX='res://../docs/evidence/challenger-corner-roll-2026-11-13/'
def snapshot():
    files=[ROOT/'scripts/prepare_challenger.py',ROOT/'scripts/challenger_reference_geometry.py']
    files+=list((ROOT/'game/assets/vehicles/challenger_hellcat_v1').glob('*'))
    files+=[ROOT/('game/vehicle/'+name) for name in ['super_rally_model.gd','panel_contour.gd','panel_contour.gdshader','compact_finish.gd','challenger_panel_contours.gd','prepared_asset_dependencies.json']]
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files if p.is_file()}
receipts=json.loads((OUT/"direct-render-fences.json").read_text()) if "--resume" in sys.argv else {}
for renderer in (['mobile'] if '--mobile-only' in sys.argv else ['gl_compatibility','mobile']):
    cases=[('opaque-direct-'+renderer,PREFIX+'opaque.gd',['--evidence-root='+PREFIX+'opaque-direct']),
           ('app-final-'+renderer,'res://tests/test_super_rally_ui.gd',['--evidence-root='+PREFIX+'app-final']),
           ('garage-final-'+renderer,PREFIX+'garage_detail.gd',['--stage=final'])]
    for label,script,args in cases:
        before=snapshot()
        command=[sys.executable,str(OUT/'run_check.py'),label,script,'--audio-driver','Dummy','--rendering-method',renderer,'--',*args]
        result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
        after=snapshot()
        changed=[p for p in before if before[p]!=after[p]]
        receipts[label]={'exit_code':result.returncode,'before':before,'after':after,'changed':changed}
        (OUT/'direct-render-fences.json').write_text(json.dumps(receipts,indent=2))
        print(label,result.returncode,result.stdout[-950:],'changed',changed,flush=True)
        if result.returncode:sys.exit(result.returncode)
        assert not changed,'Renderer inputs changed; preserve receipt and repeat this case'
