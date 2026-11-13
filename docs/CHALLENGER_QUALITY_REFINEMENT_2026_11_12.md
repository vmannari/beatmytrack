# Challenger exterior quality review and refinement (2026-11-12)

The owner asks for a quality review and refinement because the Challenger still falls short of an AAA finish. This pass improves the actual game model, materials and generated presentation. **It does not claim an AAA finish or qualified tablet performance.**

The controlled close views showed missing grille detail, collapsed lamp shapes, flat bonnet markings, box-like factory wheel spokes and contradictory glazing normals. Increasing paint gloss alone exposed more of those defects. The final changes put geometry into visible manufactured details and keep the supplied Hellcat proportions, the earlier restrained bonnet and the extended nose.

## Changes

- **CHQ01 — Optics and trim:** four projector assemblies have recessed reflectors, turned bezels and restrained light guides. A recessed open-cell grille replaces the featureless central opening. Smoked rear lenses and perimeter light guides follow a smooth fit of the measured compound rear surface; original boundary trim closes the join below the spoiler. Rolled oval exhaust tips replace fragile reduced source tubes. Existing two headlamp groups, two brake-light groups and night/brake behaviour remain.
- **CHQ02 — Surfaces and finish:** the bonnet has actual shallow vent openings, painted returns, recessed beds and thin vanes, replacing three flat black patches. The regular bonnet lattice retains its measured boundary and restrained crown. Consistent pane normals and unshadowed glazing remove the conspicuous triangular window patches; panes remain fully opaque and the interior remains removed. Automotive paint has a stronger clearcoat and more controlled roughness; glass and metal finishes are differentiated. These finishes are local to Super rally and retain saved paint colours. Door, handle and fuel-cap details remain flush contours.
- **CHQ03 — Wheels and sampling:** new factory wheels use concave split spokes, bevelled sections, a turned rim lip, hub/lugs and a recessed brake disc. Only this car uses 64-segment tyres in production. More samples are allocated to the body and fenders. Existing purchased rim designs and fitted parts retain their identities and work independently of the factory wheel.
- **CHQ04 — Integration:** both native tiers, prepared bases/modules, Garage scenes, header, artwork and catalogue previews are rebuilt under the existing source guards. The attribution notice records these modifications. The offline baker now defaults to the current qualified conversion directory.

No shared handling, collision, contacts, saved identity or competitive configuration is changed by this task. The Rally-based tune still has 20% additional engine force and a 198 km/h cap. The 14 cm nose extension remains ahead of the front arch. Original roof geometry and boundary vertices are retained after the replacement drafts proved worse.

## Native comparisons

These are actual game renders with the same close inspection camera and default paint. The inspection view deliberately crops the car; the production camera is unchanged.

| View | Before | Refined |
| --- | --- | --- |
| Front | [Before](evidence/challenger-quality-2026-11-12/detail-before/gl_compatibility/front.png) | [Refined](evidence/challenger-quality-2026-11-12/detail-measured/gl_compatibility/front.png) |
| Rear | [Before](evidence/challenger-quality-2026-11-12/detail-before/gl_compatibility/rear.png) | [Refined](evidence/challenger-quality-2026-11-12/detail-measured/gl_compatibility/rear.png) |
| Side | [Before](evidence/challenger-quality-2026-11-12/detail-before/gl_compatibility/side.png) | [Refined](evidence/challenger-quality-2026-11-12/detail-measured/gl_compatibility/side.png) |

Final actual App: [Garage](evidence/challenger-quality-2026-11-12/app/gl_compatibility/garage.png), [race](evidence/challenger-quality-2026-11-12/app/gl_compatibility/race.png), and [desktop Mobile Garage](evidence/challenger-quality-2026-11-12/app/mobile/garage.png). [Normal Rally and Super rally studio views](evidence/challenger-quality-2026-11-12/final/gl_compatibility/front.png) use the finished native model.

## Geometry cost and verification

Production geometry rises from **28,577 to 45,389 triangles**, an increase of about 59%. The offline full reference rises from 48,996 to **78,697**. Production remains about **95.0% below** the supplied 911,774-triangle model, and about 14% above the unchanged normal Rally's 39,756 triangles. The extra cost buys specific close-view features and rounder silhouettes; it is not a free performance improvement.

The older 30k/50k assertion was a task heuristic, not an owner limit. Its allocation is explicitly revised to **50k production / 85k full** for this quality pass. The independent normal-Rally-relative geometry bound, contact, opacity, replay and preparation assertions remain. There is no graphics quality selector or production fallback to the former model.

Pinned tools: Godot `4.7.2.stable.official.ed1daf0bf` and Blender 4.5.15 LTS. Blender runs with factory startup, auto-execution disabled and scripts disabled while opening the supplied source. No source textures, rig, branding or cabin contents are added. Tests use private profiles and an empty backend URL.

| Check | Result |
| --- | --- |
| Geometry, normal Rally, contacts, reset and ownership | 27/0 |
| Existing 78 fitted choices, both tiers | 316/0 |
| Source/prepared modules, materials and personal ghost | 1,438/0 |
| Prepared physics, identity, saves and full/resumed replay | 3,677/0 |
| Washing / driving / production compilation | 1,655/0; 72/0; 555/0 |
| Prepared native opacity/contour/contacts, both tiers | 30/0 each desktop renderer |
| Actual App selection, Garage and local race setup | 13/0 each desktop renderer |
| Garage shadow-profile switching and caster retention | 20/0 |
| Updated licence/creator/modifications panel | Verbatim notice passes |
| Complete prepared preflight | 551 resources; 2,267 checks; 0 failures |
| Native preview provenance | Six pictures; 158 current source hashes |

The [final receipt](evidence/challenger-quality-2026-11-12/final-acceptance.json) records **424 stable inputs**, all **15 refresh commands** and the final acceptance commands. Original normal Rally geometry and **16 of 20 unrelated PNGs** remain exact. The four concurrent Kart picture changes and capture findings are retained below; the earlier twenty-image byte-identity gate is not claimed. Picture import exits cleanly with no script errors.

The [six-file source checkpoint](evidence/challenger-quality-2026-11-12/source-only.patch) passes `git apply --check --reverse`. The [source receipt](evidence/challenger-quality-2026-11-12/source-receipt.json) retains **24 byte-exact controls**, hashes for 50 native resource/metadata files, and the unchanged original supplied blend. Concurrent Kart steering/driver additions to `CarVisual`, Kart model/helmet and the shared batching/shadow helpers landed before the coherent refresh: they are preserved and included in the guarded build, but excluded from this task's authored patch and byte-exact controls. Generated resources, documentation, metadata and unrelated edits are excluded from that patch.

## Retained findings and limits

Four final unrelated image hashes differ from task start: Kart's carousel, news, header and illustration pictures accompany the preserved concurrent Kart/steering changes. Sixteen controls, including every normal Rally image, remain byte-exact. The full twenty-image identity gate is therefore not claimed.

The first refresh also produced different hashes for four normal-car thumbnails. A separate native re-render reproduces those first-refresh hashes exactly. The current live versions returned to their task-start bytes during concurrent asset closeout, with matching current provenance; those baseline files are retained in the evidence directory. Compared with the retained production versions, the native re-render changes **2, 6, 6 and 83 pixels** for Rally, Forklift, Volt and Hover, respectively, out of 1,048,576 per image (maximum channel differences 51, 32, 52 and 37/255). Super rally and Kart repeat exactly. These are retained native capture differences, not a widened numeric acceptance threshold. The unchanged provenance and complete prepared preflights are rerun against the final live assets. See the [pixel comparison](evidence/challenger-quality-2026-11-12/preview-repeat-pixels.json), [final image hashes](evidence/challenger-quality-2026-11-12/unrelated-picture-controls.json), [observed live closeout](evidence/challenger-quality-2026-11-12/live-picture-closeout.json), and [concurrent source differences](evidence/challenger-quality-2026-11-12/prior-bake-shared-source-differences.json).


The first roof adjustment introduced ripples, and the roof replacement changed joins at the glazing. Both were rejected; original roof geometry is retained. The first grille sat behind the bumper. A guessed rear applique curve left a gap below the spoiler; a fan triangulation also pulled the wide panel inward. Regular surface sampling, a measured compound-curve fit and the retained source border correct these final views. Draft captures and failed conversions remain in the evidence directory.

The initial boundary-only rear survey encountered the source's optical holes. Its first Blender exception returned process exit zero, so the old wrapper's status alone was insufficient. That receipt is retained as a failed attempt. The qualified wrapper now uses `--python-exit-code 1`, requires both export markers and the completion marker, rejects tracebacks, and requires all three outputs to be fresh. Subsequent bounds/optical-hole failures exit nonzero and are retained. Only the final successful, source-pinned conversion feeds the accepted refresh. The original roof was restored before that conversion.

Fine panel-gap/bevel consistency under grazing light and richer tyre/metal material detail remain art-review work. Desktop comparisons and regression checks establish this pass's improvements and preserved behaviour; they do not certify AAA quality, tablet frame time or thermal behaviour. Owner appearance/reload and device qualification remain. No device query/test, APK, installation, owner-save/process change, backend request, deployment or main-index operation was performed.

Representative commands from the repository root:

```powershell
python docs/evidence/challenger-quality-2026-11-12/run_preparation.py
python docs/evidence/challenger-quality-2026-11-12/run_check.py measured-native res://tests/bake_challenger_hellcat.gd --headless -- --source=res://../build/challenger-quality-2026-11-12/converted-final
python docs/evidence/challenger-quality-2026-11-12/guarded_assets.py
python docs/evidence/challenger-quality-2026-11-12/final_import.py
python docs/evidence/challenger-quality-2026-11-12/raw_checks.py
python docs/evidence/challenger-quality-2026-11-12/final_suite.py
python docs/evidence/challenger-quality-2026-11-12/checkpoint.py
python docs/evidence/challenger-quality-2026-11-12/final_receipts.py
```
