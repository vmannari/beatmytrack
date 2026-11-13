# Larger cars in paint rows — 2026-10-26

GPI01–GPI03/R01/Q01 implement the owner's clarification: remove the **paint option row number** and use its space for the car image. The preceding main-camera adjustment addressed a different area of the screen.

Paint rows now start with the car. The display slot grows from 64×40 to **112×76** in the larger layout and from 56×36 to **96×72** in compact layouts. Row height stays 100. The hidden number and separator consume no layout width. Names, descriptions, authoritative prices, equipped/owned/preview states, category count, selection outline and Buy & Equip remain. Parts retain their visible row numbers. All 49 paints and seven vehicles remain available.

The profile-style render grows from 176×112 to **224×152**, with a matching half-size studio layout and a new cache identity so an older bitmap is not reused. The shared profile camera, lighting and composite stay in use. Visible-row rendering, a 24-image cache, one temporary studio, offscreen release and hide/free-in-flight cleanup remain. The maximum 24 mipmapped RGBA8 textures are approximately 4.2 MiB before driver overhead; this is a size calculation, not a device measurement. The runtime scope is `garage_part_option.gd` and `garage_paint_icons.gd`.

Only the superseded paint-number/small-size assertions and matching profile-reference size are updated in `test_garage_paint_list.gd`. Existing text-containment, real mouse/touch, preview, compare, account, save, purchase confirmation, all-car, cache and teardown guards remain. The existing Parts assertion in `test_customisation_carousel.gd` additionally requires the number to be visible. No new test script is added for this layout change. Geometry, main Garage camera, prices, saved cosmetics, profile-button UI and simulation are unchanged by this task.

Actual isolated commands use pinned Godot 4.7.2 through `scripts/dev.ps1`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-icons-larger-2026-10-26/run.ps1 -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-icons-larger-2026-10-26/run.ps1 -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-icons-larger-2026-10-26/run.ps1 -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-icons-larger-2026-10-26/run.ps1 -Test test_customisation_carousel -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-paint-icons-larger-2026-10-26/run.ps1 -Test test_script_parse -Mode headless
python docs/evidence/garage-paint-icons-larger-2026-10-26/record.py
```

Paint checks pass **151 headless / 192 Compatibility / 192 desktop Mobile**, including actual App views at 960×540, 1280×720 and 1720×900. The larger raster still matches an independent instance of the profile presentation within the unchanged 0.02 sampled RGBA mean difference limit. Parser **1266** passes. The retained configurator passes **600 headless** checks. All command exits are in [report.json](evidence/garage-paint-icons-larger-2026-10-26/report.json). Test data and transaction fixtures are isolated; actual App captures use guest records.

The first three attempts encountered an in-progress concurrent shared `apply_customisation` method-signature change. Their failed commands/logs are retained in `initial/`. The matching thumbnail override subsequently arrived; this task did not edit the shared showroom or thumbnail scripts.

[Native review](evidence/garage-paint-icons-larger-2026-10-26/review.html) shows the paint rows and full App. The before picture is a copied **previous native capture** from `garage-paint-framing-2026-10-26/test_garage_paint_framing-gl_compatibility/paint-app-1720.png`; it documents the preceding numbered row design, not a new baseline run. Its original source path and hash are recorded. The after images are from this task's runs. `record.py` builds `task-only.patch` from task-start source snapshots. Tracker review bases retain later concurrent entries, while the original tracker snapshots remain under `before/`. The reverse Git check validates the patch; no staging or commit is performed.

Reload and owner visual/touch acceptance remain. No physical-device attachment check or device test was performed. No APK, real authentication/purchase, live mutation, deployment, merge or owner-process restart was performed. Concurrent kit/paint-animation, entry, camera, Rivalry, vehicle, track and handling work is retained and excluded from the patch.
