from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[3]
runner=str(Path(__file__).with_name('run_check.py'))
checks=[('geometry','res://../docs/evidence/challenger-panels-2026-11-12/design_check.gd',[]),
 ('fitted-final','res://tests/test_super_rally_c3_kits.gd',[]),
 ('wash','res://tests/test_car_wash.gd',['--evidence-root=res://../docs/evidence/challenger-panels-2026-11-12/wash']),
 ('driving','res://tests/test_driving.gd',[]),
 ('parser','res://../docs/evidence/super-rally-design-2026-11-08/production_parse.gd',[])]
for label,script,args in checks:
 command=[sys.executable,runner,label,script,'--headless','--audio-driver','Dummy']
 if args:command+=['--',*args]
 subprocess.run(command,cwd=root,check=True)
