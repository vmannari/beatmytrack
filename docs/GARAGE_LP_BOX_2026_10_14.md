# Flip through an authored LP box — 2026-10-14

Requirements LPB01 (box/sleeve flipping), LPB02 (remove personal-music capability), LPB03 (placeholder LPs for later composition), LP01/LP03/LP04/SND05/MUS35/G01/R01/Q01. This supersedes the initial grid/import/remove workflow in `GARAGE_RECORD_PLAYER_2026_10_14.md`.

The retained Records workbench now has one open wooden LP box. Mouse drag, finger swipe, wheel, arrow keys and Previous/Next move through the sleeves. Dragging follows the hand; release settles at the nearest sleeve, with a bounded 0.32s flip that tilts the outgoing cover forward to reveal the next. Rapid flips begin at the displayed pose; cancellation/hiding settles and releases pointer ownership. The browse position survives Garage submenu navigation within the session. The actual tabletop crate contains the same seven native sleeves and tilts them with the displayed UI motion. Car, viewport, room, camera/zoom, local cosmetics/condition, washing and existing reflections remain retained.

Exploration remains the only playable LP. Six original working-title placeholders have distinct vector covers and saved catalogue IDs: Open Road, After Hours, Golden Hour, Coastline, Night Drive and Workshop Sessions. Their control says **Music coming later** and cannot select a fake track. Browsing them leaves the current recording and music clock intact; the transport still stops/resumes Exploration and the volume remains locally saved. No new music is generated or artistically approved here; the owner intends to create it later. Racing/practice stay silent.

The file picker, Add/Remove actions, importing, external-file decoder and copied-file playback paths are removed. The catalogue accepts only authored assets. Normal local-record validation safely discards retired import metadata and resets obsolete/placeholder playback IDs to Exploration, preserving other preferences/PBs and all original/copied music files. It performs no music-file deletion. The catalogue/sleeve/cover cache is fixed at seven entries, with 256px mipmapped native vector artwork and no added viewport or network service. Original music assets/provenance remain unchanged.

Reviewed actual [Compatibility box](evidence/garage-lp-box-2026-10-14/gl_compatibility/lp-box-exploration-1280.png), [placeholder](evidence/garage-lp-box-2026-10-14/gl_compatibility/lp-box-placeholder-1280.png), [Mobile placeholder](evidence/garage-lp-box-2026-10-14/mobile/lp-box-placeholder-1280.png), and matching per-cover/960/1600 captures. [Actual sleeve-flip preview](evidence/garage-lp-box-2026-10-14/gl_compatibility/lp-box-flip.png) is a lossless 13-frame APNG made from pinned-engine renders, with endpoint review holds. Both-renderer raw frames and CRC/decompressed-pixel equality are recorded in `motion.json`; this is a motion review, not a frame-time measurement.

Actual checks on pinned Godot `4.7.2.stable.official.ed1daf0bf`:

| Check | Result |
|---|---|
| LP box, headless | 64 checks, zero failures |
| LP box, Compatibility / desktop Mobile | 93 / 93 checks, zero failures |
| Music-bus captures after browsing | Nonzero Exploration output; stopped output exactly zero after queued audio drains |
| Existing soundtrack lifecycle/settings/canonical suite | 1,158 checks, zero failures |
| Existing five-biome silence suite | 42 checks, zero failures |
| Existing native Garage selection/camera suite | 178 checks, zero failures |
| Full script parse | 760 scripts, zero failures |

LP checks exercise actual native mouse/touch/key events and arrow controls, intermediate UI/3D sleeve poses, bounds, all six unavailable releases, seven distinct mipmapped covers, no grid/file picker/private-music API, migration and preserved PB/source-file data, unchanged stream identity while browsing, stop/resume/focus, saved volume, retained camera/car/viewport, rapid navigation and hidden cleanup.

Actual entry points, with workspace-only APPDATA and per-run logs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-lp-box/run_check.ps1 -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-lp-box/run_check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-lp-box/run_check.ps1 -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-lp-box/run_check.ps1 -ScriptName test_soundtrack -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-lp-box/run_check.ps1 -ScriptName test_biome_music_off -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-lp-box/run_check.ps1 -ScriptName test_garage_carousel
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-lp-box/run_check.ps1 -ScriptName test_script_parse -Headless
python build/garage-lp-box/encode_motion.py
```

Initial attempts are retained: the test's script-metadata inspection called an instance API as static and was corrected; PowerShell's Python-input encoding replaced control glyphs with question marks, corrected directly in UTF-8 source after native visual inspection. Pillow was unavailable for the review encoder, so the existing PNG/APNG standard-library workflow was used without installing dependencies. Final runs preserve the behavior assertions; obsolete import tests were replaced for the owner's explicit superseding requirement. Native checks require Windows certificate-store access, allowed by automatic approval review.

Runtime: `game/soundtrack/record_library.gd`, `game/persistence/local_records.gd`, `game/ui/{garage_records_menu,garage_record_station,garage_lp_box,car_showroom,garage_page}.gd`. Test: `game/tests/test_garage_records.gd`. Records: this report, the historical report notice, `docs/music/STATE.md`, `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`. Supporting runner/encoder and isolated checkpoint live in `build/garage-lp-box`; native evidence, logs, ledger and scoped patch are under `docs/evidence/garage-lp-box-2026-10-14`. Concurrent settled-rectangle rendering fixes in Garage are preserved and excluded from this task's checkpoint; main branch/index and unrelated work remain intact.

Remaining acceptance: owner's flipping/appearance review and physical-phone touch/readability/frame pacing. No phone test, APK export/install, deployment, broader physics merge, new composition or general performance claim was performed.
