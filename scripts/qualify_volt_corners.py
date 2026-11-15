"""VRC03: actual Volt consumers, native close-ups and retained assertions."""
import json,os
import run_volt_corners
from run_volt_corners import OUT,WORK
import refresh_car_10k_assets as refresh
import run_car_coarse_models as runner
def checked(label,script,*options):
    path=OUT/(label+'-receipt.json')
    if path.exists():
        value=json.loads(path.read_text())
        if value['exit_code']==0 and not value['errors']:return
    refresh.checked(label,script,*options)
def main():
    checked('prepared-models','res://tests/test_volt_corners.gd','--headless','--','--prepared')
    checked('all-kits','res://tests/test_volt_corners_modules.gd','--headless','--','--vehicle=electric','--all-kits')
    checked('parser','res://tests/check_model_refinement_parse.gd','--headless')
    checked('driving','res://tests/test_driving.gd','--headless')
    for method in ('gl_compatibility','mobile'):
        checked('native-'+method,'res://tests/capture_volt_corners.gd','--rendering-method',method)
        checked('app-'+method,'res://tests/test_volt_corners_app.gd','--rendering-method',method)
        folder=OUT/('icons-'+method);folder.mkdir(parents=True,exist_ok=True)
        os.environ['BMT_RIVALRY_CARS_EVIDENCE_DIR']=str(folder)
        path=OUT/('icons-'+method+'-receipt.json');value=json.loads(path.read_text()) if path.exists() else {}
        if not value or value['exit_code'] or value['errors']:
            runner.OUT=OUT;runner.WORK=WORK/('icons-'+method)
            assert runner.run('icons-'+method,'res://tests/test_volt_corners_icons.gd','--rendering-method',method)==0
        checked('wash-'+method,'res://tests/test_volt_corners_wash.gd','--rendering-method',method,'--','--evidence-root=res://../docs/evidence/volt-rear-corners-2026-11-15')
    print('VOLT_CORNER_QUALIFICATION complete')
if __name__=='__main__':main()
