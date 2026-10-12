# Dust Cloud Rivalry start failure — 2026-10-11

The owner reports Dust Cloud fails to start from Rivalry without feedback after
the earlier general race-start changes. Requirement IDs: **RLOAD10** (prominent
competitive-start failure), **RLOAD11** (correct update direction for compiler
mismatch), **B01, B07, R01, Q01**. RLOAD10–11 identify this follow-up slice.

## Cause and correction

`_start_rivalry_race()` gets a ticket, downloads/compiles the track and enters
`_start_race()` with that issued ticket. Rejection previously rebuilt the page
with `rivalry.error`; the detail showed only a small muted line inside the track
card. There was no owned alert for the failed action, and a subsequent ordinary
refresh could clear the inline error. The earlier feedback change did not fix
this competitive-start branch.

`game/core/app.gd` now opens the existing owned AcceptDialog after ticket,
download, compilation or supplied-ticket contract failure. The shared supplied
ticket branch also covers challenge contract rejection. Existing loading-instance,
account/navigation fences, one start operation and free-race offline choice are
retained. Late replies after intentional navigation create no stale alert.

`game/backend/cloud_tracks.gd` checks the compiler identity before the compiled
track hash. A compiler revision itself changes that hash, so the older order
reported a generic track mismatch before reaching the actual update requirement.
Older server: “This game update needs a matching server update before online
racing is available.” Newer server: “The server requires a newer game version.
Update the game to race online.” Unknown formats receive a neutral mismatch
message. Compiler, track, engine, rules, physics and handling checks still reject
incompatibility; no acceptance check is removed or weakened.

Actual read-only GET `/v1/manifest` returned HTTP200: local compiler23 versus
live compiler22; physics0.53, rules20, engine4.7.2 and creator-track-v5 match.
The Winter solid automatic scenery change introduced compiler23; see
`WINTER_ENVIRONMENT.md`, WE11. This change does not deploy it or republish
immutable track revisions, so online racing remains blocked by that rollout gap.
The owner's exact authenticated ticket/document were not read or adopted.

## Actual verification

All engine commands use pinned `4.7.2.stable.official.ed1daf0bf` through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`.
Test saves use process-local APPDATA under `.tools/rivalry-start-feedback-*`.
Windows certificate-store access is required by the existing Godot startup.

| Arguments | Actual final outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_rivalry_start_failure.gd -Graphical` | **29 checks, zero failures** |
| `-Action TestScript -ScriptPath res://tests/test_race_start_feedback.gd -Graphical` | **21 checks, zero failures** |
| `-Action TestApp` | **99 checks, zero failures** |
| `-Action Doctor` | Successful prerequisites check; ADB lists no attached devices |

**149 final checks / zero failures.** The new test exercises the actual Rivalry
start coroutine with an isolated cached desert publication named Dust Cloud and
issued-ticket fixtures. It covers older/newer/unrecognized compilers, same-compiler
wrong track, missing ticket, failed download/compile, alert retention through
ordinary refresh, a fitting 960×540 alert, exact supplied-ticket five-lap success
without an optional ghost, and late navigation replies.

Before the fix, six failure cases produced no alert. That initial run later
stopped because the fixture lacked server-shaped standings when returning from
the matching-contract race; it is not claimed as a completed baseline suite.
Fixture standing-method and entry-rank omissions were corrected. The first
compact-window assertion compared logical embedded-window coordinates with
physical window pixels; the inspected screenshot already fit. The corrected
assertion uses the actual stretched viewport rectangle, and the final29/0 passes.
No product invariant was relaxed for these fixture corrections.

Eight captures under `docs/evidence/rivalry-start-feedback-2026-10-11/` show seven
failure reasons and the compact older-server alert. Both older-server sizes were
visually inspected; fixture standings are not live score evidence. Logs remain
under `build/logs/`. Public-read command:
`.tools/backend-venv/Scripts/python.exe build/race-start-feedback/compare_live_contract.py`;
its sanitized comparison is copied beside the captures.

Changed runtime files: `game/core/app.gd`, `game/backend/cloud_tracks.gd`.
New regression: `game/tests/test_rivalry_start_failure.gd`. Documentation:
this file, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, captures and
task-only checkpoint `refs/codex/rivalry-start-feedback-20261011`.
The working branch/index and unrelated changes are preserved.

Restart the desktop client for this feedback fix. No phone is attached; no
physical-device test or Android export/install was performed. No backend
deployment, catalog migration, live ticket/player/result writes, full Validate or
physics regression suite. Remaining owner acceptance: retry the actual Dust
Cloud Rivalry action and confirm the dialog; online success needs the separately
authorized matching backend/catalog rollout.
