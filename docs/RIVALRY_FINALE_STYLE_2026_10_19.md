# Weekly Rivalry finale heading and spacing correction

Follow-up: the original passing suite did not check highlight/card bounds and missed champion/joint-champion clipping. The reproduced failure and complete-card correction are documented in [RIVALRY_FINALE_FIT_2026_10_19.md](RIVALRY_FINALE_FIT_2026_10_19.md).

RFS01: “Your week highlights” now uses the same 25-unit Barlow Condensed SemiBold heading as “Your track results” and “Final standings”. Its previous 23-unit label selected the regular body font.

RFS02: Final standings and highlights use the existing shared card defaults: 8-unit padding and 4-unit separation. Removing their local 6-unit padding / 2-unit separation overrides aligns the standings heading and title-to-content spacing with the track results card. The five displayed drivers still fit on the short layout.

The runtime change is confined to [weekly_rivalry_finale.gd](../game/ui/weekly_rivalry_finale.gd). Scores, highlights, selection, sharing and Continue retain their existing behavior. No test code or assertions changed.

R01: The existing `test_rivalry_awards.gd` passes **1,970 checks, zero failures**, using pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`, graphical Compatibility on Windows. [Successful command log](evidence/rivalry-finale-style-2026-10-19/awards-compatibility-host.log). Native screenshots cover six result states at 1280×720, 960×540, 1536×1024 and 1600×720, plus all five car models and pending Continue. Inspected [unranked week](evidence/rivalry-finale-style-2026-10-19/after/unranked-1280x720.png) and [short-screen Perfect Week](evidence/rivalry-finale-style-2026-10-19/after/perfect-960x540.png). Existing assertions confirm all five track rows, action bounds, awards, sharing and local settings. No new tests were added for this presentation-only correction. The task patch also passes `git apply --reverse --check --whitespace=error-all`.

Actual command (PowerShell, from the repository):

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/rivalry-finale-style-user'
$env:BMT_API_URL = ''
$env:BMT_RIVALRY_AWARDS_CAPTURE_DIR = Join-Path (Get-Location) 'docs/evidence/rivalry-finale-style-2026-10-19/after'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_awards.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 120
```

Initial attempts: directly invoking the PowerShell script was rejected by the host execution policy. The process-local `-ExecutionPolicy Bypass` invocation then reported an inaccessible default user log. Isolating APPDATA corrected that path; the restricted engine run reported an inaccessible Windows root certificate store. These failed launches are not passing validation; their logs are retained beside the screenshots. The host-access retry uses the same local fixture and isolated saves.

The [task-only patch](evidence/rivalry-finale-style-2026-10-19/task-only.patch), [source hashes](evidence/rivalry-finale-style-2026-10-19/checkpoint.json), and saved before/after sources form the reviewable checkpoint without including unrelated workspace edits.

Q01: Owner appearance acceptance remains. Screenshots are desktop fixture renders. No phone attachment check or physical-device test, APK/export/install, live account/backend mutation or deployment was performed.
