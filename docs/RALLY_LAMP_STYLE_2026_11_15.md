# Rally lamp style restored toward the earlier reflector design (2026-11-15)

The owner prefers the earlier lamp style over the opaque prismatic revision. The lamps again show clear fluted glass over a recessed silver reflector, a small bright bulb cap and a dark central shade. The smoother circular gasket/bezel profiles remain, and the grille refinement is preserved.

**RLS01 — Restore the preferred visual character.** `compact_front_lamps.gd` uses the original unchanged transparent headlamp shader and reflective finishes. A compact two-band reflector, visible bulb cap and round stamped shade restore the earlier depth and highlights. Hidden cap backs and shade returns are omitted behind the opaque reflector dish. The outer duplicate optical baffle is not reinstated. The newer opaque shader remains an unused historical asset, without a source change. No bitmap or new light is added.

| Racing geometry | Earlier lamps + original grille | Opaque revision at task start | Restored reflector style |
|---|---:|---:|---:|
| Both lamps | 1,384 | 960 | 1,312 |
| Grille | 1,254 | 886 | 886 |
| Front assembly | 2,638 | 1,846 | 2,198 |
| Entire stock Rally | 16,653 | 15,861 | 16,213 |

The preferred reflector appearance adds **352 stock triangles** versus the opaque revision, while the front remains **440 triangles smaller than before refinement**. The stock model remains approximately **15.00% below the restored 19,074-triangle baseline**. The equipped sample is 24,010 triangles and the full-quality stock model 100,356. Appearance feedback takes precedence over minimising the count of the rejected revision.

**RLS02 — Preserve the grille, fit and prior savings.** Lamp centres/radius and the existing night light remain. The grille source and both shader sources are byte-exact to task start. Two new complete-frame recipes copy every non-lamp member row exactly, including the unchanged grille, so the lamp source changes do not discard the previous body/detail reductions. All Rally kits are exercised during migration. Other stock/full master GPU signatures, articulation and shadow controls are checked separately.

**RLS03 — Qualify the actual renderers and consumers.** Detached task-start snapshots preserve the complete original root transform and GPU streams before authoring. Paired native stock/fitted daylight and night views require equal root transforms, stable references and exact baseline restoration. The retained grille/fit/winding/closure/weathering/night assertions use explicit full/simple models and readiness waits. Actual Garage/race and icon capture/cancellation/reuse are checked in both desktop renderers. No prior assertions are weakened.

The existing conservative `compact_*.gd` dependency rule also invalidates the unchanged Challenger consumer when this Rally builder changes. Its derived caches are regenerated without model-source authoring, and its stock/full master GPU signatures remain exact. Seven other car keys remain unchanged; no dependency routing is modified.

**RLS04 — Refresh and retain a reversible source checkpoint.** Only the lamp builder and two new frame recipes are authored in production. Derived bases, fitted kits, Garage/header resources, scoped catalogue pictures and imports are refreshed against stable source/key fences. A private source-only Git checkpoint preserves the current surrounding documentation and shared main index; derived outputs must be rebuilt after a reversal. Candidate-only captures/profiles stay under disposable build retention.

[Three-way style comparison](evidence/rally-lamp-style-2026-11-15/lamp-style-comparison.png): earlier lamps, rejected opaque revision, restored reflector style. The earlier-style reference comes from the previous task's corrected matched-transform views. This task's before/after captures use exact task-start detached snapshots, so the grille/body comparison remains matched.

The restored style increases stock encoded mesh buffers from 574,798 to 584,470 bytes and surfaces from 50 to 52. Full buffers increase 3,133,702 to 3,145,666 bytes. Front studio primitives rise 19,903 to 20,255 and stock draws 62 to 64 in Compatibility; the corresponding original pre-refinement view was 20,695 primitives and 64 draws. Transparency and the two reflector/shade finishes are deliberate appearance costs. The opaque revision's lower cost is not claimed for the restored style. [Measured geometry and every native view](evidence/rally-lamp-style-2026-11-15/measurements.json) retain the practical limits.

| Validation | Actual result |
|---|---:|
| Source budget and exact non-lamp recipe migration | 6 / 0 |
| Prepared hits/budgets and ten unchanged other stock/full masters | 30 / 0 |
| Retained grille/fit/geometry/weathering/night assertions | 274 / 0 |
| Every Rally kit / shared unchanged Challenger consumer kit | 1,441 / 0 + 1,436 / 0 |
| Matched daylight, 24 pairs per desktop renderer | 101 / 0 each |
| Matched night optics, 8 pairs per desktop renderer | 37 / 0 each |
| Actual Rally Garage/race and complete canonical tune | 8 / 0 each renderer |
| Five-car icon appearance/capture/cancellation/reuse | 496 / 0 each renderer |
| Driving / production parser | 72 / 0; 577 scripts / 0 failures |
| Final full prepared preflight | 551 resources; 2,267 checks / 0 failures |
| Catalogue / native imports | 6 pictures, 174 source hashes; 3 verified imports, 0 editor diagnostics |
| Consumed-input fence | 18,700 stable inputs; seven other car keys exact |

Representative actual commands (engine arguments, renderers and isolated paths are retained in per-command receipts):

```powershell
python scripts/create_rally_lamp_style_tools.py
python scripts/start_rally_lamp_style.py
python scripts/run_rally_lamp_style.py baseline res://tests/survey_rally_lamp_style.gd --headless
python scripts/run_rally_lamp_style.py recipe-migration-final res://tests/stage_rally_lamp_style.gd --headless
python scripts/run_rally_lamp_style.py source-models res://tests/test_rally_lamp_style.gd --headless
python scripts/refresh_rally_lamp_style.py
python scripts/run_rally_lamp_style.py prepared-models res://tests/test_rally_lamp_style.gd --headless -- --prepared
python scripts/qualify_rally_lamp_style.py
python scripts/artwork_rally_lamp_style.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compare_rally_lamp_style.ps1
python scripts/measure_rally_lamp_style.py
python scripts/record_rally_lamp_style.py
python scripts/close_rally_lamp_style.py
python scripts/checkpoint_rally_lamp_style.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

[Frame migration](evidence/rally-lamp-style-2026-11-15/recipe-migration.json), [publication](evidence/rally-lamp-style-2026-11-15/publication.json), [closure](evidence/rally-lamp-style-2026-11-15/closure.json), [source checkpoint](evidence/rally-lamp-style-2026-11-15/source-checkpoint.json) and [review patch](evidence/rally-lamp-style-2026-11-15/source.patch) record exact scope. Derived outputs need rebuilding after reversal. The standard retention receipt is in `build-retention.log`; source-preview drafts remain disposable.

No physical-device testing, FPS/GPU-time claim, export, backend request, deployment or owner-save/process action is included. Reload and owner appearance review remain.
