# Challenge result action — 2026-10-24

CRA01–CRA02/R01/G01/Q01: A race started to set a challenge time must identify its
existing challenge context in the results action. The action now reads **CONTINUE
CHALLENGE** and uses the same continuation as the primary Continue button. Existing
challenge races and challenge practice use that action too. Ordinary online races
retain **CREATE CHALLENGE**; offline ordinary races have neither action.

The existing seed continuation retains the actual finished ticket, time, track,
car, duration, attempt limit and configuration. The focused real-App fixture uses
an explicitly completed five-lap session of 110 seconds with a faster 100-second
saved PB and checks that continuation carries the 110-second finish.

Changed runtime sources: `game/core/app.gd` supplies the challenge context and
excludes duplicate creation; `game/ui/race_results.gd` labels and routes the action.
`game/tests/test_challenge_result_action.gd` covers the five contexts, button signals,
native pointer continuation, exact source/settings and short-window bounds. Test
records/cache are isolated; upload transport and ad presentation are fixture-only
overrides. No service publication is needed for this UI change.

Actual commands and outcomes, source/capture hashes and a task-only review patch
are in [report.json](evidence/challenge-result-action-2026-10-24/report.json).
The native [1280×720 result](evidence/challenge-result-action-2026-10-24/ui/Windows-gl_compatibility-seed.png)
and [960×540 result](evidence/challenge-result-action-2026-10-24/ui/Windows-gl_compatibility-seed-960x540.png)
show the action in the actual App results screen. These are controlled completed
session fixtures, not a claim of driving or live challenge creation.

Initial execution-policy/user-log failures, a transient concurrent Desert class
parse error, and corrected fixture array/finished-time initialization are retained
in the evidence. Windows sandbox root-certificate-store diagnostics remain in
successful logs; these offline fixtures do not establish TLS or service acceptance.

Client reload and owner flow/appearance acceptance remain. No phone/tablet attachment
check or physical-device test was performed. No APK, install, live account/backend
mutation, deployment or owner-process control. Concurrent changes are preserved;
the scoped patch excludes them.
