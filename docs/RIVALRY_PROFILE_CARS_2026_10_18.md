# Profile header and artificial-driver cars — 2026-10-18

RPP04: The player profile's ellipsis menu sits immediately left of X in the window header, on the same baseline with a six-unit gap and its own 52×52-unit touch target. The shared popup chrome accepts this optional header action and reserves title space for it; other windows retain their original header. Report and Block/Unblock still use the existing private safety actions.

RAC01: Every account marked `is_test_driver` that lacks a shared appearance gets a stable generated appearance for the event's car. Generation uses account ID, car ID and a versioned SHA-256 choice domain. It varies original paint palettes and subtle pigment shades, existing liveries, hood/roof stickers and supported Compact fitted parts. Other chassis retain supported stock parts. An account keeps the same appearance across refreshes, name changes, row order, weeks and process restarts for this generator/catalog version. Existing shared appearances remain authoritative. Ordinary human/development accounts do not acquire generated cosmetics. Blocked identities cannot regain cosmetics through generation.

These are client presentation records, derived automatically for existing, cached and future artificial-driver standings; they are not new backend account/car writes. The event still pins the chassis, handling and canonical race contract. The original server snapshot is not modified, per-track result rows remain lightweight, and scores, ghost/replay data and rewards are untouched. No new requests, worker jobs, file saves, subscriptions or backend deployment are needed for the generated looks. The podium and selected player profile use the same overall-row appearance.

RAC02: Screenshot review exposed clipped front geometry on wider fitted kits. The profile opts into fitting the unchanged showroom camera to the actual visible mesh bounds and current preview aspect ratio, with an eight-percent framing allowance. This changes only the profile FOV when its render target is resized/refreshed. Other uses of the shared car renderer retain their existing camera. Complete projected mesh bounds are checked for all five chassis.

Changed files: `game/ui/player_profile.gd`, `game/ui/popup_style.gd`, `game/ui/artificial_driver_appearance.gd`, `game/race/weekly_rivalry.gd`, `game/ui/rivalry_victory_car.gd`, and `game/tests/test_rivalry_player_profile.gd`, plus project notes and this report. The generator uses only the project's existing native cosmetic art and models; the palette/choice code adds no external asset.

Actual commands used the pinned Godot 4.7.2 repository entry point, with per-run `APPDATA` and `LOCALAPPDATA` directories under `build/rivalry-profile-cars-2026-10-18`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_rivalry_player_profile.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_rivalry_player_profile.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_rivalry_player_profile.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestApp -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_weekly_rivalry.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_rivalry_custom_cars.gd -CommandTimeoutSeconds 180
git diff --check -- game/ui/player_profile.gd game/ui/popup_style.gd game/race/weekly_rivalry.gd game/ui/rivalry_victory_car.gd game/tests/test_rivalry_player_profile.gd
```

Final focused results: **2176 headless / 2183 Compatibility / 2183 desktop Mobile checks, zero failures**. Coverage includes valid/stable/distinct generated combinations for 150 artificial drivers across each of all five car types; supported-part bounds; all 19 artificial members in the 20-person fixture; unchanged raw snapshots; human/shared/blocked behavior; profile/podium consistency; complete mesh framing; and the original profile/report/block/cursor/gesture checks. Header adjacency, non-overlap, touch size and viewport bounds pass at 960×540, 1280×720 and 1720×900. Original app **140**, Weekly Rivalry **1115**, existing shared-car **135**, and final parser **875 scripts** also pass. Desktop Mobile is the desktop Vulkan renderer, not a phone measurement.

Initial results are preserved separately: using fixed palettes without shade variation repeated a few Pickup/Formula combinations, producing two failures in the 2170/2177-check versions. Per-driver pigment variation fixed them without relaxing the distinctness assertion. Review of the rendered cars then found profile clipping. An initial fixed 1.3× framing allowance failed two full-mesh assertions (Compact prepared geometry and Pickup shadow proxy); fitting the actual mesh bounds corrected both. Earlier 2170/2177 passes preceded the six final framing checks. Tests ran with approved access outside the sandbox for Godot's Windows certificate store, using mock service data and isolated workspace test saves.

Reviewed captures:

- [Header menu beside X](evidence/rivalry-profile-cars-2026-10-18/gl_compatibility/player-options.png)
- [Generated artificial-driver podium cars](evidence/rivalry-profile-cars-2026-10-18/gl_compatibility/artificial-driver-podium.png)
- [Complete artificial-driver car in the profile](evidence/rivalry-profile-cars-2026-10-18/gl_compatibility/artificial-driver-profile.png)
- [Desktop Mobile profile](evidence/rivalry-profile-cars-2026-10-18/mobile/artificial-driver-profile.png)
- [Small viewport](evidence/rivalry-profile-cars-2026-10-18/gl_compatibility/profile-960x540.png)

G01/R01/Q01: Owner appearance/workflow acceptance and physical-device behavior remain. No phone attachment check/test, APK, backend change, live report/block, account mutation or deployment was performed. Concurrent workspace changes remain intact. Task preimages, initial captures, available test logs, final file hashes and a task-only patch are stored in `evidence/rivalry-profile-cars-2026-10-18`. Documentation preimages were saved before this task's notes were added; the checkpoint documentation bases also retain the concurrent device-loading notes so those changes are excluded from this patch.
