# Studio reported tracks and deletion

4 November 2026. Implementation and local acceptance are complete. The owner subsequently authorised deployment; [the private Studio rollout is complete](STUDIO_REPORTED_TRACKS_DEPLOYMENT_2026_11_04.md). The implementation-stage evidence below is retained.

STR01 adds **Reported tracks** to Studio navigation and the content tabs. The queue groups actual player report cases by track across all versions, showing total reports, distinct retained reporters, unresolved reports and latest report time. Search matches track name, creator or track ID; filters include active/deleted/all tracks, with report-count/latest-report sorting and bounded pages. Staff notes, appeals and repeated delivery do not inflate report counts. Counts cover all retained reports rather than the global activity-date window. Erased reporters remain in the report total but are excluded from the distinct retained-account count.

STR02 provides the individual report reasons, escaped player text, reported-version links and support-case links. Analyst access is read-only. Queries use stored metadata/route projections, not track documents or replay/geometry work. Report lists are paginated; grouping still aggregates the retained report inventory. No large-scale performance claim is made.

STR03 adds owner-only **Delete track**, with a preview naming the track, required acknowledgement and recorded reason. The backend requires a genuine linked player-report case, current case revision and current track state. The state token includes visibility, archive state, audit count and latest version number, rejecting intervening moderation or publication changes. Deletion atomically records an audit entry and a case event, marks the track hidden/archived, and installs the existing public quarantine. A lost response retries the identical command/body; repeated delivery returns the existing receipt. The catalogue offers no Show action for deleted tracks, and existing visibility/case-restoration commands reject an explicitly deleted track.

STR04 preserves the version documents, reports, verified runs, personal bests and publication-slot accounting. This is permanent removal from public access through Studio, not physical erasure of linked history. Existing archived tracks keep their previous shared-link behavior until explicitly deleted through this action. A dedicated regression checks that compatibility boundary. Existing public quarantine checks already reject all deleted-version metadata/document requests and race starts; no public track route or client protocol change is needed. Moderation reports are not automatically resolved and publishing capacity is not refunded. Previously downloaded offline content cannot be remotely erased by this backend action.

No schema migration, new table or expanded database grant is required. Production Studio uses its existing named staff/MFA boundary and restricted database role. No live report, track or account was modified during development.

Validation completed:

- Focused new moderation plus retained case workflow: **9 passed, 1 PostgreSQL test deselected**. Covers private reads, exact counts, pagination, analyst/unauthenticated denials, acknowledgement/reason validation, idempotency, command conflicts, stale track/version/case decisions, valid report-case linkage, historical result retention, restoration guards and old-archive compatibility.
- Retained catalogue, community-safety and published-track selection: **20 passed, 8 PostgreSQL cases deselected**.
- Isolated PostgreSQL17 with the actual restricted Studio role, production settings and a local named MFA staff verifier: **1 passed, 7 deselected**. Exercises grouped reads, details, deletion/quarantine, idempotent response and retained versions. It uses a local existing backend image with the changed runtime modules mounted; it is not a full new release-image acceptance claim. No real provider sign-in was performed.
- Real headless Edge against a newly owned loopback Studio: **9 checks passed**, with seven final captures. Checks include search, escaped report text, cancelled confirmation, lost response after a committed deletion, identical-body retry, one audit decision, public inaccessibility, case audit display, historical catalogue/no Show action, analyst inspection and no JavaScript errors. Desktop 1440px and tablet 768px captures were reviewed. Tablet report tables retain the shared horizontal scrolling behavior.
- Scoped Ruff and whitespace checks pass. The task-only checkpoint passes forward/reverse application checks without touching the main index.

Initial findings are retained: the secure Python environment lacked Playwright, so the existing browser environment was used without installing dependencies; the older browser fixture initially lacked the explicit development legacy-key gate, corrected only in that owned fixture. A catalogue-copy encoding error was corrected and the browser selection rerun. The first restricted PostgreSQL fixture supplied a legacy key and attempted game-session token admission, correctly denied by Studio's restricted role; it was replaced with the established named MFA staff fixture. The final PostgreSQL run succeeds without weakening permissions. A preliminary broad archive restriction was removed before final acceptance to preserve existing archived links. Initial sanitized PostgreSQL failures remain in the evidence folder. Existing deprecation/index-reflection and isolated-container marker warnings remain; none are reported as test failures or a clean full-suite result.

Runtime changes are in `backend/bmt_backend/studio_reported_tracks.py`, `http_routes.py`, `admin.py`, `studio_cases.py`, `studio_catalogue.py`, and the Studio `reported_tracks.js`, `app.js`, `catalogue.js`, `operations.js`, `index.html`. Tests are in `backend/tests/test_studio_reported_tracks.py` and `scripts/test_reported_tracks_console.py`. Documentation, source snapshots/hashes, JUnit results, browser checks, PostgreSQL harness and checked patch are retained under [the evidence directory](evidence/reported-tracks-2026-11-04/). Concurrent backend/achievement/Daily work was preserved.

Actual commands:

```text
# From backend/:
..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_studio_reported_tracks.py tests/test_studio_moderation.py -q -k "not restricted_admin" --tb=short --show-capture=no --junitxml=../docs/evidence/reported-tracks-2026-11-04/backend.xml
..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_studio_catalogue.py tests/test_community_safety.py tests/test_published_track_routes.py -q -k "not postgres" --tb=short --show-capture=no --junitxml=../docs/evidence/reported-tracks-2026-11-04/retained.xml

# From the repository root:
.tools/backend-secure-venv/Scripts/python.exe build/reported-tracks-2026-11-04/postgres.py
.tools/backend-venv/Scripts/python.exe scripts/test_reported_tracks_console.py
.tools/backend-secure-venv/Scripts/python.exe -m ruff check backend/bmt_backend/studio_reported_tracks.py backend/tests/test_studio_reported_tracks.py scripts/test_reported_tracks_console.py
```

At implementation completion, matching authorised Studio rollout and owner acceptance remained. No production deployment, live/backend access or mutation, actual track deletion, phone/device query or test, APK/export, owner-save/process change, or main-index write had been performed. Only owned local fixture tracks were deleted. The fixture server and labelled PostgreSQL resources were stopped/removed after verification. See the subsequent deployment report above for the completed rollout.
