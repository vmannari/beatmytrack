# Forklift model review — 2026-10-25

Request: review the current Forklift after the raised carriage, solid body panels, single rear sticker, lower fitting removal and 80 km/h changes. This is a findings-only review; no production model, handling, camera, livery or saved data was changed.

[Native screenshot gallery](evidence/forklift-review-2026-10-25/report.html) · [Machine-readable report](evidence/forklift-review-2026-10-25/report.json)

## Findings

1. **P2 / FR01 — Both fork side faces have reversed winding.** In `game/vehicle/forklift_model.gd:239`, the two profile caps use the opposite triangle order to their supplied outward normals and the connecting faces. Each fork has 14 of 32 triangles disagreeing with its normal and 18 inconsistent shared edges, in both detailed and racing geometry. They have no open boundary, so a closure-only test misses this problem. Back-face culling removes the exterior side and exposes the opposite inner side, making the fork appear thin or incorrectly shaded. Reverse the two side-face orders and retain the current profile, thickness and transport height. Evidence: `gl_compatibility/fork-side.png`, `fork-underside.png` and `mobile/batched-fork-side.png` in the review folder.

2. **P2 / FR02 — The steering-wheel rim disappears from below.** `game/vehicle/forklift_model.gd:154` uses `VisualGeometry.ring`, which constructs a single flat annulus in `game/vehicle/visual_geometry.gd:209`. It has zero geometric thickness/volume and back-face culling. The lower cockpit view retains the hub and spokes but loses the complete rim; the production merger retains this defect. Use a round-section, closed rim. The wheel's current tilt is not classified as a defect by this review. Evidence: `gl_compatibility/cockpit-top.png`, `cockpit-low.png` and `mobile/batched-cockpit-low.png`.

3. **P3 / FR03 — Lift chains read as disconnected floating blocks.** `game/vehicle/forklift_model.gd:217` places 30 mm-high blocks with 37.3 mm gaps in the detailed model and 145 mm gaps in the racing model. The geometry has no continuous connecting run, wrap over the pulley or return/anchor to the raised carriage. This is conspicuous in the Garage close-up. A connected chain silhouette with a pulley wrap and visible termination would finish the mechanism without requiring an animated lift system. Evidence: `gl_compatibility/mast-front.png` and `mobile/batched-mast-front.png`.

4. **P3 / FR04 — The upper exhaust ends in a solid cap.** The exhaust at `game/vehicle/forklift_model.gd:57` is built by `_pipe` at line 299 from default capped cylinders. Its terminal segment reports `cap_top = true` and the outlet presents a flat disk rather than a bore. Add a hollow dark opening and wall thickness; retain the upper stack and the already removed lower fitting. Evidence: `gl_compatibility/exhaust-outlet.png` and `mobile/batched-exhaust-outlet.png`.

## What reviewed well

Both formed side skins and all four rolled wheel arches have zero boundary edges, zero inconsistent shared edges and zero normal/winding disagreements in detailed and racing geometry. The rear crest is visible between the lamps, the lower fitting is absent, and the side panels, seat, guard and counterweight form a coherent vehicle. The remaining issues are localized; the raised fork position and handling do not need changing to address them.

## Native inspection and scope

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. Desktop NVIDIA RTX 3090. The diagnostic builds the actual current `CarVisual`, audits both detail variants, applies the normal rear crest, and captures the shared showroom lighting with diagnostic cameras. Mobile also captures the production static merger. These camera poses exist only in the review script.

Commands actually run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/review_forklift_model.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/review_forklift_model.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 180
```

The first Compatibility diagnostic failed because its reader assigned a null index array to `PackedInt32Array`; the reader was corrected to accept unindexed meshes. That initial log is retained in `logs/initial-diagnostic.log`. Subsequent Compatibility and desktop Mobile runs exited 0, produced 9 and 13 native screenshots respectively, and reported the same mesh defects. Exit 0 indicates the inspection completed, not that the model passed all quality checks. No failing production invariant was removed or weakened.

Changed files: the new review script, this guide, and `docs/evidence/forklift-review-2026-10-25/` only. Source hashes, exact command logs and a text-only review checkpoint are retained there. No model fix or game behavior change was made. No device attachment check, physical-device test, APK, purchase, live mutation, deployment or owner-process restart was performed. Device performance, actual saved appearance and owner visual acceptance are outside this review. Earlier handling/bridge/80 km/h results were not rerun or newly certified.
