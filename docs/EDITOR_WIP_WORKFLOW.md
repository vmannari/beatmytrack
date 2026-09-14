# Editor layout and separate WIP autosave

2026-09-14 owner follow-up; requirements R01/T01-T04/V02/V04/V05.

The top left shows the track name and a pencil that enables native text editing. Enter or leaving the field autosaves the WIP. X closes at top right. Undo/redo remain beside the title. The green Test action has an original vector play triangle. The vertically centred rail contains Track, Surfaces, Objects, Waypoints and Biome. Biome chooses the existing pine/coast/desert themes; future asset availability remains driven by the catalogue hook.

The overflow menu contains only New, Load, Save, Share and Help. The editor's separate 3D preview dialog and entry point are removed. The track library's existing track-detail rendering is retained. Object search is removed from the editor. Previous and next slots are always reserved and disabled at their limits; page size follows available width. Mesh bounds, including instanced tyres, frame each thumbnail with padding. Surfaces use coloured material glyphs with road markings, grass blades, dirt grains or liquid ripples.

## Persistence contract

Automatic edits, naming, test-drive entry and closing write through the existing validated atomic save mechanism to `user://tracks/wip/<id>.json` (and its recovery files). They do not write `user://tracks/<id>.json`. Load lists saved originals and separately labelled WIP entries; selecting either opens that exact version. Explicit Save, including Ctrl+S, writes the saved original. WIP copies remain separately recoverable. WIP files use the unchanged creator document schema and are not included in the ordinary racing library until explicitly saved. Existing saved files are not migrated or deleted.

## Changed files and actual verification

- `game/core/app.gd`: header, rail, menu, naming, biome selection, save/load routing, removal of editor preview dialog.
- `game/editor/editor_button.gd`: play, pencil, close, biome, waypoint and surface glyphs.
- `game/editor/object_browser.gd`, `object_thumbnail.gd`: fixed paging, no search, measured mesh framing and card padding.
- `game/persistence/track_library.gd`: isolated WIP storage using existing atomic write/recovery.
- App, editor workflow, object-browser and tyre/load tests updated for the explicitly changed UI and persistence requirements.

Actual commands used the pinned engine through `scripts/dev.ps1`: CaptureObjects (62 checks), TestApp (84), TestWorkflow (94), TestTyresLoad (26), TestDeleteTracks (19); final runs all passed. `git diff --check` passed. App tests preserve the existing gesture and save assertions against WIP storage. New checks verify that editor autosave leaves original content intact, WIP survives a fresh library instance, WIP geometry reloads and explicit Save updates the original. Capture review caught and fixed a duplicate Test label. Initial thumbnail bounds code accessed nodes before tree insertion and omitted instanced meshes; local transform accumulation and MultiMesh bounds corrected both. The load test initially expected old autosave behavior and was updated; its explicit-Save notice is dismissed before opening another modal.

Reviewed engine captures: [objects](evidence/editor-wip-objects.png), [overflow menu](evidence/editor-wip-menu.png), [surfaces](evidence/editor-wip-surfaces.png), [wide landscape](evidence/editor-wip-wide.png).

No physical phone test or Android export was performed. Touch-keyboard behavior, safe-area placement on a real phone and final visual acceptance remain manual checks. No canonical physics change or full physics regression in this slice. Overall art still remains below the supplied AAA reference.


## Centred dialogs and transparent header follow-up

2026-09-14 R01/T01-T04/V02/V04/V05: Biome now opens a large centred selection dialog. Rail buttons increase from 60 to 76 logical pixels high. Object cards centre in their available row; previous/next controls hide at their respective page limits, superseding the earlier always-visible rule. The header name is a transparent label with overflow clipping. X and pencil retain full hit areas with transparent style boxes. Disabled Test uses grey background, border, text and play glyph.

The pencil opens a styled centred rename modal with a native LineEdit, 40-character limit, whitespace validation, Apply/Cancel and Enter submission. Apply changes the label/document and autosaves only WIP. Cancel leaves the name unchanged. On platforms supporting virtual keyboards, it requests native input, uses the field's screen rectangle and repositions above reported keyboard height. Desktop does not call unsupported keyboard APIs. A simulated 320px keyboard clearance check and desktop focus/submit check pass; actual Android IME, keyboard resizing and safe areas remain device acceptance work.

Changed app.gd, editor_style.gd, editor_button.gd, object_browser.gd and app/browser tests. Actual final commands: scripts/dev.ps1 -Action TestApp (84 checks, zero failures), CaptureObjects (67 checks, zero failures). An initial paging assertion used the Nature fixture instead of a one-page category; corrected to Barriers. Unsupported desktop keyboard warnings were eliminated with feature checks. No canonical simulation changes or Android export. No physical phone test was performed.

Reviewed captures: [centred objects](evidence/editor-centred-objects.png), [biomes](evidence/editor-biomes-dialog.png), [rename](evidence/editor-rename-dialog.png), [disabled Test](evidence/editor-test-disabled.png).
