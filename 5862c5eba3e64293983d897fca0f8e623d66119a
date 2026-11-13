# Fixed placement controls and new sticker illustrations

2026-10-29. Requirements SW01, SW02, R01 and Q01.

SW01 keeps Place sticker and Remove in a fixed bottom row beneath the artwork
gallery. Hood/Roof stay above the gallery. Only the grid scrolls, so the placement
action remains visible at either end of the list and after returning from the
placement editor or switching panels. Empty panels retain a visible disabled
action; selecting a sticker enables it. The existing 48-unit touch height remains.

SW02 replaces all twelve former badge designs with the original **Pit Creatures**
illustrations: Apex Fox, Brake Snail, Wrong Turn, Dune Gecko, Night Moth, Tailwind,
Pit Gremlin, Moon Taxi, Kerb Hopper, Coffee Rocket, Photo Finish and Dust Devil.
They use individual silhouettes, asymmetric poses, printed ink lines and paper
edges, with coral, teal, blue, olive and ochre. The ideas are specific racing and
garage stories: a fox's checkered scarf, a snail's tyre shell, a pigeon carrying a
bent route arrow, roads inside moth wings and a coffee cup built like a piston.
This is a new visual direction; owner approval of that direction remains.

The editable artwork is in `scripts/livery_sticker_art.py`. The existing
`scripts/build_livery_art.py` imports it and exports the twelve individual SVGs,
the shared atlas and the catalogue. No fonts, downloaded art, traced reference,
third-party brands, generation service or new dependency is used. The SVG previews
stay 256×256; the atlas stays 1024×768 with its existing cells, gutters and mipmaps.
No shader, geometry, material-pass or runtime generation change is introduced.

R01 keeps every saved sticker ID and atlas index exact. Names and artwork change;
paint, pattern, sticker placement/rotation, panel independence, removal and the
previous sponsor-retirement compatibility remain. All 96 pattern/preview SVGs
are byte-exact. The generator independently reproduces all 111 output files in a
separate workspace directory. No appearance schema or backend change is needed.

Q01 uses the actual App with isolated local records and the backend disabled.
The original layout produces **57 checks / 24 failures** in the new review:
placement is clipped at the list's top, moves while scrolling and lives inside
the scroll container. The fixed layout passes **65/0 headless** and **75/0 each
Compatibility and desktop Mobile**, including real card/action taps at 1280×720,
960×540, 844×390 and 1600×900. Top/bottom views prove fixed geometry, no overlap,
visible Remove, touch height, cached panels and selected/empty state transitions.

The retained sticker-collection suite checks all six cars, twelve distinct actual
roof renders, actual touch placement and save/reload: **126/0 each Compatibility
and desktop Mobile**. Ten workbench and twelve six-car views per renderer supply
44 final captures. All command logs are in the adjacent `report.json`. No broad-project test or
Android performance claim is made. The older broad livery/swipe findings remain
documented in `STICKER_COLLECTION_2026_10_28.md`; this task does not change unrelated
kit, preview-import or camera assertions to make those suites pass.

Actual commands, through the pinned Godot 4.7.2 entry point:

```powershell
python scripts/build_livery_art.py
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/sticker-workbench-2026-10-29/run.ps1 -Phase before
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/sticker-workbench-2026-10-29/run.ps1 -Phase layout -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/sticker-workbench-2026-10-29/run.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/sticker-workbench-2026-10-29/run.ps1 -Phase after
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/sticker-workbench-2026-10-29/run.ps1 -Phase after -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/sticker-workbench-2026-10-29/run.ps1 -Phase cars -ScriptPath res://tests/test_sticker_collection.gd
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/sticker-workbench-2026-10-29/run.ps1 -Phase cars -Renderer mobile -ScriptPath res://tests/test_sticker_collection.gd
```

One runtime layout script changes. The existing swipe fixture now asserts that
the placement action is outside scrolling content, preserving its touch checks.
`game/tests/test_sticker_workbench.gd` is the new actual-App regression and native
capture helper. Task-start sources, hashes, captures, logs and a scoped patch are
in `docs/evidence/sticker-workbench-2026-10-29/`. The runner isolates the Windows
profile, disables the API and conditionally restores only its generated build
metadata. The patch is checked forward and backward in a separate directory.
Concurrent vehicle/kart-kit, Garage, editor, event/backend and generated work is
preserved and excluded from the task checkpoint.

[New artwork](evidence/sticker-workbench-2026-10-29/after/mobile/artwork.png),
[small-screen fixed action](evidence/sticker-workbench-2026-10-29/after/mobile/gallery-844x390-top.png)
and [actual-car sheet](evidence/sticker-workbench-2026-10-29/cars/gl_compatibility/all-stickers-on-car.png).

Reload/rebuild and owner acceptance of appearance/input remain. No physical-device
attachment query or test, APK export/install, real authentication/purchase,
owner-save or live/backend write, deployment, owner-process restart or main-index
staging/commit/merge was performed. Desktop Mobile is the desktop Vulkan renderer,
not an Android device test.
