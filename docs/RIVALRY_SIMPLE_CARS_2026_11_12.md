# Simple Rivalry podium cars — 12 November 2026

RSC01–RSC05: the owner requests very simple cars after the Rivalry entry investigation. The hub’s three podium previews now use small faceted vehicle shapes with player paint colours. This intentionally replaces detailed fitted parts, patterns/stickers, weathering and reflective racing materials in these thumbnails. Appearance validation, complete source payloads, self/remote scoping, scores, actions and layout remain.

## Implementation

`game/ui/rivalry_simple_car.gd` builds distinct Rally, Super Rally, Volt, Kart, Forklift and Hover silhouettes, projects their faces at a fixed viewing angle and batches the shaded colours and antialias fringes into one 2D canvas mesh per car. It creates no CarVisual, Node3D, camera, lights, reflection environment or SubViewport. Model generation is synchronous; resizing scales retained geometry. The existing menu canvas draws each car in one call, with no per-frame script processing or persistent global cache. The hub’s readiness check now waits for the actual projected models and usable layout dimensions.

Shape geometry is 368–488 triangles; the final canvas fill plus edge smoothing is 856–1,148 triangles. In the isolated six-model gallery the final renderer records 12 draws including six labels, on both desktop renderers. The early per-facet prototype cost 2,234 draws in the same gallery and was replaced before completion. The draw-call regression gate rejects that approach. Final construction is typically about 1.4–1.9 ms per model; the first desktop Vulkan mesh allocation measured 10.3 ms in one run. This is not a tablet memory/FPS claim.

Only the hub podium uses this view. The shared detailed preview, Garage, races, finale and Share views were not edited. Seventeen shared-source/configuration hash controls remain exact. The separate repeated race contact-outline issue from [the investigation](RIVALRY_RACE_LOADING_INVESTIGATION_2026_11_12.md) is not changed by this UI work.

## Actual App entry comparison

| Desktop renderer | Original first entry ms | Simple first entry ms | Original / simple repeat ms | Original / simple Rivalry feature load ms |
| --- | ---: | ---: | ---: | ---: |
| OpenGL Compatibility | 2925.4 | 660.9 | 77.8 / 72.6 | 1775.3 / 383.8 |
| Vulkan Mobile (desktop) | 5580.7 | 618.6 | 95.9 / 55.1 | 2095.8 / 390.1 |

Pinned official Godot 4.7.2 (`ed1daf0bf`), RTX 3090/i7-11700K, Windows, actual offline App, 1280×720, offscreen native windows, Dummy audio, music disabled and private user profiles. Garage background warming is suppressed, matching the earlier diagnostic. Each entry includes real page handling, readiness and drawn frames. Each table cell is a single run; renderer/OS caches and other owner processes are uncontrolled. The earlier 11-second native first-use draw stall is not reproduced by these already-warmed original controls. These timings support the local change but are not Android, network-entry, sustained-FPS or statistical performance results.

[Final actual Rivalry page](evidence/rivalry-simple-cars-2026-11-12/final-entry-simple-gl/rivalry.png) · [Six simple vehicle models](evidence/rivalry-simple-cars-2026-11-12/models-gl_compatibility.png) · [Player-specific colours](evidence/rivalry-simple-cars-2026-11-12/final-custom-cars-gl/gl_compatibility/hub-1280x720.png)

## Validation and retained findings

| Final gate | Result |
| --- | --- |
| Isolated models, geometry/raster/draw budget | 50 checks / 0 failures each desktop renderer |
| Custom appearance, malformed fallback, account scope, all six vehicles and three layouts | 204 / 0 each renderer |
| Actual App entry/reentry | 6 / 0 each renderer |
| First entering-page readiness, delayed reply, cancellation and failed service action | 67 / 0 OpenGL |
| Hub layout, score refresh and backgrounds | 381 / 0 OpenGL |
| Frozen production parsing | 551 scripts / 0 failures |

The nine final gates total 968 runtime assertions plus the separate 551-script parse scan. All seven full-project final gates have the same before/after private input digest, with 30,103 inputs per run. The two minimal native gates use only the new widget/test and their project configuration. No final native run reports a script error, leaked resource or certificate-store diagnostic. Python helper compilation and task-only patch validation are recorded separately.

Initial constant-expression parsing and a thin Kart bevel triangulation attempt failed and were corrected; their logs remain. The initial linked Vulkan measurements ran to completion but were rejected when vehicle assets changed underneath them. Per-file tracking identifies changed Forklift artwork, Challenger surfaces and Volt kit resources in one rejected run. Assets/imports were then detached into disposable private copies and other source revisions pinned, after which all table controls and final gates have stable inputs. `freeze.json` also records live/frozen differences during copying; this is not a claim of whole-live prepared-asset parity or a successful 551-resource asset preflight. The ongoing authors’ cache/geometry changes were preserved, and no frozen binary was published back to live.

## Evidence, reproduction and retention

[Evidence directory](evidence/rivalry-simple-cars-2026-11-12/) contains process commands, logs, before/after input digests, final metrics, rejected attempts, selected native pictures, source controls and a source-only patch. `game/tests/test_rivalry_simple_car.gd` can run in a minimal project containing only that test and the new widget; `python scripts/qualify_rivalry_simple_cars.py NAME --renderer gl_compatibility|mobile` prepares it. Add `--full --script res://tests/test_rivalry_custom_cars.gd` for the full hub checks. The full helper initially links runtime assets/imports and rejects any detected drift; an immutable private revision is required while other authors are baking assets. The recorded baseline command uses the task-start hub source; reconstruct it from the source-only patch when reproducing later. Do not run concurrent GPU probes.

The temporary `.keep` pin was removed and the mandatory build cleaner applied. Automatic approval review rejected immediate recursive deletion of `build/rivalry-simple-cars-2026-11-12` with “blocked by policy”; no bypass was attempted. Its project copies, shader caches and test profiles remain disposable build output under the normal 24-hour active-work grace and seven-day/20 GiB retention rules, not permanent evidence. Selected comparisons and concise receipts remain in docs; redundant PNGs are listed by hash in `capture-disposition.json`. `cleanup.json` contains the exact disposition and cleaner receipt. The task-only checkpoint reverses and reapplies byte-exactly in a small disposable source fixture, with no main-index write.

Reload is required to see the new hub previews. Owner visual acceptance and actual Android qualification remain. No device query/test, APK/export, live backend request, deployment, owner-save edit or owner-process change was performed.
