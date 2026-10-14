# Studio monitor browser acceptance, 12 October 2026

The combined local acceptance harness passed **27 checks** against real HTTP responses from a newly owned loopback backend. It did not access an existing player database, provider service or remote endpoint. Every captured record is seeded test evidence; these are not live product metrics or additional canonically driven races.

Run:

```powershell
& .tools/backend-venv/Scripts/python.exe scripts/test_studio_monitor_console.py
& .tools/backend-venv/Scripts/python.exe -m ruff check --config backend/pyproject.toml scripts/test_studio_monitor_console.py
```

Both completed successfully. The owned Uvicorn child and browser are closed by the harness. New SQLite fixtures, synthetic credentials and their private server logs remain under uniquely named `build/studio-monitor-browser-*` directories. No production deployment or device test was performed.

The harness wraps application construction before the original fixture invokes `create_app`, enabling telemetry and quality in its initial `Settings`. This matters because changing `app.state.settings` after construction does not update captured bootstrap values. It reuses `scripts/test_backend_studio_console.py` and the catalogue agent's `scripts/studio_catalogue_browser_checks.py`; it does not modify production server settings or mock browser API routes.

Diagnostic verification archives the actual Godot-generated client fixture from `build/studio-monitor-2026-10-12/client-test/statistics-sample.json` as [client-statistics-sample.json](evidence/studio-monitor-2026-10-12/client-statistics-sample.json), then posts it after replacing only fixture publication/ticket references and receipt time. The passing receipt's SHA-256 matches that immutable 3,061-byte archive: `884b0b51d93d11f7f39ed0c9e8fe5f4b9fe0ffc74f732aa02bcc156e72942fb3`. A second, clearly seeded Android device/OS slice supplies different counts. Both pass the real authenticated `/v1/telemetry/batches` ingress, preserve acknowledgement identity on duplicate delivery and reach the actual bounded product projector. One qualifying session observation establishes consistent daily activity through the same ingress. A separate OS-exit observation remains outside the race-package lane. The archive contains only fixture event/installation UUIDs and bounded diagnostic metadata; no authentication or provider secret is included.

The checks cover:

- Correct initial schema-2 negotiation; empty collection state with a visible stored published route.
- Two accepted race packages, duplicate deliveries without repeated effects, and 520 prepared position samples.
- Actual heatmap cells, device and OS narrowing, sampled-presence versus slow-second overlays, eight merged frame buckets, route segments and collection freshness.
- Crash/ANR observations with explicit unavailable model/OS attribution; selecting a model/OS cannot silently imply those exits belong to that slice.
- Published-only catalogue, stored shape previews, sorting/filtering, stable anchor/offset paging, detail/back state and actionable empty results.
- Player profile, server evidence timeline, linked cases, initial-slot/calendar-month policies and explicit missing financial/identity sources.
- Escaped append-only case notes, legal revision-fenced transition options, and a locked uncommitted command that cannot carry into analyst access.
- Explicit failed-publication metadata with no new catalogue entry or raw document/replay object: queued/failed filtering, dependency failure and client-retry guidance, creator linkage, no mutation controls and no private operation/lease fields.
- Studio pulse, exact challenge target/accepted provenance, current server reliability and financial-source-first monetisation.
- Owner catalogue preview cancellation with focus restored and no product change; purchase filters and truthful missing-feed empty state.
- Containment at 1440, 960 and 390 pixels; closed mobile navigation visibility/hit testing; menu open/close and Escape with focus restored.
- Analyst read-only controls, zero JavaScript errors, zero HTTP 5xx responses and zero remote application requests.

The implementation review exposed and corrected catalogue return-scope anchor/zero-offset differences, primary-button hover contrast and a mobile sidebar transition that could occlude text while still passing a scroll-width assertion. Earlier harness assumptions were corrected for acknowledgements containing `index`, Crash/ANR filters with unavailable attribution, the original absence of Escape navigation handling, and the refresh control intentionally hidden at phone width. Historical failed receipts are retained as failure evidence; `browser.json` is the final passing receipt.

[Passing receipt](evidence/studio-monitor-2026-10-12/browser.json), [filtered heatmap](evidence/studio-monitor-2026-10-12/quality-filtered-1440.png), [phone heatmap](evidence/studio-monitor-2026-10-12/quality-390.png), [frame distribution](evidence/studio-monitor-2026-10-12/quality-frames-1440.png), [OS exits](evidence/studio-monitor-2026-10-12/quality-exits-1440.png), [track catalogue](evidence/studio-monitor-2026-10-12/tracks-1440.png), [player investigation](evidence/studio-monitor-2026-10-12/player-1440.png), [case investigation](evidence/studio-monitor-2026-10-12/cases-390.png), [publication failure](evidence/studio-monitor-2026-10-12/publication-390.png), [pulse](evidence/studio-monitor-2026-10-12/overview-1440.png), [competition](evidence/studio-monitor-2026-10-12/competition-1440.png), [reliability](evidence/studio-monitor-2026-10-12/reliability-1440.png), and [monetisation](evidence/studio-monitor-2026-10-12/monetisation-1440.png) are seeded local UI evidence. Final desktop and phone captures were visually inspected; the closed navigation no longer covers the content.

The coordinating task owns production implementation changes and the combined review checkpoint. This subtask owns the harness, this report and its evidence only. Actual device traffic/compute, current installed-client coverage, provider financial feeds and production operational acceptance remain separate checks.
