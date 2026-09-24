# Off-road grass clippings — 2026-09-24

Requirement IDs: V02/V04/V05/Q01. Owner requested better off-road clippings in non-desert biomes. Presentation revision `grass-clippings-2` replaces bright rectangular boxes with original five-triangle folded, tapered blades. No external artwork or assets.

Blades use matte scene lighting, stable per-particle olive/green variation, warm torn tips, randomized size and two-axis tumbling. Lower launch speeds and 0.72-second lives keep the spray close to wheel contacts; geometry shrinks during its final third instead of fading into transparent confetti. Maximum clipping capacity falls from 480 to 384; blade geometry falls from 12 to 5 triangles per particle. These are budget reductions, not measured phone performance gains. Existing mud, surface eligibility, desert dust and canonical handling are unchanged.

Changed files: `game/vehicle/sand_dust.gd`, new `game/vehicle/grass_clipping.gdshader`, `game/tests/test_soil.gd`, `game/tests/test_grass.gd`, this document, status/plan entries and `docs/evidence/grass-clippings/`.

Actual commands (pinned Godot 4.7.2 through the project entry point):

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestSoil`: initial run found the old BoxMesh-specific assertion. Updated it to verify folded volumetric geometry and its triangle budget; final run: 163 checks, zero failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureSoil`: 172 checks, zero failures; shader compiled on desktop Compatibility renderer. Preserved isolated spray evidence; restored unrelated regenerated historical captures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestDesert`: 53 checks, zero failures.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureGrass`: 32 checks, zero failures. Inspected meadow driving-scale and close detail captures.

Evidence: [driving scale](evidence/grass-clippings/driving.png), [detail](evidence/grass-clippings/detail.png), [isolated spray](evidence/grass-clippings/isolated-spray.png). Meadow captures animate a presentation-only review car beside the paused fixture's original car; the HUD is paused and does not report that review car's speed. Detail view is a diagnostic camera, not a production-camera change. The isolated fixture has no visible car and serves only to inspect debris silhouettes.

Remaining acceptance: owner review in motion, night/storm/winter appearance and physical-phone frame pacing. No device test, Android export or installation performed; phone attachment was not checked. Existing unrelated working-tree edits were preserved.
