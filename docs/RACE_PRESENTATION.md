# Race presentation revision ? 2026-09-12

The owner rejected the generic menu and asked for stronger presentation and reasons to keep playing. This revision covers V03/G03 (menu hierarchy and presentation), R01 (five-lap races), R04/R06 (timing and local records), and R07 (track discovery). It preserves the authorized local slice.

## Player experience

The home screen is a race invitation: selected circuit, five-lap standing-start format, actual personal target and one dominant Start Race button. A new player gets a first-run objective and controls; a returning player resumes the last raced circuit and sees their saved five-lap PB. Missing saved circuits fall back to the built-in default. Last-track persistence is an optional allowlisted `last_track` settings string within existing local-record schema 2.

The retention proposal is mastery, variety and authorship. Finishing establishes a benchmark. Subsequent results show the exact improvement or gap, distinguish the standing lap from flying laps, and make retry immediate. Explore Circuits, Your Favorites and Create & Share describe actual available features. Search by name/creator, favorites, filters and random selection remain available in the paged library; hosted community discovery and progression remain deferred.

The visual hierarchy uses a full-width original pit scene, restrained flat surfaces, condensed display typography, a recognizable circuit silhouette and consistent navigation. Garage uses the same scene and real handling-resource values. The static menu viewport renders once, then refreshes on resize. Gameplay camera and physics are unchanged.

Reference reasoning: the owner-supplied menu board establishes car-led composition; [Turn 10's Challenge Hub explanation](https://forza.net/news/forza-motorsport-update-12) supports clear objectives and varied activities as navigation anchors. No reference image or commercial game artwork is included. Timed reward mechanisms were not adopted.

## Changed files

- `game/core/app.gd`: race invitation, last-track restoration, garage hierarchy and results composition.
- `game/ui/menu_style.gd`, `menu_backdrop.gd`, `menu_stage.gd`, `menu_scrim.gd`, `menu_feature.gd`, `circuit_emblem.gd`: shared typography, navigation, original pit geometry and surface silhouette.
- `game/ui/track_browser.gd`, `track_tile.gd`: consistent library treatment and selected-track PB.
- `game/ui/race_debrief.gd`, `race_results.gd`: integer-millisecond feedback and five-lap debrief.
- `game/persistence/local_records.gd`: validated optional last-track setting.
- `game/assets/fonts/`: Barlow fonts and SIL OFL license; provenance in `licenses/ASSETS.md`.
- `game/tests/test_menu_presentation.gd`, `test_app.gd`, `scripts/dev.ps1`: comparison/persistence checks and graphical evidence.

## Actual validation

Exact pinned Godot 4.7.2 via the project wrapper:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate`: final rerun passed import, 57 script parses and 583 checks across driving (56), tracks (163), extra tracks (27), creator (86), editor v2 (39), free editor (45), app (85), records (53), catalog (18) and menu presentation (11).
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestMenus`: 11 checks, zero failures, including millisecond ties/carry, failed-save/practice feedback, resume persistence and invalid-path rejection.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureApp`: 106 checks, zero failures. Actual creator AI test drive completed five laps with zero contacts. Result-screen captures use controlled completed-session fixtures (109.000 s, then 108.816 s), not claimed human or AI race records. A slower repeat preserves the faster PB; a fresh app instance restores the last circuit and target.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Snapshot -Screen garage`: exit 0; inspected Windows capture.
- `git diff --check`: source edits passed. Final checkpoint whitespace review retains one upstream trailing space in the byte-preserved OFL license; generated evidence logs were normalized to LF.

Reviewed captures: [returning player](evidence/race-returning.png), [first visit](evidence/race-invitation.png), [debrief](evidence/race-debrief.png), [garage](evidence/race-garage.png), [circuits](evidence/race-circuits.png). [Graphical test log](evidence/race-presentation-capture.txt), [validation log](evidence/race-presentation-validation.txt).

## Remaining acceptance

The car is still the original procedural handling stand-in; this is a presentation revision, not a finished AAA vehicle/environment asset pass. Owner visual acceptance, human driving flow, physical-phone readability/touch/performance and camera calibration remain open. No phone attachment check, device test or Android export was performed in this task. Local times remain unverified. Imported Slicks-derived content retains its existing internal-test provenance. Engagement impact has not been measured with players.
