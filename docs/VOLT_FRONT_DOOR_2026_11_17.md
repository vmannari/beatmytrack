# Volt front doors extended rearwards

## VFD01

The owner's marked side view guides a longer front door with a straighter trailing edge. The shared B-pillar station moves from 0.472 to 0.522 on the cabin chart. The window divider and body seam now share one longitudinal station from roof to sill. The front handles follow the enlarged doors on both sides. The chosen interpretation moves the window base rearwards by 143.922 mm and the sill intersection by 65.509 mm before the common 0.88 scale. Their displayed world-space distances are approximately 126.651 mm and 57.648 mm.

[Before](evidence/volt-front-door-2026-11-17/views-gl_compatibility/full-other-side-before.png) and [after](evidence/volt-front-door-2026-11-17/views-gl_compatibility/full-other-side-after.png) show the actual native full model from the same camera. Both desktop renderers have twelve matched captures covering both sides, front three-quarter and both model qualities.

## VFD02

Three authored GDScript files define the adjustment. Twenty-eight targeted native meshes carry it into the cached source models. Racing seams and handles are refitted against the actual protected post-detail side triangles with the established exposure bounds. The corresponding four reduced glass meshes retain their preceding triangle topology and UV charts, remapped onto the new native panes with regenerated interpolated normals and tangents. Complete frame migrations retain every unaffected detail and surface reduction row. Native body skins and all other native resource files retain their task-start bytes.

The final racing master has 19,037 visible triangles, compared with 18,867 at task start, an increase of 170 or 0.90%. The full master has 114,644, compared with 114,648. Shadow-only proxy triangles are counted separately. The alternative-hood bank is genuinely rebuilt, and its 62 mesh rows and array hashes remain exact. Its source guard follows the updated body file.

The publication receipt lists the exact source bindings and hashes. The source checkpoint includes reversible forward and reverse checks against private task-start copies. Derived consumers and pictures require rebuilding after reversal. [Publication](evidence/volt-front-door-2026-11-17/publication.json), [source patch](evidence/volt-front-door-2026-11-17/source.patch) and [checkpoint receipt](evidence/volt-front-door-2026-11-17/source-checkpoint.json).

## VFD03

The closure receipt records actual commands, test results and consumed-source checks. [Closure](evidence/volt-front-door-2026-11-17/closure.json).

| Check | Actual result |
|---|---|
| Source geometry, contour exposure, glass topology and surface fit | 45,498 checks, 0 failures |
| Prepared versus direct full/simple, fixed/editable consumers | 12 checks, 0 failures |
| Complete prepared Volt resources | 125 resources, 511 checks, 0 failures |
| All body-kit door and fender boundaries | 540 checks, 0 failures |
| Driving regression | 72 checks, 0 failures |
| Production parser | 583 scripts, 0 failures |
| Actual Garage and race on each desktop renderer | 8 checks, 0 failures each |
| Native matched views | 12 per renderer, 24 total |

Representative actual commands follow. The individual receipts retain full engine arguments and durations.

```powershell
python scripts/run_volt_front_door.py register-before-retry res://tests/register_volt_front_door.gd --headless
python scripts/run_volt_front_door.py native-final-stage res://tests/bake_volt_front_door.gd --headless
python scripts/publish_volt_front_door.py native
python scripts/run_volt_front_door.py migrate-glass res://tests/migrate_volt_front_door.gd --headless
python scripts/publish_volt_front_door.py recipes
python scripts/run_volt_front_door.py geometry-topology res://tests/test_volt_front_door.gd --headless
python scripts/refresh_volt_front_door.py
python scripts/run_volt_front_door.py prepared-consumers-enabled res://tests/test_volt_front_door_prepared.gd --headless
python scripts/run_volt_front_door.py app-gl res://tests/test_volt_front_door_app.gd --rendering-method gl_compatibility
python scripts/run_volt_front_door.py app-mobile res://tests/test_volt_front_door_app.gd --rendering-method mobile
```

Initial harness findings remain in the evidence. The first frame survey assumed the changed glass had no surface-reduction rows. The corrected survey retains those rows for the task-start model, and the final migration remaps their four meshes. A first contour-staging attempt searched for the protected side before applying its static and coarse source identities. The corrected lookup uses the actual post-detail protected mesh. The first glass verification used outward rays at exact boundary vertices and recorded 202 misses. Exact closest-triangle distances now cover those boundary samples under the same 1.8 mm geometric tolerance. The first prepared-consumer harness disabled the cache gate that owns modular restoration, producing four missed-hit findings. Enabling that gate for the prepared case proves actual restoration and exact equality. All intermediate receipts remain available.

The initial picture-import attempts reject a changing generated application version during concurrent Editor checks. Current settings and the equality assertion are retained. The earlier selection-portrait validation subsequently rejects the changed shared presentation revision, requiring an actual new capture.

Reload and owner appearance review remain. Physical-device testing was not performed.
