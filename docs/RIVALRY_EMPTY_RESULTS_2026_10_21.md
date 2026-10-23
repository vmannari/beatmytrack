# Rivalry empty results diagnosis and correction — 2026-10-21

Requirements: WR03–WR07, TD05, R01, Q01.

The running PC app receives an obsolete, empty Week 42 championship after the week changes. The backend's previous-membership lookup orders by week alone. Several game builds created separate memberships during that same week, so the query can return the oldest empty field rather than the player's latest championship. The app faithfully displays that response.

Read-only inspection of the configured cloud service, revision `bmt-stg-e7a444ab-api-00086-vud`, and the PC's existing Rivalry snapshot confirms:

| Week 42 championship | Human joined (UTC) | Verified best rows | Test-driver best rows |
| --- | --- | ---: | ---: |
| `4da7e6cf-9681-4d6a-8f57-dc459dc3e6b0` — displayed empty finale | October 12, 13:45:51 | 0 | 0 |
| `adead233-2e23-4024-a430-d9aaa4e9129e` | October 12, 15:27:08 | 69 | 64 |
| `caa37a7b-221f-46c4-9d8d-fe2904e03c68` | October 16, 17:41:17 | 63 | 63 |
| `54a04bb5-3642-46cc-b665-829db6ef7eda` | October 17, 19:23:24 | 67 | 62 |
| `555cf549-451b-4b10-b84b-5e075b2a223b` — latest membership | October 18, 18:31:21 | 15 | 11 |

Each field has 13 artificial drivers. The displayed field has no race attempts. Its first pinned track still belongs to physics 0.53/compiler 22; the service now runs physics 0.66/compiler 27/rules 23. These championships are distinct immutable contracts, and their results must remain separate. The current worker is ready with one available worker and zero queued races/publications. The latest championship has test-driver best counts `[5, 0, 2, 2, 2]`; this fix does not claim every driver finished every track. Ended championships do not receive newly generated races.

`backend/bmt_backend/rivalry.py` now orders previous memberships by week, the player's join time, group creation time and a stable group ID. Current-week exact-contract membership, player/car/population fences, separate history reads, accepted results and Continue acknowledgements remain unchanged. No data migration is required.

`backend/tests/test_rivalry_week_completion.py` adds two regression cases: an older empty build beside a newer membership containing an ordinarily submitted and worker-verified race, including a case where group creation time disagrees with membership join time. Both require the correct active/final championship, exact retained standings/tracks, direct access to the separate empty history, and Continue acknowledging both ended memberships.

Actual commands from the repository root:

```powershell
# Existing operator access; GET/describe/secret-read only, no session login or race writes.
& .tools/backend-venv/Scripts/python.exe build/rivalry-results-diagnosis-2026-10-21/inspect_live.py
& .tools/backend-venv/Scripts/python.exe build/rivalry-results-diagnosis-2026-10-21/inspect_live.py --pinned-build

$env:PYTHONPATH = 'backend'
# Before the runtime change: 2 failures at the finale group identity assertion.
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_rivalry_week_completion.py -k 'finale_uses_latest and sqlite' -q --tb=short -o cache_dir=build/rivalry-results-diagnosis-2026-10-21/pytest-cache
# After the runtime change: 32 passed, 15 deselected; one existing Starlette/httpx warning.
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_rivalry_week_completion.py backend/tests/test_rivalry.py backend/tests/test_test_drivers.py backend/tests/test_automatic_test_drivers.py -k 'not postgres and not godot' -q --tb=short -o cache_dir=build/rivalry-results-diagnosis-2026-10-21/pytest-cache
& .tools/backend-venv/Scripts/python.exe -m ruff check backend/bmt_backend/rivalry.py backend/tests/test_rivalry_week_completion.py
git diff --check -- backend/bmt_backend/rivalry.py backend/tests/test_rivalry_week_completion.py
```

Ruff and whitespace checks pass. The new regression first needed a clock correction because a frozen Monday ticket had expired against the real upload clock. Initial random group IDs did not reliably expose unspecified SQLite ordering; a fixed obsolete group identity reproduces the actual selection error in both cases. Assertions were retained. Initial cloud reads required normal operator credential access outside the filesystem sandbox. An admin bearer on a public player-auth route returned 401; the anonymous public metadata read succeeds. None of these attempts modified service configuration or player data.

[Sanitized diagnosis and task-only checkpoint](evidence/rivalry-empty-results-2026-10-21/report.json) retain the source hashes, exact focused failure, regression results and patch. Private API configuration remains only in the ignored build directory. The existing shared workspace contains unrelated changes, which are preserved.

The correction is local and requires an explicitly authorized backend rollout to affect the cloud client. PostgreSQL execution, native UI appearance and owner acceptance remain untested for this task. No phone attachment check/device test, APK action, live publication/race/account/queue mutation, restart or deployment was performed.
