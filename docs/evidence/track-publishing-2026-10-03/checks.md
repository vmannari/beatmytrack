# Review execution record — 2026-10-03

Requirements B01-B07/B19/B20/R01/T01-T04/Q01. Review/plan only.

- Read project instructions, DEVELOPMENT_STATUS.md, docs/PHASE_0_PLAN.md,
  creator publishing/cloud/backend/official seeding/account ownership docs and
  the existing October 2 review. Inspected actual modified client/backend/test
  sources with `rg -n` and PowerShell `Get-Content`.
- `git status --short` showed substantial unrelated/uncommitted work before this
  review. Runtime files were inspected, not edited or committed.
- Disposable domain probes: identical document/different keys create two logical
  tracks and two publishable/discoverable entries; same key reuses a version;
  edited same document ID creates a third logical track. Fake verifier is used
  only to isolate identity/transition behavior; this is not canonical driving
  evidence. See workflow-probes.json and review_workflows.py.
- Running development backend checked through public GETs only. Ready reports
  schema 0007, manifest reports physics 0.39/rules v13; workspace expects schema
  0008, physics 0.49/rules v14. Five public items, no duplicate owner/name or
  owner/document-hash groups. All five names overlap actual local master and
  publication-lock folders. Content equivalence was not established by names.
- Existing backend domain/verifier/end-to-end/seeder suites, excluding PostgreSQL:
  75 passed, 31 deselected, 1 dependency deprecation warning, 64.99 seconds.
- Pinned entry point `TestPractice`: 53 checks, zero failures, four ObjectDB
  instance leaks on exit. `TestCatalog`: 21 checks, zero failures.
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_cloud_client.py -q`:
  1 failed, 1 dependency warning, 152.02 seconds. Godot child timed out at 150
  seconds. Backend logs include a verified 12,757-tick race. Source review found
  stale `outbox.json.jobs` polling/direct reads after the adapter's per-job
  migration. Client integration is not reported as passing.
- Existing runtime/test files continued changing during review. Final inspection
  shows cursor/projection discovery and `upload_jobs()` integration polling.
  Reran the cloud-client command because of these changes: 1 failed, 1 warning,
  4.81 seconds; upload returned 503 Track validator temporarily unavailable.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://backend/runner.gd`:
  failed exit 1, missing `RewindHistory.CAPACITY` at runner line 136. Earlier 75
  passing backend tests apply to their execution snapshot, not this subsequently
  changed working tree. No runtime repair was made by this review.
- Concurrent source correction replaced the missing constant with WINDOW_TICKS.
  Same runner CheckScript command rerun passed, exit 0. Final cloud-client rerun
  still failed at the 150-second timeout (151.35 seconds total), after logs showed
  verified 12,757-tick races, successful leaderboard/rating and record-detail
  reads. Remaining hang was not isolated; integration acceptance stays open.
- `git diff --check -- DEVELOPMENT_STATUS.md docs/PHASE_0_PLAN.md docs/TRACK_PUBLISHING_RELIABILITY_PLAN.md docs/evidence/track-publishing-2026-10-03`:
  passed. New-file whitespace, Python syntax and all plan local link targets were
  checked separately with Python and passed; git diff does not inspect untracked
  files. Existing line-ending warnings are informational.
- One initial inline Python public-GET command failed with a PowerShell quoting
  SyntaxError before any HTTP call; the saved probe script replaced it and passed.
- No runtime modifications, backend restart, player-file writes/deletions,
  deployment, export, phone test or Git commit. Device attachment not checked.
  No UI changes requiring screenshots. PostgreSQL/full regression not claimed.
