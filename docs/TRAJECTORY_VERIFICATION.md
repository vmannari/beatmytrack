# Trajectory-only verification — 2026-10-09

The owner requires a simple proper-trajectory check rather than reproduction of the game. Task-local requirements **VF05** (no simulation/fallback), **VF06** (small computation budget), **VF07** (compact evidence including creator/rewind races), **VF08** (optional ghosts), **VF09** (static prepared geometry), plus **B05/B07/Q01/R01/WR07–WR08/CH09**, supersede the earlier lightweight checker/full-replay fallback described in `VERIFICATION_SPEED.md`.

## Result and measured cost

Race acceptance is now one small Python pass over timestamped positions and prepared gate planes. It instantiates no vehicle, executes no controls and calls no game engine. No tire, collision, jump, hazard, nearest-route or race-session simulation runs during the check. Full replay remains an explicitly named offline diagnostic method; missing/invalid trajectory evidence cannot trigger it.

The original five-lap fixture contains 2,130 trajectory samples and finishes at 12,757 ticks. All original lap tick counts remain `[2634,2532,2531,2530,2530]`.

| Measured scope | Median | p95 | Maximum |
|---|---:|---:|---:|
| Windows checker, 500 calls | 1.6843 ms | 3.1313 ms | 3.6786 ms |
| Windows adapter with prepared geometry, 500 calls | 1.7375 ms | 3.1731 ms | 3.9076 ms |
| Local Linux image, one CPU, 200 calls | 1.1878 ms | 1.8289 ms | 7.2331 ms |

[Windows evidence](evidence/trajectory-verification-2026-10-09/benchmark-final.json), [Linux evidence](evidence/trajectory-verification-2026-10-09/linux-verification.log). Every measured run asserted the exact five-lap timing and prevented engine execution with a failing stub. Static preparation is separate: the cold Windows descriptor took 1,188 ms including native startup/compilation. Preparing it on track validation and caching it in server-owned `OperationState` records lets workers load it without rebuilding the map. A bounded in-process cache also serves direct adapter calls; build/config changes invalidate persistent descriptors.

The normal-race **p95 <5 ms computation target is met in these tests**. This is not a universal wall-time deadline: the Linux one-CPU maximum exceeded 5 ms, and longer trajectories scale with sample count. Decode, blob/database IO, queue pickup, ghost storage and network/UI delays are outside this computation measurement. The initial unoptimized gate loop under concurrent export/test activity measured Windows median3.83/p956.84 ms; it is retained alongside the final benchmark. The final loop caches the current gate and previous signed distance instead of repeatedly unpacking/reprojecting them.

## Minimal acceptance contract

`bmt-trajectory-v1` sends the chronological input count, a small path of `[tick,x,y,elevated]`, authorized rewind events and an optional separately recorded ghost. It sends no control-frame arrays. The legacy eight-field `bmt-race-proof-v1` remains readable when attached to a recording, but its steering/velocity/handling details do not influence acceptance.

The checker requires the pinned start, finite positions within the map, increasing ticks with at most six ticks between samples, plausible segment speed and forward crossings of all prepared gates in order. It accepts a 10% speed allowance and 15 cm corridor tolerance for this deliberately broad policy. The finish is included as the last ordered gate. All five ordinary laps, or one creator lap, must complete at the exact final tick. Timing is derived from the checked path and original input count, minus authorized discarded rewind ticks; no client PB or claimed milliseconds authorizes a score. Lap-end samples are forced to preserve exact fixture lap ticks.

The implementation intentionally does **not** prove that steering, pedals, grip, collisions or jump forces would produce the path. A fabricated but plausible proper trajectory may pass. This is the owner's explicit simplification, not a claim of complete anti-cheat. Existing physical simulation/handling/rules and their game-side checkpoints are unchanged.

Client proof capture branches along with rewind state, so discarded positions cannot leave a false future path. Creator validation persists its actual practice trajectory before uploading. Development drivers still physically drive their canonical controller; the submitted proof is the resulting trajectory. Only unsubmitted obsolete input-only generator cache entries regenerate; committed upload recovery remains private/idempotent.

Ghosts come from the completed recording and are checked/stored as optional presentation. Missing/bad ghosts do not reject a proper race; ghost-storage failure does not requeue its score. Challenge ghost recovery stores existing recorded poses without invoking verification or simulation; a target without a recording remains usable. All public/development identity, membership, rating and eligibility gates remain unchanged.

Input-only recordings contain no trajectory and are no longer accepted through an automatic replay fallback. Their original data is preserved. Existing verified records are not rewritten or deleted. Rollout requires the matching client; old pending input-only recordings need actual trajectory evidence before this policy can accept them.

## Changed files

- `backend/bmt_backend/trajectory_verifier.py`: bounded envelope/rewind checks, durable static geometry and the single acceptance loop.
- `backend/bmt_backend/{verifier,worker,app,track_validation,tracks,observability,challenges,test_population_tool}.py`: preparation/cache, compact capability, no-replay acceptance, separate ghost behavior and compatible driver-cache recovery.
- `game/backend/{runner,race_proof,backend_client,cloud_tracks,track_lifecycle,generate_test_driver}.gd`: static export, path/rewind capture, compact upload, creator persistence and actual generated paths. The obsolete `lightweight_verifier.gd`/UID was removed.
- `game/core/{game,app}.gd`: attach exact completed race/creator paths and original ghosts, branch proof on resume.
- `backend/schemas/trajectory-v1.schema.json`, `backend/tools/benchmark_trajectory.py`, `backend/deploy/{stage_verifier,check_godot}.py`, `backend/bmt_backend/cloud_smoke.py`.
- Relevant native/HTTP/scoring tests, explicit replay diagnostic tests, owner override/status documents and evidence under `docs/evidence/trajectory-verification-2026-10-09`.

## Actual commands and outcomes

| Actual check | Outcome |
|---|---|
| `dev.ps1 CheckScript` for runner/client/App; new-module Ruff; task `git diff --check` | Passed, pinned Godot4.7.2. |
| `pytest test_lightweight_verifier.py` | **9 passed**: real path, compact path, no engine calls, jumps/reversed/incomplete evidence rejected, authorized rewind duration, HTTP/idempotency/ghost storage and queue priority. |
| Replay/persistent diagnostic plus trajectory test files | **80 passed**. Replay assertions explicitly call `verify_canonical_diagnostic`; none is a production acceptance fallback. |
| Native cloud race + creator HTTP fixtures | **2 passed**, including exact completed-ticket submission, actual `trajectory-v1` acceptance and durable creator publication. Initial input-only fixtures were updated to capture the actual path; local-filter assertions explicitly exercise local filtering after protocol negotiation. |
| Real recorded practice through worker | **1 passed / 1 deselected**; saved practice proof now includes its actual trajectory. Initial sandbox certificate access and obsolete input-only fixture failure retained. |
| Core trajectory/challenge/scalability subset | **51 passed / 4 skipped / 40 deselected**. Optional ghost failure now proves scoring completes once, without DB locks or a second verification; the previous expectation of requeuing a score was deliberately superseded by VF08. |
| Owned disposable PostgreSQL: trajectory/scalability/lifecycle/challenges | **113 passed / 8 skipped**; owned container removed after ownership check. Initial PowerShell/Python quoting attempt failed before running; corrected helper used. |
| Actual automatic driver worker/recovery | **1 passed**. Actual generated oval path/cache repeat | **1 passed / 1 deselected**. |
| Native challenge HTTP flows | **2 passed**: exact finished-result creation, frozen slower target, actual recorded ghost/rematch, normal results first. |
| `dev.ps1 TestRewind`, `TestApp`, `TestPractice`, backend upload script | **61 / 99 / 54 / 17 checks**, zero failures. |
| Broad initial backend slice | **110 passed / 7 skipped / 76 deselected / 2 failures**: historical rules-upgrade409 fixture and real-practice sandbox/capture setup. The historical rules mismatch is retained, not weakened. Practice passed after normal engine access and captured path evidence. |
| Windows final benchmark, 500 calls | Under5 ms for every measured call; zero engine calls. |
| Local task-only Linux image, one CPU, network disabled | Five laps and path accepted; zero engine calls. First build refused a parent worker comment/format-context mismatch; parent source inspected and guarded overlay rebuilt successfully. Unrelated packaged game files exact. |
| `dev.ps1 ExportAndroid -QuickValidation` | Startup, driving72/catalog21/menus48 passed; matching-template debug APK exported. Full Validate was not repeated; the earlier task's two storm-render failures remain unresolved. |
| `dev.ps1 Doctor`, `InstallAndroid`, `LaunchAndroid` | Tablet reconnected/authorized; install **Success**, cold launch **ok**. Full physical-device race/verification and owner acceptance not performed. |

## Delivery and remaining acceptance

The initial local candidate was **`bmt-trajectory:3437a5e036e344a13941`**; [original image receipt](evidence/trajectory-verification-2026-10-09/linux-image.json). It superseded the older lightweight image280effff proposal. Automatic approval review originally refused remote replacement without explicit owner permission. The owner subsequently stated **“backend update approved”**, authorizing the development rollout below. Production remains untouched.

The matching APK is **241,655,826 bytes**, SHA256 **13C6AF0FC9B77ADD78D7713AE5DFA2CD74002416EF566FBF057B84E5BDAC0BAD**, and was installed/launched on tablet `f0ba474a`. App data/settings/backend configuration were preserved by replacement installation. The [limited log/process check](evidence/trajectory-verification-2026-10-09/device-startup.json) confirms the process running and zero script/parse/fatal errors in the inspected tail; `APP_READY` was not present in that tail, so no stronger startup inference is claimed. Subsequent histogram/native-Google work installed newer compatible clients. Restart an already-running client to refresh its backend capabilities after rollout. No physical-device competitive finish was performed in this task.

Remaining: representative live tracks/cars/bridge transitions and longest recordings, actual device complete-race acceptance and sustained server latency/capacity measurements. No layout/art or extra player-facing label was introduced, so this task requires no new UI-design screenshot.

## Approved development deployment

The existing backend changed while approval/validation proceeded: histogram image **da0ab3da** was followed by native-Google image **190ef673**. Exact-image guards refused to overwrite the newer version. The final task-only overlay rebases on **190ef67329da6b8eac4d1141187c84b23251e7913d533192274b78495a9c1b52**, preserving all unrelated backend files and the exact histogram/comparison function ASTs. All original **112 packaged game files** remain exact except the named server verification/generation files. [Packaged proof](evidence/trajectory-verification-2026-10-09/approved-packaged-proof.json).

The final immutable image is **61b0accbcfaa3e9e9bdf444273c655bbde853b28a7a5901748854dfebfd7a9f6**. A fresh successful Cloud SQL backup **1791576838378** preceded the policy switch; the existing verification queue was checked empty. The owned development API, worker and associated migrate/smoke/catalog job images now use this digest. No migration or reseed ran, no records were rewritten/reset, and CPU/memory/scaling settings and development/public isolation were preserved. [Deployment receipt](evidence/trajectory-verification-2026-10-09/approved-deployment.json).

Actual commands: `deploy_approved.py prepare`, `rebase`, `build`, `test`, `push`, `backup`, `preflight`, `deploy`, `smoke`; `warm_live_geometry.py`; `live_worker_health.py`; `collect_live_acceptance.py`. The frozen overlay build ran with `--pull=false --network=none`; one-CPU local acceptance measured median **1.108 ms**, p95 **1.421 ms**, maximum **1.760 ms** with zero engine calls. Initial transient TLS read failures were handled with bounded read-only retries. An exact smoke-return-field guard refused the first build because the newer diagnostic had an additional results-route field; that field was preserved, not removed. A concurrent native-Google image change then caused the live guard to refuse the old parent; the new parent was reconciled and retested before mutation.

Live bootstrap now advertises **`verification: trajectory-v1`**, **`trajectory_verification: true`** and **`trajectory_schema: bmt-trajectory-v1`**. `/readyz` returns ready/schema **0020_challenges**, and the compatible worker is registered/ready. The deployed native/storage/schema smoke accepted the actual **12,757-tick five-lap** trajectory in **2.231035 ms** with **zero engine calls during acceptance**, retained the results-comparison route, and checked two temporary storage objects with cleanup. Static descriptors were prepared for **28 current published tracks** in **19.729 s**, with **zero player/score writes**. [Live job results](evidence/trajectory-verification-2026-10-09/approved-live-job-checks.json), [capabilities](evidence/trajectory-verification-2026-10-09/approved-live-capabilities.json), [readiness](evidence/trajectory-verification-2026-10-09/approved-readiness.json).

No new player/profile/race was submitted for acceptance. The read-only worker-log sample found no completed ordinary trajectory race in its sampled window; the live timing above is the explicit diagnostic fixture, not a claimed player race or cloud p95. Existing configured development-driver work continues normally. The earlier pending approval is resolved; no additional confirmation was requested after the owner's authorization.
