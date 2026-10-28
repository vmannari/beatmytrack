> **Corrected on 26 October 2026:** the layout-only roads described in this earlier record failed editor validation. All five tracks and Ville's saved copies have now been rebuilt with normal connected road parts and placed start lines. See [the correction and actual editor/Test drive results](STORM_ROAD_PARTS_2026_10_26.md). The record below is historical.

# Ville's five Storm drafts — 26 October 2026

SD01 adds the five existing Storm circuits as saved, unpublished drafts for Ville. SD02 preserves existing files and the exact authored tracks.

Added **Thunder Freight**, **Blackout Switchyard**, **Rainbreak Ridge**, **Slatewater Quarry** and **Eye of the Storm** to Ville's account-scoped draft library on this PC. Open **Create → Load track**, then search **storm**; there are two pages of results. Reopen Load track if it was already open.

Drafts are device-local. The backend's draft routes are retired and do not provide account-wide draft synchronization. This operation does not add tracks to online Free Race or to another device.

Ville's profile was identified from the existing public track cache's exact creator name and creator ID, the application's origin/player profile hash, existing publication bindings and the existing Ville-authored drafts. No authentication token, session rotation, backend API request or account update was needed.

The game's native `TrackLibrary.save_document` prepared the copies in an isolated workspace library, assigning creator **Ville**. All other document fields remain exactly equal to the original Storm sources. Native compilation confirmed unchanged route, collision cells and deck cells for every track: **36 checks, zero failures**.

The prepared files were then exclusively created in Ville's existing library: five JSON documents and five creation-date sidecars. No existing file was replaced. All **245 pre-existing library files** remained byte-identical. The library now contains **10 editable drafts**, including these five. A separate native process read the actual destination through `TrackLibrary` and the real Load track browser: **26 checks, zero failures**, with no publication bindings. Both draft pages were captured.

Relevant commands, run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/prepare_storm_ville_drafts.gd
python build/storm-ville-drafts-2026-10-26/install.py
python build/storm-ville-drafts-2026-10-26/install.py --apply
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/prepare_storm_ville_drafts.gd -TestArgument '--verify-live' -Graphical -RenderingMethod gl_compatibility
```

Native test processes used an isolated `APPDATA` directory under `build/storm-ville-drafts-2026-10-26/test-user`. The installer used the actual PC profile after the explicit request to add drafts for Ville. Its private identity mapping, file plan, pre-existing file hashes and receipt remain under that ignored build directory. The sandbox escalation allowed only the authorized local file creation; no additional user confirmation was needed.

The current shared draft gallery does not draw a route outline for layout-based roads and counts only separate road pieces. Its cards consequently show **0 road pieces** for these tracks. Their original roads remain in the saved layouts, and exact native compilation verifies they are present. This operation preserves the tracks rather than changing their road representation or the gallery UI.

Evidence: [receipt](evidence/storm-ville-drafts-2026-10-26/report.json), [first draft page](evidence/storm-ville-drafts-2026-10-26/ville-load-track.png), [second draft page](evidence/storm-ville-drafts-2026-10-26/ville-load-track-2.png). The preparation/verification helper and documentation have a task-only review patch; the actual private draft files are intentionally not included in it.

No physical-device attachment check/test, APK, publishing-slot use, purchase, publication, deployment, live backend mutation or owner-process restart was performed. Owner/editor appearance acceptance remains. Concurrent workspace changes are preserved.
