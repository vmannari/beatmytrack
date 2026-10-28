# Weekly Rivalry join failure feedback — 2026-10-27

Failed first-entry requests now leave the existing error message visible when
the Rivalry page opens. Previously, destination activation immediately called
`refresh(false)` again. Without a successful snapshot, that call reset the
adapter, cleared the error and replaced it with loading placeholders.

Requirements:

- RJF01: preserve actionable entry/enrollment failure feedback through page
  activation and prefetch.
- RJF02: keep Join and Refresh available for immediate retries; successful
  enrollment clears the error and opens the real five-track field.
- RJF03: preserve account/car/origin/population isolation, overlapping-request
  guards and eventual passive recovery.

Only `game/backend/weekly_rivalry_client.gd` changes at runtime. A failed fetch
remembers its scope and receipt time. Passive reads respect the existing
30-second refresh interval even when no snapshot was received. Explicit Join
and Refresh bypass that interval. Reset/scope changes clear the failure fence;
new fetches and successful enrollment clear the old failure normally.

The page and its copy are unchanged: connection failures display “Rivalry
unavailable. Check your connection and try again.” The known insufficient-track
rejection retains “Five eligible tracks are needed before a rivalry can open.”

`game/tests/test_rivalry_join_failure.gd` exercises the real App and delayed
in-memory service at 1280×720 and 960×540. It checks first-entry failures,
manual/automatic enrollment failures, complete on-screen message bounds,
immediate retries, duplicate Join suppression, successful enrollment, expiry of
the passive retry interval, malformed replies and account changes. Its profile
guard requires APPDATA below `build/rivalry-join-feedback/`; it writes an explicit
offline backend configuration before creating the App.

Actual verification used pinned Godot `4.7.2.stable.official.ed1daf0bf` through
`scripts/dev.ps1`:

| Check | Result |
| --- | --- |
| Original runtime, initial focused harness | 19 checks, **4 failures** reproducing the erased first-entry error at both sizes |
| Final focused headless | 38 checks, 0 failures |
| Final focused graphical Compatibility/OpenGL | 44 checks, 0 failures, six screenshots |
| Existing delayed Rivalry entry | 66 checks, 0 failures |
| Existing automatic Rivalry flow | 7 checks, 0 failures |
| Existing week completion/rollover | 38 checks, 0 failures |
| All-script parser | 1,326 scripts, 0 failures |

Commands (PowerShell, from the repository root):

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/rivalry-join-feedback/final-profile'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
foreach ($testName in @('test_rivalry_join_failure','test_rivalry_entry','test_automatic_rivalry_flow','test_rivalry_week_completion','test_script_parse')) {
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath "res://tests/$testName.gd" -CommandTimeoutSeconds 120
}
$env:APPDATA = Join-Path (Get-Location) 'build/rivalry-join-feedback/native-profile'
$env:BMT_RIVALRY_ENTRY_CAPTURE_DIR = Join-Path (Get-Location) 'docs/evidence/rivalry-join-feedback-2026-10-27/compatibility'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_join_failure.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3 -CommandTimeoutSeconds 120
```

Evidence is in [the task directory](evidence/rivalry-join-feedback-2026-10-27/):
raw baseline/final logs, the original source, six native screenshots,
`report.json` hashes and `task-only.patch`. The patch is checked in reverse
against the final workspace without staging, committing or modifying files.
The page source remains byte-identical to the task-start copy. Concurrent edits
already present in the adapter and elsewhere are excluded from this patch.

Initial execution-policy and sandbox log/certificate-store access failures did
not run the regression. The isolated test was rerun with process-local script
execution and approved Windows certificate-store access. An initial fixture
path guard rejected an unnormalized `game/../build` path; normalization corrected
the fixture, with the rejected-run log retained. The earlier successful
19-check headless and 40-check native runs are also retained.

Reload/rebuild the client to use the fix. The service responses here are
synthetic; the cause of the owner's actual server rejection and live recovery
were not diagnosed. No device attachment check or physical-device test was
performed. Owner/device feedback acceptance remains. No real authentication,
live account mutation, APK, deployment, owner-process restart, staging, commit
or merge was performed.
