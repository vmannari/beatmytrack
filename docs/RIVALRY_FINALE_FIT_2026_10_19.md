# Complete Weekly Rivalry finale cards

RFF01: Champion and joint-champion weeks can contain four highlight lines. The previous heading correction increased the cards' minimum height, but the hero retained its proportional height. The body then scrolled and clipped the last highlight and card borders above the footer. The older awards checks asserted track-row and action bounds, but did not assert complete card or highlight bounds.

The finale now reserves the measured minimum height of both card columns and the footer before allocating hero space. A compact hero title/offset applies when that leaves less than 112 logical units. The track list contributes all five rows to that budget, and card minimum-size changes update the layout. Matching card headings, 8-unit padding and 4-unit title separation remain.

RFF02: The existing awards suite now checks the complete three card rectangles, every card label's vertical bounds, and absence of body scrolling in six result states at 1280×720, 960×540, 1536×1024, 1600×720, **1927×865** (the supplied screenshot), and 1848×937. All existing action, track-row, decoration, car, identity, clipboard and local-settings assertions remain.

Changed source: [weekly_rivalry_finale.gd](../game/ui/weekly_rivalry_finale.gd) and [test_rivalry_awards.gd](../game/tests/test_rivalry_awards.gd).

R01: Pinned Godot `4.7.2.stable.official.ed1daf0bf`, through `scripts/dev.ps1`, Windows graphical Compatibility:

- Saved original runtime with the stronger checks: **5,864 checks, 40 failures**, reproducing clipped champion/tied cards. [Log](evidence/rivalry-finale-fit-2026-10-19/before-compatibility.log).
- Corrected runtime: **5,864 checks, zero failures**. [Log](evidence/rivalry-finale-fit-2026-10-19/after-compatibility.log).
- Task-only patch reverse applicability and whitespace checks pass.

Actual commands use isolated workspace saves, no API, and host access for the Windows certificate store:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/rivalry-finale-fit-user'
$env:BMT_API_URL = ''
$env:BMT_RIVALRY_AWARDS_CAPTURE_DIR = Join-Path (Get-Location) 'docs/evidence/rivalry-finale-fit-2026-10-19/before-ui'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_awards.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 120
# After the runtime correction:
$env:BMT_RIVALRY_AWARDS_CAPTURE_DIR = Join-Path (Get-Location) 'docs/evidence/rivalry-finale-fit-2026-10-19/after'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_awards.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 120
git apply --reverse --check --whitespace=error-all docs/evidence/rivalry-finale-fit-2026-10-19/task-only.patch
```

Inspected native renders: joint champion at the supplied size [before](evidence/rivalry-finale-fit-2026-10-19/before-ui/tied-1927x865.png) / [after](evidence/rivalry-finale-fit-2026-10-19/after/tied-1927x865.png), [short joint champion](evidence/rivalry-finale-fit-2026-10-19/after/tied-960x540.png), and [champion with four highlights](evidence/rivalry-finale-fit-2026-10-19/after/champion-1280x720.png). Every highlight and the bottom card borders are visible above Share/Continue.

The [task-only patch](evidence/rivalry-finale-fit-2026-10-19/task-only.patch), [hash manifest](evidence/rivalry-finale-fit-2026-10-19/checkpoint.json) and before/after source copies preserve this correction independently of unrelated workspace edits and the preceding style change.

Q01: Owner appearance acceptance remains. The checks and captures are desktop fixtures; no physical-device test or phone attachment check, Android export/install, live account/backend mutation or deployment was performed. The body retains its original scrolling fallback for smaller unsupported viewports.
