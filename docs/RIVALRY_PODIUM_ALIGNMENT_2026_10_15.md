# Weekly Rivalry podium row alignment — 15 October 2026

**RPA01:** align the car, flag/name and points vertically across the three podium cards. **RPA02:** retain the taller winner, compact hub and approved customised-car presentation. Existing RPC01–RPC04 / RPS01 / RPP01–RPP05 / R01 / Q01 remain.

The cards already shared a bottom edge, but their contents started beneath different-height rank headers. A flexible, noninteractive spacer now absorbs the remaining header space. All three car rectangles, identity rows, flags, names and points share their vertical positions and heights. The gold winner remains taller; names retain ellipsis handling.

[Before, Mobile 1280×720](evidence/rivalry-podium-align-2026-10-15/before-view/mobile/hub-1280x720.png) · [After, Mobile 1280×720](evidence/rivalry-podium-align-2026-10-15/mobile/hub-1280x720.png) · [After, Compatibility 1280×720](evidence/rivalry-podium-align-2026-10-15/gl_compatibility/hub-1280x720.png). Both final renderer folders also contain 960×540 and 1600×720 views and all five vehicle families.

Commands used the pinned Godot 4.7.2 through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with isolated `.tools/rivalry-podium-align-*-user` APPDATA and `BMT_RIVALRY_CARS_EVIDENCE_DIR=res://../docs/evidence/rivalry-podium-align-2026-10-15` for final podium captures:

| Arguments | Actual result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_rivalry_custom_cars.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan`, before edits | 163 checks, zero failures; before screenshots. |
| Same focused test after edits, Mobile/Vulkan and `gl_compatibility`/`opengl3` | **199 + 199 checks, zero failures**, including 36 new row-alignment/winner-height checks at three sizes per renderer. |
| `-Action TestScript -ScriptPath res://tests/test_weekly_rivalry.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan` | **1,136 checks, zero failures**; navigation, track entry, compact 184-unit podium and scrollable standings at three sizes. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | **765 scripts, zero failures**. |

Final car rows start at y143 with height68; identity/name rows at y212 with height24; flags at y215 with height18; points at y237 with height28 in the focused fixtures. Each value matches across all three cards. Settled work stays at141 draw calls versus515 when deliberately forcing the existing car targets to render continuously, then returns to141. These are desktop observations.

Changed implementation: `game/ui/weekly_rivalry_page.gd`; regression coverage: `game/tests/test_rivalry_custom_cars.gd`. This report and the RPA01/RPA02 entries in AGENTS/status/plan record the task. Native renderers, models, cosmetics, materials, camera and backend/canonical contracts were not edited. Raw logs, before files, [task-only patch](evidence/rivalry-podium-align-2026-10-15/scoped-change.patch) and checkpoint receipt are in the evidence directory; the separate Git checkpoint is under `build/rivalry-podium-align-checkpoint`. Main index and other work are preserved.

No physical-phone test/attachment check, APK export/install, deployment or full Validate was performed. Owner visual acceptance and physical-phone readability remain.
