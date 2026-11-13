# Dedicated carousel thumbnail studio enabled — 2026-11-03

The owner chose to retain the studio after confirming that desktop and mobile project defaults both use Compatibility. The production carousel now uses the dedicated one-view studio for native cache misses and the five bundled factory pictures. The full interactive Garage retains its original room, lights, reflections, career wall, washing and controls. Loading still uses the approved animated model ghosts.

This supersedes the keep/reject decision in [the earlier experiment](THUMBNAIL_STUDIO_EXPERIMENT_2026_11_03.md). That experiment's Compatibility comparison measured 35.143→19.174 s for the first five-picture batch (45.4% faster), and 1.384→1.290 s for the median of two later uncached batches (6.8% faster). Later all-PNG completion was 2.8% slower. The Mobile renderer comparison remains in that report as secondary evidence; it is not the project's selected renderer. These measurements concern thumbnail preparation, not a measured reduction in complete game startup or phone loading.

## Integration

- `garage_preview_cache.gd` selects `garage_thumbnail_studio.gd` and tolerates its absent reflection rig when pausing native work. Idle/input/focus/navigation gates, read priority, cancellation, bounded PNG write overlap and stale appearance guards remain.
- The studio retains the full exact car with saved paint, stickers, fitted kits and condition, at the previous 2048×512 capture size with 4× MSAA. It builds a plain curved backdrop, low-cost platform and static soft contact shadows in one viewport, without constructing workshop geometry or planar reflection captures.
- `garage-thumbnail-studio-v3` gives saved thumbnails a new cache namespace. Existing workshop PNGs cannot publish under the new identity. Stock images were regenerated through the same production studio; the baker records its source provenance. Build identity inputs now explicitly include the new studio, with its shader already covered by the shader rule.
- The live preloader no longer captures a workshop thumbnail or passes one to the carousel. Its temporary thumbnail camera/readback/restore phases were removed; full-scene geometry warming and four final live-view draws remain. Its obsolete screenshot memory allowance was removed too. Garage entry still adopts only a fully prepared live studio and covers unfinished entry with the model ghost.

The original full renderer, main `CarShowroom`, loading ghost sources and previous experimental fixtures are retained. The new production scripts have distinct Godot UIDs from the archived fixtures. Generated build identity and project renderer settings were not rewritten by this task; a normal build refresh includes the new sources.

## Verification and evidence

`docs/evidence/thumbnail-studio-enabled-2026-11-03/` contains private task-start snapshots, native logs/receipts, current bundled picture hashes and screenshots. **284 native Compatibility checks passed with zero failures**, with sixteen native captures plus the five regenerated bundled images. [summary.json](evidence/thumbnail-studio-enabled-2026-11-03/summary.json) is derived by `summarize.py`. The native checks cover:

- All five customized cars through the actual production service, exact livery/parts/body material/dirt, one viewport, full capture resolution and AA, capture gating, cache-key migration and completed PNG writes.
- Five-car PNG persistence across two processes, byte-identical decoded pixels and zero native captures on reuse, including mixed missing/stored pictures and exact prepared-picture persistence.
- Read/write overlap, paused/resumed live warming, preserved original live camera/reflections, actual-App deferred entry/ghost replacement, stale appearance/owner fencing and incomplete preload rejection.

Counts: production service 94/0; pipeline 3/0; persisted seed/reuse 33/0 and 45/0; live warm scheduling 16/0; actual-App deferred entry 61/0; prepared/partial first entry 32/0. All five reused PNGs are pixel-exact, with zero new captures and 160.279 ms readiness in the reuse fixture. The preloaded selected-car photograph and a fresh canonical dedicated-studio capture are byte-identical in the first-entry fixture. These are bounded desktop fixture results, not game-startup promises. See the [actual Garage with completed carousel](evidence/thumbnail-studio-enabled-2026-11-03/deferred-app/pictures-ready-1280x720.png).

The production integration timing rows are retained as diagnostics, not a new paired speedup result. Vehicle assets and build metadata continued to change in the shared workspace; the original A/B experiment and the integration runs use their recorded source states. Per-run receipt hashes disclose changes. No phone, exported-build, cold-driver, FPS or total process memory claim is made.

The initial bake correctly failed its source-stability gate when concurrent Electric model code changed. Its partial PNGs and log were superseded by a successful final bake; the provenance checker then passed all five images and 150 source hashes. A checker invoked before that final bake finished saw the previous stale manifest; its later run passed. An initial PowerShell source-input check hit the host's script execution policy; the checked-in read-only helper succeeded using process-local `-ExecutionPolicy Bypass`. Native logs retain the host certificate-store error.

From the workspace root:

```powershell
python docs/evidence/thumbnail-studio-enabled-2026-11-03/run_check.py production
python docs/evidence/thumbnail-studio-enabled-2026-11-03/run_check.py bake-final --script res://../scripts/bake_garage_previews.gd
python docs/evidence/thumbnail-studio-enabled-2026-11-03/run_check.py import-assets --import-assets
python scripts/check_garage_previews.py
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/thumbnail-studio-enabled-2026-11-03/check_source_identity.ps1
python docs/evidence/thumbnail-studio-enabled-2026-11-03/verify.py
python docs/evidence/thumbnail-studio-enabled-2026-11-03/summarize.py
python docs/evidence/thumbnail-studio-enabled-2026-11-03/checkpoint.py
```

Use fresh labels/cache directories to retain earlier receipts when repeating. All unattended Godot commands run through `scripts/run_no_crash_dialog.py`, pinned Godot 4.7.2, isolated APPDATA and a bounded wait. The task-only source/binary patch is checked forward, reverse and byte-exact in an owned build directory without writing the main Git index.

Reload and owner appearance/device acceptance remain. No physical-device query/test, APK/export, owner-save/process change, backend/live mutation or deployment occurred. Concurrent work was preserved.
