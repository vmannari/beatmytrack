# Gameplay antialiasing — 2026-09-16

Requirements V02/V04/V05, Q01, R01. Owner requested gameplay antialiasing and deferred graphics options.

Changed `game/project.godot`: `rendering/anti_aliasing/quality/msaa_3d=1` enables 2x MSAA on the main gameplay viewport with the existing Compatibility renderer. Existing editor viewport overrides remain explicit. Added future graphics controls to `docs/WISHLIST.md`; updated development status and phase plan.

Actual commands with pinned Godot 4.7.2:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp`: 86 checks, five failures concerning integrated saved PB targets, gaps and display. Repeated with MSAA temporarily disabled: identical five failures. Restored 2x afterward. These failures reproduce independently of this setting; no assertions were changed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Snapshot -Track FREEWAY`: exit 0, PLAYGROUND_READY and CAPTURE_SAVED on desktop OpenGL / RTX 3090. This uppercase track argument falls back to the handling yard; the capture is evidence of gameplay rendering, not FREEWAY circuit coverage.

Inspected [gameplay capture](evidence/antialiasing/gameplay-2x.png). [Capture log](evidence/antialiasing/capture.log) and [AA-disabled app comparison](evidence/antialiasing/app-tests-aa-off.log) retained. Capture startup FPS is not a benchmark. No phone/device test performed; sustained mobile frame pacing, battery/thermal impact and owner visual acceptance remain pending. No Android export performed.
