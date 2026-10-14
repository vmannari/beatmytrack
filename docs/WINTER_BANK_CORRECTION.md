# Winter connected-bank correction — 2026-10-12

The owner requests more visible snow blocks, clearer elevation above the terrain, white snow with blue primarily in shadows, then rejects the separate-block construction as worse. Final kit148 returns to the connected kit142 bank that the owner called “not bad.” This is a restrained refinement of that shape, not the rejected dense block heap. Reference-level appearance remains subject to owner review.

| Requirement | Final change |
| --- | --- |
| WE27 / V04 | Raise the connected bank's nominal crown term from 0.60 to 0.74 m, retaining its original footprint, variable crest, frost transition and buried outer apron. |
| WE28 / V04 | Retain the original embedded fragments, with radius base 0.16→0.19 m and height base 0.12→0.16 m. Restore the original placement, 80-patch / 240-fragment maximum, topology and normals after owner rejection of the larger separate blocks. |
| WE29 / V04 | Neutral-white raised snow retains the original texture's luminance and fine sculpted detail; cool scene lighting and shadows supply blue. Elevation-based blending returns to the existing terrain material at the bank's foot. |
| V05 / G01 / R01 / Q01 | Keep existing texture samples, indexed/cached meshes, directional ice, poles, camera, terrain artwork, canonical handling/collision and backend contracts. Check actual native/Mobile rendering and 4K driving cost. |

## Changed files

- `game/track/native_track_visual.gd`: final diff against the captured kit142 baseline is the visual cache version (148) and the three small crown/fragment dimension changes above. The experimental reservoir placement, lower-resolution foundation and dense separate clump geometry are removed. Existing 0.28 m longitudinal sampling, twelve cross-bank points, exact shape reuse, UV/row caches and indexed buffers are restored unchanged.
- `game/track/winter_bank.gdshader`: a vertex height factor blends the bank's raised surfaces toward neutral luminance, `clamp(original_luminance*1.06+0.09,0,0.82)`. The original value range remains readable instead of replacing it with a nearly flat white material. Low/outer surfaces blend back into the original snow texture, preserving the terrain join. No extra texture lookup or runtime noise is introduced.
- `game/tests/test_winter_environment.gd`: current evidence destination only; all existing assertions and diagnostic camera behavior remain.
- `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and this report record final scope, commands and remaining acceptance.

## Actual verification

Commands used process-local execution-policy bypass and `scripts/dev.ps1` with pinned Godot `4.7.2.stable.official.ed1daf0bf`. [Actual logs](evidence/winter-raised-blocks-2026-10-12/logs/).

| Arguments to `scripts/dev.ps1` | Result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_winter_environment.gd -Graphical -TestArgument @('--capture','--fresh-roads','--bank-detail','--video')` | Final kit148 Compatibility: 101 checks, zero failures. Fresh taper/bridge material attributes, sparse poles, terrain join, scenery/canonical separation and real captures pass. |
| Same environment script with `-Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--capture','--fresh-roads','--bank-detail')` | Final kit148 Mobile Vulkan: 100 checks, zero failures. |
| `-Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -TestArgument @('--capture','--video','--output-dir=res://../docs/evidence/winter-raised-blocks-2026-10-12/wind-validation')` | Final kit148: 47 checks, zero failures. Static 723 / moving 761, 751, 750 opaque roof samples unchanged; moving interior AA samples unchanged; dark-light delta zero. One mixed AA boundary remains within the existing acceptance. |
| `-Action Doctor` | Correct engine/templates and tools found; ADB device list empty. |

The final independent 4K driving command was `-Action TestScript -ScriptPath res://tests/profile_winter_desktop.gd -Graphical -TestArgument @('--document=C:/Users/ville/AppData/Roaming/Circuit01Lab/cloud/fe772d2e756f39f351786a6c81dcb401f381848c01d5ea2cfdc05969d0cf0aed/cd0b5ca436fd1dd3e15256ba506fa528792e351bd6df13dbbaa49681d8e75262.json','--tag=bank-correction-final','--profile-dir=res://../docs/evidence/winter-raised-blocks-2026-10-12/performance','--4k','--seconds=20','--modes=full')`.

RTX3090 Compatibility, 3840×2160, scale 1, 2× MSAA, diagnostic VSync off: 2,400 actual ticks in the unscored 20 s driving sample; frame median **3.646 ms**, p95 **6.735 ms**, p99 **8.194 ms**, worst **12.266 ms**, zero frames over 16.667 ms. GPU median **2.440 ms**, p95 **3.575 ms**. 375 draws / about 550,526 submitted primitives. [Final raw measurements](evidence/winter-raised-blocks-2026-10-12/performance/desktop-bank-correction-final-gl_compatibility.json).

Fixture submission remains 372,717 primitives / 314 Compatibility and 330 Mobile draws. Slippery's bank remains 257,607 indices, with 55,977 indexed vertices (six more than the prior kit142 report because changed positions affect exact deduplication). No numerical frame-time improvement is claimed. Cold construction was not reprofiled; the prior build caches and shape reuse remain.

Older kit143 prototype profiles are retained separately. Their first run had seven >16.667 ms frame spikes; the subsequent hidden-bank and restored-bank samples had none. These short samples do not establish the cause and are not evidence for final kit148 performance. The owner-rejected block/ledge captures are under `rejected-blocks` and `rejected-ledge`; final root captures show kit148 only.

## Review and limits

[Corrected bank close-up](evidence/winter-raised-blocks-2026-10-12/bank-detail.png), [actual driving](evidence/winter-raised-blocks-2026-10-12/driving.png), [driving motion](evidence/winter-raised-blocks-2026-10-12/driving-motion.html), [material-only bend](evidence/winter-raised-blocks-2026-10-12/materials.png), [Mobile close-up](evidence/winter-raised-blocks-2026-10-12/mobile/bank-detail.png), [starting kit142 bank](evidence/winter-raised-blocks-2026-10-12/before-bank-detail.png).

Restart to replace already prepared worlds. Owner appearance acceptance against the supplied close-up, full laps and narrow/overlapping creator-road shoulders remain open. No phone is attached; no physical-device visual/performance/thermal/touch test, Android export/install, full Validate, physics regression, backend test/deploy or live write was performed. Desktop Mobile Vulkan is not a phone test. Original asset provenance and all other work remain unchanged.

Task-only checkpoint and source patch are under `build/winter_raised_blocks`; the main Git index/branch and unrelated workspace changes are preserved.
