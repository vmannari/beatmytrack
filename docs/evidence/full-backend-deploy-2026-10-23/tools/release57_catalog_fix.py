"""Fix Cloud SQL collation-dependent discovery bounds; no schema or canonical change."""
import argparse
import importlib.util
import json
import secrets
import shutil
import subprocess
import time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('cutover57',ROOT/'.tools/release57_cutover.py')
cut=importlib.util.module_from_spec(spec);spec.loader.exec_module(cut)
d=cut.d
WORK=d.WORK/'catalog-fix';WORK.mkdir(exist_ok=True)
RECEIPT=d.OUTPUT/'catalog-fix-rollout.json'
r=json.loads(RECEIPT.read_text()) if RECEIPT.exists() else {}


def save():RECEIPT.write_text(json.dumps(r,indent=2)+'\n')


def prepare():
    assert d.r.get('promoted') and d.r.get('native_storage_smoke')
    folder=WORK/'image';folder.mkdir(exist_ok=False)
    module=ROOT/'backend/bmt_backend/discovery_projection.py'
    shutil.copyfile(module,folder/module.name)
    sha=d.digest(module.read_bytes())
    install="""import hashlib,json
from pathlib import Path
p=Path('/app/latest-package-proof.json');v=json.loads(p.read_text())
sha=hashlib.sha256(Path('/app/bmt_backend/discovery_projection.py').read_bytes()).hexdigest()
assert sha==__SHA__
v['source_hashes']['discovery_projection.py']=sha
v['post_migration_correction']={'module':'discovery_projection.py','sha256':sha,'reason':'English-collation UUID partition bounds; no canonical/schema change'}
p.write_text(json.dumps(v))
""".replace('__SHA__',repr(sha))
    (folder/'install.py').write_text(install,encoding='utf-8',newline='\n')
    (folder/'Dockerfile').write_text('FROM '+d.r['image']+'\nUSER root\nCOPY discovery_projection.py /app/bmt_backend/discovery_projection.py\nCOPY install.py /tmp/catalog-fix-install.py\nRUN python /tmp/catalog-fix-install.py\nUSER 10001:10001\n',newline='\n')
    shutil.copytree(d.WORK/'gate-tests',WORK/'tests',ignore=shutil.ignore_patterns('__pycache__','.pytest_cache'))
    shutil.copyfile(ROOT/'backend/tests/test_discovery_projection.py',WORK/'tests/test_discovery_projection.py')
    r.update(base_image=d.r['image'],base_local_tag=d.r['local_tag'],source_sha256=sha,local_tag='bmt-schema57-catalog:'+sha[:16])
    save();print(json.dumps({'prepared':True,'changed_runtime_files':1,'source_sha256':sha}))


def build():
    b=d.builder()
    result=b.runner.run([*b.c['docker'],'build','--network=none','--pull=false','--file=catalog-fix/image/Dockerfile','--tag='+r['local_tag'],'catalog-fix/image'])
    (WORK/'build.private.log').write_text(result)
    r['image_id']=json.loads(b.runner.run([*b.c['docker'],'image','inspect',r['local_tag'],'--format={{json .Id}}']))
    save();print(json.dumps({'candidate':r['image_id']}))


def test(control=False):
    b=d.builder();docker=b.c['docker'];suffix=secrets.token_hex(4)
    network,pg='bmt-collation57-'+suffix,'bmt-collation57-pg-'+suffix
    label='bmt.collation57-owner='+d.config['owner'];password=secrets.token_urlsafe(24)
    b.runner.run([*docker,'network','create','--internal','--label='+label,network]);created=False
    try:
        b.runner.run([*docker,'run','--rm','-d','--name='+pg,'--network='+network,'--label='+label,
                      '-e','POSTGRES_USER=probe','-e','POSTGRES_DB=bmt_discovery_lab','-e','POSTGRES_PASSWORD='+password,
                      '-e','POSTGRES_INITDB_ARGS=--locale=en_US.utf8','postgres:17']);created=True
        for _ in range(60):
            try:
                if 'accepting connections' in b.runner.run([*docker,'exec',pg,'pg_isready','-U','probe']):break
            except RuntimeError:pass
            time.sleep(.3)
        else:raise RuntimeError('English-collation fixture unavailable')
        locale=b.runner.run([*docker,'exec',pg,'psql','-U','probe','-d','bmt_discovery_lab','-Atc','SELECT datcollate FROM pg_database WHERE datname=current_database()'])
        assert locale=='en_US.utf8',locale
        endpoint='postgresql+psycopg://probe:'+password+'@127.0.0.1:5432/bmt_discovery_lab'
        linux=lambda p:'/mnt/'+p.drive[0].lower()+p.as_posix()[2:]
        files=['test_discovery_projection.py'] if control else ['test_discovery_v3.py','test_discovery_projection.py','test_discovery_resources.py','test_discovery_hardening.py']
        args=[*docker,'run','--rm','--network=container:'+pg,'--label='+label,'--entrypoint=python',
              '--mount=type=bind,source='+linux(WORK/'tests')+',target=/test-work/backend/tests,readonly',
              '-e','PYTHONPATH=/app:/test-work/backend/tests','-e','BMT_DISCOVERY_TEST_DATABASE_URL='+endpoint,'-e','BMT_TEST_DATABASE_URL='+endpoint,
              r['base_local_tag'] if control else r['local_tag'],'-m','pytest',*['/test-work/backend/tests/'+file for file in files],
              '-q','--tb=short','--show-capture=no','-c','/app/pyproject.toml','-p','no:cacheprovider','-k',
              'test_partition_bounds_cover_hex_ids_under_english_collation and postgres' if control else 'postgres']
        process=subprocess.run(args,capture_output=True,text=True,encoding='utf-8',timeout=1800)
        log=(process.stdout+process.stderr).replace(password,'[REDACTED]')
        (d.OUTPUT/('catalog-collation-control.log' if control else 'catalog-collation-tests.log')).write_text(log,encoding='utf-8')
        if control:
            assert process.returncode!=0 and 'test_partition_bounds_cover_hex_ids_under_english_collation' in log and 'AssertionError' in log
            r['original_reproduced']=True
        else:
            assert process.returncode==0,'See catalog-collation-tests.log'
            r['english_collation_tests_passed']=True
        save();print(log[-2500:])
    finally:
        if created:
            labels=json.loads(b.runner.run([*docker,'inspect',pg,'--format={{json .Config.Labels}}']));assert labels.get('bmt.collation57-owner')==d.config['owner'];b.runner.run([*docker,'stop',pg])
        labels=json.loads(b.runner.run([*docker,'network','inspect',network,'--format={{json .Labels}}']));assert labels.get('bmt.collation57-owner')==d.config['owner'];b.runner.run([*docker,'network','rm',network])


def push():
    assert r.get('original_reproduced') and r.get('english_collation_tests_passed')
    b=d.builder();auth=d.WORK/'catalog-push-auth';auth.mkdir(exist_ok=False)
    try:
        registry=d.config['region']+'-docker.pkg.dev';token=d.service.call('auth','print-access-token')
        b.runner.run([*b.c['docker'],'--config=catalog-push-auth','login',registry,'--username=oauth2accesstoken','--password-stdin'],input_data=token)
        remote=registry+'/'+d.config['project']+'/'+d.service.n['repo']+'/backend:schema57-catalog-'+r['source_sha256'][:16]
        b.runner.run([*b.c['docker'],'tag',r['local_tag'],remote]);b.runner.run([*b.c['docker'],'--config=catalog-push-auth','push',remote])
        r['image']=next(value for value in json.loads(b.runner.run([*b.c['docker'],'image','inspect',remote,'--format={{json .RepoDigests}}'])) if value.startswith(registry+'/'));save()
    finally:
        assert auth.resolve().parent==d.WORK.resolve() and not auth.is_symlink();shutil.rmtree(auth)
    print(json.dumps({'image':r['image']}))


def rollout():
    assert r.get('image') and r.get('english_collation_tests_passed')
    allowed=[r['base_image'],r['image']]
    cut.guard('api',d.service.n['api'],allowed)
    d.service.call('run','services','update',d.service.n['api'],'--region='+d.config['region'],'--image='+r['image'],
                   '--no-traffic','--tag='+d.r['canary_tag'],'--format=json')
    api=cut.guard('api',d.service.n['api'],[r['image']])
    route=next(value for value in api['status']['traffic'] if value.get('tag')==d.r['canary_tag'])
    assert route.get('percent',0)==0
    r.update(api_revision=route['revisionName'],api_canary_url=route['url']);save()
    d.verify_http(route['url'])
    cut.guard('worker',d.service.n['worker'],allowed)
    d.service.call('run','worker-pools','update',d.service.n['worker'],'--region='+d.config['region'],'--image='+r['image'],'--format=json')
    worker=cut.guard('worker',d.service.n['worker'],[r['image']])
    r['worker_revision']=worker.get('status',{}).get('latestReadyRevisionName');save()
    for name,kind in d.r['targets'].items():
        if kind!='job':continue
        value=cut.guard(kind,name,allowed)
        if d.stage.resource_image(value)!=r['image']:
            d.service.call('run','jobs','update',name,'--region='+d.config['region'],'--image='+r['image'],'--format=json')
    code='''import json,time
from sqlalchemy import text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
s=Settings.from_env();e=make_engine(s.database_url,s)
for turn in range(120):
 with e.connect() as c:
  source=c.scalar(text("SELECT count(*) FROM tracks t WHERE EXISTS(SELECT 1 FROM track_versions v WHERE v.track_id=t.id AND v.state='published')"))
  missing=c.scalar(text("SELECT count(*) FROM tracks t WHERE EXISTS(SELECT 1 FROM track_versions v WHERE v.track_id=t.id AND v.state='published') AND NOT EXISTS(SELECT 1 FROM discovery_heads h WHERE h.track_id=t.id)"))
 if missing==0:break
 time.sleep(2)
else:raise RuntimeError('Bounded source audit did not restore catalogue coverage')
print('LATEST_RESULT='+json.dumps({'published_tracks':source,'missing_projection_heads':missing,'manual_projection_mutations':0}));e.dispose()
'''
    coverage=d.execute('catalog-coverage-restored',code,timeout=360)
    assert coverage['missing_projection_heads']==0
    d.service.call('run','services','update-traffic',d.service.n['api'],'--region='+d.config['region'],
                   '--to-revisions='+route['revisionName']+'=100','--format=json')
    d.r.update(image=r['image'],candidate_id=r['image_id'],local_tag=r['local_tag'],canary_revision=route['revisionName'],
               canary_url=route['url'],catalog_collation_fix={'sha256':r['source_sha256'],'base_image':r['base_image'],
                   'final_image':r['image'],'published_tracks':coverage['published_tracks'],'missing_projection_heads':0})
    checked=d.verify_http(d.r['url'],True)
    (d.OUTPUT/'verify-live.json').write_text(json.dumps(checked,indent=2)+'\n')
    d.save();r['cloud_completed']=True;save()
    print(json.dumps({'api_revision':r['api_revision'],'worker_revision':r['worker_revision'],'coverage':coverage,'image':r['image']}))


def pc_rollout():
    assert r.get('cloud_completed')
    spec=importlib.util.spec_from_file_location('pc57',ROOT/'.tools/release57_pc.py')
    p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
    source=WORK/'pc-source'
    if not source.exists():
        shutil.copytree(d.WORK/'frozen/backend/bmt_backend',source,ignore=shutil.ignore_patterns('__pycache__'))
        shutil.copyfile(WORK/'image/discovery_projection.py',source/'discovery_projection.py')
    assert d.digest((source/'discovery_projection.py').read_bytes())==r['source_sha256']
    override_path=d.WORK/'pc.override.json';override=json.loads(override_path.read_text())
    linux='/mnt/'+source.drive[0].lower()+source.as_posix()[2:]
    for role in ['api','worker','migrate']:
        override['services'][role]['image']=r['local_tag']
        override['services'][role]['volumes']=[linux+':/app/bmt_backend:ro']
    override_path.write_text(json.dumps(override,indent=2)+'\n')
    p.pc.r.update(image=r['local_tag'],image_id=r['image_id'],catalog_collation_fix=r['source_sha256'])
    p.pc.save()
    p.compose('up','-d','--no-build','--no-deps','--wait','--wait-timeout','180','api','worker')
    p.pc.verify();r['pc_completed']=True;save()


def main():
    actions={'prepare':prepare,'build':build,'control':lambda:test(True),'test':test,'push':push,'rollout':rollout,'pc':pc_rollout}
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('stage',choices=actions);actions[parser.parse_args().stage]()


if __name__=='__main__':main()
