"""Sanitized post-race latency findings, release and acceptance receipts."""
import hashlib,json,shutil
from pathlib import Path
WORK=Path(__file__).resolve().parent;ROOT=WORK.parents[1]
OUT=ROOT/'docs/evidence/race-verification-speed-2026-11-07'
server=json.loads((WORK/'server-state.private.json').read_text())
assert server.get('complete') and server.get('live_verified')
device=json.loads((WORK/'deployment.json').read_text())
export=json.loads((WORK/'export-result.json').read_text())
assert device['prelaunch_manifest_exact'] and export['exit_code']==0 and not export['source_changes']
ready=device['app_ready'] and device['foreground'] and not device['startup_errors']
for name in ('live_timings.py','recent_races.py','warm_geometry.py','check_warm_geometry.py',
             'measure_live_completion.py','live_completion_client.py','prepare_export.py','export.py',
             'import_project.py','install_verify.py','resume_startup.py','server_release.py','verify_live.py',
             'http_regression.py','write_report.py'):
    shutil.copyfile(WORK/name,OUT/name)
for name in ('live-completion.json','deployment.json','deployment-secure-lock.json','install-preserved.json'):
    if (WORK/name).exists():shutil.copyfile(WORK/name,OUT/name)
for name in ('confirmation-baseline.log','stale-batch-control.log'):
    shutil.copyfile(WORK/name,OUT/name)
if ready:
    shutil.copyfile(WORK/'tablet.png',OUT/'tablet.png')
    shutil.copyfile(WORK/'startup-filtered.log',OUT/'startup-filtered.log')
(OUT/'android-export.json').write_text(json.dumps({key:export[key] for key in ('exit_code','elapsed_seconds','source_changes','build_id','apk')},indent=2)+'\n')
index=hashlib.sha256((ROOT/'.git/index').read_bytes()).hexdigest()
assert index=='1766916322d5d5a6072a820e8d2e153fd06373edcc8d5d11d0b1c4dcea8a3c31'
(OUT/'completion.json').write_text(json.dumps({'backend_deployed':True,'client_installed':True,'client_startup_verified':ready,
    'main_index_unchanged':True,'native_focused_assertions_passed':80,'primary_image_backend_passed':53,
    'primary_image_backend_skipped':2,'studio_image_backend_passed':8,'preview_image_backend_passed':8,
    'saved_app_files_preserved':789,'pending':[] if ready else ['Owner unlock and visible tablet startup acceptance']},indent=2)+'\n')
outcome=('The tablet reaches `APP_READY`, is the actual foreground activity and has no matched startup errors.' if ready else
         'Installation is verified. The tablet remains behind Android’s secure lock screen (`NotificationShade`, with the game as the focused activity). '
         'The owner has been asked to unlock it. `APP_READY`, foreground acceptance and a tablet race timing remain pending; the gate was not waived.')
report=f'''# Post-race verification speed — 2026-11-07

**Backend and client fixes deployed.** Verification geometry for all 31 current published tracks is prepared in advance; successful future publications now persist their already-validated geometry before releasing the track. The tablet update `{device['installed_version']}` is installed with faster completion delivery and corrected reward-wallet validation. {outcome}

## Measured delays and changes

The prior-day worker logs contain eight completions, with no measured queue wait. Three actual player finishes took **2.45–3.68 seconds** in the worker, while the path checks themselves took **3.24–4.01 ms**. The five subsequent deployment-control races include a **2.57-second** first use and **0.13–0.41-second** warm results. These are small, different-source samples, rather than a paired tablet benchmark.

Preparing the current catalogue exposed individual cold geometry preparations up to **9.88 seconds**, including a 106-gate track. A bounded operator pass prepares all 31 exact descriptors in **46.498 seconds**. In a fresh cloud process, with object reads and native geometry preparation deliberately forbidden, all 31 load successfully: **6.76 ms median / 11.00 ms maximum**. The cache retains the exact content/build/layout-24 guards. No track version, target or real-player score is rewritten.

One controlled live artificial race then goes from the start of upload to **verified in 1.169 seconds**, including network time, using ordinary tickets, upload and one foreground wait. The previous best is deliberately not used as a shortcut: the request requires actual path verification. This is one artificial-driver sample, not measured tablet latency or a universal timing promise. Its complete 7,980-tick race is accepted; real-player records are untouched.

The client also introduced avoidable delays:

- A single two-second foreground wait expired into slower outbox polling. The adapter now keeps one shared waiter over at most four serial windows and starts no new window after an eight-second monotonic budget; existing transport timeouts still govern an in-flight request. Early pending replies from an unavailable/busy listener immediately return to ordinary backoff. Account, origin, session-generation and exact run/ticket fences remain.
- A late pending batch reply could overwrite terminal proof, and a completion arriving during an outbox flush could lose its wake-up or inherit the old retry deadline. Terminal cache state now survives stale pending responses; an acknowledged explicit retry can still restart its original run. The outbox schedules a follow-up pass and consumes the exact cached terminal receipt without waiting for the retry timer or making another status read.
- The current server/client cosmetic catalogue contains **269 prices**, exceeding the old **256-entry** wallet limit. Valid post-race coin data was rejected. Wallet validation now accepts the complete compiled catalogue with a finite bound; zero prices, negative balances, oversized catalogues and existing ownership/revision checks remain enforced. Coins still come from the server ledger.

`publications.py` persists geometry only after the creator lap passes its original contract and timing checks, outside the publication’s locked transaction. Rejected proof cannot populate this durable cache. A cache/storage failure cannot invalidate an otherwise valid publication. This reuses geometry already computed for the accepted creator lap, avoiding another cold calculation on the first ordinary race. A future verifier/build change still invalidates old descriptors correctly; run the bounded preparation pass before that build’s traffic promotion.

## Validation and rollout

**80 focused native assertions pass**, including shared/late waits, stale batches, account changes, bounded fallback, explicit retries, completion receipts and the full wallet. Two real native-over-HTTP integration tests pass: 15 completion/read assertions and 17 non-improving/competitive-retry assertions, included in the 80. Original non-improving completion still invokes zero verifications; explicit competitive reuse invokes exactly one. Backend tests on the exact primary image pass **53 / skip 2** across SQLite and actual PostgreSQL 17; the two skips are SQLite concurrency counterparts. Each preserved Studio/preview image passes all **8** new cache cases. Ruff passes for the backend change and regression.

The native source control originally fails five of six prompt-completion checks. A separate stale-batch control still fails after the first wait fix, proving the cache-ordering bug independently. The older outcome-read test fails five cases on the exact pre-change snapshot; the catalogue-bound correction makes all 19 pass. A broader race-demand test retains the same visible-pending-Rivalry polling failure **before and after** (38 pass / one fail); its assertion was not relaxed. That legacy test initially wrote its default historical receipt; the task output was archived and the previously clean original restored byte-for-byte, then the final test used this task’s report path. Initial timer-based fake-HTTP windows needed wall-clock waits because headless startup deltas could expire them before real time elapsed. An initial local harness lacked `PYTHONPATH`; a separate broad run found the configured local PostgreSQL service unavailable and was stopped by its verified task-only launcher/child IDs. The final image tests use an owned, private PostgreSQL container instead.

The backend release changes **only `publications.py`** in each existing image. All other packaged source files and frontend assets match their exact parents. All ten workloads are updated through checked canaries at unchanged schema **0075**; identities, environment, resource limits, process settings, non-root UID/GID and the website-preview route are preserved. Live source hashing, the unchanged **12,757-tick** canonical replay, storage smoke and all 31 catalogue contracts pass. The new revisions have no recorded error/HTTP-5xx entries in the final check. No infrastructure allocation is increased.

The isolated ARM64 export passes existing prepared-resource/provenance, driving, catalogue/menu and archive checks in **208.792 seconds**, with **no export-time source changes**. APK: **{export['apk']['bytes']:,} bytes**, **{device['zip_entries']:,} valid ZIP entries**, SHA-256 `{export['apk']['sha256']}`. Replace-install preserves the original installation timestamp and all **789 saved app files byte-for-byte before launch**. The installed APK hash matches the export. Its previous APK is retained locally. No uninstall, clear-data, track synchronization or PC-save change occurs.

Initial export stopped at an empty task-profile template directory created by normal import; linking the existing pinned templates fixed the prerequisite without relaxing checks. Initial image assembly correctly failed when attempting to compile into the read-only package as its runtime user; assembly now uses root temporarily and verifies the exact original non-root user before/after. A parent image inspection could not see a BuildKit-only cached digest, so inherited UID/GID is asserted inside the build itself. Cloud Run rejected the first long Studio tag; shorter tags were used before any traffic switch. Failed canary creation left live traffic unchanged. Temporary tags, the release lock, registry credentials and the labelled synthetic PostgreSQL container are removed. Private credentials and raw cloud logs remain only in ignored task storage.

## Evidence and remaining acceptance

[Evidence](evidence/race-verification-speed-2026-11-07) contains timing summaries, native/control logs, exact-image tests, package proofs, rollout and device receipts. The [task-only checkpoint](evidence/race-verification-speed-2026-11-07/checkpoint-result.json) records source hashes and a reverse-checked patch; the shared Git index and concurrent changes are preserved. Archived deployment scripts are source copies; commands run from `build/race-verification-speed-20261107` with the existing private cloud configuration.

{outcome} No real device post-race, thermal, frame-time or universal latency claim is made. The backend timing and descriptor improvements above are observed; actual owner-visible race acceptance remains separate.
'''
(ROOT/'docs/RACE_VERIFICATION_SPEED_2026_11_07.md').write_text(report,encoding='utf-8',newline='\n')
print(json.dumps({'backend_deployed':True,'client_installed':True,'client_startup_verified':ready,'saved_files_preserved':789}),flush=True)
