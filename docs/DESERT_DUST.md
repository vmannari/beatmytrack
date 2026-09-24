# Desert dust revision 2 ? 2026-09-24

Requirements V02/V04/V05/Q01. Owner requested trying the analyzed dust redesign. Presentation identity `desert-dust-2`; canonical handling and replay contracts are unchanged.

Four lingering emitters now total 384 particles (previously 2,880), retaining nine-second lifetime. Four separate tyre emitters total 192 particles with 1.1-second lifetime. Lingering quad size is 2.6 m with scale growth capped at 2.5 and random scale up to 1.28: maximum 8.32 m, versus 25.09 m previously. Peak alpha 0.60 decreases to 0.22 at 72% age and zero at expiry. The initial, fainter trial was increased after desktop inspection. Ordinary straight driving still emits dust.

The desert shader uses soft radial density with modest texture variation, restrained sand colouring and no strongly shaded baked lobes. It reuses the existing cleared texture; no new generated asset. Rotated sampling uses INSTANCE_CUSTOM.x, documented as particle angle in [Godot 4.7 spatial shader documentation](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html). Mipmaps enabled. Non-desert dust keeps its existing shader branch/profile; additional tyre emitters remain inactive there.

## Actual commands and results

Pinned engine through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

- `-Action Import`: pass, texture reimported with mipmaps.
- `-Action CaptureDesert -Track track_3e26605a8a90165e`: final 55 checks, zero failures, including five-car deterministic replay. Desktop image inspected. Earlier intermediate runs passed 54 checks; the generic fixture passed 45.
- `-Action TestSoil`: 163 checks, zero failures.
- `-Action ExportAndroid -QuickValidation`: final APK exported; startup, 74 driving, 18 catalog and 22 menu checks passed. Existing build-tools fallback and two driving ObjectDB shutdown warnings remain.
- `-Action InstallAndroid`: final build successfully installed on attached DN2103.
- `git diff --check` for implementation files: passed, only line-ending notices.

`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-features-phone.ps1 -DesertCostProfile -Seconds 15 -ReportName desert-dust-2026-09-24` installed an intermediate build but obtained no measurements while the phone was locked. Wake/dismiss-keyguard did not unlock it. The runner eventually failed during its normal-play relaunch; a subsequent `adb shell run-as org.circuit01.handlinglab ls files` verified diagnostic markers/results were removed. Final APK was then installed separately; `-Action LaunchAndroid` subsequently succeeded, restoring normal launch. No new performance improvement is claimed. Retained configuration/hash files in this evidence folder refer to the unsuccessful intermediate benchmark, not final APK.

## Files and acceptance

Implementation: `game/vehicle/sand_dust.gd`, `game/assets/textures/dust_puff_v1.png.import`; behavior/budget and capture validation in `game/tests/test_desert.gd`. This report, status/phase notes and new evidence folder record the slice.

[Emitting plume](evidence/desert-dust-2026-09-24/dense-dust.png) and [three seconds after stopping emission](evidence/desert-dust-2026-09-24/lingering-dust.png) use real renderer with scripted motion. Existing CaptureDesert also refreshes historical scenery evidence; those unrelated captures are excluded from this checkpoint.

Remaining: owner review of density/style in motion, unlocked phone A/B profiling and sustained thermal acceptance. The new effect is visibly lighter than the prior opaque cloud; whether its obstruction is sufficient remains a visual acceptance decision. No full replay regression suite was run for this presentation-only change.


## Reference correction ? desert-dust-3

The owner rejected revision 2's weak occlusion and supplied a rally convoy photograph showing a connected, opaque beige plume. This is visual direction only; the photograph is not a shipping asset. Requirements V02/V04/V05/Q01.

Revision 3 retains separate short tyre puffs and nine-second lingering clouds but reduces the lingering population further to 256. Broader 4 m quads grow earlier (1.4x at 12% age, 2.1x at 42%, maximum 2.5x); randomized maximum width is 12.8 m. Alpha holds at 0.88/0.82/0.55 through the early/middle/late cloud before fading out. A wider dense core, lighter beige tint, reduced launch velocity and stronger upward drift connect the wake and conceal road sections. Camera and canonical handling are unchanged.

The first dense capture exposed hard ground intersections. Depth-based soft intersection fading now blends the last 0.9 m against opaque scene geometry, with Compatibility and other renderer depth reconstruction branches. This adds a depth texture read per cloud fragment; lower particle count does not establish a performance improvement. Compared with revision 2, coverage and opacity deliberately increase. Compared with the original effect, count remains 91% lower and maximum sprite area about 74% lower.

Actual validation through pinned scripts/dev.ps1: CaptureDesert with saved track track_3e26605a8a90165e passed 55 checks after the shader change, including five-car exact replay; TestSoil passed 163 checks. Desktop emitting and lingering captures inspected. [Connected plume](evidence/desert-dust-reference-2026-09-24/dense-dust.png), [lingering plume](evidence/desert-dust-reference-2026-09-24/lingering-dust.png).

Changed implementation: game/vehicle/sand_dust.gd. Documentation: this report, DEVELOPMENT_STATUS.md, docs/PHASE_0_PLAN.md and the reference-correction evidence folder. Existing capture commands also refresh historical scenery images, excluded from this checkpoint. Unrelated editor work is preserved.

Phone was attached but locked (NotificationShade, mDreamingLockscreen=true). No new phone driving test or benchmark was performed. Owner visual acceptance, road occlusion in motion and sustained phone frame pacing remain unverified. The overhead single-car view cannot reproduce the perspective and accumulated multi-car plume in the reference exactly.

Final `-Action ExportAndroid -QuickValidation` passed startup, 74 driving, 18 catalog and 22 menu checks and produced the APK; `-Action InstallAndroid` succeeded on DN2103. Existing build-tools fallback and ObjectDB shutdown warnings remain. `git diff --check` passed for this slice.


## Immediate onset correction ? desert-dust-4

Owner reported that the car had already left before dust became noticeable. Requirements V02/V04/V05/Q01. The nine-second cloud previously took 0.72 seconds to reach peak alpha and 1.08 seconds to reach 1.4x scale. Those times are now 0.108 and 0.225 seconds. Initial scale increases from 0.4 to 0.65. This changes early growth only; nine-second life, mature cloud scale and 256 lingering particles remain.

The existing 192 short tyre particles use 1.4 m cards (previously 0.8 m), stronger initial size and 0.65 peak alpha (previously 0.24). Their ground intersection fade is reduced to 0.18 m; lingering clouds use 0.45 m instead of 0.9 m. This makes young grounded dust visible while retaining soft intersections. No new emitter or canonical handling change.

Actual pinned scripts/dev.ps1 commands: `-Action CaptureDesert -Track track_3e26605a8a90165e` passed 57 checks, including new early-opacity/growth checks and five-car exact replay; `-Action TestSoil` passed 163. Desktop capture inspected: plume now connects to the rear of the car. [Immediate wake](evidence/desert-dust-onset-2026-09-24/dense-dust.png), [lingering cloud](evidence/desert-dust-onset-2026-09-24/lingering-dust.png).

Changed files: game/vehicle/sand_dust.gd, game/tests/test_desert.gd, this report, status/phase notes and onset evidence folder. Historical scenery captures and unrelated creator edits are excluded from this checkpoint. Remaining acceptance: owner driving review and physical-device frame-time measurement. Earlier opacity/size increases near-car coverage; unchanged counts do not prove unchanged GPU cost.

`-Action ExportAndroid -QuickValidation` passed startup, 74 driving, 18 catalog and 22 menu checks; APK exported. `-Action InstallAndroid` succeeded on attached DN2103. No phone driving or profiling was performed. Existing build-tools fallback and driving ObjectDB shutdown warnings remain.


## Size-dependent slow rotation ? desert-dust-6

Owner requested slower rotation, then clarified that larger clouds should rotate slower. Requirements V02/V04/V05/Q01. Base dust angular velocity is random -12..12 degrees/second, previously -110..110. A particle-process angular-speed curve is derived from inverse authored growth, reducing lingering-cloud maximum speed to about 3.1 degrees/second at full size and short tyre puffs to about 5.6. The relation follows authored growth, not per-particle random scale differences. Angular speed is integrated by particle simulation; displayed angle is not divided by changing size, avoiding backwards unwinding. Density, onset, growth, lifetime and counts remain unchanged; other debris retains its angular velocity.

Changed implementation: game/vehicle/sand_dust.gd. Updated this report, status/phase notes and [desktop screenshot](evidence/desert-dust-rotation-2026-09-24/dense-dust.png). Actual pinned `scripts/dev.ps1 -Action CaptureDesert -Track track_3e26605a8a90165e`: 57 checks passed on final revision; screenshot inspected. The intermediate constant-speed revision also passed 57 checks and Android export and was installed before the owner clarification. A still image verifies rendering, not angular speed in motion. Owner motion acceptance and physical-device performance remain outstanding; no new tests were added for this presentation adjustment.

Final `-Action ExportAndroid -QuickValidation` passed startup, 74 driving, 18 catalog and 22 menu checks; APK exported. `-Action InstallAndroid` succeeded on attached DN2103. No phone driving or profiling was performed. Existing build-tools fallback and driving ObjectDB shutdown warnings remain.


## Rotation unit correction ? desert-dust-7

Owner observed that large clouds still spun rapidly. Requirements V02/V04/V05/Q01. The previous claimed 12/3.1 degrees-per-second rates were incorrect for the angular-velocity curve path. [Godot 4.7 source](https://raw.githubusercontent.com/godotengine/godot/4.7/scene/resources/particle_process_material.cpp) integrates angular_velocity_texture * DELTA * angular_velocity directly into the radian accumulator, whereas the no-curve branch converts degrees to radians. The previous unconverted curve could therefore run about 57.3 times too fast.

The growth-derived curve now includes degrees-to-radians conversion and inverse-square slowing. Base dust speed drops to +/-4, yielding intended peak angular speed 4 degrees/s at birth and approximately 0.27 degrees/s for mature lingering clouds; tyre puffs end at approximately 0.89 degrees/s. These are calculated bounds from engine source and configured curves, not measured GPU motion. Density, onset, population and plume geometry are unchanged. Random individual scale differences are still not part of the growth-based speed curve.

Actual pinned scripts/dev.ps1: CaptureDesert with saved track track_3e26605a8a90165e passed 61 checks (includes concurrent start-line assertions), screenshot inspected. A subsequent temporary attempt to retrieve generated shader code through RenderingServer stalled and was stopped; temporary test instrumentation was removed, preserving concurrent edits. No claim of successful local shader readback. [Rendered evidence](evidence/desert-dust-units-2026-09-24/dense-dust.png) is a still image, not angular-speed measurement.

Changed implementation: game/vehicle/sand_dust.gd. This report and new evidence folder record the correction. Unrelated pending editor, start-line and status changes are excluded from this checkpoint. Remaining: owner motion review and physical-device performance measurement; no new phone driving/profile run.

Final `-Action ExportAndroid -QuickValidation` passed startup, 74 driving, 18 catalog and 22 menu checks and exported the APK; `-Action InstallAndroid` succeeded on DN2103. Existing build-tools fallback and ObjectDB warnings remain. Status/phase entries were updated locally and remain unstaged alongside unrelated pending entries.


## Visible rotation with per-particle variation ? desert-dust-8

Owner found revision 7 almost stationary and requested slightly different speeds for different particles. Requirements V02/V04/V05/Q01. Dust angular-speed magnitude is now engine-randomized once per particle spawn between 10 and 14 degrees/s (12 +/- 2), with stable clockwise/counterclockwise direction selected separately by particle index. This avoids near-zero samples from a signed interval. The variation is across particles, not time-varying jitter.

Correct radian conversion remains. Size-based slowdown is inverse growth rather than inverse-square, producing calculated mature lingering speeds of 2.6-3.64 degrees/s and mature tyre-puff speeds of 4.7-6.6 degrees/s. These values follow authored growth rather than individual random size multipliers. Density, onset, counts and persistence are unchanged.

Implementation: game/vehicle/sand_dust.gd. Actual pinned `scripts/dev.ps1 -Action CaptureDesert -Track track_3e26605a8a90165e`: 61 checks passed, including current concurrent start-line checks. [Desktop screenshot](evidence/desert-dust-variation-2026-09-24/dense-dust.png) inspected; it verifies rendering, not measured angular motion. No new tests for this small tuning change. Owner motion review and device profiling remain pending. Unrelated pending work and historical captures are excluded from the checkpoint; status/phase notes are updated locally.

Final `-Action ExportAndroid -QuickValidation` passed startup, 74 driving, 18 catalog and 22 menu checks; APK exported. `-Action InstallAndroid` succeeded on attached DN2103. No phone driving or profiling performed. Build-tools fallback remains. `git diff --check` passed for implementation/report.
