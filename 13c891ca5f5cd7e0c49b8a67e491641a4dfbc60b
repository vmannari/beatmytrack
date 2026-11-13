# Approved simpler cars become the production models — 2026-11-08

The owner accepts the reduced models after trying them in Garage and asks to
remove the option and use them always. This supersedes the optional model policy
in ACM01 and GSM01 and the earlier detailed-only choice in OMO01.

| Requirement | Result |
| --- | --- |
| SMO01 | Races always construct `CarVisual.simple_model=true`, including absent, false and true historical preferences. The shared constructor defaults to reduced geometry for part/photo and other incidental model consumers. |
| SMO02 | Remove the model selector, draft, reset and Apply handling from the shared main/pause Settings page, plus the obsolete title/description in all twelve locales and the POT. Ordinary graphics controls retain their existing behavior. Both retired saved boolean fields remain accepted and ignored; no owner save migration/edit is needed. |
| SMO03 | Garage, replacement cars, editable fitted parts, carousel warming, profile, news, Rivalry, podium/awards, header and parked cars use the accepted reduced geometry. Quality-independent paint, condition, camera, reflection, account and async publication guards remain. |
| SMO04 | Bake the reduced Compact header with a new `header-reduced-rest-v4` schema and its existing nominal two-pixel LODs. Regenerate all five catalogue photographs from reduced cars, record/validate the production quality in provenance and allow them as the reduced default fast path. Refresh prepared source identities and verify actual native rendering. |

The simplification algorithms and appearance budgets are unchanged. This selects
the already accepted lighter shapes. Detailed source models remain available to
offline comparison/bake tools and the temporary Garage washing sample reference.
That reference explicitly requests detailed geometry and is freed synchronously
before drawing. It cannot replace the production visible car. The existing wash
limits and header/car-cache memory bound remain unchanged.

## Changed sources

- `vehicle/car_visual.gd`, `core/game.gd`,
  `rendering/biome_shader_profile.gd`: production default, unconditional race
  selection and matching pre-construction shader context.
- `ui/settings_page.gd`, twelve localization catalogues and `messages.pot`:
  remove the obsolete choice without changing other settings.
- `ui/car_showroom.gd`, `garage_page.gd`, `garage_preloader.gd`,
  `garage_preview_cache.gd`, `garage_cleanliness.gd`: reduced defaults, permanent
  production selection, simpler preloader policy, reduced catalogue eligibility
  and explicit detailed wash sampling.
- `ui/profile_car_renderer.gd`, `rivalry_victory_car.gd`, `player_profile.gd`,
  `weekly_rivalry_page.gd`, `garage_news_menu.gd`,
  `garage/parking_hall_visual.gd`: use reduced models in remaining native views.
- `ui/header_simple_cache.gd`, header/garage/source-geometry bakers,
  `tests/check_prepared_assets.gd`, `scripts/bake_garage_previews.gd` and
  `scripts/check_garage_previews.py`: match selected production models while
  retaining explicit offline detailed references.
- Existing policy, Garage/cache, graphics/shared Settings, header, podium and
  translation tests: replace assertions for the superseded selector with the
  new permanent policy. Original geometry, pixel, cache and wash gates remain.

## Verification

All engine launches use pinned `4.7.2.stable.official.ed1daf0bf`, workspace-private
profiles, empty backend configuration/URL and Dummy audio. Native tests run off
screen. Desktop Mobile means Vulkan on the PC, not an Android-device test.

| Check | Actual result |
| --- | --- |
| Exportable production parser | 552 scripts, zero failures. |
| Graphics / shared main-pause Settings | 146 / 1,037 checks, zero failures. |
| Actual App Settings flow, headless / Compatibility / desktop Mobile | 34 / 37 / 37 checks, zero failures; removed control and persisted false/missing preferences covered. |
| All-five Game model/context/LOD policy in the frozen build | 116 checks, zero failures. |
| Actual Garage, live headless / frozen native Compatibility / frozen native Mobile | 201 / 241 / 241 checks, zero failures; 80 native normal/close stock/fitted captures. |
| Garage image-cache quality and stale-picture guards | 46 checks, zero failures. |
| Header geometry, engine/source guards, paint isolation and memory bound | 12 checks, zero failures; estimated 5,036,528 bytes within the unchanged 16 MiB bound. |
| Native header prepared/procedural appearance and actual hit expectations | Nine checks on each desktop renderer, zero failures. |
| All-five podium presentation/reflections/alpha edges | 54 checks on each desktop renderer, zero failures. |
| Detailed offline controls versus reduced construction | 88 checks, zero failures. |
| Personal ghost playback / reduced washing / driving entry-point regression | 38 / 45 / 72 checks, zero failures. |
| Removed localized messages / unrelated catalogue entries | 26 checks, zero failures; all other entries exact in twelve locales plus POT. |
| Frozen complete prepared library / catalogue photograph provenance | 468 resources, 1,925 checks, zero failures; five reduced photographs and 155 source hashes pass. |

The frozen preparation receipt and final source audit show no unexpected source
changes. Its project imports are independent copies and complete without script
errors. Task-owned live sources match their qualified snapshot versions. Other
concurrent Compact aero, shadow-baker and joint-test edits are also preserved and
excluded from the task checkpoint.

Native evidence includes the [Graphics page without the option](evidence/simple-models-only-2026-11-08/settings-gl/graphics-1280.png)
and [fitted reduced Compact in Garage](evidence/simple-models-only-2026-11-08/garage-gl/compact-fitted-reduced-close.png).

Actual command arrays, logs, input/output hashes and outcomes are retained in
[`evidence/simple-models-only-2026-11-08`](evidence/simple-models-only-2026-11-08/).
The executable runner and preparation steps are in
`build/simple-models-only-2026-11-08`.

The first Game policy check ran before rebuilding and correctly failed twenty
prepared-LOD assertions against stale resources. It retained all original
assertions. The first Settings fixture did not persist its initial false fields
before actual App startup loaded records; that one test assertion failed. Saving
the private fixture fixed the setup; the final test checks both persisted false
and absent preferences. A mistyped singular ghost-test path failed to load; the
actual plural `test_personal_ghosts.gd` suite was then run. These attempts remain
in the command evidence.

The initial full bake completed 442 modules but correctly rejected acceptance
because concurrent edits changed `compact_coachwork.gd`, `compact_glazing.gd` and
`electric_reference_body.gd` during that process. Those unrelated edits are
preserved and excluded from the task patch. Only their affected Compact/Volt
prepared resources were refreshed again, but that second attempt detected more
concurrent changes in `compact_glazing.gd`, `electric_reference_body.gd` and
`modular_car_kits.gd`. Both live-bake rejections are retained. Final qualification
uses a coherent isolated source copy, with independent mutable assets/imports and
no shared shader cache. Its rebuilt outputs do not overwrite live concurrent
work. Source and engine guards remain strict. The source-only checkpoint does
not claim that the evolving entire live workspace is export-ready.

The first snapshot copy hit Python's safe `SameFileError` when resealing a linked
immutable JSON input. It stopped before writing that input. Resealing through
temporary files and atomic replacement produced independent source copies and
one successful source-stable seal; no live input was modified.

No physical-device query/test, APK/export/install, owner-save/process change,
live/backend request or deployment is part of this task. Reload/rebuild is needed
for running clients; physical-device performance and appearance remain untested.
No additional FPS, memory or loading improvement is claimed. The reviewable
task-only Git patch leaves the main index and concurrent source changes intact.
