# Editor Load lists saved tracks immediately

2026-09-14, R01/T01-T04. Owner requests the saved-track list when Load is selected.

The picker was passing an empty query to String.contains, which filtered out every saved track until text was entered. Empty search now explicitly includes all tracks. The list sorts by name, includes unfinished drafts, shows a result count and empty-state message, and initially focuses the list rather than opening the search keyboard. Cancel is explicit.

Opening Load no longer commits a road preview or saves the current document before showing the list. Choosing a track still confirms pending geometry and saves the outgoing document before replacement; failed preparation keeps the picker available. The loaded track retains its ID and authored geometry. No owner track was changed during testing.

Changed files: game/core/app.gd, game/tests/test_tyres_and_load.gd and status/phase/evidence documentation. No physics, schema or platform dependencies changed.

Actual pinned-engine commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- TestTyresLoad: 23 checks, zero failures, including opening with a pending preview, showing multiple saved tracks without typing, filtering, preserving outgoing work and loading/editing a saved track or unfinished draft. The new initial-list assertion first failed and then passed with the empty-query correction.
- CaptureTyresLoad: 26 checks, zero failures. [Reviewed screenshot](evidence/editor-load-list.png) shows both saved tracks with an empty search and a Cancel button at 1280x720, Windows Compatibility/OpenGL RTX 3090.
- git diff --check: passed.

No phone/device test was performed; attached devices were not enumerated. Physical-phone list scrolling, keyboard behavior and dialog sizing remain acceptance checks. All persistence tests used disposable folders.
