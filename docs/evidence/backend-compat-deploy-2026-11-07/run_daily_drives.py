"""Supply the existing operator binding privately to the exact local worker image."""
import json
import os
import subprocess
import deploy as r

assert r.s.get('promoted')
target = json.loads((r.OUT / 'daily-inspection-after.json').read_text())
assert target['include_artificial'] and not target['variant']
r.d.write(r.WORK / 'daily-target.json', target)
resource = r.service.describe('api', r.service.n['api'])
binding = next(row for row in r.d.runtime(resource)['containers'][0]['env'] if row['name'] == 'BMT_DEV_AUTH_KEY')
if 'value' in binding:
    key = binding['value']
else:
    ref = binding['valueFrom']['secretKeyRef']
    # Secret access output deliberately bypasses the command logger.
    value = subprocess.run([*r.d.config['gcloud'], '--project=' + r.d.config['project'], 'secrets', 'versions', 'access', ref.get('key', 'latest'), '--secret=' + ref['name'], '--quiet'], capture_output=True, text=True, timeout=60, check=True)
    key = value.stdout.strip()
assert '\n' not in key and '\r' not in key and key
env = r.WORK / 'daily-operator.private.env'
env.write_text('BMT_DEV_AUTH_KEY=' + key + '\nRELEASE_API=' + r.s['url'] + '\n')
try:
    command = r.DOCKER + ['run', '--rm', '--pull=never', '--cpus=2', '--memory=1g', '--pids-limit=128', '--label', r.LABEL,
        '--env-file', r.d.unix(env), '--mount', 'type=bind,src=' + r.d.unix(r.WORK) + ',dst=/release',
        '--mount', 'type=bind,src=' + r.d.unix(r.ROOT / '.tools/gcp-staging/windows-trust.pem') + ',dst=/release-trust.pem,readonly',
        '--env', 'REQUESTS_CA_BUNDLE=/release-trust.pem', '--entrypoint', 'python', r.s['image_main'], '/release/daily_drives.py']
    output = r.d.command(command, 'daily-local-drives', timeout=7200)
    print(output, flush=True)
finally:
    env.unlink(missing_ok=True)
