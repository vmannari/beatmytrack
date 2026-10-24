# Rivalry name integration, 2026-10-24

The owner found that the names looked detached from the accepted podiums. The opaque footer was covering the card's lower outline, and its separately chosen fill differed from the card's medal hue.

| Requirement | Change |
| --- | --- |
| RNI01: continuous card | A one-unit content inset keeps the metallic frame visible around the full card, including both footer sides and its bottom. |
| RNI02: integrated names | The footer derives its fill from the card's medal color, darkened by 6%. The divider alpha decreases from 0.32 to 0.18. Side padding increases from 10 to 12 while flag/name/score gaps decrease from eight to six; names receive a restrained 12% medal tint. |

The accepted background script/shader are unchanged. Equal 194-unit card heights, 56-unit footers, 28-unit flags, 20-unit names and 22-unit points/11-unit PTS remain. Actual cars, paint/customisation, static rendering, name-profile actions, live scores, track selection-only highlighting and six-unit track padding retain their existing behavior.

Runtime changes are confined to `game/ui/weekly_rivalry_page.gd`. The focused test adds full-footer containment inside the metallic frame, related medal hues and quiet-divider checks while retaining all earlier assertions. Native close-ups are captured directly from the rendered viewport alongside full before/after views at 960x540, 1280x720 and 1600x720. No replacement bitmap artwork was introduced.

Exact commands, durations, outcomes, hashes and a task-only checkpoint are in `docs/evidence/rivalry-name-integration-2026-10-24/`. The runner uses the pinned Godot through `scripts/dev.ps1` and isolated workspace user data. Mobile means desktop Vulkan. The previously documented unrelated detail-count failure is outside this change; no detail-count assertion or code was modified.

Client reload and owner appearance acceptance remain. No phone/tablet attachment check or physical-device test, APK, live mutation, purchase, deployment or owner-process restart was performed. Concurrent work is preserved.

Final checks: 277 headless, 292 Compatibility and 292 desktop Mobile focused checks pass; full Weekly Rivalry1145, native cars199 and parser1115 pass. Both accepted background source hashes are unchanged.
