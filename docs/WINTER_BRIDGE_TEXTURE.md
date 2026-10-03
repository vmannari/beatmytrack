# Winter bridge road texture ? 2026-10-02

Requirements: V02/V04/Q01; owner request to texture the flat winter bridge road.

Creator and legacy bridge materials enabled icy_road but left ice_albedo unbound. Both now bind the existing original winter_ice_v1.png artwork, using the existing world-space sampling and subdued winter tint. No new assets, geometry, handling or collision changes.

Changed files: game/track/creator_bridge_visual.gd, game/track/bridge_presentation.gd, game/tests/capture_winter_bridge.gd, scripts/dev.ps1, DEVELOPMENT_STATUS.md, docs/PHASE_0_PLAN.md and this note. Evidence: docs/evidence/winter-bridges/gameplay.png and overview.png.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureWinterBridge`.
Outcome: exit 0 using pinned Godot 4.7.2, Compatibility renderer; two screenshots saved and collision-cell preservation assertion passed. Gameplay screenshot inspected: visible mottled ice detail across the deck. The capture fixture is adapted from the existing desert bridge fixture.

Remaining acceptance: owner visual review and physical Android appearance/performance. No Android export or device test performed. Legacy bridge binding changed but not separately captured. Existing unrelated workspace edits retained.

## Orientation correction

The first fix exposed world-axis mapping, which ran ice streaks across a bridge. CreatorBridgeVisual now emits along/across UVs in metres for each span; BridgePresentation supplies equivalent coordinates along the legacy bridge axis. bridge_road.gdshaderinc uses the shared winter_wear function and the same 5 m across / 9 m along texture scale as ordinary winter roads. This replaces world-axis sampling for winter deck colour.

Re-ran `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureWinterBridge`: exit 0, two updated captures saved, collision cells preserved. Inspected gameplay capture: streaks now run along the deck. `git diff --check` on the three changed rendering files passed (line-ending warnings only). Requirements V02/V04/Q01. No Android export/device test; owner acceptance remains.
