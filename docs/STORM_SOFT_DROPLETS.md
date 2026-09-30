# Softer screen-water edges (2026-09-30)

Requirements: V02/V04/Q01; owner requests softer screen droplets like the supplied reference.

Both adhered beads and larger sliding lens drops now fade over a broader boundary with derivative filtering. Rims and glints are weaker and wider, the dark lower edge is lighter, and screen refraction is reduced. The adhered-bead rim is masked by the feathered body rather than drawing an independent outline. No extra screen samples or blur pass. Droplet placement/motion, road material, tire spray, camera and canonical simulation are unchanged.

Changed files: game/track/storm_lens.gdshader, game/track/storm_wet_glass.gdshader, this document/evidence, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md.

Actual validation: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureStorm -Track track_acf29166cceaaa42` on pinned Godot 4.7.2: **85 checks, zero failures**, no shader errors. Final rain capture inspected. `git diff --check` and `git diff --cached --check` pass (line-ending notices only).

[Soft droplets](evidence/storm-soft-droplets/rain.png) / [Lightning capture](evidence/storm-soft-droplets/lightning.png). No physical-phone test or export; attachment was not checked. Owner visual acceptance and physical-device appearance remain outstanding.
