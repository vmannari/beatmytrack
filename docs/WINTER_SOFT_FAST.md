# Previous winter shape with faster wind — 2026-10-11

The owner rejected this combination and supplied a photographic blowing-snow reference. It is superseded by [reference-led powder flow](WINTER_REFERENCE_FLOW.md), while 24 m/s gusts, world lighting and bank contact are retained.

The owner explicitly prefers the shape before the grain revision and requests trying it with the increased speed. Revision 5 restores revision 3's soft world-lit bank-to-road flow exactly, while retaining the 6–24 m/s advection constants from revision 4. This supersedes the grain-only geometry and sparse-coverage preference; current owner visual acceptance remains pending.

Requirements WW17 (exact previous soft shape), WW18 (retain faster gusts), WW19 (readable world-integrated presentation and modest cost), plus V04/V05, G01/R01 and Q01. Physics, five laps, clocks, scoring, upload eligibility, audio, car geometry and camera are unchanged.

Changed files: `game/track/winter_snow_wind.gd`, `game/track/winter_snow_wind.gdshader`, `game/tests/test_winter_snow_wind.gd`, `docs/WINTER_SNOW_POWDER.md`, this document, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`. No core/game or asset change. Existing density/snow provenance remains intact.

The shader is byte-identical to the saved revision 3 shader under `docs/evidence/winter-snow-powder-2026-10-11/before`. The controller matches that saved revision after only changing its presentation version and speed constants/update. The parity check is saved in [restore-review.json](evidence/winter-soft-fast-2026-10-11/restore-review.json). It restores 81 ground layers/36 bank wisps, the original six-span bank-to-road profile, world density field, palette, opacity, scene lighting and shadows. Full shared gust speed remains exactly **24 m/s**, compared with the previous shape's 5.5 m/s. The 0.24 calm intensity floor gives 10.32 m/s with the retained constants. No new shape/colour/density tuning is introduced.

The allocation returns to **two draw calls and 594 maximum triangles**; the tested ten-bank scene adds 522 triangles. Desktop presentation observations were approximately 14–17 µs. Raw four-pass timing remains in [profile.json](evidence/winter-soft-fast-2026-10-11/profile.json); shared-machine timings are not a phone or precise incremental-cost claim.

Final focused outcomes: headless **33/0**, Compatibility capture/driving **44/0**, desktop Mobile/Vulkan actual draw/lifecycle **33/0**. Exact 24 m/s advection, pause/background/retry/finish/freeing, canonical snapshots, road cells and contact geometry remain checked. Opaque car-roof samples remain exact: static 741; moving 709/713/709, all with zero changed pixels. The paired lighting comparison remains lit/nonzero and unlit/zero. The broader soft coverage is logged for review; the former grain-only 8% cap is explicitly superseded by this owner-requested restoration. No canonical, roof, speed or lifecycle assertion is weakened.

```powershell
python build/review_winter_soft_fast.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -TestArgument @('--capture','--video')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
git diff --check -- game/track/winter_snow_wind.gd game/track/winter_snow_wind.gdshader game/tests/test_winter_snow_wind.gd
python build/checkpoint_winter_soft_fast.py
```

Engine commands use pinned `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`. The first inline Python parity command failed due Windows quote handling; a static helper verified exact restoration. Headless checks exited 0 but reported 51 ObjectDB instances at shutdown; this warning is retained in the actual log, not claimed resolved. Focused assertions had no failures. No full Validate, app/physics-regression rerun, Android export/install, backend work or deployment was performed.

[Four-second 30 fps driving preview](evidence/winter-soft-fast-2026-10-11/driving-motion.html), [driving still](evidence/winter-soft-fast-2026-10-11/driving.png), [gust](evidence/winter-soft-fast-2026-10-11/gust.png), [without wind](evidence/winter-soft-fast-2026-10-11/before.png), [curve](evidence/winter-soft-fast-2026-10-11/bend.png), [30 fps curve preview](evidence/winter-soft-fast-2026-10-11/motion.html), [rotated camera](evidence/winter-soft-fast-2026-10-11/rotated.png) and [compact view](evidence/winter-soft-fast-2026-10-11/compact.png) are actual Godot renders of this exact combination. Review uses a controlled strong/calm gust and a separate canonical driving fixture; it is not a completed player race and writes no competitive result. Captures were inspected for the restored shape and faster flow. Earlier variants remain saved for comparison.

Task-only checkpoint/patch, parity receipt and actual logs are saved alongside evidence using `build/winter_soft_fast/checkpoint-repo`; main branch/index and concurrent work are untouched. Restart the local client to allocate the restored meshes and pools. **No phone/device test or attachment check was performed in this restoration task.** Owner comparison of the faster soft flow, phone fill/shadow cost, render-scale/depth/MSAA behavior and all bridge/terrain cases remain pending.
