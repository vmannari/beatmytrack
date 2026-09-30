# Track compilation and race startup review — 2026-09-30

Requirements: R01 (canonical identity), V04/V05 (presentation/performance), Q01 (measured verification). This is a profiling/review checkpoint, not an implemented loading optimization. Runtime geometry, physics, visuals and online behavior are unchanged.

Follow-up: the road-builder optimization is now implemented and verified; see [ROAD_BUILD_OPTIMIZATION.md](ROAD_BUILD_OPTIMIZATION.md). The measurements below remain the original baseline.

## Measured result

Windows desktop, pinned Godot 4.7.2, Compatibility renderer, RTX 3090, existing saved Speedy and Knot documents. Two passes in one process. These are development-build measurements on this machine, not device budgets. Another game window was open, so treat small differences as noise. Timings exclude the countdown, network ticket request and initial process/script loading.

| Stage | Speedy | Knot |
| --- | ---: | ---: |
| Compile document | 322–323 ms | 424 ms |
| Instantiate race and synchronous ready | 5688–5742 ms | 2177–2204 ms |
| Race instantiation through first completed draw (includes ready) | 5834–5913 ms | 2268–2332 ms |
| Separate instrumented visual build | 5601 ms | 2033–2082 ms |
| Road visuals within that build | 5450–5459 ms | 1683–1719 ms |
| Road outlines/edge generation loop | 3096–3129 ms | 566–583 ms |
| Shoulder overlap resolution/emission | 2021–2030 ms | 645–671 ms |

Separate attribution builds are not extra production stages; do not add their times to race-ready time. Raw evidence: `docs/evidence/track-load-2026-09-30/track-load-profile.log` and `menu-selection-profile.log`.

Existing menu profiler: Speedy selection 361 ms, Knot 470 ms, cached Speedy 5.1 ms. Worker compilation kept the worst observed menu frame below 15 ms. Canonical kerb construction accounts for approximately 149–217 ms inside compilation; rasterization approximately 92–93 ms in the separate menu probe. Those are useful secondary targets, but optimizing only compilation misses the multi-second startup cost.

## Code findings

- `game/ui/track_browser.gd`: selection already compiles on a worker. `TrackCatalog` retains four compiled tracks; the app retains the catalog across menu visits. Cloud document caching stores source documents, not finished meshes.
- `game/core/app.gd::_start_race`: reuses the selected compiled track. Signed-in cloud races first await a server ticket. It then instantiates the scene and calls `add_child`, synchronously invoking race setup.
- `game/core/game.gd::_build_ground`: creates and fully builds a new `NativeTrackVisual` every race. No race visual cache or cooperative loading is used here. The editor already has a separate bounded visual cache and sliced build path.
- `game/track/native_track_visual.gd::_build_creator_roads`: generates outlines, densely samples edges at 0.20 m, constructs shoulders, then clips overlaps. `_commit_creator_road` also commits a temporary mesh and walks its vertices again to construct the final mesh.
- `game/track/shoulder_mesh.gd::emit`: already has spatial bins, but still performs per-triangle candidate collection, intersection tests, repeated fragment subtraction and triangulation. Simply adding a spatial index is not a new solution.
- `game/track/visual_road_join.gd`: rebuilds neighboring outlines/fillets for individual pieces and margins. Visual kerbs also construct cosmetic geometry separately from canonical collision kerbs; they cannot simply be substituted without changing the accepted appearance.
- `game/tests/profile_race_start.gd`: starts its timer after `root.add_child(game)`. It measures countdown/driving frame pacing, but misses the synchronous scene-building delay. The new `ProfileTrackLoad` fills this gap.

## Recommended implementation order

1. **Bounded cache of immutable visual resources.** Key by canonical content hash, visual-kit version, theme and relevant rendering options. Reuse mesh/texture resources while creating fresh race nodes and resetting dynamic tyres, lights and race state. Invalidate on edits/version changes and cap memory. This targets most of the repeated 2–6 second scene build; exact savings remain unmeasured. Avoid retaining a complete live race with old state.
2. **Reduce cold geometry work.** Cache per-build piece outlines, join cuts, samples and cumulative bend distances. Profile the edge loop at finer granularity before changing its math. Optimize shoulder candidate/fragment work while preserving overlap ownership and triangle coverage. Avoid the second mesh vertex pass where equivalent winding/normals can be emitted directly. Verify mesh/material equivalence and regression screenshots for tight joins, desert shoulders, winter and bridges.
3. **Prepare visuals during selection with a responsive loading state.** Reuse the existing cooperative build approach, keep the menu visible, cancel superseded requests, and begin countdown only after installation. This shifts/hides latency and prevents a freeze; slicing by itself does not reduce total work. Do not move active scene-tree/GPU operations blindly onto the compiler worker.
4. **Secondary compiler/cache improvements.** Cache validated compiled content with explicit compiler/rules invalidation, or reuse intermediate arrays instead of raster-to-rectangles-to-raster reconstruction. Benchmark disk costs and serialization first. Preserve exact canonical cells, kerbs, hashes and replay outcomes; never bypass cloud integrity checks or reuse race tickets.

## Reproduction and outcomes

Commands actually run from repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ProfileMenus
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ProfileTrackLoad
& "$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" devices
```

Both final profiling commands completed successfully. The load probe ran two full race constructions and first draws for each track and checked reconstructed cells/routes. During profiler development an overly broad instrumentation replacement produced an undeclared `road_start` parse error; the probe was stopped and replacement restricted to `_build_creator_roads`, then the complete probe passed. Instrumentation exists only in transient script copies, not shipping runtime code.

Optional: `ProfileTrackLoad -Track <local-track-id>` profiles another saved track. Default fixtures must exist in the local library; the command reports an error if missing. Stage numbers in the raw log are cumulative checkpoints in the marker arrays in `game/tests/profile_track_load.gd`; road-specific lines are cumulative from road-build entry.

Changed files: new `game/tests/profile_track_load.gd`; `scripts/dev.ps1` adds `ProfileTrackLoad`; this report and evidence; status entries in `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`. No production optimization or visual change was made, so no before/after speedup or visual acceptance is claimed. No phone was attached (`adb devices` empty), and no Android export/device test was performed. Network ticket latency, large cloud-only circuits, memory budgets and release/mobile timings remain to be measured. No physics regression suite was run for this profiling-only change.
