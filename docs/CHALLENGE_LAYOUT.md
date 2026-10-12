# Challenge creation alignment — 2026-10-11

The owner supplied a Create challenge reference and requested closer layout and alignment. The existing creation page now uses a 1.45:1 settings/preview split. The heading occupies the left column; the preview begins at the heading's top edge and ends at the settings' bottom edge. Cancel and Create & share remain in the separate bottom action row.

Requirement IDs: **CH14, V03, V05, R01, Q01** for presentation and verification; **CH09–CH11, CH02–CH04, CH15** for preserved exact-result, target, duration and tries behavior.

All six form rows share one fixed icon/label width and one aligned control column. Track selection has the existing scenic thumbnail, selected name, creator and Change track search action. Challenge types have centered icon/title/detail groups and consistent selected colors. Car artwork aligns with the other controls. The supported verified target is emphasized in yellow. Tries help belongs to the label column, so it cannot shift the choices. All ordinary selection targets retain a logical minimum height of 52.

The brighter original scenic preview keeps the actual route outline, with a compact name/creator plaque and biome label. Its four summary values share one left edge, with alternating quiet row fills. Empty status space collapses; pending, retry and submission-error states remain visible when needed. All default settings remain immediately visible at the tested landscape sizes; opening search or help uses the existing bounded settings scroll.

This pass uses the reference's composition with the existing feature contract: verified PB/exact completed finish for Beat my time, untargeted Group, 1/3/5/unlimited tries and 24-hour/3-day/7-day durations. Custom unverified target times, community visibility, 14 days, a new preview flow and friend delivery were not implemented. The reference image is not a shipping asset. Original scenery, fictional car art, fonts and vector icons are reused; there are no new assets or dependencies.

## Changed files

- `game/ui/challenge_create.gd`: aligned two-column page, field/summary geometry, thumbnail/plaque/biome presentation, selected option content and status visibility.
- `game/tests/test_challenges.gd`: existing layout suite now checks all six control edges, all summary value edges, panel top/bottom alignment, Group target presentation and visible creation errors.
- `docs/CHALLENGE_LAYOUT.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`: scope, actual outcomes and remaining acceptance.

## Actual verification

Commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, pinned **4.7.2.stable.official.ed1daf0bf**, and workspace-local `APPDATA` directories under `.tools/challenge-layout-20261011/`. `BMT_CHALLENGE_CAPTURE_DIR` points to the screenshots below. This isolates checks from player records and account caches.

| Actual command | Outcome |
| --- | --- |
| `CheckScript -ScriptPath res://ui/challenge_create.gd` | Passed with isolated local user data. The preceding default-user-data attempt could not open the Windows user log; it is not claimed as successful verification. |
| `TestScript -ScriptPath res://tests/test_challenges.gd -Graphical` | Final **182 checks, zero failures**, 21 captures at 1280×720, 960×540 and 1600×720. Exact finished-ticket creation, pending/error gates, target modes, tries submission, cancellation and existing challenge pages remain covered. |
| `TestApp` | **99 checks, zero failures** with a separate workspace-local user directory. |
| Scoped checkpoint `git diff --check` | Passed for changed source/document files; task-only before/after patch and Git review ref saved. |

The initial restricted graphical run produced all 140 then-existing passing checks but emitted a Windows certificate-store access error. Final graphical and application commands ran with normal local access and clean logs. No failing acceptance assertion was relaxed. Adding collapsed status exposed a submission-error parent-visibility issue during review; this was fixed and is checked by the final suite.

[Final challenge log](evidence/challenge-layout-2026-10-11/menus-final.log), [application log](evidence/challenge-layout-2026-10-11/app.log), [initial restricted log](evidence/challenge-layout-2026-10-11/menus-first.log).

## Screenshots and remaining acceptance

Inspected actual Godot captures:

- [Standard creation](evidence/challenge-layout-2026-10-11/screenshots/menu-create-1280x720.png)
- [Compact creation](evidence/challenge-layout-2026-10-11/screenshots/menu-create-960x540.png)
- [Wide Group creation](evidence/challenge-layout-2026-10-11/screenshots/menu-create-group-1600x720.png)
- [Exact completed-result creation](evidence/challenge-layout-2026-10-11/screenshots/finished-page-960x540.png)

Captures use isolated presentation fixtures; their displayed name and time are not inserted into live records. Owner visual acceptance, phone touch/search/help/keyboard and safe-area checks remain. No Android device test or attachment check, APK export/install, backend test/deployment, physics change, full Validate or production deployment was performed.

Review checkpoint: `refs/codex/challenge-layout-2026-10-11`. Inspect `git diff refs/codex/challenge-layout-2026-10-11^ refs/codex/challenge-layout-2026-10-11`. The snapshot parent contains the pre-change task files; HEAD, the existing index and unrelated work remain intact. Receipt: [checkpoint.json](evidence/challenge-layout-2026-10-11/checkpoint.json).
