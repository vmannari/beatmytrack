# Rivalry share confirmation — 2026-10-19

RSF01 fixes the completed Weekly Rivalry Share results confirmation shown in the owner's screenshot. The old shared popup reserves a fixed 60-unit heading and an unscrolled message area: the wrapped “Championship results copied” heading overlaps the results, which continue behind OK. The real Share action reproduces this with both an unranked week and a Perfect Week at 1848×937, 1280×720, 960×540 and 1600×720: 101 checks, 24 failures on the saved original implementation.

The fallback now uses the existing owned `FaultDialog` presentation with a concise “Results copied” success heading and check icon. Its scrolling content contains the exact copied summary, including all five tracks. The 1040×600 preferred size is bounded by the parent viewport with 48 units of total clearance. Ordinary results fit immediately; wrapped long names and the final Perfect Week line remain reachable above the separately positioned OK button. X and OK retain the existing destruction, scrim cleanup and focus restoration.

RSF02 preserves the exact `finale_share_text()` payload, native Share handoff, busy/cached/completed/account-and-car guards, scores and local settings. The confirmation prefix is presentation-only and is never added to the clipboard or native payload. Native Share is exercised through a recording adapter, without opening another app or sending anything.

Changed files: `game/core/app.gd`, `game/ui/fault_dialog.gd`, the focused `game/tests/test_rivalry_share.gd`, this note and `DEVELOPMENT_STATUS.md`. The saved original/final production sources, logs and rendered evidence are under [evidence/rivalry-share-2026-10-19](evidence/rivalry-share-2026-10-19). The source-only review checkpoint is [task-only.patch](evidence/rivalry-share-2026-10-19/task-only.patch); [source-hashes.json](evidence/rivalry-share-2026-10-19/source-hashes.json) records file identities. No existing unrelated work is included in that patch.

R01 uses the pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`. Runs use isolated `APPDATA` directories created under `build/rivalry-share-*`; fixtures disable `BMT_API_URL` and use unique local save folders. Commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- Original reproduction: `-Action TestScript -ScriptPath res://tests/test_rivalry_share.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence=res://../docs/evidence/rivalry-share-2026-10-19/before-ui` — 101 checks, 24 failures; [log](evidence/rivalry-share-2026-10-19/logs/before-compatibility-final.log).
- Final Compatibility: the same command with `--evidence=res://../docs/evidence/rivalry-share-2026-10-19/gl_compatibility` — 125 checks, zero failures; [log](evidence/rivalry-share-2026-10-19/logs/final-compatibility.log).
- Final desktop Mobile: add `-RenderingMethod mobile -RenderingDriver vulkan` instead of Compatibility and use evidence directory `mobile` — 125 checks, zero failures; [log](evidence/rivalry-share-2026-10-19/logs/final-mobile.log).
- Final headless: `-Action TestScript -ScriptPath res://tests/test_rivalry_share.gd` — 101 checks, zero failures; [log](evidence/rivalry-share-2026-10-19/logs/final-test_rivalry_share.log).
- Existing notices: `-Action TestScript -ScriptPath res://tests/test_fault_dialog.gd` — 95 checks, zero failures; [log](evidence/rivalry-share-2026-10-19/logs/test_fault_dialog.log).
- Existing Rivalry: `-Action TestScript -ScriptPath res://tests/test_weekly_rivalry.gd` — 1115 checks, zero failures; [log](evidence/rivalry-share-2026-10-19/logs/final-test_weekly_rivalry.log).
- Parser: `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` — 898 scripts, zero failures; [log](evidence/rivalry-share-2026-10-19/logs/final-test_script_parse.log).
- Rendered shared popups: `-Action TestScript -ScriptPath res://tests/test_popup_style.gd -Graphical -RenderingMethod gl_compatibility -TestArgument --evidence=res://../docs/evidence/rivalry-share-2026-10-19/popup-regression` — 157 checks, zero failures; [log](evidence/rivalry-share-2026-10-19/logs/popup-rendered.log).
- `git diff --check -- game/core/app.gd game/ui/fault_dialog.gd game/tests/test_rivalry_share.gd docs/RIVALRY_SHARE_2026_10_19.md` — passes (existing CRLF normalization warning only).

The initial restricted graphical launch could not read the Windows root certificate store. Subsequent runs used normal host access with isolated local data. The first unrestricted attempt exposed a test-only evidence-path mistake; globalizing the `res://` argument corrected directory creation before the actual original/final runs. The existing headless shared-popup suite was inconsistent: its initial final-source run reported one “opened filter drawer fits the viewport” failure (157 checks); the sequential saved-original run passed all 157; the sequential final-source run reported the filter and search drawer bounds assertions (157 checks, two failures). These runs are retained in [test_popup_style.log](evidence/rivalry-share-2026-10-19/logs/test_popup_style.log), [popup-original.log](evidence/rivalry-share-2026-10-19/logs/popup-original.log) and [final-test_popup_style.log](evidence/rivalry-share-2026-10-19/logs/final-test_popup_style.log). This suite's headless result is not claimed passing. The share function is not called by that suite, and the new presentation branch only matches the new Rivalry confirmation prefix. No runtime checks or assertions were weakened.

G01 rendered views, inspected in the actual Godot viewport:

- [Original overlapping confirmation](evidence/rivalry-share-2026-10-19/before-ui/share-unranked-1848x937.png).
- [Fixed ordinary results, Compatibility](evidence/rivalry-share-2026-10-19/gl_compatibility/share-unranked-top-1848x937.png).
- [Long names at 960×540, Compatibility](evidence/rivalry-share-2026-10-19/gl_compatibility/share-perfect-top-960x540.png).
- [Last line reached at 960×540, desktop Mobile](evidence/rivalry-share-2026-10-19/mobile/share-perfect-960x540.png).

Q01: owner appearance acceptance remains. Window sizes and the Mobile renderer are desktop checks. No phone attachment check or physical-device test, APK/export/install, live account/backend mutation, external message or deployment was performed.
