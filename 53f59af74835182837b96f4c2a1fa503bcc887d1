# Superwash cleaning follows the brushes — 2026-11-07

SBC01: The Garage Super Wash button starts the existing 3.6-second machine without resetting the dirty car. Its actual nose-to-tail brush position progressively cleans both persistent deposit masks across the car, with a soft trailing edge. Panels ahead retain their dirt and earlier manual strokes. The same car/body coordinate transform keeps the cleaning aligned when the pedestal turns. Only completion clears all deposits, aged grime and hidden voxels and restores clean original materials. This supersedes the instantaneous cleaning retained by SWA01/SWA02.

SBC02: Interruption by manual washing, section navigation or hiding retains and saves the portion already cleaned. A repeated button press leaves the active pass running. Newer externally saved wear cancels a stale pass. A clean car remains exact during repeated/cancelled passes. Paint, equipped parts, other cars, the machine geometry, duration and fixed spray pool are preserved. Cleaning uses existing local masks and persistence; it adds no shader, asset dependency, backend operation or canonical simulation change.

Changed runtime files:

- `game/ui/garage_super_wash.gd`: emits the actual brush position and completion; updates both existing wash masks monotonically behind the brush.
- `game/ui/car_showroom.gd`: converts the brush position to the weathering frame, saves cancellation through the existing signal and performs the complete reset on completion.
- `game/ui/garage_page.gd`: starts without instant cleaning, ignores repeat presses and cancels stale passes when newer wear arrives.

SBCQ01 covers the real Garage controls and all five active cars. `test_super_wash_animation.gd` checks unchanged start, fully cleaned masks behind / exact masks ahead of the actual brush, existing strokes, frame-size independence, partial-save/reload, repeated presses, newer-wear cancellation, paint/parts, rig reuse/cleanup and idle drawing. `test_super_wash.gd` retains its complete deposit/voxel/local-save/layout assertions after the machine finishes; its former immediate-clean expectations are updated to the owner's requested timing.

Native captures: [Compact before](evidence/super-wash-brush-cleaning-2026-11-07/gl_compatibility/compact-dirty.png), [Compact halfway](evidence/super-wash-brush-cleaning-2026-11-07/gl_compatibility/compact-middle.png), [Forklift halfway](evidence/super-wash-brush-cleaning-2026-11-07/mobile/forklift-middle.png). The evidence directory contains four stages for every car on both desktop renderers. Captures are native game renders, not device or performance measurements.

Actual validation with pinned Godot 4.7.2:

| Check | Result |
| --- | --- |
| Final brush cleaning, native Compatibility | 150 checks, 0 failures |
| Final brush cleaning, native desktop Mobile/Vulkan | 150 checks, 0 failures |
| Final brush cleaning, headless | 130 checks, 0 failures; certificate-store diagnostic retained |
| Complete clean/save/layout, native Compatibility | 268 checks, 0 failures |
| Complete clean/save/layout, intermediate headless | 256 checks, 0 failures; certificate-store diagnostic retained |
| Retained manual hose | 81 checks, 0 failures; certificate-store diagnostic retained |
| Prepared car asset preflight | 468 resources, 1925 checks, 0 failures |
| Native preview provenance | Five exact photographs, 156 current source hashes; active PNGs byte-exact to before |
| Scoped checkpoint | Nine files; forward/reverse/content checks pass |

All final native runs exit 0 without matched engine errors. The guarded asset pipeline changed no monitored sources during its run and required only the five photograph captures/provenance refresh; existing car scenes/modules remain valid. Validation receipts and the checked source patch are recorded in [report.json](evidence/super-wash-brush-cleaning-2026-11-07/report.json). Commands run from the repository root:

```powershell
python docs/evidence/super-wash-brush-cleaning-2026-11-07/run.py --mode gl_compatibility
python docs/evidence/super-wash-brush-cleaning-2026-11-07/run.py --direct --mode mobile
python docs/evidence/super-wash-brush-cleaning-2026-11-07/run.py --direct
python docs/evidence/super-wash-brush-cleaning-2026-11-07/run.py --direct --mode gl_compatibility --test test_super_wash
python docs/evidence/super-wash-brush-cleaning-2026-11-07/run.py --direct --test test_garage_hose
python scripts/run_no_crash_dialog.py -- python scripts/prepare_car_assets.py --output docs/evidence/super-wash-brush-cleaning-2026-11-07/prepared
python docs/evidence/super-wash-brush-cleaning-2026-11-07/checkpoint.py
git diff --check -- game/ui/car_showroom.gd game/ui/garage_page.gd game/ui/garage_super_wash.gd game/tests/test_super_wash.gd game/tests/test_super_wash_animation.gd
```

The first restricted standard-entry launch failed with certificate-store / Access denied errors. Direct headless checks pass their assertions while retaining the certificate-store diagnostic. Approved native launches use the pinned Godot 4.7.2, a private offline profile and the required crash-dialog wrapper. Initial intermediate checks and the initial preview preflight failure are retained: an early shared-weathering helper temporarily invalidated conservative geometry identity. The helper now belongs entirely to Garage; the shared weathering script is byte-exact to task start. The normal pipeline refreshes identity and native preview provenance through its existing guards. Generated build identity/project metadata are separate from authored changes. Concurrent work is preserved.

Reload/rebuild and owner appearance acceptance remain. No physical-device query or test, APK build/install, owner-save or owner-process change, live/backend request, deployment, staging or commit was performed. Desktop Mobile/Vulkan checks are not tablet tests.
