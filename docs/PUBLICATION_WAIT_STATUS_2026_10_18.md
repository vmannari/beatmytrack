# Publication wait and Load track status — 2026-10-18

PWS01 gives explicit player publications priority over idle artificial-driver generation. PWS02 displays the saved publication state on Create → Load track cards. R01 retains normal server verification, saved evidence and original request identities; Q01 requires reproduced failures and rendered checks.

## Live observation

The owner's transferred Winter track, Snowmen, uploaded successfully as Ville and remained queued with zero verification attempts. The service was ready, while the competitive worker heartbeat was stale. Read-only worker-pool logs showed a long automatic-driver generation pass occupying the competitive worker. Its existing cooperative cancellation check considered ordinary human races, but omitted publication intents.

The existing worker subsequently claimed the original request and published it normally on its first attempt. The server's creation-to-finish interval was **212 seconds (3 minutes 32 seconds)**. Read-only Studio inspection confirmed the published receipt and verified creator run. The local journal then became published and the saved draft/autosave retired from Load track through the existing finalization path. No manual queue mutation, replacement publication, re-test, force acceptance or extra slot consumption was performed by this task. Private identifiers, track contents and detailed operational receipts stay in ignored `build/snowmen-publication-diagnosis/`.

## Changes

`backend/bmt_backend/background_work.py` now checks claimable ordinary-player publication intents alongside its original human-race check. Both queued work and expired verification leases interrupt artificial generation through the existing `BackgroundYielded` path. Active leases, failed/published requests and artificial backlogs do not interrupt. The existing 250 ms check cadence and generator cleanup remain; this does not promise a 250 ms complete publication time. No new worker, scheduler, polling service or infrastructure setting is introduced.

`game/backend/track_lifecycle.gd` retains the job state in the bounded presentation projection. `game/ui/draft_browser.gd` passes it to the existing tile. `game/ui/track_tile.gd` uses Publishing, Queued, Checking, Published or Failed while keeping Draft/Tested for unpublished local work. Badge width follows its actual text. An identical queued response retains the original gallery nodes and controls. The actual selected detail caption and submit guards remain in force.

## Actual validation

| Check | Result |
| --- | --- |
| New priority regression with archived original implementation | 3 failed, 4 passed; all three claimable-publication interruption assertions reproduce |
| New priority and original publication-intent contracts, SQLite | 21 passed, 2 skipped, 22 PostgreSQL cases deselected |
| Existing human-race preemption | 1 passed, 8 unrelated cases deselected |
| Journal-to-Load-track badge regression, headless | 25 checks, zero failures |
| Badge regression, Compatibility | 27 checks, zero failures |
| Badge regression, desktop Mobile | 27 checks, zero failures |
| Publishing slots / retained controls | 55 checks, zero failures |
| Original local publication / real driven creator lap | 31 checks; 2605 ticks / 436 samples; zero failures |
| Complete parser | 894 scripts, zero failures |
| Scoped whitespace check | Passed |

The priority fixture uses the real publication API, database, saved original document/trajectory hashes and normal publication verifier. Interruption itself neither claims nor rewrites the intent. Original evidence is then accepted once through the normal processing path. Lease/state cases verify that settled or currently owned work does not cause artificial generation to spin.

The badge fixture saves actual local journals and scans them through the real DraftBrowser. It checks every displayed state, the queued submit guard, unchanged queued-poll node identities and original Draft/Tested fallbacks. [Compatibility queued card](evidence/publication-wait-status-2026-10-18/gl_compatibility/queued-1280x720.png) and [desktop Mobile checking card](evidence/publication-wait-status-2026-10-18/mobile/checking-1280x720.png) use disposable Winter-loop data rather than the owner's files.

Initial attempts retained in the task record: importing the shared publication fixture initially omitted its dependent `domain` fixture; adding that import exposed the three intended failures. The broad initial invocation additionally encountered seven PostgreSQL setup errors because the historical localhost:55439 fixture is unavailable. Final SQLite results are scoped explicitly, with no PostgreSQL pass claimed. The first network probe met the sandbox's socket restriction; approved read-only host access succeeded. Existing dependency/index-reflection warnings remain.

Commands used the pinned Python environment and Godot 4.7.2:

```powershell
.tools/backend-venv/Scripts/python.exe build/inspect_snowmen_publication.py
.tools/backend-venv/Scripts/python.exe build/inspect_snowmen_worker.py
.tools/backend-venv/Scripts/python.exe build/run_publication_priority_baseline.py
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_publication_background_priority.py backend/tests/test_publication_intents.py -k 'not postgres' -q --tb=short
.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_lightweight_verifier.py -k player_run_preempts_background -q --tb=short
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publication_badges.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 120
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publication_badges.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 120
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publication_badges.gd -CommandTimeoutSeconds 120
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publishing_slots.gd -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_local_draft_publication.gd -CommandTimeoutSeconds 180
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
```

Godot used disposable workspace APPDATA and process-only PowerShell execution-policy Bypass. Original-source snapshots, backend before/final logs, synthetic renderer captures, command receipts and the source-only task patch are under `docs/evidence/publication-wait-status-2026-10-18/`. Concurrent client, editor, Rivalry and backend work is preserved. No root Git metadata is changed.

The live Snowmen publication is complete. These scheduling and badge changes remain **local source changes**: matching client/backend-worker rollout and owner appearance acceptance remain. No deployment, phone attachment check/test or APK/export/install was performed.
