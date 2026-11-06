# Volt pale roof in Night — investigation, 2026-11-06

The panoramic roof retains its daytime reflection in Night. It is dark tinted glass in the model, but `electric_glass.gdshader` uses `render_mode unshaded` and a fixed analytic daytime sky/cloud palette. Neither the biome's ambient light nor any scene light affects its output. The body darkens while the glass remains comparatively pale. This reproduces the reported appearance as pale grey-blue in the tested desktop view; it is not a white paint assignment.

## Requirements and findings

- **VNR01 — trace the roof material.** `game/vehicle/electric_reference_cabin.gd:106` creates a separate panoramic-roof material with display-space tint `(0.026, 0.043, 0.055)`. `game/vehicle/electric_glass.gdshader:2` makes it unshaded; lines 19–23 construct the daytime reflection and line 31 mixes it into the final colour. Only `studio_mode` changes the analytic environment. There is no Night input. `VehicleWeathering._bind` skips this glass because it is not a StandardMaterial3D/livery material, so weathering does not correct the lighting response.
- **VNR02 — confirm in native rendering.** The production Game scene, stock Volt and a generated Night track run in a private offline profile. The ordinary race camera is captured first. A diagnostic close view then compares the same car, pose and roof under Night lighting, every scene light plus ambient disabled, and daytime lighting. Black/white roof-only material controls identify 16,780 fully covered interior roof pixels. Their mean RGB is exactly `(47.963, 62.333, 70.506)` on a 0–255 scale in all three cases; maximum difference is **zero**. This demonstrates the failure without relying on the roof being hidden or on a shader-source assertion. Restoring the original material reproduces the complete Night frame byte-for-byte. Track data and simulation state remain unchanged.
- **VNR03 — identify the bounded correction.** Give the analytic glass reflection a dark Night palette/strength selected through car-owned materials at race preparation, preserving daylight and studio defaults. Do not globally darken the car paint or scene. The same shader is used by Hovercraft, so any implementation needs explicit scope and checks for both models, prepared/procedural cars, daytime and Garage transitions. Honour the existing prepared-asset and thumbnail provenance checks. No correction is implemented by this investigation.

## Evidence and actual commands

```powershell
python docs/evidence/volt-night-roof-2026-11-06/run_review.py gl_compatibility
python docs/evidence/volt-night-roof-2026-11-06/checkpoint.py
```

The runner uses `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_volt_night_roof.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180`, with a process-scoped execution policy and private APPDATA/LOCALAPPDATA under `build/volt-night-roof-20261106`. It uses the pinned Godot `4.7.2.stable.official.ed1daf0bf`. Final desktop Compatibility / RTX 3090 run: **exit 0, 13 checks, 0 failures**, seven native captures. The [process receipt](evidence/volt-night-roof-2026-11-06/gl_compatibility-receipt.json) confirms the five inspected shipping sources and the fixture remain unchanged during the accepted run. The [pixel report](evidence/volt-night-roof-2026-11-06/gl_compatibility/report.json) contains exact measurements.

- [Production race framing](evidence/volt-night-roof-2026-11-06/gl_compatibility/night-production-camera.png)
- [Night diagnostic close view](evidence/volt-night-roof-2026-11-06/gl_compatibility/night-close.png)
- [All lighting disabled](evidence/volt-night-roof-2026-11-06/gl_compatibility/all-lights-off-close.png)
- [Same roof under day lighting](evidence/volt-night-roof-2026-11-06/gl_compatibility/day-lighting-close.png)

An initial launch was blocked by PowerShell's script execution policy. A second sandboxed launch returned exit 1 with root-certificate-store and Access denied messages; subsequent capture files were not treated as an accepted run. A complete permitted desktop rerun produced the accepted receipt and images. A sandboxed process-list diagnostic also returned Access denied. The initial logs/receipts are retained beside the final evidence; none count as passing tests.

The first isolated patch round-trip hit inherited Git newline conversion during the byte-equality check. Setting `core.autocrlf=false` in that disposable verification repository preserved the existing mixed line endings; the repeated forward/reverse checks and byte comparisons passed. No main-repository Git configuration was changed.

## Files, checkpoint and limits

Added `game/tests/review_volt_night_roof.gd`, the evidence runner and this report; updated the three project status summaries. The reviewable [task patch](evidence/volt-night-roof-2026-11-06/task.patch) contains only those investigation changes, with [forward/reverse verification](evidence/volt-night-roof-2026-11-06/checkpoint.json). Native images, logs and receipts remain alongside it.

No material, model, biome lighting or gameplay implementation was changed. The standard `dev.ps1` entry point refreshed generated client identity metadata; concurrent changes are preserved and excluded from the task patch. No main-index staging or commit was performed.

No device query/test, APK/export, owner-save/process change, live/backend request or deployment. The owner's exact car configuration, track and camera were not supplied; this verifies the underlying material fault in a local stock-car reproduction. Mobile renderer, physical-device appearance, a corrected implementation and owner acceptance remain untested.
