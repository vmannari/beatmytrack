# Editor draft saving — 2026-09-29

Requirements: T01/T04/R01/Q01. The owner requested that abandoned editor sessions stop filling the draft browser with unnamed empty tracks.

The creator now treats its WIP autosave as crash recovery rather than an implicit user save. Closing the editor, starting another track, or loading another draft while the current document has unsaved changes opens a Save / Discard / Cancel dialog. Save requires a non-empty track name; the placeholder `My circuit` is not accepted as an implicit name. Discard deletes only that track's WIP recovery files, preserving an already committed original. Cancel keeps the editor open. A clean, explicitly saved document exits without another prompt.

Changed files: `game/core/app.gd`, `game/persistence/track_library.gd`, `game/tests/test_app.gd`, `game/tests/test_creator.gd`, this report, `DEVELOPMENT_STATUS.md`, and `docs/PHASE_0_PLAN.md`.

Verification: `CheckScript -Script core/app.gd` passed. `git diff --check` passed. `TestCreator` covers WIP-only deletion. The new app-flow assertions cover the real name gate, departure dialog, Discard navigation, and recovery-file removal. The complete `TestApp` run did not reach those assertions because its existing startup fixture now opens the account screen and fails the older `Play exposes creator navigation` expectation before this editor flow; the run was stopped after the script errors left it waiting. This failure was not suppressed.

No Android export or physical-device test was performed. Phone keyboard layout and owner UX acceptance of the dialog remain outstanding.
