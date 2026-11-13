# Obsolete code and compatibility maintenance review

12 November 2026. Review only; no application or backend source was changed.

All six findings were subsequently implemented and validated in the
[cleanup](CODE_CLEANUP_2026_11_12.md).

Six cleanup findings remain after the 7 November cleanup. The clearest waste is
in retired Garage preview code and APIs kept solely for old tests. There is no
evidence here that deleting saved-data upgrades or historical race recovery is
safe. Those paths still have an explicit purpose.

## Findings

### 1. Medium: tests keep a second synchronous upload API in production

`game/backend/cloud_tracks.gd:726` defines `queue_run`, explicitly described as
synchronous compatibility for diagnostics. Its callers are in tests, including
`test_cloud_tracks.gd:110,195` and `test_pending_input_recovery.gd:90`. Production
connects `result_saves.sink` to `queue_run_async` at line 48. Both wrappers repeat
owner/origin selection, outbox setup, notification and error handling around the
same `_queue_run_io` implementation.

Likewise, `upload_jobs` at line 886 scans every job synchronously and is called
only by tests. The active uploads dialog uses the asynchronous, paged
`upload_history` at lines 200 and 775.

**Recommendation:** migrate the fixtures to `await queue_run_async` and paged
`upload_history`, then remove these two compatibility wrappers. Tests should
provide the current background adapter instead of requiring an older API in the
shipping client. Preserve `_queue_run_io`, original operation keys, recovery
markers, accepted-run lookup and input-only journal recovery. This is removal of
test adapters, not retirement of old pending races.

**Why it matters:** maintaining two entry paths obscures which scheduling and
completion behavior the tests exercise. No current production UI stall is
attributed to these unused wrappers.

### 2. Medium: the retired part-photo renderer survives through offline tools and cache hooks

`game/ui/garage_part_photos.gd:1` is an orphaned 148-line studio/queue renderer:
there is no incoming source, scene or plugin reference in the searched app and
tooling. Its metadata keys `photo_livery`, `photo_parts`, and `painted-part-1`
also have no consumers outside this file.

The related 138-line `game/ui/compact_kit_thumbnail.gd` is instantiated by offline
bakers/capture utilities and the old thumbnail portion of
`game/tests/test_garage_customisation_speed.gd:29`. The current Garage creates
`garage_part_option.gd` rows at `garage_page.gd:1213`; the livery menu uses the
same replacement control. Outside the orphaned photo renderer, the old thumbnail
class remains referenced in runtime code only to clear and account for its
texture dictionary in `editor/editor_memory.gd:40,131`.

**Recommendation:** delete `garage_part_photos.gd` and its UID. Move the still-used
thumbnail generator to excluded offline support, update its bakers/captures, and
remove its runtime cache hooks. Keep any generated pictures with independently
verified consumers. Migrate the production-menu portion of the speed fixture to
the actual option rows; retain historical thumbnail comparisons as offline
controls where useful.

**Why it matters:** the current UI maintains no such photo cache, yet memory
accounting and several menu assertions still preserve its implementation. Those
assertions do not establish the behavior of the replacement option controls.

### 3. Low: the old part-highlight overlay is allocated but can never highlight

`game/ui/garage_part_highlight.gd:12` has no caller of `show_part`. Garage creates
one at `garage_page.gd:104` and only calls `clear` at lines 1302 and 1328.
Consequently, nothing populates `meshes` or creates its shader material. The
current `_preview_kit` path uses `garage_part_indicator.gd` and explicitly
documents the callout's purpose.

**Recommendation:** remove the highlight object, its two clears, the helper and
its private shader, with their UIDs. Update the three old
`test_customisation_carousel.gd` assertions that inspect the permanently empty
`meshes` dictionary to verify actual material preservation and the current
callout instead.

**Why it matters:** the old renderer is inert, and the old assertions can pass
without exercising an overlay or verifying that preview materials stay intact.

### 4. Low: Challenge tests use setters that the current UI never calls

`game/ui/challenge_create.gd:533` retains `_choose_mode`, `_choose_duration`, and
`_choose_attempt_limit`. Their only callers are in `test_challenges.gd` and
`test_challenges_http.gd`. The active custom-rules UI edits `_draft_rules` in
`_rule_choices` at line 394 and commits through `_commit_rules` at line 437.
The old setters directly mutate committed state and call `_update`.

**Recommendation:** drive the current rules controls and commit action in the
tests, then remove the three setters. Preserve account-scope, submission and
locked-result behavior in the current flow.

**Why it matters:** these adapters allow older tests to bypass the draft/commit
and cancellation behavior that users now encounter. This is a test-coverage and
maintenance finding, not a claim that ordinary users can call the old setters.

### 5. Low: ten additional helpers have no callers

The following are ordinary methods rather than engine lifecycle callbacks.
Reference searches found declarations only, except for the two profile names
also declared on an old test host.

| Location | Unused method | Cleanup boundary |
| --- | --- | --- |
| `game/core/app.gd:829` | `_open_profile_achievements` | Remove the obsolete shortcut and test-host stub. |
| `game/core/app.gd:839` | `_open_profile_tracks` | Current profile renders its own track section. |
| `game/core/game.gd:1013` | `ghost_description` | Settings reads `PersonalGhostRun.DESCRIPTIONS` directly. |
| `game/editor/object_browser.gd:167` | `open_properties` | Also remove `controls_requested` and its sole editor subscription at `core/features/editor.gd:310`; no other emitter exists. Keep the property editor itself. |
| `game/persistence/track_library.gd:232` | `list_wips` | Keep WIP saving/loading and the active merged `editable_entries` browser. |
| `game/ui/garage_first_draw.gd:19` | `queue_geometry` | Actual opening preparation uses `hold` and `prepare`; keep those. |
| `game/ui/rivalry_award_art.gd:31` | `crown_geometry` | Drawing uses `crown_rect` directly. |
| `game/vehicle/electric_coachwork.gd:315` | `canopy_width` | Keep the independently called `raw_canopy_width`. |
| `game/vehicle/electric_reference_body.gd:322` | `intake_edge` | Other cap/curtain geometry remains active. |
| `game/vehicle/kart_geometry.gd:134` | `loft_top` | Keep `loft_station`, which still has other consumers. |

**Recommendation:** remove the methods and the stated dead wiring. Geometry
sources participate in prepared-asset fingerprints, so their removal requires
the normal coherent provenance refresh even if generated geometry is unchanged.

### 6. Low: two backend helpers are superseded and unreferenced

- `backend/bmt_backend/rivalry.py:625`, `conditional_snapshot`: no calls or
  imports. Active endpoints call `snapshot_response`, which delegates to
  `rivalry_reads.response`. That implementation owns the live bounded read,
  ETag, cache-control and server-time response behavior.
- `backend/bmt_backend/product_worker.py:20`, `pending_exists`: no calls or
  imports. `select` and `ProductEvent` imports in that module are only used by
  this helper. The running worker uses the staged actor/shared/rollup machinery.

**Recommendation:** remove both functions and the two newly unused
`product_worker` imports. Keep the active response implementation and telemetry
queue/recovery logic.

## Compatibility that should remain

| Apparent legacy code | Evidence of a current purpose |
| --- | --- |
| Full car models and `garage_car_cache` | `ui/garage_cleanliness.gd:125` creates a full, `garage_template=true` reference for wash eligibility. Its cache restore is live. The full scene preloads in Garage entry/preloader can support this later work; they are not proven obsolete merely because the displayed car is reduced. |
| `simple_car_models` and `reduced_car_models` save keys | `LocalRecords._normalize` rejects unknown settings. Deleting the two accepted keys without a boundary upgrade could reject an entire old save, including its PBs. They are already ignored by production rendering. |
| Save schema 1, control-layout/livery upgrades and condition sidecars | These preserve supported player records and cosmetics at the persistence boundary. Their old input formats need not remain in live UI APIs. |
| Input-only upload and publication-retry recovery | These consume durable pre-update operations with original identities and clock/restart protections. No evidence establishes that all such jobs have drained. |
| Historical backend physics/manifest compatibility | `contracts.py` still feeds tickets, publications, Rivalry and job-contract selection. Historical immutable records and pending jobs require a separate retirement decision; a current client version alone is insufficient evidence. |
| `legacy_deck` | The current compiler writes it at `editor/track_compiler.gd:168`, and `BridgeElevation` reads it. This is live bridge composition data. |
| Renderer/platform branches and diagnostics | Compatibility rendering is the configured desktop/mobile renderer. Android plugins, debug probes and the support report have active entry points. |
| Android export-plugin scripts | Relative `script="export_plugin.gd"` declarations in each `plugin.cfg` are real callers that an absolute-path scan misses. |

There is also a small simplification opportunity in the ignored
`rivalry_victory_car.simple_model` widget property and in production calls that
always pass `true` to `CarShowroom.apply_model_quality`. The latter method is
still used for both qualities by offline reference tests. This review does not
recommend deleting the full-quality construction path or its reference assets.

## Method and validation

- Lexical inventory: 545 project GDScripts and 5,491 top-level functions,
  excluding tests, diagnostics and generated/build directories from the runtime
  candidate set. Caller searches also included tests, backend code, scripts,
  native code, scene/configuration text and plugin configurations. Test-only
  references and engine callbacks were reviewed separately. This is not a formal
  proof of reachability for arbitrary dynamically constructed names.
- Reviewed the prior cleanup and its preservation constraints, then traced
  current producers, replacement consumers and candidate-specific references.
- Ran the exact pinned `4.7.2.stable.official.ed1daf0bf` engine directly with
  private APPDATA/LOCALAPPDATA, an empty backend URL, Dummy audio and
  `res://tests/test_editor_shipping_parse.gd`: **555 scripts, 0 parser failures**.
  The engine also emitted the existing root-certificate-store diagnostic; this
  is not a claim of an entirely error-free log.
- Validation was limited to static reference review and parsing. No behavioral
  suite, native visual comparison, export, backend integration test or device
  test was run. Cleanup acceptance should cover the specific production flows
  above after any changes.
- Concurrent edits were detected in `vehicle/kart_steering.gd` and
  `vehicle/super_rally_model.gd` during the review. Neither is a finding target.
  They were preserved. The report does not claim a frozen whole-checkout state.

Reproduction commands:

```powershell
python docs/evidence/code-obsolescence-review-2026-11-12/scan.py
# In an isolated test shell, set APPDATA and LOCALAPPDATA to private directories
# below build/obsolete-code-review-2026-11-12, and set BMT_API_URL to an empty value.
$reviewRoot = (Resolve-Path build/obsolete-code-review-2026-11-12).Path
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' `
  --headless --path game --audio-driver Dummy `
  --script res://tests/test_editor_shipping_parse.gd `
  --log-file (Join-Path $reviewRoot shipping-parse.log)
```

The actual parser log, scan script and full lexical inventory are retained under
`build/obsolete-code-review-2026-11-12/`. The compact source receipt and raw parser
log are retained in `docs/evidence/code-obsolescence-review-2026-11-12/`.

No player files, owner processes, backend services, device state, production
assets, Git index or deployment were changed by this review.
