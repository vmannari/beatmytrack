# Third game and backend code review

Repair follow-up (2026-10-03): R1-R13 are repaired in local source. See the [repair record](CODE_REVIEW_REPAIRS_2_3_2026_10_03.md) for final commands/results, migration and remaining deployment/device/PostgreSQL acceptance. The original dated findings and evidence below are retained.

This pass finds **five additional P2 defects** in draft deletion, session-expiry/profile transitions, delayed race starts, replay bounds and retention work. All eight findings from the [second review](CODE_REVIEW_PASS_2_2026_10_03.md) still reproduce. The cumulative open list is therefore **13 findings: two P1 and eleven P2**. The two highest priorities remain local saves getting stuck during autosync and Sign out retaining credentials while reporting success.

Reviewed on **2026-10-03** against the current working tree based on Git `a7010f62cd70049b73e3c035dad24b46d0c719b2`, including substantial existing and concurrent changes. Rules v16, physics 0.49, compiler 20 and the pinned **Godot 4.7.2.stable.official.ed1daf0bf** remain the current contracts. This pass focuses on adjacent lifecycle/recovery paths rather than repeating the prior report's descriptions. Camera/art changes made concurrently are outside this pass.

Requirements covered: **Q01, G01, R01, T01–T04, B01–B07, B19, B20 and B23**, with the current account, creator lifecycle and rewind overrides. Finding IDs R9–R13 continue R1–R8 from the second report. P2 denotes a significant conditional correctness or scaling defect; no additional P1 is claimed here.

The review changes documentation and isolated probe scripts. It does not repair runtime behavior, change schemas, deploy services, use real credentials or modify owner/player data. A DN2103 phone is attached according to Doctor; no physical-device test was performed. No export, installation, deployment or mixed-workspace Git checkpoint was performed. There are no visible UI changes requiring screenshots.

## Additional findings

### R9 P2 Deleted drafts can still upload and reappear

Sources: [draft deletion](../game/core/app.gd), `_confirm_delete_draft` lines 2031–2054; [local library](../game/persistence/track_library.gd), `delete_editable` lines 224–236; [track lifecycle](../game/backend/track_lifecycle.gd), `defer_sync` lines 62–64, `process_jobs` lines 177–205 and `_restore_heads` lines 414–457. Requirements B19/Q01.

The confirmed Delete draft action removes the saved draft/autosave and test files, but does not cancel its in-memory pending synchronization or durable workflow jobs. A pending snapshot can therefore upload after the successful deletion. On the next private-head recovery, `_restore_heads` treats the missing local file as reinstall recovery and recreates the draft's autosave from the backend. Already synchronized drafts can reappear through that same recovery branch even without a pending upload. The UI says the deletion cannot be undone, while recovery automatically reverses it.

**Reproduced:** the actual app confirmation removes a fixture autosave. The real lifecycle then makes one upload and retains one workflow job. Simulating the next private-head recovery restores the autosave. The client supplies fictional server responses; local confirmation, persistence and lifecycle code are real. No owner's draft or live backend object is involved. [Evidence](evidence/code-review-pass3-2026-10-03/client-probes.json).

Record an explicit durable deletion/archive intent for this owner and authoring ID. Cancel queued synchronization and fence in-flight completions; have private-head recovery respect that intent. Preserve immutable published versions and existing share links under their separate retention contract. Regress deletion before staging, after staging, during upload and after remote backup, then restart/recover the profile. Simply removing the visible local file cannot complete this operation.

### R10 P2 Automatic session expiry leaves the app using the old local profile

Sources: [backend client](../game/backend/backend_client.gd), `clear_session` lines 49–53 and authenticated refresh/read failure paths lines 221–251; [account controller](../game/backend/account_controller.gd), `changed` signal and explicit account actions; [application profile switch](../game/core/app.gd), `_account_changed` lines 341–353 and `_select_player_storage` lines 359–404. Requirements B01/Q01.

An authenticated background request can clear the session after a definitive invalid refresh response. That transition happens inside `BackendClient`, which does not notify the account controller. The app changes local storage only when the controller emits `changed`. Consequently, credentials are cleared but the account badge, active profile, records path and draft library remain those of the former authenticated player until a later explicit account operation.

**Reproduced:** a real client read receives fixture 401 responses for both the original request and refresh. The client becomes signed out, but the app's profile scope and records path are unchanged, guest records are not selected, and the account button still says `Review fixture`. A subsequent preference save succeeds into the previous profile. The app uses real profile-selection and persistence functions with isolated paths. [Evidence](evidence/code-review-pass3-2026-10-03/client-probes.json).

Publish an account-state transition whenever the client establishes or clears an identity, and handle it consistently in the controller/app. Preserve or explicitly recover in-progress editing/racing when switching storage; pin existing attempts to their original owner rather than moving them into a guest outbox. Regress revocation/refresh expiry during background upload, resume checking and standings reads, including subsequent guest edits and later sign-in. This is separate from R2: here the client correctly clears credentials but the rest of the app misses the transition.

### R11 P2 A delayed race start can override later navigation

Sources: [race start](../game/core/app.gd), `_start_race` lines 1391–1440; [navigation](../game/core/app.gd), `_show_screen` lines 194–213. Requirements R01/Q01.

The menu stays interactive while `_start_race` awaits its ticket. On completion, only account scope is checked; navigation and the initiating selection are not bound to the request. If the player opens Settings or another menu while the request is outstanding, the late result still hides that newer menu and creates the original race. A failed late request can likewise present its offline-race dialog over the newer screen. Restart already protects its active game/account more carefully, so ordinary start lacks the same lifecycle discipline.

**Reproduced:** a delayed fixture ticket response runs after navigation from Race to Settings. The actual `_start_race` installs the ticket, creates the gameplay scene and hides the menu while `screen` remains `settings`. Navigation presentation and account setup are stubbed to avoid owner configuration/network activity; race creation uses the real game scene. [Evidence](evidence/code-review-pass3-2026-10-03/client-probes.json).

Bind start to a navigation/selection generation and capture the intended track/vehicle contract. Invalidate or cancel it when the player navigates away; check that generation after each await and before installing the ticket or presenting fallback UI. Alternatively expose an explicit cancellable starting state. Regress delayed success/failure, back navigation, vehicle/track selection changes and rapid repeated starts.

### R12 P2 The verifier rejects advertised maximum four-channel replays before simulation

Sources: [verifier envelope](../backend/bmt_backend/verifier.py), `_json_bytes` lines 34–43, `MAX_FRAMES` line 20 and `verify_run` lines 207–218; [HTTP parser](../backend/bmt_backend/middleware.py), `parse_body` lines 57–79; [worker classification](../backend/bmt_backend/worker.py), lines 122–123; [recorded input](../game/input/drive_frame.gd), `packed` lines 20–21. Requirements T01–T04/B07/B20/Q01.

The replay schema supports 216,000 frames and three or four quantized channels. The HTTP parser's 1,200,000-node budget explicitly accommodates a full four-channel replay. The canonical adapter still has a 1,000,000-node budget for the complete invocation envelope. A four-channel replay alone at the advertised maximum needs more than 1,080,000 visited nodes; track/envelope data adds more. Such a request passes submission validation but cannot reach simulation, and the worker classifies the envelope rejection as terminal `invalid_replay`. Normal game recording includes the fourth channel while the handbrake is active. The failure is conditional on a long replay containing enough four-channel frames.

**Reproduced:** both 216,000-frame formats pass HTTP and replay-schema validation. The three-channel envelope passes; the four-channel envelope fails with `JSON structure exceeds verification bounds` despite occupying only 2,160,037 replay bytes. Through the real API/database/worker with a fixture verifier invoking the real envelope validator, submission returns 202 and the worker records `rejected / invalid_replay` before any canonical subprocess starts. The zero-input fixture is a format/bounds probe, not a claimed legally completed race. [Evidence](evidence/code-review-pass3-2026-10-03/backend-probes.json).

Derive compatible structural limits from the supported replay and bounded track contracts, and apply them consistently at admission and canonical invocation. Preserve finite-number, nesting, input-range and byte protections. Regress maximum supported three/four-channel envelopes with a maximum supported track and rewind metadata; also verify an actual long completed replay. Do not lower the advertised frame limit merely to conceal the inconsistent bounds.

### R13 P2 Retention bounds orphan candidates but leaves scan work unbounded

Sources: [retention](../backend/bmt_backend/maintenance.py), `retain` lines 43–50; [offline application requirement](../backend/bmt_backend/maintenance.py), lines 16–25. Requirements B23/Q01.

The 1,000-object cap counts orphan candidates, not inspected files. A store containing mostly referenced old objects can therefore scan its entire history to find no candidates. Every eligible file makes one reference lookup, or two when no track version references it. This work repeats on subsequent runs without a traversal cursor. The same scan occurs before application, which requires stopped API/workers, so growing history can make the maintenance window grow even though the advertised deletion batch stays small.

**Measured with real indexed SQLite lookups and content-addressed fixture files:**

| Retained old objects | SELECTs per dry run | Elapsed time | Orphans found |
| --- | --- | --- | --- |
| 250 | 255 | 266.038 ms | 0 |
| 1,500 | 1,505 | 1,417.077 ms | 0 |

The reference plan uses `ix_version_content`; this is **not a missing-index finding**. The measurements demonstrate the per-object query count and absent scan bound. They are warmed desktop SQLite timings, not PostgreSQL/NAS outage or throughput measurements. [Evidence](evidence/code-review-pass3-2026-10-03/backend-probes.json).

Cap inspected objects independently of deletion candidates, persist traversal progress and batch reference membership queries. Report inspected/deferred counts so operators know whether a batch completed the traversal. Keep the offline deletion gate, reference protection and orphan age threshold. Regress a large mostly-live store, repeated resumed batches, reference changes between batches and interruption before/after deletion.

## Previous findings rechecked

The prior probes were executed against the current code. Their new outputs are saved separately so the second report's original measurements remain historical evidence.

| Second-pass finding | Current result |
| --- | --- |
| R1 P1 Save during autosync | Stale `expected_head = new`, revision conflict and `can_retry = false` still reproduce. |
| R2 P1 Busy Sign out | Session and saved credentials remain while the panel reports local sign-out. |
| R3 P2 Rejected-upload storage | Eight accepted jobs; three rejected requests still increase object count from 8 to 11. |
| R4 P2 Completed-receipt scan | No-work flush still costs 387.965 ms with 2,000 completed receipts on this desktop run. |
| R5 P2 Catalog cap | Finished and persisted catalog still contains 1,001 entries despite a 1,000 cap. |
| R6 P2 Mixed-build health | Matching obsolete fixture API/worker artifacts report ready while ticket issuance returns 409. No live deployment mismatch is asserted. |
| R7 P2 Offset-only scores | Offset 10,020 returns 422; Around me repeats the invalid page and is never requested. |
| R8 P2 Expired validation claims | An expired claim at three/max-three attempts executes a fourth validation. |

[Current client recheck](evidence/code-review-pass3-2026-10-03/previous-client-recheck.json), [current backend recheck](evidence/code-review-pass3-2026-10-03/previous-backend-recheck.json). Recommendations and source detail for these eight remain in the [second report](CODE_REVIEW_PASS_2_2026_10_03.md).

## Actual verification

Commands ran from the repository root. `python` below is `.tools/backend-venv/Scripts/python.exe`. The Godot entry point is `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, using the pinned engine/templates.

| Actual command | Actual outcome |
| --- | --- |
| `python docs/evidence/code-review-pass2-2026-10-03/backend_probes.py` | Exit 0; all five previous backend observations reproduced. Copied output into this pass's evidence directory. |
| Godot entry point `-Action TestScript -ScriptPath res://tests/review_pass2_probes.gd -CommandTimeoutSeconds 120` | Exit 0; all five previous client observations reproduced. Saved the new timing output separately and retained the earlier report's original evidence. |
| `python docs/evidence/code-review-pass3-2026-10-03/backend_probes.py` | Exit 0 on initial and final runs. Reproduces envelope/worker rejection and retention scan work; final run records the indexed reference plan and timings above. |
| Godot entry point `-Action TestScript -ScriptPath res://tests/review_pass3_probes.gd -CommandTimeoutSeconds 120` | Exit 0; records draft resurrection, stale profile after expiry and late race creation after navigation. |
| `python -m pytest backend/tests/test_domains.py backend/tests/test_resumes.py backend/tests/test_maintenance.py backend/tests/test_track_lifecycle.py -k 'not postgres' -q --tb=short --show-capture=no --junitxml=build/review-pass3-domains.xml` | 43 passed, one skipped, 47 deselected; 15.51 s. |
| `python -m pytest backend/tests/test_verifier.py -q --tb=short --show-capture=no --junitxml=build/review-pass3-verifier.xml` | 52 passed; 28.29 s. Includes real canonical-engine tests. |
| `python -m ruff check backend` | All checks passed. |
| `python -m ruff check --select F docs/evidence/code-review-pass3-2026-10-03/backend_probes.py` | Initial new-probe check found one unused import; removed it. Final check passes. |
| Godot entry point `-Action TestRecords -CommandTimeoutSeconds 120` | 54 checks, zero failures; exit 0. |
| Godot entry point `-Action TestRewind -CommandTimeoutSeconds 180` | 57 checks, zero failures; exit 0. |
| Godot entry point `-Action TestDeleteTracks -CommandTimeoutSeconds 120` | 20 checks, zero failures; exit 0. It does not exercise deletion followed by backend synchronization/recovery. |
| Godot entry point `-Action TestReview -CommandTimeoutSeconds 150` | 17 checks, zero failures; exit 0. |
| Godot entry point `-Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 120` | 254 scripts parsed, zero failures; exit 0. Count reflects the concurrent working tree. |
| Godot entry point `-Action Doctor` | Engine/templates/prerequisites passed; DN2103 attached. No device test performed. |
| `git diff --check -- DEVELOPMENT_STATUS.md docs/PHASE_0_PLAN.md docs/CODE_REVIEW_PASS_3_2026_10_03.md docs/evidence/code-review-pass3-2026-10-03 game/tests/review_pass3_probes.gd` | Exit 0 for tracked documentation changes. Newly added untracked files are outside Git's diff check. |

Selected tests total **95 backend passes, one skip and 148 Godot checks**, plus script parsing. They do not cover the newly reproduced scenarios. Probe exit 0 means the observation script completed, not that the runtime is free of defects. The Python harness emits the existing Starlette/httpx deprecation warning. Full backend/Godot gates, PostgreSQL concurrency, live Google/provider flows and NAS/device load were not run in this pass; prior full-gate limitations remain recorded in the [repair report](CODE_REVIEW_FIXES_2026_10_03.md).

## Changed files and remaining acceptance

Added: this report, [backend probe](evidence/code-review-pass3-2026-10-03/backend_probes.py), [backend results](evidence/code-review-pass3-2026-10-03/backend-probes.json), [client probe](../game/tests/review_pass3_probes.gd), [client results](evidence/code-review-pass3-2026-10-03/client-probes.json), and the two previous-pass recheck JSON files linked above. Development status and Phase 0 plan receive review pointers. Review probes are not shipping flows or invariant tests; existing assertions were not weakened.

The backend probe uses a resolved temporary directory under `build/`, fixture authentication and SQLite; its database and object store are disposed afterward. Godot evidence files remain in unique ignored `build/review-pass3-*` directories. Runtime/source changes made by other work were preserved. No real credentials, owner drafts, accounts, databases or deployments were modified by this review. This pass makes no new claim about the live PC backend's operational status.

After repairs, acceptance needs regressions for all 13 open findings; account/navigation/deletion flows under delayed or interrupted networking; process/relaunch and storage-failure recovery; a legally completed maximum-envelope replay through the actual verifier; resumable bounded retention on PostgreSQL; and a clean full regression gate. DS925+ capacity and maintenance windows, Android frame/thermal behavior and human touch/UX acceptance remain unmeasured. The desktop probes identify concrete defects, but do not establish a production player capacity.
