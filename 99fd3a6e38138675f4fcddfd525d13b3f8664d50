# Superwash animation — 2026-11-02

SWA01: Pressing Super Wash now starts a 3.6-second rollover machine over the actual selected car: two counter-rotating side brushes, an overhead roller and falling rinse spray. The rig deploys beyond the nose, traverses the entire model and retracts past the tail. It fits the visible model bounds, including equipped parts, and follows the existing rotating pedestal. The established instantaneous, local-only complete cleaning and save remain; interruption cannot lose a completed wash.

SWA02: Manual washing, navigation, hiding, car replacement and kit replacement clear/dispose feedback. Repeated uses reuse the rig for the same model. The three brush MultiMeshes, merged steel/hardware and fixed 96-droplet MultiMesh total six geometry submissions per existing view, with no shadow casting, extra world, viewport, physics, backend, image asset or dependency. Animation advances through the existing showroom process only while visible; completion returns to retained idle drawing. Paint and fitted parts remain untouched.

Runtime changes: `game/ui/garage_super_wash.gd` implements the presentation; `game/ui/car_showroom.gd` owns animation and cleanup; one added line in `game/ui/garage_page.gd` starts it after the existing clean reset. Regression: `game/tests/test_super_wash_animation.gd`. Supporting runner, encoder, scoped patch and source snapshots are under `docs/evidence/super-wash-animation-2026-11-02/`.

Actual validation with pinned Godot 4.7.2:

| Check | Result |
| --- | --- |
| Final native Compatibility animation | 89 checks, 0 failures |
| Final native desktop Mobile/Vulkan animation | 89 checks, 0 failures |
| Existing native Compatibility Super Wash regression | 257 checks, 0 failures |
| Existing headless hose regression | 81 checks, 0 failures |
| Initial headless animation | 74 checks, 0 failures; sandbox certificate-store error retained |
| Native motion capture | 55 frame saves, 0 failures; 15 Hz manually stepped production animation |

Both final renderers have start/middle/rinse captures for Compact, Kart, Forklift, Electric and Hovercraft. [Animated native preview](evidence/super-wash-animation-2026-11-02/super-wash-animation.png), [Compact](evidence/super-wash-animation-2026-11-02/gl_compatibility/compact-middle.png), [Forklift](evidence/super-wash-animation-2026-11-02/gl_compatibility/forklift-middle.png), [Mobile Hovercraft](evidence/super-wash-animation-2026-11-02/mobile/hovercraft-middle.png). Motion preview is a lossless APNG of actual native renders, not an FPS measurement.

Commands from repository root:

```powershell
python docs/evidence/super-wash-animation-2026-11-02/run.py
python docs/evidence/super-wash-animation-2026-11-02/run.py --direct
python docs/evidence/super-wash-animation-2026-11-02/run.py --direct --mode gl_compatibility
python docs/evidence/super-wash-animation-2026-11-02/run.py --direct --mode mobile
python docs/evidence/super-wash-animation-2026-11-02/run.py --direct --mode gl_compatibility --test test_super_wash
python docs/evidence/super-wash-animation-2026-11-02/run.py --direct --test test_garage_hose
python docs/evidence/super-wash-animation-2026-11-02/run.py --direct --mode gl_compatibility --motion
python docs/evidence/super-wash-animation-2026-11-02/encode_motion.py
python docs/evidence/super-wash-animation-2026-11-02/checkpoint.py
git diff --check -- game/ui/car_showroom.gd game/ui/garage_page.gd
```

The initial `scripts/dev.ps1` attempt failed during restricted Windows startup with certificate/access-denied errors. A direct pinned-engine fallback provides an explicit workspace log; its headless run passes assertions but retains the certificate-store error. Approved native runs outside that restriction pass cleanly, using a private APPDATA/LOCALAPPDATA profile and disabled backend URL. All automated launches use `scripts/run_no_crash_dialog.py`. Initial native geometry passes are retained in `initial-native.log` and `initial-rig.gd.txt`; visual inspection corrected fiber alignment/density before the final two-renderer checks. The dev entry point regenerated build metadata; it is excluded from this task's checkpoint. Pre-existing Garage/record/layout/model and other concurrent edits remain preserved.

Owner appearance and physical-phone performance/touch acceptance remain. Reload/rebuild to see the animation. No device attachment query/test, APK, owner-save or owner-process change, live/backend mutation, deployment or main-index write was performed.
