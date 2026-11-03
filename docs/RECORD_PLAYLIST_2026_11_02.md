# Selectable record playlist

RPL01 adds a saved Playlist checkbox beside every Garage record. All fourteen records start included for existing saves. Membership changes save immediately without changing the current track, pause state or volume. A record outside the playlist remains available for direct play. Keep at least one record selected; its checkbox is disabled with a translated explanation when it is the only remaining entry.

RPL02 makes automatic end-of-record advancement and Previous/Next follow the selected records in catalogue order, including wraparound and navigation from a directly played excluded record. A single selected record repeats. Automatic advancement reads the bound LocalRecords object's current settings, including after another atomic save replaces its dictionary. Racing remains silent and cannot advance the menu playlist.

RPL03 adds the optional `settings.music_playlist` array to the existing schema-2 preferences. Its entries must be distinct known record IDs, with one to fourteen entries. Missing preferences retain the original all-record behavior. LocalRecords validates saves and reloads through its existing atomic path; failed saves restore both saved membership and checkbox state and use the existing Garage storage notice. There is no backend contract change.

Changed runtime files:

- `game/ui/garage_records_menu.gd`: independent 52-unit checkbox targets, translated heading/accessibility/last-entry explanation, immediate save and selected-record transport.
- `game/soundtrack/record_library.gd`: bounded playlist validation, default membership and shared directional selection.
- `game/soundtrack/audio_world.gd`: filtered automatic advancement using current bound preferences.
- `game/persistence/local_records.gd`: validation of the additive preference.

Supporting files: `game/tests/test_record_playlist.gd`, three authored rows in `scripts/translations/record_playlist.tsv`, the source catalogue and twelve locale catalogues, this document, the AGENTS entry, and task-owned evidence/runner/checkpoint scripts. Catalogue changes append only the three task messages and retain concurrent translations.

Actual commands, run from the repository root:

```powershell
python docs/evidence/record-playlist-2026-11-02/run_native.py
python docs/evidence/record-playlist-2026-11-02/run_native.py --graphical
python docs/evidence/record-playlist-2026-11-02/run_native.py --graphical --mobile
python docs/evidence/record-playlist-2026-11-02/run_native.py test_supplied_soundtrack
python docs/evidence/record-playlist-2026-11-02/run_native.py test_record_player_redesign --graphical
python docs/evidence/record-playlist-2026-11-02/run_native.py test_records
python docs/evidence/record-playlist-2026-11-02/check_catalogues.py
git diff --check -- game/soundtrack/record_library.gd game/soundtrack/audio_world.gd game/ui/garage_records_menu.gd game/persistence/local_records.gd
python docs/evidence/record-playlist-2026-11-02/checkpoint.py
```

Final results: playlist **57 checks / 0 failures headless**, **61 / 0 native Compatibility**, **61 / 0 native desktop Mobile**. Retained supplied soundtrack **41 / 0**, native record-player interaction/layout **39 / 0**, local records **54 / 0**. Combined **313 checks / 0 failures**. Scoped catalogue checks verify all **36 translations**, three source messages and matching placeholders. No whole-project localization-clean claim is made. Git whitespace checks pass with existing line-ending notices.

The focused fixture uses the actual App/Garage, isolated storage and an empty service origin. It covers mouse/touch membership changes independent of direct play, disk reload, both transport directions, automatic advancement after another save, actual native end-of-track signals, paused editing, a one-record playlist, race guards, rejected empty/duplicate/unknown/malformed values, visible failed-save recovery and subsequent successful edits. Six native captures cover 960x540, 1280x720 and 1600x900 across both renderers:

- [Compatibility 960x540](evidence/record-playlist-2026-11-02/gl_compatibility/playlist-960x540.png)
- [Compatibility 1280x720](evidence/record-playlist-2026-11-02/gl_compatibility/playlist-1280x720.png)
- [Desktop Mobile 1280x720](evidence/record-playlist-2026-11-02/mobile/playlist-1280x720.png)

Initial fixture findings are retained: the first run assumed a `music_record` key existed even when default selection had never needed saving. It raised a script error and stalled, then its exact owned headless process was identified and stopped. The corrected fixture explicitly commits its starting selection. Initial successful native captures showed the intentionally triggered storage-error dialog; the fixture now dismisses that notice before capturing the record controls. Neither correction changes production behavior or weakens an assertion. The sandbox denied process enumeration; a scoped elevated command identified only the exact fixture command line. PowerShell `Stop-Process` failed, then the verified process's `.Kill()` succeeded. The task runner now bounds its own launched process tree on timeout. The existing Windows root-certificate-store warning occurs in successful offline runs and is retained in logs. Native tests use the Dummy audio driver; delivered speaker sound was not assessed.

The review checkpoint uses task-start runtime/catalogue files and a fresh baseline immediately before adding the shared AGENTS entry. New files are additions. It preserves concurrent workspace edits, and its patch passes forward/reverse application and normalized-text equality checks inside an owned temporary repository. The main Git index is untouched; no commit or merge is made there.

Reload and owner appearance/touch acceptance remain. No physical-device query/test, APK, real authentication, purchase, owner-save/process change, live/backend mutation or deployment was performed.
