"""Review startup grant drift using disposable PostgreSQL, never a retained DB."""
import importlib.util
import json
import os
from pathlib import Path
import secrets
import subprocess
import time

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/security-second-review-2026-10-24'
OUT=ROOT/'docs/evidence/security-second-review-2026-10-24'
DOCKER=['wsl.exe','-d','Ubuntu','--','docker']
NETWORK='bmt-security-second-review-20261024'
PG=NETWORK+'-pg'
LABEL='bmt.security-second-review=20261024'

PROGRAM=r'''
import importlib.util,json,os,secrets
from types import SimpleNamespace
from sqlalchemy import text
from bmt_backend.db import make_engine
from bmt_backend.migrate import upgrade
spec=importlib.util.spec_from_file_location('review_grants','/review/database_privileges.py')
policy=importlib.util.module_from_spec(spec);spec.loader.exec_module(policy)
root=make_engine(os.environ['BMT_DATABASE_URL']);upgrade(root)
credentials={name:secrets.token_hex(32) for name in policy.DEFAULT_ROLES.values()}
with root.begin() as db:policy.provision_roles(db,credentials)
policy.configure(root)
base=root.url.set(username='bmt_worker',password=credentials['bmt_worker'])
worker=make_engine(base.render_as_string(hide_password=False))
settings=SimpleNamespace(environment='production',workload_role='worker')
policy.verify_runtime(worker,settings)
with root.begin() as db:db.execute(text('GRANT CREATE ON SCHEMA public TO bmt_worker'))
policy.verify_runtime(worker,settings)
with worker.begin() as db:db.execute(text('CREATE TABLE public.review_worker_created(id integer)'))
with root.begin() as db:db.execute(text('DROP TABLE public.review_worker_created'))
policy.configure(root)
with root.begin() as db:
 db.execute(text("INSERT INTO studio_staff(id,display_name,role,enabled,last_seen_at) VALUES ('review-fixture-staff','Fictional revoked staff','analyst',false,1)"))
 db.execute(text('GRANT UPDATE(enabled) ON public.studio_staff TO bmt_worker'))
policy.verify_runtime(worker,settings)
with worker.begin() as db:db.execute(text('UPDATE public.studio_staff SET enabled=true'))
with root.connect() as db:
 reenabled=db.scalar(text("SELECT enabled FROM public.studio_staff WHERE id='review-fixture-staff'"))
result={'disposable_postgresql_only':True,'baseline_restricted_worker_passed':True,
 'startup_accepted_unexpected_schema_create':True,'worker_created_table':True,
 'startup_accepted_unexpected_staff_update':True,'worker_reenabled_fictional_revoked_staff':reenabled}
print('REVIEW_RESULT='+json.dumps(result));worker.dispose();root.dispose()
'''

def main():
    WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    password=secrets.token_hex(32)
    pg_env=WORK/'postgres.private.env'
    pg_env.write_text('POSTGRES_PASSWORD='+password+'\nPOSTGRES_DB=bmt_review\n',encoding='utf-8')
    app_env=WORK/'app.private.env'
    app_env.write_text('BMT_DATABASE_URL=postgresql+psycopg://postgres:'+password+'@'+PG+':5432/bmt_review\n',encoding='utf-8')
    def unix(path):return '/mnt/'+path.drive[0].lower()+path.as_posix()[2:]
    def run(args,**kw):
        value=subprocess.run([*DOCKER,*args],capture_output=True,text=True,encoding='utf-8',timeout=240,**kw)
        if value.returncode:
            (WORK/'postgres-error.private.log').write_text(value.stdout+value.stderr,encoding='utf-8')
            raise RuntimeError('Disposable PostgreSQL probe failed; see private diagnostic')
        return value.stdout
    run(['network','create','--internal','--label',LABEL,NETWORK])
    created=False
    try:
        run(['run','-d','--rm','--name',PG,'--network',NETWORK,'--label',LABEL,'--env-file',unix(pg_env),
             '--tmpfs','/var/lib/postgresql/data:rw','postgres:17-bookworm']);created=True
        for _ in range(60):
            ready=subprocess.run([*DOCKER,'exec',PG,'pg_isready','-U','postgres'],capture_output=True)
            if ready.returncode==0:break
            time.sleep(.25)
        else:raise RuntimeError('Disposable PostgreSQL not ready')
        receipt=json.loads((ROOT/'build/security-deploy-2026-10-24/receipt.private.json').read_text(encoding='utf-8'))
        result=run(['run','--rm','-i','--network',NETWORK,'--label',LABEL,'--env-file',unix(app_env),
                    '--mount','type=bind,src='+unix(ROOT/'backend/bmt_backend/database_privileges.py')+',dst=/review/database_privileges.py,readonly',
                    '--entrypoint','python',receipt['local_tag'],'-'],input=PROGRAM)
        (OUT/'postgres-drift.log').write_text(result,encoding='utf-8')
        value=json.loads(result.split('REVIEW_RESULT=',1)[1])
        (OUT/'postgres-drift.json').write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(value))
    finally:
        if created:
            metadata=json.loads(run(['inspect',PG]))[0]
            assert metadata['Config']['Labels']['bmt.security-second-review']=='20261024'
            run(['stop',PG])
        metadata=json.loads(run(['network','inspect',NETWORK]))[0]
        assert metadata['Labels']['bmt.security-second-review']=='20261024'
        run(['network','rm',NETWORK])

if __name__=='__main__':main()
