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
