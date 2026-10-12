2026-10-09 follow-up: the latest reference removes the third column and places Back/Race below the preview and standings cards. See [current two-card layout and actual verification](RIVALRY_TWO_COLUMN.md).

# Rivalry track detail reference correction — 2026-10-09

Requirements: WR06/WR09-WR10, R01, V03-V05, Q01; the owner's track-detail reference requests the existing three columns, eight standings rows, signed player-relative gaps, a sticky player, a closest challenger and an appropriate default ghost.

The left panel retains its original biome artwork and preview outline. Back to Tracks is reduced to a 48-logical-pixel touch target and returns to the existing rivalry overview/track list. A chequered start marker and forward arrow use the pinned full document's canonical route start and direction, projected onto the retained discovery outline. The verified cached document is used immediately; an uncached document downloads in the background through the existing integrity-checked cache. Until that document is available, the outline remains visible without guessing a start position. The sample fixture and reference's identities/times are never shipping fallbacks.

The centre panel retains the yellow rank and total, with the full ordered track board immediately underneath. Eight complete rows fit the viewport at the checked sizes. Every entrant remains accessible by scroll, touch drag, wheel or the “more drivers” action; the count indicates entrants below the viewport. At the end, that action returns to the top. Every timed competitor has a signed three-decimal difference from the player's weekly PB. Missing times/gaps remain dashes. The player's row retains its yellow outline and appears as an opaque sticky row at the top or bottom while its original row is outside the viewport. The copy disappears when the original row returns; it passes pointer input through so mouse-wheel scrolling still works.

The right panel retains the leading/rival headline and yellow Race action. The closest challenger section contains the actual flag, rank, name, best race time and millisecond gap, with quiet dividers. Tied competitors show “Level with you.” Choice zero follows the nearest faster rival; when leading, it follows the closest challenger, including a tied rival. If the player has no time, an available timed opponent can be selected. Menu labels and race ghost fetching share `WeeklyRivalry.ghost_target`, so the selected challenger is the recording actually requested. Explicit No ghost, leader and personal-PB choices remain. The ghost description updates with the choice. There is no fabricated challenger when no comparable recorded time exists.

Changed files:

- `game/ui/weekly_rivalry_page.gd`: denser detail, challenger, default ghost, compact back action and marker preparation.
- `game/ui/rivalry_track_standings.gd`: full scrolling board, eight-row sizing, gaps, sticky player and continuation action.
- `game/ui/lap_route_view.gd`: opt-in miniature race markers; other callers retain their existing presentation.
- `game/race/weekly_rivalry.gd`: shared presentation-only ghost/challenger selection.
- `game/core/app.gd`: verified preview document preparation and shared ghost target resolution.
- `game/tests/test_rivalry_track_detail.gd`: isolated fixtures, geometry/data invariants, scroll/touch/wheel checks and captures.
- This report, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.

No canonical simulation, physics/rules version, track file, competitive scoring, backend deployment, population isolation or normal-results-first behavior changes.

## Actual validation

Commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, pinned **4.7.2.stable.official.ed1daf0bf**. Runtime tests set `APPDATA` to isolated workspace folders under `build/rivalry-track-detail-*-user`; Windows certificate-store access was required for Godot startup.

| Arguments | Actual result |
|---|---|
| `-Action TestScript -ScriptPath res://tests/test_rivalry_track_detail.gd -Graphical` | **333 checks, zero failures**. Leading, ranked, last-place, tied, unranked and twenty-driver fields; eight complete rows, signed gaps, unchanged competitive data, top/bottom sticky behavior, duplicate removal, more action, touch dragging, wheel over the pinned row, canonical start/reversal equality, original outline preservation and menu/race ghost agreement. Twenty-four native captures at 1280×720, 960×540 and 1600×720. |
| `-Action TestScript -ScriptPath res://tests/test_weekly_rivalry.gd -Graphical` | **1,256 checks, zero failures**. Existing overview, track navigation, result, pending-verification, finale and unranked behavior. |
| `-Action TestApp` | **99 checks, zero failures**. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | **390 scripts, zero failures**. |
| `-Action Doctor` | Pinned engine/matching templates found; tablet `f0ba474a` listed **offline**. No physical-device test performed. |

Final logs are in [the evidence directory](evidence/rivalry-track-detail-2026-10-09/logs). Initial execution-policy, default user-log, certificate-store and ADB sandbox failures were addressed with the process-scoped execution-policy option, isolated storage and approved native access. An initial undeclared script identifier was corrected to the existing cloud adapter. Focused scrolling tests exposed that scrollbar signals precede content layout; deferred updates fix stale sticky placement/counts. A marker fixture initially contained unsupported dictionary keys; JSON serialization now matches real full-document input, without weakening document validation or geometry equality. Failed runs are retained alongside final evidence.

Inspected captures: [leading desert detail](evidence/rivalry-track-detail-2026-10-09/ui/leader-1280x720.png), [compact detail](evidence/rivalry-track-detail-2026-10-09/ui/leader-960x540.png), [sticky leader](evidence/rivalry-track-detail-2026-10-09/ui/leader-scrolled-1280x720.png), [sticky last-place player](evidence/rivalry-track-detail-2026-10-09/ui/last-player-960x540.png), [ranked detail](evidence/rivalry-track-detail-2026-10-09/ui/ranked-1280x720.png), [twenty-driver field](evidence/rivalry-track-detail-2026-10-09/ui/twenty-drivers-960x540.png). These are explicit isolated UI fixtures, not live standings. Existing original artwork is reused; no new raster assets or external dependencies.

Remaining acceptance: owner visual/interaction review, actual-device legibility and gestures, live-backend document/ghost behavior under slow or failed connections, and mobile performance. No Android export/install, live competitive submission, full Validate/physics regression, backend rollout or production action was performed. A task-only source patch and hashes provide the review checkpoint while preserving the existing dirty working tree.
