# Super rally: complete classic coupe body (2026-11-08)

The owner rejected the initial Rally hatchback with extra body kits and chose a **1970s C3 Stingray direction: curved fenders, long bonnet and low cabin**. This revision replaces the entire exterior with an original procedural coupe. The public car name remains Super rally; no Chevrolet badges, downloaded models or reference photographs are shipped.

## Requirements and delivered behavior

- **SRC301 — Separate body:** its own sculpted nose, curved front/rear fenders, narrow waist, two-door cabin, T-top roof, recessed rear window and integral rear sails. Closed popup headlamp covers, opening illuminated units at night, side gills, slim bumpers, side exhausts, period five-slot wheels and four round tail lamps complete the classic silhouette. The factory body needs no cosmetic purchases.
- **SRC302 — Preserve driving:** the Super rally tune remains `super-rally-1`, with 19,800 N engine force and a 55 m/s / 198 km/h cap. Steering, grip, brakes, handbrake, wheel contacts and collision dimensions retain the approved Rally basis. The 18 canonical/configuration/resource controls are checked against task-start bytes. Normal Rally construction has an exact semantic mesh/transform control in both quality tiers.
- **SRC303 — Keep customization:** all existing hood, aero, rim and body choices now build coupe-specific geometry. Changing or resetting a kit retains the complete coupe core. Existing Rally cosmetic entitlements and prices remain shared, with duplicate legacy ownership entries prevented. Paint, decals, dirt, washing, rolling wheels and brake lamps remain integrated.
- **SRC304 — Show the same car everywhere:** Super rally has its own exterior model/cache identity, prepared fixed/editable bases, fitted modules, Garage model, catalogue, menu, news and header pictures. Its family/chassis alias still supplies Rally-compatible audio and entitlements. Garage focus follows the lower hood/roof and rear deck; the race camera is unchanged.

The [National Corvette Museum collection](https://members.corvettemuseum.org/museum-collection) supplied historical shape reference. All shipped geometry is authored in `game/vehicle/super_rally_model.gd` using existing project materials and mesh utilities.

## Native appearance evidence

| View | Compatibility | Desktop Mobile |
| --- | --- | --- |
| Front, beside normal Rally | [Capture](evidence/super-rally-design-2026-11-08/c3-refined/gl_compatibility/front.png) | [Capture](evidence/super-rally-design-2026-11-08/c3-final/mobile/front.png) |
| Rear | [Capture](evidence/super-rally-design-2026-11-08/c3-refined/gl_compatibility/rear.png) | [Capture](evidence/super-rally-design-2026-11-08/c3-final/mobile/rear.png) |
| Side | [Capture](evidence/super-rally-design-2026-11-08/c3-refined/gl_compatibility/side.png) | [Capture](evidence/super-rally-design-2026-11-08/c3-final/mobile/side.png) |
| Overhead | [Capture](evidence/super-rally-design-2026-11-08/c3-refined/gl_compatibility/overhead.png) | [Capture](evidence/super-rally-design-2026-11-08/c3-final/mobile/overhead.png) |
| Actual App Garage | [Capture](evidence/super-rally-design-2026-11-08/c3/gl_compatibility/garage.png) | [Capture](evidence/super-rally-design-2026-11-08/c3/mobile/garage.png) |
| Actual App catalogue | [Capture](evidence/super-rally-design-2026-11-08/c3/gl_compatibility/catalogue.png) | [Capture](evidence/super-rally-design-2026-11-08/c3/mobile/catalogue.png) |
| Actual local race | [Capture](evidence/super-rally-design-2026-11-08/c3/gl_compatibility/race.png) | [Capture](evidence/super-rally-design-2026-11-08/c3/mobile/race.png) |

The review harness uses equal framing for both cars, with a wider review-only zoom after the first C3 capture clipped its longer nose. This does not change the gameplay camera. The rejected hatchback design and its earlier evidence remain under `rejected-rally-kit-design`, `first`, `second` and `final`; those captures and their checks do not qualify this coupe.

## Actual validation

Engine: **4.7.2.stable.official.ed1daf0bf**, from the pinned absolute executable. Tests use a task-owned APPDATA directory and empty backend URL. The [command receipts and raw logs](evidence/super-rally-design-2026-11-08/) retain arguments, owned PID, elapsed time, process exit and script-error count.

| Check | Actual result |
| --- | --- |
| Complete coupe geometry, exact normal Rally construction, kit reset, finite vertices, ownership and full task-start price catalogue | **27 checks, 0 failures** |
| All 78 fitted choices across both quality tiers; wheel contacts, lamp handles, stock reset and night units | **316/0** |
| Prepared bases/modules compared against current source, all Super rally choices, ghosts/materials/weathering | **1,486/0** |
| Physics, saves, full/resumed serialized replay and required prepared base/module hits | **3,677/0** |
| Washing and independent car condition | **1,655/0** |
| Driving | **72/0** |
| Production script compilation | **554 scripts, 0 failures** |
| Builder dependency audit | **180 edges covered** |
| Actual App selection, save/reload, pictures, Garage and ordinary five-lap race setup | **13/0 each desktop renderer** |
| Coherent six-car prepared-asset refresh, original strict validator | **551 resources, 2,267 checks, 0 failures** |
| Catalogue provenance, original checker | **6 exact native pictures, 157 current source hashes** |
| Fresh original pipeline verification after final UI text correction | **Both preflights pass** |
| Final import after all native picture bakes | **Exit 0, zero script errors** |

The complete refresh freezes **368 source inputs with zero changes**, keeps all per-model fingerprints exact across generation, and records every bake/check with zero process or script failures. [Bake commands](evidence/super-rally-design-2026-11-08/c3-assets-commands.json), [source fence](evidence/super-rally-design-2026-11-08/c3-assets-source-receipt.json), [prepared receipt](evidence/super-rally-design-2026-11-08/c3-assets-prepared.log) and [picture receipt](evidence/super-rally-design-2026-11-08/c3-assets-picture-preflight.log) are retained. Twenty-four bases, 520 fitted modules, six Garage models and one shared Compact header template are checked. Super rally uses its own modular bases for header rendering. Live paint-option icons render the actual coupe through the existing bounded icon cache.

Full stock geometry bounds before the shared body scale are 2.050 m wide, 1.311 m high and 4.923 m long. This is lower and longer than the normal Rally (2.070 × 1.513 × 4.355 m). Reduced stock geometry has 18,760 triangles versus normal Rally's 39,756; full reference geometry has 62,484 versus 101,660. These are geometry counts, not measured device performance.

Measured Super rally 0–100 km/h remains 1.708 s versus Rally 2.125 s; five-second distance remains 175.340 m versus 146.562 m. Forty-eight matched-speed coast/brake/handbrake controls remain exact; powered trajectories naturally differ with the extra acceleration.

Representative commands, from the repository root:

```powershell
python docs/evidence/super-rally-design-2026-11-08/run_check.py c3-geometry-final res://tests/test_super_rally_design.gd --headless
python docs/evidence/super-rally-design-2026-11-08/run_check.py c3-all-kits res://tests/test_super_rally_c3_kits.gd --headless
python docs/evidence/super-rally-design-2026-11-08/run_check.py c3-modules res://tests/test_modular_car_assets.gd --headless -- --vehicle=super_rally --all-kits
python docs/evidence/super-rally-design-2026-11-08/run_check.py c3-prepared-physics res://tests/test_super_rally.gd --headless -- --prepared --evidence-root=res://../docs/evidence/super-rally-design-2026-11-08/c3
python docs/evidence/super-rally-design-2026-11-08/c3_assets.py
python docs/evidence/super-rally-design-2026-11-08/run_check.py c3-app-gl res://tests/test_super_rally_ui.gd --rendering-method gl_compatibility -- --evidence-root=res://../docs/evidence/super-rally-design-2026-11-08/c3
python docs/evidence/super-rally-design-2026-11-08/run_check.py c3-app-mobile res://tests/test_super_rally_ui.gd --rendering-method mobile -- --evidence-root=res://../docs/evidence/super-rally-design-2026-11-08/c3
python scripts/prepare_car_assets.py --verify --output build/super-rally-c3-final-verification
```

## Source changes and review checkpoint

The [33-file authored source checkpoint](evidence/super-rally-design-2026-11-08/source-only.patch) passes `git apply --check --reverse`; its [source receipt](evidence/super-rally-design-2026-11-08/source-receipt.json) lists every before/after hash. It includes the complete new model, exact task-start reference fixtures and focused design/kit tests. Existing backend/faster-car changes, generated binaries/identities, documentation and concurrent work are excluded. No index mutation, staging or commit was performed.

The source changes group into `super_rally_model.gd`/`car_visual.gd` for the body and fitted parts; the catalogue, customization, livery, weathering and audio files for explicit model versus family routing; cosmetic catalogue/Garage for shared entitlements; showroom/profile/podium and Garage camera helpers for presentation; prepared cache/dependency/identity tools for independent geometry; and the dedicated design, kit, existing-car, washing and actual-App tests. `compact_kits.gd` is byte-exact to task start.

## Retained findings and limits

- The first C3 geometry run printed 27/0 while a fitted scoop raised a typed-array runtime error. The helper now treats any `SCRIPT ERROR:` as failure even when Godot exits zero. The array assignment is corrected; the clean 316/0 exhaustive fitted run and 1,486/0 source/module comparison cover it.
- Earlier rejected-design bakes and tests remain recorded. One initial rejected-design prepared preflight reported Electric key mismatches; a fresh unchanged validator passed without guard changes. These results are historical and are not substituted for the C3 preflight.
- The broad earned-coins test retains its stale 87-item catalogue expectation (56/1); the complete current price/ownership catalogue is compared exactly with the task-start fixture by this task's dedicated test. No pricing assertion was relaxed.
- Sandbox certificate-store diagnostics occur at engine initialization. The PowerShell import wrapper reports status 1 when native stderr is redirected, although all three new PNG imports and editor loading complete; the production parser and native checks provide independent script/import validation. No service requests are made.
- Review caught a UTF-8 round-trip error in Garage UI text introduced during the initial alias edit. All original Unicode strings are restored; only the three intended entitlement substitutions differ from task start. This correction occurred after the coherent model bake. Its [receipt](evidence/super-rally-design-2026-11-08/garage-text-correction.json) proves all model, Garage, header and picture fingerprints unchanged, followed by fresh original [prepared](evidence/super-rally-design-2026-11-08/c3-final-prepared-preflight.log) and [picture](evidence/super-rally-design-2026-11-08/c3-final-pictures-preflight.log) preflights. The final direct subprocess import returns zero without script errors, followed by both native App runs.
- Concurrent `visual_geometry.gd` batching/articulation corrections are preserved and included in the actual asset inputs, but excluded from the authored source checkpoint. Camera-baseline reconstruction is disclosed in [its provenance receipt](evidence/super-rally-design-2026-11-08/camera-baseline-provenance.json).
- No device query/test, APK export/install, owner-save or owner-process change, backend request/deployment, staging or main-index write was performed. Restart/reload and owner appearance/feel acceptance on PC and tablet remain. Existing backend admission/rollout limits from [the original Super rally delivery](SUPER_RALLY_2026_11_08.md) still apply.
