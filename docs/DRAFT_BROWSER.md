# Local draft browser — 2026-09-23

## Delete icon refinement

V03/V05: `game/ui/menu_icon.gd` now draws a symmetric bin with a raised handle, separate lid, tapered rounded body and two inset ribs, rasterized at 4× resolution with mipmaps. `game/ui/draft_browser.gd` explicitly centers the 28-pixel glyph horizontally and vertically within the 64×64 Delete action. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureTyresLoad`: 68 checks passed; refreshed [gallery evidence](evidence/draft-browser/gallery.png) visually inspected. No phone test/export; owner visual acceptance remains.

## Selected draft actions and local publication follow-up

Owner follow-up (R01/T01–T04/V03/V05/Q01) supersedes the per-card actions and publication limitation below. Cards now select a draft; a shared bottom panel shows its scenic road preview, metadata, Edit track, Test drive, Publish and a square 64×64 Delete icon. Test drive has no subtitle. Untested cards show DRAFT; tested cards show TESTED. Publish is grey/disabled with the exact text **Complete test run to publish** until completion, then becomes yellow. Selection moves safely with paging/search; empty results hide all selected-draft actions.

The owner clarified that publishing should exercise the local workflow for now: make the tested version playable, lock it against editing and remove it from this menu; online connections come later. `TrackLibrary.publish_document` requires a matching tested receipt, saves the playable version and persists a publication snapshot under `.published/`. Published identities are excluded from draft enumeration and rejected by app load/edit and library save/autosave paths. Existing drafts are not retroactively published. No network service, verified leaderboard or online publication is claimed. Local save and publication lock are sequential commits: if the second commit fails, an error is reported and the draft remains editable/retryable.

Test drive stays untimed and unranked. A separate one-lap `TrackSession` witness in the presentation/composition layer checks all ordered road gates and the finish; normal race timing and the five-lap contract are untouched. Merely launching or abandoning a drive never marks Tested. AI/demo driving is ineligible. Completing one ordered lap from the draft browser persists the tested snapshot and returns to the browser. Editor-launched practice can earn the same status while continuing freely; its result is reported upon leaving practice.

Receipts store the exact full document using the existing atomic JSON writer and recovery format in `.tested-<physics/rules/compiler hash>/`. They are outside playable indexing and do not extend creator-v5. Any saved change, including name, objects, road geometry or start line, removes the previous receipt and its recovery files. Undoing back to the old content does not restore it. Identical saves preserve it. Full-document matching also prevents unsaved altered content from passing the publication check. Publication is a local UX lock, not server-side anti-tamper verification.

Additional changed files: `game/core/game.gd` (untimed completion witness), `game/ui/menu_icon.gd` (action glyphs), `game/tests/test_editor_practice.gd`; the existing browser/library/app/tile/load-test files and documentation were updated. The track document schema, canonical simulation, normal race rules and replay format are unchanged.

Actual final validation, using `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 <action>` with pinned Godot 4.7.2:

- `CaptureTyresLoad`: 68 checks pass; inspected [draft layout](evidence/draft-browser/gallery.png) and [tested/Publish enabled](evidence/draft-browser/tested.png). An initial test fixture used a StringName key where the strict JSON contract requires String; corrected the fixture without relaxing validation. A follow-up exposed duplicate notice dialogs on rejected loads; removed the duplicate and final capture is clean.
- `TestTyresLoad`: 68 checks pass after adding the structural receipt guard. Coverage includes completed/abandoned test transitions, receipt persistence, name/object invalidation, undo non-resurrection, publication rejection before testing, local playable copy, gallery removal, editing lock and reload persistence. Completed-lap integration uses deterministic position sweeps through the actual ordered gates, not a human driving acceptance run.
- `TestPractice`: 49 checks pass, including six laps of actual autonomous practice without scored completion, AI exclusion from publication, and ordinary five-lap racing. The run reports two ObjectDB instances leaked at shutdown; this warning remains unresolved.
- `TestBiomes`: 92 checks pass.

No phone test or APK export performed; device attachment not checked. Remaining acceptance: human test-lap driving, phone layout/touch, owner visual review, shutdown warning investigation, and future online publishing integration.

Requirements R01/T01–T04/V03/V05/Q01. Owner requests Load track to reopen non-published work, show scenic cards and creation information, and support deletion.

Create > Load track and editor Map > Load now open a dedicated full-screen local draft gallery. It shares the menu navigation, workshop backdrop, biome scenery, road outlines and yellow actions. It provides name/biome search, four-card pages ordered by actual last-save time, local date/time, saved/autosaved status, road and object counts, an editing hint, Continue editing and Delete. Empty/search-empty states are explicit. Blank drafts do not display the internal fallback lap route. Road previews show authored pieces, not an invented start marker.

The previous Create action incorrectly opened the racing library, missing WIP autosaves. The replacement reads both local saved originals and the WIP directory, deduplicates by document ID and chooses the newest readable version. Equal file timestamps prefer WIP. Last saved comes from the same readable primary/backup/temp selected by the existing recovery flow; it is presentation metadata, not part of the document or simulation. Times use the device's current timezone offset.

Continue editing restores the existing identity/geometry, clears outgoing undo state and continues the same autosave flow. Editor entry saves outgoing work first and guards pending surface/invalid road previews. Back returns to the editor when entered there, otherwise biome selection. Deleting asks for confirmation, defaults focus to Cancel, and removes the saved original, autosave and recovery files for that ID only. It clears an active deleted document so it cannot be resurrected by the next autosave and removes stale favorite/selected-track references. A storage error is reported rather than claiming success; deletion of two stores is not transactional.

No publication service or publication field exists in the strict creator-v5 schema. Thus this local slice lists locally editable documents, including imported local documents, and excludes built-in racing catalog entries. A future publication contract must supply published-state filtering; no fake published/unpublished flags were introduced. Existing player files are not migrated or deleted by this implementation; deletion occurs only through the player's confirmed action. Tests use an isolated generated user directory.

Changed files: `game/ui/draft_browser.gd` (new), `game/core/app.gd`, `game/persistence/track_library.gd`, `game/ui/track_tile.gd`, `game/tests/test_tyres_and_load.gd`, this document, development/phase notes and `docs/evidence/draft-browser/gallery.png`.

Actual commands via pinned Godot 4.7.2:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureTyresLoad`: 44 checks, zero failures. Includes newest autosave selection, deduplication, real timestamp, paging/search, geometry restoration, continuing autosave, Back, cancellation/confirmation deletion, backup non-resurrection, invalid-ID rejection, loading unfinished work and invalid-preview guard. Existing tyre regressions remain in this combined suite.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestBiomes`: 92 checks, zero failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestMenus`: 22 checks, zero failures.

[1280×720 desktop evidence](evidence/draft-browser/gallery.png) inspected. Initial capture exposed footer overflow; reduced the draft thumbnail minimum height and recaptured with the full footer visible. Cards use actual road-piece outlines over shared biome artwork, not rendered track screenshots; paint and objects are represented by metadata rather than the outline preview. All metadata is loaded when opening the library; large-draft-library performance is not benchmarked. No phone test or APK export performed; device attachment was not checked. Remaining acceptance: owner visual review and physical-phone touch/layout. Existing unrelated workspace edits are retained; no combined Git commit was made.
