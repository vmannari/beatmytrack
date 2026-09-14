# Delete saved user tracks

2026-09-14. Requirements R01/T01-T04: user-requested local track management, persistence and usable menus.

Tracks > Saved tracks > select a track > Delete track opens a named confirmation with Cancel focused. Both race-ready tracks and unfinished drafts have this action; built-in tracks do not. Successful deletion removes the primary JSON and its .tmp/.bak recovery files, invalidates the catalog, removes the favorite and last-used reference, switches a deleted active selection to a built-in circuit, and clears the matching in-memory editor document/history so later autosaving cannot recreate it. Other user tracks and historical race records remain intact. Exported copies outside the local library are not deleted.

The library validates the ID before constructing any path and removes only the three named files in its configured directory. Recovery files are removed first; if removing any existing file fails, the UI reports the error and does not clear application state. This is permanent deletion with confirmation, not a trash/undo feature. No actual owner track was deleted during development.

Changed files: game/persistence/track_library.gd, game/ui/track_browser.gd, game/core/app.gd, game/tests/test_track_deletion.gd, scripts/dev.ps1, this document and the status/phase notes. The new regression is also included in Validate. Physics and schemas are unchanged.

Actual commands used the pinned engine through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- TestDeleteTracks: 19 checks, zero failures (path traversal rejection, confirmation/cancel, primary/recovery removal, unrelated track preservation, favorites/selection/editor cleanup, catalog refresh, built-in exclusion, unfinished-draft action).
- CaptureDeleteTracks: 21 checks, zero failures on Windows Compatibility/OpenGL RTX 3090. [Library action](evidence/delete-track-library.png), [confirmation](evidence/delete-track-confirm.png), [actual output](evidence/delete-track-tests.txt). The initial test setup assigned settings before app startup reloaded them; it was corrected to assign the isolated fixture settings after startup, then rerun successfully.
- Import: passed; Android build-tools remain unavailable.
- TestApp: 84 checks, zero failures.
- TestCatalog: 18 checks, zero failures, including the 5,000-entry query.
- git diff --check: passed.

No phone/device test was performed; devices were not enumerated. Android prerequisites remain unavailable. Remaining acceptance: touch reach and dialog sizing on a physical phone, plus a manual storage-permission failure check. Captures and automated file operations used disposable test directories only.
