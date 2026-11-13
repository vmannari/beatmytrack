# Challenger surface and proportion refinement (2026-11-09)

The owner requests drawn contours for doors, handles and fuel cap, a smoother hood, a slightly longer nose and removal of small surface artefacts. **CHR01–CHR04** refine the supplied Challenger exterior while preserving the Super rally identity and existing Rally-based 198 km/h tune.

- **CHR01 — Flush detail:** replace both thick source door shells with continuous thin outer skins fitted to the dense original exterior. Remove source handles and fuel-cap latch; flatten the connected fuel-cap embossing and discard its collapsed/back-facing walls. Door seams, handles and fuel door are thin contour ribbons, without extruded side walls or shadows. Markings sit about 1.8 mm above the final triangulated skin and follow that skin, including its actual fitted part boundaries. No cabin or interior is added.
- **CHR02 — Hood and surface:** replace the collapsed source hood and vent rims with a regular constrained lattice. Its outer footprint is measured by ray intersections against the original dense top skin; its interior uses a restrained smooth crown, blending back to the measured fender/cowl junction. Small vent graphics follow the final hood lattice. Remove subpixel fragments, preserve roof boundary vertices, share the fitted side tangent field, and inset the opaque glazing backing to eliminate overlapping windshield facets. A ray pick identifies the small black front-corner fragments as the native grille backing protruding through the fenders; a narrower, lower backing fixes that overlap.
- **CHR03 — Proportion:** smoothly extend only the nose ahead of z = −1.72 m by up to **14 cm**. Stock length changes from approximately 4.337 m to **4.477 m** before the shared body scale. Physical wheel contacts, wheelbase, track, collision, mass and all handling parameters remain unchanged. Fit the headlight mount, decorative splitter, hood-kit sampling and hood livery projection to the new nose.
- **CHR04 — Integration:** refresh both model tiers, all prepared bases/fitted modules, Garage scenes and native catalogue/menu/header/news pictures under the existing source/revision guards. Update the modification notice. Preserve all existing saved paint, parts, car identity, replay and competitive settings.

Default production geometry is **28,577 triangles**, with a 48,996-triangle offline full reference. Both remain inside the existing 30,000/50,000 checks. The higher counts than the preceding 22,894/41,766 model pay for cleaner skins and retained boundaries; there is no device-performance claim. The original supplied 911,774-triangle model remains reduced by about **96.9%** in production.

## Before and after

| View | Before | Revised |
| --- | --- | --- |
| Front | [Previous model](evidence/challenger-hellcat-2026-11-09/final/gl_compatibility/front.png) | [Revised](evidence/challenger-refinement-2026-11-09/final/gl_compatibility/front.png) |
| Side | [Previous model](evidence/challenger-hellcat-2026-11-09/final/gl_compatibility/side.png) | [Revised](evidence/challenger-refinement-2026-11-09/final/gl_compatibility/side.png) |
| Overhead | [Previous model](evidence/challenger-hellcat-2026-11-09/final/gl_compatibility/overhead.png) | [Revised](evidence/challenger-refinement-2026-11-09/final/gl_compatibility/overhead.png) |

Close views: [front](evidence/challenger-refinement-2026-11-09/detail-finished/gl_compatibility/front.png), [side](evidence/challenger-refinement-2026-11-09/detail-finished/gl_compatibility/side.png), [right](evidence/challenger-refinement-2026-11-09/detail-finished/gl_compatibility/right.png) and [rear](evidence/challenger-refinement-2026-11-09/detail-finished/gl_compatibility/rear.png). These are actual native game geometry; the close inspection camera deliberately crops parts of the car. Production race/Garage cameras are unchanged.

Actual final App [Garage](evidence/challenger-refinement-2026-11-09/app-final/gl_compatibility/garage.png), [race](evidence/challenger-refinement-2026-11-09/app-final/gl_compatibility/race.png), and [desktop Mobile Garage](evidence/challenger-refinement-2026-11-09/app-final/mobile/garage.png) are recorded after the complete prepared refresh.

The actual Garage also revealed front-bumper self-shadow mottling. The Super rally Garage profile uses normal shadow bias 8 instead of the room's original 2, retaining every caster and the complete shadow range. Initial entry and subsequent car replacement apply the profile; switching to another car restores the room's captured original value. Camera, light colour/energy, reflection passes and other car profiles remain unchanged. [Before](evidence/challenger-refinement-2026-11-09/app-caster-control/gl_compatibility/garage.png) and [controlled larger-bias comparison](evidence/challenger-refinement-2026-11-09/app-shadow-range/gl_compatibility/garage-normal-bias-8.png).

## Conversion and checks

The [offline conversion](../scripts/prepare_challenger.py) continues to use the owner-supplied `.blend` with auto-execution disabled, verified Blender 4.5.15 LTS, and no original packed textures, studio, rig or interior. [Source/background sampling](evidence/challenger-refinement-2026-11-09/component-game-bounds.json) and [survey](evidence/challenger-refinement-2026-11-09/survey.log) locate the original features. The final [preparation receipt](evidence/challenger-refinement-2026-11-09/preparation-command.json) pins exact source, component labels and conversion script throughout both tier exports into a separate final output directory. Native conversion additionally requires the actual imported triangle totals to match the complete conversion receipt for each tier.

Pinned Godot: `4.7.2.stable.official.ed1daf0bf`. All [test commands and logs](evidence/challenger-refinement-2026-11-09/) run with a private profile and empty backend URL.

| Check | Result |
| --- | --- |
| Original geometry/normal Rally/reset/ownership checks | 27/0 |
| Existing 78 fitted choices, both quality tiers | 316/0 |
| Washing | 1,655/0 |
| Driving | 72/0 |
| Production script compilation | 554/0 |
| Prepared source/module/ghost/material comparison | 1,438/0 |
| Prepared physics/saves/full and resumed replay | 3,677/0 |
| Both-tier native opaque-window/contour probe and actual prepared hits | 30/0 each desktop renderer |
| Actual App selection, Garage and local race | 13/0 each desktop renderer |
| Initial and repeated Super rally/Rally shadow-profile switching; casters retained | 20/0 |
| Complete prepared scenes and catalogue provenance | 551 resources / 2,267 checks / 0 failures; 6 native pictures / 157 source hashes |

The [final receipt](evidence/challenger-refinement-2026-11-09/final-acceptance.json) records **410 stable inputs**, the complete [15-command geometry refresh](evidence/challenger-refinement-2026-11-09/assets-commands.json), the subsequent [seven-command presentation refresh](evidence/challenger-refinement-2026-11-09/presentation-commands.json), and 16 final acceptance commands. All per-car geometry revisions match across the presentation correction. Normal Rally's geometry signature and [20 unrelated PNGs](evidence/challenger-refinement-2026-11-09/unrelated-picture-controls.json) remain exact. Final picture import exits cleanly with zero script errors.

The [ten-file source-only checkpoint](evidence/challenger-refinement-2026-11-09/source-only.patch) passes `git apply --check --reverse`. The [receipt](evidence/challenger-refinement-2026-11-09/source-receipt.json) records **21 byte-exact shared/canonical controls**, native resource hashes and the unchanged original `.blend`. Generated scenes, binary meshes, build metadata, documentation and unrelated concurrent work are excluded from the source patch. The physics test changes only its hood projection assertion; all motion/replay assertions remain. The existing geometry assertion now specifically requires the longer nose, and the opacity fixture also requires the unshadowed contour surface.

Representative commands, from the repository root:

```powershell
python docs/evidence/challenger-refinement-2026-11-09/run_preparation.py
python docs/evidence/challenger-refinement-2026-11-09/run_check.py native-final res://tests/bake_challenger_hellcat.gd --headless -- --source=res://../build/challenger-refinement-2026-11-09/converted-final
python docs/evidence/challenger-refinement-2026-11-09/guarded_assets.py
python docs/evidence/challenger-refinement-2026-11-09/final_import.py
python docs/evidence/challenger-refinement-2026-11-09/run_check.py modules res://tests/test_modular_car_assets.gd --headless -- --vehicle=super_rally --all-kits
python docs/evidence/challenger-refinement-2026-11-09/run_check.py opaque-gl res://tests/test_challenger_hellcat.gd --rendering-method gl_compatibility -- --prepared --evidence-root=res://../docs/evidence/challenger-refinement-2026-11-09/opaque
python docs/evidence/challenger-refinement-2026-11-09/run_check.py opaque-mobile res://tests/test_challenger_hellcat.gd --rendering-method mobile -- --prepared --evidence-root=res://../docs/evidence/challenger-refinement-2026-11-09/opaque
```

## Retained drafts and limits

The first hood lattice used an approximate boundary and exposed corner gaps; its `first` captures are retained. A topological-boundary attempt correctly rejected the source's branched/overlapping edge loops; measured ray intersections recover the full footprint instead. A separate fuel-cap patch introduced a visible junction and is superseded by flattening the original connected skin. Surface-marking projection and roof-name handling are corrected in both tiers. Early exploratory conversions overlapped, and their outputs are unqualified; the final separate-directory conversion runs alone with stable input hashes and exact per-tier native totals. An initial detail-harness quoting/missing-file attempt is retained. No acceptance assertion is weakened.

Garage controls isolate the remaining mottling to body self-shadowing. Removing LODs, regenerating normals, hiding the grille/glass/other casters, increasing depth bias and providing a positions-only shadow mesh did not fix it. A source visibility-filter trial removed 10,838 hidden bumper triangles before reduction, also without fixing the symptom; that trial is rejected, and the exact qualified source and native buffers are restored. Zero normal bias produces widespread acne; shortening the shadow range clips the car out of valid shadow coverage, so that option is rejected. Bias 8 removes the bumper mottling while keeping all casters and range 12. The retained [caster](evidence/challenger-refinement-2026-11-09/app-caster-control/), [LOD](evidence/challenger-refinement-2026-11-09/app-lod-control/), [range/bias](evidence/challenger-refinement-2026-11-09/app-shadow-range/) and conversion logs preserve these controls. The positions-only trial used the format described in the [official ArrayMesh documentation](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html#class-arraymesh-property-shadow-mesh); it is not part of the final change.

The presentation correction changes only `car_showroom.gd` after the complete geometry bake. A separate [presentation refresh](evidence/challenger-refinement-2026-11-09/presentation-source-receipt.json) verifies unchanged per-car geometry revisions, reuses the validated prepared scenes, regenerates native pictures, and passes both original strict preflights again. No rejected or frozen geometry is published over changed model inputs.

The opacity fixture initially reused its previous task's default output folder. Its output directory is now an explicit argument; all final new captures use the new evidence root. The preceding task's original command logs and final numerical acceptance receipt are preserved; its window-probe images were refreshed by the exploratory run, as noted in that report. Its App and standard comparison captures remain the authoritative original visuals.

Sandbox certificate-store diagnostics remain in engine logs; one earlier desktop Mobile App run also records a WASAPI output-device invalidation and completes its assertions. Backend configuration is explicitly offline. No device query/test, APK export/install, owner-save/process change, live/backend request, deployment or main-index write is performed. Owner appearance acceptance and device appearance/performance qualification remain.
