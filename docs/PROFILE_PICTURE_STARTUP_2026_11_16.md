# Profile and Garage picture startup - 2026-11-16

PCS01: investigate the slow car picture next to the profile at startup. PCS02:
allow existing pictures to load before optional startup/menu work finishes.
PCS03: verify the Garage carousel consumes the same pictures.

Stock pictures ship as assets. Customised pictures already persist as validated
512 x 288 PNGs beneath each records profile's `header_appearance_icons` directory.
The delay found here is that both PNG reads and native picture generation used
`_header_car_work_allowed`, which waits for `startup_complete`, the end of account
restoration and unrelated cloud/menu work. An existing disk picture could wait
behind those gates despite needing no new car renderer.

App now supplies a separate read policy. Existing PNGs can read and publish during
startup/account restoration and ordinary menu-data loading. Foreground, active-game,
race-loading and feature-loading restrictions remain. Captures and completed capture
writes retain their original policy. Standalone consumers without the new callback
inherit the original `allowed` policy. Current owner/appearance/visual-revision keys,
PNG validation, selected-car priority, single worker, fourteen-entry bounds and
capture eligibility remain unchanged.

`garage_shared_pictures.gd` already delegates to `header_car_icons.gd`; no carousel
implementation change was needed. Both widgets receive the same texture object.

Changed runtime files: `game/core/app.gd` (callback and read policy) and
`game/ui/header_car_appearance_cache.gd` (separate dispatch/publication eligibility).
The regression is `game/tests/test_profile_picture_startup.gd`, run by
`scripts/verify_profile_picture_startup.py`. It uses explicitly synthetic, correctly
keyed private PNG fixtures to test scheduling and exact decoded pixels independently
of concurrent model authoring. It exercises the real App policy callbacks, real
profile widget, Garage cached-thumbnail widgets and shared-picture adapter.

Results:

| Check | Actual result |
|---|---|
| Focused desktop Compatibility | 16 checks, 0 failures; 2 disk hits, 0 captures, 0 carousel renders |
| Focused desktop Mobile/Vulkan | 16 checks, 0 failures; 2 disk hits, 0 captures, 0 carousel renders |
| Former combined read gate, each renderer | 16 checks, exactly 1 expected failure: pictures do not restore while startup/menu-data work remains blocked; they restore once that gate opens |
| Existing equipped-picture recovery, Compatibility | 45 checks, 0 failures; original two-object/one-resource shutdown diagnostic retained |
| Actual separate-App restart, initial Compatibility run | Seed 14/0, history retention 7/0, restore 24/0; exact PNG/pixel hashes, 2 disk hits, 0 captures/worlds; shared profile/carousel textures |
| Final production parser | 582 scripts, 0 failures |

The initial restart run temporarily included three early-read checks in the existing
restart fixture. Subsequent foreground/loading checks were consolidated into the
new focused fixture; the existing restart test is restored exactly to its task-start
source. The final focused comparison proves the old scheduling failure independently.
Its five-second deadline is an assertion window, not a phone latency measurement.

The initial full Mobile seed completed 14 checks with no assertion failures, then
stalled during process exit. Its owned PID was stopped after 80.812 seconds. Full
Mobile restart qualification is not claimed. Subsequent cross-process controls on
both renderers correctly rejected changed visual keys while other work regenerated
`build_identity.gd`. The unchanged-key gate was retained; no stale PNG was relabelled
or published. The first manual control also used a different path spelling; its
corrected-path repeat still rejected the changing visual revision. The final focused
tests use one process per case, with its own valid in-process key and private files.
An initial focused fixture parse error used App's local `RaceLoading` name without
importing it; the fixture now loads the class explicitly. These attempts remain in
the command logs.

Relevant visual/model changes still invalidate old pictures. Missing, corrupt or
obsolete PNGs require fresh rendering after the menu is ready. This change removes
an unnecessary cache-hit wait; it does not guarantee an immediate picture after
every development rebuild. No appearance, model, live Garage, save schema or cache
identity was authored by this task.

Actual commands:

```powershell
python scripts/verify_profile_picture_startup.py gl_compatibility
python scripts/verify_profile_picture_startup.py mobile
python scripts/verify_car_picture_restart.py gl_compatibility
python scripts/verify_car_picture_restart.py mobile
python scripts/run_shared_car_pictures.py gl_compatibility-profile-picture-startup-equipped res://tests/test_header_equipped_cache.gd --direct
python scripts/run_shared_car_pictures.py headless-profile-picture-startup-final-parse res://tests/check_model_refinement_parse.gd --direct
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Focused comparisons: [Compatibility](evidence/profile-picture-startup-2026-11-16/gl_compatibility/b8846013b1/report.json),
[desktop Mobile](evidence/profile-picture-startup-2026-11-16/mobile/d74b070c52/report.json).
Actual initial restart: [report](evidence/car-picture-restart-cache-2026-11-15/gl_compatibility/5503cf3604/summary.json),
[native Garage/profile view](evidence/car-picture-restart-cache-2026-11-15/gl_compatibility/5503cf3604/restore/pictures-restore.png).

The source-only private Git checkpoint excludes concurrent App editor-view changes
and all generated identities/assets. Its patch is checked byte-exact in both
directions without using the shared index. Standard build retention applies.
Reload is needed. Owner startup/appearance acceptance and physical-device testing
remain; no phone/device query or test, export, backend deployment, owner-save edit
or owner-process action was performed.
