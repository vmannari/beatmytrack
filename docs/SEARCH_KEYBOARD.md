# Search above the Android keyboard

2026-10-01. Requirements R01/V03/V04/G03/Q01.

The search drawer follows the actual virtual keyboard height, converted from physical pixels to viewport coordinates. While typing it becomes wider and more compact, keeping the input, scrollable result preview, Clear and Show tracks above the keyboard. Decorative headings are hidden; search scope choices are also hidden when vertical space is especially limited. Done dismisses the keyboard without applying the draft search. Mobile keyboard submission also dismisses it; desktop Enter still applies search.

Changed runtime file: `game/ui/track_search_drawer.gd`. The graphical harness `game/tests/capture_premium_menus.gd` covers two keyboard heights and waits for the hero slide to finish before capturing fixed-layout baselines. Rectangle comparisons use floating-point approximate equality.

Actual commands run through the pinned engine entry point:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CheckScript -ScriptPath res://ui/track_search_drawer.gd`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureMenus`: final run passed **1630 checks**, zero failures, at 1280x720, 960x540 and 1600x720. Earlier runs exposed three intermittent section-baseline failures; waiting for the slide to finish resolved them.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 DeployAndroid -QuickValidation -DeviceSerial PRQKU4U4PREQNRWG`: passed quick validation, exported, installed successfully and launched with Status ok. Existing build-tools fallback and driving-test ObjectDB warnings remain; full physics regression was not run for this UI change.

Physical phone verification: opened Search with the real landscape keyboard, typed `blind`, and visually confirmed Blind Spot as the live result with the input and Show 1 track accessible above the keyboard. Screenshots: [empty query](evidence/search-keyboard-2026-10-01/phone-keyboard.png), [live match](evidence/search-keyboard-2026-10-01/phone-query.png). Desktop simulated keyboard captures: [1280x720](evidence/search-keyboard-2026-10-01/desktop-keyboard-1280x720.png), [960x540](evidence/search-keyboard-2026-10-01/desktop-keyboard-960x540.png).

Remaining acceptance: another session restarted the phone app into a driving test during the dismissal check, so Done dismissal was not confirmed on the physical device. Other keyboard apps, floating keyboards and other phone sizes remain untested. No player records were edited for this check.
