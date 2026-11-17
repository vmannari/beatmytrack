# Kart kit changes preserve the paint projection

The owner reported that Kart paint looked different during kit changes and changed again when the transition completed. KPT01 fixes the temporary material copy; KPT02 checks rendered endpoints and every Kart kit option; KPT03 checks interrupted changes and natural completion.

## Cause and change

`game/ui/garage_kit_transition.gd` duplicated each ShaderMaterial before assigning the sweep shader. On the pinned Godot build, that duplication resets matrix-valued shader parameters. A focused probe set `mesh_to_body` to a translated frame: the old path returned null for both the source and the copy immediately afterward. The rendered side-pod pattern consequently used a different projection during the effect. This is especially visible on the Kart's laterally offset side pods. The selected livery dictionary did not change.

The helper now snapshots all shader uniforms, creates a fresh ShaderMaterial, and assigns those values explicitly. The original material and its paint frame stay intact. Existing sweep timing, clipping, render priority, recursive next passes and StandardMaterial conversion remain in place. Only this one runtime source changes.

The new `game/tests/test_kart_kit_paint_transition.gd` checks a translated/rotated matrix independently, original-material preservation and independent uniform storage. It exercises all 30 non-stock Kart options and returns to stock with plain custom colours, a pattern/sticker, dirt/wetness and a premium mural. Sixteen rendered cases compare the previous model with progress zero and progress one with the restored model. The existing 12-pixel maximum remains unchanged; sampling uses every second pixel and an RGB-distance threshold of 0.04. Premium keeps the preceding wet condition, also exercising that combination. Interrupted selection is followed through natural completion.

## Actual results

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. Final runs used separate task-local APPDATA/LOCALAPPDATA directories, disabled music, and an empty API URL. No player records are loaded by the new showroom fixture.

| Check | Checks / failures |
| --- | --- |
| Original native reproduction, Compatibility | 193 / 4 |
| Final focused headless, every Kart option | 678 / 0 |
| Final focused Compatibility | 790 / 0 |
| Final focused desktop Mobile/Vulkan | 790 / 0 |
| Existing Garage kit suite, headless | 2416 / 0 |
| Existing Garage kit suite, Compatibility | 2452 / 0 |
| Existing Garage kit suite, desktop Mobile | 2452 / 0 |
| Exportable production parser | 583 scripts / 0 failures |

Original patterned side pods differ by 416 sampled pixels at the start and 377 at the end; weathered pods differ by 405 and 368. Final Compatibility maxima across all sixteen cases are 3 at the start and 1 at the end. Final Mobile maxima are zero at both ends. The final endpoint pictures were visually inspected.

Retained examples: [original transition endpoint](evidence/kart-kit-paint-2026-11-17/original-gl_compatibility/stripes-body-end.png), [original completed model](evidence/kart-kit-paint-2026-11-17/original-gl_compatibility/stripes-body-finished.png), [fixed transition endpoint](evidence/kart-kit-paint-2026-11-17/final-gl_compatibility/stripes-body-end.png), [fixed completed model](evidence/kart-kit-paint-2026-11-17/final-gl_compatibility/stripes-body-finished.png). All case metrics and run logs are under [evidence](evidence/kart-kit-paint-2026-11-17/).

The initial headless fixture used an invalid pattern identifier and failed eight coverage assertions; the fixture was corrected to the existing `apex_twin` pattern and `crest` sticker. Explicit uniform upload after duplication and an alternate fragment-height calculation each retained the four native failures and were rejected. They are not part of the fix. One earlier fresh-material run passed 194 checks before adding premium/all-option/matrix coverage. The first existing-suite invocation supplied a resource URI to an older fixture expecting an absolute directory; it reached the final report write, failed there and its owned test process was stopped. The repeat uses an absolute evidence path and passes. These logs/reports remain retained; no product assertion was relaxed.

## Commands and checkpoint

Initial repository entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_kart_kit_paint_transition.gd -TestArgument '--evidence-root=res://../docs/evidence/kart-kit-paint-2026-11-17/original-headless' -CommandTimeoutSeconds 180
```

Subsequent runs used the same pinned executable, through an isolated-profile runner. The retained runner can be invoked from the repository root:

```powershell
python docs/evidence/kart-kit-paint-2026-11-17/run.py final-headless headless res://tests/test_kart_kit_paint_transition.gd
python docs/evidence/kart-kit-paint-2026-11-17/run.py final-gl_compatibility gl_compatibility res://tests/test_kart_kit_paint_transition.gd
python docs/evidence/kart-kit-paint-2026-11-17/run.py final-mobile mobile res://tests/test_kart_kit_paint_transition.gd
python docs/evidence/kart-kit-paint-2026-11-17/run.py retained-headless-fixed-path headless res://tests/test_garage_kit_transition.gd
python docs/evidence/kart-kit-paint-2026-11-17/run.py retained-gl_compatibility gl_compatibility res://tests/test_garage_kit_transition.gd
python docs/evidence/kart-kit-paint-2026-11-17/run.py retained-mobile mobile res://tests/test_garage_kit_transition.gd
python docs/evidence/kart-kit-paint-2026-11-17/run.py final-parser headless res://tests/test_editor_shipping_parse.gd
git diff --check -- game/ui/garage_kit_transition.gd game/tests/test_kart_kit_paint_transition.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

The first focused final runs and retained headless/Compatibility runs used the same runner under `build/kart-kit-paint/run.py`; retained Mobile and the final parser used the durable evidence copy above. The receipt and reversible source patch record the exact task delta. The private Git checkpoint preserves the task-start runtime bytes and preceding documentation, with forward/reverse byte verification and no shared-index staging. Intermediate duplicate screenshots and temporary probes were removed; standard build retention applies.

Reload the game to load the corrected transition helper. Owner appearance review and physical-device acceptance remain. Desktop Mobile is a renderer test; no physical-device test was performed. No export, deployment, live-service operation, owner-save edit or owner-process restart was performed. Other existing workspace changes and generated build metadata are outside this patch.
