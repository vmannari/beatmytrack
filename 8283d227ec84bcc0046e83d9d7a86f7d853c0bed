# Challenger marked surface joins — 2026-11-12

CHJ01 fixes the owner's four marked areas: the front wing/corner, upper front
door join, quarter-panel shoulder below the C-pillar, and rear corner. CHJ02
updates the native and prepared presentation assets and verifies the result.

The earlier individual patches retained component gutters and folded corner
triangles. Fitting their normals alone left discontinuous geometry. Four local
radial charts now fair geometry and tangents together across the component
boundaries. Front corner, upper rear shoulder and rear corner triangles are
clipped at the repair boundary and replaced by continuous constrained skins.
Original crossings constrain the
new boundaries. Contour markings retain their shallow exterior offset.

The authored source changes are
[`scripts/challenger_panel_geometry.py`](../scripts/challenger_panel_geometry.py)
and [`scripts/prepare_challenger.py`](../scripts/prepare_challenger.py).
Conversion also refreshes the Challenger native meshes and their manifests;
the asset pipeline refreshes prepared bases, fitted modules, Garage scenes,
and pictures. The retained measured source art and licence remain in place.

Extra corner samples are balanced by fewer longitudinal samples on the broad
door skins, retaining the finer transverse profile and original boundary
constraints. The assembled stock car is **49,540 production / 83,935 full-tier
triangles**, below the established 50k/85k allocations and the preceding
49,985/84,753 totals. This is a geometry count, not a device-performance claim.
The factory bonnet, opaque glazing, wheel contacts, nose extension and 198 km/h
tune retain their existing controls.

| Check | Actual result |
| --- | --- |
| Marked surfaces, both sides and both tiers, 5 mm station spacing | 2,624 checks / 0 failures; original control 2,624 / 21 |
| Existing source bonnet/side profile, door joins and fender normals | 884 / 0 |
| Existing rear glazing, backing and tail trim | 784 / 0 |
| Stock geometry and unchanged normal Rally control | 27 / 0 |
| Fitted part choices | 316 / 0 |
| Prepared modules and ghost comparison | 1,438 / 0 |
| Prepared physics, replay and handling profile | 3,677 / 0 |
| Washing / driving / production script parsing | 1,655 / 0; 72 / 0; 554 / 0 |
| Prepared opacity, contacts and budgets | 30 / 0 on each desktop renderer |
| Actual App Garage selection, reload and local race preparation | 13 / 0 on each desktop renderer |
| Coherent asset refresh | 434 stable source inputs, 10 final successful commands |
| Strict prepared resources / native picture provenance | 551 resources, 2,267 / 0; six images, 157 source hashes |

Native prepared views: [white side](evidence/challenger-surface-joins-2026-11-12/garage-final/gl_compatibility/white-side.png),
[white front](evidence/challenger-surface-joins-2026-11-12/garage-final/gl_compatibility/white-front.png),
[white rear](evidence/challenger-surface-joins-2026-11-12/garage-final/gl_compatibility/white-rear.png),
and [Vulkan side](evidence/challenger-surface-joins-2026-11-12/garage-final/mobile/white-side.png).
The [original side](evidence/challenger-surface-joins-2026-11-12/garage-before/gl_compatibility/white-side.png)
uses the retained task-start paint mesh in the same showroom and camera.
Final measurements, commands and native hashes are in
[the acceptance receipt](evidence/challenger-surface-joins-2026-11-12/final-acceptance.json).

The repair uses the existing Blender 4.5.15 conversion and pinned Godot 4.7.2
engine. Every check uses private saves and an empty backend URL. Exact commands,
exit codes and elapsed times are retained alongside each log in
[`evidence/challenger-surface-joins-2026-11-12`](evidence/challenger-surface-joins-2026-11-12/).
Entry points are `run_preparation.py`, `final_checks.py`, `guarded_assets.py`,
`prepared_checks.py`, and `checkpoint.py`. The initial complete refresh
used 15 commands. After the final upper-shoulder refinement,
`guarded_assets_final.py` refreshes the affected vehicle with 10 commands and
retains the other catalogue pictures. Both refreshes use the full input fence
and strict shared preflights.

Both desktop renderers run on the RTX 3090; Vulkan Mobile here is a desktop
renderer, not a tablet test. The App test prepares a local five-lap race; it is
not a manually driven five-lap session. An initial OpenGL App run emitted a
shutdown diagnostic for two ObjectDB instances and one resource still in use,
retained in `app-gl-initial.log`. The final OpenGL App run completes without
that diagnostic; the final Vulkan App run emits the same shutdown diagnostic
after all 13 assertions pass. Clean test-process teardown is not claimed.
A final Vulkan probe attempt at eight settle frames recorded
89 front-view pixel changes. The failure, images and pixel survey are
retained in `opaque-initial-mobile-finding` and `probe-difference.log`. The
local qualification harness increases settling to 32 frames and keeps every
original assertion, including exact byte equality of the unchanged view and
the bright-probe comparison. Vulkan then passes all 30 assertions. The
production test and all opacity materials remain unchanged.

The main index, all eight captured car configurations and the two captured
canonical handling/simulation sources remain byte-exact. Of 24 immediate
pre-refresh unrelated PNG controls, 23 remain byte-exact; the controls also
observe a concurrent update to `game/assets/news/vehicles/forklift.png`. This
update is preserved. The photography commands here write only the Super rally
news image; no Forklift source edit was authored. The six catalogue images pass
their strict native provenance check. These controls are recorded separately
from the source fence.

The initial broad front probe crossed the headlamp/nose return, and the rear
probe crossed the separate lamp opening. The corrected body-only profiles are
retained in `joins.gd`. The 10 mm trial and subsequent 5 mm scan retain the same
absolute gap, reflection and geometry bounds; the denser scan resolves the
curved front return more accurately. Failed drafts and coarse-probe receipts
remain recorded. The unchanged existing 884-check gate passes independently.
The final Vulkan review exposed a remaining upper shoulder kink; the narrow
upper strip was retopologised and added to the surface scan. Its interior edges
are paired exactly. An exact-edge ray miss is resolved by a 10 micrometre
longitudinal probe, with the independent edge-pairing audit rejecting real
openings. The scan excludes the separate rear-quarter window opening.
A conversion whose inputs changed while running was rejected by the source
fence; only the subsequent stable conversion was accepted. A reused historical
panel check initially wrote its old output path; that receipt was restored from
its original retained log and subsequent runs write into this task's folder.

The two-file source patch applies and reverses byte-exactly in a private source
checkpoint, with whitespace checks enabled. A broad tracker `git diff --check`
also reports historical repeated-CR whitespace in AGENTS/DEVELOPMENT_STATUS;
the scoped source patch passes and those historical entries are retained.
No main-index write, owner-save or owner-process change, device query/test,
APK, backend request or deployment is
part of this task. Fresh owner appearance acceptance and device qualification
remain.

Task build output, private profiles, the private source checkpoint and redundant
draft PNGs were removed after their receipts were saved. The required
`scripts/clean_build.ps1 -Apply` run completed successfully; shared build output
remains 21.71 GiB because recent/protected/locked entries are retained by policy.
The final native hashes, source hashes and protected controls were verified
again after cleanup.
