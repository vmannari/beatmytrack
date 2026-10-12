# Reference-led fault messages — 2026-10-11

The owner supplied a large scenic Update required dialog as a presentation
guideline. The local fault message now follows that composition: dimmed menu,
rounded navy panel, original sunset road illustration fading behind editable
text, a large yellow warning, clear heading/cause, top-right Close and a yellow
OK action. Requirement IDs: **FM01–FM04** (reference composition, truthful
actionable copy, modal lifecycle/input, responsive capture), **RLOAD10–11,
V03/V05, B01, R01, Q01**. FM IDs identify this presentation slice.

## Behavior and files

- `game/ui/fault_dialog.gd` and its UID: an owned AcceptDialog subclass preserves
  `dialog_text`, confirmed/canceled signals and existing teardown. Native duplicate
  text/button/title chrome is hidden. A single scrim dims and blocks the menu;
  OK, Close, Enter and Escape dismiss it, restore prior focus and remove the
  scrim. Intentional navigation frees the notice with the old page. Body content
  can scroll independently for unusually long causes without covering OK.
- `game/ui/fault_dialog.gdshader` and its UID: one static CanvasItem scenic fade
  with antialiased rounded border; no new simulation or per-frame callbacks.
- `game/ui/menu_icon.gd`: one original vector warning glyph, rasterized once at
  224px with mipmaps for the 150px warning. Existing glyph sampling is preserved.
- `game/core/app.gd`: failure notices use the custom dialog. Existing affirmative
  export/creator information and preview instructions retain their informational
  dialog; confirmation/offline choices and file dialogs retain their behavior.
- `game/tests/test_fault_dialog.gd` and its UID: real menu input isolation,
  owned dismissal/focus, category/cause, long content, three desktop sizes,
  successful-export classification and page teardown.
- `game/tests/test_rivalry_start_failure.gd` and generated UID: optional `--evidence=` argument
  saves new presentation captures separately from historical evidence.
- This document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, captures and
  the task-only checkpoint record actual results.

For the known old-server compiler mismatch, the category is **Update required**,
the heading is **Can't go online yet**, and the actual cause is retained. One
support row says **Keep racing offline / Choose a downloaded track in Free Race**.
It does not assert that deployment is underway or promise a time/progress guarantee.
Other failure categories use their own heading/cause and omit that support row.
Compiler numbers, diagnostics, duplicate explanations and reference example scores
are not added to player-facing text. No contract check is bypassed.

## Art and provenance

The dialog reuses `game/assets/menu/rivalry_winter_v1.png`, the existing original
sunset mountain/road art from the Rivalry presentation. Its earlier provenance
remains in `docs/RIVALRY_REFERENCE.md`. No generated bitmap, copied reference crop
or new asset download is introduced. The owner's supplied screen is a composition
reference, not a shipping asset. The warning is a new editable SVG path inside
the established icon system; text/actions remain real controls.

## Actual commands and outcomes

Pinned **4.7.2.stable.official.ed1daf0bf**, through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with
process-local APPDATA under `.tools/fault-message-*` and normal Windows
certificate-store access. Fixtures use no owner credentials or live backend.

| Arguments | Actual final outcome |
| --- | --- |
| `-Action CheckScript -ScriptPath res://core/app.gd` | Successful application/dependency compilation |
| `-Action Import` | Successful new global-class/resource registration; UIDs generated |
| `-Action TestScript -ScriptPath res://tests/test_fault_dialog.gd -Graphical` | **83 checks / zero failures**, final Compatibility render |
| Same with `-RenderingMethod mobile -RenderingDriver vulkan` | **83 checks / zero failures**, desktop RTX3090 Mobile Vulkan |
| `-Action TestScript -ScriptPath res://tests/test_rivalry_start_failure.gd -Graphical -TestArgument '--evidence=res://../docs/evidence/fault-message-2026-10-11/rivalry'` | **29 checks / zero failures**; actual failure/refresh/success/navigation flow |
| `-Action TestScript -ScriptPath res://tests/test_race_start_feedback.gd -Graphical` | **21 checks / zero failures**; cancellation, offline confirmation and five-lap recovery |
| `-Action TestApp` | **99 checks / zero failures** |
| `-Action Doctor` | Successful prerequisites check; ADB lists no attached devices |

**315 final checks / zero failures.** The first native preview exposed an upscaled
warning icon and white focused primary text; both were corrected, then the final
modal suite/captures passed. No failing acceptance assertion was weakened.
Compatibility and Mobile UI captures cover 1280×720, 960×540 and 1600×720,
connection/storage/timeout and scrolling long causes. The normal, compact and
connection Compatibility captures were visually inspected. Input tests actually
send mouse/touch to underlying menu controls and keyboard dismissal events.

Captures: `docs/evidence/fault-message-2026-10-11/`, with separate `mobile/`,
`rivalry/` and `free-race/` directories. The general and Rivalry integration
fixtures initially wrote their historical capture paths; those older PNGs were
restored byte-exact from their existing Git checkpoints after the new versions
were saved separately. Logs remain under `build/logs/`.
Task-only review checkpoint: `refs/codex/fault-message-20261011`; working branch,
real index and unrelated changes are preserved.

Restart the desktop game to use the dialog. No phone is attached; no physical
device test or Android export/install was performed. No full Validate, physics
regression suite, backend changes/deployment, live tickets/results or purchases.
Remaining acceptance: owner visual review and physical-device text/touch behavior.
The compiler23/client versus compiler22/server online blocker is unchanged by
this UI task; its matching backend/catalog rollout remains separate.
