# Personal best placement and histogram consistency — 2026-10-11

Requirements: RR06/R01/R03, TD06/TD08, B05/B07, V03/V05 and Q01.
The owner reports Top 40% beside a fastest-looking personal marker in the
Slippery discovery records panel. HC01 binds placement to the displayed PB;
HC02 aligns race/lap captions and markers; HC03 handles new local PBs and late
replies; HC04 preserves the unified population, exact counts and restrained UI.

## Cause and correction

`game/ui/track_browser.gd` selected the faster local/verified PB for the histogram
marker, then copied the server comparison without checking its `candidate_ticks`.
A warmed response could therefore rank an older verified PB while showing a
faster local time. A second case sent the slower device PB despite displaying a
faster server PB. Cached snapshots could also keep their previous marker after a
new local record. These paths were reproduced using isolated fixtures; the exact
owner account/packet was not read and the screenshot's live rank is not asserted.

Discovery now uses the same minimum local/known-server PB for the record caption,
marker and foreground request. Placement is shown only when its candidate matches
that time at canonical tick precision. A stale or legacy unbound placement is
withheld until the matching read returns. Existing bars remain visible, and no
new captions or loading notices were introduced. Best lap also uses the same
local/verified minimum as its marker. Local PB changes start one new comparison
read without track reselection or polling; replies for older PBs cannot replace
the newer placement. Exact rank is never inferred from histogram bins.

The existing single deduplicated race/lap population, 16-bin frame, verified counts,
account/car/rules fences, public/artificial competition isolation, normal results
first and five-lap race contracts remain. These are presentation candidates;
they do not insert unverified samples or alter competitive PBs. The public High
scores list retains its existing competitive population and is separate from the
owner-required unified comparison histogram.

## Changed files

- `game/ui/track_browser.gd`: candidate binding, PB-aligned request/captions/markers,
  PB-sensitive selection key and stale reply guard.
- `game/tests/test_personal_comparison.gd` and its `.uid`: regression using the
  actual browser, held transport, local/server PB differences, canonical tick
  rounding, cache updates, duplicate events and out-of-order replies.
- This report, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, five PNG captures,
  task-only patch and checkpoint receipt.

## Actual commands and outcomes

Commands used pinned Godot **4.7.2.stable.official.ed1daf0bf** through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`.
Tests used process-local APPDATA folders under `.tools/personal-comparison-*`,
without owner saves or credentials. Graphical tests used Compatibility/OpenGL.

| Arguments | Actual outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_personal_comparison.gd` | Initial reproduction: 11 checks, 6 failures |
| `-Action TestScript -ScriptPath res://tests/test_personal_comparison.gd -Graphical` | Final: 22 checks, 0 failures; five captures |
| `-Action TestScript -ScriptPath res://tests/test_startup_histogram.gd` | 22 checks, 0 failures; rerun after late-reply guard |
| `-Action TestScript -ScriptPath res://tests/test_unified_histograms.gd` | 127 checks, 0 failures; rerun after late-reply guard |
| `-Action TestScript -ScriptPath res://tests/test_histogram_continuity.gd` | 12 checks, 0 failures |
| `-Action TestScript -ScriptPath res://tests/test_results_histograms.gd` | 37 checks, 0 failures |
| `-Action TestApp` | 99 checks, 0 failures |
| `-Action Doctor` | Prerequisites pass; ADB reports no attached devices |
| `git diff --check -- game/ui/track_browser.gd` | Pass; existing CRLF normalization warning only |

**319 final regression checks, zero failures.** Earlier intermediate passes are
not added again. The first restricted test failed before execution because it
could not read the Windows certificate store; normal local access allowed the
tests to execute. Logs are under `build/logs/`.

Five fixture screenshots under `docs/evidence/personal-comparison-2026-10-11/`
show stale placement withheld, aligned fastest and faster verified PBs, and a
cached new PB at 960×540 and 1600×720. The aligned/stale/verified/small-screen
captures were visually inspected. They use original existing Winter artwork and
a generated default route named Slippery fixture, not the owner's actual course
or live standings. Task-only review ref: `refs/codex/personal-comparison-20261011`;
its receipt and scoped patch are beside the captures. Working branch/index and
unrelated work are preserved.

## Limits and acceptance

Restart the desktop client to load the correction, then inspect the affected
Slippery/car record. A matching placement can remain absent if its read fails;
the stale percentage is never substituted. Population snapshots retain their
existing server refresh cadence, and histogram bins cannot establish an exact
rank on their own. Owner acceptance of the actual account remains outstanding.
No phone is attached; no device test, Android export/install, full Validate or
physics regression was performed. No backend change, live player/race write,
deployment or new asset was needed or performed.
