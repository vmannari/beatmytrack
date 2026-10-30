# Restore the original live Garage entry (2026-10-27)

The owner reports that the first Garage has the wrong liveries and cannot move, and identifies the optimisation work as the regression. The photo-first opening was the cause: it loaded the catalogue's stock PNG instead of the saved appearance and blocked drag input until its preparation job finished.

The production App now uses the original `CarShowroom` from entry. The actual car receives saved colours, pattern, stickers, fitted parts and condition through the existing Garage builder; its normal input handler is connected immediately. No stock cover, alternate material rendering or staged reveal is selected. Original lights, glass, shadows, floor/pedestal reflections and camera remain. Ready-world retention, catalogue-card caching, native model caches and account/save fences remain.

This owner correction supersedes the photo-first entry, deferred-construction and deferred-tools contracts in the earlier opening/reflection tasks. It preserves their requirement for original rendering quality. The older optional covered-entry helpers remain unchanged for historical diagnostics; production no longer selects them.

| Requirement | Result |
| --- | --- |
| GLE01 | Restore the original main live showroom; no `GarageOpeningPicture` on entry. |
| GLE02 | Saved appearance is applied to the native car; first drag and viewport-routed touch drag rotate it. |
| GLE03 | Preserve original quality, seven-car browsing, retained returns, ownership and saved data. |
| R01 / Q01 | Reproduce the regression, verify native pixels/input/reflections, retain source hashes and a scoped patch. |

The behavior change removes the two App assignments that enabled progressive entry and its preparation callback, with one explanatory comment. `garage_page.gd`, `car_showroom.gd`, the optional opening helper, native car cache, reflections and `car_visual.gd` remain byte-identical to this task's start. Concurrent simulation changes are preserved and excluded. No shaders, geometry, camera, economy, save format or backend code was edited by this task.

## Verification

All commands use pinned Godot `4.7.2.stable.official.ed1daf0bf`, disposable profiles and an empty API URL. [The report](evidence/garage-live-entry-2026-10-27/report.json) contains complete command/environment records, source hashes, raw failures, screenshots and the reverse-checked scoped patch. Reproduce with `python docs/evidence/garage-live-entry-2026-10-27/run_checks.py LABEL SCRIPT MODE`.

- Task-start regression: five checks / four failures. The first native car is absent, a stock cover is present, progressive entry is selected and the first connected drag does nothing.
- Corrected focused test: 46 headless / 50 Compatibility / 50 desktop Mobile checks pass. The test seeds nondefault saved paint, pattern and a sticker; checks all seven native cars/materials; routes touch through the actual viewport; verifies image changes after paint/orbit; and checks retained returns, owner replacement and unchanged saved appearance/equipped selection.
- Retained actual App: 141 checks pass. Retained reflection test: 26 Compatibility checks pass, including actual deck/floor pixel differences, moving reflections and lifecycle/persistence checks. All 1,321 scripts parse.
- Preferred `scripts/dev.ps1 -Action CheckScript` succeeds through a process-local execution-policy bypass. Its normal generated build identity/version output is recorded separately; the source rollback patch does not fold in generated metadata or unrelated concurrent changes.

Native images show the saved red striped/stickered Compact in the original reflective studio and the changed camera view after rotation. Small carousel cards still use their existing catalogue fallback while exact saved thumbnails resolve; this task restores the main interactive preview.

## Timing and acceptance limits

The live renderer is restored, including its existing cold driver cost. These isolated desktop measurements include the normal menu transition and native target settling; they are not phone results:

| Renderer/profile | Entry callback | First live page |
| --- | ---: | ---: |
| Compatibility, fresh shader profile | 196 ms | 27.55 s |
| Compatibility, reused shader profile | 219 ms | 2.68 s |
| Desktop Mobile, fresh shader profile | 1.39 s | 7.36 s |
| Desktop Mobile, reused shader profile | 914 ms | 1.63 s |

Correct saved 3D and working controls replace the misleading still image. This is not an instant-entry or cold-stall fix, and no earlier 250 ms callback guarantee is claimed for synchronous original construction. The sandbox certificate-store error is retained separately from test failures. No failing appearance, input or pixel assertion was relaxed.

Reload/rebuild and owner acceptance of saved appearance, dragging, first-entry latency and device behavior remain. No device attachment check or physical-device test, APK/AAB, real authentication/purchase, owner-save/live backend mutation, deployment, Git staging/commit/merge or owner-process restart was performed.
