# Rivalry decorations and footer correction, 2026-10-12

AD01–AD04 / AR01/AR02/AR08/AR10 / WC01–WC04 / V03–V05 / R01 / Q01: the owner reports misplaced/poor-looking Weekly Champion and Joint Weekly Champion decorations, then requests an unclipped bottom action row and a corrected Perfect Week badge.

- **AD01:** center the heading, subtitle and context as one award block. Fit the wreath around the actual heading width, so the longer joint-champion title gets the same balanced clearance. Place the crown above the words, clear of their bounds.
- **AD02:** replace the hand-drawn feather-like leaf stacks and flat hero crown with original editable SVG artwork: a curved botanical laurel with pointed paired leaves and restrained gold shading, plus a matching detailed crown. Mirror one branch using a drawing transform, avoiding the negative-width rectangle offset found during capture review.
- **AD03:** use that same artwork in the earned Perfect Week badge. The two-line editable lettering has its own space; the smaller crown sits above it and the side branches stay clear. Increase badge width from 100 to 112 logical units, retaining its 72-unit height.
- **AD04:** keep the 52-unit Share/Continue row outside the body clipping viewport. If content cannot fit, only the body can scroll. Compact right-card spacing so all five track rows remain visible at the tested sizes, including the four-highlight joint-champion view.

Previously the crown centered on the whole hero while the heading was left-aligned. Laurels used nearly the entire hero width and looked like isolated vertical leaf stacks. The previous footer checks compared against the full root/window; the page's bottom clipping inset could still cut the actions, particularly in a joint championship. New checks use both the actual page boundary and body clipping viewport.

New assets are original repo-native SVGs authored for this correction. They reuse no pixels from the owner's reference and add no generated raster, third-party dependency or runtime API. Their Godot import metadata is included. No race, score, achievement eligibility, car/condition, backend, save or canonical camera contract changes were made.

## Changed files

- `game/ui/rivalry_award_art.gd` — shared SVG crown/branches, exact mirrored drawing and decoration bounds.
- `game/ui/weekly_rivalry_finale.gd` — centered/fitted title group, fixed footer/body containment, compact right cards and badge spacing.
- `game/assets/ui/awards/crown.svg`, `laurel_left.svg` and their `.import` metadata — original editable artwork.
- `game/tests/test_rivalry_awards.gd` — crown/heading alignment, branch clearance, Perfect Week bounds, native pixel symmetry/nonempty artwork, page/body/footer clipping checks and configurable capture destination.
- This document, the follow-up in `docs/RIVALRY_AWARDS.md`, status/plan entries and scoped evidence/checkpoint.

## Actual verification

All engine commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, pinned **4.7.2.stable.official.ed1daf0bf**. Set `BMT_RIVALRY_AWARDS_CAPTURE_DIR` to the absolute path of `docs/evidence/rivalry-award-decoration-2026-10-12/ui` for new captures; historical ceremony evidence was preserved.

| Actual action/arguments | Outcome |
| --- | --- |
| `-Action Import -CommandTimeoutSeconds 120` | Passed; imported both SVGs. |
| `-Action TestScript -ScriptPath res://tests/test_rivalry_awards.gd -Graphical -CommandTimeoutSeconds 180` | Final **1,970 checks / 0 failures**, **33 captures**. Champion/joint/Perfect Week alignment, native branch-pixel symmetry, four sizes, five actual cars, all five initially visible tracks, sharing/Continue and page clipping checks. |
| Same with `-RenderingMethod mobile -RenderingDriver vulkan` | Final **1,970 checks / 0 failures**, **33 captures**, desktop Vulkan only. |
| `-Action TestScript -ScriptPath res://tests/test_weekly_rivalry.gd -CommandTimeoutSeconds 120` | **1,115 checks / 0 failures**; active hub, touch targets, finished detail and navigation retained. |
| `-Action TestScript -ScriptPath res://tests/test_rivalry_week_completion.gd -CommandTimeoutSeconds 120` | **38 checks / 0 failures**; actual Continue flow unchanged. Also passed at the initial correction stage. |
| `-Action Doctor` | Exact prerequisites found; **empty ADB device list**. |
| Targeted whitespace and reverse-checkpoint applicability | Recorded by final checkpoint validation. |

The intermediate pointed-leaf attempt failed clearance checks (**558 failures**) and was replaced with bounded SVG branch artwork. Capture review then revealed the negative-width drawing offset; explicit mirrored drawing and actual transparent-viewport pixel comparison verify its correction. Both branch pixels and geometry now align; checks were not relaxed to permit overlap. One native rerun encountered a concurrent unrelated Garage typed-array error; that source was corrected by the other ongoing workspace work, and this task's final reruns passed without editing Garage files.

Inspected fixture evidence: [champion and Perfect Week](evidence/rivalry-award-decoration-2026-10-12/ui/perfect-1280x720.png), [joint champion with full footer](evidence/rivalry-award-decoration-2026-10-12/ui/tied-1280x720.png), [small-screen Perfect Week](evidence/rivalry-award-decoration-2026-10-12/ui/perfect-960x540.png), and [small-screen joint winner](evidence/rivalry-award-decoration-2026-10-12/ui/tied-960x540.png). Equivalent Vulkan captures are under `ui/mobile/`. These show synthetic fixture standings, not live player results.

No phone was attached, and no physical-device test, Android export/install, backend/full physics regression, live account mutation or deployment was performed. Remaining acceptance is the owner's visual review and phone readability/native sharing; existing PB-rollout and permanent-trophy/collision-evidence limitations are unchanged. Restart the game to load the correction.

The [task-only checkpoint](evidence/rivalry-award-decoration-2026-10-12/scoped-change.patch) and [manifest](evidence/rivalry-award-decoration-2026-10-12/checkpoint.json) preserve unrelated work. No mixed working-tree commit was created.
