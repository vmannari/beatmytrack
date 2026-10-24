# Results challenge setup — 2026-10-24

The race-results **Create challenge** action now opens a dedicated single-race
setup. It offers One-to-one or Group race, duration (24 hours, 3 days, 7 days), and
tries per driver (Unlimited, 1, 3, 5). **Create & share** creates the invitation.
The finished track, car and exact time appear in the footer. Back restores the
same results screen and completed game.

## Requirements and implementation

| ID | Behavior |
| --- | --- |
| RCS01 | Enter the results-only step directly. Only mode, duration and tries can be selected; format, track, car, track-count and visibility selectors are absent from this view. |
| RCS02 | Keep the completed ticket, track version and vehicle fixed, including slower-than-PB finishes. Existing verification, account fencing, explicit creation, operation keys and sharing remain authoritative. |
| RCS03 | One final Create & share action. No extra race starts. Back restores the retained results. The separate menu wizard and its race-to-set continuation retain their chosen configuration. |
| G01 | Native desktop screenshots at 1280×720, 960×540, 844×390 and 390×844, including the reachable last tries choice when the options scroll. |
| R01 / Q01 | Focused native checks, actual App navigation, existing creation regressions and disposable HTTP integration; task-only patch against captured starting files. |

`game/core/app.gd` opts the ordinary results action into `results_only`.
`game/ui/challenge_create.gd` supplies that step with immediate rule selection,
one fixed track, source verification and a single final action. It prepares no
track browser or car showroom worlds for this step. Existing menu creation and
setup-drive returns use their original steps. Creation visibility retains the
existing adapter setting and public-sharing terms flow; no API/schema changes.

Native checks are in `game/tests/test_results_challenge_setup.gd` and
`test_challenge_result_action.gd`. The ordinary HTTP test now exercises the
results-only rules directly, retaining its exact-ticket and slower-than-PB checks.

## Actual validation

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. Runs used isolated workspace
APPDATA, fixture accounts and local SQLite services. Desktop Mobile means the
desktop Vulkan renderer on an RTX 3090.

| Check | Actual result |
| --- | --- |
| `test_results_challenge_setup`, headless | 74 checks, 0 failures |
| Same, Compatibility / desktop Mobile | 82 / 82 checks, 0 failures |
| `test_challenge_result_action`, headless / Compatibility | 27 / 34 checks, 0 failures |
| Existing `test_challenge_cards` | 223 checks, 0 failures |
| Existing `test_app` | 141 checks, 0 failures |
| `test_script_parse` | 1,105 scripts, 0 failures |
| `backend/tests/test_challenges_http.py` | 2 passed; ordinary results 54 native checks, race-to-set 52, all 0 failures |

The focused checks cover all 24 mode/duration/tries combinations, exact source
payloads, pending/unavailable verification, retry, duplicate submission, edits and
Back during submission, late replies after an account change, and layout/scroll
reachability. HTTP runs actually verify completed five-lap recordings, create the
challenge from the slower finish, restore results on cancellation, and retain the
original setup-drive duration and tries. No existing assertion was weakened.

Commands used PowerShell with isolated APPDATA:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_results_challenge_setup.gd -CommandTimeoutSeconds 120
# Desktop variants add -Graphical -RenderingMethod gl_compatibility or mobile.
# Other native checks use the same entry point with the test script named above.
$env:PYTHONPATH = Join-Path (Get-Location) 'backend'
& .tools/backend-secure-venv/Scripts/python.exe -m pytest backend/tests/test_challenges_http.py -q -s --basetemp=build/results-challenge-http-pytest
```

Exact logs and SHA-256 fingerprints are in
[report.json](evidence/results-challenge-setup-2026-10-24/report.json).
The initial sandbox launch failed Windows certificate-store access; subsequent
native runs used host access with workspace-only saves. The initial pytest launch
missed PYTHONPATH and was corrected. Both failed launch logs are retained.
Native captures prompted compact horizontal rules in landscape; short views scroll
the options while keeping Create & share visible. Existing HTTP reflection and
Starlette warnings and temporary comparison-unavailable responses are retained in
the passing integration log.

## Native views

- [Verified setup, 1280×720](evidence/results-challenge-setup-2026-10-24/ui/gl_compatibility/1280x720.png)
- [Short landscape, last tries choice](evidence/results-challenge-setup-2026-10-24/ui/gl_compatibility/844x390-tries.png)
- [Portrait, 390×844](evidence/results-challenge-setup-2026-10-24/ui/mobile/390x844.png)
- [Actual App results action](evidence/results-challenge-setup-2026-10-24/ui/actions/Windows-gl_compatibility-results-setup.png)

Reload/rebuild the client and review the appearance and touch flow on the owner's
device. No physical-device test or device-attachment check was performed. No APK,
production mutation, deployment, purchase, social send or owner-process restart
was performed. Concurrent workspace changes are preserved. The scoped checkpoint
is [task.patch](evidence/results-challenge-setup-2026-10-24/task.patch), relative to
the captured starting sources rather than the repository's already-dirty HEAD.
