"""C301-C302: create and independently review current-source candidate families."""
import json,subprocess,sys,shutil
from concurrent.futures import ThreadPoolExecutor
from run_car_pass10 import ROOT,OUT,WORK,run
BLENDER=ROOT/'build/tools/blender-4.5.15-windows-x64/blender.exe'
def checked(label,script):
    assert run(label,script,'--headless')==0,label
def blender(family):
    script='scripts/remesh_car_pass10'+('' if family=='remesh' else '_'+family.replace('-','_'))+'.py'
    with (OUT/('generate-'+family+'.log')).open('w',encoding='utf-8') as log:
        subprocess.run([str(BLENDER),'--background','--factory-startup','--python-exit-code','1','--python',script],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
    print('CP3_GENERATED',family,flush=True)
def proof(family,installer):
    checked('install-'+family,'res://tests/'+installer+'.gd')
    checked('export-'+family,'res://tests/export_car_pass10_proof.gd')
    with (OUT/('check-'+family+'.log')).open('w',encoding='utf-8') as log:
        subprocess.run([sys.executable,'scripts/check_car_pass10_geometry.py'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
    for name in ('candidate-plan.json','geometry-review.json'):shutil.copyfile(OUT/name,OUT/(family+'-'+name))
    review=json.loads((OUT/'geometry-review.json').read_text());print('CP3_PROVED',family,review['accepted'],review['rejected'],flush=True)
def main():
    families=['remesh','radial','fittings','body','kart-body','field-paint']
    with ThreadPoolExecutor(max_workers=3) as executor:
        jobs={family:executor.submit(blender,family) for family in families}
        proof('lod','bake_car_pass10_candidates')
        for family in families:
            jobs[family].result()
            proof(family,'install_car_pass10_'+('remeshed' if family=='remesh' else family.replace('-','_')))
    print('CP3_CANDIDATE_REVIEW_COMPLETE')
if __name__=='__main__':main()
