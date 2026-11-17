"""VHO01-VHO03: reference-guided stock bonnet seam, measured and reviewable."""
import json,re
from run_volt_hood_outline import ROOT,OUT
MARKER='VOLT-HOOD-OUTLINE-20261116'
REPORT='docs/VOLT_HOOD_OUTLINE_2026_11_16.md'
closure=json.loads((OUT/'closure.json').read_text(encoding='utf-8'))
geometry=json.loads((OUT/'geometry.json').read_text(encoding='utf-8'))
table='| Check | Actual outcome |\n|---|---|\n'
for label in closure['qualified_receipts']:
    receipt=json.loads((OUT/(label+'-receipt.json')).read_text(encoding='utf-8'));assert receipt['exit_code']==0 and not receipt['errors']
    lines=(OUT/(label+'.log')).read_text(encoding='utf-8',errors='replace').splitlines()
    useful=[line for line in lines if re.search(r'(checks|resources;|scripts,|VHO_NATIVE|VOLT_HOOD_MESH_BAKE)',line)]
    table+=f"| {label} | {useful[-1] if useful else 'Clean run; exact arguments in receipt'} |\n"
text=f'''# Volt bonnet shut lines follow the new reference (2026-11-16)

The stock bonnet now has long straight side edges, a small taper toward the nose, straight front/rear edges and short rounded corners. The owner-provided purple fastback reference guides the practical panel outline. [Matched top and three-quarter comparison](evidence/volt-hood-outline-2026-11-16/hood-outline-comparison.png).

**VHO01 — Shape a practical panel opening.** A closed trapezoid in physical X/Z coordinates replaces the constant-UV perimeter that bowed outward along the sides and curved broadly across the nose. Its front half-width is 0.65 m, rear half-width 0.72 m, front Z=-2.15 m and rear Z=-1.055 m before the existing whole-car scale. Four 25 mm corner transitions keep the long pressed edges straight while avoiding sharp line ends. The existing fitted-contour sampler projects the outline onto the actual bonnet surface with its original 2.2 mm width and 0.8 mm lift. Native point/ray checks retain complete coverage and the original 0.35–1.50 mm exposure bounds.

The measured old side bow is **61.586 mm**, versus less than **0.00005 mm** on the new rendered straight runs. The old builder is retained as a genuine rejected straightness control. Both qualities still use **384 contour triangles**. The bonnet surface, normals, body shape, windshield and other seams remain unchanged.

**VHO02 — Preserve model quality and modular parts.** Four new exact-frame recipes retain every previous detail/surface reduction row and prove all non-bonnet-line raw and post-detail members identical. Stock/equipped/full masters remain **21,309 / 27,033 / 114,648 triangles**. Prepared consumers restore actual bases and all four selected modules; all non-contour GPU streams and transforms match the detached task-start snapshots exactly. The existing alternative bonnet designs keep their authored seams. Their 62-mesh source-guarded bank is actually regenerated after the body source change; all 62 array hashes remain exact to the previous manifest and read back identically. The bank remains 2,338,026 bytes.

The authored source scope is six files: `electric_reference_body.gd`, four new Electric frame JSONs and the rebaked alternative-hood bank manifest. [Exact bindings and source hashes](evidence/volt-hood-outline-2026-11-16/publication.json). Challenger and other-car model sources, handling, paint/livery programs and production cameras are not authored.

**VHO03 — Validate receiving models and refresh pictures.** Actual Garage top/bonnet-top/front/three-quarter captures cover both model qualities on Compatibility and desktop Mobile, sixteen images per renderer. The receiving App checks Garage/race geometry and canonical configuration. All 120 Electric kit scenes, four bases and Garage model are rebuilt; scoped preflight covers 125 resources/511 assertions. The final consumed-source fence is stable across **{closure['consumed_inputs']:,} inputs**.

{table}
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
'''
(ROOT/REPORT).write_bytes(text.encode('utf-8'))
summary=f'''VHO01-VHO03: physical straight tapered bonnet outline with 25mm corners replaces bowed constant-UV edges, following the owner reference. Actual fitted sides61.586mmto<0.00005mm bow; same384tri contour, existing surface/paint/windshield preserved. Geometry4690/0 and prepared10/0; all other frame members/rows and non-contour GPU/transforms exact. Stock21309/fitted27033/full114648 unchanged. Sixty-two optional-hood arrays exact after actual2338026-byte bank rebuild. Four exact frame migrations, complete125-resource511/0, desktop App8/0 each,16 native images each, parser581/0 and final{closure['consumed_inputs']}-input fence pass. Actual pictures/imports refreshed; initial probe/camera/typed-fixture and concurrent identity rejection retained without weaker assertions. Six-source scope, exact source checkpoint and standard retention preserve concurrent work/index; no Challenger/other-car model or handling authoring. [Changes, comparison, commands and limits]({REPORT}). Reload/owner review remains; no phone/FPS/export/backend/deployment/owner-save/process or shared-index action.'''
block=('<!-- '+MARKER+' -->\n## Volt bonnet shut lines follow a straighter practical outline (2026-11-16)\n'+summary+'\n<!-- /'+MARKER+' -->\n\n').encode('utf-8')
for name in ('AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md'):
    path=ROOT/name;pattern=('<!-- '+MARKER+r' -->\r?\n.*?<!-- /'+MARKER+r' -->\r?\n(?:\r?\n)?').encode()
    path.write_bytes(block+re.sub(pattern,b'',path.read_bytes(),flags=re.S))
print('VHO_DOCUMENTATION reference change, measured validation and three trackers')
