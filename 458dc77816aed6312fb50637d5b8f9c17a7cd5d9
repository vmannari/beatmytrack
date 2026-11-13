# Forklift engine cover and rear guard variation — 2026-11-03

The owner accepted the cabin frame range and requested the same improvement for rear guards and engine covers. All thirteen alternatives in each of these two categories now have distinct formed surfaces, service layouts or mounted assemblies. Original and all fourteen choices per category remain, with every item ID preserved.

[Native before/after gallery](evidence/forklift-cover-guard-variation-2026-11-03/gallery.html) · [Engine cover overview](evidence/forklift-cover-guard-variation-2026-11-03/hood-overview.jpg) · [Rear guard overview](evidence/forklift-cover-guard-variation-2026-11-03/aero-overview.jpg)

## Designs

| Existing cover ID | Design | Construction |
| --- | --- | --- |
| `fork_vent` | Louvre cassette | Broad recessed cooling cassette in a folded shell |
| `fork_rib` | Cast fin cover | Integral alloy cooling fins and matching cast shell |
| `fork_twin` | Butterfly cover | Two complete curved doors, real centre joint and separate latches |
| `fork_scoop` | Raised rear intake | Rising shell with a deep rear intake |
| `fork_louvre` | Herringbone louvres | Opposed diagonal vanes clipped inside recessed banks |
| `fork_split` | Two-piece service cover | Painted front hinge shell and separate graphite lift-out panel |
| `fork_dome` | Barrel cover | Broad continuous crown with narrow shoulder vents |
| `fork_fan` | Circular filter cover | Round recessed cassette, rolled rim, screen and captive screws |
| `fork_cross` | Captive service hatch | Chamfered removable hatch, handle and six retaining fasteners |
| `fork_flush` | Flush cover | Clean low shell and narrow rear slot |
| `fork_armour` | Protected shoulders | Shaped bolted wear plates seated on the lid |
| `fork_channel` | Pressed flutes | Four longitudinal formed flutes in darker metal |
| `fork_race` | Folded side vents | Creased crown and recessed shoulder intakes |

| Existing guard ID | Design | Construction |
| --- | --- | --- |
| `fork_bar` | Pressed impact beam | Folded face, end cheeks and lower return |
| `fork_wrap` | Wraparound guard | Continuous corner returns with replaceable buffers |
| `fork_twin` | Twin tube rails | Two separated round rails on mounting webs |
| `fork_low` | Low rubber shoe | Moulded low impact shoe and steel backing |
| `fork_bow` | Swept wing guard | Continuous rising curved beam with outer pads |
| `fork_step` | Recessed step guard | Raised wings around a lower cast-tread service step |
| `fork_mesh` | Open service grille | Genuine open vanes in a welded frame |
| `fork_roller` | Dock roller guard | Rubber rollers with captive axles, top/bottom ears and backplates |
| `fork_plate` | Counterweight shield | Faceted shield with fasteners and replaceable lower rubber face |
| `fork_cage` | Braced box guard | Open frame, diagonal braces and corner pads |
| `fork_arc` | Rolled steel tube | Broad round curved tube and supported mounting saddles |
| `fork_rib` | Triple dock buffers | Three moulded ribbed pads on a carrier rail |
| `fork_tow` | Clevis towing guard | Bored twin ears, captive vertical pin and separate guard wings |

All guards have supported chassis shoes and stays. Covers retain the existing lid aperture and gasket, with hardware seated on the selected formed surface. Matte industrial finishes, body/accent paint, closed bevelled edges and actual recessed/open geometry follow the accepted forklift style.

## Scope and preservation

- `game/vehicle/forklift_kits.gd`: only engine-cover/rear-guard builders and their dedicated helpers change. The entire accepted cabin and wheel builder section stays byte-exact.
- `game/vehicle/forklift_kit_surface.gd`: optional barrel, hip, ridge, wedge and fluted lid profiles. The default crown geometry remains exactly unchanged, including accepted cabin weather/sun roofs. All other geometry helpers remain byte-exact.
- The forklift catalogue generator changes only these two categories' names/descriptions. Cabin/wheel rows, Original rows and all option IDs remain unchanged. The backend catalogue and forklift model source remain byte-exact to task start.
- Four forklift bases, 104 full/simple modules and the Garage template refresh for the source identities. No other vehicle assets are rebaked.
- The new retained-deck regression uses the immutable task-start surface helper. The existing capture helper gains an optional lower cover/straight rear detail view; existing default captures retain their cameras and behaviour.

## Validation

- Final construction: **9,170 checks / 0 failures**. Closed volumes, consistent edges/winding, exterior normals, finite vertices, fitted bounds and the existing under-14,000 assembly triangle limit remain enforced. Maximum cover is 7,076 triangles; maximum guard is 6,532. The unchanged wheel maximum remains 13,632.
- Raw options: **741 / 0**.
- Exact Original: **12 / 0**, with zero body/wheel geometry, UV/colour or normal differences at either detail level.
- Retained default decks: **18 / 0**. All vertex, normal, UV/index arrays and bounds match the immutable task-start helper at both detail levels, including both accepted cabin roof shapes and a pocketed cover.
- Prepared assets: **1,580 / 0**, covering all full/simple options and combinations against source geometry.
- Actual Garage: **187 / 0 in Compatibility and 187 / 0 in desktop Mobile**, including all previews, equip/disk reload, ownership cancellation, reset and race/ghost models. Each renderer records all 56 choices.
- Native review: **252 final/control captures** — 56 matched before, 56 prepared after, 28 additional cover/guard detail views and 112 actual Garage views. The accompanying report records their hashes and all 109 prepared resource hashes.

The first construction run found four bumper-envelope failures: wraparound and step buffers protruded 10 mm and 0.5 mm beyond the existing rear limit in both detail levels. The pads moved inward; the original gates and limits remain. `construction-first.log/json` retain the failures. The first visual pass also retained overly contrasting fin strips and pale flutes; integral fin seating/matching cast material and a darker flute finish corrected them. Those initial images remain alongside the final gallery.

## Reproduction

Run through the pinned Godot and crash-dialog wrapper with isolated APPDATA and an empty API URL:

```powershell
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_cover_guard.ps1 -Stage before
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_cover_guard.ps1 -Stage quality
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_cover_guard.ps1 -Stage polish
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_cover_guard.ps1 -Stage bake
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_cover_guard.ps1 -Stage gl
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_cover_guard.ps1 -Stage mobile
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_cover_guard.ps1 -Stage capture
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_forklift_cover_guard.ps1 -Stage detail
python docs/evidence/forklift-cover-guard-variation-2026-11-03/make_gallery.py
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/forklift-cover-guard-variation-2026-11-03/contact_sheets.ps1
```

`before` was run before any geometry changes; do not overwrite its task-start evidence with a later source. `polish` rechecks construction/options and captures the final fin/flute polish. `quality` also retains the Original/default-deck controls. `capture` after baking refreshes the gallery from the prepared production path. `detail` shows lower cover profiles and straight rear assemblies. Screenshots are native renders; contact sheets only scale and label them.

## Limits

Reload, owner visual acceptance and device/touch performance acceptance remain. No device query/test, APK, real purchase/authentication, owner-save/process change, live/backend mutation, deployment or main-index write was performed. Desktop Mobile refers to the renderer on this Windows desktop, not a phone. Existing English-fallback option copy remains; concurrent checkpoint/loading/music/Daily work is preserved.
