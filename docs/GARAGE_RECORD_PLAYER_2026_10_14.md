# Garage LP player and local record collection — 2026-10-14

The later owner clarification supersedes the grid/import collection described below. The current UI uses an authored LP box with six future-music placeholders and no personal-music import. See `GARAGE_LP_BOX_2026_10_14.md`; this report preserves the initial implementation evidence.

Requirements LP01 (native player), LP02 (selectable LP collection), LP03 (saved background-music selection), LP04 (bounded local assets and preserved behavior), MUS35/MUS36/SND05/G01/R01/Q01.

Garage has a vinyl icon in both its car browser and selected-car rail. It moves the retained camera to a listening console beneath the left poster. The original cabinet, matched two-way speakers, 57cm turntable plinth, platter, 30cm grooved vinyl, spindle, pivot/counterweight/bent tonearm/cartridge and open cover use native geometry. The LP turns at 33⅓ RPM during audible menu playback and stops while muted, stopped, hidden or suspended. Returning restores the retained car view; camera, car, viewport, condition, parts, washing and reflections remain under the existing Garage lifecycle.

The right workbench shows actual LP sleeves, the current selection, volume and Play/Stop. Exploration is the initial recording. **Add an LP** imports an owner-chosen MP3, OGG Vorbis or PCM WAV; it copies exact source bytes into local game data and creates a selectable sleeve. Selection and stop state apply to menus/results and survive reopening/restart. Removing an imported LP removes its game copy and entry; the source stays intact. The built-in Exploration LP remains available. No rejected score candidate was restored, no new music generated, and no remote media or service was added. The optional scope/content questions received no answer during implementation; existing menu/results playback and silent racing were retained.

Custom collection bounds: twelve imports, 24MiB per file, 96MiB total owned copies/staging files, ten minutes per recording; thirteen mipmapped 256px cover textures including Exploration. Saved metadata contains bounded titles, content hashes and allowlisted formats, deriving paths inside `user://lp_records`. Atomic metadata commit failures roll back and release new copies. Importing an existing recording reselects it without duplicates and restores a missing copy. One existing music voice switches with a 120ms fade out and 250ms fade in; at most current/pending audio resources are retained. Existing volumes, interface/vehicle sounds, focus handling, race/practice silence and scoring remain. Custom full-file loops are not newly edited musical seams.

Original vector cover artwork matches the native sleeves; no raster generation or external artwork was used. Exploration's existing source/export/provenance and licensing uncertainty remain unchanged. Imported recordings belong to the owner's local collection and are not shipped source assets. Test recordings/imports stay in isolated workspace user data.

Inspected actual [Compatibility player](evidence/garage-record-player-2026-10-14/gl_compatibility/record-player-default.png), [Mobile player](evidence/garage-record-player-2026-10-14/mobile/record-player-default.png), three-width populated collection captures, and garage overview. Populated review captures include clearly named test imports; the default shipping view contains Exploration and Add an LP.

Actual verification on pinned Godot `4.7.2.stable.official.ed1daf0bf`:

| Check | Result |
|---|---|
| LP workflow, headless | 33 checks, zero failures |
| LP workflow, Compatibility / desktop Mobile | 42 / 42 checks, zero failures |
| Recorded Music-bus output | Selected LP peak 0.018005 / 0.017883; stopped output exactly zero after the queued block drains |
| Existing soundtrack suite, headless | 1,158 checks, zero failures |
| Existing five-biome silence suite, headless | 42 checks, zero failures |
| Existing native Garage carousel/selection/camera suite | 178 checks, zero failures |
| Full project script parse | 749 scripts, zero failures |

Actual entry points (runner relocates APPDATA to workspace-only test data and preserves each log):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-record-player/run_check.ps1 -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-record-player/run_check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-record-player/run_check.ps1 -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-record-player/run_check.ps1 -ScriptName test_soundtrack -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-record-player/run_check.ps1 -ScriptName test_biome_music_off -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-record-player/run_check.ps1 -ScriptName test_garage_carousel
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-record-player/run_check.ps1 -ScriptName test_script_parse -Headless
```

Initial failures are retained: restricted certificate-store access (automatic approval review allowed native checks); an incorrect helper argument; capture timing shorter than the camera tween; physical-window comparison against logical canvas dimensions; pause-property assertions without a headless decoder; queued audio captured immediately after stop; and a Mobile fixture focus event preceding the manual stream check. Corrected fixtures retain real selection/audio/silence/fit/camera assertions. The existing soundtrack Settings fixture initially ran before asynchronous app startup, yielding stale-page settings failures and detached-tree teardown; it now waits for `startup_complete`, with every assertion preserved, and passes all 1,158 checks.

Runtime files: `game/soundtrack/audio_world.gd`, new `record_library.gd`, `game/persistence/local_records.gd`, `game/ui/{garage_page,garage_environment,car_showroom,garage_mode_icons}.gd`, new `garage_records_menu.gd`, `garage_record_station.gd`, `garage_vinyl.gdshader`. Tests: new `test_garage_records.gd` and the startup wait in `test_soundtrack.gd`. Records: this report, `docs/music/STATE.md`, `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`. Concurrent room-thumbnail/reflection and wash-effect changes are preserved and excluded from this task's checkpoint.

Evidence/logs and task-only Git checkpoint ledger/patch: `docs/evidence/garage-record-player-2026-10-14`; isolated checkpoint repository: `build/garage-record-player/checkpoint-repo`. Main branch/index and unrelated workspace edits are preserved. Native loading/loop APIs were checked against Godot's [runtime audio-loading documentation](https://docs.godotengine.org/en/stable/tutorials/io/runtime_file_loading_and_saving.html) and [FileDialog documentation](https://docs.godotengine.org/en/stable/classes/class_filedialog.html), then exercised on the pinned engine.

Remaining acceptance: owner appearance/music-collection review and physical-phone file picker, playback, readability and performance. No phone test, APK export/install, deployment, general phone performance claim or new musical-quality approval was performed.
