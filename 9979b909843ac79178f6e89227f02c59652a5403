# Hover Slide 5.1 locked — 2026-11-08

The owner selects Slide 5.1 as Hover's normal controls. `hovercraft-5` promotes
the complete selected configuration: steering rate 19, yaw cap 2.7, lateral
response 0.28 and powered lateral damping 0.9. All other handling fields match
the former preset. The normal profile name stays Hovercraft. Hover is removed
from the local experiment selector; stale preset indices resolve to the normal
configuration. Pickup experiments remain available as before.

The original `hovercraft-4` resource and six-choice preset implementation are
retained under `game/tests/fixtures/hover_slide51_reference/`. The earlier
Slide 5 variants and UFO regression explicitly use historical references.
The actual race capture checks the new production version. Both local Hover
manifest occurrences in the trajectory fixture use the new version and hash
`d596a12c9a654391f7ae881662162595170a6c2ef6418eb1ec2dd1b36b4db9cc`.

Pinned Godot 4.7.2, private APPDATA/LOCALAPPDATA and an empty backend URL:

- `python build/hover-slide51/checks.py test_hover_slide51_locked test_hover_slide5_variants test_handling_test_selector test_handling_test_presets test_driving test_rewind test_hovercraft_ufo test_handling`
  gives 45,236/0 for exact production-versus-selected-preset states across
  five initial speeds, five steering inputs and three throttle levels, with
  braking, deterministic replay and restored replay. Historical Slide 5
  variants give 99/0, selector 12/0, remaining presets zero failures,
  driving 72/0, rewind 61/0 and handling 88/0.
- `python build/hover-slide51/checks.py test_hover_slide_variants test_hovercraft_ufo`
  gives historical five-choice variants 83/0. The frozen UFO regression retains
  92 checks/1 failure: the independent historical-simulation comparison for
  current Kart-18. Its Hover-4 behavior and replay checks pass. The assertion
  remains intact and the failed receipt is retained.
- `python build/hover-slide51/native.py` runs the actual production Hover scene
  in Compatibility and desktop Mobile: 14/0 each, with four captures each for
  coasting turn, powered catch, correction and braking. These are presentation
  checks, not device or performance qualification. Compatibility reports
  58 objects/11 resources retained at exit; certificate-store and hitch
  diagnostics are retained in the logs.

The initial new-test invocation called a nonexistent VehicleState.restore
method and stalled; its receipt remains under `build/hover-slide51/`. The final
test uses the production RewindHistory snapshot/restore API and passes. Only
the exact owned initial test processes were stopped. No owner process changed.
The historical UFO report was restored from its tracked receipt after the
old runner wrote there; new historical runs write under this task's build
directory. No numerical assertion was relaxed.

`python scripts/prepare_car_assets.py --output build/hover-slide51/prepared-assets`
rebuilt 20 bases, 442 modules, five Garage cars, the header template and five
native catalogue pictures. Its initial preflight retained 806 stale-metadata
failures. Source receipts before/after were identical, but the final geometry
identity consistency assertion rejected this first run. A subsequent read-only
preflight isolated two metadata failures in the single unrelated reduced Volt
`body/volt_race.scn` module. `python build/hover-slide51/repair_one.py` rebaked
only that module through the unchanged original baker. Picture provenance
already passed five native images/155 current source hashes.

The final pipeline attempt encountered concurrent Super Rally implementation:
13 model/cache/catalogue source files changed, adding a sixth playable car.
Its preflight retained 468 resources/1931 checks/941 failures; this is a different
source configuration from the completed bakes. The second owned pipeline and
its child processes were stopped to avoid competing writes. All concurrent
sources remain. Whole current-tree prepared/export readiness is not claimed;
the asset pipeline must run after that concurrent work settles.

A fresh current-source Hover run still completed all 45,236 motion assertions
with the same handling hash but crashed during teardown (0xC0000005). The
test now pins the native-track class graph, following the existing driving
test harness. The same fresh selector run exposed the new Super Rally missing
from the test's old fixed no-selector list; the expectation now explicitly
limits experiments to the retained Pickup. Original failures remain logged.
The final current-source rerun passes 45,236 motion checks and 13 selector
checks with clean process exits. The task-only reverse patch check passes.

The source-only checkpoint is `build/hover-slide51/task-source.patch`; generated
resources and identity metadata remain separate. Raw test logs, initial failures,
native captures and bake receipts are retained under `build/hover-slide51/`.

Reload/rebuild is required. Matching online handling contracts and owner/device
feel acceptance remain. No device query/test, APK, owner-save edit, live/backend
request, deployment or main-index operation. Concurrent source work is preserved.
