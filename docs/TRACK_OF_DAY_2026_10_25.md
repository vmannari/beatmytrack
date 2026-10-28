# Track of the Day

Implemented locally on 2026-10-25. Requirements TOD01–TOD04 / R01 / Q01.

Race now has a sun-shaped Track of the Day destination alongside Weekly Rivalry,
Free Race and Challenges. It shows the selected track, creator, rating, route,
car picker, Race action and time until the next UTC day. The ordinary immutable
track download, five-lap race, verification and rewards paths remain in use.
Leaving that race returns to Track of the Day. All three existing mode pages,
the temporary transition rail and remembered Race navigation reach the new page.
The seven new player-facing messages have directly authored translations in all
eleven additional supported languages.

| Requirement | Implemented behavior |
|---|---|
| TOD01 | A working Race-menu destination with native input, scrolling, car selection and the actual Game round trip. |
| TOD02 | One backend-selected track/revision per UTC day for everyone. Random selection from the deduplicated union of the top 50 composite-ranked and top 50 trending eligible, previously unfeatured tracks. Trending uses the existing recent distinct verified-racer ranking. |
| TOD03 | Permanent logical-track history, independent of the expiring Free Race daily lists. Publishing a new revision never resets history. Day publication, history and the cross-worker fence commit in one transaction. |
| TOD04 | Small-catalogue startup may repeat only when every currently eligible track has appeared. New eligible tracks always take priority. Repeats choose among the least recently featured tracks, avoiding consecutive repeats whenever alternatives exist. |

The initial policy is `track-of-day-v1`. The concrete startup boundary is **100
eligible tracks**. Reaching that supply permanently closes the repeat exception,
even if tracks are later hidden or removed. After that, an exhausted catalogue
has no pick until a future day can select an unused track. These pool sizes and
the startup boundary are implementation defaults for owner acceptance.

History exclusions happen before each pool's ranking/limit. This means unused
tracks outside yesterday's top 50 are still eligible as earlier tracks are used.
The union gives each distinct candidate one equal random chance; appearing in
both pools gives no extra ticket. There is no client-side random fallback.
The selector uses current published discovery heads and excludes hidden tracks,
unpublished revisions, deleted/disabled creators and artificial test creators.
It samples the current incrementally maintained rankings, rather than taking a
catalogue-wide snapshot. Each lane reads at most 50 rows per partition and keeps
50 global candidates; HTTP never scans or ranks the catalogue.

The existing discovery worker performs selection. A singleton database fence
serializes competing workers; a completed day is immutable. A restarted worker
does not reroll it, and a clock moving backward cannot backfill a conflicting
selection. The permanent tables retain only track/revision IDs, days and policy,
with no owner/player identifiers. They intentionally have no source-data foreign
keys or discovery-retention cleanup. Explicit migration rollback removes the
ledger and therefore must not be used as routine maintenance.

`GET /v1/track-of-the-day` is public, with optional authenticated block checks.
It returns day/start/end/server time, policy/reason/status and a usual discovery
track summary or `null`. Current moderation and owner restrictions are checked
again on every read. A hidden or blocked pick is unavailable to that reader; it
does not cause a second global selection. With today's selection still unbuilt,
the endpoint returns `503 TRACK_OF_DAY_PREPARING` and `Retry-After: 30`; yesterday
is never presented as today's track. The response is private/no-store. The UI
rechecks authority before racing, disables an expired pick and refreshes at
midnight; a preparing response retries after 30 seconds. Other failures expose
Retry. UTC days have no Helsinki daylight-saving adjustment.

Migration `0068_track_of_day` follows `0067_discovery_rank`. It adds
`track_of_day_state`, `track_of_day_history` and `track_of_days`. Explicit runtime
privileges allow the worker SELECT/INSERT/UPDATE and API/admin SELECT; runtime
roles receive no DELETE permission for this ledger. Bootstrap advertises
`track_of_day_version: 1`. Release needs the matching API, discovery worker,
client, migration chain and reapplied runtime grants. Concurrent work has since
added migration 0069, which correctly depends on 0068; it is outside this task.

Runtime changes are in `backend/bmt_backend/track_of_day.py`, the discovery
models/worker, app bootstrap/routes and database privileges; and in
`game/ui/track_of_day_page.gd`, the shared mode rail/icons, browser/Rivalry
navigation and `game/core/app.gd`. The API schema is
`backend/schemas/track-of-day-v1.schema.json`. Tests are
`backend/tests/test_track_of_day.py`, `test_track_of_day_native.py` and
`game/tests/test_track_of_day.gd`. Translation authoring is
`scripts/translations/track_of_day.tsv`, with updated gettext catalogues.

Actual verification:

- Backend focused: **10 passed**, 10 PostgreSQL cases deselected. Covers pool
  membership, exclusion before limiting, competing SQLite workers, restart/day
  stability, 400-day history, revision pins, startup exhaustion/new supply,
  permanent maturity, one-track startup, moderation/blocks, read cost and
  migration rollback/re-upgrade against disposable databases.
- Backend retained discovery regression: **45 passed**, 74 PostgreSQL cases
  deselected; includes the original eight focused cases before the final two
  were added. Final focused tests and Ruff pass after the last backend edit.
- Native real-HTTP App/Game flow: **26 headless**, **26 Compatibility** and **26
  desktop Mobile checks pass**, including the ordinary race and return. The final
  headless run additionally presses the actual destination buttons from all
  three existing mode pages. Graphical runs capture 1280×720, 960×540 and 844×390.
- Retained parser **1195**, App **141**, race-mode input **57** and race-mode
  carousel **42** pass.
- Localization/tooling: **19 passed**, 24,925 subtests at the translation
  checkpoint; the same 36 older untranslated sources remained then. Subsequent
  concurrent Store gifting source edits made the global catalogue stale (504
  diagnostics at the recorded check). This task does not claim that the global
  translation completeness gate passes.
- Focused translation verification: **77** populated translated messages with
  matching placeholders, zero failures, after the concurrent source changes.

The first native attempt failed because the sandbox prevented Godot from reading
the Windows root certificate store. The authorized isolated rerun succeeded.
The initial native fit fixture compared canvas coordinates with physical window
pixels and reported two failures; it now compares with the visible canvas in
the same coordinate system, retaining the original fit bound. Initial evidence
is preserved. An import-order lint issue was corrected. No gameplay or ranking
assertion was weakened.

See [the evidence report](evidence/track-of-day-2026-10-25/report.json) for actual
commands, results and hashes, and the scoped review patch in the same directory.
Native views: [Compatibility desktop](evidence/track-of-day-2026-10-25/gl_compatibility-daily-1280x720.png),
[compact landscape](evidence/track-of-day-2026-10-25/gl_compatibility-daily-844x390.png),
[Mobile desktop](evidence/track-of-day-2026-10-25/mobile-daily-1280x720.png).

No phone/tablet attachment check or physical-device test was performed. No APK,
purchase, authentication to a real account, live database change, deployment or
owner-process restart was performed. PostgreSQL runtime/migration contention,
production cost, owner acceptance of the startup boundary and device appearance
remain unverified. Existing concurrent work is preserved.
