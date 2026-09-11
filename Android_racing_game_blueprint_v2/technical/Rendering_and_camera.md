# 2.5D presentation architecture / v2.0

The world is rendered with 3D meshes and a high overhead Camera3D; the authoritative driving model remains planar. "2.5D" here is a presentation/simulation separation, not a low rear chase view or a requirement for sprites.

## Scene and data boundaries

```text
RaceScene
  WorldRoot (Node3D)
    TrackVisuals       generated road mesh, kerbs, allowlisted decorations
    CarVisual          mesh, wheel/steering animation, slip effects
    GhostVisuals       non-colliding sampled playback
    LightRig           restrained directional lighting and stylized environment
  FollowRig (Node3D)
    Camera3D           reference-calibrated overhead view
  HUD (CanvasLayer)
    RaceStatus / TouchControls / Pause
  RacePresenter        interpolates canonical snapshots; never changes official state

Canonical planar simulation -> snapshots -> RacePresenter -> 3D transforms
                            -> verifier (no meshes, textures, UI or GPU required)
Track data -----------------> canonical collision/gates
           -----------------> TrackVisualBuilder / editor preview
```

Choose a documented mapping, e.g. simulation (x,y) to Godot world (x,0,-y) with +Y world up; derive heading consistently. Do not use a 3D wheel/rigid-body solver to replace the pinned canonical simulation merely for visuals. Body roll/pitch, wheel spin, suspension motion and visual tire deformation are presentation-only unless deliberately introduced as versioned simulation rules. The headless verifier continues to use canonical data, not mesh collision imported from user files.

## Camera

`ui/Camera_contract.json` is the calibration contract. Keep follow translation, projected magnification, yaw and pitch as distinct settings. Store a reference-scene fixture, car pose, aspect ratio and camera profile. Capture projected vehicle bounds before and after the adjustment. For orthographic framing, new extent = old extent / 1.15. Perspective setup requires matching the screenshot rather than assuming a fixed metre height can be inferred. Camera3D exposes projection, size, FOV and aspect policies. [S21]

Render world and HUD separately. No whole-circuit automatic fitting during racing. An editor overview and menu showroom camera are separate presentation scenes. Follow interpolation uses render snapshots; it must not feed back into steering or simulation. On performance-tier switches, keep camera framing and HUD scale stable.

## Rendering decision gate

Keep the Godot standard / typed GDScript stack. The previous reason "Compatibility because this is a 2D game" is superseded. Prototype the required stylized 3D corner in Compatibility and Mobile on the intended Android devices; choose the lowest-cost renderer that preserves the accepted appearance and frame pacing. Godot documents Compatibility for simple 3D/wider hardware coverage and Mobile for newer-device 3D needs; the choice still requires measurement. Do not adopt Forward+ merely to chase an AAA label. [S04]

Start from toon material shading as a capability baseline; custom tonal bands and selective mesh contours can be assessed in the slice. Godot documents `diffuse_toon` and `specular_toon`, but those flags alone do not reproduce the reference. [S22] Prefer a small, coherent material library and selected silhouette outlines. Benchmark contour thickness, outline aliasing, foliage overdraw, shadow cost and effects in motion. Do not assume a screen-space normal-buffer outline works identically across renderers; keep renderer-specific features behind presentation profiles.

## Content pipeline

Author original, provenance-tracked cars and a bounded modular road kit. Store export scale, pivot, forward axis, silhouette/LOD requirements, collision category and material slot IDs per asset. TrackVisualBuilder consumes existing allowlisted road pieces and shared geometry parameters; it may not invent a different drivable boundary. Decorative terrain/trees stay outside a view/occlusion safety envelope or use a reviewed fade policy. A shaded 3D editor preview can reuse the same builder while offering an overhead editing camera.

Geometry/collision/surface changes still create a track version. A material-only or non-colliding cosmetic revision may be presentation-only only after visibility/fairness review; it cannot secretly add collision or hide gates. Store separate visual-kit and collision-kit versions where needed. Existing starter data schemas are kept as the canonical v1 contract; add explicit versioned visual metadata during implementation rather than making unsupported schema fields appear accepted now.

## Performance / scope

P0-V is a reviewable vertical slice: one car, one polished corner, a small prop kit, race HUD, garage composition and device profiling. Set final triangle/material/texture/visible-object budgets from measurements, not from a desktop render. Target 60 fps on an agreed device; measure thermal behaviour. A lower quality mode may reduce effects and visible decoration, but never simulation rate, grip, timing or collision. The full six-car / twelve-track content scope is re-estimated after this gate.

No engine project, custom shader or 3D car asset has been built as part of this documentation revision. The calibrated PNG is an image-space framing mockup. The reference art and menu crops are not shipping assets.

[S04] https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
[S21] https://docs.godotengine.org/en/stable/classes/class_camera3d.html
[S22] https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html
All three official documentation pages checked 2026-09-11.
