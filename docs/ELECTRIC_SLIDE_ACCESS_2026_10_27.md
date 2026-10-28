# Easier electric power slides and firmer braking — 2026-10-27

The owner finds electric-17 difficult to slide and expects acceleration plus steering to start a slide much more easily. They also request slightly stronger braking. The accepted direction remains planted and punchy with controllable power slides, distinct from Compact. These requests supersede the previous small-power-slide ceiling and the 12 m/s² stopping windows.

## Requirements and implementation

- ESA01: Accelerating and turning must produce a deliberate slide with keyboard and moderate controller pedal input, including a standing launch.
- ESA02: Lifting and straightening must recover predictably. Keep planted light-pedal handling, existing steering geometry, ordinary right-angle corner clearance and smooth high-speed behavior.
- ESA03: Increase one-pedal braking moderately while retaining progressive release, exact stopping, stopped hold and D/R behavior.
- R01: Version canonical behavior and fixtures, preserve the six other car identities/arithmetic and independently verify a five-lap recording.
- Q01: Retain actual commands, failed trials, native evidence and a task-scoped review patch. Preserve concurrent changes.

Electric-18 changes regeneration 12→15 m/s², launch lateral-response scale 0.30→0.18, powered lateral-response scale 0.70→0.28 and slide drive loss 0.25→0.20. The last change keeps useful motor pull while the car travels sideways. Mass, motor force, steering rate/angle/inertia, neutral lateral response/grip, curvature envelope and 190 km/h cap stay exact.

Two optional configuration fields control the existing power-slide response. `power_slide_full_pedal=0.65` reaches full effect at 65% pedal instead of 85%; the smooth onset still starts above 46%. Light pedal, lift, straight steering and reverse retain the existing inactive gates. `power_slide_high_speed_scale=0.75` smoothly reduces this effect from 100.8 km/h toward maximum speed. This preserves the original high-speed turning checks without reducing ordinary-speed slide access. Neither field adds yaw or drive force. Defaults retain exact prior arithmetic and disappear from legacy configuration snapshots.

The canonical physics identity is `arcade-planar-0.75`; electric hash is `6b260c269efbdf3fe6de32f618125255998a0cd706cfe02fd47d13c3b028e424`. The local backend fixture changes only global physics and the electric entry. Six other vehicle configuration identities are exact.

## Actual results

The 518-check focused matrix covers seven starting speeds (0–170 km/h), three steering inputs, four pedal positions, mirrored turns, replay, pedal progression, recovery, neutral geometry and braking. At 50 km/h, full steering and 65% pedal now produce 19.45° peak slip, with sliding beginning at 300 ms. The same new grip settings with the old pedal gate reach only 8.53° and never cross the unchanged 14.9° sliding threshold. The full matrix peaks at 19.93°; normal-speed deliberate inputs sustain actual sliding and grip response. Every sampled powered turn still accelerates, retaining at least 79.29% of the old tune's final speed over the same 1.5 seconds. Straightening settles slip below 1° and yaw below 0.1 rad/s within 300 ms.

The standing full-power/full-steer launch reaches the sliding threshold at 616.7 ms. Native Game keyboard input produces 17.885° versus 5.270° with the powered response disabled. Both desktop renderers pass 77 input/selection/control/recovery checks. These are synthetic inputs through real Game code, not a physical-controller or owner driving-feel test.

| Release from | Electric-17 time / distance | Electric-18 time / distance |
| --- | --- | --- |
| 72 km/h | 1.650 s / 16.368 m | 1.325 s / 13.112 m |
| 190 km/h | 4.267 s / 111.000 m | 3.433 s / 89.497 m |

First-tick deceleration at 72 km/h is 15.219 m/s² including resistance. Stopping distance is about 20% shorter. Zero crossing, stationary hold, reverse release and progressive pedal behavior pass. Actual 0–100 remains 1.4917 s and 190 km/h is reached in 3.2667 s. Full-power straight D/R trajectories remain exact for 2,400 ticks each. All 18 ordinary held-circle radius results are exactly equal to electric-17; original lane, prompt-turn, alignment and speed-consistency checks pass unchanged.

Over and under completes five ordered laps, both bridge layers and zero contacts. The 34,805-input recording independently verifies at 290,035 ms with lap ticks `[7020,6947,6946,6946,6946]`. Five Storm circuits complete their existing one-lap diagnostics; three legacy regression circuits each complete five laps with zero contacts and exact replay. Artificial driving is a regression check rather than owner feel acceptance.

## Commands and checks

All Godot calls use `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe`; direct headless calls use an absolute `--log-file` under this task's evidence directory. The actual suite list and checked results are in [report.json](evidence/electric-slide-access-2026-10-27/report.json).

```powershell
# Each suite in report.json, including the focused slide, existing electric,
# handling, rewind and parser checks:
& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --log-file 'C:/Codes/Godot/Beat my track/docs/evidence/electric-slide-access-2026-10-27/test_electric_slide_access-final.log' --script res://tests/test_electric_slide_access.gd -- --evidence-root=res://../docs/evidence/electric-slide-access-2026-10-27

powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_electric_car_ui.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--evidence-root=res://../docs/evidence/electric-slide-access-2026-10-27/native-compatibility','--over-and-under','--powered-drift')"
# Repeated sequentially with -RenderingMethod mobile -RenderingDriver vulkan
# and a separate native-mobile evidence directory.

# From backend/:
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_verifier.py tests/test_electric_car.py -q -k 'not postgres and not retained_over_and_under_rejection' --tb=short --basetemp ../build/electric-slide-access-pytest-final

# From the repository root:
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-slide-access-2026-10-27/verify_canonical.py
./.tools/backend-secure-venv/Scripts/python.exe docs/evidence/electric-slide-access-2026-10-27/finalize_evidence.py
```

Final results: focused518, powered269, launch111, release38, speed53, character74, held53, power19, balance16, car60, one-pedal63, low-speed87, response86, turning61, radius64, direct corners32, consistency529, normal tracks20, Over and under7, legacy laps6, handling88, rewind61 and parser1326 all pass. Native Compatibility77 and desktop Mobile77 pass. Backend72 pass with the same two historical exclusions and six warnings. Import and independent canonical verification pass. Counts fall where intentionally changed fields are removed from historical equality checks; the new focused test explicitly checks the final balance.

Native review images include [powered slide](evidence/electric-slide-access-2026-10-27/native-compatibility/power-slide.png), [race](evidence/electric-slide-access-2026-10-27/native-compatibility/race.png) and matching [desktop Mobile slide](evidence/electric-slide-access-2026-10-27/native-mobile/power-slide.png). Hitches remain visible in diagnostic logs; no frame-time or phone-performance claim is made.

## Retained trials and contract updates

Initial scale 0.20 caused excessive angle or lost too much acceleration in several moderate-pedal tight turns. Scale0.25 still missed the explicit acceleration floor. Scale0.28 plus reduced slide drive loss passes. New test drafts initially overconstrained standstill onset/dwell and tiny grip activation; final checks require a real threshold crossing, at least half a second of sliding and lower grip than the non-sliding old tune. Angle, speed, symmetry, recovery and exact-replay guards remain explicit.

The unfaded powered tune failed two original top-speed radius checks in each of turning and response; the implementation's continuous high-speed fade fixes them. Those checks retain their original 10% tighter radius and completion bounds. A character-test draft required an arbitrary 8° minimum even during the new fast-speed fade; its replacement requires at least 1.5× the actual preceding tune's slip at every tested speed. Original logs/metrics are retained under the evidence root and `before-speed-fade/`.

Historical 8° power-slide ceilings and 95% same-time power-turn speed floors deliberately change to bounded deliberate slides (<24° in retained suites, <26° across the expanded matrix) with >=78% retained speed and positive acceleration. Light-pedal <8°, initial launch <8°/5° heading, original steering/corner alignment, exact replay, zero-speed/D/R, other-car defaults and identity protections remain. New explicit stopping windows are 1.25–1.4 s / 12–14 m from72 and 3.3–3.6 s / 85–95 m from190. The owner requested both behavior changes; no unrelated failed invariant is removed.

The first backend run had 71 passes and one setup import error while a concurrently edited `studio_usage` module was unavailable. The module subsequently appeared without changes by this task; the final identical selection passes72. All244 artifacts in the two previous electric evidence directories retain their original hashes. Every new output has its own destination; historical baseline reads remain immutable.

## Scope and remaining acceptance

Runtime scope is the electric resource, two optional HandlingConfig fields/snapshot omissions and the powered lateral-response gate/fade. Supporting scope is tests, local canonical fixture, documentation and the review checkpoint. Compact resource/catalogue/input sources remain exact. Concurrent Garage, rendering, vehicle geometry, backend and documentation changes remain preserved and excluded from the checkpoint.

Reload/rebuild the client and roll out a matching verifier before online use of physics0.75. Owner keyboard/controller driving-feel acceptance remains, including power-slide initiation and braking on normal90° tracks. No physical-device attachment check or device test was performed. No APK, real purchase/authentication, owner-save mutation, deployment, root-index staging, commit, merge or owner-process restart was performed.
