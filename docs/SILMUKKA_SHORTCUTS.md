# Silmukka shortcut correction — 2026-09-16

**Owner screenshot follow-up:** [v7 inside-boundary correction](SILMUKKA_HAIRPIN_BOUNDARY.md) supersedes the narrower-cut acceptance and percentage gate below.

Requirements: G01 / R03 / R07 / T02 / V05. The owner could cut Silmukka without a penalty after the outside-corner fix. This supersedes the v5 detector described in OUTER_CURVE_SHORTCUTS.md.

## Finding and implementation

The v5 diagnostic caught only one of eleven sampled substantial chord cuts by their rejoin. Its outside-position debt reset could forgive the entire earlier bypass. Additionally, corner allowances credited turns that the car had skipped, and an outside sample vetoed an inside cut elsewhere in the excursion.

TrackSession now compares signed route progress with actual distance over a contiguous excursion. It requires more than 8 m and 15% distance saved, plus spatial proof of an inside bypass beyond the existing road/kerb tolerance. It does not award geometric corner credit for skipped turns or erase evidence based on the side of the rejoin. Outside samples are not positive evidence, but cannot veto a separate inside bypass.

The recent driven approach is retained (bounded to 512 samples, sampled at least 0.5 m apart) so a late progress catch-up does not mistake already-driven road for a cut. History resets each completed lap, preventing a previous clean lap from concealing the next lap's shortcut. Excursion comparisons reset after 40 m on the allowed corridor with continuous progress, after the bounded excursion history fills, or after a proven bypass. These are distance bounds, not a confirmation delay.

One continuous cut receives one penalty. Rearming requires at least half a second and 20 m back within the road corridor, aligned with its direction; briefly crossing another road cannot rearm the warning. First-warning timing remains immediate upon proof. Penalized laps still count, the penalty remains +5 seconds, and the HUD warning persists two seconds. Rules key is `standing-5-local-v6`; handling is unchanged.

The final route projection is unchanged from v5. A stricter local-branch experiment was rejected because it did not resolve the legal-line regressions. The final fix relies on retained driven-path evidence, not that experimental restriction.

## Reproduction and tests

`game/tests/fixtures/silmukka.json` is a read-only snapshot of the owner's locally saved Silmukka track, captured for regression testing. The original saved file was not modified. Tests compile this fixture instead of depending on mutable user storage.

Commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 <Action>`, using pinned Godot 4.7.2.

| Action | Actual result |
| --- | --- |
| TestSilmukka | 101 checks, zero failures: eleven cuts saving 16–55 m, each at 60/120/240 Hz; clean approaches; exactly one penalty; clean-lap history cannot hide the following lap's cut |
| TestRouteValidation | 55 checks, zero failures: kerbs, wide exits and rejoins, rotated inside cuts, hairpins, crossings, early feedback and lap counting |
| TestTracks | 167 checks, zero failures, including driven native laps and replay comparisons |
| TestRecords | 53 checks, zero failures |
| TestApp | 86 checks, zero failures |
| TestPieces | 172 checks, zero failures |
| TestFreeEditor | 55 checks, zero failures |
| CaptureShortcutFeedback | 10 checks, zero failures; compact warning capture inspected |
| ReviewRouteValidation | 49 diagnostic offset trajectories on seven saved tracks; all 21 centreline and ±4 m paths finish without penalties |

699 targeted checks passed in total. All 33 Silmukka cut runs warn during the cut or within one simulation tick after rejoining: maximum measured post-rejoin delay 0.0167 s. The synthetic hairpin still warns 42–50 ms after leaving its allowed corridor at 24 m/s. These are fixture measurements, not a guaranteed bound on every track.

Evidence is in [evidence/silmukka-shortcuts](evidence/silmukka-shortcuts/), including the before diagnostic, final assertion logs, saved-track review and regenerated warning captures. Intermediate failed experiments are not counted as passing checks.

Changed files: `game/race/track_session.gd`, `game/race/race_rules.gd`, `game/track/native_track.gd`, `game/tests/test_route_validation.gd`, new `game/tests/test_silmukka.gd` and its fixture, `scripts/dev.ps1`, plus this record and the status/plan links. Removed the obsolete blanket outside exemption and corner-credit helpers. The older helper-only debt-reset test was replaced with actual outside-lap/rejoin assertions, retaining the no-false-penalty requirement.

## Limits and acceptance

These are deterministic scripted trajectories, not a human driving acceptance test. Some extreme ±6/±8 m saved-track paths still trigger penalties or fail to finish; they are not all legal racing lines, and their classification is not asserted as correct. The prior Over and under +6 m projection/finish issue remains outside this fix. Complex overlapping routes still need owner testing. Full Validate was not rerun, and its previously recorded engine-process crash is not claimed resolved.

No phone test or mobile performance acceptance was performed. No camera, art or HUD layout changes were made. Unrelated working-tree changes were preserved; no combined Git commit was made.
