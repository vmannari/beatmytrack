"""Start a bounded local pass using the cloud worker's exact canonical image."""
import argparse
import json
import os
import subprocess
import tempfile
import uuid
from pathlib import Path
from urllib.parse import urlparse

import requests

ROOT = Path(__file__).resolve().parents[2]


def unix(path):
    return '/mnt/' + path.drive[0].lower() + path.as_posix()[2:] if os.name == 'nt' else path.as_posix()


def run(args):
    config = json.loads((ROOT/'.tools/gcp-staging/config.json').read_text(encoding='utf-8-sig'))
    project, region = config['project'], config['region']
    base = 'bmt-stg-' + config['owner'][:8]
    env = os.environ.copy()
    ca = ROOT/'.tools/gcp-staging/windows-trust.pem'
    if ca.exists():
        env['CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE'] = str(ca)
    def gc(*arguments):
        result = subprocess.run([*config['gcloud'], '--project='+project, *arguments, '--quiet'],
            capture_output=True, text=True, encoding='utf-8', errors='replace', check=False, env=env, timeout=60)
        if result.returncode:
            raise RuntimeError('Google Cloud operator command failed; check the existing local sign-in')
        return result.stdout.strip()
    api = json.loads(gc('run','services','describe',base+'-api','--region='+region,'--format=json'))
    worker = json.loads(gc('run','worker-pools','describe',base+'-worker','--region='+region,'--format=json'))
    # The CLI uses the v1 describe format. Resolve only the owned workload's
    # existing identity/secret binding; no database credentials enter Docker.
    template = worker.get('spec',{}).get('template',{})
    spec = template.get('spec',template)
    image = spec['containers'][0]['image']
    origin = api.get('status',{}).get('url') or api.get('uri')
    api_template = api.get('spec',{}).get('template',{})
    api_spec = api_template.get('spec',api_template)
    parsed = urlparse(origin or '')
    if (parsed.scheme != 'https' or not parsed.hostname or not parsed.hostname.startswith(base+'-api-')
            or not parsed.hostname.endswith('.run.app') or parsed.username or parsed.password
            or not image.startswith(region+'-docker.pkg.dev/'+project+'/') or '@sha256:' not in image):
        raise RuntimeError('Expected the owned API and an immutable matching worker image')
    if args.inspect:
        print(json.dumps({'api':origin,'worker_image':image,'local_cpu_limit':args.cpus,'max_jobs':args.max_jobs,
            'target':str(args.rivalry or args.batch) if args.rivalry or args.batch else
                'list artificial rivalries' if args.list_rivalries else 'active queued batch','generation_started':False}))
        return
    binding = next((v for v in api_spec['containers'][0].get('env',[]) if v['name']=='BMT_DEV_AUTH_KEY'),None)
    if not binding:
        raise RuntimeError('The existing development operator binding is unavailable')
    if 'value' in binding:
        key = binding['value']
    else:
        reference = binding.get('valueFrom',{}).get('secretKeyRef',{})
        if not reference:
            raise RuntimeError('Unsupported development operator secret binding')
        key = gc('secrets','versions','access',reference.get('key','latest'),'--secret='+reference['name'])
    batch = str(args.batch) if args.batch else None
    rivalry = str(args.rivalry) if args.rivalry else None
    if args.list_rivalries:
        response = requests.get(origin+'/v1/dev/test-drivers/local-rivalries',headers={'X-Dev-Auth-Key':key},
            verify=str(ca) if ca.exists() else True,timeout=(5,20),allow_redirects=False)
        if response.status_code != 200:raise RuntimeError('Unable to list artificial rivalries')
        print(json.dumps(response.json(),indent=2));return
    if batch is None and rivalry is None:
        response = requests.get(origin+'/v1/dev/test-drivers/batches/active',headers={'X-Dev-Auth-Key':key},
            verify=str(ca) if ca.exists() else True,timeout=(5,20),allow_redirects=False)
        if response.status_code != 200:
            raise RuntimeError('Unable to inspect the active local-generation batch; deploy the matching API first')
        value = response.json().get('batch')
        if not value or value.get('complete'):
            print('No active unfinished batch. Create an explicit development batch before running local races.')
            return
        batch = str(uuid.UUID(value['batch_id']))
    local_root = ROOT/'.tools/artificial-races'
    folder = local_root/('rivalries' if rivalry else 'batches')/(rivalry or batch)
    folder.mkdir(parents=True,exist_ok=True)
    private = None
    try:
        available = subprocess.run([*config['docker'],'image','inspect',image],capture_output=True,check=False,timeout=30)
        if available.returncode:
            # Temporary registry credentials are scoped to this pull and never
            # change the owner's global Docker configuration.
            auth = Path(tempfile.mkdtemp(dir=local_root,prefix='registry-'))
            try:
                token = gc('auth','print-access-token')
                login = subprocess.run([*config['docker'],'--config',unix(auth),'login',region+'-docker.pkg.dev',
                    '--username=oauth2accesstoken','--password-stdin'],
                    input=token,capture_output=True,text=True,check=False,timeout=30)
                if login.returncode:
                    raise RuntimeError('Unable to authenticate the pinned worker image pull')
                pulled = subprocess.run([*config['docker'],'--config',unix(auth),'pull',image],capture_output=True,check=False,timeout=180)
                if pulled.returncode:
                    raise RuntimeError('Unable to pull the pinned worker image')
            finally:
                credential = auth/'config.json'
                if credential.exists():credential.unlink()
                auth.rmdir()
        if '\n' in key or '\r' in key:
            raise RuntimeError('Invalid development operator credential encoding')
        with tempfile.NamedTemporaryFile(dir=folder,prefix='operator-',suffix='.private.env',delete=False) as handle:
            private = Path(handle.name)
            handle.write(('BMT_DEV_AUTH_KEY='+key+'\n').encode())
        command = [*config['docker'],'run','--rm','--pull=never','--cpus='+str(args.cpus),'--memory=768m','--pids-limit=128',
            '--env-file',unix(private),'--mount','type=bind,src='+unix(local_root)+',dst=/local']
        if ca.exists():
            command += ['--mount','type=bind,src='+unix(ca)+',dst=/local-trust.pem,readonly',
                        '--env','REQUESTS_CA_BUNDLE=/local-trust.pem']
        command += ['--entrypoint','python',image,'-m','bmt_backend.local_artificial_races','--api',origin,
            '--rivalry' if rivalry else '--batch',rivalry or batch,'--state','/local/'+('rivalries/' if rivalry else 'batches/')+
            (rivalry or batch)+'/state.json','--cache-dir','/local/cache',
            '--max-jobs',str(args.max_jobs),
            '--godot','/usr/local/bin/godot','--project','/opt/bmt/game']
        result = subprocess.run(command,cwd=ROOT,check=False)
        if result.returncode:
            raise RuntimeError('Local pass stopped; its durable journal remains available for the same command')
    finally:
        if private is not None and private.exists():
            assert private.resolve().parent == folder.resolve()
            private.unlink()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    target=parser.add_mutually_exclusive_group()
    target.add_argument('--batch',type=uuid.UUID)
    target.add_argument('--rivalry',type=uuid.UUID)
    target.add_argument('--list-rivalries',action='store_true')
    parser.add_argument('--max-jobs',type=int,default=1)
    parser.add_argument('--cpus',type=float,default=1)
    parser.add_argument('--inspect',action='store_true',help='Inspect non-secret bindings without starting generation')
    args=parser.parse_args()
    if not 1<=args.max_jobs<=20 or not .5<=args.cpus<=8:
        parser.error('Use 1–20 attempts per pass and 0.5–8 local CPUs')
    run(args)


if __name__=='__main__':
    main()
