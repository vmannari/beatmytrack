# Garage: a further 25% triangle reduction — 2026-11-15

The requested additional reduction is applied to the Garage environment: **41,467 → 31,075 master triangles, down 25.06%**. This is **76.83% below the original 134,089**. The published workshop contains 29,245 triangles and the physical platform 1,816; the floor and six contact-shadow quads add 14. Vehicle model source and handling are outside this pass.

G2501: reduce the current environment by at least 25%. G2502: retain the room layout, recognizable props, original finishes, lights, record behavior and attachments. G2503: publish current prepared assets under the existing guards and verify actual Garage entry.

| Component | Previous | Current |
| --- | ---: | ---: |
| Spare-wheel rack and wheels | 6,672 | 4,980 |
| Workbench and tools | 4,770 | 3,974 |
| Plant, planter and soil | 3,726 | 2,114 |
| Trophy display wall | 3,679 | 2,741 |
| Tool storage | 4,084 | 3,012 |
| Compressor | 3,185 | 2,174 |
| Record station, vinyl and 14 sleeves | 4,539 | 3,084 |
| Architecture, roof and shared fixtures | 4,274 | 3,678 |
| Drain | 1,152 | 1,152 |
| Other props | 2,916 | 2,336 |
| **Prepared workshop** | **38,997** | **29,245** |
| Physical platform | 2,456 | 1,816 |
| Floor/contact quads | 14 | 14 |
| **Default environment** | **41,467** | **31,075** |

The count follows the [previous reduction](GARAGE_70_PERCENT_2026_11_14.md). Earned awards, record contents and the car vary the complete scene total. Master counts exclude LOD/culling savings and additional reflection submissions. They are not GPU frame totals or a load-time/FPS improvement measurement. [Inventory and cost receipt](evidence/garage-25-2026-11-15/counts.json).

Unique ArrayMesh payload, including stored LOD index buffers, is 1,985,052 → 1,520,084 bytes (23.42% less); PrimitiveMesh parameter resources are excluded from that measure. The compressed workshop is 587,368 → 445,071 bytes (24.23% less). Mesh instance/unique mesh counts remain 109/96, so no draw-call reduction is claimed.

## Changes

Tiny default shafts up to 15mm radius use four cardinal samples, retaining their axial and radial bounds and analytical normals. Larger shafts retain eight/twelve samples. Turned profiles retain their rows with eight/twelve/sixteen azimuth samples; small rolled rings use eight. Compact boxes with a smallest dimension up to 0.5m use closed six-face geometry. The broad shutter-panel bevels and largest bodies remain. The platform cylinder uses 64 sides and its rolled rings 48 major samples.

The four spare wheels retain their positions, spokes, lugs and brakes, with 20-sided casings/lips and twelve wider tread repeats. The plant keeps its 28 leaves and their attachment positions, with four-by-two grids, seven leader points, direct petioles, four-sided stems and a sixteen-sided planter/soil. The brand retains its font, text and folded laurel leaves, with fewer stem segments and a larger TextMesh curve step. A probe records 637 → 459 lettering triangles for the selected step.

Bolt slots, compressor dial markings, ruler marks and laurel midribs use two-triangle front surfaces instead of closed miniature solids. Their front positions/widths and finishes remain. These are surface details; their depth and edge highlights are deliberately simplified. Record hardware uses fewer samples for the platter, disc, label and tiny controls, while preserving vinyl/sleeve nodes, artwork, gestures and transport behavior. No new shader, external art or model is introduced.

## Checks and appearance tradeoff

The strengthened environment budget passes **82 checks/0 failures** with the published scene. It retains all earlier source-versus-prepared, named object/light/attachment transform, cap area/bounds/position/UV/winding, eight principal objects, six award slots and record-node assertions. The total budget tightens from 41,500 to **31,100**, and the room limit to **29,270**. Four-sided cap cases and front-mark area, width, finish and winding checks are added. The previous room is rejected by the new suite with **81 checks/3 failures**, including both tighter budget gates; its printed platform count uses the new source platform.

Two initial candidates miss the unchanged new target: 34,203 and 31,957 triangles. Further surface-mark and hardware reductions reach 31,075. One new mark-bound fixture initially expects a zero-depth renderer AABB. A direct native probe demonstrates the engine's 0.00001m culling padding while every actual vertex lies on the exact authored plane. The fixture now measures the actual vertex bounds with the same tolerance. No existing assertion is relaxed.

| Verification | Result |
| --- | ---: |
| Source/prepared geometry, budget, marks and layout | 82/0 |
| Existing conservative mesh cleanup | 20/0 |
| Native paired-view fixture | 202/0 each desktop renderer |
| First capture/selection/cancellation | 90/0 each desktop renderer |
| Opening reflections | 18/0 each desktop renderer |
| Opening tools | 16/0 each desktop renderer |
| Actual App Garage entry and input | 45/0 each desktop renderer |
| Saved playlist behavior, headless | 57/0 |
| Saved playlist behavior, native Compatibility | 63/0 |
| Production parsing | 573 scripts/0 |

The paired fixture retains the same live car instance and finish for each before/after pair. It covers six cars at front/rear/close and ten prop views, including both reflection textures: **84 image pairs per renderer**. Compatibility and desktop Mobile both complete without native/script errors. The inspected props remain recognizable and the brand remains legible. Close views show the expected coarser curves, vice base, leaves and small fittings.

The prior strict small-change image gate is retained, with **57/84 pairs passing per renderer**. The worst mean RGB errors are 1.703094/255 Compatibility and 1.902909/255 Mobile in the vice close-up, with 4.398438%/4.340386% of pixels differing by more than eight levels. These results do not establish pixel equivalence. The unchanged historical fine-detail policy test reports **78 checks/25 failures**, compared with 22 failures after the preceding reduction; its older chord-error/sample-count requirements remain visible. There is no whole-suite clean claim.

Final App first-live observations are 1.617s Compatibility/2.404s desktop Mobile. These are individual health samples with the current shared car assets, not matched controls or attribution to the environment change. Foreground handling uses the existing task-owned offscreen test adapter; production guards are intact.

## Publication and shared-work controls

The source check reproduces the original 38,997/2,456 environment before changes. Its stored workshop provenance is initially stale for a concurrently updated car LOD helper, although exact master/source geometry still matches. The producer rebuilds from the current inputs rather than restamping metadata. Its existing private candidate, exclusive lock, error logger, source/output fences and manifest-last rollback publish the new workshop. The read-only workshop gate confirms **28 current source hashes**. All 28 inputs plus the scene and provenance are byte-stable throughout the live verification run: [30-file room fence](evidence/garage-25-2026-11-15/room-fence.json).

Separate car work continues writing module resources during some native comparisons. Those paths are recorded by the runner; they are preserved. The before/after phases use the same already-instantiated stock car. This pass makes no vehicle geometry, canonical data or handling changes, and does not claim a whole-project stable-input window for those initial runs.

An initial broader preflight reports **551 resources/2,267 checks/166 findings**, identifying 83 stale Challenger resources after shared car-code changes. The following closeout records their reconstruction and the final catalogue/current-source checks.

The stale Challenger consumers are reconstructed in a private project using the current standard base/module/rest producers. All native error checks remain active. A **25,402-input source fence** and exact current car-key controls protect publication of **83 resources**, preserving the other five cars' outputs. No model source, handling or provenance metadata is manually restamped. The complete private and live preflights both pass **551 resources/2,267 checks/0 failures**. The initial live preflight observes a concurrent generated-identity rewrite; the later final native run supplies the stable combined fence.

Within the closed verification window, six catalogue photographs refresh using the current models, and their private native image imports are checked before copying. The photo validator passes **six exact images/173 current source hashes**, and the workshop validator retains **28 current hashes**. Generated identity is refreshed after the pictures with exact car-key controls. Native pairs **202/0** and actual App **45/0** repeat in both renderers after cache publication, with **26,205 relevant source/output files byte-stable** across those runs. [Final fence](evidence/garage-25-2026-11-15/final-fence.json), [cache publication](evidence/garage-25-2026-11-15/cache-publication.json), [identity controls](evidence/garage-25-2026-11-15/identity-controls.json).

**Late concurrent changes supersede global readiness, not the Garage geometry result.** After that window, other work adds `car_iteration_reduction` calls to `car_visual.gd` and changes Challenger source meshes/livery images plus App/feature code. The catalogue validator correctly rejects the changed car source. Current shared car/cache/catalogue and whole-App readiness are therefore unqualified pending those tasks' corresponding refreshes; the earlier full preflight and App results describe the recorded snapshot. No later car source or output is restored or restamped by this pass. The independent workshop validator still passes all **28 current source hashes**, and a fresh room budget/layout check passes **82/0**, retaining **31,075 environment triangles**. [Late source diff and rejection receipt](evidence/garage-25-2026-11-15/late-concurrent.json).

A [nine-file normalized source-only checkpoint](evidence/garage-25-2026-11-15/checkpoint.json) applies and reverses exactly in a private fixture. Generated assets and other authors' work are excluded from that patch. Required build retention cleanup is applied, removing one eligible entry: **31.35 → 31.32 GiB**. Recent/protected/locked outputs and the 24-hour grace retain storage above the 20 GiB target; [the receipt](evidence/garage-25-2026-11-15/retention.json) records that limit. No task pin is created.

Representative commands:

```powershell
python scripts/run_garage_25.py published-budget --headless --reference-room=res://../build/garage-25-2026-11-15/before/workshop_v1.scn
python scripts/run_garage_25.py native-gl --script res://../build/garage-25-2026-11-15/paired.gd
python scripts/run_garage_25.py native-mobile --renderer mobile --script res://../build/garage-25-2026-11-15/paired.gd
python scripts/run_garage_25.py publish-room --headless --script res://tests/bake_garage_architecture.gd --output="C:\Codes\Godot\Beat my track\game\assets\garage"
python build/garage-25-2026-11-15/verify.py
python build/garage-25-2026-11-15/repair_cache.py
python scripts/check_garage_workshop.py
```

Every engine launch uses pinned Godot 4.7.2 through `run_no_crash_dialog.py`, disposable offline storage and an offscreen native window where applicable. [Compatibility before](evidence/garage-25-2026-11-15/gl_compatibility/before/compact-front.png) · [after](evidence/garage-25-2026-11-15/gl_compatibility/after/compact-front.png). [Vice before](evidence/garage-25-2026-11-15/gl_compatibility/before/vice.png) · [after](evidence/garage-25-2026-11-15/gl_compatibility/after/vice.png). [Plant before](evidence/garage-25-2026-11-15/mobile/before/plant.png) · [after](evidence/garage-25-2026-11-15/mobile/after/plant.png).

Reload and owner appearance acceptance remain. No device query/test, export, live backend operation, deployment, owner-save/process action or main-index staging/commit. Disposable scenes/projects/shader caches stay under `build/`; permanent evidence contains concise receipts, source transcripts and selected native comparisons.
