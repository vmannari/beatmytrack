# Approved optimized models are the standard — 2026-11-07

The owner explicitly selects the newly optimized LOD models from the comparison
for every production view. This supersedes the older optional “Simpler car models”
setting. The older, more aggressively reduced variants are not the selected design.

| Requirement | Implementation |
| --- | --- |
| OMO01 | Race construction always selects the approved optimized models. Both historical values of `simple_car_models` produce the same standard car and native preparation context. |
| OMO02 | Remove the obsolete selector from main-menu and pause Settings. Preserve old saved fields harmlessly; no save migration or owner-data edit is required. |
| OMO03 | Profile/header, Rivalry, news and parking-hall consumers select the standard models. The shared podium renderer ignores its retained legacy widget flag. Garage already uses the approved optimized models. |
| OMO04 | Rebuild the Compact header template with standard geometry and LODs, invalidate old templates through a new schema, refresh prepared assets/provenance, and validate actual model selection and native presentation. |

`CarVisual.simple_model` is the internal flag for the **older coarse variant**.
Production callers now select `false`: the approved regular models with the new
automatic LODs. Original master vertex/index buffers remain within those resources
for close-view selection. This change removes the alternative production choice;
it does not strip the full-detail level from the approved LOD resources. Legacy
variants and constructor switches remain available to offline comparison/bake
tools. There is no deletion of archived models or owner content.

Race/Garage/podium/header views keep their existing cameras, lighting, material
staging, appearance, condition and account fences. The stock header's schema is now
`header-optimised-rest-v3`; its source/engine/construction guards still reject old
or mismatched resources. The approved optimized header is estimated at 9,172,704
bytes by the existing conservative car-cache accounting, within its unchanged
16 MiB bound. Existing generated header visual identities include the renderer
factory changes, so older equipped pictures are invalidated without deleting
their owner's saves. No new setting or explanatory game UI was added.

Runtime changes:

- `core/game.gd` and `rendering/biome_shader_profile.gd`: ignore legacy preference
  selection and report the actual standard model before/after car construction.
- `ui/settings_page.gd`: remove the draft, control, reset and Apply handling for
  the obsolete choice. Existing record parsing remains compatible with old saves.
- `ui/profile_car_renderer.gd`, `rivalry_victory_car.gd`, `garage_news_menu.gd`,
  `player_profile.gd`, `weekly_rivalry_page.gd` and
  `garage/parking_hall_visual.gd`: standardize model selection. The podium widget's
  old property remains accepted by existing internal callers but cannot select a
  coarse car.
- `ui/header_simple_cache.gd`: retain its existing entry point with the new
  standard-model guard/schema; its offline baker now prepares standard LODs.

The focused all-car test constructs actual Game scenes for all five current
vehicles with each historical preference value. It checks prepared LOD use,
canonical snapshot stability, ordinary lap count, native preparation identity and
unchanged wash mapping. Retained Settings/header/podium tests were updated where
their previous expectation explicitly required the superseded selector/coarse
variant. Other checks and appearance thresholds remain intact.

Initial validation passes were: model policy 55/0, header geometry/guards 12/0,
graphics Settings/race lifecycle 155/0, shared pause/main Settings 1,037/0, actual
Settings→Garage→race 14/0, and all-five-car podium quality 54/0 each desktop
renderer. Graphics Settings captures cover 1280×720, 960×540 and 1600×720. Two
App-based native suites also emit two-ObjectDB/one-resource shutdown diagnostics;
these are retained and are not classified as an established pre-existing issue.
The independent policy/header/podium checks did not produce those diagnostics.

A concurrent edit to `vehicle/prepared_car_cache.gd` changed the model source
graph after the initial targeted Compact refresh. A subsequent native header
comparison retained tiny image differences but correctly failed its two positive
cache-hit assertions (9 checks/2 failures). The source guard rejected the stale
template; it was not disabled or relaxed. The concurrent edit is preserved and
excluded from this task's owned source changes. The complete library was rebuilt
against that current graph and the affected checks were rerun before acceptance.
The initial and final command receipts/logs are retained separately.

Final source-stable results:

| Check | Actual result |
| --- | --- |
| All-five-car Game policy, both saved preference values | 55 checks, zero failures. Prepared LODs are actually used. |
| Optimized header geometry, source/engine guards and isolation | 12 checks, zero failures. |
| Native header custom paint and fitted appearance/cache hits | 9 checks, zero failures; two stock/custom-paint template hits and the expected fitted fallback. |
| All-five-car podium presentation, Compatibility / desktop Mobile | 54 checks each, zero failures; 14 final native captures including alpha-edge and Garage comparisons. |
| Complete prepared library | 468 resources, 1,925 checks, zero failures. |
| Native photograph provenance | Five images/157 source hashes pass. All five PNGs remain byte-exact to this task's start. |

The final model-input receipt contains no source changes during preparation or
through the final checks. A concurrent Rivalry heading translation is also
preserved and excluded from the task-only source hunk; only this task's model
selection line is included for that shared file.

All engine launches use pinned `4.7.2.stable.official.ed1daf0bf`, scoped crash-dialog
suppression, isolated workspace profiles and an empty backend URL. Graphical tests
are positioned off screen; Mobile is the desktop Vulkan renderer. Actual commands,
source hashes, outcomes and captures are under
[`docs/evidence/optimized-models-only-2026-11-07`](evidence/optimized-models-only-2026-11-07/).
The task runner and preparation scripts are under
`build/optimized-models-only-2026-11-07`.

No device query/test, APK export/install, owner-save/process change, live/backend
request or deployment was performed. Owner/device appearance and frame-time
acceptance remain. This is a consistency change, not a new loading/FPS or memory
speedup claim: views formerly using the coarse variant can draw more geometry
than before. Concurrent source/index work is preserved; the reviewable task-only
source/binary checkpoint excludes generated whole-workspace build identity files.
