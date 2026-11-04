"""Owner-authorised Studio-only moderation rollout; no live deletion or migration."""
import argparse
import base64
import hashlib
import importlib.util
import json
from pathlib import Path
import secrets
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
OUT = ROOT/'docs/evidence/reported-tracks-deployment-2026-11-04'
OUT.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location('release_util', ROOT/'build/full-backend-deploy-2026-10-26/deploy.py')
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)
d.WORK, d.OUT, d.STATE = WORK, OUT, WORK/'state.private.json'
d.state = json.loads(d.STATE.read_text()) if d.STATE.exists() else {}


class PrivateRunner(d.staging.Runner):
    def run(self, argv, *, input_data=None, allow_missing=False, cwd=None):
        assert cwd is None
        if 'print-identity-token' in argv or 'print-access-token' in argv:
            p = subprocess.run(argv, input=input_data, capture_output=True, text=True, timeout=60)
            assert p.returncode == 0, 'Credential refresh failed; no token output logged'
            return p.stdout.strip()
        return d.command(argv, 'cloud-command', input_data=input_data, allow_missing=allow_missing)


d.service = d.staging.Staging(d.config, WORK, PrivateRunner())
s, service = d.state, d.service
REGION = '--region='+d.config['region']
DOCKER = ['wsl.exe', '-d', 'Ubuntu', '--', 'docker']
NAME = service.n['admin']
SOURCES = [r['path'] for r in json.loads((ROOT/'docs/evidence/reported-tracks-2026-11-04/sources.json').read_text())
           if r['path'].startswith('backend/bmt_backend/')]


def inspect():
    assert not s.get('promoted')
    resource = service.describe('api', NAME)
    d.write(WORK/('before-'+NAME+'.private.json'), resource)
    s['targets'], s['parents'] = {NAME: 'api'}, {NAME: d.staging.resource_image(resource)}
    s['base'] = s['parents'][NAME]
    s['traffic_before'] = resource['status']['traffic']
    serving = [r for r in s['traffic_before'] if r.get('percent', 0)]
    assert len(serving) == 1 and serving[0]['percent'] == 100
    revision = json.loads(service.call('run', 'revisions', 'describe', serving[0]['revisionName'], REGION, '--format=json'))
    serving_image = revision['spec']['containers'][0]['image']
    if serving_image != s['base']:
        # Cloud Run resolves an OCI index to its platform manifest. Verify the
        # exact child digest rather than treating index/child references as drift.
        import requests
        registry, repository = s['base'].split('/', 1)
        repository, digest = repository.split('@')
        token = service.call('auth', 'print-access-token')
        result = requests.get('https://'+registry+'/v2/'+repository+'/manifests/'+digest,
            auth=('oauth2accesstoken', token), headers={'Accept': 'application/vnd.oci.image.index.v1+json'}, timeout=(5,30))
        del token
        result.raise_for_status()
        assert serving_image.split('@')[1] in {row['digest'] for row in result.json().get('manifests', [])}, 'Serving image is not a child of the configured index'
    s['serving_image_before'] = serving_image
    s['studio_url'] = resource['status']['url']
    api = service.describe('api', service.n['api'])
    s['api_before'] = {'image': d.staging.resource_image(api), 'traffic': api['status']['traffic']}
    s['api_url'] = api['status']['url']
    response = d.http(s['api_url'], '/v1/manifest')
    response.raise_for_status()
    s['manifest_before'] = response.json()
    ready = d.http(s['studio_url'], '/ready', private=True)
    ready.raise_for_status()
    s['schema'] = d.HEAD = ready.json()['schema']
    assert d.http(s['studio_url'], '/v1/admin/overview', private=True).status_code in (401, 403)
    assert d.http(s['api_url'], '/v1/admin/reported-tracks').status_code == 404
    d.save()
    print(json.dumps({'studio': NAME, 'base': s['base'], 'schema': s['schema'], 'runtime_files': len(SOURCES)}), flush=True)


def prepare():
    context = WORK/'context'
    context.mkdir(exist_ok=False)
    reviewed = {r['path']: r['after'] for r in json.loads((ROOT/'docs/evidence/reported-tracks-2026-11-04/sources.json').read_text())}
    for rel in SOURCES:
        assert hashlib.sha256((ROOT/rel).read_bytes()).hexdigest() == reviewed[rel], 'Reviewed source changed: '+rel
        target = context/rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT/rel, target)
    (context/'Dockerfile').write_text('''ARG BASE
FROM ${BASE}
USER root
COPY backend/bmt_backend/ /app/bmt_backend/
USER 10001:10001
''')
    tests = WORK/'tests'
    tests.mkdir(exist_ok=True)
    for name in ['conftest.py','test_studio_reported_tracks.py','test_studio_moderation.py','test_studio_catalogue.py',
                 'test_community_safety.py','test_published_track_routes.py','test_studio.py','test_auth_postgres.py',
                 'test_cloud_setup.py','test_domains.py','legacy_authoring_fixture.py']:
        shutil.copyfile(ROOT/'backend/tests'/name, tests/name)
    s['source_hashes'] = {rel: hashlib.sha256((context/rel).read_bytes()).hexdigest() for rel in SOURCES}
    s['source_hash'] = hashlib.sha256(json.dumps(s['source_hashes'], sort_keys=True).encode()).hexdigest()
    d.write(OUT/'sources.json', s['source_hashes'])
    d.save()
    print('Frozen ten reviewed Studio runtime files; other deployed content inherited', flush=True)


def sources_match():
    assert all(hashlib.sha256((ROOT/rel).read_bytes()).hexdigest() == value for rel, value in s['source_hashes'].items())


def build():
    sources_match()
    s['local'] = 'bmt-reported-tracks-20261104:'+s['source_hash'][:16]
    d.command(DOCKER+['build', '--network=none', '--pull=false', '--build-arg', 'BASE='+s['base'],
                      '-t', s['local'], d.unix(WORK/'context')], 'build', timeout=600)
    d.save()
    print('Built exact Studio patch image', flush=True)


def test():
    sources_match()
    network, pg = 'bmt-reported-tracks-release-20261104', 'bmt-reported-tracks-release-20261104-pg'
    label = 'bmt.task=reported-tracks-release-20261104'
    password = secrets.token_hex(24)
    pg_env, test_env = WORK/'pg.private.env', WORK/'test.private.env'
    pg_env.write_text('POSTGRES_PASSWORD='+password+'\nPOSTGRES_DB=bmt_reports\n')
    url = 'postgresql+psycopg://postgres:'+password+'@'+pg+'/bmt_reports'
    test_env.write_text('BMT_GCP_SETUP_TEST_DATABASE_URL='+url+'\nPYTHONPATH=/app:/test-work/backend/tests\n')
    d.command(DOCKER+['network', 'create', '--internal', '--label', label, network], 'test-network')
    try:
        d.command(DOCKER+['run', '-d', '--rm', '--name', pg, '--network', network, '--label', label,
            '--pull=never', '--env-file', d.unix(pg_env), '--tmpfs', '/var/lib/postgresql/data:rw', 'postgres:17-bookworm'], 'test-pg')
        for _ in range(40):
            p = subprocess.run(DOCKER+['exec', pg, 'pg_isready', '-U', 'postgres'], capture_output=True)
            if not p.returncode:
                break
            time.sleep(.25)
        else:
            raise RuntimeError('Owned PostgreSQL unavailable')
        output = d.command(DOCKER+['run', '--rm', '--network', network, '--env-file', d.unix(test_env),
            '--mount', 'type=bind,src='+d.unix(WORK/'tests')+',dst=/test-work/backend/tests,readonly',
            '--mount', 'type=bind,src='+d.unix(OUT)+',dst=/results', '--workdir', '/test-work/backend/tests',
            '--entrypoint', 'python', s['local'], '-m', 'pytest', 'test_studio_reported_tracks.py', 'test_studio_moderation.py',
            'test_studio_catalogue.py', 'test_community_safety.py', 'test_published_track_routes.py', '-q', '-k', '(not postgres) or restricted_admin',
            '--tb=short', '--show-capture=no', '-p', 'no:cacheprovider', '--junitxml=/results/exact-image.xml'], 'exact-tests', timeout=300)
        # Include the restricted-admin marker case using the explicit test URL;
        # ordinary parameterised PostgreSQL fixtures are outside this selection.
        (OUT/'exact-image.log').write_text(output, encoding='utf-8')
        print(output.splitlines()[-1], flush=True)
        s['tests_passed'] = True
        d.save()
    finally:
        value = json.loads(d.command(DOCKER+['inspect', pg], 'test-owner'))[0]
        assert value['Config']['Labels']['bmt.task'] == 'reported-tracks-release-20261104'
        d.command(DOCKER+['stop', pg], 'test-cleanup')
        value = json.loads(d.command(DOCKER+['network', 'inspect', network], 'network-owner'))[0]
        assert value['Labels']['bmt.task'] == 'reported-tracks-release-20261104'
        d.command(DOCKER+['network', 'rm', network], 'network-cleanup')
        pg_env.unlink(missing_ok=True)
        test_env.unlink(missing_ok=True)


def push():
    assert s.get('tests_passed')
    sources_match()
    auth = WORK/'docker-auth'
    auth.mkdir(exist_ok=False)
    try:
        token = service.call('auth', 'print-access-token')
        d.command(DOCKER+['--config', d.unix(auth), 'login', d.config['region']+'-docker.pkg.dev',
                          '--username=oauth2accesstoken', '--password-stdin'], 'docker-login', input_data=token)
        del token
        remote = s['base'].split('@')[0]+':reported-tracks-20261104-'+s['source_hash'][:16]
        d.command(DOCKER+['tag', s['local'], remote], 'image-tag')
        d.command(DOCKER+['--config', d.unix(auth), 'push', '--quiet', remote], 'image-push', timeout=600)
        value = json.loads(service.call('artifacts', 'docker', 'images', 'describe', remote, '--format=json'))
        s['image'] = remote.split(':')[0]+'@'+value['image_summary']['digest']
        d.save()
    finally:
        assert auth.resolve().parent == WORK.resolve() and not auth.is_symlink()
        shutil.rmtree(auth)
    print('Tested immutable Studio image pushed', flush=True)


def live_reads(label):
    module_source = base64.b64encode((WORK/'context/backend/bmt_backend/studio_reported_tracks.py').read_bytes()).decode()
    code = '''import base64,json,sys,types
from types import SimpleNamespace
from sqlalchemy import event,text
from sqlalchemy.orm import sessionmaker
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
e=make_engine(Settings.from_env().database_url)
@event.listens_for(e,'connect')
def readonly(dbapi,record):
 previous=dbapi.autocommit;dbapi.autocommit=True
 with dbapi.cursor() as c:c.execute('SET default_transaction_read_only=on')
 dbapi.autocommit=previous
m=types.ModuleType('bmt_backend.deployment_reported_tracks');m.__package__='bmt_backend';sys.modules[m.__name__]=m
exec(compile(base64.b64decode('''+repr(module_source)+'''),'<frozen Studio moderation>','exec'),m.__dict__)
r=SimpleNamespace(app=SimpleNamespace(state=SimpleNamespace(session_factory=sessionmaker(e))))
page=json.loads(m.reported_tracks(r,'analyst',q='',visibility='all',sort='reports',offset=0,limit=5).body)
details=0
for row in page['items']:
 data=json.loads(m.reported_track(__import__('uuid').UUID(row['track_id']),r,'analyst',offset=0,limit=5).body)
 assert data['track']['report_count']==row['report_count'];details+=1
with e.connect() as c:
 c.execute(text('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY'))
 names=['tracks','track_versions','runs','personal_bests','lap_personal_bests','studio_cases','studio_case_events','studio_quarantines']
 result={'schema':c.scalar(text('SELECT version_num FROM alembic_version')),'tables':{n:c.scalar(text('SELECT count(*) FROM "'+n+'"')) for n in names},'hidden_tracks':c.scalar(text('SELECT count(*) FROM tracks WHERE hidden')),'archived_tracks':c.scalar(text('SELECT count(*) FROM tracks WHERE archived')),'deletion_decisions':c.scalar(text("SELECT count(*) FROM admin_audit WHERE action='track_deletion'")),'readable_reported_track_sample':len(page['items']),'detail_checks':details,'transaction_read_only':c.scalar(text('SHOW transaction_read_only'))}
assert result['transaction_read_only']=='on'
print('RELEASE_RESULT='+json.dumps(result));e.dispose()
'''
    return d.execute(label, code, job=service.n['migrate'], timeout=180)


def rollout():
    assert s.get('tests_passed') and s.get('image')
    sources_match()
    d.HEAD = s['schema']
    original = d.guarded(NAME)
    assert original['metadata']['labels']['bmt-owner'] == d.config['owner']
    assert d.envmap(original)['BMT_WORKLOAD_ROLE']['value'] == 'admin'
    assert service.describe('api', NAME)['status']['traffic'] == s['traffic_before']
    lock = ROOT/'.tools/gcp-staging'/('rendered-'+d.config['owner'])/'update.lock'
    with lock.open('x') as stream:
        json.dump({'task': 'reported-tracks-20261104', 'source_hash': s['source_hash']}, stream)
    s['rollout_started'] = True
    d.save()
    s['data_before'] = live_reads('read-only-before')
    assert s['data_before']['schema'] == s['schema']
    d.save()
    service.call('run', 'services', 'update', NAME, REGION, '--image='+s['image'], '--no-traffic',
                 '--tag=reported-tracks-new', '--format=json')
    resource = service.describe('api', NAME)
    canary = next(r for r in resource['status']['traffic'] if r.get('tag') == 'reported-tracks-new')
    s['canary'] = {'revision': canary['revisionName'], 'url': canary['url']}
    d.save()
    d.verify_admin(canary['url'])
    assert d.http(canary['url'], '/v1/admin/reported-tracks', private=True).status_code in (401,403)
    for rel in SOURCES:
        if '/admin_ui/' in rel and not rel.endswith('index.html'):
            name = Path(rel).name
            result = d.http(canary['url'], '/admin/assets/'+name, private=True)
            assert result.status_code == 200 and result.content == (WORK/'context'/rel).read_bytes(), name
    page = d.http(canary['url'], '/admin', private=True)
    assert page.status_code == 200 and 'reported_tracks.js' in page.text
    service.call('run', 'services', 'update-traffic', NAME, REGION,
                 '--to-revisions='+canary['revisionName']+'=100', '--format=json')
    s['promoted'] = True
    d.save()
    print('Studio canary passed; new revision promoted', flush=True)


def verify():
    assert s.get('promoted')
    d.HEAD = s['schema']
    d.verify_admin(s['studio_url'])
    assert d.http(s['studio_url'], '/v1/admin/reported-tracks', private=True).status_code in (401,403)
    assert d.http(s['studio_url'], '/admin/assets/reported_tracks.js', private=True).content == (WORK/'context/backend/bmt_backend/admin_ui/reported_tracks.js').read_bytes()
    assert d.http(s['api_url'], '/v1/manifest').json() == s['manifest_before']
    assert d.http(s['api_url'], '/v1/admin/reported-tracks').status_code == 404
    api = service.describe('api', service.n['api'])
    assert {'image': d.staging.resource_image(api), 'traffic': api['status']['traffic']} == s['api_before']
    s['data_after'] = live_reads('read-only-after')
    before, after = s['data_before'], s['data_after']
    assert after['schema'] == before['schema']
    for field in ('hidden_tracks','archived_tracks','deletion_decisions'):
        assert after[field] == before[field], field
    assert all(after['tables'][name] >= count for name,count in before['tables'].items())
    d.guarded(NAME, [s['image']])
    service.call('run', 'services', 'update-traffic', NAME, REGION, '--remove-tags=reported-tracks-new', '--format=json')
    lock = ROOT/'.tools/gcp-staging'/('rendered-'+d.config['owner'])/'update.lock'
    assert json.loads(lock.read_text())['source_hash'] == s['source_hash']
    lock.unlink()
    s['completed'] = True
    d.save()
    receipt = {'studio': NAME, 'image': s['image'], 'base': s['base'], 'revision': s['canary']['revision'],
               'source_hash': s['source_hash'], 'before': before, 'after': after,
               'public_api_unchanged': True, 'competitive_manifest_unchanged': True, 'live_deletions': 0}
    d.write(OUT/'acceptance.json', receipt)
    d.write(ROOT/'.tools/gcp-staging'/('rendered-'+d.config['owner'])/'studio-reported-tracks.json', receipt)
    print('Live Studio verified; report reads pass; no live tracks deleted; public API and results retained', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('stage', choices=['inspect','prepare','build','test','push','rollout','verify'])
    globals()[parser.parse_args().stage]()
