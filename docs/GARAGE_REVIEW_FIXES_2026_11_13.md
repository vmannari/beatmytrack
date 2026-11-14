# Garage review fixes — 2026-11-13

The three P2 findings in [the third Garage review](GARAGE_MODEL_REVIEW3_2026_11_13.md) are corrected. Requirements: **GRF01** preserve accepted assets when generation is rejected; **GRF02** remove only generated-name noise from workshop equivalence; **GRF03** validate workshop provenance before export.

## Changes

- `scripts/bake_garage_previews.gd` renders six PNG candidates privately. It checks source files, disk geometry revisions, prepared-scene hashes and every existing output before publication. Excluded photographs remain protected. The producer and transaction helper are included in provenance. `--output=` supports isolated validation.
- `game/tests/support/asset_bake_transaction.gd` serialises cooperating producers with an exclusive directory. Accepted files remain untouched during generation and validation. Publication retains backups, installs the manifest last, and rolls back handled file-operation failures. An interrupted run retains its lock, backups and a small `previous.json` recovery receipt for inspection. It never guesses whether a previous writer is dead.
- `game/tests/bake_garage_architecture.gd` uses that same transaction, hashes its declared inputs before construction, and verifies them before publication. The generator and helpers are themselves inputs. `garage_architecture_car.gd` supplies the pedestal occupant without constructing an unrelated vehicle model.
- `game/tests/test_menu_responsiveness.gd` delegates its existing geometry/finish comparison to `support/garage_geometry_comparison.gd`. Only the allocation number in Godot-generated `@Class@number` names is ignored. Authored names, transforms, mesh arrays, layers, shadows and compared finish properties remain significant. The architecture-only fixture likewise avoids unrelated vehicle generation.
- `scripts/check_garage_workshop.py` checks the exact scene SHA-256 and the complete current source set declared by the baker. `scripts/dev.ps1` runs it in `Export-Android` before car preparation or export tooling. Missing, changed or omitted dependencies reject the gate.
- `test_garage_bake_safety.gd` and `scripts/test_garage_workshop.py` cover rejection, concurrent output changes, rollback, excluded files, first-generation failure, valid publication, and geometry-comparison negative controls. Four new GDScript UIDs accompany the source files.

This changes offline preparation and validation. No vehicle geometry, physics, camera or runtime appearance code was authored by this task. Workshop and six catalogue assets were regenerated against current sources; concurrent record-station and vehicle-loading edits were preserved.

## Validation

| Actual check | Result |
|---|---|
| Publication and comparison regression | 25 checks, zero failures |
| Python workshop-validator cases | 7 tests passed |
| Existing mesh cleanup | 20 checks, zero failures |
| Live refreshed workshop equivalence | 2 checks, zero failures |
| Native Compatibility menu/App/capture suite | 42 checks, zero failures |
| Production parser | 558 scripts, zero failures |
| PowerShell parser and isolated actual export-function rejection | Passed; rejected workshop stops before preparation/tools/export |
| Workshop provenance | Exact scene and 26 current source hashes |
| Catalogue provenance after final accepted refresh | Six images and 163 current source hashes |
| Native Vulkan Mobile menu suite | 42 checks, two exact-pixel failures; repeated sequentially with the same result |
| Original task-start menu test on current Vulkan sources | 42 checks, three failures: the generated-name finding plus the same two pixel failures |
| Global prepared-car preflight | 551 resources / 2,267 checks / 551 stale-source failures; not a pass |

The two Vulkan failures are `cooperative capture has exact synchronous native pixels` and `equally warmed synchronous captures remain exact`. Their reproduction with the original test distinguishes them from these fixes. The workshop assertion passes with the corrected comparator. No pixel tolerance or existing numerical invariant was weakened.

Private failure-injection probes extend the real producers and change their second source snapshot after candidate generation. Both reject, preserving **all six accepted PNGs and the old catalogue manifest**, and **both accepted workshop files**, byte for byte. Their temporary locks are removed. The successful publication and deliberately failed manifest-install tests also check exact rollback, including when no earlier files existed. Production assets were never the failure-injection destination.

Initial live tests encountered concurrent vehicle-loading compile/typed-array errors. They are retained in the logs and were subsequently corrected externally. A temporary source fixture provided an independent control while those errors were present; its two compatibility edits were never copied into production. Final Compatibility, parser, workshop and failure-injection results above use the live checkout.

The refreshed comparison initially detected 28 real differing rows in the stale workshop, beyond the now-normalised names. These included record-sleeve transforms and meshes following a concurrent `garage_record_station.gd` edit. Rebuilding the workshop resolves them with the original exact geometry/finish equality retained. The new validator also correctly rejected the old receipt before regeneration.

A subsequent concurrent `personal_ghost.gd` edit invalidated the catalogue receipt during closeout. The validator rejected it correctly. A further accepted six-picture refresh passes the current 163-source catalogue gate; that external source edit is preserved.

Concurrent changes to `car_refinement_lods.gd` and prepared-scene bytes subsequently invalidated both receipts again. One final guarded workshop/catalogue refresh completed, followed by passing 26-source workshop and six-picture/163-source validators. These qualify that refreshed snapshot; continuing external asset work can invalidate it again. No older vehicle sources or prepared scenes were restored.

## Commands and evidence

Tests use pinned Godot `4.7.2.stable.official.ed1daf0bf`, the crash-dialog wrapper, private APPDATA/LOCALAPPDATA under `build/garage-review-fixes-2026-11-13`, an empty backend URL, Dummy audio and offscreen native windows. Representative command forms:

```powershell
python build/garage-review-fixes-2026-11-13/run.py safety-final25 headless res://tests/test_garage_bake_safety.gd
python scripts/test_garage_workshop.py
python build/garage-review-fixes-2026-11-13/run.py workshop-publish-final headless res://tests/bake_garage_architecture.gd
python build/garage-review-fixes-2026-11-13/run.py preview-publish gl_compatibility res://../scripts/bake_garage_previews.gd
python build/garage-review-fixes-2026-11-13/run.py menu-gl-final gl_compatibility res://tests/test_menu_responsiveness.gd --output=res://../build/garage-review-fixes-2026-11-13/menu-gl-final
# Same native menu script also ran with renderer mobile.
python build/garage-review-fixes-2026-11-13/run.py parser headless res://tests/check_model_refinement_parse.gd
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-review-fixes-2026-11-13/export-gate.ps1
python scripts/check_garage_workshop.py
python scripts/check_garage_previews.py
python scripts/run_no_crash_dialog.py -- python scripts/prepare_car_assets.py --verify --godot 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --output build/garage-review-fixes-2026-11-13/prepared
```

[Evidence](evidence/garage-review-fixes-2026-11-13/) retains logs, private rejection probes and hashes, two native captures, and a source-only patch for ten source files plus four UIDs. The patch passes forward/reverse application and exact normalised-text round trips in an isolated repository. Initial patch-format/PowerShell-fixture attempts were corrected before the final successful checks. The shared Git index was unchanged at the source receipt; no main-index staging or commit was performed. Generated assets are recorded by hash rather than included in that source-only checkpoint.

Publication uses several fixed filenames: it is **not a power-loss-atomic directory swap**. Other readers can observe a short installation interval. A crashed process or failed rollback leaves the recovery lock for inspection; source/export provenance gates must pass again before shipping. Handled validation failures never start installation, and the tested file-operation failure restores the previous generation.

No device query/test, APK/export, deployment, backend request, owner-save mutation or owner-process change was performed. Current whole-project prepared-car readiness and the inherited Vulkan pixel checks remain unqualified. Owner/relaunch/device acceptance remains separate. Disposable fixtures/profiles/captures stay under build retention; no complete project/profile/shader cache is permanent evidence.

Closeout: both live provenance validators and the two-check workshop equivalence pass after the final refresh. All fourteen owned source/UID hashes and the main-index hash match the checkpoint receipt. The task retention pin is removed and 32 private source/resource junctions are detached. The first prescribed cleanup invocation deferred to another active cleaner; the repeat completed successfully: **23.12 → 23.12 GiB, zero eligible entries**, with recent/protected/locked output keeping the workspace above the 20 GiB target. Durable evidence is approximately 1.3 MB.
