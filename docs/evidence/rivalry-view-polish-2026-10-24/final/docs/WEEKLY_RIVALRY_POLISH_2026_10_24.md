# Weekly Rivalry presentation, 2026-10-24

The owner supplied a podium/standings reference, requested tighter track-list right padding, then clarified that added gradients should be removed while the podiums retain the reference's gold, cool silver-blue and bronze backgrounds.

| Requirement | Result |
| --- | --- |
| WRP01: podium cards | Flat medal-colored backgrounds, matching borders and subtle shadows; winner rises eight logical units. The 194-unit winner and 186-unit side cards share their bottom edge. Actual native cars use an 88-unit frame with existing fit-to-frame support, contact shadows, Garage finish and bounded static rendering. |
| WRP02: podium information | A dedicated 48-unit footer has a subtle top divider, left flag/name and right score with separate smaller PTS. Scores and units cannot wrap, and the score column reserves 36 units. Car, footer, flag, name and score baselines remain aligned across all three cards. |
| WRP03: standings | Flat gold player highlight, edged top-three badges and quieter six-unit scrollbar styling. The heading gutter tracks the scrollbar's actual inherited width so headings and values stay aligned. |
| WRP04: tracks | Flat backgrounds, quiet selection border, preserved focus ring, no yellow stripe, aligned ranks/times/statuses and only six logical units of padding at the right edge. Entire rows remain the existing detail-opening action. |
| WRP05: header | Actual ordinal position/field size and points ahead or to lead; tied, unranked and single-driver states have explicit wording. Week/countdown share a bordered element at the right. Score-only refresh updates the summary without replacing cars or input controls. |
| WRP06: shared presentation | Slightly darker Rivalry backdrop, restrained selected navigation borders/shadows, and reference-colored podium fills. No new gradient or per-frame shader remains. |

Runtime changes are confined to `game/ui/weekly_rivalry_page.gd`, `game/ui/menu_style.gd` and `game/ui/race_mode_rail.gd`. `game/tests/test_weekly_rivalry.gd` now asserts the owner's raised-winner requirement instead of the superseded equal-card-top requirement and supports a separate evidence directory. Its remaining assertions are retained. `game/tests/test_rivalry_view_polish.gd` adds native geometry, footer wrapping, reference-color, live-refresh, gap-state, scrollbar alignment and track-padding checks. Fixture names/scores are test data only; shipping values still come from the existing model.

The evidence directory is `docs/evidence/rivalry-view-polish-2026-10-24/`. `run_checks.ps1` invokes the pinned engine through `scripts/dev.ps1`; per-mode results record actual arguments, durations, logs and exit codes. Native captures cover 960×540, 1280×720 and 1600×720. Task-start runtime/test copies and a task-only patch preserve the other changes already present in this working tree.

Initial failures are retained: Windows execution policy required an explicitly scoped PowerShell invocation, sandboxed Godot could not read the Windows root certificate store, unconstrained footer labels wrapped scores vertically, and the inherited scrollbar width initially displaced the GAP heading. The fixture's source-self mapping and final track-entry ordering were also corrected. The short-lived gradient helper/shader was removed following the owner's direction. The raised-card assertion changes the expected presentation; no scoring, interaction, car or visibility assertion was weakened.

The broader track-detail suite retains one failure in 321 checks: after its twenty-driver scenario, a later fourteen-driver view can briefly retain the old “12 more drivers” label. The exact task-start copies of all three edited runtime scripts were reloaded into an isolated process's memory; the same unchanged suite again returned 321 checks with this one failure. The probe records the correct eight visible rows alongside the stale label, then the corrected label on the next scenario. `probe_rivalry_detail_polish.gd` and `detail-baseline-probe.log` retain that comparison. No source file or owner process was replaced for this control, and no assertion was weakened.

Final verification results and source hashes are recorded in `report.json`. The new focused fixture uses actual native UI and 3D cars inside a representative menu shell; the existing Weekly Rivalry regression also exercises the real App and saves its own views.

Final focused checks pass: 142 headless, 145 Compatibility and 145 desktop Mobile. Existing native car checks pass with 135 headless/199 Compatibility checks, and the full Weekly Rivalry interaction suite passes with 1124 headless/1145 Compatibility checks. Player-profile checks pass 2176 checks, App passes 141, and the all-project parser passes 1102 scripts. The retained broader detail failure above is not counted as a pass.

Client page reload and owner appearance acceptance remain. No phone/tablet attachment check or physical-device test was performed. Mobile captures use the desktop Vulkan renderer. No APK, live account/backend mutation, purchase, deployment or owner-process restart was performed. Existing concurrent changes are preserved.
