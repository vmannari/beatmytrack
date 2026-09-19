# Grey handrails and asphalt material correction - 2026-09-15

Owner requests grey handrails with a suitable shade and rejects the road's visual quality. Requirements V02/V04/V05; preserve G01/R01. Track-kit-22.

## Changes

- `creator_bridge_visual.gd`: centralized rail colors, warm neutral grey top `#858681` and graphite side/posts `#60635f`. Chosen after viewing the actual bridge against warm concrete, grass and charcoal road: grey keeps the rail readable without the previous blue accent. Simple profile and 0.85 m height retained.
- `bridge_presentation.gd`: native rails use the same color constants.
- `surface_detail.gdshaderinc`: replaces soft 25 cm mottling with finer thresholded mineral flecks/pores (approximately 8 cm noise scale), low-contrast larger chips, and projected-footprint filtering. No broad macro patches. First graphical trial was too speckled; final trial reduced contrast and increased fine-grain frequency. No new bitmap assets.
- `native_track_visual.gd`: track-kit-22. This document, project status/plan and evidence folder record delivery.

## Actual verification

Ran both actions twice, before and after the final texture tuning, through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with pinned Godot 4.7.2:

- `CaptureStyle -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_5765ff853b63dea5.json"`: all captures succeeded, unchanged native cells, zero bad road normals.
- `CaptureBridgeHUD`: each run passed 95 checks, zero failures; native/creator collision layers preserved.
- Scoped `git diff --check`: passed with line-ending notices only.

Inspected both trial and final road/creator bridge images on desktop Compatibility. Final [road](evidence/grey-rails-asphalt/road.png), [creator bridge](evidence/grey-rails-asphalt/bridge.png), [native capture](evidence/grey-rails-asphalt/native.png) and logs saved. This is a material refinement for owner review, not a claim that road art quality has been accepted.

No phone test, device enumeration, motion capture or GPU profile performed. Grain stability and readability on a phone remain unverified. Existing shoulder joins, bridge crest seams and raster outlines remain limitations. Camera, handling, collision and user documents unchanged; user-data wear remains deferred.
