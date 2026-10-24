import json,os,subprocess,sys
from pathlib import Path
p=Path(__file__).resolve().parent
env=dict(os.environ,PYTHONPATH=str(Path.cwd()/'backend'))
state=p/'postgres-state.json'
if state.exists():
 env['BMT_GCP_SETUP_TEST_DATABASE_URL']=json.loads(state.read_text())['url'].replace(':55461/', ':5432/') if os.name=='posix' else json.loads(state.read_text())['url']
 env['BMT_TEST_DATABASE_URL']=env['BMT_GCP_SETUP_TEST_DATABASE_URL']
label=sys.argv[1]
args=[sys.executable,'-m','pytest',*sys.argv[2:],'--basetemp='+str(p/label),'--junitxml=docs/evidence/security-fixes-2026-10-24/'+label+'.xml']
result=subprocess.run(args,env=env,capture_output=True,text=True)
(Path('docs/evidence/security-fixes-2026-10-24')/(label+'.log')).write_text(result.stdout+result.stderr,encoding='utf-8')
print((result.stdout+result.stderr)[-10000:]);sys.exit(result.returncode)
