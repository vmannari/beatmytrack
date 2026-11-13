# Kart model refinement — 2026-10-25

The owner requests a substantially better kart model, with AAA as the quality ambition, then identifies a broken seat back, protruding helmet chin/knees, bumper ends meeting the tyres, an incoherent exhaust and an overly reclined steering wheel. The final model addresses each correction in the native Garage and race renderer. Owner visual acceptance and physical-device cost acceptance remain open; passing checks do not establish an AAA quality certification.

## Requirements and scope

| ID | Delivered behaviour |
|---|---|
| KR01 / V02–V05 | Original sculpted nose, Nassau fairing and side pods; bent chassis rails, floor tray/pedals, slick tyre shoulders and recessed magnesium-style rims. Restrained shared CompactFinish paint, alloy and rubber. |
| KR02 | Closed seat bucket/back, one continuous helmet shell and fitted visor, continuous bent trouser legs without protruding knee pads. |
| KR03 | Bumper supported by inboard chassis mounts, clear of the tyres. Connected engine header → transverse expansion chamber → stinger → silencer → hollow rear outlet, with stays attached to chassis rails. |
| KR04 | Steering rim tilted 1.15 radians from horizontal toward an upright plane facing the driver; column, top display and hand contact aligned. |
| KR05 | Full and simpler racing geometry, offline prepared meshes, matching articulated shadow proxies, native catalogue/news art and all 49 livery photos. |
| R01 / G01 / Q01 | Preserve canonical dimensions, handling/configuration, replay, records and driving camera; retain concurrent work and keep review evidence. |

## Implementation and actual bounds

`game/vehicle/kart_model.gd`, `kart_geometry.gd` and `kart_slick.gdshader` replace the old `_kart` function through a kart-only dispatch in `vehicle_models.gd`. Other vehicles' dispatch and geometry remain at task-start content. New surfaces are original code-authored geometry; no external model, manufacturer identity, generative service or runtime network dependency is introduced.

Loft stations stay monotone along the model and have explicit solid end caps. This removes the folded, saw-toothed seat closure and fairing tips seen during the initial review. Paint inlays sample the exact underlying loft rather than crossing its surface. Visor and gasket have independent depth offsets. The helmet chin is part of the same surface, and each trouser leg is one continuous bend. The rear bumper now curves behind the tyres and has two independent inboard chassis mounts.

The detailed model has **86,096** visible triangles; the optional simpler model has **25,280** (70.6% fewer). This is a substantial increase from the original 5,416/3,192 triangles. The 208 prepared mesh resources total 956,278 bytes, excluding the manifest. Small fittings use lower sampling, and lathed parts omit redundant linear profile subdivisions. The existing batching retains all visible triangles and wheel articulation. No new frame callback, light, screen pass or simulation step is added by the model.

The seat, nose, side pods and Nassau shell each have **zero non-manifold/open edges** after positional welding, in both model modes. Sampled authored surface vertices clear conservative cylindrical tyre envelopes by at least **0.084953 model metres** for the bumper and **0.096977 model metres** for the checked exhaust pieces. At the retained 0.88 body scale these correspond to approximately 7.48 cm and 8.53 cm. These are vertex/envelope checks, not a collision solver or a real kart engineering certification.

Matching simplified shadow proxies are 1,074 body triangles and 130/130/148/148 wheel triangles. Their previous files are backed up. The prepared manifest binds the exact model/geometry SHA-256 values. The baking helper refreshes the current original surfaces; unused resources from the intermediate task bake were moved into evidence. The native newspaper bake gained an optional `--vehicle` filter to update only the kart.

The simulation source, handling-config source, kart Resource and camera contract hashes exactly match the task-start hashes in `invariants-before.json`. The regular working tree contains substantial earlier/concurrent edits, including electric/Forklift dispatch; those are preserved.

## Native review evidence

- [Original front](evidence/kart-refinement-2026-10-25/before-model/full-front.png), [original rear](evidence/kart-refinement-2026-10-25/before-model/full-rear.png).
- [Final front](evidence/kart-refinement-2026-10-25/model/full-front.png), [rear](evidence/kart-refinement-2026-10-25/model/full-rear.png), [opposite rear](evidence/kart-refinement-2026-10-25/model/full-rear-left.png), [driver](evidence/kart-refinement-2026-10-25/model/full-driver.png), [overhead](evidence/kart-refinement-2026-10-25/model/full-top.png).
- [Actual Garage](evidence/kart-refinement-2026-10-25/native/garage-1280.png), [actual overhead race](evidence/kart-refinement-2026-10-25/native/race.png), [actual rear seat](evidence/kart-refinement-2026-10-25/native/race-seat-rear--1.0.png).
- Matched desktop Mobile/Vulkan views are in `model-mobile/` and `native-mobile/`. The close-up cameras are evidence-only; the actual race capture retains the production camera.

## Commands and verification

All runs use `scripts/dev.ps1` and pinned Godot `4.7.2.stable.official.ed1daf0bf`. APPDATA/LOCALAPPDATA point into `build/kart-refinement/`, and the App fixture stores disposable records/cloud state in that directory. Native Godot required execution outside the sandbox to read Windows' certificate store. No owner process was restarted.

| Wrapper action / script | Actual result |
|---|---|
| `TestScript res://tests/test_kart_model.gd --baseline` with Compatibility | 12 captured views, 0 failures; original geometry recorded |
| `TestScript res://tests/bake_kart_model.gd` | 208 exact-source full/simple meshes and five matching shadow proxies |
| `TestScript res://tests/test_kart_model.gd`, graphical Compatibility | 62 checks, 0 failures |
| Same model script, graphical `mobile` / `vulkan` | 62 checks, 0 failures |
| `TestScript res://tests/test_kart_refinement_ui.gd`, graphical Compatibility | 14 checks, 0 failures; actual Garage at 960×540, 1280×720 and 1600×720; actual Ellipse race |
| Same UI script, graphical `mobile` / `vulkan` | 14 checks, 0 failures |
| Same UI script with `--bake-art` | 1 save check, 0 failures; native catalogue art |
| `TestScript res://tests/bake_livery_previews.gd --vehicle=kart` | 49 native photographs regenerated |
| `TestScript res://tests/bake_news_car_photos.gd --vehicle=kart` | 1 car, 0 framing failures |
| `Import` | Passed; native art imported; isolated Android build-tools directory warning retained |
| `TestKart` | 32 handling checks and 107 catalogue/replay checks, 0 failures; three five-lap kart runs, zero contacts, exact replay |
| `TestApp` | 141 checks, 0 failures |

Full command arguments, final parser/whitespace/checkpoint outcomes and source hashes are in [report.json](evidence/kart-refinement-2026-10-25/report.json).

Initial sandbox log/certificate access and PowerShell execution-policy failures are retained as environment failures, not passing tests. The first detailed render had 168,196 triangles and one budget failure, folded loft ends, intersecting inlays and visor depth fighting. The next revision had 96,320 triangles and one budget failure. The helmet/knee/seat revision passed 53 checks at 91,712 triangles; the subsequent mechanical revision had 96,848 triangles and one budget failure. Removing redundant lathe rows brings the final model below the original 95,000-triangle test ceiling; no ceiling, topology assertion or visual invariant was weakened. Intermediate captures/reports remain in `initial-surface-review/` and `mechanical-review/`.

The actual App diagnostic logged first-use desktop frames of 348/168 ms in Compatibility and 263/137 ms in Mobile. These hitches are retained; this task does not establish their cause or a sustained performance improvement. Offline meshes avoid rebuilding curved surfaces during normal loading, but phone frame pacing, memory/thermal cost and owner appearance approval remain required acceptance.

No physical-device attachment check or test, APK build/install, live backend/account/purchase mutation, deployment or owner-process restart was performed. A client reload is needed for already running processes to replace cached meshes, scripts and photos.
