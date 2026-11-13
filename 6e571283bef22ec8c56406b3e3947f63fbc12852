# Individual and group challenge check — 2026-10-25

Both one-on-one and group challenges passed the local checks. No challenge
runtime change was needed. Two new regression files exercise a three-account
group through the actual native App, HTTP API and verification worker.

## Coverage

| Area | Verified behavior |
| --- | --- |
| Individual | Exact completed-race target, including slower-than-PB finishes; verified-PB creation; source-drive return; recipient joins, actual target ghost, five-lap verification, signed target gap, rewards, retry and rematch. |
| Group | Menu creation with a PB or without a source; Create & race; results-screen creation with the selected 24-hour/three-try rules; no fixed duel target. |
| Three-account group | Creator's opening result counts once; two independent recipients join the same invitation; verified times produce ranks 1/2/3; only each member's best counts; slower and tied retries retain the original best run. |
| Tries and account boundaries | Each participant has its own budget. An exhausted member sees a disabled race action and the server rejects another start with 409; another member can still join and race. Logout clears result/polling state and guest snapshots contain no signed-in membership. Repeated joining creates no duplicate member. |
| Broader authority | Unit checks cover two-person and twenty-person capacity, owned/compatible sources, idempotent requests, pending verification, deadlines, cancellation, hidden/blocked sources, rewards and custom/multi-track totals. Native retries pin their original invitation/stage/account. |

## Actual runs

Engine: `4.7.2.stable.official.ed1daf0bf`. Tests used isolated workspace APPDATA,
disposable SQLite services on loopback and fixture identities. Public-sharing
terms were explicitly accepted by each test identity. Five-lap races used the
existing deterministic native driving fixture and actual trajectory verification.

| Check | Result |
| --- | --- |
| Backend challenge, discovery, custom-track and series tests, `-k 'sqlite and not migration'` | 43 passed, 2 skipped, 53 deselected |
| Existing ordinary/race-to-set native HTTP tests | 2 passed; 54 / 52 native checks, zero failures |
| New three-account group native HTTP test | 1 passed; 58 native checks, zero failures |
| Existing multi-track native HTTP test | 1 passed; 26 native checks, zero failures |
| `test_challenge_race_flows` | 34 checks, zero failures |
| `test_challenges` | 216 checks, zero failures |
| `test_challenge_result_view` | 293 checks, zero failures |
| `test_results_challenge_setup`, desktop Compatibility | 82 checks, zero failures |
| `test_script_parse` | 1,120 scripts, zero failures |
| Ruff on the new Python test | Passed |

The backend run explicitly excluded PostgreSQL and migration tests. Its two
SQLite skips are tests that require concurrent PostgreSQL behavior. This is not
a PostgreSQL/concurrency, migration, production or load certification.

Native commands used `powershell -NoProfile -ExecutionPolicy Bypass -File
scripts/dev.ps1 TestScript -ScriptPath res://tests/NAME.gd
-CommandTimeoutSeconds 150`. Results setup used timeout 120 and added
`-Graphical -RenderingMethod gl_compatibility`. HTTP commands used:

```powershell
$env:PYTHONPATH = Join-Path (Get-Location) 'backend'
& .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_challenges_http.py -q -s --basetemp=build/challenge-check-http-baseline-2026-10-25
& .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_challenge_group_http.py -q -s --basetemp=build/challenge-group-http-final-2026-10-25
& .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_challenge_multi_http.py -q -s --basetemp=build/challenge-check-multi-http-2026-10-25
```

Each command also set APPDATA below `build/challenge-check-2026-10-25`.
[report.json](evidence/challenge-check-2026-10-25/report.json) records commands,
logs, outcomes and source/artifact fingerprints. The new tests are
`backend/tests/test_challenge_group_http.py` and
`game/tests/test_challenge_group_http.gd`. Existing tests and runtime files were
not edited by this task.

## Corrections and limits

The initial new group fixture reached 58 checks with two failing logout
assertions: it incorrectly required the selected invitation to be empty after
logout. Guest discovery is allowed to select a public invitation again. The test
now waits for that refresh and checks that private result identity, outcome,
polling and signed-in membership have cleared. All racing/ranking/tries checks
passed in that initial run. The fixture's source polling was also corrected to
observe a completed lookup before launching another, and its Python imports were
formatted. The initial failure log is retained; no existing assertion was removed
or weakened.

Passing HTTP runs retain dependency/index-reflection warnings and temporary
comparison-unavailable responses while the isolated catalogue prepares. Native
runs used approved host access for Windows certificates. There was no TLS bypass.
Concurrent tutorial and Studio edits were preserved and are outside this task.

No physical-device test or device-attachment check was performed. No APK,
production service check/mutation, deployment, purchase, social send or
owner-process restart was performed. Device behavior and production rollout
compatibility still need their own acceptance.

[Rechecked results setup capture](evidence/challenge-check-2026-10-25/results-setup-1280x720.png)
and [task-only checkpoint](evidence/challenge-check-2026-10-25/task.patch).
