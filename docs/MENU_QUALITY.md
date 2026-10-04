# Menu correctness and performance review — 2026-10-04

Requirements: **R01, V03, V04, V05, Q01**. Owner requested a review of menu behavior, correctness, general quality and performance, prioritizing fluent interaction. This slice fixes measured menu work and input correctness while retaining the established artwork, dimensions and gesture thresholds.

## Findings and changes

1. **Primary tab taps rebuilt the menu shell and its warmed pages.** Race/Create/Garage now promote the existing page controls through the same cache used by swipes. The header stays alive, including jumps across two page positions. Explicit `_show_screen` refreshes retain their refresh semantics. Create still starts a fresh draft; cached biome choices reset when required.
2. **Cloud status signals rebuilt the catalog/cards and stopped carousel settlement.** A browser compares a copied cloud read-model snapshot, including server/player scope and retained favorites, before reconciling the catalog. Status-only signals update status text. Changed metadata still reaches the UI. Dirty inactive pages catch up on activation.
3. **Repeated refreshes rebuilt cards and hero/record sections with unchanged data.** Cards retain identity across refreshes/reordering. Changed route metadata invalidates their geometry cache; favorite/rating/title updates refresh presentation. Ready-track reselection is a no-op. Record/detail and hero snapshots avoid identical reconstruction; optional standings still hydrate asynchronously.
4. **The warmed Garage bound its Race action to the track selected when it was created.** Its action now reads the current selection, and its circuit caption updates both on page promotion and when a pending Race selection completes.
5. **Each page promotion rewrote every descendant's mouse/focus state in GDScript.** The page root now applies the pinned engine's recursive mouse/focus overrides. Descendant preferences remain intact, and gesture hit-testing honors the effective override. A refreshed biome column inherits its page gate rather than owning a second gate. [Godot Control reference](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control-property-mouse-behavior-recursive) documents the inherited behavior; availability/interaction were verified with the pinned 4.7.2 engine.
6. **Route projection and atlas creation repeated during card redraws.** Cards cache projected paths/shadows until their route or dimensions change. The five biome atlas resources and the shared menu Theme are reused. Callers that customize shared styles already duplicate them or install their own overrides.
7. **Age/race-history filters were absent from the carousel query signature.** Changing them now resets the carousel consistently with the other filters. Carousel favorite actions also update the matching hero star.

Retained-card callbacks read the card's current metadata and catalog index. The first retention implementation's captured entry/index callbacks were caught by new regressions and corrected before the final device build.

## Changed files

- `game/core/app.gd`: cached primary navigation, page-root input ownership and current Garage selection/caption.
- `game/ui/track_browser.gd`: read-model/section reconciliation, card retention and current callbacks, no-op selection, filter/favorite correctness.
- `game/ui/track_tile.gd`: in-place metadata presentation, projected route cache and shared biome atlases.
- `game/ui/menu_style.gd`: shared Theme cache.
- `game/ui/menu_page_swipe.gd`: inherited input overrides in gesture ownership and button hit-testing.
- `game/diagnostics/mobile_menu_probe.gd`: opt-in debug CPU/frame/tab diagnostic, with no race or persisted draft created by the probe.
- `game/tests/test_menu_quality.gd` / `.uid`: isolated behavioral regressions and repeatable CPU measurements.
- `game/tests/capture_premium_menus.gd`: explicit page settlement, isolated cloud root/API, native metadata fallback and an explicitly offline controlled results fixture.
- `scripts/profile-menu-quality-phone.ps1`: explicit device targeting, existing-marker protection and cleanup/restoration in `finally`.
- This document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and `docs/evidence/menu-quality-2026-10-04/`.

## Desktop verification and evidence

All commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and Godot **4.7.2.stable.official.ed1daf0bf**, with matching Android templates.

| Actual command/action | Actual outcome |
|---|---|
| `Doctor` | Initial sandbox adb home-directory failure; authorized rerun lists physical DN2103 and Pixel_9 emulator. |
| `TestScript -ScriptPath res://tests/test_menu_quality.gd -CommandTimeoutSeconds 60/90` | Baseline: **10 checks / 8 reproduced failures**. Final: **23 / 0**. |
| `TestMenuLoading -CommandTimeoutSeconds 90` | **38 / 0**. Cold/rapid/cached selection, stale worker draining and optional standings covered. |
| `TestScript -ScriptPath res://tests/test_menu_page_swipe.gd -Graphical -CommandTimeoutSeconds 120` | Final **246 / 0**; earlier run **224 / 0**. Includes actual viewport input, fixed header, modal/carousel ownership and cached-page restoration. |
| `TestApp -CommandTimeoutSeconds 120` | **97 / 0**. |
| `TestMenus -CommandTimeoutSeconds 90` | **48 / 0**. |
| `TestCatalog -CommandTimeoutSeconds 90` | **21 / 0**, with 5,000 entries and bounded overlapping cards. |
| `TestScript -ScriptPath res://tests/test_weekly_rivalry.gd -CommandTimeoutSeconds 90` | **764 / 0**. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 90` | **291 scripts / 0 failures**. |
| `CaptureMenus -CommandTimeoutSeconds 180` | **1,744 / 0** at 1280×720, 960×540 and 1600×720. |
| `ExportAndroid -QuickValidation -CommandTimeoutSeconds 180` | Baseline and optimized builds pass import/startup, driving **72**, catalog **21**, menu **48**, then export. Full Validate is not run by this mode. |

On the isolated 40-entry fixture, 30 status signals took **177.030 → 0.503 ms** total CPU time. Thirty selections of the already-ready track took **160.784 → 0.046 ms**. These measure eliminating redundant work, not end-to-end network or race-start latency. The final export's 5,000-entry scrolling fixture measured **481 μs median / 759 μs p95 / 954 μs maximum** per boundary. Earlier runs varied under concurrent graphical/CPU work; a general carousel speedup is not claimed from those samples.

Saved logs: [baseline failures](evidence/menu-quality-2026-10-04/baseline-regression.log), [final quality](evidence/menu-quality-2026-10-04/quality-final.log), [gesture checks](evidence/menu-quality-2026-10-04/gestures-final.log), [captures](evidence/menu-quality-2026-10-04/captures.log), [app](evidence/menu-quality-2026-10-04/app.log), [selection](evidence/menu-quality-2026-10-04/loading.log), [rivalry](evidence/menu-quality-2026-10-04/weekly.log), [parser](evidence/menu-quality-2026-10-04/parser.log).

Inspected graphical evidence: [compact Race](evidence/menu-quality-2026-10-04/desktop/tracks-populated-fixture-960x540.png), [Garage](evidence/menu-quality-2026-10-04/desktop/garage-1280x720.png), [rating filter](evidence/menu-quality-2026-10-04/desktop/filters-rating-960x540.png), [keyboard search](evidence/menu-quality-2026-10-04/desktop/search-keyboard-960x540.png), [wide comparison data](evidence/menu-quality-2026-10-04/desktop/tracks-data-fixture-1600x720.png), [controlled results](evidence/menu-quality-2026-10-04/desktop/results-fixture-960x540.png). Fixtures are presentation evidence; they are not claimed verified racing results.

Initial capture runs exposed assumptions in the old harness: it checked action rectangles during a live slide, assumed a native entry existed in the cloud-only catalog, omitted rebuilding native fixture detail after disconnecting its cloud adapter, and tried to drive a native fixture through the cloud-only Race gate. The repaired harness waits for actual settlement, supplies explicit local metadata and marks the controlled results fixture with stand-in publication metadata while explicitly requesting offline start. No gameplay gate or assertion was weakened. An early quality fixture omitted builtin IDs, and the retained-focus fixture initially checked before scrollbar layout; both fixture defects were corrected. The native input change also reproduced and fixed a disabled nested biome gate.

## Device method and limits

Physical **DN2103**, serial `PRQKU4U4PREQNRWG`, was attached and used for installs and measurements. The emulator was listed but was not used for this comparison. Every probe targets that serial, cold-launches the debug APK, warms Race for 1.5 seconds, samples 120 idle frames, issues 30 status signals and traverses six tab destinations with 45 frames per transition. The device's existing five-entry cached catalog is unchanged. Frame measurements are process callback clock intervals and include scheduling; they are not a GPU trace or Android compositor presentation timings.

Actual device commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 InstallAndroid -DeviceSerial PRQKU4U4PREQNRWG
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-menu-quality-phone.ps1 -DeviceSerial PRQKU4U4PREQNRWG -Output docs/evidence/menu-quality-2026-10-04/phone-before
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-menu-quality-phone.ps1 -DeviceSerial PRQKU4U4PREQNRWG -Output docs/evidence/menu-quality-2026-10-04/phone-after
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-menu-quality-phone.ps1 -DeviceSerial PRQKU4U4PREQNRWG -Output docs/evidence/menu-quality-2026-10-04/phone-swipes -Mode PageSwipes
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-menu-quality-phone.ps1 -DeviceSerial PRQKU4U4PREQNRWG -Output docs/evidence/menu-quality-2026-10-04/phone-final
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-menu-quality-phone.ps1 -DeviceSerial PRQKU4U4PREQNRWG -Output docs/evidence/menu-quality-2026-10-04/phone-final-swipes -Mode PageSwipes
```

The baseline's Garage diagnostic invoked its then-current `_show_screen` callback directly; the later diagnostic invokes the actual Garage tab callback, which now promotes cached controls. Race/Create use their existing navigation callbacks in both builds. The six destinations and timing windows are identical.

The first optimized phone run, before native input gating, reduced maximum tab frames **263.367 → 60.833 ms** and maximum status-window frames **41.938 → 21.066 ms**. Cards were retained. Its eight page swipes all reached the prepared destination with no reported failure; median frame intervals were **16.43–16.965 ms**, with a maximum **43.290 ms**. [Baseline raw report](evidence/menu-quality-2026-10-04/phone-before/report.json), [first optimized report](evidence/menu-quality-2026-10-04/phone-after/report.json), [first swipe report](evidence/menu-quality-2026-10-04/phone-swipes/report.json).

Final physical-device comparison, after native input gating:

| Measurement | Baseline | Final |
|---|---:|---:|
| Median unchanged status call | 5.889 ms | **0.454 ms** |
| Maximum primary tab call | 108.203 ms | **4.152 ms** |
| Maximum frame across six tab transitions | 263.367 ms | **46.022 ms** |
| Maximum status-window frame | 41.938 ms | **19.389 ms** |
| Idle median process-frame interval | 17.005 ms | **16.730 ms** |
| Track cards retained after status signals | No | **Yes** |

[Final raw report](evidence/menu-quality-2026-10-04/phone-final/report.json), [comparison data](evidence/menu-quality-2026-10-04/comparison.json) and [inspected phone Race](evidence/menu-quality-2026-10-04/phone-final/menu.png). Transition p95 intervals are **17.901–20.219 ms**. The maximum transition frame improved about **82.5%**; the CPU call improved about **96.2%**. The remaining 46 ms spike prevents a claim of a perfectly locked 60 fps.

The final [eight-swipe report](evidence/menu-quality-2026-10-04/phone-final-swipes/report.json) has **zero failures**, median frame intervals **16.718–16.931 ms**, drag-call maxima **0.653–1.325 ms**, and maximum full-window frame **43.328 ms**. These viewport-dispatched gestures establish actual device behavior and short-window timing, not human finger feel.

Additional native Android input checked the final installed build: Race → Garage shows the current [Dust Cloud caption](evidence/menu-quality-2026-10-04/phone-native/garage.png); Create accepts [Winter](evidence/menu-quality-2026-10-04/phone-native/winter.png), tapping Create again [resets to Grass](evidence/menu-quality-2026-10-04/phone-native/create-reset.png), and the rebuilt palette still accepts [Desert](evidence/menu-quality-2026-10-04/phone-native/desert-after-reset.png). Returning to Race and swiping over its five visible cards [keeps Race active](evidence/menu-quality-2026-10-04/phone-native/carousel.png). Screenshots were inspected; [actual adb commands](evidence/menu-quality-2026-10-04/phone-native/commands.log) are saved. No race or persisted draft was created by these checks.

Baseline debug APK SHA-256: `430027202684A56C4682263F8EEB7C03D1121BAD0826C3FD75392F71C5576650`. Final installed debug APK: `629616E50A0EA28866C1879EEC9B044508D5E36603EFBF8E4888F747C35F4242`. The final export passes the focused checks and installation reports **Success**; final probe cold launches report **881 ms** and **904 ms**. [Final export logs](evidence/menu-quality-2026-10-04/export-final/android-export.log), [installation](evidence/menu-quality-2026-10-04/install-final/adb-install.log). Temporary probe markers were removed and normal startup restored after every completed probe.

## Checkpoint and remaining acceptance

[Scoped source patch](evidence/menu-quality-2026-10-04/changes.patch), generated against the saved task-entry snapshots and verified with `git apply --reverse --check`, is the reviewable checkpoint. Base Git reference: `0cd3a71ced9f2473f20d5acbd6df44e003bb3641`; the initial workspace already contained unrelated changes. Concurrent race-loading/backend/ad work is preserved and excluded from this patch. Shared Android builds contain the contemporaneous workspace, so these tests do not independently accept those unrelated features. No mixed-tree commit, canonical change, backend restart/migration/deployment or full physics Validate was performed.

This is a short single-phone benchmark. Human finger feel, long sessions/thermal behavior, other phones, large live catalog updates, cold track restoration and sustained authenticated network activity remain acceptance targets. Actual changed-catalog querying still sorts metadata on the main thread; departing a browser with an unfinished compilation still joins that worker. Those paths merit separate measurements before changing their ownership/consistency contracts. Focused driving validation reports existing shutdown instance warnings in some runs; none were suppressed.
