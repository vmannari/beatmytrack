"""Assemble sanitized review receipts and a reversible documentation-only patch."""
from datetime import datetime, timezone
import difflib
import hashlib
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent


def xml_result(name):
    root = ET.parse(OUT / name).getroot()
    suites = root.findall('testsuite') if root.tag == 'testsuites' else [root]
    result = {key: sum(int(s.get(key, '0')) for s in suites)
              for key in ('tests', 'failures', 'errors', 'skipped')}
    result['passed'] = result['tests'] - result['failures'] - result['errors'] - result['skipped']
    result['seconds'] = round(sum(float(s.get('time', '0')) for s in suites), 3)
    result['failed_tests'] = []
    result['skipped_tests'] = []
    for case in root.iter('testcase'):
        identity = case.get('classname', '') + '::' + case.get('name', '')
        for kind in ('failure', 'error'):
            item = case.find(kind)
            if item is not None:
                result['failed_tests'].append({'test': identity, 'type': kind,
                                             'message': item.get('message', '')[:1200]})
        if case.find('skipped') is not None:
            result['skipped_tests'].append({'test': identity,
                'reason': case.find('skipped').get('message', '')[:400]})
    result['artifact'] = name
    return result


def main():
    manifests = json.loads((OUT / 'source-manifest.json').read_text())
    drift = []
    for item in manifests:
        p = ROOT / item['path']
        current = hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
        if current != item['sha256']:
            drift.append({'path': item['path'], 'inventory_sha256': item['sha256'],
                          'completion_sha256': current})
    additional = []
    for name in ('game/core/app.gd', 'game/core/build_identity.gd', 'game/editor/track_document.gd',
                 'game/editor/creator_limits.gd', 'game/editor/track_compiler.gd'):
        p = ROOT / name
        additional.append({'path': name, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()})
    (OUT / 'additional-source-manifest.json').write_text(json.dumps(additional, indent=2) + '\n')
    routes = json.loads((OUT / 'routes.json').read_text())
    scan = json.loads((OUT / 'credential-scan.json').read_text())
    native = []
    for name in ('test_session_rotation', 'test_backend_exception_recovery', 'test_backend_second_pass',
                 'test_account_privacy', 'test_communication_followup', 'test_medium_communication',
                 'test_draft_privacy'):
        p = OUT / (name + '.log')
        if not p.exists():
            p = OUT / (name + '-engine.log')
        value = p.read_text(encoding='utf-8', errors='replace')
        native.append({'test': name, 'artifact': p.name,
            'summaries': re.findall(r'[^\r\n]*\d+ checks[^\r\n]*', value),
            'failed_assertions': re.findall(r'^FAIL[^\r\n]*', value, re.M),
            'script_errors': len(re.findall('SCRIPT ERROR', value)),
            'status': 'timeout_after_fixture_error' if name == 'test_account_privacy' else
                'incomplete_deadline' if name == 'test_medium_communication' else
                'failed' if 'FAIL:' in value else 'passed'})
    files = ['test_auth.py', 'test_browser_auth.py', 'test_google_crypto.py', 'test_commerce.py',
        'test_provider_proofs.py', 'test_resumes.py', 'test_resume_recovery_wire.py', 'test_admin.py',
        'test_admin_support.py', 'test_admin_player_grants.py', 'test_store_admin.py', 'test_privacy.py',
        'test_attack_resistance.py', 'test_scalability_admission.py', 'test_communication_boundary.py',
        'test_community_safety.py', 'test_storage.py', 'test_s3_storage.py', 'test_gcs_storage.py',
        'test_appearance_sync.py', 'test_discovery_hardening.py', 'test_discovery_resources.py',
        'test_earned_coins.py', 'test_challenges.py', 'test_world_ranking.py', 'test_network_health.py',
        'test_product_analytics.py']
    command = ['.tools/backend-secure-venv/Scripts/python.exe', '-m', 'pytest']
    receipt = {'date': '2026-10-24', 'written_at_utc': datetime.now(timezone.utc).isoformat(),
        'requirements': ['SEC01', 'SEC02', 'SEC03', 'SEC04', 'SEC05', 'SEC06', 'SEC07', 'SEC08', 'R01', 'Q01'],
        'scope': 'Local security review; documentation and reproductions only; no remediation or rollout',
        'git_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'existing_uncommitted_work': True, 'source_files': len(manifests), 'route_declarations': len(routes),
        'source_changes_after_inventory': drift,
        'manual_admin_access_routes': ['/v1/admin/publications', '/v1/admin/publications/{publication_id}'],
        'findings': [
            {'id': 'SEC06', 'severity': 'high', 'kind': 'new local reproduction', 'title': 'Small unfinished bodies exhaust default API process'},
            {'id': 'SEC01', 'severity': 'high', 'kind': 'existing approved trust limitation', 'title': 'Paths do not prove physical race legality'},
            {'id': 'SEC02', 'severity': 'high for progression integrity', 'kind': 'existing trust limitation', 'title': 'Self-reported incidents authorize clean progression'},
            {'id': 'SEC07', 'severity': 'high conditional on legacy-key exposure', 'kind': 'known configuration hardening', 'title': 'Production legacy owner key bypasses named MFA path'},
            {'id': 'SEC03', 'severity': 'medium', 'kind': 'new HTTP reproduction', 'title': 'Both appearance writes accept unowned Coin cosmetics'},
            {'id': 'SEC04', 'severity': 'medium before rewarded-ad launch', 'kind': 'intentional bridge requiring production fence', 'title': 'Unconditional temporary ad-preview resumes'},
            {'id': 'SEC05', 'severity': 'medium hardening', 'kind': 'requires valid bearer possession', 'title': 'Deletion lacks fresh identity proof'},
            {'id': 'SEC08', 'severity': 'medium conditional on workload compromise', 'kind': 'configuration containment', 'title': 'Shared Compose secrets and schema ownership'},
        ],
        'validation': {'backend': xml_result('backend-security.xml'),
            'bespoke_finding_and_control_probes': xml_result('review-probes.xml'),
            'deployment_config': xml_result('deployment-config.xml'),
            'slow_body': json.loads((OUT / 'slow-body.json').read_text()),
            'native': native, 'pip_check': 'No broken requirements found',
            'postgres': 'Unavailable local port 55439; marker-only filtering failed to exclude parametrized cases; final selection excluded their IDs',
            'vault': {'registered': True, 'available': True, 'sealed_bytes': 0, 'roundtrip': False,
                      'artifact': 'vault-probe.log'}},
        'secret_scans': {'known_format': {'files': scan['files'], 'bytes': scan['bytes'],
                        'candidates': scan['candidates'], 'disposition': 'Both candidates are the same published AWS signing fixture'},
                        'literal_fields': json.loads((OUT / 'literal-token-scan.json').read_text())},
        'dependency_audit': {'packages': 46, 'status': 'pending explicit approval',
            'sandbox_attempt': 'ConnectionError', 'auto_review': 'Rejected package/version inventory export to public OSV as potentially sensitive',
            'complete_cve_scan': False},
        'commands': [
            {'prerequisite': '$env:PYTHONPATH=(Join-Path (Get-Location) "backend")',
             'argv': command + ['backend/tests/' + f for f in files] + ['-q', '-m', 'not postgres and not godot',
                '-k', 'not postgres', '--basetemp=build/security-review-20261024/pytest-sqlite',
                '--junitxml=docs/evidence/security-review-2026-10-24/backend-security.xml']},
            {'argv': command + ['docs/evidence/security-review-2026-10-24/test_review_probes.py', '-q',
                '--basetemp=build/security-review-20261024/probes-complete',
                '--junitxml=docs/evidence/security-review-2026-10-24/review-probes.xml']},
            {'argv': command + ['backend/tests/test_gcp_staging.py', 'backend/tests/test_gcp_update.py',
                'backend/tests/test_results_deployment.py', 'backend/tests/test_build_inputs.py', '-q',
                '--basetemp=build/security-review-20261024/deploy-tests',
                '--junitxml=docs/evidence/security-review-2026-10-24/deployment-config.xml']},
            *[{'argv': [command[0], 'docs/evidence/security-review-2026-10-24/' + f]}
              for f in ('inventory.py', 'token_scan.py', 'slow_body_probe.py', 'run_native.py', 'dependency_audit.py')],
            {'argv': [command[0], '-m', 'pip', 'check']},
        ],
        'initial_harness_limits': ['Missing PYTHONPATH on first pytest invocation',
            'Missing pytest base parent directory: 88 passed, 1 failed, 276 setup errors, 1 skipped, 12 deselected',
            'Marker-only filtering attempted unavailable local PostgreSQL; run interrupted; commerce diagnostic reproduced timeout',
            'Bespoke square originally included a sample after finishing and nesting example was within actual depth bound; corrected fixtures, no guard weakened',
            'Native runner initially mishandled TimeoutExpired text output; fixed for subsequent tests'],
        'not_performed': ['Live cloud/IAM/ingress inspection', 'Live exploitation or account mutation',
            'Phone/tablet attachment check', 'Physical-device tests', 'APK export/install/inspection',
            'Production provider purchases/ads', 'Deployment or migration', 'Complete Git-history/binary secret scan',
            'Complete dependency/container/native/Android vulnerability audit', 'Native/engine memory-safety fuzzing'],
        'review_artifacts': ['docs/SECURITY_REVIEW_2026_10_24.md',
                            'docs/evidence/security-review-2026-10-24/'],
        'remediation_implemented': False}
    (OUT / 'report.json').write_text(json.dumps(receipt, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    checkpoint = [ROOT / 'docs/SECURITY_REVIEW_2026_10_24.md',
                  *sorted(p for p in OUT.iterdir() if p.is_file() and p.name != 'task-only.patch')]
    patch = []
    for p in checkpoint:
        path = p.relative_to(ROOT).as_posix()
        raw = p.read_bytes()
        if raw.startswith((b'\xff\xfe', b'\xfe\xff')):
            # Windows PowerShell redirected native output as UTF-16. Preserve
            # its text as UTF-8 so the review checkpoint is a portable text patch.
            p.write_text(raw.decode('utf-16'), encoding='utf-8', newline='\n')
        content = p.read_text(encoding='utf-8').replace('\r\n', '\n')
        if not content.endswith('\n'):
            content += '\n'
        p.write_text(content, encoding='utf-8', newline='\n')
        body = content.splitlines(keepends=True)
        patch.append('diff --git a/' + path + ' b/' + path + '\n')
        patch.append('new file mode 100644\n')
        patch.extend(difflib.unified_diff([], body, fromfile='/dev/null', tofile='b/' + path))
    (OUT / 'task-only.patch').write_text(''.join(patch), encoding='utf-8', newline='\n')
    print(json.dumps({'backend': receipt['validation']['backend'],
        'bespoke': receipt['validation']['bespoke_finding_and_control_probes'],
        'deployment': receipt['validation']['deployment_config'], 'source_drift': drift}))


if __name__ == '__main__':
    main()
