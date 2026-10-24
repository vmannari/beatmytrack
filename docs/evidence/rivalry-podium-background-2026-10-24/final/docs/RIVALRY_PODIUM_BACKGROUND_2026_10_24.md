# Rivalry podium background correction, 2026-10-24

The owner clarified that the podium background should follow the supplied reference's stage treatment and that tracks should have a highlight only when selected. This supersedes the earlier interpretation of the podiums as uniform flat fills. Other panels retain their existing flat style.

| Requirement | Implemented behavior |
| --- | --- |
| RPB01: reference podium backgrounds | Dark gold, silver-blue and bronze upper walls; localized medal-colored light on a faint perspective floor; subdued side edges; matching metallic borders and opaque, separate player footers. Existing native cars, contact shadows, poses, cosmetics, fit, raised winner, footer alignment and render-target limits remain. |
| RPB02: selected tracks only | Normal, hovered and pressed states share the same neutral fill/border on unselected rows. Only the selected row receives the lighter fill and border. Keyboard focus still selects the intended track and retains its focus ring. Moving the pointer over a different row does not select it. |

`game/ui/rivalry_podium_backdrop.gd` and its shader draw a static stage behind each car. The stage ends at the actual footer boundary, using container-managed holders and layout signals. It has no animation, frame callback, added 3D viewport or external asset. `game/ui/weekly_rivalry_page.gd` attaches the stages and makes track styles depend only on selection. Shared themes and other panels are unchanged by this follow-up.

`game/tests/test_rivalry_view_polish.gd` retains the existing card, score, alignment, live-refresh and track-padding assertions. The superseded flat-podium check is replaced by stage containment and actual native light/palette checks. It also verifies all three button states, moving selection, and pointer hover. With cars temporarily hidden, native pixels independently verify the floor pool against the darker wall and edges; normal captures restore the actual cars. The test accepts a separate evidence destination and exact task-start source for comparisons.

Evidence, exact command arguments, durations, outcomes, source hashes and the task-only checkpoint are in `docs/evidence/rivalry-podium-background-2026-10-24/`. Native comparisons cover 960x540, 1280x720 and 1600x720. `run_checks.ps1` uses the pinned Godot through `scripts/dev.ps1` and isolated workspace user data. The initial native check caught the container fitting the stage behind the footer; that failed log is retained. A separate holder now confines lighting above the footer without changing any assertion threshold.

The existing broader detail-count failure documented in `WEEKLY_RIVALRY_POLISH_2026_10_24.md` remains outside this presentation follow-up. No detail-count code or assertion was changed.

Client reload and owner appearance acceptance remain. No phone/tablet attachment check or physical-device test was performed; Mobile evidence uses desktop Vulkan. No APK, purchase, live backend/account mutation, deployment or owner-process restart was performed. Concurrent work is preserved.

Final checks: 196 headless, 210 Compatibility and 210 desktop Mobile focused checks pass. The existing full Weekly Rivalry interaction suite passes 1145 checks, native car checks pass 199, and all 1106 project scripts parse. Compatibility's settled draw count is 155 versus 529 while all three native car views are forced live; the three new stage quads account for the previous task's 152-to-155 change. This is a desktop work count, not device performance certification.
