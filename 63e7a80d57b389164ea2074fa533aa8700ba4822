from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[3]
folder=Path(__file__).resolve().parent
runner=str(folder/'run_check.py')
checks=[('modules','res://tests/test_modular_car_assets.gd',['--headless'],['--vehicle=super_rally','--all-kits']),
 ('panels-final','res://../docs/evidence/challenger-panels-2026-11-12/panel_geometry.gd',['--headless'],[]),
 ('shading-final','res://../docs/evidence/challenger-panels-2026-11-12/surface_shading.gd',['--headless'],[]),
 ('physics','res://tests/test_super_rally.gd',['--headless'],['--prepared','--evidence-root=res://../docs/evidence/challenger-panels-2026-11-12/physics']),
 ('credit','res://../docs/evidence/challenger-panels-2026-11-12/credit.gd',['--headless'],[]),
 ('shadow-switch','res://../docs/evidence/challenger-panels-2026-11-12/shadow_switch.gd',['--headless'],[])]
for renderer,label in [('gl_compatibility','gl'),('mobile','mobile')]:
 checks.extend([
  ('opaque-'+label,'res://tests/test_challenger_hellcat.gd',['--rendering-method',renderer],['--prepared','--evidence-root=res://../docs/evidence/challenger-panels-2026-11-12/opaque']),
  ('app-'+label,'res://tests/test_super_rally_ui.gd',['--rendering-method',renderer],['--evidence-root=res://../docs/evidence/challenger-panels-2026-11-12/app']),
  ('review-'+label,'res://../docs/evidence/challenger-panels-2026-11-12/review.gd',['--rendering-method',renderer],['--stage=final'])])
 checks.append(('garage-final-'+label,'res://../docs/evidence/challenger-panels-2026-11-12/garage_detail.gd',['--rendering-method',renderer],['--stage=final','--prepared']))
for label,script,options,args in checks:
 command=[sys.executable,runner,label,script,'--audio-driver','Dummy',*options]
 if args:command+=['--',*args]
 subprocess.run(command,cwd=root,check=True)
