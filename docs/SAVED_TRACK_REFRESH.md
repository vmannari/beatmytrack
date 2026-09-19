# Saved track selection refresh

2026-09-16; requirements R01/T01-T04 (local creator save and drive workflow).

Saving edited geometry updated the on-disk document and catalog revision, but left the app's selected compiled track unchanged. Home, Garage and the library detail could therefore launch the previous geometry until the track was selected again.

`game/core/app.gd` now recompiles the selected circuit after a successful explicit save of that same circuit. Failed saves and WIP autosaves do not replace the selected saved circuit. Other selected circuits remain selected.

`game/tests/test_creator_refinement.gd` now seeds an older selected circuit, saves a different curve angle, and presses the actual Home Race button without reselecting. It compares both the selection and the running gameplay track against the committed document's content hash.

Actual verification:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestRefinement`: 32 checks, zero failures. Godot reports two ObjectDB instances leaked at exit. An initial test attempt was stopped after a test-harness property typo; the corrected run completed.
- `git diff --check -- game/core/app.gd game/tests/test_creator_refinement.gd`: passes (line-ending warnings only).
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestWorkflow`: 168 checks, zero failures, including WIP persistence and editor practice.

No presentation changes or new screenshot assets. No Android export or device test performed; phone attachment was not checked. Owner acceptance remains: edit a selected saved circuit, Save, return Home or Tracks, and immediately drive it. Existing unrelated working-tree changes were preserved.
