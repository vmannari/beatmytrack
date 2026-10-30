# Weekly Rivalry opens with prepared content (2026-10-28)

Swiping back from Create could promote the prebuilt Race neighbor while its Rivalry membership was unresolved. Activation started the fetch after the empty loading cards were already visible. The normal Rivalry button's existing membership gate did not cover this route. The new actual-App fixture reproduces the original behavior with 11 failures in 38 checks.

| Requirement | Implemented behavior |
| --- | --- |
| RRE01 | Unresolved Rivalry neighbors remain hidden during dragging. Committing the swipe, using the Race tab, and menu navigation all use the existing membership gate and reuse its pending fetch. The current page stays visible until membership or an actionable failure is ready. |
| RRE02 | Horizontal and vertical arrivals prepare the real page offscreen. The standings scroll, five track rows and native podium-car viewports are ready before the transition starts. Four desktop draw boundaries allow the existing bounded Garage-radiance preparation to finish. A new touch cannot prematurely finish this preparation. |
| RRE03 | Navigation cancellation retains the existing request, account and car scope fences. Confirmed guests/nonmembers and connection failures retain their actions; background score refresh and car-switch publication retain their existing behavior. No artificial entries or scores are added to game data. |

Runtime changes are limited to `game/core/app.gd` and `game/ui/weekly_rivalry_page.gd`. The new `game/tests/test_rivalry_ready_entry.gd` exercises the actual App with a delayed synthetic service, offline configuration and disposable workspace saves. Its native runs inspect the first entering frame, check actual nontransparent pixels in every podium render, and save eight screenshots per renderer. Existing tests are unchanged.

Actual commands, source and screenshot hashes, original failures and the checked source-only patch are indexed in [report.json](evidence/rivalry-ready-entry-2026-10-28/report.json). All engine runs use pinned `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`; [run_checks.ps1](evidence/rivalry-ready-entry-2026-10-28/run_checks.ps1) records the retained-test commands and isolated destinations.

| Verification | Actual outcome |
| --- | --- |
| Starting runtime, new fixture | 38 checks, 11 failures |
| Initial fixed headless fixture | 41 checks, zero failures |
| Final expanded headless fixture | 50 checks, zero failures |
| Compatibility, 1280×720 | 67 checks, zero failures; eight screenshots |
| Desktop Mobile, 960×540 | 67 checks, zero failures; eight screenshots |
| Existing Rivalry entry | 66 checks, zero failures |
| Existing car-switch publication | 36 checks, zero failures |
| Existing enrollment failure/retry | 38 checks, zero failures |
| Existing automatic enrollment | 14 checks, zero failures |
| Existing restart/menu caches | 27 checks, zero failures; retained track-browser anchor warning |
| Existing week completion | 38 checks, zero failures |
| Existing race-mode input and retained page | 57 checks, zero failures |
| Full script parser | Initial 1,396 and final 1,397 scripts, zero failures |
| Broader unchanged App fixture | 141 checks, one editor touch-cancellation failure |
| Same App assertions with this Rivalry patch removed | Same 141 checks and same one editor touch-cancellation failure |

Native evidence shows [the current Create page during the delayed swipe](evidence/rivalry-ready-entry-2026-10-28/compatibility/swipe-waiting.png), [populated content at the first entering frame](evidence/rivalry-ready-entry-2026-10-28/compatibility/swipe-first-frame.png), [the complete Rivalry overview](evidence/rivalry-ready-entry-2026-10-28/compatibility/swipe-ready.png), [compact vertical-rail arrival](evidence/rivalry-ready-entry-2026-10-28/mobile/rail-ready.png), and [the actionable failure state](evidence/rivalry-ready-entry-2026-10-28/mobile/failure.png). These are synthetic fixture standings, not live results.

The initial sandbox run reported Windows certificate-store access errors. The retained local runs use the same pinned engine with isolated offline profiles. Two broader App attempts caught concurrent editor edits: a `_selected_object_properties` reference preceding its definition, then an unavailable `editor_history.gd` preload. Those attempts are retained. The final App run and an independent control both fail only `canceled touch releases capture and all gesture state` in the editor; this task does not change that assertion or editor input. The control uses the current App with only this Rivalry patch removed and changes only the two App instantiation sites in a copy of the original fixture. Its [source hashes](evidence/rivalry-ready-entry-2026-10-28/app-control-provenance.json), exact copied sources and [log](evidence/rivalry-ready-entry-2026-10-28/app-control.log) are retained; both temporary scripts were removed afterward.

Concurrent Garage account-restoration and editor changes in the shared App file are preserved and excluded from [task.patch](evidence/rivalry-ready-entry-2026-10-28/task.patch); the evidence builder constructs its base by undoing only this task's exact edits. Forward and reverse `git apply --check` pass without changing the main index. Generated build/project metadata are excluded. Logs retain their individual build IDs; this is not a frozen whole-workspace claim.

Network latency and initial construction/rendering costs remain. The change controls when content becomes visible; it does not claim faster network responses, zero hitches, phone performance or device acceptance. Reload/rebuild and owner review on the original device remain. No device attachment query or physical-device test, APK, live account/save mutation, backend deployment, owner-process restart, main-index staging, commit or merge was performed.
