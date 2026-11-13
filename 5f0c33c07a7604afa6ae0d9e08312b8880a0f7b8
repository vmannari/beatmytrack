# Daily standings entry and appearance — 2026-11-02

The daily result card previously rendered an unavailable placeholder while its first standings request was pending, silently returned to the same placeholder on failure, and did not observe account changes or race verification. It now distinguishes loading from failure, offers a retry, and refreshes on identity and verification signals. TrackOfDayPage supplies the cloud signal source. Existing day/version/car/account response fences remain.

The nearby list recognizes the authenticated server row even without a local daily result. Inserting a local comparison removes the duplicate server player row first. Nearby, full-dialog and post-race standings use Rivalry's translucent yellow player fill, full yellow outline and yellow text rather than inconsistent solid-yellow or left-stripe highlights. Other rows use Rivalry's dark translucent fill.

Validation uses the pinned engine, crash-dialog wrapper, isolated profiles and explicit offline fixtures through `docs/evidence/daily-fixed-limits-2026-11-01/run_native.py`:

- `test_daily_standings_entry`: 7 checks, 0 failures, headless. Delayed initial response, server player without local result, highlight, request failure/retry, verification and identity refresh.
- `test_daily_medal_page`: 79 checks, 0 failures, headless. Existing medal/car/stale-response and page behavior.
- `test_daily_standings --graphical`: 38 checks, 0 failures, desktop Compatibility. Pagination, validation, account and rollover checks. Its verification assertion now requires both the full board and card requests.

The first new test failed because PowerShell converted a literal ellipsis in the fixture to `?`; the assertion now checks the loading phrase without that character. The first retained standings run failed its former one-request assertion because verification correctly refreshes two consumers; the final assertion checks both request limits. All runs reported the existing Windows root-certificate-store error. The graphical run also reported two retained objects and one resource at exit; assertion success does not establish clean teardown.

No live API, deployment, owner saves/processes, device query or main-index operation. Reload and owner visual acceptance remain. Pre-existing work in the page, standings test and post-race source is preserved. Task-start runtime copies are in `build/daily-standings-fix/`.

## Navigation cache follow-up

The user requires returning to the daily page without a loading flash. The card now stores validated summaries on the persistent service client, with at most 24 entries. Keys include service origin, account, event day/version, vehicle, records path and local best milliseconds. Before rendering or issuing a background refresh, the card restores the matching summary and checks elapsed monotonic time against event expiry. Failed background requests retain visible rows and offer retry. A first request without cached data still shows loading. Preview construction can restore the cache without issuing network work.

`test_daily_standings_entry` now passes 14 checks, including destroying/recreating the card with a delayed response, repeated activation, car switching and return, account isolation, cold failure, and expiry rejection. The Windows certificate-store error remains in the isolated run. No network service was contacted.
