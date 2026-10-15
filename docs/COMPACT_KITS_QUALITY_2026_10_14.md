# Compact kit construction and quality review — 2026-10-14

The owner rejected implausible designs and requested a review of every kit at the AAA quality target. All 43 existing choices were reviewed against the production compact. Original remains the factory model; nine replacement hoods, nine wheel faces, nine body packages and twelve aero choices now use more coherent construction. Saved IDs, independent installation, paint, local condition, tyres, articulated wheels, reflections and the retained Garage pane remain.

Open the [interactive native review gallery](evidence/compact-kits-quality-2026-10-14/review.html). It offers every choice on the actual Garage car, full front/rear views and close-ups, with Compatibility and Mobile captures. There are **139 car views per renderer**, plus the [hood](evidence/compact-kits-quality-2026-10-14/catalog-compatibility/hood.png), [aero](evidence/compact-kits-quality-2026-10-14/catalog-compatibility/aero.png), [rim](evidence/compact-kits-quality-2026-10-14/catalog-compatibility/rims.png) and [body](evidence/compact-kits-quality-2026-10-14/catalog-compatibility/body.png) shipping-photo sheets. These are native models and screenshots, with no generated concept images substituted for production geometry.

## Construction corrections

- **Body packages:** hollow-looking oval rails became closed, bevelled sill and bumper sections with hidden returns reaching the existing sheet/bumper. Extensions follow the original rolled arches and retain an inner return. Track packages have a connected splitter deck, sill blades and a rising diffuser tray with attached strakes. Rally/gravel flaps have actual mounting brackets and fasteners. Rear extensions clear the complete original plate frame; Club and Endurance use a quieter dark rear apron.
- **Hoods:** the tall boxed scoops became lower blended intakes, with recessed mouths and restrained grille rails. Louvres now have real thickness and end returns. The cowl grille cuts through the panel into a recess. Pressed ribs and cowl height are restrained; crown inserts taper instead of covering an arbitrary rectangle. Continuous panel gaps replace dozens of short seam boxes.
- **Rims:** flat cast/forged faces with bevelled edges replace tubular spokes. Cross mesh has an actual crossed lattice. Rally disc has eight genuine through-windows, rather than overlapping petals. Hub sockets and four lug heads sit in the face; perimeter fasteners land on the rim flange, and valves point inward from the bead. A plain machined rotor replaces false drilled-hole dots. The original tyres and steering/rolling frames remain.
- **Aero:** GT uses a closed blade and shaped endplates; supports have fabricated faces and closed ends. Twin blades both meet their endplates. Gurney lips follow the actual swept trailing edges. Integral hatch roots and the roof lip are closed solids. The disconnected split design became a continuous **Swept wing**, retaining the `splitwing` saved ID. Rally hoop now has a coherent arched bridge. Low rear wing, Rear twin blade and Endurance rear retain their lower, farther-aft positions.

## Every retained choice

| Category | Choices and reviewed intent |
|---|---|
| Hood, 10 | Original factory sheet; Twin louvres, paired six-blade vents; Rally scoop, single blended forward intake; Power dome, pressed engine-clearance crown; Track extractor, broad recessed four-blade vent; Raised cowl, restrained rear plenum and genuine grille opening; Twin intakes, paired low mouths; Reverse intake, rear-facing mouth; Pressed ribs, three shallow longitudinal pressings; Vented dome, raised crown and paired flanking vents. |
| Rear aero, 13 | Original; Roof lip, small fitted extension; Ducktail, low hatch lip; GT wing, conventional roof supports; Hatch sweep, integral tapered shelf; Low rear wing, rear-metal pedestals; Swan neck, upper blade clamps; Rear twin blade, two connected levels; Rally hoop, arched roof bridge; Endurance rear, broad low blade and fitted Gurney; Whale tail, broad moulded hatch shelf; Drag deck, flat rear stabilizer; Swept wing, continuous swept low blade. |
| Rims, 10 | Original; Forged five, broad five-spoke face; Split six, six paired branches; Turbine, twelve swept blades; Cross mesh, crossed eight-pair lattice; Deep dish, recessed five-spoke face and stepped lip; Rally disc, eight open cooling windows; Sport six, straight six-spoke face; Slim ten, slender ten-spoke face; Tri spoke, three broad swept spokes. |
| Body, 10 | Original; Street, restrained painted sills/aprons; Rally, protective arches and mounted flaps; Club sport, homologation arches and complete track aero floor; Heritage, small period-style flares and shallow aprons; Touring, deeper road skirts and restrained floor aero; Wide arch, wider returned arches; Endurance, broader arches and full splitter/diffuser; Gravel, protective trim and wider flaps; Urban sport, compact road skirts and shallow floor aero. |

All 10/13/10/10 choices remain independent. Existing selections reload normally; factory reset reveals Original. The label change for `splitwing` does not change persistence schema/version 1.

## Fit, budgets and verification

`CompactHoodKits`, `CompactWheelKits` and `CompactBodyKits` replace the earlier repeated generators. `CompactKitSurface` builds consistent winding around concave returns and keeps end caps in the same immutable surface. Unused legacy generators were removed; the small `CompactKitVariants` hood-profile/roll-ID compatibility helper remains. Every full/simple prepared mesh matches the regenerated source surface hash.

| Final check | Result |
|---|---|
| `test_compact_kit_geometry.gd --parts-only` | 5,223 checks, 0 failures: finite normals, clockwise faces, original hood boundaries, articulation, wash coordinates and roll clearance. |
| `test_compact_kit_construction.gd` | 1,354 checks, 0 failures: closed fabricated sections, real thickness, original tyre-envelope/plate-frame clearance and rays through all eight wheel windows. |
| `test_expanded_compact_catalog.gd` | 1,543 checks, 0 failures: all **13,000 combinations per quality**, actual maximum assembly, source hashes, rolled-fender clearance and canonical roll-state invariance. |
| `test_compact_aero_variety.gd` | 836 checks, 0 failures: mounts on actual rear metal, original glazing clearance, low/aft positions, closed saddles and retained editing. |
| `test_incremental_compact_kits.gd` | 346 checks, 0 failures: same car/body/tyres/pivots, unselected parts, paint and dirt retained across installation. |
| `test_compact_kits.gd`, Compatibility + Mobile | 520 + 520 checks, 0 failures: actual touch choices, scrolling, saved/reset selections, rollback, three sizes and race/ghost/awards integration. |
| `test_garage_customisation_speed.gd`, Compatibility + Mobile | 1,396 + 1,396 checks, 0 failures: exact imported photos/meshes, bounded caches, retained workbench controls and physical-panel invalidation. |
| Standard/simple racing | 85 checks, 0 failures; original compact stays 104,558 detailed / 39,594 simple visible triangles, with five standard simple shadow casters. Existing batched/original comparison differs by at most one channel value. |
| Garage reflections, Compatibility + Mobile | 25 + 25 checks, 0 failures; actual deck/floor reflections, motion and hidden-page lifecycle. |
| Final parse | 725 scripts, 0 failures. |

The real catalog maxima are **168,914 detailed** and **64,578 simple** visible triangles, below the existing 170,000 budget. The prepared catalog has **1,260 meshes** (6,198,820 compressed bytes); the previous catalog had 1,244, so it remains below the 1,400-entry check. The 86 lossless, mipmapped 384×112 photographs total 1,967,112 PNG bytes. The runtime photo cache remains **16**, and the retained workbench roots remain bounded. Original tyre sizes and the canonical simulation/contracts were not changed.

Native snapshots and command logs are in `docs/evidence/compact-kits-quality-2026-10-14`. The first construction/normal runs exposed missing cap indices and inconsistent fold normals; both were corrected. Early maximum-combination runs exceeded budget; excess metal-face/arch subdivisions were reduced while retaining the openings, fitted profiles, tyre geometry and strict budget assertion. Final passes above use the final assets. No broader full-validation/physics suite or phone performance improvement is implied.

## Switching and acceptance

The actual application timing captures use isolated local records and the complete shipping Garage. `timings-compatibility/timings.json` and `timings-mobile/timings.json` record dispatch and first-render times, with `standalone_real_garage=false`. Offline photographs and exact prepared surfaces remain the switching path; there is no live preview world per card or rebuild of the complete car on a part change.

| Actual first-render action | Compatibility | Mobile |
|---|---:|---:|
| Open Tuning / initial Hood | 77.3 ms | 103.3 ms |
| First Aero category | 47.5 ms | 42.5 ms |
| First Rims category | 44.1 ms | 32.1 ms |
| First Body category | 34.0 ms | 30.9 ms |
| Sampled part installations, all categories | 11.7–74.1 ms | 28.8–225.5 ms |

These are desktop measurements, with first-load rim stalls still observable; the prior expanded-kit Mobile trace also recorded a 206.2 ms initial Cross mesh installation. This is preservation of the prepared/independent switching architecture, not a paired phone frame-rate or universal stall-free claim.

AAA remains the owner's visual-quality target. The gallery is a concrete review result, with physical-phone brightness, aliasing, touch and frame-pacing/thermal acceptance still outstanding. This task did not build/install an APK, deploy a backend, change canonical handling/scoring, or modify the parallel tyre/racing-render/livery/menu-motion work.

The scoped two-commit review is in `build/compact-kits-quality/checkpoint-repo`; its exact baseline/task hashes and source/asset/evidence hashes are in `delivery.json`, with `task-only.patch` beside it. The shared branch and index are untouched by this task.
