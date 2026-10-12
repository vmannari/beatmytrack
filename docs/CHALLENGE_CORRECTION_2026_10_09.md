# Exact post-race challenges — 2026-10-09

The owner reported that Create challenge after a finish displayed an unavailable-service message and asked for another drive, exposed unnecessary track/car/search controls, and used an inadequate generic dialog. The owner also explicitly removed the unrequested Compare tab.

## Requirements and change

| ID | Implemented behavior |
| --- | --- |
| CH09 / CH02 / CH04 | The post-race action captures the completed upload ticket, immutable track version, actual car, lap count, finish time and account/server scope before the durable upload queue takes ownership. A later retry or menu selection cannot change this result reference. |
| CH10 / CH03 | Result-based creation sends `source_ticket_id`. The backend resolves that ticket's owned, verified run on the exact pinned board, including a slower-than-PB finish. Missing/queued/verifying results return pending; they never fall back to the player's PB. Supplying both ticket and run references is rejected. Group creation from a finish seeds the same verified run. |
| CH11 / V03 / R01 | A custom CanvasLayer sheet replaces the native ConfirmationDialog. Original scenic art, actual route/time, restrained navy panels, yellow segmented type/duration choices, a single primary action, a close icon and eased entrance use the game's existing visual language. Result-based creation has no track/car/search selectors. Service failure retains the result and offers Retry; pending or failed verification never offers another drive. General menu creation retains the necessary selection controls and first-time race flow. |
| CH12 / R01 | RaceResults returns to Track/Sectors/Speed. The added Compare tab, embedded comparison component and default-view switch are removed. Existing histograms remain on the original separate RaceComplete page, with their existing unified scope, deduplication and markers. |
| CH13 / B01–B07 / Q01 | The retained owned development service was confirmed to lack `/v1/challenges`. A narrow frozen overlay adds challenge API/models/migration and the required registration/worker/retention hooks. A fresh successful backup precedes additive migration0019→0020. Existing settings, records, tracks, public isolation, artificial-driver development gates and all112 packaged canonical game files are preserved. Production was not touched. |

The displayed finish comes from the captured race while verification is pending, then from that exact verified ticket. Client times never authorize competitive scores. No local-only or simulated challenge is substituted when the service is unavailable.

## Changed files

`game/ui/challenge_create.gd`, `game/core/app.gd`, `game/ui/race_results.gd`, `game/ui/race_complete.gd`, `backend/bmt_backend/challenges.py`, the challenge GDScript/Python tests, `docs/schemas/challenge-create-v1.schema.json`, `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and challenge documentation. The inspected rollout operator and receipts are retained under `docs/evidence/challenge-correction-2026-10-09/`; its private configuration and credentials remain outside Git.

## Actual verification

| Command actually run | Outcome |
| --- | --- |
| `scripts/dev.ps1 CheckScript -ScriptPath res://core/app.gd` | Passed using pinned Godot4.7.2.stable.official.ed1daf0bf. |
| `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_challenges.gd -Graphical` | 99 checks, zero failures at1280×720,960×540,1600×720. Includes missing API/pending verification/no-rerace, locked selectors, immediate actual finish, exact ticket submission, viewport bounds and source retry behavior. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_challenges.py -k sqlite -q` | 16 passed, one row-lock skip,17 deselected. Exact slower result, existing faster PB, pending ticket with an existing PB, ownership and ambiguous source references covered. |
| `.tools/backend-venv/Scripts/python.exe scripts/test_challenges_postgres.py` | 33 passed, one SQLite row-lock skip on SQLite plus an owned disposable PostgreSQL service; that owned container was removed. New evidence copied into this task and the prior task's evidence restored from its checkpoint. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_challenges_http.py -q -s` with `BMT_CAPTURE_CLOUD` | Two actual graphical/canonical flows:43/47 checks pass; later actual post-race button recheck44 passes. A faster prior verified PB is established in the result-creation case; the slower completed race is used for the invitation. Source-race return, guest try, group creation/race, ghosts, result feedback and rematch continue to pass. |
| `scripts/dev.ps1 TestApp` | 99 checks pass. |
| `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_results_histograms.gd -Graphical` | 36 checks pass. |
| `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_unified_histograms.gd -Graphical` | 46 checks pass. |
| `scripts/dev.ps1 ExportAndroid -QuickValidation -CommandTimeoutSeconds 300` | Import/APP_READY, driving72/catalog21/menus48 pass; corrected debug APK built. Existing31-instance driving shutdown warning retained; no full Validate or physics change/merge. |
| Rollout operator `prepare`, `build`, `backup`, `deploy`, `smoke` | Missing endpoint confirmed; frozen image built/pushed with exact112-file canonical preservation; backup1791521718841 successful; additive migration/API/worker/smoke/catalog update complete; endpoint/native replay/storage/schema/worker readiness passed. |
| `scripts/dev.ps1 Doctor` then `InstallAndroid`/`LaunchAndroid -DeviceSerial f0ba474a` | Tablet initially attached/authorized. Streamed install failed and the device subsequently became unauthorized/offline. Installation and launch of this candidate are unconfirmed; no physical-device challenge UI/race acceptance is claimed. |

The source-race test initially established a PB in both cases, contradicting its own first-time/no-PB setup; the setup was corrected while retaining the slower-than-PB case. A rollout preflight initially used unsupported `jobs execute --command`; no new execution/migration resulted from that failure. The corrected operator verifies the existing Python command and overrides execution arguments only, retaining the same quiet-queue assertion. [Google's execution interface](https://docs.cloud.google.com/sdk/gcloud/reference/run/jobs/execute) documents the supported argument override.

## Evidence and delivery

- [Actual Create challenge button over completed results](evidence/challenge-correction-2026-10-09/http-flow/create-from-results.png)
- [Corrected normal results without Compare](evidence/challenge-correction-2026-10-09/http-flow/normal-results.png)
- [Compact sheet](evidence/challenge-correction-2026-10-09/screenshots/finished-sheet-960x540.png)
- [Native HTTP test log](evidence/challenge-correction-2026-10-09/http-button.log)
- [Database checks](evidence/challenge-correction-2026-10-09/postgres.log)
- [Canonical packaged-file preservation](evidence/challenge-correction-2026-10-09/packaged-game-proof.json)
- [Development rollout receipt](evidence/challenge-correction-2026-10-09/development-rollout.json)

The controlled UI fixture includes88.110s only in tests. Native HTTP pictures are actual canonical races on a disposable local service, with test identities; they are not evidence of a completed race on the retained development service or real Google sign-in. No reference times/names were inserted into shipping data.

Corrected APK: `build/android/challenge-correction-debug.apk`,241,130,965 bytes, SHA-256 `374392FBF2156C4517CECA36EACDAC4B8040CBCB80BEBE12767F0EE7D66A5AA7`. Matching development image: digest `925c6b2606395012a8d9c85a01ac46918fc1f8b44b4b9a88927f111ee7a3ca50`. Owner style/feel acceptance, tablet installation/touch testing and real-account end-to-end challenge acceptance remain. Restart the desktop game to load changed UI; the matching development API is already updated. HTTPS App Link activation remains separate; no production rollout, purchase, data reset, driving-rules change or unsolicited social feature was performed.
