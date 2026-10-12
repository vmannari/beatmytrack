# Histograms farther along the carousel, 2026-10-10

Owner reports that farther tracks have missing/slow histograms. Requirements
**HSTART06** follow the visible carousel/page window; **HSTART07** prioritize
the currently selected comparison; **HSTART08** display comparison data without
waiting for race geometry; **HOPT02/RR06/R01/B07/Q01/V03/V05** retain scoped
data, no polling, exact charts and pinned race eligibility.

## Reproduced gaps

The prior implementation warmed startup metadata and selection neighbours,
but scrolling by itself did not warm the cards entering view. Its append-and-
trim queue could keep four older queued tracks while discarding most of the
new distant window. A selected request only moved ahead of that queue, still
waiting for two old in-flight requests. Finally, the detail/record view stayed
hidden until document download and compilation finished, even if the comparison
packet was already ready.

A controlled run against the saved pre-task queue/browser produced **11
checks / four failures**, separately reproducing all four gaps. The original
requests were held rather than simulated as completed. [Baseline log](evidence/carousel-histograms-2026-10-10/baseline.log).

## Change

Both ordinary and paged virtual carousels now warm the visible cards and a
small look-ahead as their metadata arrives. A window identity avoids work on
every scroll pixel. Preview pages remain read-only/no-HTTP until activation.
The already selected track's own pending/completed read is excluded from this
speculation. The app's startup warmer yields ownership to the active Free Race
carousel rather than reasserting the first six tracks on every catalog event.

New windows replace stale queued speculation. There are at most **two
background comparison jobs plus one reserved foreground job**; a newer
selection can also use free background capacity while an older foreground
request is in flight. Only the latest queued foreground selection is retained;
discarded queued callers are released. In-flight requests remain owned until
completion. Shared comparison and leaderboard results coalesce rather than
starting duplicate reads. Partial leaderboard data does not masquerade as a
complete histogram. The existing 32-entry/2-MiB/ten-minute cache remains.

A ready validated packet can now render the selected metadata's race/lap
charts before its document download or geometry compilation completes. The
hero and comparison belong to that requested version. Unresolved local PBs
are left unclaimed; verified own-time data can be displayed. Race, High scores
and Rate actions remain disabled until the actual pinned native target is
ready, preventing actions against the previous selected track. The handoff
preserves charts and enables Race for the completed target only.

Vehicle, selection serial, server/account and cache scope guard late replies.
New selections reset the exceptional-wait clock. Actual empty/failure states,
the 2.5-second exceptional notice, personal overlays/retained frames, unified
comparison field, normal results first and public/artificial isolation remain.
No canonical simulation, verification, backend, rewards or score-write changes.

## Actual verification

Pinned Godot **4.7.2.stable.official.ed1daf0bf**, Windows Compatibility renderer.
Commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Arguments after entry point | Actual outcome |
|---|---|
| `-Action TestScript -ScriptPath res://tests/probe_carousel_before.gd -Graphical` | 11 checks, four expected failures against captured original code; temporary entrypoint then removed |
| `-Action TestScript -ScriptPath res://tests/test_carousel_histograms.gd -Graphical` | **21 checks, zero failures**; distant queue replacement, held-old-request priority, newer selection/free capacity, visible-window warming, no stationary polling, charts before held document/geometry, correct pinned Race handoff, rapid stale reply guards and real paged adapter |
| `-Action TestScript -ScriptPath res://tests/test_discovery_pages.gd -Graphical` | **274 checks, zero failures**; all 5,000 records reachable with bounded 15-page/300-metadata cache, 2,100.343 ms fixture paging traversal |
| `-Action TestScript -ScriptPath res://tests/test_startup_histogram.gd -Graphical` | **26 checks, zero failures** |
| `-Action TestScript -ScriptPath res://tests/test_instant_comparisons.gd -Graphical` | **28 checks, zero failures**; foreground assertion now requires an actual independently started request rather than just queue position |
| `-Action TestScript -ScriptPath res://tests/test_unified_histograms.gd -Graphical` | **150 checks, zero failures** |
| `-Action TestScript -ScriptPath res://tests/test_menu_loading.gd` | **40 checks, zero failures** |
| `-Action TestScript -ScriptPath res://tests/test_menu_loading_speed.gd -Graphical` | **30 checks, zero failures**, captures under `build/carousel-histograms/menu-speed` |
| `-Action TestApp` | **99 checks, zero failures** |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | **465 scripts, zero failures** before temporary baseline probe removal; final parse receipt retained |
| `-Action Import` | Exit zero; new regression UID registered |

The unified suite reads the retained fixture with
`BMT_RESULTS_EVIDENCE=docs/evidence/histogram-grid-2026-10-09`. The new tests
use fictional 50-track metadata and the existing retained Slippery comparison
packet; no live requests or identities were used in this task. The paged
subtest runs the actual CloudTracks/DiscoveryPages adapter with a controlled
authenticated client, crosses the page boundary at index 40, and verifies its
newly arrived metadata starts comparison reads without fetching the catalog.

The selected distant packet was ready at the test's eight-frame observation
point, **52.709–62.147 ms** in final runs, while the two older background
requests remained held. This is local fixture orchestration, not live HTTP,
phone performance or an end-to-end startup guarantee. A held-document capture
was made after the section transition settled; charts were actually visible
in the scene while the old native track was still owned and Race was disabled.
[Settled metadata-stage capture](evidence/carousel-histograms-2026-10-10/far-track-before-geometry.png),
[final fixture log](evidence/carousel-histograms-2026-10-10/carousel-final.log).
The fictitious track names and controlled high-score row are not live scores.

Existing startup coverage initially exposed duplicate leaderboard reads when
warming promoted pages. Reusing pending/completed leaderboard data corrected
that with independence assertions retained. The new metadata adapter initially
omitted its `load_more` method; the fixture was completed without changing
product behavior. The initial capture was mid-transition and was replaced by
the settled capture. No failing product invariant was weakened.

Runtime files: `game/backend/comparison_preloader.gd`,
`game/ui/track_browser.gd`, `game/core/app.gd`. New regression:
`game/tests/test_carousel_histograms.gd`/UID; existing priority assertion in
`game/tests/test_instant_comparisons.gd` updated. This report, project status
documents and task-only review checkpoint `refs/codex/carousel-histograms-20261010`
record actual commands and evidence.

No phone attachment check, physical-device test, Android export/install,
full Validate, live backend requests, deployment or player-score writes.
Restart/rebuild the client to use the change. Actual installed-client far
browsing, variable network/timeout behavior and device performance remain
owner acceptance checks. Genuine missing data and fully occupied slow network
requests cannot be made instantaneous; this change removes the identified
client coverage, queue and geometry dependencies.
