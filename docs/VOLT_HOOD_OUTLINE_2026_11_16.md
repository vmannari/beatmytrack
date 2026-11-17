# Volt bonnet shut lines follow the new reference (2026-11-16)

The stock bonnet now has long straight side edges, a small taper toward the nose, straight front/rear edges and short rounded corners. The owner-provided purple fastback reference guides the practical panel outline. [Matched top and three-quarter comparison](evidence/volt-hood-outline-2026-11-16/hood-outline-comparison.png).

**VHO01 — Shape a practical panel opening.** A closed trapezoid in physical X/Z coordinates replaces the constant-UV perimeter that bowed outward along the sides and curved broadly across the nose. Its front half-width is 0.65 m, rear half-width 0.72 m, front Z=-2.15 m and rear Z=-1.055 m before the existing whole-car scale. Four 25 mm corner transitions keep the long pressed edges straight while avoiding sharp line ends. The existing fitted-contour sampler projects the outline onto the actual bonnet surface with its original 2.2 mm width and 0.8 mm lift. Native point/ray checks retain complete coverage and the original 0.35–1.50 mm exposure bounds.

The measured old side bow is **61.586 mm**, versus less than **0.00005 mm** on the new rendered straight runs. The old builder is retained as a genuine rejected straightness control. Both qualities still use **384 contour triangles**. The bonnet surface, normals, body shape, windshield and other seams remain unchanged.

**VHO02 — Preserve model quality and modular parts.** Four new exact-frame recipes retain every previous detail/surface reduction row and prove all non-bonnet-line raw and post-detail members identical. Stock/equipped/full masters remain **21,309 / 27,033 / 114,648 triangles**. Prepared consumers restore actual bases and all four selected modules; all non-contour GPU streams and transforms match the detached task-start snapshots exactly. The existing alternative bonnet designs keep their authored seams. Their 62-mesh source-guarded bank is actually regenerated after the body source change; all 62 array hashes remain exact to the previous manifest and read back identically. The bank remains 2,338,026 bytes.

The authored source scope is six files: `electric_reference_body.gd`, four new Electric frame JSONs and the rebaked alternative-hood bank manifest. [Exact bindings and source hashes](evidence/volt-hood-outline-2026-11-16/publication.json). Challenger and other-car model sources, handling, paint/livery programs and production cameras are not authored.

**VHO03 — Validate receiving models and refresh pictures.** Actual Garage top/bonnet-top/front/three-quarter captures cover both model qualities on Compatibility and desktop Mobile, sixteen images per renderer. The receiving App checks Garage/race geometry and canonical configuration. All 120 Electric kit scenes, four bases and Garage model are rebuilt; scoped preflight covers 125 resources/511 assertions. The final consumed-source fence is stable across **20,001 inputs**.

| Check | Actual outcome |
|---|---|
| geometry | VHO_GEOMETRY 4690 checks, 0 failures; old side bow=0.06158610325829 |
| hood-bank | VOLT_HOOD_MESH_BAKE: 62 meshes, 2338026 bytes |
| prepared-consumers | VHO_PREPARED 10 checks, 0 failures |
| prepared-final | PREPARED_ASSETS 125 resources; 511 checks, 0 failures |
| app-gl | CAR_SIMPLIFICATION_APP 8 checks, 0 failures |
| app-mobile | CAR_SIMPLIFICATION_APP 8 checks, 0 failures |
| native-preview-fixed | VHO_NATIVE_CAPTURES 16 images; matched camera, paint and Garage |
| native-mobile | VHO_NATIVE_CAPTURES 16 images; matched camera, paint and Garage |
| parser | PRODUCTION_PARSE 581 scripts, 0 failures |

Volt catalogue/header images and the existing globally versioned six-car selection-portrait set are genuinely rendered again; these are derived pictures, not other-car model authoring. Eight image imports are verified with exact project settings. The first portrait attempt rejected a concurrent generated build-identity change before publication; the later actual bake and validator pass. No source metadata is restamped to bypass rejection.

Initial fixture findings are retained: the bonnet line has no native prebuilt file, so the first inventory probe incorrectly tried to load a nonexistent file; the corrected probe uses the actual builder. The first direct top camera was above the room ceiling and was moved below it, with the display stage aligned to the same axis for both models. A prepared-consumer fixture initially duplicated an inherited output constant, then passed a detached Node3D to a CarVisual-only inventory helper; distinct names and the recorded task-start counts correct those harness errors. No geometry, fit or receiving assertion is relaxed.

Representative actual commands; receipts retain full arguments and diagnostics:

```powershell
python scripts/run_volt_hood_outline.py register-before res://tests/register_volt_hood_outline.gd --headless
python scripts/run_volt_hood_outline.py migrate res://tests/migrate_volt_hood_outline.gd --headless
python scripts/run_volt_hood_outline.py hood-bank res://tests/bake_volt_hood_meshes.gd --headless
python scripts/run_volt_hood_outline.py geometry res://tests/test_volt_hood_outline.gd --headless
python scripts/refresh_volt_hood_outline.py
python scripts/artwork_volt_hood_outline.py
python scripts/run_volt_hood_outline.py prepared-consumers res://tests/test_volt_hood_outline_consumers.gd --headless
python scripts/close_volt_hood_outline.py
python scripts/checkpoint_volt_hood_outline.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

[Closure](evidence/volt-hood-outline-2026-11-16/closure.json), [source-only patch](evidence/volt-hood-outline-2026-11-16/source.patch) and [checkpoint receipt](evidence/volt-hood-outline-2026-11-16/source-checkpoint.json) record a byte-exact forward/reverse checkpoint without shared-index staging. Reversal needs a derived-cache rebuild. Standard retention runs without a task pin. No physical-device test, FPS qualification, export, backend request, deployment or owner-save/process action is performed. Reload and owner appearance acceptance remain.
