# Free Race startup histogram, 2026-10-10

Owner reports that opening Free Race after starting the game leaves its
histogram loading indefinitely. Requirements **HSTART01**: hydrate the initial
restored selection; **HSTART02**: hydrate a prepared page when it becomes
visible; **HOPT02/RR06/R01/B07/Q01/V03/V05**: keep unified charts, one read per
selection, account gates, independent race actions and honest unavailable states.

## Cause and fix

`TrackBrowser` rendered its initial selected track with a Loading caption,
but only tile selection called `_load_cloud_detail`. Startup can restore an
already available cloud track and never select a tile. Likewise, promoting
the prepared neighbouring Free Race page did not initialize its comparison.
No histogram HTTP request started on those paths: this was a client
initialization bug, not a measured slow backend query.

The visible detail now initializes the selected track's comparison once.
Preview pages still start no HTTP work; activation initializes the promoted
page. The existing selection marker and pending request map prevent duplicate
requests. An actually missing snapshot can initialize again, while complete
snapshots and errors remain stable under repeated draws/catalog notifications.
Synchronous replies are reread before rendering so an earlier empty snapshot
cannot overwrite a completed chart. Tile selection uses this same path.

Leaderboard and comparison requests remain independent. A failed comparison
clears its pending operation and shows the existing unavailable state. Guests
retain the sign-in gate. No source selectors, new labels, artificial public
rankings, polling, backend changes or score writes are introduced.

## Actual checks and evidence

Pinned Godot **4.7.2.stable.official.ed1daf0bf**, through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Arguments after the entry point | Actual outcome |
|---|---|
| `-Action TestScript -ScriptPath res://tests/test_startup_histogram.gd -Graphical`, before fix | 21 checks, 11 failures reproduce missing initial requests, absent completion and false perpetual loading |
| Same startup suite, final | **26 checks, zero failures**; restored opening, preview promotion, synchronous replies, errors, guest gates, no duplicate polling and four saved captures |
| `-Action TestScript -ScriptPath res://tests/test_unified_histograms.gd -Graphical` | **150 checks, zero failures**; every comparable driver, player markers, cached frames, missing-cache/failure recovery and stable charts |
| `-Action TestScript -ScriptPath res://tests/test_menu_loading_speed.gd -Graphical` | **30 checks, zero failures**; initial requests without a manual call, independent replies and scoped restart caches |
| `-Action TestScript -ScriptPath res://tests/test_menu_loading.gd` | **39 checks, zero failures** |
| `-Action TestScript -ScriptPath res://tests/test_startup_discovery.gd -Graphical` | **18 checks, zero failures** |
| `-Action TestApp` | **99 checks, zero failures** |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | **449 scripts, zero failures** |
| `-Action Import` | Exit zero; registered concurrent `EngineAudioBlend` and refreshed pending workspace audio imports |

The unified suite uses
`BMT_RESULTS_EVIDENCE=docs/evidence/histogram-grid-2026-10-09` for its retained
source fixture. Menu-speed captures use `BMT_MENU_SPEED_EVIDENCE` under
`build/startup-histogram/menu-speed-final`. All requests in these fixtures are
held local responses; no live backend data, credentials or accounts are used.

[Baseline log](evidence/startup-histogram-2026-10-10/baseline.log),
[final startup log](evidence/startup-histogram-2026-10-10/startup-final.log),
[unified log](evidence/startup-histogram-2026-10-10/unified-final.log).
Inspected [initial loading](evidence/startup-histogram-2026-10-10/startup-loading.png)
and [initial ready](evidence/startup-histogram-2026-10-10/startup-ready.png);
[promoted loading](evidence/startup-histogram-2026-10-10/promoted-loading.png)
and [promoted ready](evidence/startup-histogram-2026-10-10/promoted-ready.png)
also saved. The ready captures intentionally keep the independent leaderboard
response held while both histograms are visible. Fixture identities/times
remain test data, not shipped scores.

The first partial implementation fixed direct opening but missed promotion;
the retained startup test exposed it and activation was corrected. Existing
unified coverage then found that a cleared comparison snapshot could retain
an old selection marker; the initialization condition now handles a genuinely
missing snapshot while keeping the no-polling assertions. An initial app
test could not parse the concurrent audio class before Import registered it;
the final app test passed. No failing product assertion was weakened.

Runtime file: `game/ui/track_browser.gd`. New test:
`game/tests/test_startup_histogram.gd` and UID. Updated tests:
`game/tests/test_menu_loading_speed.gd` now relies on actual startup hydration;
`game/tests/test_unified_histograms.gd` holds/releases the initial response
rather than manually starting it. This report, both project status documents
and task-only checkpoint `refs/codex/startup-histogram-20261010` record the work.

No phone attachment check, physical-device test, Android export/install,
full Validate, live backend requests, deployment or player-score writes.
Restart the desktop client, or rebuild Android, to pick up the change.
Actual saved-session startup on the owner's installed client and compact
device presentation remain acceptance checks. Genuine network requests may
still take time; the fix ensures the request actually starts and its result
replaces the loading state.
