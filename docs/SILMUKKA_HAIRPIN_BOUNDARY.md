# Screenshot hairpin follow-up — 2026-09-16

**Superseded for tight islands:** [v8 constructed-hairpin crossing correction](TIGHT_HAIRPIN_CROSSINGS.md). The later review also corrects the assumption that all smoothed-route diagnostic paths represent legal driving.

Requirements G01 / R03 / R07 / T02 / V05. Owner supplied a paused fourth-lap screenshot showing an inside-grass crossing of Silmukka's central hairpin, with earlier penalties already accumulated. This supersedes v6 acceptance for narrower cuts. The screenshot does not supply an exact recorded trajectory; tests reconstruct a family of narrower crossings at that bend.

## Cause and change

The road-radius calculation took the wider of the two sides of the route. At the photographed hairpin, the route bends differently from the actual road centre. Borrowing the outside width allowed 11 m of inside separation in the spatial proof test, including overlap margins. Several substantial grass crossings therefore produced no proof of a shortcut.

`NativeTrack` now caches a separate inside-boundary radius for cut evidence, using the local bend direction and a one-sided surface scan. The nominal road half-width remains a conservative floor, and the existing kerb/car/raster margins remain. The measured allowance at this bend is now 8 m instead of 11 m. The wider radius still serves general route-corridor tracking; this does not tighten outside excursions globally.

`TrackSession` retains the requirement to save more than 8 m and to prove an inside bypass. The additional 15% ratio was removed because its denominator included the clean approach, which could dilute evidence from the same shortcut depending on where the comparison window began. A briefly tried 4 m threshold was rejected after it caused legal-line regressions. Final rules key: `standing-5-local-v7`. No handling, rearm, HUD or camera changes.

## Actual checks

Commands used pinned Godot 4.7.2 through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 <Action>`.

| Action | Result |
| --- | --- |
| TestSilmukka | 140 checks, zero failures |
| TestRouteValidation | 55 checks, zero failures |
| TestTracks | 167 checks, zero failures; native driven laps and replay comparisons |
| TestRecords | 53 checks, zero failures |
| TestApp | 86 checks, zero failures |
| TestPieces | 172 checks, zero failures |
| TestFreeEditor | 55 checks, zero failures |
| ReviewRouteValidation | Read-only diagnostic over 49 saved-track paths; all 21 centreline and ±4 m paths finish with zero penalties |

728 assertion checks pass. `git diff --check` on the changed runtime files passes (Git emits existing CRLF normalization notices).

The original Silmukka fixture still exactly matches the saved owner document. The new matrix covers sixteen narrow chords through route samples 50–100: fifteen substantial grass cuts are penalized by rejoin. The shortest chord (65–85) saves only 6.48 m and reaches 6.82 m separation, within the retained generous corridor, so it remains unpenalized. The initial provisional assertion that every chord should be penalized was corrected after measuring this geometry; no general kerb allowance was removed. The earlier v6 diagnostic missed seven of the fifteen larger lines.

Additional tests stop for two seconds on the inside grass before continuing and take the same narrow cut on all five laps. Stopping does not erase evidence; each lap receives exactly one penalty, including lap four, for +25 s total. Existing cut-timing, outside-rejoin and kerb assertions remain intact.

Logs: [before narrow-cut diagnostic](evidence/silmukka-hairpin/silmukka-screenshot-before.log), [final Silmukka assertions](evidence/silmukka-hairpin/screenshot-final-TestSilmukka.log), [final route assertions](evidence/silmukka-hairpin/screenshot-final-TestRouteValidation.log), [saved-track review](evidence/silmukka-hairpin/silmukka-screenshot-owner-final.log). Other command logs are alongside them.

Changed files: `game/track/native_track.gd`, `game/race/track_session.gd`, `game/race/race_rules.gd`, `game/tests/test_silmukka.gd`, this document, status/plan links and evidence logs. The saved owner track was not modified.

## Remaining acceptance

The exact screenshot drive was not recorded or replayed; human driving of that crossing remains the acceptance check. Extreme ±6/±8 m diagnostic paths still include penalties and unfinished laps and are not classified as universally valid or invalid. Broader overlapping-route limitations from the previous review remain. No phone test or mobile performance test was performed. Full Validate was not rerun; the earlier engine-process crash is not claimed resolved. No visible UI changes were made, so existing HUD captures remain representative. Unrelated workspace changes were preserved; no combined Git commit was made.
