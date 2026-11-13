"""Publish sanitized, factual release receipts; private bindings stay under build/."""
import hashlib
import json
import shutil
from pathlib import Path

work=Path(__file__).resolve().parent
root=work.parents[1]
out=root/'docs/evidence/backend-compat-deploy-2026-11-07'
s=json.loads((work/'state.private.json').read_text())
client=json.loads((work/'deployment.json').read_text())
assert s.get('backend_complete') and s.get('history_preserved') and client['prelaunch_manifest_exact']
ready=client['app_ready'] and client['foreground'] and not client['startup_errors']
for name in ('deploy.py','rollout.py','pg_rehearsal.py','install_verify.py','resume_startup.py',
             'pregenerate.py','daily_drives.py','run_daily_drives.py','prepare_daily_drives.py',
             'inspect_daily.py','check_logs.py','check_daily_http.py','cleanup.py','write_report.py','checkpoint.py'):
    shutil.copyfile(work/name,out/name)
for name in ('deployment.json','install-preserved.json','device-transfer-failure.json','deployment-secure-lock.json'):
    if (work/name).exists():
        shutil.copyfile(work/name,out/name)
if ready:
    shutil.copyfile(work/'tablet.png',out/'tablet.png')
    shutil.copyfile(work/'startup-filtered.log',out/'startup-filtered.log')
export=json.loads((work/'export-result.json').read_text())
export_receipt={key:export[key] for key in ('exit_code','elapsed_seconds','source_changes','apk','build_id')}
(out/'android-export.json').write_text(json.dumps(export_receipt,indent=2)+'\n')
index=hashlib.sha256((root/'.git/index').read_bytes()).hexdigest()
assert index=='1766916322d5d5a6072a820e8d2e153fd06373edcc8d5d11d0b1c4dcea8a3c31'
(out/'completion.json').write_text(json.dumps({'backend_verified':True,'client_installed':True,'client_startup_verified':ready,
    'saved_app_files_preserved':client['prelaunch_files_preserved'],'main_index_unchanged':True,
    'main_index_sha256':index,'pending':[] if ready else ['Owner secure-screen unlock and foreground startup acceptance']},indent=2)+'\n')
device_outcome=('The tablet reaches `APP_READY`, is the actual foreground activity and has no matched startup errors. '
                'Its native screenshot was captured for inspection.' if ready else
                'Installation is complete, but Android’s secure lock screen prevents the final `APP_READY`/foreground check. '
                'The app is the focused activity behind NotificationShade; the owner has been asked to unlock it. '
                'No startup error was matched. Startup acceptance remains pending, rather than being waived.')
history=s['history_before']
text=f'''# Matching backend and Android deployment — 2026-11-07

The configured game backend is deployed and verified at schema `0075_receipt_reference_indexes`, upgraded from `0073_publication_publisher_check`. API, private Studio, worker and all seven jobs use matching immutable backend images; the existing website-preview route remains on its own preserved frontend. The ARM64 tablet app is installed as `{client['installed_version']}`. {device_outcome}

This deploys the [performance and cost fixes](BACKEND_PERFORMANCE_FIXES_2026_11_07.md), current Profile/Daily/telemetry support and the current Electric-29 handling contract. Release source hash: `{s['source_hash']}`. See the [rollout receipt](evidence/backend-compat-deploy-2026-11-07/rollout.json) for full image digests and UTC times. Public traffic moved at `{s['promoted']}`.

## Compatibility and preservation

All **31 published tracks** have newly validated, immutable build revisions. The original revisions and scores were not rewritten. Current Free Race selection pins advance atomically without changing tracks or order; existing Rivalry contracts retain their histories. Today’s Daily has a same-geometry compatible variant, created only after five locally driven recordings passed ordinary authenticated tickets, uploads and native server verification. Its initial artificial population is **one verified driver per car**, not a reconstructed historical field. Original Daily targets and accepted results remain valid and unchanged.

A successful managed Cloud SQL backup `{s['backup_id']}` precedes migration. Before/after aggregate fingerprints match for **{history['personal_bests']['count']:,} race bests**, **{history['lap_personal_bests']['count']:,} flying-lap bests**, **{history['rivalry_bests']['count']:,} Rivalry bests** and all **{history['track_versions']['count']} pre-existing track revisions**. These aggregate checks export no player rows. Runtime identities, secrets, resource allocations, limits, commands and probes are preserved across all ten targets. Exact parent frontend hashes preserve Studio, privacy, public pages and the website preview. Least-privilege checks confirm the worker cannot read login tokens or staff records or edit/delete audit records; legacy database login remains disabled.

The tablet update uses replace-install on OnePlus Pad 2 `f0ba474a`, retains its original first-install timestamp and preserves all **{client['prelaunch_files_preserved']} files under the app’s files directory byte-for-byte before first launch**. Installed and exported APK hashes match. No uninstall, clear-data, PC-save manipulation or track synchronization was performed. APK: **{export['apk']['bytes']:,} bytes**, **{client['zip_entries']:,} valid ZIP entries**, ARM64 only; SHA-256 `{export['apk']['sha256']}`. The previous installed APK is retained locally with digest `{client['previous_apk_sha256']}`.

## Validation

- Each exact image passes **192 tests**, with five expected skips: three SQLite-only counterparts of PostgreSQL checks and two historical source controls unavailable in the image. Total **576 passed / 15 skipped / zero failures or errors**. PostgreSQL notification, role, Daily concurrency and snapshot cases actually run.
- PostgreSQL 17 rehearsal uses **20,005 synthetic receipts**: 73→75 upgrade, downgrade, repeat upgrade and real invalid concurrent-index recovery preserve data. `EXPLAIN ANALYZE` uses all four receipt-reference indexes, with only five matching rows retired.
- All three images import the stripped native project, validate the current recorded trajectory and retain the golden **12,757-tick** canonical diagnostic and exact lap times. Full package hashes match frozen source, apart from the intentionally byte-preserved parent frontends.
- Live API readiness/bootstrap/build contracts, private Studio fences, matching worker heartbeat, discovery projections and all **31** discovery entries pass. The actual public Daily selection and fresh limits return HTTP 200 and all nine cutoffs for each of the five matching cars. Live native replay/storage smoke passes and cleans its two diagnostic objects. No new revision error or HTTP 5xx entry appears in the bounded release log check.
- The isolated Android export succeeds in **216.236 seconds**, with no export-time source changes. Existing prepared-resource/provenance, driving, catalogue and menu gates pass; every APK ZIP checksum is checked before installation. The pinned official Godot 4.7.2 ARM64 engine is used; no unqualified custom Android shader engine is substituted.
- New staging regression checks require the exact numeric checkpoint-cache dependency and every literal preload’s presence. Ruff passes for the staging change and test. The shared Git index remains unchanged; unrelated working changes are preserved.

## Findings and retained initial failures

Native Linux acceptance found a genuine missing dependency: `TrackSession` preloads `race/checkpoint_layout_cache.gd`, which the stripped verifier omitted. `stage_verifier.py` now includes it, with `test_verifier_stage.py` covering the dependency closure. The corrected package passes real native acceptance; error checks were retained.

The first image-test run produced 18 PostgreSQL setup errors because the tests deliberately require a loopback database. Containers now share the owned PostgreSQL container’s loopback network; no test safety assertion was changed. The final three suites pass. Initial fresh Android export needed the isolated project’s import/class cache; normal import followed by the unchanged export gates succeeds. A local recording-plan omission of the required manifest was corrected before any upload.

The first catalogue job could not read GCS objects using the intentionally restricted migrator identity. The existing catalogue operator job supplies its already-authorized storage access. That attempt then exposed an idle-in-transaction timeout during slow native validation. The release caller retains loaded immutable metadata and commits the read transaction before storage/native work; a fresh transaction still locks and rechecks every head before the atomic append. No IAM or timeout setting was relaxed, and neither failed attempt changed track revisions. Initial failure tracebacks and the secondary verifier shutdown warning remain in private task logs. The old API’s `/ready` returned `SCHEMA_NOT_READY` between schema migration and traffic promotion; this is not a zero-downtime deployment claim.

The first rollback-APK transfer stopped when the USB target disconnected, before installation. After reconnection the complete prior APK was verified, then the new APK installed with the preservation checks above. The secure-lock startup timeout is retained in its own receipt. {device_outcome}

## Receipts and limits

[Evidence](evidence/backend-compat-deploy-2026-11-07) contains exact-image test summaries, package/native proofs, database rehearsal/backup/history receipts, compatible catalogue/Daily results and device installation results. Scripts are archived source copies; deployment commands run from the task’s `build/backend-compat-deploy-20261107` directory, where private state, credentials and raw cloud logs remain excluded from evidence. Owned synthetic PostgreSQL/network resources, temporary registry credentials, temporary canary tags and the release lock are removed. Rollback images/APK are retained.

Cloud resource sizing is unchanged; no realized billing reduction is claimed from this rollout. Native tests, five controlled server-verified races and installation/startup checks do not establish tablet driving, thermal, frame-time or visual acceptance. Existing device/user acceptance limits from the linked feature reports remain.
'''
(root/'docs/BACKEND_COMPAT_DEPLOY_2026_11_07.md').write_text(text,encoding='utf-8',newline='\n')
print(json.dumps({'backend_verified':True,'client_installed':True,'client_startup_verified':ready,'main_index_unchanged':True}),flush=True)
