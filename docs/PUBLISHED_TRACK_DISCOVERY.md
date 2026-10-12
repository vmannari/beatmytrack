# Published tracks in Free Race — 2026-10-07

Requirements **B01–B07 / R01 / V03–V05 / Q01**. The owner reported that the just-published **Star** was absent from Free Race and expected immediate visibility.

The public staging API confirms the real track is published, visible, credited to **Ville**, and first on its newest discovery page. Its logical ID is `3fe3be78-8db0-4404-81fe-9a25742f6cd1`, revision `767228de-9eb6-45ae-a756-b7f9d04da482`. The existing desktop cache also contains Star among 28 tracks. Publishing succeeded; no republication or player-data repair was needed.

The previous return opened Race at the initial alphabetical carousel window, preserving previous filters and the local draft selection. Star sits beyond that window. Separately, a paginated server snapshot begun before publication could replace the newly remembered card when its final page arrived. The saved task-start cloud adapter reproduces that disappearance in the regression.

After acknowledged publication, the app opens **Free Race**, clears the previous discovery filters, selects the exact public revision and scrolls its whole card into view after layout. The focus is consumed once, leaving later visits and manual selection alone. Catalog refresh resets its old cursor and bypasses the ordinary minute throttle after publication. Outstanding old catalog/search reads are fenced; an interrupted catalog read schedules a fresh newest page. A later complete server snapshot can still remove withdrawn tracks. Normal search, catalog caps and immutable identities remain in use.

Changed runtime files: `game/core/app.gd`, `game/ui/track_browser.gd`, `game/backend/cloud_tracks.gd`. New regression/opt-in capture files: `game/tests/test_publication_discovery.gd`, `game/tests/test_published_star_live.gd`. Documentation: this report, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and the evidence/checkpoint below.

## Actual validation

Pinned **Godot 4.7.2.stable.official.ed1daf0bf**, through `scripts/dev.ps1`:

- Publication regression: **22 checks, zero failures**. Task-start disappearance reproduced; completed/late snapshots, immediate refresh, persisted cache, late old-revision search, server withdrawal, actual Publish handler, exclusion filters and fully visible selection beyond the initial virtual window while the HTTP read remains pending.
- Read-only native live Star check: **12 checks, zero failures**, **28 actual public tracks**. No saved login. Normal hash/document validation, actual public Star selection, enabled Race, desktop **1280×720** and compact **960×540** full-card visibility.
- Existing app flow: **99 checks, zero failures**.
- Existing catalog/bounded recovery: **86 checks, zero failures**; existing catalog tests: **21 checks, zero failures**.
- Existing real HTTP cloud library and durable publishing lifecycle: **2 pytest tests passed in 38.96 seconds**, one existing Starlette deprecation warning. These use disposable local API/worker/database fixtures, including actual verification, lost publication response recovery, cache-index failure/retry, immutable revision replacement and withdrawal.
- `git diff --check` for the changed runtime/tests: exit **0**; Git reports only the repository's existing CRLF normalization notices.

Actual commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publication_discovery.gd
$env:BMT_STAGING_API_URL = 'https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_published_star_live.gd -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_review_followups.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestCatalog
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BackendTestLifecycle
```

Public `Invoke-RestMethod` GETs checked `/v1/tracks?limit=20&q=Star` and `/v1/tracks?limit=20`. Initial sandbox network access failed; the first approved request omitted `/v1` and returned 404, then the corrected request succeeded. The first sandboxed engine run could not create its standard user log; approved engine runs used isolated test saves and passed. An initial atomic patch did not match the existing `_random()` call and made no edits; it was corrected before validation.

Screenshots were inspected: [previous return behavior](evidence/published-track-2026-10-07/star-before-return.png), [Star selected on desktop](evidence/published-track-2026-10-07/star-free-race-desktop.png), [compact layout](evidence/published-track-2026-10-07/star-free-race-compact.png). The previous-return capture reproduces the old navigation semantics using the current app and actual live document; it is not a screenshot of an older executable. [Scoped checkpoint and evidence](evidence/published-track-2026-10-07/) preserve task-start runtime sources, exact changes, source hashes and logs, excluding unrelated existing work.

## Remaining acceptance

Restart the running desktop app to load this code; publishing then opens the new public card directly. Star is already public and searchable without publishing again. Live checks only read/downloaded public content; the real user's publication, account and records were not changed. The complete real publishing protocol is exercised separately against disposable loopback fixtures.

No Android export/install, physical-phone interaction, full Validate, backend rollout or production deployment was performed. Phone attachment was not checked. Owner acceptance of the publishing return on the intended device remains. An older running binary continues to use its existing navigation until restarted.
