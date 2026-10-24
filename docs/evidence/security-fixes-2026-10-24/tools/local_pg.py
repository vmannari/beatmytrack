"""Own disposable PostgreSQL fixture; never connects to the running PC database."""
import json, secrets, subprocess, sys, time
from pathlib import Path
p=Path(__file__).resolve().parent
name='bmt-security-fixes-20261024'
def docker(*args,check=True):
    return subprocess.run(['wsl.exe','-d','Ubuntu','--','docker',*args],capture_output=True,text=True,check=check)
if sys.argv[1]=='start':
    if docker('inspect',name,check=False).returncode==0: raise RuntimeError('Fixture name already exists')
    password=secrets.token_hex(32)
    env=p/'postgres.env'; env.write_text('POSTGRES_PASSWORD='+password+'\nPOSTGRES_DB=bmt_security\n')
    unix='/mnt/c/'+str(env)[3:].replace('\\','/')
    docker('run','--detach','--name',name,'--label','bmt-purpose=security-fixes-20261024','--pull=never',
        '--publish','127.0.0.1:55461:5432','--env-file',unix,'--tmpfs','/var/lib/postgresql/data:rw',
        '--memory','768m','--cpus','1','postgres:17-bookworm','-c','max_connections=40')
    for _ in range(50):
        if docker('exec',name,'pg_isready','-U','postgres','-d','bmt_security',check=False).returncode==0: break
        time.sleep(.2)
    else: raise RuntimeError('Fixture did not become ready')
    (p/'postgres-state.json').write_text(json.dumps({'url':'postgresql+psycopg://postgres:'+password+'@127.0.0.1:55461/bmt_security'}))
    print('Owned PostgreSQL17 fixture ready on loopback55461')
elif sys.argv[1]=='stop':
    value=json.loads(docker('inspect',name).stdout)[0]
    if value['Config']['Labels'].get('bmt-purpose')!='security-fixes-20261024': raise RuntimeError('Wrong fixture owner')
    docker('rm','--force',name); print('Removed owned PostgreSQL fixture')
