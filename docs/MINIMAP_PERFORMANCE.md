# Minimap performance and line weight

2026-09-15 owner feedback: large performance impact and overly thick minimap. Requirements **V02/V03/V05/Q01/R01**; the placed-road-only source remains authoritative.

## Fix

The previous map projected every road vertex and issued a filled-polygon command for each small road triangle whenever the player marker updated (roughly 12.5 times per second). This was expensive even though the roads were static.

`HUDRoadMap` now gives roads their own cached CanvasItem. Projection and screen-space point reduction run only on configuration or resize. Marker redraws draw two circles and do not invalidate the road layer. Thin lines come from paired edges of the placed road geometry, never race waypoints. The pale stroke is 1.5 logical pixels with a subtle 3-pixel dark backing, replacing the full-width road fill. Marker size is also slightly reduced.

## Measured desktop result

Pinned Godot 4.7.2, Compatibility, RTX 3090. `ProfileMinimap` reads the baseline script from Git checkpoint `c647398`, loads the same owner Curvy document, warms each version, then requests 180 real rendered marker updates. Instrumentation times only the map's steady-state `_draw` callback, not whole-frame or GPU time.

| | First run | Reproducibility run |
|---|---:|---:|
| Previous redraw callback | 6.131 ms | 5.921 ms |
| Cached-road marker callback | 0.052 ms | 0.051 ms |

The static road layer drew **once** across all 180 updates; its three layout/configuration rebuilds occurred during warm-up. This is about a **99% reduction in measured redraw CPU cost**, not a claim of a corresponding overall FPS increase. [Saved profile output](evidence/minimap-performance/profile.txt).

## Actual commands and checks

All actions used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `ProfileMinimap -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_5765ff853b63dea5.json"`: two successful comparisons, results above. Baseline is regenerated from the pinned Git revision.
- `CaptureBridgeHUD`: **95 checks, zero failures**, including new marker/cache checks, placed-road-only source, waypoint/paint independence, layouts and controls. Four captures saved without rendering errors.
- `CaptureStyle -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_5765ff853b63dea5.json"`: owner track read only; all captures and flat-road normal/cell audits passed.
- `Import`: passed; environment still reports missing Android build-tools.

Changed files: `game/ui/hud_road_map.gd`, `game/tests/test_bridge_hud.gd`, `game/tests/profile_minimap.gd` (+ UID), `scripts/dev.ps1`, this document/evidence and status/phase-plan entries. Unrelated local road, menu, race-start and suspension work is preserved separately.

[Thinner minimap capture](evidence/minimap-performance/after.png). [Previous thick map](evidence/reference-hud/curvy-bridge.png).

No phone test, Android export or full regression matrix was performed. Remaining acceptance: owner line-weight preference and whole-game performance on the affected device. The profile isolates a confirmed minimap bottleneck; it does not rule out other rendering costs.
