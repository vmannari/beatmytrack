# Baked road loading and the one-second target — 2026-09-30

Requirements: R01 (canonical track identity), V04/V05 (presentation/performance), Q01 (measured acceptance). Follows `ROAD_BUILD_OPTIMIZATION.md`.

## What is achieved, and what is not

Prepared tracks now load their road resources after an app restart. On the same pinned Godot 4.7.2 Windows/RTX 3090 desktop, a fresh process with on-disk artifacts produced:

| Measured phase | Speedy | Knot |
| --- | ---: | ---: |
| Compilation, during selection | 0.352 s | 0.446 s |
| Race scene setup | 0.335 s | 0.520 s |
| Race setup through first completed draw | **0.558 s** | **0.644 s** |
| Sum of compilation and first-draw measurements | 0.910 s | 1.091 s |

The race-start phase is below one second for these two prepared desktop tracks. This is **not a universal sub-second claim**: the combined measured phases still exceed one second for Knot, and measurements exclude downloads, online race-ticket requests, initial application/resource startup and the intentional race countdown. The real app already holds the compiled selection when Race is pressed.

A separate process with no matching disk artifact measured 2.939 s Speedy / 1.893 s Knot setup, including writing the initial artifact. First draw was 3.199 s / 2.021 s. A forced uncached run without disk writes measured 2.729 s / 1.850 s setup. Cold builds remain above the target. Comparisons are small samples under ordinary desktop activity, not device guarantees; do not infer a steady-state frame-rate change.

The next architectural step for reliably fast **first encounters with downloaded tracks** is to bake versioned presentation assets when tracks are published and deliver them ahead of the Race action. That requires a trusted content pipeline and validation against the track/visual versions; it is not implemented here. It would remove client geometry cooking from that path, but network and phone measurements would still be needed. Reducing UI freezes through sliced loading alone would not reduce total preparation time.

## Implemented

- `game/track/shoulder_mesh.gd`: large synchronous builds split independent triangle work across at most four CPU workers. Workers read frozen geometry, each owns its candidate cache, and return only point/UV arrays. The main thread combines results in original triangle order and creates rendering data. Small jobs and cooperative editor builds retain the serial path. The serial/parallel paths share the same clipping helper. This follows the separation required by Godot's [thread-safe API guidance](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html): active scene/GPU work remains on the main thread. No canonical simulation work was moved or modified.
- `game/track/road_mesh_artifact.gd` and `road_mesh_disk_cache.gd`: compressed, locally generated presentation artifacts under `user://cache/road_meshes_v1`. Keys include format, exact engine version, canonical content hash, visual-kit version, theme, palette and night-light partition setting. Artifacts contain road meshes, materials/textures, transforms/render flags and road metadata; they are not an accepted UGC input format. Player track JSON never supplies resource-cache paths.
- Artifact writes use temporary files and renames. A bounded SHA-256 sidecar check rejects damaged/incomplete files before loading engine resources; misses fall back to building. Completed artifacts are limited to eight files / 96 MiB, with a 32 MiB per-file/admission limit. Pruning recognizes only generated hash filenames and retains the just-written entry. Ordinary track files are untouched. The existing two-entry / estimated 32 MiB memory cache remains.
- `game/track/native_track_visual.gd`: consumes saved artifacts and admits them to the memory cache. Fresh scene nodes still own each race. Unsaved editor rebuilds do not write disk artifacts. Saved editor tracks can persist an already completed road or request that the pending editor build save its result once ready; pending requests are capped at eight. Oversized/non-cacheable tracks retain the uncached path.
- `game/core/app.gd`: successful explicit saving of a valid circuit requests that preparation. Save does not synchronously rebuild road geometry. If an unfinished editor build is cancelled, its artifact may still need preparation on a later visit.
- `game/tests/profile_track_load.gd`: `-Screen cold` disables disk artifacts; `-Screen ready` measures real setup/first draw without extra attribution builds. The default still includes uncached stage attribution.
- `game/tests/test_road_cache.gd` / `scripts/dev.ps1`: `TestRoadCache` covers four biomes, exact material parameters and texture bytes after a real resource save/load, metadata/render flags, edit/version/partition invalidation, corrupt/interrupted writes, replacement, saved-editor preparation and bounded pruning that preserves unrelated files. `test_road_build.gd` explicitly disables disk reads when checking cold geometry.

Physics, compiler/rules identity and track-kit-89 output remain unchanged. Disk resources are treated as immutable, like the preceding memory cache. Changing presentation output in a later revision requires the visual-kit/cache key to change.

## Commands actually run and outcomes

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ProfileTrackLoad
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ProfileTrackLoad -Screen cold
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ProfileTrackLoad -Screen ready
# Repeat -Screen ready in a new process to verify restart loading.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestRoadBuild -Screen local
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestRoadBuild
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestRoadCache
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestShoulders
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestRoadApproval
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestSurfaceProfile
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureStyle -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_3e26605a8a90165e.json"
& "$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" devices
git diff --check
```

- Cold exact geometry: default golden/cache suite **33 passed**; direct original-builder/local-track comparison **47 passed**, including Speedy/Knot. Baseline goldens were not regenerated.
- Disk cache: **66 passed**. No cache script errors in the final run.
- Shoulder ownership/union regression and **71 join / 18 contour** checks passed.
- Editor road approval: **38 passed**, including sliced/unsliced equality, supersession, save and exit. The parallel test run's slowest editor frame was 127 ms; editor frame pacing is not certified by this slice.
- Graphical surface profile: **928 passed**. Cached Speedy capture completed and was inspected; canonical cells remained intact. The existing gravel normal diagnostic still includes intentionally sloped clod facets, as in the original capture; road/ground top-face counts remain zero.
- One attempted early polygon-intersection shortcut failed exact mesh equality in all fixtures and was removed. The retained worker implementation passes the unchanged golden output. The first disk test also exposed an overly small mesh-count guard for tiled night roads; the guard now accommodates the existing bounded night tiling while retaining the byte cap, and the full disk suite passes.

Evidence is in `docs/evidence/road-cache-2026-09-30/`: `track-load-profile.log` is the final fresh-process prepared run, `track-load-bake-ready.log` is the matching first bake, and `track-load-cold-final.log` disables disk use. Earlier development probes are retained separately. Timing probes ran separately from regression batches.

No phone was attached, Android export/device testing was not performed, and there was no backend deployment. Remaining acceptance: real phone timings and peak memory, new/downloaded-track preparation, slow storage/network behavior, and a strict end-to-end latency budget. A full physics regression was not run because canonical code did not change.

![Prepared Speedy road loaded for desktop review](evidence/road-cache-2026-09-30/saved-speedy.png)
