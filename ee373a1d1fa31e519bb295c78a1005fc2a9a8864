# Volt slow-speed steering — 2026-11-06

VSS01: The owner finds Volt too sensitive at very low speed. Electric-29 applies
the existing low-speed steering-angle scale at 0.75, down from 1.0. Full reduction
applies through 2 m/s (7.2 km/h), fading smoothly to the previous steering at
8 m/s (28.8 km/h). Input buildup/unwind rates, normal-speed lock, propulsion,
braking and power-slide parameters are unchanged. Shared simulation is unchanged.
The new car version and hash distinguish competitive contracts; the local backend
fixture has the new electric identity only. Deployment was not performed.

VSS02: Actual 0.2-second left/right, partial/full steering cases at +/-1,2,3 m/s
show heading ratios 0.692–0.764 versus the archived electric-28 configuration.
The 75 normal-speed step cases match exactly. Straight power/coast comparisons
and deterministic replay pass. The dedicated check passes 8512/0; retained final
Volt reference 10/0, handling 88/0, driving 72/0 and rewind 61/0 pass. Actual Game
loads electric-29 without an experimental selector. Over-and-under passes 7/0:
five ordered laps, 35891 inputs, zero contacts and exact replay. Five Storm tracks
pass 20/0: one ordered lap each, zero contacts and exact replay.
The final-reference test explicitly applies this approved correction to its Turn 5
reference; all remaining physical fields retain exact comparisons.

VSS03: Volt prepared bases, modules and Garage template are refreshed; the picture
pipeline and complete prepared-asset preflight run after identity generation.
See assets-before.json, assets-after.json, bake logs and preflight/commands.json.
This is a handling change, not a UI change; no new UI screenshot is required.

Commands: `python docs/evidence/volt-slow-steering-2026-11-06/run_check.py LABEL
res://tests/SCRIPT.gd` with the precise arguments in each receipt; preparation uses
`python docs/evidence/volt-slow-steering-2026-11-06/prepare_assets.py`.
Pinned Godot 4.7.2, crash-dialog wrapper, private profiles, empty backend URL.
The standard dev.ps1 attempt exited 1 with Access denied; the direct pinned runs
above passed. Certificate-store errors and ObjectDB/resource shutdown warnings are
retained. An initial PowerShell/Python quoting error made no source changes.

Limitations: automated checks cannot establish the owner's steering feel. Tablet
testing, installation and matching service rollout remain; no device query/test,
APK, backend request, owner-save/process change or main-index write occurred.
No merge or full historical physics-suite acceptance is claimed. Concurrent work
is preserved. task.patch is a private-Git binary checkpoint, checked in reverse
against the exact final files.
