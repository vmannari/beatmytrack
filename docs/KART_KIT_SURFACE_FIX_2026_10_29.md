# Kart kit holes and surface glitches, 2026-10-29

The reported defects were reproduced in the actual Garage and in the native mesh buffers. The fix closes the nose/fairing/pod ends, seals tube ends and bumper-loop seams, corrects mirrored wheel faces, and fits headlamps outside the newly sealed noses.

| Requirement | Defect and correction |
| --- | --- |
| KSF01 | Panel cap vertices were appended to an already indexed stream without indices, so they never became visible triangles. Caps now append as indexed surfaces, with matching shared-edge coordinates. |
| KSF02 | Kit tubes had open ends; closed loops used incompatible endpoint frames and abrupt axis changes. A kit-specific tube builder adds end caps, periodic closed paths and continuously transported frames. The cross-brace frame uses a supported rounded loop. |
| KSF03 | Mirroring the disc/deep-dish axial profiles reversed their exterior winding. Profiles now normalize their orientation before generating the surface. |
| KSF04 | Some original fixed lamps lay inside the sealed custom noses. Lamp housings now belong to the nose assembly and seat on its actual outer surface; Original retains the exact factory geometry. |
| R01 / Q01 | Saved choices, kit selection, paint/wash, actual race/ghost construction, original stock geometry and native asset reuse remain covered by regression checks. |

Four runtime files change: `kart_kit_shapes.gd`, `kart_kits.gd`, `kart_detail.gd` and `kart_model.gd`. Two new owned utilities audit surfaces and capture opposite-side close views, each with a native UID. Catalogue IDs, save schema, prices and canonical handling are unaffected. New geometry keys prevent loading the defective historical assets. The baker adds 230 corrected immutable meshes, bringing the manifest to 1,136; all 906 task-start mesh files remain SHA256-exact. Six prepared Garage templates refresh successfully. No historical asset is overwritten or deleted.

## Reproduction and final checks

The first audit found defects in all 56 non-stock category/detail cases. Its final version independently rejects **42 historical open panel meshes and four inward-facing mirrored wheel meshes** directly from the preserved native resources. Thus the final audit also demonstrates that the old assets are defective.

Final inspection expands the actual vertex/index arrays, welds shared positions on an integer one-micrometre grid, checks boundary-edge use and orientation, and requires outward signed volume. Fitted colour/keyline overlays are excluded from solid-closure checks. It also compares full raw/production triangle counts and checks that both headlamp lenses are visible from outside each sealed nose.

| Actual check | Result |
| --- | --- |
| Baked surface, batching and lamp audit | 126 checks, 0 failures, all 28 alternatives at both detail levels |
| Historical defective-mesh control | 2 checks, 0 failures; rejects 42 open panels and 4 inward wheel meshes |
| Existing shape/tyre-sweep regression, final sources | 336 checks, 0 failures; minimum clearance 25.921 mm |
| Actual Garage workflow, Compatibility | 984 checks, 0 failures; 38 screenshots |
| Same workflow, desktop Mobile/Vulkan | 984 checks, 0 failures; 38 screenshots |
| Opposite-side close views | 56 final native views per desktop renderer, plus 56 matched original Compatibility views |
| Original stock arrays/transforms | 4 checks, 0 failures |
| Existing kart model/construction | 62 / 32 checks, 0 failures; stock 87,136 full / 30,292 simple triangles |
| Actual-App saved appearance recovery | 70 checks, 0 failures, all six active cars |
| Preferred shape-script dependency check | Passed |
| Source-only review patch | 8 files; live reverse check, isolated forward application/content comparison and isolated reverse check passed |

The final workflow maximum is 94,880 sampled triangles, below the existing 120,000 ceiling. Additional cap faces and fitted lamp frames have a cost; no device frame-rate, thermal or hitch-free claim is made. The 4,096 combined appearances were not individually rendered.

Matched native evidence: [original open bumper seam](evidence/kart-kit-surface-fix-2026-10-29/before-native/aero-cage-left.png), [corrected bumper](evidence/kart-kit-surface-fix-2026-10-29/final-compatibility-close/aero-cage-left.png), [original open nose end](evidence/kart-kit-surface-fix-2026-10-29/before-native/hood-sprint-left.png), [sealed nose with fitted lights](evidence/kart-kit-surface-fix-2026-10-29/final-compatibility-close/hood-sprint-left.png), [corrected pod](evidence/kart-kit-surface-fix-2026-10-29/final-mobile-close/body-box-right.png). The close-view folders cover every alternative from both sides. Final workflow folders also cover actual touch, scrolling, equip/save/reload, failed-save rollback, cancellation, reset, car switching, race/ghost appearance, three sizes and Finnish/German presentation.

## Actual commands and retained findings

Pinned Godot: `4.7.2.stable.official.ed1daf0bf`. Tests use disposable project-local data and an offline backend:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/kart-kit-surface-fix/local/appdata'
$env:LOCALAPPDATA = Join-Path (Get-Location) 'build/kart-kit-surface-fix/local/localappdata'
$env:BMT_API_URL = ''
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_kit_surfaces.gd -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath 'res://tests/test_kart_kit_surfaces.gd' -TestArgument @('--historical','--evidence-root=res://../docs/evidence/kart-kit-surface-fix-2026-10-29/before-historical') -CommandTimeoutSeconds 240"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_kart_kits.gd -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_garage_cars.gd -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_kart_kit_surface_orbit.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/kart-kit-surface-fix-2026-10-29/final-compatibility-close' -CommandTimeoutSeconds 420
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_kits.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/kart-kit-surface-fix-2026-10-29/final-compatibility-workflow' -CommandTimeoutSeconds 600
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_kit_variety.gd -TestArgument '--evidence-root=res://../docs/evidence/kart-kit-surface-fix-2026-10-29/final-fit' -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_kart_kit_surface_orbit.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--evidence-root=res://../docs/evidence/kart-kit-surface-fix-2026-10-29/final-mobile-close' -CommandTimeoutSeconds 420
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_kits.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--evidence-root=res://../docs/evidence/kart-kit-surface-fix-2026-10-29/final-mobile-workflow' -CommandTimeoutSeconds 600
# Retained TestScript checks: test_kart_kit_stock_control.gd,
# test_kart_model.gd, test_kart_construction.gd,
# test_garage_appearance_recovery.gd.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://vehicle/kart_kit_shapes.gd -CommandTimeoutSeconds 180
git apply --reverse --check docs/evidence/kart-kit-surface-fix-2026-10-29/source-only.patch
```

The initial sandboxed engine attempt failed to read the Windows certificate store; the isolated host-access run passed. A direct script invocation also hit execution policy and was corrected to use the prescribed launcher. Intermediate audit runs reported three tiny false edge defects because the triangle-mesh convenience path rounded fine bevel coordinates; the final audit reads the raw indexed buffers and uses integer edge keys. Earlier endpoint precision corrections remain. The final historical control still rejects the actual original defects. A temporary engine UID-generation helper was removed after assigning the two utility UIDs.

Intermediate captures without fitted lamps and all initial findings are retained separately. Final evidence uses `final-*` folders. Exact hashes, selected logs, raw reports and the checked patch are linked from [the report](evidence/kart-kit-surface-fix-2026-10-29/report.json). Concurrent changes and generated current build identities are preserved; refreshed templates can contain concurrent model authorship, so this is not a whole-tree freeze.

Reload/rebuild and owner visual acceptance remain. No physical-device query/test, APK export/install, real auth/purchase, owner-save/live/backend mutation, deployment, owner-process restart or main-index staging/commit/merge was performed. No clean full-project parser or device-performance pass is claimed.
