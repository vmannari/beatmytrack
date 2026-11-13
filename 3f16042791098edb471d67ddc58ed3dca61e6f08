# Super rally: restrained body contours and finish (2026-11-09)

The owner reports exaggerated bonnet humps and a comic-book appearance in the actual Garage. **SRR01–SRR03** refine the existing C3-inspired coupe while preserving its identity and driving tune.

- **SRR01 — Shape:** lower, broader fender shoulders blend into a flatter stock bonnet. Front/rear shoulder coefficients change from 0.24/0.20 m to 0.095/0.11 m; their longitudinal and transverse falloffs are broader. The stock centre rise falls from 35 to 9 mm. A slightly fuller waist, narrower axle shoulders and less pointed nose reduce the exaggerated hourglass silhouette. The rear sail tip follows the revised deck. Nose corners remain joined to the side panels.
- **SRR02 — Finish:** a Super-rally-only paint helper raises roughness from 0.38 to 0.49, reduces metallic/specular response and lowers clearcoat from 0.22 to 0.10. Darker, slightly rougher glazing reduces the flat blue contrast. Existing saved colours, liveries and part selections are preserved. Shared `CompactFinish` and other cars are unchanged.
- **SRR03 — Integration:** both model tiers and all retained kits inherit the updated body/finish. Prepared models and native Garage/catalogue/menu/header/news pictures refresh through the existing guarded pipeline. Physics, wheel contacts, race camera, entitlements and backend contracts are unchanged.

All authored production changes are in [super_rally_model.gd](../game/vehicle/super_rally_model.gd). Its [source-only patch](evidence/super-rally-restraint-2026-11-09/source-only.patch) passes `git apply --check --reverse`; [22 task-start source/resource controls](evidence/super-rally-restraint-2026-11-09/source-receipt.json) remain byte-exact. The checkpoint excludes binaries, generated metadata, documentation and unrelated work. No staging or commit was performed.

## Native comparisons

| View | Before | Final |
| --- | --- | --- |
| Front | [Capture](evidence/super-rally-restraint-2026-11-09/before/gl_compatibility/front.png) | [Capture](evidence/super-rally-restraint-2026-11-09/final/gl_compatibility/front.png) |
| Side | [Capture](evidence/super-rally-restraint-2026-11-09/before/gl_compatibility/side.png) | [Capture](evidence/super-rally-restraint-2026-11-09/final/gl_compatibility/side.png) |
| Rear | [Capture](evidence/super-rally-restraint-2026-11-09/before/gl_compatibility/rear.png) | [Capture](evidence/super-rally-restraint-2026-11-09/final/gl_compatibility/rear.png) |
| Overhead | [Capture](evidence/super-rally-restraint-2026-11-09/before/gl_compatibility/overhead.png) | [Capture](evidence/super-rally-restraint-2026-11-09/final/gl_compatibility/overhead.png) |

Final actual App views: [Compatibility Garage](evidence/super-rally-restraint-2026-11-09/app/gl_compatibility/garage.png), [desktop Mobile Garage](evidence/super-rally-restraint-2026-11-09/app/mobile/garage.png), [Compatibility race](evidence/super-rally-restraint-2026-11-09/app/gl_compatibility/race.png) and [desktop Mobile race](evidence/super-rally-restraint-2026-11-09/app/mobile/race.png).

The review harness disables prepared caches and uses the same camera, lighting and paint for before/after. Normal Rally appears beside Super rally as a control.

## Actual checks

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. [Receipts and logs](evidence/super-rally-restraint-2026-11-09/) use a private task profile and empty backend URL.

| Check | Result |
| --- | --- |
| Existing geometry, normal Rally construction, kit/reset, ownership and catalogue controls | 27 checks, 0 failures |
| All 78 fitted choices, both quality tiers, wheel contacts, lamps and stock reset | 316/0 |
| Washing and independent condition | 1,655/0 |
| Driving | 72/0 |
| Every prepared Super rally part versus source, ghosts, materials and weathering | 1,486/0 |
| Production script compilation | 554 scripts, 0 failures |
| Normal Rally native pixels, four identical-camera views | Exact |
| Complete prepared-asset validator | 551 resources / 2,267 checks / 0 failures |
| Original catalogue provenance check | 6 native pictures / 157 source hashes |
| Unrelated production pictures | 20 PNGs byte-exact |
| Final native-picture import | Exit 0 / zero script errors |
| Actual App selection, save/reload, Garage and local race setup | 13/0 each desktop renderer |

The coherent refresh records [368 stable source inputs](evidence/super-rally-restraint-2026-11-09/assets-source-receipt.json), with zero changes during generation and exact per-car fingerprints across the bake. [All command receipts](evidence/super-rally-restraint-2026-11-09/assets-commands.json), the original [prepared validator](evidence/super-rally-restraint-2026-11-09/assets-prepared.log) and [picture checker](evidence/super-rally-restraint-2026-11-09/assets-picture-preflight.log) pass. Other cars' menu/news/header/catalogue [picture controls](evidence/super-rally-restraint-2026-11-09/unrelated-picture-controls.json) remain exact.

Stock geometry stays at 62,484 triangles full / 18,760 reduced. The new pre-scale envelope is 2.010 × 1.311 × 4.884 m; wheel contacts and physical dimensions are unchanged.

Representative commands:

```powershell
python docs/evidence/super-rally-restraint-2026-11-09/run_check.py geometry res://../docs/evidence/super-rally-restraint-2026-11-09/design_check.gd --headless
python docs/evidence/super-rally-restraint-2026-11-09/run_check.py fitted res://tests/test_super_rally_c3_kits.gd --headless
python docs/evidence/super-rally-restraint-2026-11-09/assets.py
python docs/evidence/super-rally-restraint-2026-11-09/final_import.py
python docs/evidence/super-rally-restraint-2026-11-09/run_check.py modules res://tests/test_modular_car_assets.gd --headless -- --vehicle=super_rally --all-kits
python docs/evidence/super-rally-restraint-2026-11-09/run_check.py app-gl res://tests/test_super_rally_ui.gd --rendering-method gl_compatibility -- --evidence-root=res://../docs/evidence/super-rally-restraint-2026-11-09/app
python docs/evidence/super-rally-restraint-2026-11-09/run_check.py app-mobile res://tests/test_super_rally_ui.gd --rendering-method mobile -- --evidence-root=res://../docs/evidence/super-rally-restraint-2026-11-09/app
```

## Findings and limits

An initial nose-rounding draft moved the hood corner ahead of the side panel and exposed a small corner gap. Its `after` captures remain retained; the final front-edge profile keeps the side-panel junction at z = −2.48 m. No assertion was weakened. Sandbox certificate-store diagnostics remain in raw engine logs.

No device query/test, APK export/install, owner-save/process change, live/backend request, deployment or main-index write was performed. PC reload and owner appearance acceptance remain; device appearance/performance are unqualified. This is a cosmetic refinement, with the 198 km/h Rally-based tune preserved.
