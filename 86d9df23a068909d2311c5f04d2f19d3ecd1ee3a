"""Remove only ephemeral resources owned by this release after successful checks."""
import json
import deploy as r

assert r.s.get('tests_passed') and r.s.get('backend_complete')
name = 'bmt-compat-20261107-pg'
labels = json.loads(r.d.command(r.DOCKER + ['inspect', name, '--format={{json .Config.Labels}}'], 'cleanup-pg-labels'))
assert labels.get('bmt.compat-release') == '20261107'
r.d.command(r.DOCKER + ['rm', '-f', name], 'cleanup-pg')
network = r.s['test_network']
labels = json.loads(r.d.command(r.DOCKER + ['network', 'inspect', network, '--format={{json .Labels}}'], 'cleanup-network-labels'))
assert labels.get('bmt.compat-release') == '20261107'
r.d.command(r.DOCKER + ['network', 'rm', network], 'cleanup-network')
auth = r.WORK / 'registry-auth.private'
assert auth.resolve().parent == r.WORK.resolve() and not auth.is_symlink()
for path in auth.iterdir():
    assert path.name == 'config.json' and path.is_file() and not path.is_symlink()
    path.unlink()
auth.rmdir()
r.s['ephemeral_resources_cleaned'] = True
r.d.save()
r.d.write(r.OUT / 'cleanup.json', {'owned_test_database_removed': True, 'owned_test_network_removed': True,
                                  'temporary_registry_credentials_removed': True, 'rollback_packages_retained': True})
print('Owned synthetic test resources and temporary registry credentials removed', flush=True)
