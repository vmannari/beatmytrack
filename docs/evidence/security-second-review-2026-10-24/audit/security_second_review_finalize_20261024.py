"""Create a scoped review report; never modify runtime code or deployment."""
import difflib
import hashlib
import json
from pathlib import Path
import shutil
from datetime import datetime, timezone
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/security-second-review-2026-10-24'
WORK=ROOT/'build/security-second-review-2026-10-24'
def read(name):return json.loads((OUT/name).read_text(encoding='utf-8'))
def junit(name):
    root=ET.parse(OUT/name).getroot()
    suites=[root] if root.tag=='testsuite' else list(root)
    result={key:sum(int(v.get(key,0)) for v in suites) for key in ('tests','failures','errors','skipped')}
    result['passed']=result['tests']-result['failures']-result['errors']-result['skipped']
    return result

manifest=read('source-manifest.json')
drift=[v['path'] for v in manifest if not (ROOT/v['path']).exists() or hashlib.sha256((ROOT/v['path']).read_bytes()).hexdigest()!=v['sha256']]
final_sources={v['path']:hashlib.sha256((ROOT/v['path']).read_bytes()).hexdigest() for v in manifest if (ROOT/v['path']).is_file()}
(OUT/'completion-source-hashes.json').write_text(json.dumps(final_sources,indent=2)+'\n',encoding='utf-8')
supplement=['backend/tests/test_security_fixes.py','backend/tests/test_discovery_daily.py','backend/tests/test_cost_transport.py',
            'game/core/app.gd','game/ui/draft_browser.gd','game/tests/test_draft_privacy.gd','game/tests/test_backend_exception_recovery.gd',
            'game/tests/test_cost_downloads.gd','game/track/desert_wind_envelope.gd']
(OUT/'supplemental-source-hashes.json').write_text(json.dumps({v:hashlib.sha256((ROOT/v).read_bytes()).hexdigest() for v in supplement if (ROOT/v).exists()},indent=2)+'\n',encoding='utf-8')
cloud=read('cloud-read-only.json')
scan=read('credential-scan.json')
report={
 'requirements':['SEC-R2','SEC09','SEC10','SEC01','SEC02','SEC05','R01','Q01'],
 'completed_at':datetime.now(timezone.utc).isoformat(),
 'scope':'Second working-tree security pass, frozen deployed-release comparison and read-only cloud inspection',
 'new_findings':[
  {'id':'SEC09','severity':'medium','title':'Incomplete HTTP headers bypass application receive deadlines and exhaust the default server connection allowance',
   'sources':['backend/Dockerfile:41','backend/deploy/compose.yaml:95','backend/bmt_backend/middleware.py:518'],
   'precondition':'A network path can hold incomplete HTTP headers at Uvicorn; cloud edge exploitability was not tested',
   'evidence':read('incomplete-headers.json')},
  {'id':'SEC10','severity':'medium','title':'Production startup accepts unexpected schema CREATE and staff UPDATE grants',
   'sources':['backend/bmt_backend/database_privileges.py:196','backend/bmt_backend/database_privileges.py:220'],
   'precondition':'Privileged grant/configuration drift; not an unauthenticated way to grant database permissions',
   'evidence':read('postgres-drift.json')}],
 'retained_findings':{'SEC01':'Approved lightweight trajectory trust limitation confirmed with current 879-tick synthetic proof',
                      'SEC02':'Caller-controlled incident claim still changes the clean result',
                      'SEC05':'Normal valid bearer still initiates permanent deletion without fresh identity proof'},
 'fixed_findings_rechecked':['SEC03','SEC04','SEC06 application body phase','SEC07','SEC08 configured grants and cloud credential separation'],
 'backend':junit('backend-tests.xml'),'backend_deselected':54,'daily_current_fixture_recheck':junit('daily-recheck.xml'),
 'retained_risk_probes':junit('retained-risks.xml'),'native':read('native-results.json'),
 'draft_wait_fixture':read('test_draft_privacy_after_scan-results.json'),
 'cloud':cloud,'cloud_iam':read('cloud-iam.json'),
 'inventory':{'source_files':len(manifest),'public_route_declarations':len(read('routes.json')),
              'changed_since_manifest':drift,'secret_scan':scan},
 'dependencies':{'pip_check':'No broken requirements found',
  'advisories_checked':[
   {'url':'https://github.com/Kludex/starlette/security/advisories/GHSA-86qp-5c8j-p5mr','patched':'1.0.1','locked':'1.7.0','affected':False},
   {'url':'https://github.com/Kludex/starlette/security/advisories/GHSA-82w8-qh3p-5jfq','patched':'1.3.1','locked':'1.7.0','affected':False}],
  'complete_cve_scan':False,'prior_inventory_export_rejection_not_retried':True},
 'limitations':['Review only; no runtime remediation, deployment or live player mutation',
  'Incomplete-header reproduction was loopback only, not a cloud denial-of-service test',
  'Grant drift reproduction used disposable PostgreSQL17 schema62 plus the current grant checker; no retained database used',
  'Broader current schema66 PostgreSQL concurrency/migration/pack/archive acceptance remains separate',
  'Working tree is concurrent; inventory is not a frozen client release',
  'Native exception-recovery fixture retains removed-transport expectations and times out after its missing-schema exception',
  'Original draft test has three early assertions; separate wait fixture passes20 owner checks with3 unrelated Desert script diagnostics',
  'No real provider/MFA/purchase/ad workflow, APK inspection/install, device attachment check or physical-device test',
  'No complete dependency/container OS/native memory-safety audit or sustained distributed-abuse certification',
  'Cloud staging deliberately retains development/test-driver mode; private Studio disabled; PC remains at prior release'],
 'harness_corrections':['Initial fictional StudioStaff INSERT used a nonexistent created_at column; fixture corrected, disposable container removed in both runs',
  'One native-runner generation command had shell quoting syntax failure before execution; replaced by a script file',
  'Initial broad daily rollback fixture failed; current independently changed fixture includes projection readiness and passes its focused recheck'],
 'commands':[
  '.tools/backend-secure-venv/Scripts/python.exe -X utf8 .tools/security_second_review_probe_20261024.py',
  '.tools/backend-secure-venv/Scripts/python.exe -X utf8 .tools/security_second_review_cloud_20261024.py',
  '.tools/backend-secure-venv/Scripts/python.exe -X utf8 .tools/security_second_review_pg_20261024.py',
  'PYTHONPATH=backend python -m pytest backend/tests/{test_security_fixes,test_auth,test_browser_auth,test_appearance_sync,test_rivalry_appearance,test_resumes,test_privacy,test_cost_transport,test_packed_storage,test_cost_archives,test_cost_http,test_custom_challenge_tracks,test_discovery_daily}.py -m "not godot" -k "not postgres and not canonical_three_rewinds and not additive_attempt_migration" -q --tb=short --basetemp=build/security-second-review-2026-10-24/pytest -p no:cacheprovider --junitxml=docs/evidence/security-second-review-2026-10-24/backend-tests.xml',
  '.tools/backend-secure-venv/Scripts/python.exe -X utf8 .tools/security_second_review_native_20261024.py',
  '.tools/backend-secure-venv/Scripts/python.exe -X utf8 .tools/security_second_review_draft_fixture_20261024.py',
  '.tools/backend-secure-venv/Scripts/python.exe -X utf8 .tools/security_second_review_native_20261024.py test_draft_privacy_after_scan',
  '.tools/backend-secure-venv/Scripts/python.exe -X utf8 .tools/security_second_review_inventory_20261024.py',
  '.tools/backend-secure-venv/Scripts/python.exe -X utf8 -m pip check',
  'PYTHONPATH=backend python -m pytest docs/evidence/security-second-review-2026-10-24/test_retained_risks.py -q --tb=short --basetemp=build/security-second-review-2026-10-24/retained-risks -p no:cacheprovider --junitxml=docs/evidence/security-second-review-2026-10-24/retained-risks.xml',
  'PYTHONPATH=backend python -m pytest backend/tests/test_discovery_daily.py -k "rollback and sqlite" -q --tb=short --basetemp=build/security-second-review-2026-10-24/daily-recheck -p no:cacheprovider --junitxml=docs/evidence/security-second-review-2026-10-24/daily-recheck.xml',
  '.tools/backend-secure-venv/Scripts/python.exe -X utf8 .tools/security_second_review_iam_20261024.py']}

audit=OUT/'audit';audit.mkdir(exist_ok=True)
for p in (ROOT/'.tools').glob('security_second_review_*_20261024.py'):
 shutil.copyfile(p,audit/p.name)
for path in ('backend/bmt_backend/database_privileges.py','backend/bmt_backend/middleware.py','backend/bmt_backend/workloads.py','backend/deploy/compose.yaml','backend/Dockerfile'):
 target=audit/path;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/path,target)
report['artifact_sha256']={p.relative_to(OUT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.rglob('*') if p.is_file() and p.name not in ('report.json','task-only.patch')}
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')

doc='''# Second game security review — 24 October 2026

The deployed fixes substantially improve the game’s security boundary. This pass confirms **two additional medium-severity gaps**, both with bounded local reproductions. The previously recorded competitive-proof, clean-race and deletion-reauthentication risks remain. No new frontend account-isolation exploit, public Studio access or exposed cloud bucket was confirmed.

This is a review, not a remediation or rollout. It covers the current client/backend working tree and a read-only inspection of the separately frozen cloud release. No live race/account/administrative mutation, cloud attack, database export, deployment or client-process control was performed. Device attachment was not checked; no physical-device test, APK export/install, real sign-in, ad or purchase occurred.

## Findings

| ID | Severity | Result and prerequisite |
|---|---|---|
| SEC09 | Medium | Incomplete request headers can exhaust the default Uvicorn connection allowance before application deadlines begin. Requires a network path that forwards/retains these incomplete headers at that server. |
| SEC10 | Medium | The production database startup checker accepts some unexpected grants, including schema CREATE and staff UPDATE. Requires privileged grant/configuration drift; the normal grant setup does not grant these rights. |
| SEC01 | High, retained policy risk | Current geometric trajectory acceptance still accepts a fabricated, nonphysical synthetic five-lap path. The owner-approved lightweight verification tradeoff remains in force. |
| SEC02 | High for progression integrity, retained | Changing the client’s incident report still changes a result to clean without independently proving collision/off-track behavior. |
| SEC05 | Medium, retained | A normal usable bearer still initiates permanent account deletion without a fresh identity challenge. |

### SEC09: requests can consume connections before the body guard runs

The [container command](../backend/Dockerfile#L41) and [production Compose API](../backend/deploy/compose.yaml#L95) use `--limit-concurrency 24 --timeout-keep-alive 5`. The [new receive deadline](../backend/bmt_backend/middleware.py#L518) starts after the server has parsed a complete request head and dispatched to ASGI. It therefore cannot expire a connection that never finishes its HTTP headers.

Against a newly started loopback-only current API,23 sockets each send a partial request head. Health returns503/503/503 immediately and again after6.2 seconds; ordinary authentication also returns503. Closing those sockets restores health200. Baseline health is200. The attack never needs a valid account or a request body. [Exact reproduction](evidence/security-second-review-2026-10-24/incomplete-headers.json).

This is a remaining availability path alongside the repaired small-body receiver issue. The five-second keep-alive setting does not provide a deadline for receiving the first request head. Uvicorn documents [keep-alive between requests and concurrency counting open connections](https://raw.githubusercontent.com/Kludex/uvicorn/main/docs/server-behavior.md). The local result does **not** demonstrate that Google’s public frontend forwards this attack. The repository’s API listener is loopback-bound in production Compose and the NAS proxy is separately configured; that limits exposure and makes proxy acceptance decisive.

Use a server/proxy header-completion deadline and connection admission limits before ASGI, keep Uvicorn reachable only through that protected path, and verify both the real edge and any direct-service bypass. Do not remove the existing application receive caps. Raising the connection count alone increases the attack budget without resolving the missing deadline.

### SEC10: startup checks only part of the effective privilege policy

The [production checker](../backend/bmt_backend/database_privileges.py#L196) rejects elevated/owning/inheriting users, some forbidden table reads, audit UPDATE/DELETE, and a mismatched workload. Its [forbidden-grant list](../backend/bmt_backend/database_privileges.py#L220) does not reject schema CREATE or every protected-table write privilege.

A separate, disposable PostgreSQL17 database is migrated to the deployed schema62. The current provisioning/grant code establishes the intended restricted worker, which passes startup. After an administrative fixture grants schema CREATE, startup still passes and the worker creates a table. After resetting the baseline and granting only `UPDATE(enabled)` on `studio_staff`, startup again passes and the worker re-enables a fictional revoked staff row without SELECT access. [Exact results](evidence/security-second-review-2026-10-24/postgres-drift.json).

The normal `configure()` grants are correct for these two operations: it revokes schema CREATE and does not grant worker staff writes. An external player cannot use this check to issue GRANT. The weakness is that a deployment/grant mistake survives a guard described as rejecting excessive runtime authority. Staff revocation integrity can then fail if that worker is compromised. No such live database grant was introduced or demonstrated.

Derive startup validation from the complete reviewed effective grant policy, including schema CREATE, protected-table/column writes and non-CRUD privileges, function execution and workload-specific exceptions. PostgreSQL exposes [effective schema, table and column privilege checks](https://www.postgresql.org/docs/17/functions-info.html#FUNCTIONS-INFO-ACCESS-TABLE). Preserve explicit scheduler activation and audit-redaction exceptions; fail closed rather than silently changing grants from the ordinary application.

## Fixes and live cloud state rechecked

The seven existing cloud target definitions still use the deployed `sha256:16c22624a9bf5f1995c8315fbf1554d62dc3707826ba6a9217ff0f2d65327c0e` image. API99 receives100% of traffic, worker count is1 and readiness reports schema62. Public `/admin`, administrative overview/publications and monitor control return404; bootstrap reports no configured console; public configuration reports ads not permitted. These are ordinary GETs, not exploitation attempts.

The retired service account is disabled and its database secret version is DISABLED. API/worker/database-owner secrets have distinct intended service-account bindings; API and worker have only Cloud SQL client at the inspected project role level. The bucket has no public/all-authenticated binding, SQL has zero authorized network entries, and deletion protection remains enabled. Conditional ordinary-object deletion remains scoped to its original prefix. No credential contents or player records were read. Organization-level inherited permissions and a fresh live SQL effective-grant enumeration were outside this read-only check. [Cloud metadata](evidence/security-second-review-2026-10-24/cloud-read-only.json), [IAM/network summary](evidence/security-second-review-2026-10-24/cloud-iam.json).

Both appearance writers retain server unlock checks. Production configuration still rejects shared Studio keys, MFA disabling and temporary ad previews; public API administration is excluded unless an explicit nonproduction legacy opt-in is set. Receiver cancellation/total deadlines and the existing Circuit resume policy remain covered. The deployed stack deliberately runs the owner-approved development/test-driver policy; this is not a production-mode signoff. The PC backend remains on its prior release pending the earlier private-backup approval, and this review performs no PC rollout.

The synthetic SEC01 proof still completes five laps in879 ticks at the real current trajectory acceptance method. SEC02 still changes the clean result by changing only the incident claim. SEC05 still returns202 for normal-bearer deletion and then401 for that revoked bearer. These probes use fictional identities and synthetic geometry; none creates a live record or reward. They confirm retained risks and do not authorize changing the owner’s verification policy. [Six finding/control probes](evidence/security-second-review-2026-10-24/retained-risks.log).

## Client, storage and regression evidence

Manual tracing includes account/session fences and Windows DPAPI/Android AES-GCM vaults; the two ownership writers and migration; public/private router boundaries; immutable-cache authorization and ETags; bounded packed-ghost decoding and account-scoped local cache paths; packed object integrity/ranges; encrypted cold idempotency receipts and account key erasure; and bounded discovery/maintenance operations. Inventory breadth exceeds manual line-by-line review.

- Backend selection: **183 passed,1 failed,54 deselected**. Authentication, browser handoff, appearance authorization, resumes, privacy and new packed-storage/transport/archive behavior are included. The failure is the daily-selection rollback/rebuild fixture returning `DISCOVERY_INDEX_PREPARING`. The current concurrently updated fixture explicitly waits for projection readiness and its focused recheck passes **1 test,25 deselected**. The original failure/log remains; no broad-suite rerun or full-schema PostgreSQL claim is made.
- Actual disposable PostgreSQL verifies both new grant-drift reproductions. Its first run used an incorrect fictional `StudioStaff.created_at` field; the corrected fixture passes. Only the owned fixture containers/network were removed.
- Pinned Godot4.7.2, isolated Windows profiles: cosmetic ownership **9**, session rotation **17**, account privacy/deletion recovery **27**, and download/cache safety **120** checks pass. Earlier sandbox secure-store symptoms do not reproduce in these permitted, isolated checks. This does not certify Android hardware or an exported client.
- The original draft-browser test retains **17 checks/3 failures** because it checks entries immediately after starting an asynchronous scan. A separate copy retains every original owner assertion, adds a bounded scan-completion wait, and passes **20 checks/0 failures**. Three unrelated Desert wind constant-expression/dependent-script diagnostics occur after the summary and are retained; this is not a clean full-project parse result. No original assertion or runtime source was changed by this review.
- The original exception-recovery test still expects a removed legacy input-upload fallback, accesses a missing `schema` after its failed assertion and reaches the owned runner’s50-second deadline. It is retained as an unresolved historical fixture, not converted to a pass or reported as a cross-account exploit.
- Inventory fingerprints **599 source files** and **140 public route declarations**. The value-redacting known-format scan covers **24,245 tracked/selected untracked text files** up to2MB each. Its two candidates are the existing public AWS signing example and its historical patch. Ignored credentials, complete Git history, binaries and arbitrary unknown secret formats remain outside the scan.
-46 locked Python packages are inventoried; `pip check` finds no broken requirements. A limited primary-advisory comparison finds locked Starlette1.7.0 above the patched versions for the maintainer’s [Host/path issue](https://github.com/Kludex/starlette/security/advisories/GHSA-86qp-5c8j-p5mr) and [URL-encoded form limits issue](https://github.com/Kludex/starlette/security/advisories/GHSA-82w8-qh3p-5jfq). This is not a complete dependency/OS/native CVE audit. The previously rejected full package-inventory export was not retried.

The working tree includes newer undeployed storage/archive/discovery/client changes. Completion hashes identify concurrent drift; this report does not treat the workspace as an immutable release. Real provider/MFA/store/ad/consent acceptance, exported-client inspection, complete PostgreSQL concurrency, edge/client-IP abuse tests, native memory-safety work and restore/load exercises remain. Cloud trusted-proxy networks are unset in the inspected environment; the effective frontend/client-IP chain still needs acceptance before public quotas can be trusted across real users. No cloud rate-exhaustion test was performed.

All actual commands, source/artifact hashes, failures, code-only probe copies and limitations are in [the machine-readable report](evidence/security-second-review-2026-10-24/report.json). The [first review](SECURITY_REVIEW_2026_10_24.md), [source fixes](SECURITY_FIXES_2026_10_24.md) and [deployment receipt](SECURITY_DEPLOYMENT_2026_10_24.md) remain separate checkpoints. This pass changes only review tools and documentation; concurrent runtime changes and owner processes are preserved.
'''

patch=[]
def edit(path,new):
 target=ROOT/path;old=target.read_text(encoding='utf-8') if target.exists() else ''
 saved=WORK/'doc-before'/path
 saved.parent.mkdir(parents=True,exist_ok=True)
 if not saved.exists():saved.write_text(old,encoding='utf-8')
 else:old=saved.read_text(encoding='utf-8')
 target.write_text(new,encoding='utf-8')
 patch.extend(difflib.unified_diff(old.splitlines(keepends=True),new.splitlines(keepends=True),fromfile='a/'+path,tofile='b/'+path))
edit('docs/SECURITY_SECOND_REVIEW_2026_10_24.md',doc)
entry=('2026-10-24 SEC-R2/SEC09-SEC10/R01/Q01: Second security pass confirms incomplete-header connection exhaustion before ASGI deadlines and incomplete production effective-grant validation (unexpected schema CREATE/staff UPDATE). Both medium, bounded loopback/disposable PostgreSQL reproductions; no live exploit. SEC01/02/05 retained probes confirm approved trajectory/incident trust and bearer-only deletion risks. Read-only cloud7targets remain on secured schema62, Studio404, old identity/secret disabled, bucket private and SQL authorized networks0. Backend183pass1fail54deselected; concurrent daily-readiness fixture recheck1pass. Native ownership9/rotation17/privacy27/download120 pass; original draft17/3 becomes20/0 with a separate bounded scan wait, retaining3 concurrent Desert parser diagnostics; old legacy-transport recovery fixture times out. Inventory599/public140, value-redacted24245-file scan finds only2 known AWS examples; no full CVE claim. Commands, fingerprints, limits and scoped checkpoint: docs/SECURITY_SECOND_REVIEW_2026_10_24.md and docs/evidence/security-second-review-2026-10-24/report.json. Review only; no runtime fixes, deployment, player mutation, device check/test or APK. Concurrent work/owner processes preserved.')
edit('AGENTS.md','## Second security review override (2026-10-24)\n'+entry+'\n\n'+(ROOT/'AGENTS.md').read_text(encoding='utf-8'))
edit('DEVELOPMENT_STATUS.md',entry+'\n\n'+(ROOT/'DEVELOPMENT_STATUS.md').read_text(encoding='utf-8'))
path='docs/README.md';text=(ROOT/path).read_text(encoding='utf-8')
needle='| Privacy and moderation |'
index=text.index(needle)
text=text[:index]+'| Security review | [Second pass and retained risks](SECURITY_SECOND_REVIEW_2026_10_24.md), [source fixes](SECURITY_FIXES_2026_10_24.md), [cloud rollout](SECURITY_DEPLOYMENT_2026_10_24.md) | [Request boundary](../backend/bmt_backend/middleware.py), [database grants](../backend/bmt_backend/database_privileges.py) |\n'+text[index:]
edit(path,text)
(OUT/'task-only.patch').write_text(''.join(patch),encoding='utf-8')
print(json.dumps({'new_medium_findings':['SEC09','SEC10'],'backend':report['backend'],
                  'retained_probes':report['retained_risk_probes'],'source_drift':drift,'review_only':True}))
