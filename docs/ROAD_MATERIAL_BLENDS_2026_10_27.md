# Compacted gravel and gradual material joins — 2026-10-27

RMB01: The owner requests gravel closer to the Desert road. Grass and Storm now
reuse the existing Desert compacted-road texture, warm road palette and quiet
directional detail. Storm darkens this same finish. This supersedes the previous
grey stone treatment in the initial selected-piece implementation.

RMB02: Asphalt and gravel now blend through connected road cells up to three
metres on either side of a material boundary. The transition uses a smooth curve
with mild grain breakup. Ground colour, normal detail, wet roughness/specularity
and asphalt markings fade together. Equal-material joins remain solid; separated
roads do not bleed across grass gaps. The previous one-cell material change is
explicitly superseded by this broader visual transition.

RMB03: Bridge decks and ground have independent blend channels. Connected ramps
meet the ground finish gradually; bridge-to-bridge joins also blend. An asphalt
underpass cannot tint a gravel deck. Bridge paint tapers through the transition,
and gravel no longer carries asphalt approach markings. The existing bridge
shape, ramps, rails and shadows remain; their lighting still follows the physical
geometry.

RMB04: This is presentation work. Selected materials, physical surface cells,
kerbs, metadata and content hashes remain exact before and after mask generation.
The two synthetic mixed-track identities are identical to the prior task's
verified client identities. Existing driving factors remain 0.8 grip/2.0
resistance on gravel. No compiler, schema, rules, car tuning or shared physics
version changes. Visual kit 216 and a versioned preview-mask key invalidate the
old presentation cache.

The worker prepares asphalt coverage, ground material and deck material in one
RGBA image. Bridge installation reuses that image. A cold standalone race makes
it once on demand. Distance propagation visits only connected road cells within
the fixed blend distance; it does not blur through intervening grass or add
unbounded convolution passes. Existing cache limits remain. No phone frame-time
or memory claim is made.

Runtime files are `game/editor/creator_preview_masks.gd`,
`game/track/bridge_presentation.gd`, `creator_bridge_visual.gd`,
`bridge_road.gdshaderinc`, `creator_road.gdshaderinc`, `surface_detail.gdshaderinc`,
`surface_shader_variants.gd` and `native_track_visual.gd`. The focused regression
is `game/tests/test_road_material_blends.gd`, extending the previous real App
workflow. The base test now accepts a separate evidence output directory and
asserts intermediate material values instead of the superseded hard join.
`docs/CREATOR_FORMAT.md` records the current presentation behavior.

Actual validation:

- Compatibility desktop: 185 checks, zero failures. Includes every road shape,
  editor selection, WIP save, undo/redo, actual Test drive in Grass/Storm, repeated
  material selection, native unselected views and bridge closeups.
- Mobile desktop: 182 checks, zero failures, with the same real App and bridge
  review. This runs on the desktop GPU. The three extra Compatibility checks are
  the explicit captured-task-start implementation comparison added afterward;
  the final runtime is identical between these two native runs.
- Existing compiler raster: all eight original complete-track goldens pass,
  without generating new fixtures.
- Full GDScript parser: 1,353 scripts, zero failures.
- An earlier isolated domain-only run passed 115 checks. The later native runs
  also cover the shared mask reuse and retained-task-start comparison.
- Captured task-start mask values across the joint are
  `[1, 1, 1, 1, 0, 0, 0, 0]`. The new values at the same offsets are
  `[1, .957, .796, .561, .318, .114, .004, 0]` for both biomes. The six interior
  samples now all contain intermediate material values.
- Both synthetic mixed-track hashes match the prior implementation exactly:
  Grass `806aa926351422654a97d5650b888b0a2fa89b02bda5c1e480b7abbdab26cfec`;
  Storm `d1c6eb1ae7672149fac48a41d956e9389028be54400058e1661d823a5d6f723b`.

Commands use the pinned Godot 4.7.2 build through the existing entry point, with
`APPDATA` set to `build/road-material-blends-2026-10-27/appdata` or a dedicated
regression directory. The inherited App fixture uses its original per-process
build directory, isolated records, library and cloud root. The API URL is empty.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_road_material_blends.gd -TestArgument '--domain-only'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_road_material_blends.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_road_material_blends.gd -Graphical -RenderingMethod mobile
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_compiler_raster.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
```

Evidence, exact command logs, mask samples, source hashes and the source-only
Git-checked checkpoint are in
`docs/evidence/road-material-blends-2026-10-27/report.json`. Twenty-four PNGs show
the real editor/Test drive and standalone native bridge detail in both renderers.
The first Compatibility review passed 180 checks before shared-image reuse and
approach-paint cleanup; final native results above supersede that draft. Optional
Python pixel inspection found Pillow unavailable; a standard-library PNG reader
was used instead, without installing dependencies.

Reload the client and review the warm finish, transition length, bends, ramps and
paint fade on the intended device. Owner appearance/motion/touch and sustained
performance acceptance remain. No physical-device attachment query or physical-
device test was performed. No APK, real authentication/purchase, owner-save or
live mutation, deployment, owner-process restart, main-index staging, commit or
merge was performed. Concurrent work is preserved.
