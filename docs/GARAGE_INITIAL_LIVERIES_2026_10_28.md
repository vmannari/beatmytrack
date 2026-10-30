# Correct Garage liveries on entry (2026-10-28)

The Garage could briefly show factory liveries in two places: its main picture when entering before preloading finished, and its carousel while customized previews loaded. Both paths now respect the saved appearance.

| Requirement | Change |
| --- | --- |
| GL01 | Keep the normal live showroom on cold entry. An available preloaded showroom still transfers normally; an unavailable preload builds the saved live car instead of displaying a factory photograph. |
| GL02 | Clear a thumbnail when its appearance key changes. Only a matching factory, prepared, cached or newly rendered photograph may fill it. Customized slots remain empty until their own picture is ready. Unchanged completed pictures stay visible. |
| R01 / Q01 | Strengthen the existing actual-App carousel regression, including all seven cold customized cars, main-view entry without a preload, repaint/condition/parts invalidation, stale publication, exact factory pictures and real PNG recovery. |

Runtime files are `game/core/app.gd` and `game/ui/garage_cached_thumbnail.gd`. Tests change only `game/tests/test_garage_entry_carousel.gd`. No new renderer, image cache, shader, artwork, save format or gameplay contract is introduced. The existing one capture renderer, idle/input/navigation gates and 14-file cache bound remain.

The current request supersedes the earlier carousel stock-photo fallback. The deliberate tradeoff is that an uncached customized thumbnail has an empty picture area while its matching preview loads. Its car name and selection button remain available. Exact factory photographs still appear immediately. No temporary factory photo covers the main car.

## Verification

Commands, complete outcomes, source hashes and screenshot inventory are recorded in [report.json](evidence/garage-initial-liveries-2026-10-28/report.json). The isolated runner uses the pinned Godot 4.7.2 through `scripts/dev.ps1`, separate test persistence and an empty backend URL:

```text
python docs/evidence/garage-initial-liveries-2026-10-28/run_checks.py LABEL SCRIPT MODE
```

| Check | Actual result |
| --- | --- |
| Forced-cold regression against original runtime sources | 47 checks, 14 failures reproduce both stock-photo paths |
| Fixed cold/carousel regression, headless | 47 checks, zero failures |
| Fixed cold/carousel regression, Compatibility and desktop Mobile | 60 checks each, zero failures |
| Existing live-entry regression, Compatibility | 50 checks, zero failures |
| Existing preloaded first-entry regression, Compatibility | 31 checks, zero failures |
| Existing App regression, headless | 141 checks, zero failures |
| Preferred App `CheckScript` | Pass |

Both desktop renderers exercise actual custom capture, stale completion rejection and disk recovery. Recovered PNG pixels match the original capture exactly without constructing another capture world. The existing prepared-picture comparison remains within its original tolerance: mean byte error 0.000206232 versus repeated-capture variation 0.000054121 plus the unchanged 0.01 allowance.

The first sandboxed attempt exited with certificate-store/Access-denied errors before the test ran. Local isolated reruns passed. An initial retained live-entry control reached the original owner-replacement nil-car error; the unchanged suite passes after GL01. Earlier intermediate baseline runs and their failures remain in the evidence directory.

## Native views

- [Original stock-livery carousel](evidence/garage-initial-liveries-2026-10-28/baseline-compatibility/gl_compatibility-saved-cars-immediate.png).
- [Correct saved live car, with uncached thumbnail slots waiting](evidence/garage-initial-liveries-2026-10-28/live-compatibility/first-saved-live.png).
- [Settled cold-entry view](evidence/garage-initial-liveries-2026-10-28/fixed-compatibility/gl_compatibility-saved-cars-settled.png).
- [Prepared saved car and matching thumbnail](evidence/garage-initial-liveries-2026-10-28/preloaded-compatibility/live.png).

The carousel regression deliberately changes only its Compact thumbnail to blue to exercise a superseded red request. Its `saved-appearance-resolved` screenshots therefore show that blue test thumbnail alongside the unchanged red main car; this is fixture behavior, not an appearance synchronization claim.

## Checkpoint and acceptance

`task.patch` contains only the two runtime changes and the strengthened regression, checked forward and backward against isolated copies. Before/after source archives and hashes are retained. Shared status documents preserve the concurrent backend resource documentation. The development wrapper's generated build identity/version are archived separately and restored to their task-start values; the next normal development launch regenerates them.

Reload the game to use the fix. Cold native construction and first-use shader hitches remain possible; this change makes no startup-speed guarantee. Owner acceptance of the thumbnail wait and physical-device appearance/input/latency remain outstanding. No physical-device attachment query or device test, APK/AAB, authentication/purchase, owner-save/live backend mutation, deployment, owner-process restart, main-index staging, commit or merge was performed.

## Tablet deployment follow-up

The owner subsequently requested deployment to the tablet. TD01–TD03 build/install/launch evidence is in [tablet-report.json](evidence/garage-initial-liveries-2026-10-28/tablet-report.json).

An isolated snapshot contains the exact reviewed Garage runtime sources. The original export guard detected stale Electric tuning provenance, so all seven native catalogue pictures were rebaked in that snapshot, with all 126 source guards passing. The pinned Android export passed import, startup and driving 72/catalogue 21/menu 41 checks. Other workspace edits arrived during compilation; their hashes are recorded separately and they are excluded from this build. The deployment did not overwrite their sources or generated metadata.

The 361,361,241-byte APK, build `0.3.0-creator.853af05f507ba2b577868ce36dfcdc6c`, has SHA-256 `1b0e7721402d32e03d4303ac11990b0219bc720ccb4f3215a56e79fd9bc01153`. An in-place `adb install -r` returned **Success** on the OnePlus Pad 2 (`OPD2403`, Android 15, arm64). The installed version and APK hash match; the original first-install timestamp remains unchanged. No uninstall, data clear or track synchronization was performed. The completed host installer wrapper was closed after it remained open following the successful installation.

Android's launch command returned **Status: ok / COLD**, but the tablet's secure lock screen prevented the game from finishing foreground startup. Initial process logs have no `APP_READY`, and the retained screen captures are black. Normal wake and keyguard-dismiss requests left `showing=true / secure=true`; no credential or security setting was changed. The owner was asked to unlock the tablet. Rendered-game, Garage appearance, input and performance acceptance remain pending that unlock. Installation is verified; rendered startup is not claimed.
