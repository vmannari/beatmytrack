# Garage preview and navigation recovery — 2026-11-02

GPR01–GPR03 cover the owner's blocked Garage button, indefinitely loading Rally carousel card, and preservation of the preview worker's input/idle limits.

## Cause and correction

The Garage picture cache, carousel picture cache and optional studio preloader each record active touch indices. A press can arrive in the main viewport while its release or cancellation arrives in the header dropdown's separate popup viewport. The workers never received that release. The orphaned index indefinitely blocked rendering; a missing exact picture then also held the Garage navigation gate. This reproduces both reported symptoms without an account, backend change or owner data.

`game/ui/preview_touch_input.gd` installs one tree-level relay and one input observer per popup window, including internal MenuButton/ColorPickerButton popups and windows added later. Popup releases/cancellations clear only the corresponding tracked index. The relay does not consume events, poll, relax idle limits, or clear other held fingers. Both `garage_preview_cache.gd` and `garage_preloader.gd` register with it. Existing local releases and application focus/pause handling remain authoritative.

Runtime changes are those three files. `game/tests/test_garage_preview_recovery.gd` supplies the regression; its fixture uses private records and no signed-in session. The test dispatches a press to the main viewport and release to the real header PopupMenu, changes a saved car appearance, requests Garage, switches profile/header car, and verifies every current carousel picture. A later-created PopupPanel checks two-finger isolation and cancellation.

## Actual validation

All commands ran from the repository root using the pinned Godot 4.7.2 executable, process-tree crash-dialog suppression, and isolated APPDATA/LOCALAPPDATA. The runner records the exact command, native log, result and screenshots in each named evidence directory.

```powershell
python docs/evidence/garage-preview-recovery-2026-11-02/run_checks.py control-compatibility gl_compatibility --task-start
python docs/evidence/garage-preview-recovery-2026-11-02/run_checks.py final-compatibility gl_compatibility
python docs/evidence/garage-preview-recovery-2026-11-02/run_checks.py final-mobile mobile
python docs/evidence/garage-preview-recovery-2026-11-02/checkpoint.py
```

| Run | Actual result |
| --- | --- |
| Task-start sources, Compatibility | 13 checks, 6 failures, exit 1: three orphaned-touch checks, missing-picture progress, Garage return and Rally picture. Later-popup checks are skipped because the failed return leaves Profile active. |
| Final Compatibility | 17 checks, 0 failures, exit 0. |
| Final desktop Mobile renderer | 17 checks, 0 failures, exit 0. |
| Scoped source checkpoint | Forward/reverse application and exact byte comparisons recorded in `checkpoint.json`. No main-index operation. |

The task-start and final Compatibility carousel screenshots were inspected. The task-start image shows Rally's loading card; the final image shows its exact orange saved finish. Final native logs retain the sandbox's certificate-store startup error; no crash was reported. An intermediate Mobile run completed the behavior checks but also logged a concurrent Daily Results preload whose new file was not yet available; that log is retained under `intermediate-mobile-parse`, and the final run was repeated after the file appeared. The runner now rejects script errors even if the fixture exits successfully. Before this fix, an earlier attempt to relax the picture-visibility gate did not reliably resolve the symptom and was removed. The popup-release regression establishes the cause independently of that hypothesis.

Evidence: [task-start carousel](evidence/garage-preview-recovery-2026-11-02/control-compatibility/carousel.png), [fixed carousel](evidence/garage-preview-recovery-2026-11-02/final-compatibility/carousel.png), [fixed Garage after profile selection](evidence/garage-preview-recovery-2026-11-02/final-compatibility/recovered.png), [Compatibility report](evidence/garage-preview-recovery-2026-11-02/final-compatibility/report.json), [Mobile report](evidence/garage-preview-recovery-2026-11-02/final-mobile/report.json).

## Limits and remaining acceptance

The fix needs a reload/rebuild to enter the owner's running app. Owner confirmation on the original sequence and physical-device touch acceptance remain; no phone/device test was performed. Desktop Mobile means the desktop Vulkan Mobile renderer, not an Android measurement. No owner-save mutation, owner-process restart, deployment, live backend mutation, APK, or main-index staging/commit/merge was performed. Concurrent App and soundtrack edits are preserved; the task patch is based on captured working sources rather than HEAD.
