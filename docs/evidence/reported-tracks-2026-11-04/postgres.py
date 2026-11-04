"""Task-owned PostgreSQL check using the existing backend image and patched files."""
import json
from pathlib import Path
import secrets
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
OUT = ROOT/'docs/evidence/reported-tracks-2026-11-04'
DOCKER = ['wsl.exe', '-d', 'Ubuntu', '--', 'docker']
NAME = 'bmt-reported-tracks-20261104'
LABEL = 'bmt.task=reported-tracks-20261104'


def unix(path):
    return '/mnt/'+path.drive[0].lower()+path.as_posix()[2:]


def call(*args, timeout=60):
    result = subprocess.run(DOCKER+list(args), capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError('Owned Docker command failed: '+result.stderr[:700])
    return result.stdout


def main():
    password = secrets.token_hex(24)
    pg_env, test_env = WORK/'pg.private.env', WORK/'test.private.env'
    pg_env.write_text('POSTGRES_PASSWORD='+password+'\nPOSTGRES_DB=bmt_reports\n')
    url = 'postgresql+psycopg://postgres:'+password+'@'+NAME+'-pg/bmt_reports'
    test_env.write_text('BMT_GCP_SETUP_TEST_DATABASE_URL='+url+'\nPYTHONPATH=/app:/test-work/backend/tests\n')
    call('network', 'create', '--internal', '--label', LABEL, NAME)
    try:
        call('run', '-d', '--rm', '--name', NAME+'-pg', '--network', NAME, '--label', LABEL,
             '--pull=never', '--env-file', unix(pg_env), '--tmpfs', '/var/lib/postgresql/data:rw',
             'postgres:17-bookworm')
        for _ in range(40):
            p = subprocess.run(DOCKER+['exec', NAME+'-pg', 'pg_isready', '-U', 'postgres'], capture_output=True)
            if not p.returncode:
                break
            time.sleep(.25)
        else:
            raise RuntimeError('Owned PostgreSQL not ready')
        args = ['run', '--rm', '--network', NAME, '--env-file', unix(test_env), '--workdir', '/test-work/backend/tests',
                '--mount', 'type=bind,src='+unix(ROOT/'backend/tests')+',dst=/test-work/backend/tests,readonly',
                '--mount', 'type=bind,src='+unix(OUT)+',dst=/results']
        for name in ['studio_reported_tracks.py', 'http_routes.py', 'admin.py', 'tracks.py', 'studio_cases.py', 'studio_catalogue.py']:
            args += ['--mount', 'type=bind,src='+unix(ROOT/'backend/bmt_backend'/name)+',dst=/app/bmt_backend/'+name+',readonly']
        args += ['--entrypoint', 'python', 'bmt-publication-20261103-main:219427a98e48114c', '-m', 'pytest',
                 'test_studio_reported_tracks.py', '-k', 'restricted_admin', '-q', '--tb=short', '--show-capture=no',
                 '-p', 'no:cacheprovider', '--junitxml=/results/postgres.xml']
        result = subprocess.run(DOCKER+args, capture_output=True, text=True, timeout=180)
        output = (result.stdout+result.stderr).replace(password, '[REDACTED]')
        (OUT/'postgres.log').write_text(output, encoding='utf-8')
        print(output[-4500:])
        assert result.returncode == 0
    finally:
        info = json.loads(call('inspect', NAME+'-pg'))[0]
        assert info['Config']['Labels']['bmt.task'] == 'reported-tracks-20261104'
        call('stop', NAME+'-pg')
        info = json.loads(call('network', 'inspect', NAME))[0]
        assert info['Labels']['bmt.task'] == 'reported-tracks-20261104'
        call('network', 'rm', NAME)
        pg_env.unlink(missing_ok=True)
        test_env.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
