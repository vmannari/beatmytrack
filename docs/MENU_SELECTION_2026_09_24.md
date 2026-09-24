# Play selection performance — 2026-09-24

Requirements R01/G01/V03/V05/Q01. Owner requested menu profiling while investigating the intermittent race hitch separately. This slice improves cold track preparation and cached selection; it does not claim to fix the unconfirmed five-second freeze.

## Findings and changes

Selecting a new track compiles its driving data on one background worker. Current Play cards/detail use static illustrations, not live TrackShowroom scenes. Desktop tap handlers already returned in roughly 1 ms, but cold preparation took 510 ms for Speedy and 601 ms for Knot. About 234–271 ms of that work was repeated road rasterization.

`game/editor/track_compiler.gd` now computes coverage once for both the physical surface and separate paint-protection mask. Their different terrain-object values and shoulder rules remain independent. Cells already painted with the requested road kind skip redundant overlap calculations. No geometry simplification, physics/rules/content version change, or handling change.

`game/ui/track_catalog.gd` keeps the four-entry memory budget but evicts the least recently used track. Updating an existing entry no longer unnecessarily evicts another entry. Revision invalidation remains intact.

`game/ui/track_browser.gd` displays an already-cached selection immediately even when an unrelated compile is pending. Superseded results cannot overwrite it. Race remains disabled until that worker finishes, avoiding transfer of the obsolete menu compilation into gameplay. Leaving the browser during a cold compile still joins that worker; this residual navigation delay is not eliminated.

Diagnostics/tests: `game/tests/profile_menu_selection.gd`, `game/tests/test_menu_loading.gd`, `game/tests/test_compiler_raster.gd`, `game/tests/fixtures/compiler_raster.json`, `game/diagnostics/mobile_menu_probe.gd`, `scripts/dev.ps1`, `scripts/profile-menu-phone.ps1`, their generated UIDs, this report, status/plan and evidence. The phone probe now selects Speedy/Knot/Speedy and never starts a race or writes PBs/settings.

## Measurements

Graphical desktop, RTX 3090, pinned Godot 4.7.2. [Before](evidence/menu-selection-2026-09-24/before.log) and [final after](evidence/menu-selection-2026-09-24/after.log):

| Selection | Before ready | After ready |
| --- | ---: | ---: |
| Speedy, cold | 510 ms | 375 ms |
| Knot, cold | 601 ms | 481 ms |
| Speedy, cached | 5.16 ms | 5.12 ms |

Final cold-selection improvement is approximately 27% / 20%. Intermediate runs were faster (334/462 ms), so these are measured samples, not a guaranteed timing budget. Desktop activity and thermal state were not controlled. Raster-phase attribution fell from approximately 271/234 ms to 101/95 ms in the final instrumented run. Other native-data construction remains significant.

Attached DN2103, freshly exported/installed debug APK: [phone report](evidence/menu-selection-2026-09-24/phone/report.json), [inspected screenshot](evidence/menu-selection-2026-09-24/phone/menu.png), [APK hash](evidence/menu-selection-2026-09-24/phone/apk-hash.txt). Play opens in 76.535 ms, full metadata index ready at 227.535 ms. Cold Speedy/Knot ready in 690.645/873.995 ms; cached Speedy in 36.365 ms. Tap-call costs for cold tracks are 3.181/2.054 ms. Cold-selection maximum frame intervals are 69.102/58.655 ms, so this is not a constant-60-FPS claim. No matching pre-change phone run was taken in this slice; do not treat desktop percentages as phone speedups. Diagnostic markers were removed and normal play restored.

## Actual validation

Commands through the pinned entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ProfileMenus
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestMenuLoading
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestCompilerRaster
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestCompilerRaster -CompilerAudit local-corpus
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestFreeEditor
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestPieces
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ExportAndroid -QuickValidation
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action InstallAndroid
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-menu-phone.ps1
```

- Menu loading: **19 checks pass**, including immediate cached selection during a cold load, supersession, race gating, LRU eviction and revision invalidation.
- Compiler: **8 golden fixtures pass**; local-corpus audit **27 checks pass** (eight fixtures plus all 19 valid saved documents). SHA-256 fingerprints cover complete native metadata, surface/deck cells, route/width/radius arrays, kerb triangles/masks, snow-bank triangles and content hash. Fixtures cover overlapping/tapered roads, dirt/asphalt, terrain objects, protected road paint and desert conversion. Legacy-invalid local files were not modified or counted as valid tracks.
- Road pieces: **362 checks pass**, including two completed five-lap AI races and the existing creator golden.
- Android quick validation: startup/import, driving **74**, catalog **18**, menus **22** pass. Existing two-ObjectDB-instance shutdown warning remains in driving tests.
- **Unresolved test failure:** TestFreeEditor reports 42 checks / 1 failure, then a nil access at line 191 because its UI assertion looks for a removed Play-page `Edit` button. That assertion was not removed or weakened. No full-suite-green claim.

Golden fixtures were generated from the unmodified compiler snapshot, Git blob `f1c3339b0f5b2bfbc8fe47f7d8474b027d77cde8` (available at commit `4e98662:game/editor/track_compiler.gd`), using the diagnostic's write-golden mode before verification against the optimized compiler. Optional corpus/write-golden audits require that snapshot at `build/menu-selection-baseline/track_compiler.gd`; normal eight-fixture regression does not. Local diagnostic scripts and baseline snapshots are outside shipping content.

Remaining acceptance: owner menu responsiveness, broader phone/device coverage, reducing the remaining first-selection wait and frame spikes if needed, and separate reproduction of the intermittent race hitch. No race-freeze attribution follows from these menu measurements.
