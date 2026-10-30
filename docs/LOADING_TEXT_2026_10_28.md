# Loading-screen character repair — 28 October 2026

LT01 repairs the owner's reported corrupted loading-screen symbols. Thirteen presentation lines in `game/core/app.gd` contained UTF-8 punctuation previously decoded as Windows-1252: ellipses appeared as `â€¦`, separators as `Â·`, and dimensions used `Ã—`. The original Unicode ellipsis, middle dot and multiplication sign now render normally during track/race/ghost preparation, parking-hall entry and the track-preparation caption.

LT02 updates `game/localization/messages.pot` and `en.po` for those messages. All nine resulting source messages already have nonempty translations in every one of the twelve packaged language catalogues. Unrelated catalogue blocks and their source references are retained.

R01 keeps every other App line exact to the task-start snapshot, including the existing Garage changes. No loading behavior, layout, fonts, artwork or simulation changes. The runner archives its generated `project.godot` version and `core/build_identity.gd` and restores its pre-run bytes. A later workspace identity differs from both the task-start and this task's generated identity; that concurrent metadata is preserved. No main-index staging or commit.

Q01 actual commands and outcomes:

- `python scripts/localization.py extract`: source/English inventory refreshed, then unrelated reference-only churn excluded; final source inventory remains current.
- `python -m unittest discover -s scripts -p test_localization.py`: **14 tests pass** on the final catalogues.
- `python docs/evidence/loading-text-2026-10-28/run_checks.py headless`: pinned Godot **4.7.2 stable ed1daf0bf**, existing `test_race_loading.gd`: **348 checks, zero failures**. Includes actual race preparation/countdown, cancellation and failed-ticket loading text.
- `python docs/evidence/loading-text-2026-10-28/run_checks.py native`: Compatibility capture of the original loading component, using literals extracted from task-start/current App source: **24 checks, zero failures**, eight before/after PNGs covering English/Finnish track and parking screens. Visually inspected the before/after English track and corrected Finnish parking views.
- `python docs/evidence/loading-text-2026-10-28/verify_sources.py`: exact thirteen-line reversible encoding repair, translation coverage, current English inventory, retired task-generated metadata, whitespace and reverse-apply validation of the task-only patch pass. Its initial strict task-start metadata assertion exposed the later concurrent identity; the final audit records and preserves that identity.

The initial sandboxed Godot attempt stopped at `Failed to read the root certificate store` / `Access denied` before running assertions. The same isolated offline test passed after approved execution with Windows certificate-store access. The capture helper is preserved in evidence and copied temporarily into `game/tests` for the repository entry point; the temporary file was removed.

Evidence: [report](evidence/loading-text-2026-10-28/report.json), [task-only patch](evidence/loading-text-2026-10-28/task.patch), [before](evidence/loading-text-2026-10-28/before-en-track.png), [after](evidence/loading-text-2026-10-28/after-en-track.png), [Finnish parking](evidence/loading-text-2026-10-28/after-fi-parking.png).

Reload/rebuild and owner appearance acceptance remain. No physical-device test or attachment query, APK, deployment, real authentication/purchase, owner-save mutation or owner-process restart was performed.
