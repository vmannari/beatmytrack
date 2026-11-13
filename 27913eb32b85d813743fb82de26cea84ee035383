# Settings licences page — 2026-10-25

The owner requests implementation of the licence information discussed in chat.
Settings now has a permanent **Licences** category, available without sign-in and
in release builds. A fixed selector opens an offline, selectable document with
clickable source/licence URLs. Finger dragging scrolls the document; dragging
does not activate a link. Apply, Reset and preference status are hidden here.
Saved preferences and pending drafts are preserved when visiting the page.

## Requirements and files

- LCP01: `game/ui/settings_page.gd` integrates the permanent category and a lazy,
  retained reader in `game/ui/licences_panel.gd`.
- LCP02: `game/legal/third_party_notices.gd` obtains the exact engine MIT text,
  component copyrights/file mappings and full third-party licence texts from
  `Engine.get_license_text()`, `get_copyright_info()` and `get_license_info()`.
- LCP03: existing Barlow, Libre Baskerville, Noto JP/KR and Google Sans OFL texts,
  flag-icons MIT, Unicode, godot-cpp, particle shader and Windows runtime notices
  are displayed verbatim. Platform-specific entries follow the running platform.
- LCP04: `game/legal/audio_notices.txt` credits the tyre source and loop editor,
  links CC BY 3.0 and describes the edits. It also credits recorded vehicle,
  weather/nature and supporting music sources with their source terms. Legal
  bodies are not machine-translated or changed with the selected game language.
- LCP05: AndroidX 1.5.0, Google Identity 1.1.1 and Mobile Ads 25.5.0 notices are
  copied byte-for-byte from the existing local dependency archives. Mobile Ads
  appears only for Android debug, matching the current SDK inclusion. Exact
  archive/member/output hashes: `evidence/licences-page-2026-10-25/android-notice-sources.json`.
- LCP06: fifteen directly authored rows in `scripts/translations/licences.tsv`
  supply English and all eleven requested languages. `scripts/localization.py`
  inventories registry headings without treating legal bodies as UI copy.
  The PO catalogues are updated for these entries, and `messages.pot` is refreshed.

`game/export_presets.cfg` retains existing includes/exclusions and explicitly
includes the legal text directory, Barlow OFL and particle shader notice.
Windows notices remain subject to the Android preset's existing Windows exclusion.

## Verification

Commands use the pinned Godot via `scripts/dev.ps1`, with process-local
`APPDATA=build/licences-test-profile` and a temporary test records/library path.
Native checks required approved access to the Windows certificate store.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://ui/settings_page.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_licences_page.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_licences_page.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_licences_page.gd -Graphical -RenderingMethod mobile
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestWindowsAudioExport -CommandTimeoutSeconds 360
python -m unittest discover -s scripts -p test_translation_authoring.py
python -m unittest discover -s scripts -p test_localization.py
python scripts/localization.py check
```

Focused results: **520 headless, 532 Compatibility and 532 desktop Mobile checks,
zero failures**. These cover release/guest navigation, actual touch activation,
finger scrolling, preserved settings/drafts, complete engine notices, native
1280×720/960×540/1600×720 layouts, all eleven translated headings/selectors,
verbatim legal bodies and the complete long Android SDK notice. The actual App
opens the page through Settings. App **141/141**, parser **1197/1197** and Python
translation-authoring **7/7** pass; all **180** feature translation values pass.

The broader localization completeness gate remains failing. Existing unfinished
editor copy and concurrent daily-track/store changes are recorded separately in
`localization-check.json`; none of this feature's messages fail. The general
localization unit suite retains one catalogue-completeness failure while the
other eleven tests pass. Source inventory refreshes do not fill unrelated copy
or weaken completeness assertions.

The first graphical test exposed missing RichTextLabel finger scrolling (three
failures); the final implementation adds drag handling and suppresses link
activation after a drag. Initial headless activation/Label translation fixture
mistakes were corrected while graphical touch checks and exact-text assertions
were retained. Initial PowerShell policy, sandbox logfile/certificate failures
and the first whole-content ZIP's 180-second timeout at 98% are retained in the
evidence. The second ZIP uses a 360-second bound. Export inspection is recorded
in `export-inspection.json`: **16 byte-identical notice files**, all three
licence/settings scripts, **5294 archive entries**, with Windows modules excluded
as intended. The second export completed successfully; this is a content ZIP,
not an APK.

## Source review and limits

Public Pixabay listings now identify the crash as **u_mgq59j5ayf**, asset 394903,
and both grass sources as **DRAGON-STUDIO**, assets 511299/511301, under Pixabay
Content License. Names/IDs match the supplied filenames already in the bank.
`audio-source-review.json` records the public pages and original local records.
No replacement recording was downloaded and no new byte comparison to a public
download was performed. Historical source manifests remain unchanged.

- [Godot compliance guidance](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html)
- [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/)
- [OFL requirements](https://openfontlicense.org/open-font-license-official-text/)
- [Crash listing](https://pixabay.com/sound-effects/film-special-effects-sound-effect-car-crash-394903/)
- [Grass 05 listing](https://pixabay.com/sound-effects/nature-grass-rustling-05-511299/)
- [Grass 04 listing](https://pixabay.com/sound-effects/nature-grass-rustling-04-511301/)

This implements the notices page rather than asserting a complete independent
rights audit. Dependency upgrades need refreshed SDK notices. General source,
store/legal and device acceptance remain separate. No device attachment check
or device test was performed; no APK, purchase, authentication, deployment,
live backend mutation or owner-process restart. Concurrent work is preserved.

Native screenshots, initial task snapshots, source hashes, commands/logs and
the task-only review patch are under `docs/evidence/licences-page-2026-10-25/`.
