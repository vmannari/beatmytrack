# Faster Google Cloud test drivers

Requirements: TD01–TD07, WR03–WR07, B01–B07, R01, Q01. The owner requested simulated drivers in the existing Google Cloud environment, considerably faster pace, Weekly Rivalry population and 200 finishes per track.

The retained `beat-my-track` staging service now explicitly enables development authentication and isolated test drivers. A completed Cloud SQL backup preceded enablement. A new Secret Manager key is available only to the runtime identity and the authenticated operator; it is not installed in the game, stored in plans, passed on command lines or committed. Google identities remain separate. Production defaults still disable this feature.

There are 213 artificial profiles: 13 rivals in the focused 14-member Week 41 compact group (with a separate development observer), and 200 profiles in the larger fleet. The larger plan schedules **5,400 genuine five-lap finishes across all 27 current official tracks**, one per fleet driver per track. These are input recordings uploaded through ordinary tickets and verified by the existing worker. Histogram population counts distinct verified PBs, not repeated attempts by one driver. Additional focused-rivalry PBs can put the total above 200 on its five tracks.

**The bulk population is still running; 200 verified finishes on every track has not yet been achieved.** The authoritative [progress report](evidence/cloud-test-drivers-2026-10-06/population-progress.json) explicitly records `complete: false` until every track reaches its target. Both hidden Windows schedulers have durable plans and resume using the same idempotency keys after interruption. They depend on this PC remaining on; startup registration and automatic next-week plans are not configured. Full-fleet matching waits for all requested history jobs to verify, then generates genuine weekly attempts. The smaller rivalry already has verified standings and ghosts independently of that history work.

## Pace and completion

`profiled-route-3` emits ordinary quantized controls, uses full throttle and a bounded speed-dependent route lookahead, and reduces continual braking caused by heading error. No car, handling, physics, gate, collision or timing rule was changed. Against the **same deployed compiler 20**, the original controller takes 19,538 ticks on Over and under; the final controller takes **13,863 ticks (29.05% less race time)**. Both recordings passed canonical verification. The oval regression also requires a material improvement and preserves deterministic recordings and skill ordering.

The fast route follower is tried first. If it cannot finish, the scheduler actually drives slower scales, then an obstacle-aware variant; it never rewrites a time or waives a gate. Ellipse exposed a dense loose-tyre wall that static contact queries missed. The variant reads the actual deterministic tyre positions and uses real reversing and steering to detour within the authored road width. Low/middle/high fleet profiles completed all five laps at 8,725/7,437/6,705 ticks, respectively, with exact canonical verification. It is a fallback because proactive detours slowed some other circuits. Ajorata, Ellipse, Knit and Over and under were separately verified through the final scheduling path. Failed required-history drives get four additional attempt variations; exhausted failures remain visible and prevent declaring the target complete.

## Histograms and rivalry

Authenticated development clients can read `/v1/dev/test-drivers/track-versions/{version_id}/histogram?vehicle_id=compact`. It uses the separate test board's verified PB frequencies and returns explicit test labels. Normal public boards still reject test-board IDs and exclude artificial drivers. Ratings and community eligibility retain their existing artificial-identity exclusions.

In the debug app, Race labels the development distribution **TEST DATA · … simulated drivers**, with a **Player data / Test data** switch in the chart heading. Normal standings and player ranks remain separate. Results also label the development chart; normal race results continue to display immediately. The capability and UI are unavailable in release behavior or with test drivers disabled. In Weekly Rivalry, select **TEST RIVALS: ON** to join the isolated test population using your normal Google account; no development key is required by the game for that selection. Normal rivalries continue to contain real drivers only.

Actual cloud screenshots, inspected at 1280×720 and 960×540: [Race test histogram](evidence/cloud-test-drivers-2026-10-06/live-histogram-960x540.png), [verified standings](evidence/cloud-test-drivers-2026-10-06/live-standings-1280x720.png), [duel detail](evidence/cloud-test-drivers-2026-10-06/live-detail-960x540.png). They show the population at capture time, not a fabricated 200-driver finished population.

## Cloud rollout and operations

The workspace compiler is 21, so its recordings were correctly refused by the live compiler-20 build. The generator instead uses `.tools/cloud-driver-project`, extracted from the exact deployed image, with only the offline controller and generator updated. The engine is pinned to `godot-version.txt` (4.7.2 stable ed1daf0bf).

The test histogram endpoint was rolled out with a minimal derived image containing changes to only the deployed `runs.py` and `test_drivers.py`. All `/opt/bmt` canonical project files and the native manifest were compared between base and derived images and were byte-identical. API, worker and existing diagnostic/migration jobs use the new immutable image. This additive retained-staging operation did not weaken the general staging script's changed-image refusal, migrate the schema or deploy production. The original image/rollout receipt is retained. Existing tracks/accounts and local WSL services were not replaced.

From the repository root, using the existing private operator TLS configuration when required:

```powershell
$env:PYTHONPATH = 'backend'
$env:CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE = (Resolve-Path .tools/gcp-staging/windows-trust.pem).Path
$env:REQUESTS_CA_BUNDLE = $env:CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE

# Read current authoritative counts; no races are generated by report.
& .tools/backend-venv/Scripts/python.exe backend/deploy/gcp/test_population.py report --state build/cloud-histograms-200-2026-10-06.json

# Resume after a reboot/interruption. Use one process per plan.
& .tools/backend-venv/Scripts/python.exe backend/deploy/gcp/test_population.py watch --state build/cloud-histograms-200-2026-10-06.json --project .tools/cloud-driver-project --godot 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --max-jobs 20 --interval 10
& .tools/backend-venv/Scripts/python.exe backend/deploy/gcp/test_population.py watch --state build/cloud-rivalry-fast-2026-10-06.json --project .tools/cloud-driver-project --godot 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --max-jobs 20 --interval 10
```

Initial commands actually run: `test_population.py enable` then `enable --apply --confirm-owner` with the retained owner ID; `fill --seed 61006 --target-subject cloud-test-observer --instant`; `fleet --seed 62006 --count 200 --all-tracks --instant`; bounded `tick` passes; hidden `watch` launch/restarts; and `report --output docs/evidence/cloud-test-drivers-2026-10-06/population-progress.json`. Private rollout/capture launchers are retained under `.tools/gcp-staging`; sanitized rollout proof, pace/completion evidence and a scoped source checkpoint are in the evidence directory. Runtime PID/start/command receipts and stdout/stderr logs are next to each plan under `build/`.

## Actual checks and limitations

- Backend driver/staging regressions: **42 passed**; Ruff passes. Tests cover 200 distinct drivers on every one of 27 tracks, private histogram counts, public isolation, persisted profiles, disabling sessions, credential-role separation, scheduling/idempotent recovery and actual slower-input fallback.
- Pinned canonical profile integration: **one test passed**, exercising three skill levels, deterministic repeatability, attempt variation, five laps and material oval pace improvement.
- Native live Google Cloud acceptance: **34 checks, zero failures**, including verified rivalry ghosts, private histogram reads, playable track selection, labeled chart, switch back to real-player data and ten screenshots.
- App regression: **99 checks, zero failures**. Final parser: **309 scripts, zero failures**.
- Final fast-first/fallback completion probes finished **all five laps on all 27 tracks**. These are neutral-profile completion probes, not a claim that all 200 driver histories are finished.
- The exact-cloud baseline/pace proof, difficult-circuit canonical recordings and final completion probes are separate from the bulk server verification. A neutral completion probe does not prove all 200 profiles will finish every circuit.

Earlier failures were retained and corrected: Windows sandbox certificate access; missing cloud-project engine pin/read-only extracted cache; compiler 21/20 mismatch; existing-account `USERNAME_TAKEN` (used an independent observer without altering that account); a paginated diagnostic selecting a local track; initial chart toggle clipping; initial overdriving/skill inversion; Ellipse's tyre-wall stall; and overly broad detours. An accidental `CheckScript` invocation without its required path launched the app and was stopped; it was not reported as a parse pass. One background restart lacked the CLI trust environment; both scoped schedulers were restarted with the established trust configuration. No automatic approval rejection occurred.

Changed source files: `backend/bmt_backend/test_driver_generator.py`, `test_population_tool.py`, `test_drivers.py`, the histogram query in `runs.py`; `backend/deploy/gcp/staging.py` and new `test_population.py`; `backend/tests/test_test_drivers.py`, `test_test_drivers_integration.py`, `test_gcp_staging.py`; `game/input/profiled_route_driver.gd`, `game/backend/generate_test_driver.gd`, the test-capability accessor in `backend_client.gd`, `game/ui/track_browser.gd`, `race_complete.gd`, and `game/tests/test_test_driver_live.gd`. Existing concurrent work is preserved in the scoped checkpoint; no mixed-workspace commit was made.

The [scoped checkpoint](evidence/cloud-test-drivers-2026-10-06/scoped-change.patch) contains only this task's source/documentation changes. `git apply --check --reverse --ignore-space-change` passes against the working tree; the whitespace option accommodates the repository's mixed Windows line-ending normalization.

Remaining acceptance: actual 200-per-track completion, long-running scheduler/worker throughput, exhausted controller failures, elite human pace calibration on every circuit, next-week unattended scheduling, Results chart visual acceptance, and physical-device behavior. This seed is for **compact**; the other four vehicle histograms are not populated by this plan. No Android export/install/device test was performed and phone attachment was not checked. No simulation change required a full physics regression. Retained staging continues its existing billing; worker count, CPU and memory were not increased.
