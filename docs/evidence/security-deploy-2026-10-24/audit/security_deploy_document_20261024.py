"""Publish only aggregate deployment receipts, source and scoped documentation."""
import difflib
import hashlib
import json
import shutil
from datetime import datetime
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'build/security-deploy-2026-10-24'
OUT = ROOT / 'docs/evidence/security-deploy-2026-10-24'
s = json.loads((WORK / 'receipt.private.json').read_text(encoding='utf-8'))
assert s.get('cloud_finished') and s.get('legacy_identity_retired')

def read(name):
    return json.loads((OUT / name).read_text(encoding='utf-8'))

before, after = read('cloud-before.json'), read('cloud-after.json')
assert before['tables'] == after['tables']
rows = sum(v['rows'] for v in before['tables'].values())
seconds = round((datetime.fromisoformat(s['maintenance_ended']) - datetime.fromisoformat(s['maintenance_started'])).total_seconds(), 1)

def junit(name):
    suite = ET.parse(OUT / name).getroot()
    nodes = [suite] if suite.tag == 'testsuite' else list(suite)
    totals = {k: sum(int(n.get(k, 0)) for n in nodes) for k in ('tests', 'failures', 'errors', 'skipped')}
    totals['passed'] = totals['tests'] - totals['failures'] - totals['errors'] - totals['skipped']
    return totals

stages = ['inspect', 'freeze', 'build', 'preflight', 'test', 'plan', 'provision',
          'push', 'maintenance', 'runtime-files', 'operator-access', 'transport-check',
          'synthetic-rehearse', 'quiesce', 'stop-worker', 'cutover-data',
          'test-secret-access', 'canary', 'promote', 'smoke', 'authority', 'discovery', 'retire', 'finish']
report = {
    'requirements': ['SEC06', 'SEC07', 'SEC03', 'SEC08', 'SEC04', 'R01', 'Q01'],
    'status': 'cloud_deployed_pc_backup_approval_pending',
    'finished_at': s['finished_at'], 'project': 'beat-my-track', 'region': 'europe-west1',
    'api_url': s['url'], 'api_revision': s['canary_revision'], 'worker_revision': s['worker_revision'],
    'image': s['image'], 'source_hash': s['source_hash'], 'parent_image': s['parent'],
    'schema_before': before['schema'], 'schema_after': after['schema'],
    'managed_cloud_sql_backup_id': s['backup_id'],
    'data_preservation': {'original_tables_exact': len(before['tables']), 'original_rows_exact': rows,
                          'invalid_indexes': after['invalid_indexes'],
                          'excluded_disposable_tables': ['discovery_budget', 'discovery_snapshots'],
                          'excluded_schema_marker': 'alembic_version',
                          'cosmetic_comparison': 'Existing grants at original cutoff; new server-stored grandfather grants are permitted'},
    'maintenance': {'started': s['maintenance_started'], 'ended': s['maintenance_ended'], 'seconds': seconds},
    'tests': {'authority': junit('authority-tests.xml'), 'exact_image': junit('exact-image-tests.xml'),
              'exact_image_deselected': 12, 'synthetic_rehearsal': read('synthetic-migration-rehearsal.json')},
    'native_contract': read('candidate-manifest.json'), 'native_storage_smoke': read('native-storage-smoke.json'),
    'worker_readiness': read('worker-readiness.json'), 'live_authority': read('live-authority.json'),
    'discovery': read('discovery-http.json'), 'final_http': read('final-http.json'),
    'targets': read('final-targets.json'), 'pc': read('pc-unchanged.json'),
    'studio': {'public_routes_status': 404, 'separate_staff_service_enabled': False,
               'reason': 'No named staff audiences/subjects or verified MFA provider configured'},
    'retired': {'legacy_database_login': 'bmt NOLOGIN', 'legacy_service_account_disabled': True,
                'legacy_secret_version_disabled': True, 'legacy_bucket_and_cloudsql_client_access_removed': True},
    'pc_approval': {'required': True, 'automatic_review_rejected': True,
                    'action': 'Export PC database and objects into a private workspace backup before PC update',
                    'reason': 'Deploy did not specifically authorize sensitive player/identity/token-hash data copy and destination',
                    'requested_destination': str(WORK / 'pc-backup'), 'backup_executed': False, 'pc_update_executed': False},
    'limits': ['Retained development staging; existing development/test-driver policy remains explicit',
               'No real staff/provider/MFA acceptance; Studio remains disabled',
               'No client process restart, device attachment check, physical device test or APK/export/install',
               'No fixed-cost reporting replica, private Studio service or population job started',
               'No production capacity, distributed denial-of-service or restore-drill certification',
               'Frozen schema62 release excludes later concurrent schema63 and client work',
               'Do not restore old insecure writers after the cosmetic ownership cutover'],
    'corrections': ['Transient disposable PostgreSQL readiness retry corrected',
                    'Receipt merge prevents unrelated concurrent preparation keys being lost',
                    'gcloud flags-file keys corrected to leading -- before successful execution',
                    'Protected staging guard snapshot moved from restricted application role to existing migration identity',
                    'Inline Windows diagnostic quoting corrected before execution',
                    'Initial canary startup denied retained test-driver secret; exact-secret IAM binding added to new identities'],
    'executed_stages': stages,
}
audit = OUT / 'audit'
audit.mkdir(exist_ok=True)
for name in ('security_deploy_20261024.py', 'security_deploy_fingerprint_20261024.py',
             'security_deploy_synthetic_20261024.py', 'security_deploy_document_20261024.py'):
    shutil.copyfile(ROOT / '.tools' / name, audit / name)
for path in ('backend/bmt_backend/workloads.py', 'backend/tests/test_security_fixes.py'):
    target = audit / path
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(WORK / 'frozen' / path, target)

report['artifact_sha256'] = {p.relative_to(OUT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                             for p in OUT.rglob('*') if p.is_file() and p.name not in ('report.json', 'task-only.patch')}
(OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')

patches = []
def edit(path, new):
    target = ROOT / path
    old = target.read_text(encoding='utf-8') if target.exists() else ''
    backup = WORK / 'docs-before' / path
    if not backup.exists():
        backup.parent.mkdir(parents=True, exist_ok=True)
        backup.write_text(old, encoding='utf-8')
    else:
        old = backup.read_text(encoding='utf-8')
    target.write_text(new, encoding='utf-8')
    patches.extend(difflib.unified_diff(old.splitlines(keepends=True), new.splitlines(keepends=True),
                                      fromfile='a/' + path, tofile='b/' + path))

doc = f'''# Security deployment — 2026-10-24

The retained Google Cloud staging API, one worker and all five existing owned job definitions now use the SEC06/SEC07/SEC03/SEC08/SEC04 release at schema `0062_retire_discovery_cache`. API revision **{s['canary_revision']}**, worker **{s['worker_revision']}**. The existing [API]({s['url']}) is healthy and receives 100% of traffic. Private Studio remains disabled because named staff identities and a verified MFA provider have not been configured. The PC backend and running clients remain unchanged.

The immutable image is `{s['image']}`. Frozen source SHA256 is `{s['source_hash']}`. Godot4.7.2 / compiler27 / physics0.66 / rules23 / five laps remain exact. The snapshot includes migrations0058–0062 and the tested concurrent ranking/configuration/cache-retirement changes; later concurrent schema0063/client changes are outside this artifact.

## Authority and preservation

The API and worker now have separate service accounts, database credentials and scoped secret grants. Runtime database users are nonowners. The migrator alone receives the schema-owner credential; diagnostic/operator jobs use the restricted API database credential. The former shared SQL login is `NOLOGIN`, its old service identity and secret version are disabled, and its storage/Cloud SQL access is removed. Current definitions contain no legacy administrator keys, staff subject lists or monitor credentials. Existing development/test-driver policy is retained explicitly; this is development staging, not a production-mode certification.

Public Studio/admin/monitor paths return404 before database work. Legacy Studio opt-in and temporary ad-preview resumes are explicitly false. The deployment also corrects the development API boundary: administrative routers require an explicit legacy opt-in outside production. Appearance ownership enforcement and the server-stored grandfathering migration are active. Old insecure appearance writers must not be redeployed.

Maintenance ran from **{s['maintenance_started']}** to **{s['maintenance_ended']}**, about **{seconds / 60:.1f} minutes**. A database-free maintenance revision paused all application routes. Old requests drained, the worker stopped, and accepted race/publication/validation queues were empty. Managed Cloud SQL backup **{s['backup_id']}** succeeded without exporting player records. After57→62, all **{rows:,} original rows across{len(before['tables'])} compared tables** match their pre-migration fingerprints; no invalid indexes remain. The schema marker and two deliberately retired disposable discovery tables are excluded. Existing cosmetic grants are compared at the original cutoff; legitimate migration grants are additions. Comparisons precede ordinary worker projections/retention.

## Verification

- Working-source authority selection: **70 passed**. Exact frozen image with disposable PostgreSQL17: **258 passed,1 skipped,12 deselected**. These are focused gates, not a full-suite claim.
- Synthetic-only57→62 rehearsal: **131 tables /103,328 original rows exact**, no real player records copied. Measured1.557s is a local rehearsal, not cloud latency/capacity evidence.
- Actual live native replay/schema/GCS smoke: **passed**,12,757 canonical ticks, two temporary diagnostic objects, zero player writes.
- One matching live worker, empty queue and all **16 discovery partitions ready** before public traffic reopened. Public discovery traverses **{report['discovery']['public_tracks']} tracks**, with no duplicate IDs.
- Live production-strength API role validation passes even though staging runs development mode. Worker cannot read session tokens/staff or rewrite/delete administrative audit records; API cannot read staff; Studio role cannot read session tokens. Preview resumes/legacy Studio keys are false.
- All seven target images match, existing resource/process settings and worker count are preserved, temporary traffic tags are removed and the owned deployment lock is released. PC container images/configuration/start times remain exact.

Initial failures and corrections are retained in [the machine-readable report](evidence/security-deploy-2026-10-24/report.json): disposable PostgreSQL startup retry, receipt merge, gcloud flags-file spelling, a correctly denied application-role read of the protected staging guard, shell quoting and the initial missing exact-secret grant for retained staging test drivers. None required weakening the runtime database grants or exposing Studio.

## PC approval and remaining acceptance

Automatic approval review rejected the proposed PC database backup copy before execution because the sensitive player records, identities/token hashes and destination were not specifically authorized by “deploy.” The pending request names `{WORK / 'pc-backup'}`. No PC backup was copied, no alternative real-data rehearsal bypassed that rejection, and PC containers/data were not changed. Explicit backup approval is required before the PC rollout can continue.

Client restart/install and owner/device acceptance remain. No phone/tablet attachment check, physical-device test, APK/export/install, real provider sign-in, purchase, population execution or reporting replica was performed. Studio activation needs named staff/provider/MFA acceptance; broad reporting retains its separate replica/cost gate. Load/edge calibration and restore exercises remain operational acceptance. Concurrent work and owner processes are preserved; no mixed-tree commit is created.

Operational scripts are private ignored `.tools/`; code-only audit copies, exact image/package hashes, logs and aggregate receipts are in [the evidence folder](evidence/security-deploy-2026-10-24/). Credentials, environment files and raw resource metadata remain in ignored private build storage. Actual entry point:

```text
.tools/backend-secure-venv/Scripts/python.exe -X utf8 .tools/security_deploy_20261024.py <stage>
```

Executed stages: `{', '.join(stages)}`. The proposed real-PC `rehearse` command was rejected before execution; `synthetic-rehearse` uses invented data and aggregate cardinalities only. The dated [source-fix report](SECURITY_FIXES_2026_10_24.md) describes the implementation and prior tests; [the23October release](LATEST_BACKEND_DEPLOY_2026_10_23.md) remains the PC deployment receipt.
'''
edit('docs/SECURITY_DEPLOYMENT_2026_10_24.md', doc)

summary = (f'2026-10-24 SEC-D01/SEC06/SEC07/SEC03/SEC08/SEC04/R01/Q01: Authorized retained cloud rollout reaches schema62 on API99/worker40 and all five matching job definitions. Separate runtime identities/credentials and explicit grants are active; old shared SQL login, service account and secret are disabled. Studio/admin/monitor return404 and ad previews are off. Managed backup{s["backup_id"]}; all{rows} original rows/{len(before["tables"])} compared tables exact, invalid indexes0. Focused70/exact-image258pass1skip12deselected, synthetic131tables/103328rows, live native/schema/GCS smoke with zero player writes, worker16partitions and discovery{report["discovery"]["public_tracks"]} pass. Existing development test-driver policy/resources remain; later concurrent schema63 is outside the frozen artifact. Actual commands, corrections, hashes and scoped checkpoint: docs/SECURITY_DEPLOYMENT_2026_10_24.md and docs/evidence/security-deploy-2026-10-24/report.json. PC backup copy was rejected by automatic review pending explicit sensitive-data/destination approval; PC remains unchanged. Studio staff/MFA, client/owner/device/restore/load acceptance remain; no device check/test/APK, population job, reporting replica or client restart. Concurrent work/owner processes preserved.')
for path, prefix in [('AGENTS.md', '## Security cloud deployment override (2026-10-24)\n'), ('DEVELOPMENT_STATUS.md', '')]:
    edit(path, prefix + summary + '\n\n' + (ROOT / path).read_text(encoding='utf-8'))

path = 'docs/README.md'
text = (ROOT / path).read_text(encoding='utf-8')
text = text.replace('[latest recorded release](LATEST_BACKEND_DEPLOY_2026_10_23.md)', '[latest cloud release](SECURITY_DEPLOYMENT_2026_10_24.md), [PC release](LATEST_BACKEND_DEPLOY_2026_10_23.md)')
start = text.index('The latest recorded backend deployment is schema **0057**.')
end = text.index('\n\n', start)
text = text[:start] + ('The [latest cloud security deployment](SECURITY_DEPLOYMENT_2026_10_24.md) is schema **0062**, with separate runtime credentials and Studio disabled. The PC backend remains at schema **0057** pending explicit private-backup approval. Later workspace migrations do not prove rollout. Consult feature reports and release receipts before selecting matching artifacts; World Ranking launch, production billing, private staff access and broad reporting retain their configuration gates.') + text[end:]
edit(path, text)
path = 'docs/SECURITY_FIXES_2026_10_24.md'
text = (ROOT / path).read_text(encoding='utf-8')
text = text.replace('**These changes have not been deployed.**', '**The later [24October cloud deployment](SECURITY_DEPLOYMENT_2026_10_24.md) activates the backend fixes; PC/client rollout remains pending.** This report records the implementation checkpoint before that deployment.')
edit(path, text)
path = 'backend/deploy/README.md'
text = (ROOT / path).read_text(encoding='utf-8')
edit(path, '2026-10-24 cloud rollout: schema0062 and separate API/worker identities are active; public Studio is disabled. PC remains unchanged pending private backup approval. See [actual security deployment, validation and remaining acceptance](../../docs/SECURITY_DEPLOYMENT_2026_10_24.md).\n\n' + text)
(OUT / 'task-only.patch').write_text(''.join(patches), encoding='utf-8')
print(json.dumps({'report_written': True, 'original_rows_exact': rows, 'cloud_finished': True,
                  'pc_backup_approval_pending': True, 'documentation_patch_files': 6}))
