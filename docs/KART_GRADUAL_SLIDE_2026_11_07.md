# Gradual kart sliding — 2026-11-07

KGS06 follow-up: Owner still cannot feel a change and confirms PC play. The tablet
loading deployment excluded these pending tunes, but that does not establish the
cause of this PC report. Read-only process inspection found Project Manager and
separate tests, with no identifiable running PC race; the exact build the owner
played remains unverified. Close/relaunch the PC game from the current project to
load the changed resource. No owner process was closed or save modified.

Kart-17 uses0.50 high-speed lateral response, retaining the98–140km/h envelope.
Actual powered corner entry peaks8.97degrees versus7.30 for Kart-16. Sustained
0.35/0.65/1.0 steering reaches8.513/7.740/6.639degrees at133.071/126.929/120km/h;
recovery remains317/333/350ms. The real full-lock test demonstrates why repeated
small top-speed tuning can feel subtle: the corner-speed cap reduces speed to120,
which also attenuates the speed-dependent slide. Controlled100/120/140 samples
now show1.478/2.627/4.790degrees, with only0.006 added degrees at100. These are
diagnostics, not proof of the owner's perceived feel.

The stronger0.40 candidate is rejected: it peaks11.32degrees and passes bounded
slip checks but fails the unchanged turn-speed test18/1. The half-steer turn is
126.369km/h versus126.176 for the full-steer uncapped control. Nearby0.44/0.45
candidates also invert that comparison. Final0.50 passes the original18/0 without
editing its assertions. The final dedicated test6377/0 also compares real entry
and sustained turns against retained Kart-16, with the previous10-degree peak
ceiling retained. Logs for the rejected candidate are archived under
`build/kart-noticeable-slide/rejected-0.4/`.

Files: `game/resources/cars/kart.tres`, extended fast-slide test and saved prior
fixture, existing kart/final/winter/capture identity checks, both local fixture
manifests, scoped prepared assets/provenance and the comparison probe. Kart-17
hash is`9e51b0c5d8ee7bb052ac3ff10f8efb2466d829b87c6b16802c557979b2ab7548`.
A concurrent scenery script introduced a PackedByteArray.sha256_text parse error
during verification. `game/track/scenery_mesh_lods.gd` now hashes its original bytes
through HashingContext instead, preserving the surrounding concurrent feature.
Initial assertion summaries accompanied by script errors are not accepted as
passing integration runs. Final integration runs explicitly reject script errors.

Commands/logs under `build/kart-noticeable-slide/`: `python run_checks.py
probe_kart_slide_response`; the same runner with`test_kart_fast_slide
test_kart_turn_speed`; `python prepare_assets.py`; `python run_final_checks.py
test_kart_final_handling test_driving test_rewind test_kart_fast_slide_tracks`.
Each runner path is relative to this output directory; invoke it from the repo
root with the full`build/kart-noticeable-slide/` prefix. Pinned offline Godot,
private profiles, empty backend URL. No device test, APK, live/backend request or
deployment; owner feel remains unverified. Earlier proposals below are historical.

KGS06 final: dedicated6377/0 and unchanged turn-speed18/0; fresh final actual
Game3613/0, driving72/0, rewind61/0 and three five-lap zero-contact full/resumed
replays15/0, with zero script errors. Sixty kart modules refreshed; scoped bake
sources stable, prepared468/1925/0 and five-picture157-source checks pass.
`build/kart-noticeable-slide/task-source.patch` is the incremental source-only
checkpoint, checked in reverse. Initial scenery parser failures, rejected0.40
speed regression and one command-quoting failure are retained. Main index and
concurrent work remain preserved. No claim that the running owner PC build was
updated or that the new feel has been accepted.

KGS05 follow-up: Owner requests double the slide. Kart-16 lowers top-speed lateral
response0.75to0.60 while retaining the98–140km/h envelope. The dedicated test now
compares against saved Kart-15 (`game/tests/fixtures/kart_double_slide_before.tres`):
at140, added slip versus the original Kart-12 is1.822degrees, previously0.912
(1.998x). At100 added slip remains0.005degrees; at120 it is0.640. The matched-speed
test's absolute slip at100/120/140 is1.477/2.409/3.883degrees. Hard-turn peak is7.298
degrees; recovery remains<=350ms. Dedicated6372/0 passes. Its hard-turn ceiling is
explicitly updated from7 to10degrees for the owner's stronger request, while
speed progression, low-speed controls, recovery and replay requirements remain.

Runtime change is limited to `game/resources/cars/kart.tres`. Identity checks,
both local fixture manifests and prepared assets follow Kart-16, hash
`c12f17cdbef0c3f843eed4ece60157e6f98434df2277192e6dcfd3332166e4ec`.
Commands/logs: `python build/kart-double-slide/run_checks.py test_kart_fast_slide`;
the same runner with `test_kart_turn_speed test_kart_final_handling test_driving
test_rewind test_kart_fast_slide_tracks`; `python
build/kart-double-slide/prepare_assets.py`. The private offline runner and scoped
asset procedure remain as described for KGS04. No device test, APK or deployment
is performed; owner feel remains unverified. Earlier sections retain historical
measurements for the preceding proposals.

KGS05 final validation: turn18/0, final/actual Game3613/0, driving72/0, rewind61/0
and track15/0 pass (three five-lap zero-contact races, exact full/resumed replay).
Sixty kart modules are rebuilt; stable source receipts,468-resource1925/0 and
five-picture157-source preflight pass. The historical turn-speed cleanup warning
is retained. `build/kart-double-slide/task-source.patch` is the incremental
source-only checkpoint, checked in reverse against final files; binary assets
remain in the workspace. Concurrent changes and the main index are preserved.

KGS04 follow-up: Owner asks for a slightly stronger slide. Kart-15 changes only
the top-speed lateral-response scale from0.80 to0.75 plus the handling identity;
the98–140km/h smooth progression is unchanged. Controlled-speed slip at100/120/140
is1.475/2.132/2.974degrees, compared with1.474/2.051/2.746 for Kart-14. Added slip at
100 remains0.003degrees. Actual hard-turn peak rises from5.254 to5.644degrees;
recovery stays within350ms. Dedicated6365/0, turn18/0, final/actual Game3613/0,
driving72/0 and rewind61/0 pass. The prior measurements below describe Kart-14.

Current commands/logs: `python build/kart-slide-strength/run_checks.py
test_kart_fast_slide test_kart_turn_speed test_kart_final_handling test_driving
test_rewind test_kart_fast_slide_tracks`; `python
build/kart-slide-strength/prepare_assets.py` performs scoped kart baking and full
preflight. Existing identity assertions and both local fixture manifests use
Kart-15/hash`4c7ab214529fcf699f5a1020b2b626d55630899eaa5cf451027cfaa72898300d`.
Runtime change is in`game/resources/cars/kart.tres`; shared simulation is unchanged
in this follow-up. No device test, APK, backend request/deployment or main-index
write. Owner driving feel remains unverified.

KGS04 validation finishes with track15/0 (three five-lap races, zero contacts,
exact full/resumed replay), sixty kart modules rebuilt, stable source receipts,
468 prepared resources/1925 checks/zero failures, and five pictures with157 current
source hashes. The incremental source-only checkpoint is
`build/kart-slide-strength/task-source.patch`; generated resources remain in the
workspace. Known historical turn-speed resource-exit warning remains.

KGS01: Owner clarifies that sliding should be almost absent at 100 km/h and grow
gradually with speed without becoming excessive at full speed. Kart-14 replaces
the initial Kart-13 proposal: lateral response now fades from its original value
at 98 km/h to 80% at 140 km/h. The smoothstep curve has zero slope at both ends.
The previous proposal reached 65% response at 126 km/h. No yaw force is added;
low-speed handling, tire capacity and straight-line speed remain unchanged.

KGS02: Controlled-speed tests run the real simulation, regulating only velocity
magnitude after each step to compare identical speeds with 0.12 steering. These
are diagnostic corner samples, not a claim that full-lock racing holds 140 km/h.

| Speed (km/h) | Slip (degrees) | Extra slip versus original tune |
| --- | --- | --- |
| 100 | 1.474 | 0.003 |
| 110 | 1.709 | 0.089 |
| 120 | 2.051 | 0.282 |
| 130 | 2.443 | 0.526 |
| 140 | 2.746 | 0.684 |

All eleven samples from 90 to 140 km/h increase monotonically; the additional
slide also increases monotonically. Actual full-power ten-second turns at
0.35/0.65/1.0 steering settle at 5.162/5.248/5.181 degrees, with a maximum peak of
5.254 degrees (previous proposal 7.363). Recovery remains 317/333/350 ms.
Dedicated speed/symmetry/replay/straight/low-speed checks pass 6365/0.

KGS03: Retained turn-speed18/0, low-speed steering zero failures, winter55/0,
final handling/actual Game3613/0, handling88/0, driving72/0 and rewind61/0 pass.
The three track checks pass15/0: five ordered laps each on Over and under, Storm
Freight and Storm Quarry, zero contacts, exact full and resumed replay. The runs
take25656/35956/39887 ticks respectively. Tests emit the known historical
turn-speed/low-speed resource cleanup warnings; no script errors occur.

Files: the response envelope in `game/vehicle/vehicle_simulation.gd`, its property
comment in `handling_config.gd`, `game/resources/cars/kart.tres`, the extended
`game/tests/test_kart_fast_slide.gd`, existing kart/final/winter/capture identity
assertions, both kart manifests in `backend/tests/fixtures/load_trajectory.json`,
and dependent generated prepared resources/identities/provenance. The new hash is
`bf1067dbbb2d4b537cc91162684511b85d0e1073e90ac108cb8c61cf70850a1b`.

Commands and full logs are under `build/kart-gradual-slide/`:

- `python build/kart-gradual-slide/run_checks.py test_kart_fast_slide`
- `python build/kart-gradual-slide/run_checks.py test_kart_turn_speed test_kart_low_speed_steering test_kart_winter_grip test_kart_final_handling test_handling test_driving test_rewind test_kart_fast_slide_tracks`
- `python scripts/prepare_car_assets.py --output build/kart-gradual-slide/prepared-assets`

The asset pipeline passes with stable source receipts: 442 modules rebuilt,
468 prepared resources/1925 checks/zero failures, and five native pictures with
157 current source hashes. Pre-bake stale-resource/provenance failures are retained
as expected inputs to regeneration. The combined slide-task source checkpoint is
`build/kart-gradual-slide/task-source.patch`, checked in reverse against final
sources; generated binary assets remain in the workspace.

The runner uses the pinned Godot 4.7.2 console executable, the crash-dialog wrapper,
private APPDATA/LOCALAPPDATA and an empty backend URL. This follows the initial
task's standard `scripts/dev.ps1` attempt and passing normal-access rerun; direct
runs retain the known exit-resource warnings that make that wrapper reject
otherwise passing historical tests. No device test, APK export/install, owner-save
change, backend request or deployment was performed. Owner/tablet driving feel
and matching service rollout remain. Concurrent work and the main index remain
preserved; no merge was performed.
