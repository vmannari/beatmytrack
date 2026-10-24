# Object rotation — 2026-10-23

OR01: Objects now have sixteen discrete orientations, 22.5° apart. Rotate advances to the next absolute orientation, including returning to the grid after a free angle and wrapping at 360°.

OR02: Tap the angle beside Rotate, or the angle in the object palette, to open the native rotation picker. It offers all sixteen orientations and an additional Free rotation option with a continuous slider and a numeric angle field. Apply commits the selected angle; Cancel leaves the object and placement angle unchanged. Object runs retain their tangent-based orientation.

OR03/R01: Selected objects retain position, scale and other fields; each applied change uses the existing undo, redo and local WIP persistence. New placements use the selected angle without creating history until an object is placed. Pending dialogs check the document, canvas, selection and object kind before applying. Track formats, compiler and driving rules are unchanged.

Changed runtime files: `game/core/app.gd`, `game/editor/object_browser.gd`, and the new `game/editor/object_rotation.gd`. Tests: new `game/tests/test_object_rotation.gd`; `game/tests/test_editor_v2.gd` expects 22.5° and waits for startup/preparation before exercising actual touch placement.

G01/Q01 evidence and exact commands are in [the evidence directory](evidence/object-rotation-2026-10-23/), with native screenshots at 1280×720, 960×540 and 1600×900. [Free rotation at 960×540](evidence/object-rotation-2026-10-23/free-rotation-960-gl_compatibility.png) and [all sixteen directions](evidence/object-rotation-2026-10-23/sixteen-orientations-mobile.png) were visually inspected.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/object-rotation-2026-10-23/run.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/object-rotation-2026-10-23/run.ps1 -Graphical -Renderer gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/object-rotation-2026-10-23/run.ps1 -Graphical -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/object-rotation-2026-10-23/run.ps1 -TestName test_editor_workflow
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/object-rotation-2026-10-23/run.ps1 -TestName test_editor_v2
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/object-rotation-2026-10-23/run.ps1 -TestName test_app
git diff --check -- game/core/app.gd game/editor/object_browser.gd game/tests/test_editor_v2.gd
```

The pinned Godot build is `4.7.2.stable.official.ed1daf0bf`. Final focused checks: **60 headless, 65 Compatibility, 65 desktop Mobile**, all passing. Existing editor workflow **254**, older editor suite **37**, and App **141** pass. Exact outcomes and checkpoint verification are recorded in `report.json`.

The normal `scripts/dev.ps1` entry point was attempted with CheckScript and TestScript. Its error gate stops on the sandbox's Windows certificate-store diagnostic. The evidence runner uses the same pinned engine directly, isolated workspace APPDATA, Dummy audio and `BMT_API_URL=audit-disabled`; it preserves the diagnostic, checks the engine exit code and rejects other script/runtime errors. An initial launch also encountered the ordinary-profile log permission and PowerShell execution-policy restrictions, corrected through workspace-only storage and process-only policy bypass.

Initial corrections: renamed a browser method that conflicted with Control's native `set_rotation`; used a String key for the fixture's optional scenery flag; compared dialog geometry in logical viewport coordinates; waited for deferred dialog retirement; and explicitly synchronized SpinBox's edit buffer so Apply cannot restore an older angle after slider/preset changes. The older editor test also initially ran before startup and before preparation completed. No failing production invariant was removed.

The task-only patch and source hashes exclude concurrent editor restructuring and other work. Existing owner processes were preserved. No phone attachment check, physical-device test, APK, live service/account mutation or deployment was performed. Owner interaction/appearance and physical touch/keyboard acceptance remain; reload the client to use the new controls.
