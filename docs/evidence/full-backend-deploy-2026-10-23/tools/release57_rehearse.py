"""Restore the existing private PC backup into isolated PostgreSQL and rehearse 42->57."""
import hashlib
import importlib.util
import json
import secrets
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release57', ROOT / '.tools/full_backend_deploy_20261023.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
d = release.d
b = d.builder()
docker = b.c['docker']
suffix = secrets.token_hex(4)
network, pg = 'bmt-release57-restore-' + suffix, 'bmt-release57-restore-pg-' + suffix
label = 'bmt.release57-rehearsal=' + d.config['owner']
password = secrets.token_urlsafe(24)
backup = ROOT / 'build/full-backend-deploy-2026-10-18/pc-backup/database.dump'
expected = next(line.split()[0] for line in (backup.parent / 'SHA256SUMS').read_text().splitlines() if line.endswith('database.dump'))
assert hashlib.sha256(backup.read_bytes()).hexdigest() == expected


def program(code, *, image=None):
    return b.runner.run([*docker, 'run', '--rm', '-i', '--network=' + network, '--label=' + label,
                         '--entrypoint=python', '-e', 'BMT_DATABASE_URL=postgresql+psycopg://bmt:' + password + '@' + pg + ':5432/bmt',
                         image or d.r['local_tag'], '-'], input_data=code)


snapshot = '''import hashlib,json
from sqlalchemy import inspect,text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
e=make_engine(Settings.from_env().database_url)
with e.connect() as c:
 i=inspect(c);tables={};before=__BEFORE__
 names=list(before['tables']) if before else sorted(set(i.get_table_names())-{'alembic_version'})
 for name in names:
  columns=before['tables'][name]['columns'] if before else [v['name'] for v in i.get_columns(name)]
  rows=c.execute(text('SELECT '+','.join('"'+v+'"' for v in columns)+' FROM "'+name+'"'))
  values=sorted(json.dumps(list(row),sort_keys=True,separators=(',',':'),default=str) for row in rows)
  tables[name]={'columns':columns,'rows':len(values),'sha256':hashlib.sha256(('\\n'.join(values)).encode()).hexdigest()}
 result={'schema':c.scalar(text('SELECT version_num FROM alembic_version')),'tables':tables,'database_bytes':c.scalar(text('SELECT pg_database_size(current_database())')),
  'invalid_indexes':c.scalar(text('SELECT count(*) FROM pg_index WHERE NOT indisvalid'))}
 if before:assert tables==before['tables'],[name for name in tables if tables[name]!=before['tables'][name]]
 print(json.dumps(result))
e.dispose()
'''

created = False
b.runner.run([*docker, 'network', 'create', '--internal', '--label=' + label, network])
try:
    b.runner.run([*docker, 'run', '-d', '--rm', '--name=' + pg, '--network=' + network, '--label=' + label,
                  '-e', 'POSTGRES_USER=bmt', '-e', 'POSTGRES_DB=bmt', '-e', 'POSTGRES_PASSWORD=' + password, 'postgres:17'])
    created = True
    for _ in range(60):
        try:
            if 'accepting connections' in b.runner.run([*docker, 'exec', pg, 'pg_isready', '-U', 'bmt']):
                break
        except RuntimeError:
            pass
        time.sleep(.3)
    else:
        raise RuntimeError('Isolated rehearsal PostgreSQL unavailable')
    with backup.open('rb') as data:
        result = subprocess.run([*docker, 'exec', '-i', pg, 'pg_restore', '-U', 'bmt', '-d', 'bmt', '--no-owner', '--no-privileges', '--exit-on-error'],
                                stdin=data, capture_output=True, check=False)
    assert result.returncode == 0, result.stderr.decode(errors='replace')
    scaled = '--scaled' in sys.argv
    if scaled:
        targets = json.loads((d.OUTPUT / 'aggregate-preflight.json').read_text())['counts']
        seed = (ROOT / '.tools/release57_scale_seed.py').read_text().replace('__TARGETS__', repr(targets))
        print(program(seed))
    before = json.loads(program(snapshot.replace('__BEFORE__', 'None')))
    assert before['schema'] == '0042_achievements'
    started = time.monotonic()
    log = program('from bmt_backend.migrate import main\nmain()\n')
    elapsed = time.monotonic() - started
    after = json.loads(program(snapshot.replace('__BEFORE__', repr(before))))
    assert after['schema'] == release.HEAD and after['invalid_indexes'] == 0
    (d.WORK / 'rehearsal-before.private.json').write_text(json.dumps(before, indent=2) + '\n')
    (d.WORK / 'rehearsal-after.private.json').write_text(json.dumps(after, indent=2) + '\n')
    basename = 'migration-rehearsal-scaled' if scaled else 'migration-rehearsal'
    (d.OUTPUT / (basename + '.log')).write_text(log, encoding='utf-8')
    result = {'restored_existing_backup': True, 'backup_sha256': expected, 'schema_before': before['schema'], 'schema_after': after['schema'],
              'migration_seconds': elapsed, 'database_bytes_before': before['database_bytes'], 'database_bytes_after': after['database_bytes'],
              'original_tables_exact': len(before['tables']), 'original_rows_exact': sum(row['rows'] for row in before['tables'].values()),
              'invalid_indexes': after['invalid_indexes'], 'cloud_capacity_claim': False, 'backup_scope': 'existing PC development database',
              'synthetic_cloud_cardinalities': scaled}
    (d.OUTPUT / (basename + '.json')).write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
finally:
    if created:
        labels = json.loads(b.runner.run([*docker, 'inspect', pg, '--format={{json .Config.Labels}}']))
        assert labels.get('bmt.release57-rehearsal') == d.config['owner']
        b.runner.run([*docker, 'stop', pg])
    labels = json.loads(b.runner.run([*docker, 'network', 'inspect', network, '--format={{json .Labels}}']))
    assert labels.get('bmt.release57-rehearsal') == d.config['owner']
    b.runner.run([*docker, 'network', 'rm', network])
