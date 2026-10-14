# Snow powder clouds at banks — 2026-10-12

The owner accepts the harder bank interaction but rejects its fragment appearance, requesting the dust-cloud style with snow-specific motion. This revision replaces the large pushed clods and entry fragments with compact textured powder. The accepted bank resistance and physics56 are unchanged.

## Requirements and files

- WSP01, cloud appearance: `game/vehicle/sand_dust.gd`, `winter-spray-6`. Reuse the existing original `dust_puff_v1.png`, cloud billboard geometry, depth fading and world-space occlusion. Snow-only material variants retain the texture's broken edges and granular density, remove the sandy pigment and use white highlights with cool shaded lobes. Ordinary dust's shader template is unchanged.
- WSP02, snow motion: two ten-puff pushing pools roll outward around the contact, grow briefly and then fall and thin over0.62 seconds. Two twelve-puff one-shot entry pools disperse over0.42 seconds. Downward gravity and stronger damping replace buoyant, lingering dust movement. Particle rotation and random spawn spread break up repetition. A small body-height probe increases density when the car is embedded, while origins remain attached to actual bank contacts/visible-bank heights. Stationary/clear-road/airborne/elevated suppression and retry/rewind cleanup remain.
- WSP03/Q01, bounded work and adaptation: bank slots drop from176 fragments to44 puffs, with the same four systems. Cropped octagonal cards and the existing two texture samples avoid new artwork or full-screen volumes. Snow clouds join the shared cloud-material rebinding path so changed creator bridge layouts and height-occlusion settings reach them. The existing sparse cosmetic height bake and fine canonical contact index remain.
- G01/R01/V04/V05: bank forces, prepared contact geometry, car handling, camera and road/bank/terrain materials are untouched by this task. Accepted `snow_banks.gd` and `vehicle_simulation.gd` hashes are checked against the preceding bank checkpoint. No physics/content contract is bumped.

`game/tests/test_snow_bank_behaviour.gd` captures this evidence, checks downward/short-lived clouds and bridge rebinding, and explicitly resumes only its diagnostic scene after focus loss. It adds a fixed-position hidden/shown GPU profile. `game/tests/capture_winter.gd` updates the superseded solid-fragment visual expectations to the owner's textured-cloud request and animates its staged particles while the vehicle is frozen. `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md` record actual delivery.

## Actual verification

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, `scripts/dev.ps1`, PowerShell process execution-policy Bypass and normal Windows graphics/certificate access. Graphics run on an RTX3090 desktop, not the attached phone.

| Actual arguments after `scripts/dev.ps1` | Outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_snow_bank_behaviour.gd -Graphical -TestArgument @('--capture')` | Final Compatibility:52,035 checks,0 failures; all five cars/replay/rewind/contact preservation, 180 driving frames,80 pushing frames, two entry bursts |
| Previous command with `-RenderingMethod mobile` | Final Mobile Vulkan:52,035 checks,0 failures; same interaction outcomes |
| `-Action TestScript -ScriptPath res://tests/capture_winter.gd -Graphical -TestArgument @('--output-dir=res://../docs/evidence/winter-snow-clouds-2026-10-12/interaction')` |168 checks,0 failures; contact mapping, impact lifetime/direction, wheel snow and lifecycle |
| `-Action TestDesert` |87 checks,0 failures |
| `-Action Import` | Final import passed after a concurrently authored `ContainerVisual` became available |
| `-Action Doctor` | DN2103 phone attached; no physical-device test performed |

Actual hidden/shown GPU probes find1,356 Compatibility and1,305 Mobile powder pixels at the contact. The historical JSON field remains `visible_fragment_pixels`, now measuring powder. Initial evidence with a focus-loss pause drawer is rejected; diagnostic resumption corrects it. Two later test starts and the first import caught an unfinished unrelated ContainerVisual registration; no foreign source was reverted, and final import/tests pass. Initial logs remain in evidence.

At1280×720, final fixed-contact GPU stage medians range0.903–3.692 ms on Compatibility and0.585–3.508 ms on Mobile. The large first-stage/order variation reflects desktop load/warmup, preventing a reliable incremental-cost estimate. Last visible/hidden medians are0.903/0.899 ms and0.585/0.588 ms respectively; these are raw observations, not a speedup or phone guarantee. The diagnostic pauses particle positions and measures the whole scene, so it does not establish active frame pacing or worst-case bank-cloud cost. Raw profiles include draw/primitive counts and all stages.

## Review and limits

[Driving motion](evidence/winter-snow-clouds-2026-10-12/motion.html), [powder close-up](evidence/winter-snow-clouds-2026-10-12/push-visible.png), [Mobile motion](evidence/winter-snow-clouds-2026-10-12/mobile/motion.html), [Mobile close-up](evidence/winter-snow-clouds-2026-10-12/mobile/push-visible.png), [Native profile](evidence/winter-snow-clouds-2026-10-12/powder-profile.json), [Mobile profile](evidence/winter-snow-clouds-2026-10-12/mobile/powder-profile.json). The closer inspection camera is diagnostic only.

Restart the client to load the effect. Owner acceptance remains for powder density, snow character and visibility in the normal cameras, including glancing hits and deep/reverse travel. The texture is a small billboard volume proxy and the bank mesh remains fixed. No phone appearance/performance test, Android export/install, full Validate, physics merge, backend test/deployment or live write was performed. Original asset provenance remains; no new raster asset or external dependency was added.

The task-only checkpoint/source patch is under `build/winter_snow_clouds`, with main index/HEAD and concurrent work preserved. Motion HTML remains in workspace evidence.
