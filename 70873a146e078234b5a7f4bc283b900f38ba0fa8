# Garage kit assembly sweep — 2026-10-26

Garage kit previews and direct equipped changes now use a local, bottom-to-top assembly sweep. A narrow warm highlight replaces the old fitting with the new one over 0.58 seconds, using the same eased timing style as the accepted paint effect. Only the changed categories participate. Hold-to-compare and authoritative restores remain immediate.

[Watch the GT wing assemble](evidence/garage-kit-transition-2026-10-26/kit-sweep.png), [review the native views](evidence/garage-kit-transition-2026-10-26/review.html), or [inspect commands, hashes and results](evidence/garage-kit-transition-2026-10-26/report.json).

| Requirement | Result |
| --- | --- |
| GKT01 | Local transition for Hood, Rear aero, Rims and Body kits, including previews, stock removal and direct equipped changes. |
| GKT02 | 0.58-second opaque assembly sweep with a narrow highlight; original finishes, unchanged geometry, camera, condition and live reflections remain. |
| GKT03 | One outgoing fittings snapshot, exact equipped comparison, existing account/navigation/ownership/save/purchase fences and cleanup. |
| R01 | All 43 choices, native endpoint checks, weathered-material path, resource lifetime, retained configurator/camera/paint checks. |
| Q01 | Captured motion and stills, actual commands, scoped review patch and explicit device limits. |

Runtime scope:

- `game/ui/garage_kit_transition.gd` owns the temporary fittings snapshot and shader copies.
- `game/ui/car_showroom.gd` starts, redraws and finishes the effect; replacement, paint, washing, hide and detach clear it.
- `game/ui/garage_page.gd` requests animation for kit changes and retains the shown target between choices. Equipped-geometry cleanliness checks still run before browsing. Save failures restore the authoritative kit immediately.
- `game/ui/garage_cached_thumbnail.gd` accepts the parent's optional animation argument; static cached thumbnails retain their existing behavior.

The actual car, incoming kit meshes, camera and existing world stay in place. One temporary sibling holds copies of outgoing changed frames, sharing immutable meshes. It does not enter car geometry, picking or wash binding scans. Complementary opaque clipping replaces outgoing fittings with incoming ones through a shared height cutoff; there is no full-car duplicate or added viewport. Source clearcoat, specular mode, finish priority, shader uniforms and material passes are retained. Original incoming materials are restored at completion, and the temporary snapshot is freed immediately. Active motion redraws the main car and its reflections; idle rendering stops again.

Native endpoint comparisons cover one representative change in each category, with an unchanged limit of 12 pixels exceeding 0.04 RGB distance. Final before/after differences are zero or one sampled pixel on both renderers. All 43 options and stock returns additionally retain the actual car/world/camera, unchanged mesh instances/transforms, condition and save/purchase boundaries. A lightly dirty, wet hood checks the weathering shader and exact wash/condition data. Tests also cover natural completion, rapid selection, one-snapshot ownership, compare, account changes, navigation, hide and destruction during the effect.

The first native review passed 2457 checks but showed an overly broad hood highlight. Its original frames/log remain under `initial/broad-highlight-native`. The final highlight width scales with the fitting height and uses lower emission. No assertion or tolerance was weakened.

Final focused results are **2424 headless**, **2460 Compatibility** and **2460 desktop Mobile/Vulkan**, with zero failures. Retained checks include the configurator (**647 Compatibility**), camera stability (**646 headless**), accepted paint animation (**156 Compatibility**), full parser (**1266 scripts**) and pinned import, also with zero failures. Exact commands, exit codes and elapsed times are in the report.

Actual commands run through the pinned `scripts/dev.ps1` entry point with repository-owned isolated APPDATA:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-kit-transition-2026-10-26/run.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-kit-transition-2026-10-26/run.ps1 -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-kit-transition-2026-10-26/run.ps1 -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-kit-transition-2026-10-26/run.ps1 -Test test_customisation_carousel -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-kit-transition-2026-10-26/run.ps1 -Test test_garage_preview_stability
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-kit-transition-2026-10-26/run.ps1 -Test test_garage_paint_transition -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-kit-transition-2026-10-26/run.ps1 -Test test_script_parse
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/garage-kit-transition-2026-10-26/run.ps1 -Import
python docs/evidence/garage-kit-transition-2026-10-26/record.py
```

The lossless APNG replays actual Garage progress captures using the effect's sine easing timing with endpoint holds. Existing configurator captures also exercise the actual App and three landscape sizes. `task-only.patch` is reverse-checked against current sources. Original modified runtime sources and task-start hashes remain in the evidence folder. Concurrent paint-row, paint-framing, startup, Rivalry, model, handling, track and other work is preserved and excluded from that patch.

Reload the game to see the change. Owner motion, rapid interaction, physical touch and sustained device performance remain acceptance checks. Physical-device attachment was not checked and no device test was performed. No APK/AAB, real authentication/purchase, live service mutation, deployment, staging, commit, merge or owner-process restart was performed.
