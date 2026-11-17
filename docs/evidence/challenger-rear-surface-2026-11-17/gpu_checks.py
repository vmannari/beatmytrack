from pathlib import Path
import json,subprocess,sys
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
base='res://../docs/evidence/'+out.name+'/'
results=[]
for renderer in ['gl_compatibility','mobile']:
 for tier in ['simple','full']:
  label='final-'+renderer+'-'+tier
  command=[sys.executable,str(out/'run_check.py'),label,base+'capture.gd','--rendering-method',renderer,'--audio-driver','Dummy','--','--prepared','--stage=final',*(['--full'] if tier=='full' else [])]
  subprocess.run(command,cwd=root,check=True)
  results.append({'label':label,'renderer':renderer,'tier':tier})
 for label,script,args in [('opacity-'+renderer,base+'opaque.gd',['--prepared','--evidence-root=res://../build/'+out.name+'/opacity']),('app-'+renderer,'res://tests/test_super_rally_ui.gd',['--evidence-root=res://../build/'+out.name+'/app'])]:
  subprocess.run([sys.executable,str(out/'run_check.py'),label,script,'--rendering-method',renderer,'--audio-driver','Dummy','--',*args],cwd=root,check=True)
  results.append({'label':label,'renderer':renderer})
 (out/'gpu-checks.json').write_text(json.dumps(results,indent=2))
