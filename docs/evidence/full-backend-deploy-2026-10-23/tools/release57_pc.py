"""Deploy the matching schema57 image to the existing PC backend and preserve its data."""
import argparse
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('pc18', ROOT / '.tools/full_backend_pc_20261018.py')
pc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pc)
pc.WORK = ROOT / 'build/full-backend-deploy-2026-10-23'
pc.OUTPUT = ROOT / 'docs/evidence/full-backend-deploy-2026-10-23'
pc.RECEIPT = pc.OUTPUT / 'pc-rollout.json'
pc.r = json.loads(pc.RECEIPT.read_text()) if pc.RECEIPT.exists() else {}


def compose(*args):
    return pc.run(['compose', '--env-file', '.tools/bmt-pc.env', '-f', 'backend/deploy/compose.pc.yaml',
                   '-f', 'build/full-backend-deploy-2026-10-23/pc.override.json', *args])


pc.compose = compose


def plan():
    path = pc.WORK / 'pc.override.json'
    override = json.loads(path.read_text())
    for role in ['api', 'worker']:
        before = json.loads((pc.WORK / ('bmt-pc-dev-' + role + '-1-before.private.json')).read_text())
        override['services'][role]['environment'] = {key: value for key, value in (entry.split('=',1) for entry in before['Config']['Env']) if key.startswith('BMT_')}
    override['services']['migrate']['environment'] = dict(override['services']['api']['environment'])
    path.write_text(json.dumps(override, indent=2) + '\n')
    value = json.loads(compose('config', '--format=json'))
    for role in ['api', 'worker']:
        before = json.loads((pc.WORK / ('bmt-pc-dev-' + role + '-1-before.private.json')).read_text())
        previous = dict(entry.split('=',1) for entry in before['Config']['Env'])
        proposed = value['services'][role]
        assert proposed['image'] == pc.r['image']
        assert all(str(v) == previous[key] for key,v in proposed['environment'].items() if key.startswith('BMT_'))
        objects = next(m for m in before['Mounts'] if m['Destination'] == '/var/lib/bmt/objects')
        volume = next(m for m in proposed['volumes'] if m['target'] == '/var/lib/bmt/objects')
        assert value['volumes'][volume['source']]['name'] == objects['Name'] == 'bmt-pc-dev_objects'
    result = {'settings_preserved': True, 'data_volume_preserved': True, 'same_candidate_image': True, 'roles': ['api', 'worker'], 'configuration_secrets_withheld': True}
    (pc.OUTPUT / 'pc-runtime-plan.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


def snapshot(name):
    before = pc.r.get('data_before')
    columns = {key: {'columns': value['columns'], 'pk': value['pk']} for key,value in before['tables'].items()} if before else None
    code = (ROOT / '.tools/release57_fingerprint.py').read_text(encoding='utf-8').replace('__COLUMNS__', repr(columns))
    result = json.loads(pc.program(code).decode().split('LATEST_RESULT=',1)[1])
    (pc.OUTPUT / ('pc-' + name + '.json')).write_text(json.dumps(result, indent=2) + '\n')
    if before:
        assert result['tables'] == before['tables'], [key for key in result['tables'] if result['tables'][key] != before['tables'][key]]
        pc.r['data_preserved'] = True
    else:
        assert not any(result['pending'].values()), result['pending']
        pc.r['data_before'] = result
    pc.save()
    print(json.dumps({'pc_snapshot': name, 'schema': result['schema'], 'original_rows_exact': before is not None,
                      'tables': len(result['tables']), 'rows': sum(row['rows'] for row in result['tables'].values())}))


pc.snapshot = snapshot


def catalog(apply=False):
    assert pc.r.get('migrated')
    spec = importlib.util.spec_from_file_location('release57cutover', ROOT / '.tools/release57_cutover.py')
    release = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(release)
    code = release.d.catalog_program(apply)
    code = code.replace('from bmt_backend.gcs_storage import GCSBlobStore', 'from bmt_backend.storage import LocalBlobStore').replace('store=GCSBlobStore(s)', 'store=LocalBlobStore(s.object_dir)')
    result = json.loads(pc.program(code, objects=True, readonly=True).decode().split('LATEST_RESULT=',1)[1])
    assert result['matching_new_revisions_required'] == 0 and result['inserted_versions'] == 0
    (pc.OUTPUT / ('pc-catalog-' + ('apply' if apply else 'preview') + '.json')).write_text(json.dumps(result, indent=2) + '\n')
    if apply:
        snapshot('data-after-catalog')
        pc.r.update(catalog_applied=True, catalog_preserved=True)
        pc.save()
    print(json.dumps(result))


def main():
    actions = {'prepare': pc.prepare, 'plan': plan, 'backup': pc.backup, 'snapshot': lambda: snapshot('data-before'),
               'migrate': pc.migrate, 'preview': catalog, 'catalog': lambda: catalog(True), 'promote': pc.promote, 'verify': pc.verify}
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('stage', choices=actions)
    actions[p.parse_args().stage]()


if __name__ == '__main__':
    main()
