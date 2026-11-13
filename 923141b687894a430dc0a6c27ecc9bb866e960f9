# Electric model design review — 2026-10-26

The current model is recognisably an electric sedan, but it is still below the requested premium game-asset standard. The largest gap is the relationship between the rounded lower body and the angular cabin. Repeated local bonnet corrections have improved its outline without resolving that broader design problem. The next substantial improvement should start with the silhouette and cabin, then the body surfaces, then the smaller assemblies.

This is a review, not a model revision. Findings below are visual assessments, with measurements identified separately. Passing existing continuity and construction tests does not constitute visual acceptance or an AAA certification.

[Open the comparison board](evidence/electric-design-review-2026-10-26/comparison.html). It switches between both model detail levels, Compatibility and desktop Mobile, and the reference photographs.

## Scope and requirements

| ID | Requirement | Result |
|---|---|---|
| EDR01 | Review the entire current electric model | Silhouette, hood/front, rear, doors, glazing, mirrors, wheels, materials and edge quality reviewed in fresh native views |
| EDR02 | Compare against Lucid and other relevant EVs | Official Lucid Air, Porsche Taycan and facelifted Hyundai IONIQ 6 references examined |
| EDR03 | Identify useful next changes | Priorities and a proposed design sequence below; no corrective work performed |
| R01 | Preserve the production model and unrelated work | Review does not modify runtime sources/configuration; task adds a capture script and review evidence only |
| Q01 | Record reproducible evidence and limitations | 44 native captures, measured mesh bounds/budgets, source hashes, commands and scoped review patch |

The comparison concerns proportion, curvature, assembly design and visual consistency. Manufacturer photography has different lighting, lenses, materials and interiors; matching its photorealism is not a fair acceptance target for this game's established mature cel-shaded style. The fictional identity and high overhead racing camera remain appropriate constraints.

## Reference comparisons

| Reference | Relevant lesson | Difference visible in our model |
|---|---|---|
| [Lucid Air](https://lucidmotors.com/air) — primary reference | A softly integrated canopy and restrained nose make the broad body surfaces feel deliberate. The narrow lamps have visible housing/optical depth. | Our cabin has straight screen edges and abrupt roof corners; the bonnet looks like an inset lid within a uniformly thick rim. The white light strip supplies identity but little sense of an optical assembly. |
| [Porsche Taycan exterior design](https://newsroom.porsche.com/en_US/products/taycan/exterior-design-18551.html) — secondary form reference | A descending roof, narrowed rear cabin and stronger rear shoulders create a coherent sporting silhouette. | Our nearly level beltline, rectangular roof plan and straight rear-screen descent make the upper and lower forms feel separate. More sharply sculpted wheels would also suit the existing body better. The linked design article describes the original Taycan, not a claim about current model specifications. |
| [Hyundai IONIQ 6 facelift](https://www.hyundai.com/worldwide/en/newsroom/detail/hyundai-motor-unveils-the-new-ioniq-6-and-ioniq-6-n-line-under-%E2%80%98pure-flow%2C-refined%E2%80%99-concept-0000000928) — secondary rear/continuity reference | The curved cabin, tail and ducktail form one gesture; repeated horizontal elements link front and rear. | Our rear has more detail than the earlier version, but the rear window, deck lip, lamp slot and bumper still read as stacked separate pieces. The useful lesson is consistency, not adopting Hyundai's pixel lights or a second competing identity. |

These comparisons are my visual interpretation of the cited official images/design descriptions. Lucid should remain the main direction; collecting distinctive parts from all three would make the design less coherent.

## Findings, in recommended order

### DR01 — High priority: cabin and whole-car silhouette

The exact side view shows distinct corners where the windscreen meets the roof and where the roof turns into the rear screen. From above, the roof is a near rectangle, and the side windows form a series of planar-looking trapezoids. The thick, straight painted borders reinforce the appearance of a separate cabin placed on the body. This dominates the model's perceived quality in both detail levels and renderers.

Develop the windscreen crown, roof arc, side-window outline and rear-pillar return together. Give the roof edges a controlled rounded transition and draw the rear cabin into the shoulders. Judge that silhouette before adding trim. This does not require changing wheel centres, collision dimensions or the racing camera.

Evidence: [side](evidence/electric-design-review-2026-10-26/native/full-side.png), [roof](evidence/electric-design-review-2026-10-26/native/full-roof.png), [top](evidence/electric-design-review-2026-10-26/native/full-top.png). Source: `electric_coachwork.gd`, `cabin_point`, `screen_point`, `roof_point` and `cabin`.

### DR02 — High priority: bonnet, shoulders and front mass

The present seam is cleaner and tapers inward in the top view. That specific improvement should be retained. It has not made the whole front Lucid-like: the bonnet remains a rounded rectangular insert, the surrounding wing/edge is visually heavy, and the frontal view produces a trough-like impression between the raised outer shoulders. Concentrated highlights on the wings make this more conspicuous.

Reshape the bonnet crown, wing tops and nose as one broad controlled surface, using a slimmer, less uniform perimeter treatment. Retain the clean taper while choosing the seam as part of the whole surface design. A new outline alone will not resolve the front's inflated appearance. The visual impression is not proof of a new mesh intersection or normal failure.

Evidence: [bonnet](evidence/electric-design-review-2026-10-26/native/full-bonnet.png), [front](evidence/electric-design-review-2026-10-26/native/full-front.png). The clean-bonnet regression from the preceding task remains unchanged.

### DR03 — High priority: glazing and material response

The screens have little apparent depth. In Compatibility they usually read almost black; in desktop Mobile the same views are much greyer. Along with the straight borders, this makes them look like filled panels. The shared paint can produce a small bright highlight without clearly explaining the wider surface curvature.

First correct the glass curvature and pillar transitions. Then tune bounded reflections, edge darkening/seals and material separation within the established art style. A very simple dark interior silhouette could help close Garage views if its cost is justified; a complete interior is not necessary for overhead racing. Increasing global gloss would accentuate the existing shape problems. The glass shader is intentionally opaque and uses an analytic environment, so the lack of cabin depth is a presentation limitation rather than missing transparency accidentally hidden by a setting.

Evidence: the same `full-side`, `full-bonnet` and `full-roof` views in [Compatibility](evidence/electric-design-review-2026-10-26/native/) and [desktop Mobile](evidence/electric-design-review-2026-10-26/desktop-mobile/). Source: `electric_glass.gdshader` and `compact_finish.gd`.

### DR04 — Medium priority: rear composition

The formed lip, recessed lamp strip and quieter lower valance improve on the earlier flat rear. Nevertheless, the broad bumper face, simple plate recess and abrupt glass-to-deck break still look generic. The tail lamp does not strongly explain the turn into the rear quarters.

Resolve the rear window/deck/quarter surfaces together; make the lamp housing and bumper shoulder follow the same curvature. Keep the lip restrained and integrate the plate recess into the bumper's form. More fins, strips or badges would contribute less than that work.

Evidence: [rear quarter](evidence/electric-design-review-2026-10-26/native/full-rear-quarter.png), [tail detail](evidence/electric-design-review-2026-10-26/native/full-tail-detail.png).

### DR05 — Medium priority: wheels and stance

The wheel spokes have a soft, twisted paddle appearance. The broad dark brake disc, small generic hub and polished outer ring provide weak separation between forged wheel, brake and tyre. The arch pocket is prominent, and the large body panels make the wheels feel smaller than their physical diameter alone suggests.

Use a cleaner spoke cross-section, consistent machining edges, a legible barrel and distinct rotor/caliper finishes. Review arch clearance and wheel-to-body proportions in the real camera, preserving steering clearance and existing physical wheel locations. Enlarging tyres or moving axles is not an automatic consequence of this finding.

Evidence: [wheel](evidence/electric-design-review-2026-10-26/native/full-wheel.png), [side](evidence/electric-design-review-2026-10-26/native/full-side.png). Wheels consume 65,280 of 169,821 full-detail triangles (38.44%), despite these remaining visual weaknesses. This count includes four wheel assemblies outside the body hierarchy; it is not a draw-call measurement.

### DR06 — Medium priority: panel and small-assembly design

The door outlines are basic quadrilaterals, the charge flap is a simple rectangle, the rocker resembles an attached rounded rail, and the mirror housings look like oval pods. The narrow lamps read more strongly as emissive lines than as lenses set into manufactured housings. Their shared simplification compounds across the car.

Use consistent panel-gap depth and radii, relate door cuts to the pillar/quarter design, integrate the sill, and give mirrors a distinct mount, shell, underside and glass aperture. Keep light signatures legible while adding restrained lens/housing depth. These details should follow the new primary forms.

### DR07 — Medium priority: seam and termination cleanup

The close rear view contains broken dark slivers along the deck edge; the exact side view has stepped/open-looking terminations at the lower bumper corners. These are visible quality findings in both renderers, not a confirmed diagnosis of holes. Existing construction tests do not establish that these particular visible joins are finished.

Inspect the affected mesh joins, winding, local depth separation and triangulation before prescribing a fix. Recheck them in moving close views with both detail levels; a favourable three-quarter still should not be the only acceptance view.

## Measured proportions and cost

| Measurement | Current model in world metres | Lucid Air, official dimensions converted from inches |
|---|---:|---:|
| Length | 4.2273 | 4.9759 |
| Height | 1.3288 | 1.4072 |
| Wheelbase | 2.4600 | 2.9591 |
| Wheelbase / length | 58.19% | 59.47% |
| Height / length | 31.43% | 28.28% |

Model dimensions are visible-mesh bounds at rest. The Air is a larger vehicle; these ratios are context, not a specification to copy or a reason to resize gameplay geometry. The modest wheelbase/length difference does not explain the entire appearance problem. Cabin contours, body mass distribution and local transitions remain the stronger visual issues. Width is deliberately omitted because mirrored/body-only width conventions differ. [Lucid dimension source](https://lucidmotors.com/air).

Full/simple geometry is **169,821 / 69,761 triangles**, with identical measured outer bounds. The existing full-detail ceiling is 170,000, leaving only 179 triangles. Reallocate geometry before adding assemblies; a larger triangle budget alone will not improve the silhouette. The capture rig uses unbatched parts to inspect construction, so its 1,020 mesh instances are not the production draw-call count. No device performance or FPS conclusion follows from this review.

At the unchanged default overhead camera, fine wheel and lamp details become small. The roof, glass arrangement, overall outline and large highlight shapes remain visible. Prioritising those forms helps both Garage and racing. The production-camera capture uses the normal camera profile over a diagnostic studio, not an actual race scene.

## Proposed design sequence and acceptance

1. Approve one cohesive Lucid-inspired silhouette in neutral grey: exact side, front, rear, top and the existing Garage view. Keep the fictional identity and physical constraints.
2. Refine continuous cabin/body/front/rear surfaces. Review broad highlights from several angles before reinstating detail.
3. Fit glazing, panels, lamps, mirrors and wheels to the approved surfaces, reallocating geometry within the existing budget.
4. Check both detail levels and both renderers at Garage and unchanged gameplay framing; then assess movement and device cost separately.

The narrow lighting, restrained trim, cleaner inward bonnet taper and improved rear lip are useful elements to keep. A whole-car form pass is the recommended next step; another isolated bonnet-seam adjustment is unlikely to deliver the requested quality.

## Commands, evidence and limits

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_electric_design.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-root=res://../docs/evidence/electric-design-review-2026-10-26/native' -CommandTimeoutSeconds 150
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_electric_design.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence-root=res://../docs/evidence/electric-design-review-2026-10-26/desktop-mobile' -CommandTimeoutSeconds 150
```

Both commands completed successfully on pinned Godot 4.7.2: 22 captures per renderer, zero PNG save failures and matching geometry. These are evidence-generation results, not 44 passed design-quality assertions. Initial direct invocation was blocked by the shell's execution policy; the standard process-scoped invocation above completed without changing system policy. Logs are retained under this evidence directory.

The capture script parsed and ran in both native processes. No production geometry, materials, handling, input, camera configuration, photos or prepared resources were edited. No broad replay/backend suite was necessary for this review. No physical-device test or attachment check, APK build, live mutation, deployment or owner-process restart was performed. The existing owner/device appearance and motion acceptance remains open, and the findings here remain unfixed by design.

The initial source audit detected concurrent `electric.tres` handling changes from electric-13 to electric-14. The diff was inspected and preserved, not reverted or included in the review checkpoint. All eight other monitored sources, including model authoring/assembly, finish/glass, presentation, studio, camera and simulation, remain byte-exact. The audit's initial stop is retained in the evidence; the final retention check explicitly excludes only that concurrent configuration change.

The local manufacturer images are review references only, kept outside `game/`; they are not production assets or redistribution licences. Exact download URLs and hashes are recorded in [report.json](evidence/electric-design-review-2026-10-26/report.json). A scoped text patch records the review script, this report, comparison board and documentation entries without staging or committing concurrent work.
