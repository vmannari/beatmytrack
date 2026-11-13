# Kart momentum slide — 2026-11-07

KMS01: Owner clarifies that fast steering should lose tire grip and carry the kart
along its existing movement vector. Kart-18 replaces the preceding response-only
tuning with an actual lateral-force cap: full grip through98km/h, smoothly fading
to85% at140km/h. The chassis's existing steering/yaw calculation remains intact;
the tires have less force to redirect world-space momentum. Slowing restores grip.
The old lateral-response reduction is disabled for this kart. Other vehicles use
the default1.0 force scale, omitted from their configuration snapshots.

KMS02: Actual one-second140km/h entry,0.65 steering, full power: incoming-direction
travel increases13.221to15.010m versus Kart-17. Travel deflection falls140.54to131.54
degrees while the chassis continues into the bend; body/travel separation reaches
19.35degrees. Coasting carries1.69m farther in the incoming direction. Both turn
directions agree. These are actual simulation steps, without regulating velocity
or rotating the movement vector to match heading. The trace comparison is at
`build/kart-momentum-slide/trajectory-comparison.svg`; its arrows show both travel
and body direction.

Against the same kart with its force reduction disabled, half-second coasting
path differences at40/80/100/120/140km/h are0/0/0/0.069/0.623m. Thus the onset stays
negligible near100km/h and develops with speed. Sustained powered steering peaks
at21.07degrees and settles near108.16km/h; straightening settles within342ms.
This real grip loss can scrub below the existing120km/h artificial full-lock speed
ceiling. The preceding speed test is now explicitly historical, retaining all its
assertions against saved Kart-17; the active test checks actual outward travel,
bounded slide, useful speed, recovery and energy loss instead of promising that
less grip preserves the former corner speed. The former response-only test is
also preserved against the same historical fixture. No failing assertion is deleted.

KMS03: New momentum checks4995/0 include deterministic replay, meaningful outward
path displacement, low-speed controls, 4800 exact straight acceleration/braking/
coast/reverse steps,140km/h straight cap, coasting energy monotonicity, other-car
identity preservation and bounded recovery. Historical response6377/0 and
turn-speed18/0 pass. Final integration outcomes and assets are recorded below.

Kart42/0, winter55/0, final/actual Game3613/0, handling88/0, driving72/0,
rewind61/0 and three five-lap zero-contact full/resumed replay checks15/0 pass,
with no script errors. Dedicated paths cover full-lock and partial steering in
both directions, powered and coasting. The historical tests are explicitly
qualified as historical; they are not evidence that the new grip-loss car must
hold the prior artificial corner-speed ceiling.

Runtime files: `game/vehicle/handling_config.gd`, `vehicle_simulation.gd` and
`game/resources/cars/kart.tres`. Tests: new momentum test/probe and saved Kart-17
fixture; existing final/winter/kart/capture identity checks; explicit historical
response and turn-speed regressions. Both local load fixture manifests use
Kart-18/hash`6365a7fd75150925c961de04933fbc238de7ca0e7202b0e1c2cfe1ff66f751cb`.
Prepared assets and image provenance follow current sources.

Commands, logs and private offline profiles are under`build/kart-momentum-slide/`:

- `python build/kart-momentum-slide/run_checks.py probe_kart_momentum_slide`
- The same runner with`test_kart_momentum_slide test_kart_fast_slide test_kart_turn_speed`.
- The same runner with`test_kart test_kart_winter_grip test_kart_final_handling test_handling test_driving test_rewind test_kart_fast_slide_tracks`.
- `python scripts/prepare_car_assets.py --output build/kart-momentum-slide/prepared-assets`
- `python build/kart-momentum-slide/plot_trajectory.py` uses the real-step trace.

Pinned Godot4.7.2, private APPDATA/LOCALAPPDATA, empty backend URL. Script errors
count as failed runs. The momentum/historical tests retain resource-at-exit
warnings. Matplotlib is absent; the diagnostic path figure uses standalone SVG
from recorded coordinates without installing dependencies.

Limitations: PC owner feel remains unverified; relaunch the current project before
trying the tune. No device test, APK, owner-process/save change, live request or
backend deployment. Matching service rollout remains. Concurrent work and the
main index are preserved; no merge or appearance/performance claim.

Final asset pipeline:442 modules rebuilt,468 prepared resources/1925 checks/zero
failures and five native pictures with157 current source hashes. The complete
bake source receipt is stable. Expected pre-bake stale-resource/provenance
failures are retained. `build/kart-momentum-slide/task-source.patch` is an
incremental source-only checkpoint checked in reverse against final files;
generated binary assets remain in the workspace. The retained verification-log
summary records every final test log and its hash.
