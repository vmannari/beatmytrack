# Owner-provided catalogue proposal - 2026-09-14

Reference proposal, not a claim that every listed variation is implemented. The owner subsequently confirmed movable tyres and requested movable lightweight props; those instructions supersede the fixed/no-scattering and disappearing-prop suggestions below. Actual shipped bounds: [OBJECT_BROWSER.md](OBJECT_BROWSER.md).

I would keep **Track, Surfaces, Objects and Race** as the four main tools. Within **Objects**, use five categories:

**Nature · Barriers · Trackside · Props · Buildings**

Trees, rocks and grass become part of **Nature**, rather than separate navigation categories. **All** and **Recent** are filters. Variants such as tree size or barrier colour should sit under one asset tile—not fill the browser with near-duplicates.

The catalogue below is my proposed starting specification.

## 1. Objects

Every object should have an obvious interaction type: **Decorative**, **Solid**, or **Soft obstacle**. Its appearance should communicate that behaviour before the player hits it.

### Nature

| Object                     | Variants                               | Impact on driving                                                                                                             |
| -------------------------- | -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| **Pine tree**              | Small, medium, tall; a few silhouettes | **Solid trunk.** Branches and canopy do not collide with the car. Fade the canopy when it would hide the player.              |
| **Broadleaf tree**         | Small and mature                       | Same trunk collision as pine trees; mainly offers visual variety.                                                             |
| **Bush**                   | Low, rounded, irregular                | **Decorative.** Drive through without a penalty; bend or briefly fade foliage around the car.                                 |
| **Grass clump**            | Short, tall, dry                       | **Decorative.** No extra grip or speed effect beyond the underlying surface.                                                  |
| **Flower patch**           | Small restrained colour variations     | **Decorative.** Useful for visual identity and landmarks without affecting racing.                                            |
| **Pebbles / small stones** | Individual stones or scattered patch   | **Decorative.** Visibly much smaller than collidable rocks.                                                                   |
| **Rock / boulder**         | Several shapes and sizes               | **Solid.** Deflects or stops the car according to the collision angle. Collision follows the visible rock reasonably closely. |
| **Rock outcrop**           | Low ridge, larger formation            | **Solid.** Creates natural boundaries and separates nearby sections of track.                                                 |
| **Fallen log**             | Short and long                         | **Solid obstacle.** Blocks passage; not a disguised jump.                                                                     |

**Important distinction:** a decorative pebble should never become a substantial obstacle merely because the creator scales it up. Provide separate decorative and collidable assets, with sensible size limits.

### Barriers

| Object               | Variants                              | Impact on driving                                                                                                                     |
| -------------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **Tyre stack**       | Single stack, short group             | **Solid, impact-absorbing.** Loses speed on contact with little rebound; no scattering tyres in the initial version.                  |
| **Tyre wall**        | Straight or curved line               | Same behaviour as tyre stacks, but used to define longer boundaries.                                                                  |
| **Concrete barrier** | Plain, red/white                      | **Rigid collision.** Stops a head-on approach; allows sliding along the side with speed loss.                                         |
| **Metal guardrail**  | Straight or curved                    | **Solid boundary.** Smooth collision along its length, without snagging the car on individual posts.                                  |
| **Wooden fence**     | Low and standard height               | **Solid boundary** in the initial version. Keep its behaviour consistent rather than making some visually identical fences breakable. |
| **Wire fence**       | Short and tall                        | **Solid but visually permeable.** Useful where the player should see the next section of track.                                       |
| **Traffic cone**     | Individual, automatically spaced line | **Soft obstacle.** Tips or disappears when hit, with negligible speed loss. A guide, not an effective shortcut barrier.               |

**Placement:** walls, guardrails and fences should support **dragging a line or curve**, with automatic spacing and joining. Players should not need to place every segment individually.

### Trackside

| Object                         | Variants                    | Impact on driving                                                                                           |
| ------------------------------ | --------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Chevron / direction board**  | Left, right, double-chevron | Communicates the upcoming corner. Small freestanding versions are **soft obstacles**.                       |
| **Braking-distance board**     | Configurable number         | Visual braking reference; **soft obstacle** if struck.                                                      |
| **Banner / advertising board** | Preset designs and colours  | Visual identity and landmarks. Ground-mounted rigid boards are **solid**; overhead fabric has no collision. |
| **Flag / bunting**             | Colours and simple patterns | **Decorative.** No meaningful driving penalty.                                                              |
| **Light pole**                 | A small number of styles    | **Solid pole.** Place outside the expected racing line; fade it if it obscures the car.                     |
| **Start gantry**               | Simple frame, banner frame  | **Solid supports**, clear passage underneath. The actual timing line remains a separate Race element.       |

These assets help players **learn the circuit**. Distinctive signs, trees and structures can identify corners without adding HUD instructions.

### Props

| Object                  | Variants                        | Impact on driving                                                                                                   |
| ----------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **Crate**               | Small wooden crate              | **Soft obstacle.** Breaks with a small, capped speed loss. Fragments are visual only.                               |
| **Barrel**              | A few paint colours             | **Soft obstacle.** Knocks over with a small speed loss; does not explode or become unpredictable persistent debris. |
| **Pallet / scrap pile** | Low decorative arrangement      | **Decorative**, kept visibly low and outside the role of a route-blocking obstacle.                                 |
| **Parked vehicle**      | Utility car, van                | **Solid.** A large, readable obstacle or trackside landmark. Clearly distinguish it from active racers.             |
| **Shipping container**  | Short and long; colour variants | **Solid.** Useful for creating temporary-course boundaries and compact industrial environments.                     |

I would add breakable crates and barrels **after basic solid collisions feel good**. They require more behaviour than static scenery, but should not introduce randomness into competitive lap times.

### Buildings

| Object                  | Variants                     | Impact on driving                                                                              |
| ----------------------- | ---------------------------- | ---------------------------------------------------------------------------------------------- |
| **Shed / small garage** | A few footprints and colours | **Solid footprint.** Background structure or large route-defining obstacle.                    |
| **Marshal hut**         | Small booth, raised booth    | **Solid base.** Useful as a distinctive corner landmark.                                       |
| **Grandstand**          | Short and long modules       | **Solid footprint.** Primarily scenery; position where it does not obscure the racing surface. |

Keep this category small initially. A few reusable structures are more useful than a large catalogue of buildings that all behave identically.

## 2. Track components

These belong under **Track**, not Objects. Curves, hairpins and chicanes should be convenient presets of editable geometry—not rigid pieces with dozens of separate variations.

| Component             | Editable properties                            | Impact on racing                                                                                               |
| --------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| **Straight**          | Length, width, surface                         | Creates acceleration and braking sections.                                                                     |
| **Curve**             | Radius, angle, width, direction                | Controls corner speed and racing-line choice.                                                                  |
| **Hairpin**           | Radius, entry/exit length, width               | Creates tight braking and rotation challenges.                                                                 |
| **S-bend / chicane**  | Spacing, bend strength, direction              | Tests transitions, positioning and rhythm.                                                                     |
| **Width transition**  | Start/end width and length                     | Creates narrowing sections, wider exits and overtaking opportunities.                                          |
| **Kerb**              | Side, extent, width, colour                    | Initially a driveable edge with sound/vibration feedback—not a severe hidden traction penalty.                 |
| **Jump ramp**         | Width, approach and ramp profile within limits | Launches the car according to approach speed. Landing position and attitude matter; no automatic speed boost.  |
| **Bridge / overpass** | Span, height, approaches, width                | Enables crossing routes at different heights. Requires matching elevation, collision and checkpoint behaviour. |

**Jumps and bridges are advanced components.** I would expose them only once airborne handling and elevation are reliable, rather than presenting them as ordinary decoration.

## 3. Surfaces and driving hazards

Put these under **Surfaces**. Their effects should come from the driving model, not from arbitrary instant changes to the displayed speed.

| Surface                    | Proposed driving impact                                                                           | Visual distinction                                    |
| -------------------------- | ------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| **Asphalt**                | Reference grip and rolling resistance.                                                            | Dark, relatively smooth.                              |
| **Packed dirt**            | Slightly reduced grip and modest additional resistance. Still suitable for a proper racing route. | Firm brown surface.                                   |
| **Gravel**                 | Reduced grip, longer braking and more sliding; additional resistance.                             | Loose, pale granular material.                        |
| **Grass**                  | Less grip and more resistance than asphalt, but remains recoverable.                              | Green ground, independent of decorative grass clumps. |
| **Mud**                    | Stronger rolling resistance and reduced grip.                                                     | Dark, visibly soft patches.                           |
| **Shallow water / puddle** | Temporary drag and reduced grip while crossing.                                                   | Thin reflective water with the ground visible below.  |
| **Oil spill**              | Strong local grip reduction, with little added rolling resistance.                                | Distinct dark slick; readable against asphalt.        |
| **Deep water / pond**      | Undriveable: triggers recovery to a safe position.                                                | Clearly deeper water and an unmistakable shoreline.   |

Surface effects should blend at boundaries rather than abruptly clamping velocity. **Shallow and deep water must never look interchangeable.**

A cliff edge with a fall-and-recovery consequence also belongs with **terrain/hazards**, not as an ordinary decorative rock variant.

## 4. Race elements

These define how the course works rather than how it looks.

| Element                 | Impact                                                                                                                               |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| **Start/finish line**   | Defines lap timing and completion. Snaps across the driveable track.                                                                 |
| **Starting positions**  | Defines car positions and orientation at the start. Generate a sensible arrangement automatically, with manual adjustment available. |
| **Ordered checkpoints** | Verifies the intended route and prevents unintended shortcuts. Visible in the editor; normally invisible during racing.              |
| **Recovery points**     | Defines safe return positions after water, falls or becoming stuck. Must not move the player ahead of their validated race progress. |

Lap count and driving direction are **Race settings**, not objects to place.

## 5. Rules that keep this understandable

**Collision costs time, not money.** I would avoid vehicle damage and repair costs: the consequences should be lost speed, a compromised line or recovery.

**Identical-looking objects should behave identically.** Do not initially expose arbitrary collision strength or grip multipliers per object. Give creators creativity through layout, surfaces and combinations—not invisible rules.

**Keep decoration separate from handling.** A grass clump does not secretly slow the car; the grass surface does. A tree collides at its trunk, not across its entire canopy.

**Reset interactive objects for every competitive attempt.** Cones, barrels and crates should begin in the same state, with non-colliding debris, so earlier impacts do not change the next run.

For the compact asset browser, show **thumbnail + name** on each tile. On selection, reveal one short behaviour label—such as **“Solid · trunk collision”** or **“Decorative · no collision”**—alongside the relevant variants. That provides the important information without bringing back a permanent properties panel.
