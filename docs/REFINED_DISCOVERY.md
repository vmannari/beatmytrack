# Refined track discovery - 2026-09-19

Requirements: R01, R04/R06/R07, V02/V03/V05. Owner reference authorizes the refined menu and preparation for cloud records; no cloud deployment is included.

## Implemented

Direct 48-unit star buttons on every track card save/remove favorites independently of selection. The bottom overview is removed. The selected-track panel has identity, five laps, score/play counts, separate local race and flying-lap PBs, race/lap distribution tabs, friend rows and a prominent Race action. Existing edit/delete/remix remain accessible. Simplified discovery dropdown offers Recommended, Trending, Friends, New and Rivals; favorites and My tracks stay independent. One search matches title or creator. Sort choices are alphabetical, user score descending and playthroughs descending, with stable alphabetical/ID ties and missing numbers last. Import/refresh moved into More; random selection remains available.

The runtime uses real local PBs and no invented population. Cloud feeds, ratings, plays, percentiles, distributions and friend records show missing-data states until supplied. User score is interpreted as track rating/score, not race speed. Recommended currently lists the local library; it has no recommendation algorithm. No online counts or social identities are invented.

## Cloud boundary

`TrackDiscoveryProvider` is a shared app-owned read model, injected into each browser. It contains no network, persistence or simulation operations. A future asynchronous adapter can hydrate it on the main thread and emit `changed`; the browser refreshes from snapshots. Record snapshots are keyed by `LocalRecords.key_for`, incorporating content hash, physics version, complete handling configuration and race rules. Local unverified PBs remain in LocalRecords and are never uploaded or promoted into verified standings by the UI.

Contract fields:
- `track_stats[track_id]`: optional score, plays, trending, friend_created, new; optional rival with time_beaten, previous_top_percent, current_top_percent. Missing numeric values remain unknown, not zero.
- `records_by_rules_key[key]`: optional race_top_percent, lap_top_percent, race_distribution, lap_distribution and friends. Smaller top-percent numbers mean better ranks.
- Distribution: bins (nonnegative population counts), min_ms, max_ms, player_bin (-1 when absent). Race/lap bins represent one verified PB per comparable player, never every attempt. The adapter must validate bounds, bins, units, ordering and totals before hydration.
- Friends: ordered player, race_ms, lap_ms rows, capped at four visible rows in this menu.

Rivals qualify when a comparable player's time has beaten the player's PB, or top-percent worsens across a ten-percent band: ceil(current/10) > ceil(previous/10). Equality at 10% stays in the first band; 10.1% moves into the second. Improvement, missing baseline and worsening within a band do not trigger. The future service must pin the same rules/version and metric, establish/acknowledge baselines, deduplicate notifications and provide the current player's scoped feed. The provider assumes trusted normalized adapter data; it is not an untrusted response parser.

Future cloud integration still needs authenticated transport, server verification, versioned wire schemas, bounded paging/cache, loading/error/stale states, retry/outbox policy and publication lifecycle. These belong behind the provider, not in controls or canonical physics. No server, account system, upload, deployment or dependency was added. Current metadata sorting is local; a cloud service must apply filtering/sorting before pagination over its full catalog.

## Changed files and evidence

`game/core/app.gd`; `game/ui/track_browser.gd`, `track_tile.gd`, new `track_discovery_provider.gd` and `track_distribution.gd` (and generated UID files); `game/tests/test_menu_presentation.gd`, `capture_premium_menus.gd`; wishlist, this document and status/phase entries. Existing original scenery reused; no new artwork or license change.

Commands used the pinned wrapper: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 <Action>`.
- Import: passed (SDK build-tools fallback warning).
- TestMenus: 22 checks, zero failures, including rival boundaries, search, score/plays sorting and missing feed data.
- TestCatalog: 18 checks, zero failures, including 5,000-entry query.
- TestRecords: 53 checks, zero failures.
- CaptureMenus: initial two runs exposed 18 offscreen-action failures each; fixed panel spacing/card height. Final 460 checks, zero failures at 1280x720, 960x540 and 1600x720. Includes viewport star taps without selection and bottom-overview removal. Populated social/distribution screenshots use disposable synthetic fixtures, never owner data.
- ADB devices: PRQKU4U4PREQNRWG attached. No APK export, installation or physical-phone test performed for this slice.

Screenshots: [local data](evidence/refined-discovery/tracks-1280x720.png), [populated gallery](evidence/refined-discovery/tracks-populated-fixture-1280x720.png), [synthetic distribution/friends](evidence/refined-discovery/tracks-data-fixture-1280x720.png), [compact](evidence/refined-discovery/tracks-data-fixture-960x540.png). Actual graphical captures inspected. Compact output uses existing logical canvas stretch and does not prove phone readability.

Remaining acceptance: owner visual review, phone touch/readability/safe areas and performance; live cloud data/provider integration. The header retains two rows at the current logical resolution to preserve search and touch space. My tracks published/local distinction was added to the wishlist only. Concurrent handling-resource edits are outside this checkpoint.
