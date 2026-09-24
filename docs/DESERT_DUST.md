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
