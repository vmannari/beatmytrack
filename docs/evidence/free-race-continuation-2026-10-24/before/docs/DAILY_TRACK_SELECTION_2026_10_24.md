# Daily Free Race track ranking

Implemented locally on 2026-10-24. Requirements DTR01–DTR05 / R01 / Q01.
The default Free Race view receives up to 100 daily picks. Search by name or
creator continues across the complete eligible catalogue. The numerical policy
below is a starting balance for owner acceptance.

| Requirement | Result |
|---|---|
| DTR01: rank tracks from several signals | Versioned, deterministic score combining rating confidence, freshness, recent unique racers, repeated racing, capped race volume and lifetime unique finishers. |
| DTR02: choose a fresh set each day | Resumable background selection once per UTC day; a target mix of 60 ranked, 20 fresh and 20 rotating tracks. |
| DTR03: retain catalogue search | Search, explicit filters/sorts, Favorites, My tracks and New/Popular/Top rated query the full eligible catalogue. Direct links and publication return still reach exact revisions. |
| DTR04: protect ranking and existing gameplay | Server-verified contributions, per-player caps, creator/test exclusions, confidence shrinkage, current moderation/block checks, bounded expiry and account erasure. No canonical driving or rewards changes. |
| DTR05: bounded delivery and review | Background batches, capped candidate pools, atomic publication, actor-scoped existing cursors, native HTTP tests and retained evidence. |

The score is an integer from 0 to 1,000,000, with these weights:

| Signal | Weight | Definition |
|---|---:|---|
| Rating | 30% | `(rating_sum + 17.5) / (rating_count + 5) / 5`, capped at one; the existing five-vote, 3.5-star prior reduces single-vote influence. Cards still show actual ratings. |
| Recent unique racers | 20% | Existing distinct eligible verified racers over the preceding seven days; logarithmic saturation at 1,000. |
| Replay frequency | 20% | `max(within_day_repeats, capped_races - recent_unique_racers, 0) / (capped_races + 20)`, capped at one. The denominator shrinks small samples. It measures repeated racing, not a separately observed return-day retention rate. |
| Race volume | 10% | Eligible verified finishes, capped at five per player/track/UTC day; logarithmic saturation at 5,000. |
| Freshness | 15% | Linear boost declining to zero after 14 days from the original track record's creation, evaluated at UTC day start. Editing or publishing another revision does not reset it. |
| Lifetime unique racers | 5% | Existing latest-version verified-finisher count, logarithmically saturated at 10,000. It is version-scoped, rather than a newly reconstructed cross-version lifetime total. |

Race volume and within-day repeats retain the current UTC day plus the previous
six days. The pre-existing recent-unique signal uses its exact rolling seven-day
window. New race/replay counters are prospective after this worker update on an
already bootstrapped service; they mature over seven days. Existing ratings and
unique-finisher projections remain available immediately. Historical run scans
are not introduced into browsing or normal racing.

Only committed verified runs contribute. Creator-owned races, creator proof,
creator-test boards, artificial/test players, test populations, disabled and
deleted players are excluded from the new race/replay counters. Each retained
driver/track/day row stores at most five contributions. The contribution update,
journal processing and projection checkpoint commit together. Restriction,
restoration, expiry and privacy erasure update the associated totals under the
existing partition lock. Existing unique-player/rating eligibility is retained.
These caps limit repeated play influence; this is not a claim of complete
multi-account fraud prevention.

Each daily list interleaves three ranked slots, one fresh slot and one discovery
slot per five. Fresh choices rotate among tracks created within 14 days.
Discovery first prefers tracks absent from the previous day's list, then uses
the hash of policy/day/track for reproducible rotation. Candidates deduplicate by
track. Creator and biome caps are soft: first try three tracks per creator and
35 per biome, then relax to ten/60 and finally the list size if supply is limited.
Missing fresh candidates use the other pools. Small catalogues can supply fewer
than 100 tracks, and a catalogue of 100 or fewer cannot always change membership.
This replaces the default view's previous official/community mix; the explicit
legacy Recommended API feed retains its original full-catalogue behaviour.

The existing discovery daemon performs one bounded selection step alongside a
projection turn. Each step scans at most 128 indexed current heads, with three
candidate pools capped at 500 each and a per-creator pool cap of 100. The daemon
retains its single connection. Scan position and pools commit together; publication
and the final list are atomic. Initial projection/bootstrap must be ready, and
expired activity for a partition must drain before its candidates are sampled.
The daily score samples projections during the background scan; it is not a
single catalogue-wide database snapshot. The finished list is immutable for that
day. Discovery health includes the daily policy, partition and publication time.

At UTC rollover, yesterday's publication remains available while today's build
finishes. With neither today nor yesterday ready, the API returns retryable
`DISCOVERY_DAILY_PREPARING`, rather than a false empty catalogue. Empty published
catalogues are valid. Up to three days of derived daily records remain for open
cursors; older records are removed in bounded batches. Day selection pins IDs and
revisions; current visibility, account restrictions and blocks are checked again
on every page and Random request. Hidden items can reduce the list until the next
publication. Daily HTTP requests never rank or scan the catalogue: they check at
most 100 version IDs and hydrate at most 20 cards. Search retains the existing
indexed query and resource budgets.

Bootstrap advertises `discovery_daily_version: 1`. The client requests `feed:
daily` for ordinary unfiltered Recommended Free Race only when this capability is
available, and otherwise uses the existing Recommended feed. Random anchors within
the same daily list. Search, filters and links outside the picks retain catalogue
access. The status text identifies “Daily picks” in the existing status area.
No new screen, external service, dependency or runtime AI was added.

Changed runtime files are the discovery models, activity and daily selector,
projection/erasure/worker, query/v3 API, explicit database grants, the single
bootstrap capability in `app.py`, `discovery_filters.gd` and
`discovery_windows.gd`. Migration `0064_daily_track_selection` follows the current
`0063_custom_challenge_tracks` migration. The request schema now permits `daily`.
Tests are `test_discovery_daily.py`, `test_discovery_daily_native.py` and
`test_daily_track_selection.gd`. The task-only checkpoint and SHA256 manifest in
the evidence directory exclude unrelated concurrent changes to shared files.

The final backend selection passes **111 tests**, with two skips and 73 explicitly
deselected PostgreSQL cases (`-k 'not postgres'`). The full attempt before that
completed 107 tests before an existing PostgreSQL fixture could not connect to its
local database. No PostgreSQL pass is claimed. The dedicated daily rollback and
the existing legacy-member migration test also pass separately.

Validation uses disposable SQLite databases, loopback HTTP, isolated workspace
userdata and the pinned Godot 4.7.2. The actual commands, final counts, source
hashes and retained interruptions are in
[report.json](evidence/daily-track-selection-2026-10-24/report.json). The focused
native HTTP test passes 21 headless checks and 24 checks on each desktop renderer.
It follows the real default feed to 100 tracks, tests Random and exact revision
anchors, downloads/compiles an immutable track, renders Free Race, and uses the
actual Search drawer to find a track outside the daily list. Native views:
[Compatibility Free Race](evidence/daily-track-selection-2026-10-24/captures/gl_compatibility-daily-free-race.png),
[Mobile Search](evidence/daily-track-selection-2026-10-24/captures/mobile-full-catalogue-search.png),
[compact layout](evidence/daily-track-selection-2026-10-24/captures/mobile-daily-compact.png).

Existing native discovery/window checks321, legacy entry point321,
preloading120, Free Race list233, startup18, challenge discovery92, App141 and
parser1076 pass. Initial script-policy/userdata/certificate-store interruptions,
a native fixture checking its caption before prefetch completed, the first
migration rollback guard, a concurrent recording-cache parser interruption and
an unavailable local PostgreSQL fixture are retained. The caption fixture now
waits for its actual owned reads. Explicit migration rollback removes only daily
cursors/derived data and preserves ordinary views, tracks and versions; it has a
dedicated test. The unrelated recording-cache source was corrected concurrently;
this task did not edit it. No invariant was weakened.

Release requires the matching client, API, discovery worker and migration0064,
with the explicit runtime database grants reapplied by the release operator.
No live database or existing worker/process was changed. PostgreSQL migration,
query plans, worker contention, sustained catalogue/DAU load, production resource
cost and physical-device behaviour remain unverified. The weights, 100-track
size, 60/20/20 balance, diversity limits, freshness horizon and activity caps need
owner acceptance and later calibration against real play. Balance changes require
a policy version and a future daily publication; published lists are not silently
rewritten. No phone/tablet attachment check, physical-device test, APK, purchase,
live account/backend mutation or deployment was performed.
