# Demand-driven work during racing — 2026-10-26

The race client now suppresses the optional work identified in `RACE_BACKGROUND_WORK_AUDIT_2026_10_26.md`. A timer expiring or window focus returning is not, by itself, a reason to fetch unused data. A visible result, a newly committed edit, an account transition or a durable unfinished operation provides a concrete reason to work.

These are client changes. No backend schema, verifier, physics, vehicle configuration, recording format or gameplay input changes are included. No backend deployment, APK, device test, real authentication/purchase, owner-save mutation, owner-process restart, staging, commit or merge was performed.

## Runtime behavior

| Work | New behavior | What still wakes it |
| --- | --- | --- |
| Appearance reads | No clean 30-second server polling. The timer stops when there is no unfinished sync. An error from an otherwise clean read does not turn into automatic polling. | Actual appearance commits, unsatisfied durable edits/acknowledgements, account adoption, or explicit freshness requested by the Garage. |
| Empty upload outbox | Initial recovery checks the scoped journal. Once empty, timer ticks perform no further scan or migration read. | Both actual synchronous/asynchronous result writers and direct durable-job writes clear the empty marker. A profile transition explicitly invalidates recovery state. |
| Empty resume recovery | A signed-out adapter does not process. An empty signed-in journal stops processing instead of repeatedly making directories, taking a recovery lease and scanning. | Identity changes or successfully saving an unfinished recovery operation. Explicit recovery still validates the journal and account ownership. |
| Previous uploads and purchase/appearance recovery | Start and completion-triggered entry points defer optional work during preparation and an unfinished race, including pause. | Known pending operations resume with existing backoff in a menu/result context. Original operation identities and journals remain. |
| Challenge/rivalry result polling | Background timer and direct completion callbacks obey the same consumer predicate. Unrelated hidden results do not poll. | A visible relevant result/context outside active driving. Existing receipt reuse and per-ticket backoff remain. |
| Achievement reads | Focus return no longer fetches achievements. A receipt/publication event still invalidates them; an event arriving during racing is retained and coalesced. | The deferred event resumes on menu entry, or the existing explicit achievement consumer requests data. |
| Hidden menu/editor work | Ordinary races, Garage free drive and retries suspend the retained menu's process mode as well as hiding it. Routine editor polling and retained-Garage memory inventory stop during active racing. Queued speculative comparisons are cancelled when covered race preparation begins. | Results/return/cancellation restore the appropriate menu mode. The selected preparation needed for race entry still has its explicit awaited poll. A real OS memory warning still runs the memory-pressure handler. |

The App supplies the policy to each service rather than relying only on a timer guard. This covers direct result callbacks, purchase retry chaining and uploads resumed from a saved-result/long-poll callback. Upload preparation checks again after asynchronous reads/packing; it defers without changing the operation into a failure. An upload already acknowledged by the server retains its durable acknowledgement before optional follow-up work is deferred.

The shared predicate blocks optional work while covered preparation is active and while an existing race has not finished. Finishing unlocks result consumers; pausing an unfinished race does not unlock unrelated work. The menu helper stores the existing process mode and restores it for retained editor/Garage returns, preparation cancellation, results and restart.

Required current-race saves, canonical ticks, input evidence, rewind history, explicitly requested resume/charge operations, account safety and actual memory pressure remain available. Bounded consent-based quality counters and compact release hitch diagnostics remain. Existing in-flight requests can complete; this change is not a blanket cancellation of every network request or an assertion of zero background callbacks.

## Validation

`game/tests/test_race_work_demand.gd` exercises the actual App and production race with a real parked Garage, private records and a synthetic signed-in transport. The vehicle is driven with the actual accelerator action. Existing service callbacks execute unchanged except for the production policy added by this task. The fixture's transport returns synthetic 503 responses; it cannot send real HTTP requests or create real purchases.

The actual-App regression covers:

- No routine memory inventory during driving; all three parked Garage viewports remain disabled.
- No HTTP from clean, pending upload, appearance, purchase, challenge/rivalry-result or focus-return probes during the active race, including direct service entry points.
- Receipt-driven achievement invalidation retained during racing and delivered after return.
- Pending uploads, appearance sync and purchase retries resume after return; the original upload/purchase keys remain unchanged.
- Hidden result contexts do not poll; relevant visible result contexts still do.
- A confirmed-empty outbox does not rescan. Both real result-writing paths wake an idle outbox.
- An empty resume journal sleeps; saving a valid new operation wakes it.
- Clean appearance polling stops its timer; a failed clean read alone does not fetch again.
- Retained menu processing restores correctly, and an actual memory-pressure notification still trims without stepping the simulation.

Final run details and exact commands are in `docs/evidence/race-demand-work-2026-10-26/report.json` and the copied logs. The headless and native desktop reports record hashes at the beginning and end of each run. Tests use the pinned Godot 4.7.2 build, private APPDATA/LOCALAPPDATA and synthetic account/storage paths. The native Compatibility window is positioned offscreen; no owner-window input is sent.

The two final actual-App runs passed **40 checks each**; the selected functional suites passed **1,168 assertions** in total. The project parser loaded **1,309 scripts with zero failures**. Assertions from repeated intermediate runs and the separate failing AI witness are not included in that passing total. All 17 audited source hashes stayed unchanged within both final App runs.

Selected retained checks include appearance conflict/lost-reply recovery, real Garage coin controls, achievement state/UI, upload rate limits and durable retry keys, multi-instance resume ownership, old input-only upload recovery, challenge result actions, all seven Garage test-drive/return paths and the actual App editor save-failure/restart/return round trip. A full project script parse is also run. The report distinguishes final results from intermediate attempts rather than counting repeated runs as extra coverage.

Two test adapters needed updates to their existing contracts, without relaxing their assertions:

- `test_backend_reuse.gd`: the comparison mock now supplies `base_url()` and player identity required by the current preloader's account-scope fence. The preloader itself is unchanged by this task.
- `test_resume_recovery_budget.gd`: newly queued fixture runs now include the current trajectory proof/options and advertised capability. The publication retry mock supplies the current entitlement precondition, counted separately from mutation-budget assertions. Its clock fixture expires the local monotonic deadline as well as advancing server time; a clock adjustment alone is not permission to accelerate retry. Existing pacing/key assertions remain, with an additional entitlement-check assertion.

Initial comparison failures, the original recovery-budget timeout/script error, the subsequent publication-mock failures and the intermediate passing runs are retained under `build/race-demand-work-2026-10-26` and indexed in the evidence.

An additional direct-Game AI witness (`test_editor_practice.gd`) ran 39 checks with four failures: its driver recorded zero completed ordered laps and 27,678 contacts, then could not produce the expected finish state. It instantiates the unchanged Game directly rather than exercising the modified App race policy. `game/core/game.gd` still matches the original audit's byte hash. This failure and its script error are preserved; no driving assertions or physics were changed to make it pass. The actual App editor round-trip test separately passes all 16 checks.

Passing App/Garage probes emitted a two-instance ObjectDB warning on process exit. A verbose run identified two `RefCounted` objects with reference count zero, without identifying a script owner. This is recorded rather than treated as proof of a growing in-race memory leak or a clean-exit guarantee. Godot also emitted the root-certificate-store initialization error; the fixtures use no real HTTP. There were no script errors in the final passing targeted suites.

Desktop functional checks do not establish Android CPU/GPU cost, long-session behavior or all weather/mode combinations. This work does not claim a measured frame-rate improvement. Rebuild/reload the client to apply it; physical-device driving/return/recovery acceptance remains.

## Review scope

The task-start byte snapshots, hashes, exact commands, original failures, final results and a patch against those snapshots are retained. The scoped patch includes only this task's App/service changes, adapter maintenance, new regression and this report. The earlier audit and its original evidence remain intact. Concurrent workspace work is preserved.

Concurrent header-car/Garage edits appeared in App and separate account-cache edits appeared in the comparison preloader while this task ran. They are retained in the workspace and excluded from the task patch. For the overlapping App file, the review base folds those concurrent edits into a copy of the baseline before applying only this task's changes. Original task-start bytes are separately archived; no live source was restored or overwritten to construct the review base.
