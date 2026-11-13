# Vehicle simplification pass — 2026-11-07

Implemented locally for all five current vehicles. Native comparisons pass on
Compatibility and desktop Mobile; owner and tablet acceptance remain. This pass
reduces submitted geometry while retaining original full-detail meshes. It does
not establish an FPS, loading-time or memory improvement on a device.

| Requirement | Result |
| --- | --- |
| VSP01 | Offline index-only detail levels for all 20 active base variants and eligible geometry across all 442 fitted modules. Full-detail vertex/GPU storage, original indices, materials, bounds and complete articulation remain exact. |
| VSP02 | Race assets use car-only LOD bias 2 with the existing one-pixel viewport policy. Stock Garage assets retain bias 1 with their existing half-pixel viewports. Glazing and shadow-only proxies remain full detail. Hover optimises only geometry under the independently articulated left/right fan rotors; its layered hull, skirt, canopy and ducts remain exact. |
| VSP03 | Rebuild 20 bases, 442 modules, five Garage templates, one header template and preview provenance. Final 468-resource preflight: 1,925 checks, zero failures; five photographs/157 source hashes pass. |
| VSP04 | 45,061/0 structural checks, 640/0 native checks per renderer, 180 native comparison cases/540 captures, and retained modular/racing/driving/washing suites pass. |

The [comparison sheet](evidence/vehicle-simplification-2026-11-07/comparison.png)
shows full detail on the left and automatic detail on the right. It uses native
Compatibility captures, cropped equally without rescaling either comparison.
The [full native captures](evidence/vehicle-simplification-2026-11-07/native-gl/)
and [machine-readable summary](evidence/vehicle-simplification-2026-11-07/summary.json)
retain all cases and measurements.

At 1280×720, isolated stock cars in the overhead component fixture submit:

| Car | Original visible primitives | Automatic detail | Reduction |
| --- | ---: | ---: | ---: |
| Rally | 101,662 | 32,825 | 67.71% |
| Kart | 87,202 | 23,368 | 73.20% |
| Forklift | 145,514 | 26,816 | 81.57% |
| Volt | 120,582 | 34,570 | 71.33% |
| Hover | 72,062 | 68,114 | 5.48% |

Both renderers return the same counts. The fixture includes its two floor
triangles; counters are for visible submissions, without separate shadow-pass
totals. Close views retain denser geometry. These are component geometry results,
not race FPS or overall game rendering costs. Hover's deliberately smaller gain
protects the previously accepted layered surfaces.

Each renderer compares stock detailed, fitted detailed and stock simpler cars,
in overhead/front-close/rear-close views with day and Night lighting. Cars retain
actual paint patterns/stickers and local dirt/snow presentation; Volt uses the
actual race-owned Night glass binding. Each case switches the same instance from
full detail to LOD and back. All 180 restored controls are pixel-exact. Maximum
mean RGB-channel difference is 0.035060/255 on Compatibility and 0.036689/255 on
Mobile. The maximum fraction of pixels differing by more than 8/255 in any RGB
channel is 0.14475% and 0.17462%, respectively, below the retained 0.5% gate.
These comparisons pass the existing Garage appearance gates; LOD images are not
claimed pixel-identical to full detail. Native stock/fitted examples and the Hover
canopy/fans were inspected.

The structural audit compares every active prepared scene against its task-start
archive: complete articulated tree, local transforms/visibility, mesh attachment,
original arrays, raw GPU surface storage, active material properties and shaders,
original bounds, layers and shadow modes. It checks that glazing, layered Hover
surfaces and shadow-only proxies contain no LODs. The existing modular suite
independently exercises prepared construction, kit replacement and fallback.

Implementation files:

- `game/vehicle/car_mesh_lods.gd`: shared **offline-only** preparer, retaining the
  existing Garage helper's exact-storage transfer and adding vehicle-specific
  eligibility and per-instance LOD bias. It is part of the existing conservative
  geometry dependency hashes, so policy changes invalidate affected preparations.
- `game/tests/support/garage_mesh_lods.gd`: existing Garage/workshop entry point
  delegates to the shared preparer. Workshop preparation retains its former
  policy; this task does not rebake the room.
- `game/tests/bake_modular_car_bases.gd` and `bake_modular_car_kits.gd`: prepare
  LOD indices after each ordinary stock/module bake. The existing Garage baker
  already invokes the shared helper through its original entry point.
- `game/tests/test_vehicle_mesh_simplification.gd`: original-resource audit and
  same-instance native comparisons. Refreshed prepared scenes/preview provenance
  accompany the source changes.

There is no runtime mesh simplification, new quality setting or world/camera
policy change. Original procedural/stale-asset fallbacks retain full geometry;
the existing fitted-simpler racing fallback remains unchanged. Fitted modules
shown in Garage inherit bias 2 within its half-pixel viewport, which is more
conservative than the stock Garage bias. No canonical simulation, handling,
collision, score, appearance-save or backend contract changes are needed.

The storage tradeoff is **17,721,128 added bytes** (16.90 MiB) in prepared scenes;
the original vertex buffers remain resident alongside additional index streams.
Measured prepared scene totals, including unchanged retired scenes, are
59,893,850 → 77,614,978 bytes. No resident-memory or packaged-APK measurement was
performed. Four active preview PNGs are byte-exact to before; Hover's preview is
refreshed for its rotor LODs. Provenance records the current complete source graph.

Actual validation, pinned `4.7.2.stable.official.ed1daf0bf`, private workspace
APPDATA/LOCALAPPDATA profiles, empty backend URL and crash-dialog wrapper:

| Command/script | Outcome |
| --- | --- |
| `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_modular_car_bases.gd` through the wrapper | Pinned entry point; all 20 base bakes pass. |
| `python scripts/prepare_car_assets.py --output build/vehicle-simplification-2026-11-07/assets` through the wrapper | Complete source-stable library/picture rebuild and both final preflights pass. |
| `test_vehicle_mesh_simplification.gd`, headless | Final 45,061 checks, zero failures across 468 resources. |
| Same script, `gl_compatibility` and desktop `mobile` | 640 checks/90 cases/270 captures each, zero failures. |
| `test_modular_car_assets.gd` | 1,173 checks, zero failures. |
| `test_racing_car_models.gd` | 88 checks, zero failures. |
| `test_driving.gd` | 72 checks, zero failures; actual Game construction is included. |
| `test_garage_wash_surfaces.gd` | 45 checks, zero failures. |

[Command receipts/logs](evidence/vehicle-simplification-2026-11-07/logs/) record
arguments, owned PIDs, exits and durations. The build helper at
`build/vehicle-simplification-2026-11-07/run.py` launches private bounded engine
processes, with graphical windows positioned off screen. Native Mobile identifies
an NVIDIA RTX 3090; it is a desktop renderer check. The model-input source receipt
is stable through baking and all native checks.

Retained initial findings: the first audit accidentally included five retired
resources and treated engine-assigned anonymous leaf suffixes as authored names
(39,144 checks/268 failures). The corrected audit uses the same five-car/468-scene
scope as export preflight, retains exact authored names, and compares anonymous
mesh leaves by their exact parent and sibling slot. Original buffer/material/pose
assertions remain; additional complete articulation checks strengthen the final
audit. The task runner initially rejected forwarded arguments before launching a
native process; forwarding was corrected. An attempted Python comparison-sheet
helper found Pillow unavailable; no dependency was installed, and the sheet uses
Windows' existing image drawing facilities. Initial pre-bake source/picture
preflight rejections are retained alongside final passes. No production model
failure was hidden by these fixture/tooling corrections.

Owner review, client reload/rebuild and representative tablet appearance/frame-time
acceptance remain. No device query/test, APK export/install, owner-save/process
change, live/backend request, deployment or main-index staging/commit/merge was
performed. Concurrent work is preserved. The task-only source/binary patch and
forward/reverse/content verification receipt are stored beside the evidence;
generated whole-workspace build identities are recorded, not included as owned
source changes.
