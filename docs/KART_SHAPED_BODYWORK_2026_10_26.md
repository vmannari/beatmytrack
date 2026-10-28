# More defined kart bodywork — 2026-10-26

KSB01–KSB03 / V02–V05 / R01 / G01 / Q01: the owner finds the front bumper, fuel tanks and related forms too smooth after the hardware finishing pass. This revision changes the underlying shapes.

The front bumper now has a broad face, a flatter crown, clipped corner returns and a defined lower lip. The Nassau panel and both painted side housings have flatter decks, shoulder breaks, tapered sides and small rolled edges. The actual central fuel tank has distinct lower walls, sloping shoulders and a narrower filler area with a flat-topped bevelled cap. The airbox has a flat lid and defined sides. These are original formed meshes; the previous inflated elliptical cross-sections are replaced.

| Requirement | Review |
| --- | --- |
| KSB01: more deliberate bumper and body shapes | [Before](evidence/kart-shaped-bodywork-2026-10-26/before-gl_compatibility/full-front.png), [after](evidence/kart-shaped-bodywork-2026-10-26/model-gl_compatibility/full-front.png), [overhead](evidence/kart-shaped-bodywork-2026-10-26/model-gl_compatibility/full-top.png) |
| KSB02: shaped fuel tank and airbox | [Actual tank inspection cutaway](evidence/kart-shaped-bodywork-2026-10-26/bodywork-view-gl_compatibility/full-fuel-tank-isolated.png), [engine and airbox](evidence/kart-shaped-bodywork-2026-10-26/model-gl_compatibility/full-engine.png) |
| KSB03: fitted production integration | All inlays are clipped to the actual new shell triangles. Pod strips and the airbox seal ray-fit their actual skin. Prepared meshes, body shadow and native pictures are refreshed. Original tyre, steering, body-tilt, driver, seating and handling assertions remain. |

Independent bodywork checks measure actual crown surfaces, fuel-tank shoulder narrowing and closed tank/airbox meshes. The original exact model/detail sources, reloaded only in isolated process memory, fail 10 of the 16 new checks; the reshaped detailed and racing models pass all 16. Existing regression assertions and tolerances are preserved.

Detailed/racing geometry changes from **94,870/31,506 to 87,136/30,292 triangles**, retaining the 95,000 detailed cap. There are 292 active prepared meshes, including 250 byte-identical originals; 38 replaced resources are archived. The body shadow is rebuilt and the four wheel shadows remain exact. The original driver/helmet and canonical configuration are preserved. No new textures, shaders, lights, dependencies or per-frame processing are introduced.

Runtime changes are `kart_model.gd`, `kart_detail.gd` and the new `kart_bodywork.gd`. The existing bake/model checks pin the new authoring-source digest. `test_kart_bodywork.gd` contains the independent checks and an inspection-only tank cutaway; the production tank stays in its normal location. The existing photo recipe adds the bodywork dependency without altering its camera or studio. Catalogue, news, Garage, header and all 49 livery pictures are regenerated only for the kart. The existing Garage-car bake gains an optional vehicle filter and refreshes only `cars_v1/kart.scn`. The native integration test additionally compares actual Garage geometry with a directly built production kart.

Actual commands use pinned Godot 4.7.2 through `scripts/dev.ps1`. User data is isolated under `build/kart-shaped-bodywork`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-shaped-bodywork-2026-10-26/run.ps1 -Job before
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-shaped-bodywork-2026-10-26/run.ps1 -Job draft
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-shaped-bodywork-2026-10-26/run.ps1 -Job bodywork-draft
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-shaped-bodywork-2026-10-26/run.ps1 -Job bodywork-before
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-shaped-bodywork-2026-10-26/pipeline.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-shaped-bodywork-2026-10-26/pipeline.ps1 -ResumePresentation
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-shaped-bodywork-2026-10-26/run.ps1 -Job native -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-shaped-bodywork-2026-10-26/run.ps1 -Job native
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-shaped-bodywork-2026-10-26/run.ps1 -Job header
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-shaped-bodywork-2026-10-26/run.ps1 -Job import
python docs/evidence/kart-shaped-bodywork-2026-10-26/finalize.py
```

The pipeline runs the model and Garage-template bake, bodywork/retained mechanical/driver/construction/fit/proportion tests, native production model/tank cutaway/Garage/race checks, all artwork refreshes, import, handling and parser, then native model/cutaway/Garage/race with desktop Vulkan Mobile. Its first native Garage check exposed an older prepared template referencing retired rounded meshes. That failure is retained in `initial-garage-template-failure.log`; the task then adds the filtered template bake and resumes presentation checks. Later Mobile comparisons initially counted the concurrent progressive Garage's temporary opening copies (174,000 versus 87,136 triangles). The harness now waits for that studio's existing preparation state to finish, then retains exact equality at 87,136. A transient concurrent opening-facade property error is also retained; that source was corrected independently. Final native assertions pass with two ObjectDB shutdown warnings and logged startup hitches; their allocation source is not established by this shape task, and no device/performance claim is made. Per-job arguments, logs, actual outcomes, source hashes and the binary review patch are in [report.json](evidence/kart-shaped-bodywork-2026-10-26/report.json). The patch excludes concurrent shared presentation work and leaves the main Git index untouched.

Reload/rebuild and owner shape acceptance remain. No physical-device attachment check or test, APK, real authentication/purchase, live mutation, deployment, main-index staging, commit, merge or owner-process restart was performed. Desktop Mobile is a desktop Vulkan test; device appearance, motion and performance remain untested.
