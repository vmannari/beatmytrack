# Forklift cabin frame variation — 2026-11-03

The owner rejected the previous range because nearly all frames shared the same four pillars, rectangular side portals and flat roof. This revision changes the architecture of all thirteen alternatives while retaining Original and every existing item ID.

[Interactive native before/after comparison](evidence/forklift-cabin-variation-2026-11-03/gallery.html) · [All fourteen frames](evidence/forklift-cabin-variation-2026-11-03/cabin-overview.jpg)

## Frame identities

| Existing ID | New design | Visible construction |
| --- | --- | --- |
| `fork_rail` | Round hoop frame | Two continuous transverse round hoops with slim side ties |
| `fork_plate` | Pressed pillar frame | Broad tapered painted rear pillar skins and deep roof blades |
| `fork_twin` | Rear cantilever frame | Two substantial painted rear goosenecks, open front corners, roof-hung mirror mounts |
| `fork_canted` | Swept frame | Rearward-swept pillars and sloping longitudinal roof |
| `fork_round` | Barrel roof frame | Longitudinal side arches and curved roof profile |
| `fork_cross` | Crossbeam frame | Low roof with a single broad X and painted rear corner haunches |
| `fork_canopy` | Weather canopy | Full overhanging formed roof and deep rain gutters |
| `fork_lattice` | Diamond roof frame | Fine diagonal roof bays on slim pillars |
| `fork_arch` | Vaulted frame | Transverse curved ribs with low side rails and a high crown |
| `fork_sport` | Wedge frame | Tapered, sloping roof with three broad longitudinal slats |
| `fork_mesh` | Screen roof frame | Fine metal screen and light alloy-coloured frame |
| `fork_heavy` | Heavy duty frame | Thick portals, deep painted side rails and broad pillar haunches |
| `fork_safari` | Sun shade frame | Extended pale front shade and open rear roof |

Structural changes drive the variation; material and paint accents reinforce the differences. Original body, wheels, mast, lights, mirrors and beacon are retained. Accessory brackets meet each new structure, and the original mounting hardpoints remain. The cantilever intentionally uses only the rear chassis feet.

## Scope and preservation

Only the cabin section of `game/vehicle/forklift_kits.gd` changes geometry. The engine cover, rear guard and wheel builders are byte-exact to this task's snapshot. The catalogue generator changes only cabin names/descriptions; all item IDs and other category rows remain. The complete backend catalogue is byte-exact to the previous refinement baseline. No backend runtime, schema, migration, economy or ownership change is involved.

The source hash changes require refreshed prepared resources: four forklift bases, all 104 full/simple option modules and the Garage template. Other vehicle files and unrelated concurrent work remain outside this task.

## Validation and review

- Construction: **8,606 checks / 0 failures**. Closed volumes, consistent edges/winding, exterior normals, finite vertices, fitted bounds and existing triangle limits remain enforced for every option at both detail levels. Maximum cabin assembly is 9,308 triangles; the unchanged overall maximum is 13,632 against the unchanged 14,000 limit.
- Raw options: **741 / 0**.
- Exact Original comparison: **12 / 0**. Detailed/simple body and wheels match the immutable original builder with zero unmatched triangles, UV/colour differences or normal differences.
- Prepared assets: **1,580 / 0**, matching the source model through all full/simple options and combinations.
- Actual Garage: **187 / 0 in Compatibility and 187 / 0 in desktop Mobile**, with 56 screenshots each. Existing previews, equip/disk reload, ownership cancellation, reset and race/ghost model paths remain covered.

The first construction run found four failures in the thick heavy-frame portal: the corner bend was too tight for its section, creating folded edges. Increasing the bend radius fixed the actual geometry. `construction-first.log` retains the failures; no assertion, tolerance or budget was relaxed.

Native review starts with fixed matched rear three-quarter captures in the existing Garage. Final prepared views also cover front three-quarter and side elevations: 42 cabin views plus 112 actual Garage views give **154 final native captures**. Gallery images are direct native renders; the overview only scales and labels those captures. Fourteen exploratory raw cabin views and the first failed construction log are retained separately.

## Reproduction

Use the pinned Godot through the crash-dialog wrapper and isolated offline runner:

```powershell
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_cabin_variation.ps1 -Stage quality
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_cabin_variation.ps1 -Stage bake
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_cabin_variation.ps1 -Stage gl
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_cabin_variation.ps1 -Stage mobile
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_cabin_variation.ps1 -Stage views
python docs/evidence/forklift-cabin-variation-2026-11-03/make_gallery.py
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/forklift-cabin-variation-2026-11-03/contact_sheet.ps1
```

The exploratory `capture` stage renders all 56 choices before baking; the final `views` stage refreshes the fourteen cabin captures at three angles. The runner uses `tmp/forklift-cabin-variation-user` as APPDATA and an empty API URL. It does not launch or restart the owner's game.

## Limits

Reload, owner appearance acceptance and touch/device performance acceptance remain. No phone/device test or query, APK, real authentication/purchase, owner-save/process change, live/backend mutation, deployment or main-index write was performed. Desktop Mobile means the Godot Mobile renderer on this Windows desktop. Automated checks cover construction; owner visual acceptance remains. Existing English-fallback catalogue copy is retained.
