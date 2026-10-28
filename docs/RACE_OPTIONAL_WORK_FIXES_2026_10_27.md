# Runtime items 5 and 6: deferred menu work and sleeping callbacks

27 October 2026. Implements the owner's requested items 5 and 6 from the runtime follow-up. This closes the two late-completion gaps and removes the pause-only allocation and empty Garage-preloader frame callback. The earlier [race-work re-audit](RACE_BACKGROUND_WORK_REAUDIT_2026_10_27.md) remains the historical reproduction.

Requirements: **RTF05A** defer new optional snapshot writes; **RTF05B** defer header-image publication and late readback; **RTF06A** construct pause state only while paused; **RTF06B** sleep the empty preloader with event-driven wake and complete read reaping; **R01** preserve existing ownership/durability/input assertions; **Q01** distinguish desktop functional verification from Android/performance acceptance.

## Resulting behavior

| Requirement | Change |
|---|---|
| RTF05A | App binds the shared menu snapshot writer to the existing race-work policy. Late menu responses still update/coalesce the latest scoped RAM snapshot. A blocked writer sleeps before copying or dispatching another optional disk job. An already dispatched atomic write completes normally. Navigation, menu/results visibility and loading-state events wake pending work. The existing 16-path / 2 MiB-per-write bounds and scope checks remain. |
| RTF05B | Completed header read/write images stay in their existing single job while the consumer is ineligible. No mipmap generation, `ImageTexture` publication, disk-hit increment or changed notification occurs then. Eligibility rechecks owner epoch and current appearance before publication; owner/appearance changes discard stale results. A second guard at `frame_post_draw` prevents readback/new writes when race entry closes permission after the earlier frame callback; it retains one valid recapture for menu return. |
| RTF06A | The 16-value presentation key is constructed only in the paused branch. Active frames do not allocate that array or a replacement empty array. Resuming clears the retained key once. Existing camera/viewport/locale/rewind/ghost invalidations and canonical state remain. |
| RTF06B | The Garage preloader retires optional state and consumes outstanding threaded reads before disabling its process callback. Navigation, loading-state changes, existing appearance invalidation and foreground lifecycle events wake it. A wake during an active race goes back to sleep. Pressure eviction remains suppressed and still reaps outstanding loads. Asset limits, original studio adoption, paint/parts/wear ownership, visibility/culling restoration and direct/partial entry remain. |

This does not defer required current-race persistence or cancel admitted atomic saves. No simulation, reward, entitlement, save-format or shader/geometry behavior is changed by this task.

## Changed runtime files

- `game/backend/menu_snapshot_writer.gd`: policy binding, dispatch guard and resume entrypoint.
- `game/ui/header_car_appearance_cache.gd`: completed-image eligibility and late-draw guard.
- `game/ui/garage_preloader.gd`: sleep/reap logic and invalidation/lifecycle wake.
- `game/core/game.gd`: pause-key allocation moved into the paused branch.
- `game/core/app.gd`: bind the writer policy and wake optional work on navigation/menu/loading events.

`game/tests/test_race_optional_work.gd` extends the existing race-work audit, retaining its original demand-work assertions and replacing its historical bug-counterexample method with the fixed-behavior checks. The historical audit and its original assertions/evidence are unchanged. The new fixture uses private records, explicit offline configuration and synthetic transport.

## Verification

Pinned Godot `4.7.2.stable.official.ed1daf0bf`; native testing is Windows Compatibility on the workstation, with Dummy audio. Exact process arguments, test copies, logs, output JSON, captures and source hashes are in [the evidence ledger](evidence/race-optional-work-fixes-2026-10-27/report.json).

| Fresh run | Actual result |
|---|---|
| Focused real-App race regression, headless | **85 checks / zero failures** |
| Same focused regression, native Compatibility | **85 checks / zero failures** |
| Existing App suite | **141 checks / zero failures** |
| Existing equipped-header native suite | **45 checks / zero failures**, including unchanged picture/reference thresholds, disk reuse, corrupt-cache recovery and account replacement |
| Existing Garage preload, headless | **399 checks / zero failures** |
| Existing Garage preload, native Compatibility | **400 checks / zero failures**, including actual original world adoption/input, resource-only/partial/interrupted entry, scope and pressure guards |
| Final parser | **1,346 scripts / zero parse failures** |

The focused runs include a 35-second active-driving window, late snapshot coalescing, an actual already-admitted atomic write finishing under a closed policy, resumed latest-value persistence, completed read and write images, no duplicate publication, stale account/appearance rejection, the post-draw race, real ResourceLoader request reaping, loading/focus wake and pause camera/viewport invalidation. Original pending upload/purchase/appearance/achievement identities and real menu recovery still pass. Assertions overlap and are not independent feature counts.

All seven final runs return zero and contain no script errors or leaked-object/resource shutdown findings. They do emit the existing sandbox root-certificate-store initialization error; this has not been suppressed and these are not error-free engine acceptance receipts.

### Retained initial failures

The first new fixture used `get_tree()` on a SceneTree and failed parsing. The corrected fixture uses the SceneTree itself. A later run observed a wake after the preloader had already slept again; a fixture observer now checks delivery independently of that transient flag. Its camera-save probe also exposed that the parent transport fixture's synthetic appearance state was not a committed save fixture. Camera persistence now uses a separate valid private store, with its parent directory explicitly created. The intermediate missing-directory assertion remains in evidence. The stuck earlier fixture's own process was stopped by its runner's 360-second timeout; no owner process was stopped.

No production invariant was weakened to address these fixture failures. The final camera save is asserted successful, and the inherited pending-operation/recovery assertions still pass.

## Commands and source scope

From repository root, the evidence runner uses the pinned executable directly:

```text
python build/race-optional-work-fixes-2026-10-27/run_checks.py focused-headless-v4 tests/test_race_optional_work.gd headless
python build/race-optional-work-fixes-2026-10-27/run_checks.py focused-native tests/test_race_optional_work.gd gl_compatibility
python build/race-optional-work-fixes-2026-10-27/run_checks.py app-headless tests/test_app.gd headless
python build/race-optional-work-fixes-2026-10-27/run_checks.py header-native tests/test_header_equipped_cache.gd gl_compatibility
python build/race-optional-work-fixes-2026-10-27/run_checks.py preload-headless-final tests/test_garage_preload.gd headless
python build/race-optional-work-fixes-2026-10-27/run_checks.py preload-native-final tests/test_garage_preload.gd gl_compatibility
python build/race-optional-work-fixes-2026-10-27/run_checks.py parser-latest tests/test_script_parse.gd headless
```

Existing-test copies change only explicit empty `backend.cfg` setup and known output paths; original assertions and fixture reads remain. APPDATA/LOCALAPPDATA are private directories beneath the task build folder. No development-wrapper build-identity generation was invoked.

Five runtime baselines were captured before editing. The task-only App after-image contains only this task's 12 added lines; concurrent road-material editor controls and their helper are preserved in the working tree and excluded from that patch. A later concurrent first-menu-draw/early-construction gate in `garage_preloader.gd` is also preserved and excluded from the task-only after-image. The final Garage preload suites and parser are repeated against that combined working tree. Concurrent render/cache, upload rounding, backend and other owner changes are excluded as well. The headless focused run's 25 source hashes match start/end. The native focused run records an unrelated `ui/car_showroom.gd` change during execution; the five task runtime sources remain stable in that run. It is not claimed to be an immutable whole-tree release run.

The [task-only checkpoint](../build/race-optional-work-fixes-2026-10-27/task-only.patch) is checked/applied in an isolated directory and compared byte-for-byte. The owner repository is not staged or committed. See [checkpoint verification](evidence/race-optional-work-fixes-2026-10-27/checkpoint-verification.json) and [source hashes](evidence/race-optional-work-fixes-2026-10-27/source-hashes.json).

## Limits and remaining acceptance

These changes close scheduling/eligibility gaps and unnecessary work; they do not establish a measured FPS gain or runtime 10/10. The final native Garage control records a 4.60-second warm-draw interval, including other App rendering. Its timing is not a paired performance benchmark, and concurrent rendering work is outside this patch.

Reload/rebuild the client to use the changes. Owner acceptance and Android input/lifecycle/frame-time/pressure behavior remain untested. No physical-device attachment query/test, APK/AAB, real authentication/purchase/provider operation, owner-save mutation, cloud mutation/deployment, owner-process restart or main-index staging/commit/merge was performed.
