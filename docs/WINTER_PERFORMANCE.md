# Winter PC performance check

2026-10-11, owner-requested WE24 / WE20-WE23 / G01 / R01 / Q01. Final visual kit 132. The reported sustained PC slowdown was not reproduced in these local driving samples. A substantial cold-road construction cost was reproduced and reduced without changing any road mesh buffers.

## Measured findings

Windows, pinned Godot 4.7.2, OpenGL Compatibility, RTX 3090, native 3840×2160, 100% render scale, existing 2× MSAA. VSync and frame caps are disabled only inside the explicit diagnostic. Real 120 Hz canonical RouteDriver driving, actual camera/HUD, snow, trails, shadows and audio run normally; the diagnostic never starts a ticket, uploads a score or changes the cached track document. Unscored diagnostic laps use a high finish limit solely to prevent results interrupting sampling.

The cached published **Slippery** Winter document has 11 pieces, including bridge, hairpins, bends and taper. Four independent restarted 20-second passes, each after warmup:

| Pass | Frame median | Frame p95 | Frame p99 | Worst frame | GPU median | Frames >16.667 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Full scene | 2.742 ms | 3.774 ms | 5.275 ms | 12.129 ms | 2.411 ms | 0 / 7066 |
| Wind hidden | 2.503 ms | 3.442 ms | 4.073 ms | 6.737 ms | 2.168 ms | 0 / 7792 |
| Banks hidden | 2.898 ms | 3.817 ms | 4.343 ms | 6.667 ms | 2.772 ms | 0 / 6740 |
| Full scene repeated | 2.741 ms | 3.687 ms | 4.552 ms | 6.736 ms | 2.471 ms | 0 / 7137 |

Each pass advances 2400 canonical ticks and ends about 79–80 metres from its initial position. These are moving samples, not complete five-lap races or a benchmark of every part of the track. Full-scene submission is about 572k primitives / 375 draws including shadows and HUD. Hiding banks changes the snow's opaque depth intersections, so the bank-off GPU difference cannot be treated as an isolated bank cost. Wind's GPU difference here is approximately 0.24–0.30 ms at 4K. This high-end GPU does not establish low-end PC or Android performance.

The smaller creator fixture was also profiled at 1920×1080 and 3840×2160 using full/wind-off/bank-off/flat-world/shadows-off/full-repeat passes. Before optimization, 4K full medians were 3.076/2.909 ms; after, 2.797/2.848 ms. GPU medians stayed around 2.44–2.50 ms. The variation does **not** establish a large sustained FPS gain. Flat-world removes material masks as well as detail and is only a broad shader-cost bound. Raw engine process/physics monitors update periodically and include transition/compilation work; frame intervals and explicitly instrumented game counters are the useful steady-state evidence here. Concurrent desktop activity is not controlled.

## Changes and cold-build result

- Indexed bank geometry removes duplicate vertex-shader work while retaining all triangles, positions, normals and material coordinates. The fixture bank has 139872 index entries but only 27301 vertices; Slippery has 284352 entries / 54606 vertices, approximately 81% fewer vertices than the equivalent unindexed triangle list. This is buffer reduction, not a claim of 81% faster frames.
- Snow-only bank areas skip road ice/frost texture sampling. Larger snow masses and their outer apron retain the original matching snow material; only the irregular toe needs the ice transition.
- Per-road-piece coordinate and nine-point bank-row caches avoid recalculating the same attributes for neighbouring triangles and sections. These temporary caches are released as pieces finish and do not add per-frame work.

A separate headless road-only benchmark disables memory/disk road reuse and alternates the pre-optimization archived renderer and final renderer on the same already compiled Slippery document:

| Pass | Before | After |
| --- | ---: | ---: |
| 1 | 7764.751 ms | 3441.802 ms |
| 2 | 7648.571 ms | 3387.715 ms |

Average 7706.661 → 3414.759 ms, **55.7% less cold road-building time**. Every complete mesh buffer agrees byte-for-byte: SHA256 `d293dc104ed14a286a957d71b07b114ddab46dead95ef75fd4e0b94b9928adfc`, 233574 vertices / 284352 indices across all road surfaces. This times cold road construction alone, not whole race startup, shader compilation, editor end-to-end latency or steady frame time. Existing sliced preparation and persistent caches remain. Cold construction still costs several seconds on this track.

## Files, actual commands and evidence

Runtime changes are in `game/track/native_track_visual.gd` and `winter_bank.gdshader`, as part of [the bank/ice pass](WINTER_FROST_FRINGE.md). No canonical physics, collisions, compiler, rules or backend change.

`game/tests/profile_winter_desktop.gd` is an explicit local diagnostic. Actual runs through `scripts/dev.ps1 -Action TestScript -Graphical` used:

- `-ScriptPath res://tests/profile_winter_desktop.gd` for the pre-optimization fixture.
- Same, `-TestArgument @('--tag=optimized')` after indexing/snow-only shading.
- Same, `-TestArgument @('--tag=slippery','--document=<cached Slippery JSON>','--4k','--seconds=20','--modes=full,no_wind,no_banks,full_repeat')` for the larger published track. The original document is read only; its SHA256 is `cd0b5ca436fd1dd3e15256ba506fa528792e351bd6df13dbbaa49681d8e75262`.
- `-ScriptPath res://tests/profile_winter_road_build.gd -TestArgument @('--document=<same cached Slippery JSON>')`, headless, for the alternating cold builds and exact mesh-parity fence. The archive initially lived at `build/winter_frost/before-uv-cache.gd`; the same bytes are now retained at `docs/evidence/winter-performance-2026-10-11/before-uv-cache.gd` for repeatability. Its anonymous-script adapter guards an unrelated typed scenery API with an assertion; only road construction is invoked. The initial unadapted archived script failed that named-class type check; no product invariant or parity assertion was weakened.

[Full Slippery measurements](evidence/winter-performance-2026-10-11/desktop-slippery-gl_compatibility.json), [fixture before](evidence/winter-performance-2026-10-11/desktop-gl_compatibility.json), [fixture after](evidence/winter-performance-2026-10-11/desktop-optimized-gl_compatibility.json), [cold-build parity](evidence/winter-performance-2026-10-11/road-build-slippery.json). Actual command logs and scoped checkpoint receipts are saved alongside the frost evidence.

Final visual checks: fresh Compatibility environment 101 / Mobile Vulkan 100 checks, wind 47 checks on each renderer, all zero failures; prior app smoke 99 checks and actual bridge capture pass. Fresh-road checks disable only the diagnostic's disposable cache, preserving owner cache/files. Actual material/driving/rotated captures are linked in the art report.

Remaining acceptance: reproduce the owner's exact running track/settings and any intermittent pause, compare editor changes and cold first-corner shader behavior, and measure lower-end PC/Android sustained frame time. No phone/device performance run, export/install, full Validate, backend deployment or live writes were performed. Restart the client for kit 132. The isolated task checkpoint preserves unrelated/main-index work.
