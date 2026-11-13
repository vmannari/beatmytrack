# Track editor: UX, UI and object-quality review — 28 October 2026

The editor is capable, but its interaction rules require too much discovery through trial and error. The object library has a reasonably coherent stylized identity. Its biggest visual weakness is how much of that identity disappears at the actual editing scale, especially in dense overview mode.

This review concentrates on the experience of choosing, placing and editing roads, surfaces and scenery. It includes a fresh native walkthrough, all **55 catalogue variants** rendered through the production thumbnail builder, and arranged object inspections through the actual editor world. These are scripted desktop observations and visual judgments, not a human usability study or Android touch test. No production fixes are made by this review.

## Main usability issues

### UX01 — Opening an object's options changes your choices

This is the clearest everyday workflow defect. Reopening the tree options changes Large / 1.5× back to Medium / 1×. Reopening guardrail options changes Curve placement back to Single. Selecting Boulder and tapping the highlighted Rock family tile changes the choice back to Rock, without opening the options.

These are actual production callback results, recorded in [`walkthrough.json`](evidence/editor-experience-2026-10-28/mobile/walkthrough.json). [`ObjectBrowser._activate_asset`](../game/editor/object_browser.gd:219) always chooses the asset before deciding whether to open its options. [`App._choose_object`](../game/core/app.gd:5705) resets scale and placement. The family tile also compares the exact kind rather than family membership.

The user expects inspecting settings to preserve them. Keep the current variant, size and placement when opening an inspector. Give options an explicit affordance and a title naming the object. The existing second-tap behavior is also difficult to discover: most cards do not indicate that another tap reveals size, variants or run placement.

### UX02 — Picking small or nearby objects is unreliable

At 6 px/m, a tap exactly on one cone selected a different cone four metres / 24 screen pixels away. The selected neighbour was later in the object array. Both fall within the 30-pixel selection radius, and [`EditorCanvas._begin`](../game/editor/editor_canvas.gd:317) accepts the last-added candidate before considering which is closest.

This feels like the editor is ignoring the finger, especially when decorating a road edge. The large hit area is helpful for small props, but nearby candidates need sensible priority and an explicit way to cycle overlaps. Evidence: [`selection.json`](evidence/editor-experience-2026-10-28/mobile/selection.json).

### UX03 — The next action and current tool state are under-explained

The blank editor presents eight similarly weighted actions, starting with Start line, although a road is needed before placing one. Test and Publish are disabled without a visible short explanation of the missing step. After choosing a curve, instructions exist internally but the status label is hidden: the clean native walkthrough records `hint_visible=false` while the road preview is pending.

Road controls have large, usable targets, but most non-bridge geometry handles communicate through symbols alone. A new user must infer which one changes width, radius or lead-in. The yellow tick means committing a new preview in one state and finishing the current selection in another. Object placement and selection also change automatically depending on what is tapped.

Keep a short contextual instruction visible: “Drag an end to reshape; tick to place,” “Tap ground to place Pine tree,” or “Select an object to edit.” Show the active parameter and unit while dragging. A compact first-use sequence would help: choose section → reshape → place → connect → place start → test. This need not be a blocking tutorial.

Evidence: [`first entry`](evidence/editor-experience-2026-10-28/mobile/01-first-entry.png), [`first curve`](evidence/editor-experience-2026-10-28/mobile/02-first-curve.png), [`selected hairpin`](evidence/editor-experience-2026-10-28/mobile/08-hairpin-selection.png).

### UX04 — Dense overview turns recognizable props into anonymous shapes

The current editor deliberately reduces detail with at least 24 visible authored objects and a scale below 8 px/m, or while moving the view. The threshold is broad enough to affect ordinary scenery editing.

In a 32-object inspection at 6 px/m, cars, crates, barrels and huts become similar beige rectangles or boxes; trees and rocks become simple discs. Several meaningful colours and distinguishing silhouettes disappear. The same view with detailed presentation enabled makes the objects recognizable again. This is a presentation choice, not evidence that the original models lack detail.

Preserve recognizability in simplified meshes: a car should retain a car silhouette, a cone its orange taper, a barrel its round form. An explicit editing-detail control and a visible indication of simplified overview would also make the change less surprising. Performance still matters; replacing everything with full detail is not the only remedy.

Evidence: [actual default overview](evidence/editor-experience-2026-10-28/mobile/09-dense-normal-overview.png), [same framing with full detail](evidence/editor-experience-2026-10-28/mobile/10-dense-full-comparison.png). The relevant policy is [`editor_detail.gd`](../game/editor/editor_detail.gd:22).

### UX05 — Fine placement and bulk editing are limited

Ordinary object placement and dragging snap to whole metres. That is coarse for small cones, half-metre-deep signs, thin fences or props placed against a kerb. Zooming in does not expose a finer object-placement increment. The road Snap control does not provide a corresponding object snap control.

Object editing exposes a single selection. Copy, rotate, size and delete operate on that object; there is no visible group-selection workflow. Runs speed up initial fence/barrier placement, but adjusting a furnished area or moving a group afterward returns to individual editing.

For frequent track building, adjustable snapping, precise movement, multi-selection and group duplication would offer more practical value than adding further scenery variants. This is an assessment of exposed controls and workflow, not a claim that every editor needs a full desktop CAD feature set.

### UX06 — The UI sometimes describes a different thing from the result

Family thumbnails show the default model rather than the selected variant. Rock/Boulder and the tyre variants are therefore difficult to distinguish from the selected card alone. Jump thumbnails render the biome's default profile, while the selected jump style lives in a separate options control. A very low ramp is especially difficult to identify from its flat preview.

Surface labels and illustrations remain Grass, Sand and Water in Winter, where the actual palette is snow/ice coloured. The icons do not explain the seasonal interpretation. The properties popup is also sparse for simple objects and has no strong selected-object heading.

Use biome-aware material names/previews and show the current variant/style in the selected card or inspector. Improve the jump preview angle or profile diagram while preserving the intentionally restrained jump height and existing physics.

### UX07 — Surface controls are not fully contextual

Area mode retains the prominent Brush size control and the round/square brush options. The filled area is determined by polygon points; the area raster branch bypasses the brush-radius calculation. Changing brush size does not expand or shrink the filled polygon as the UI might suggest.

At the same time, useful commands such as Remove last point and Cancel surface live in the secondary options panel. Controls are distributed among the top-centre toolbar, bottom material palette and right-side panel. Prefer area-specific actions while drawing a polygon, and reserve brush size/shape for the modes that use them.

Evidence: [`surface discovery`](evidence/editor-experience-2026-10-28/mobile/07-surface-discovery.png), [`surface options`](evidence/track-editor-review-2026-10-28/native/mobile/06-surface-options-1280.png), and the area branch in [`track_compiler.gd`](../game/editor/track_compiler.gd:219).

### UX08 — Readability and visual hierarchy need a finishing pass

The dark panels, cyan selection and consistent rounded shapes provide a useful visual language. The remaining friction is practical: small 14-unit object captions, thin low-contrast props, labels that can exceed their tile width, and detailed terrain flecks competing with tiny authored objects. The expanded object popup uses a large blank panel for a simple size choice and can cover the area being edited.

The top header gives substantial space to track/creator identity while immediate construction instructions are hidden. Save/help/settings live behind an ellipsis. Recovery terminology such as WIP asks the player to understand storage implementation details. A clearer hierarchy would emphasize the active tool, selected item, next action and whether the current work is saved/testable.

At a smaller physical window the existing logical scaling helps, but phone legibility and finger occlusion still require an actual device check. Enlarged contact sheets in this report must not be mistaken for the size of the live palette cards.

## Visual object quality

The assets are generally **competent stylized low-poly scenery with an uneven finish**. I did not see a reason to replace the entire library. The better pieces have recognizable construction and useful details; the weaker pieces need stronger silhouettes, material separation or presentation.

| Group | Current assessment |
| --- | --- |
| Container, crates, pallet, wooden fence, huts | Among the stronger assets. Corrugation, boards, rails, doors and roof details give them structure and identity. |
| Guardrails, concrete, tyres, cones, trackside signs | Generally clear and functional in the studio. Thin rails/signs need better map-scale readability. Small signs and narrow posts disappear quickly at the planning angle. |
| Igloo, snow castle, snow/ice lanterns, Ice Compact | Strong thematic identity and pleasing construction. White-on-white contrast hides some detail in the actual Winter editor. |
| Trees, bushes, rocks, flowers and grass | Coherent faceted style. Repetition and similar ground colours reduce variety/readability. Flowers, grass and pebbles can resemble the incidental ground flecks when placed. |
| Utility car, van and wreck | Readable, but among the simpler and more blocky assets. The wreck could communicate damage more strongly through its silhouette; in the current view it resembles another parked car in a different colour. |
| Cliff, ridge and larger rocks | Usable blockers, but the cliff's rectangular ends, stepped bands and flat base read like an isolated wall segment. Natural embedding and less repeated profiles would improve scenery composition. |
| Jump and speed bump | The speed bump has a clear functional stripe pattern. The default low ramp's thumbnail reads as a thin slab. Improve shape communication rather than exaggerating its requested low profile. |
| Pyramid, obelisk, columns and temple wall | Clear Desert theme with readable major forms. More restrained material/edge variation could reduce the repeated procedural appearance. |

These judgments refer to the actual built-in geometry, not generated concept art. The contact sheets use the production thumbnail builder and enlarge its normal 104×82 cards by 2×. The map inspections retain the production planning camera at 10 px/m, with detailed objects enabled naturally by the normal scale threshold.

Contact sheets: [variants 1–24](evidence/editor-experience-2026-10-28/mobile/atlas-01.png), [25–48](evidence/editor-experience-2026-10-28/mobile/atlas-02.png), [49–55](evidence/editor-experience-2026-10-28/mobile/atlas-03.png).

Actual editor inspections: [Nature](evidence/editor-experience-2026-10-28/mobile/objects-pine-nature_inspection.png), [Trackside](evidence/editor-experience-2026-10-28/mobile/objects-pine-trackside_inspection.png), [Props/buildings](evidence/editor-experience-2026-10-28/mobile/objects-storm-props_and_buildings_inspection.png), [Desert](evidence/editor-experience-2026-10-28/mobile/objects-desert-desert_inspection.png), [Winter](evidence/editor-experience-2026-10-28/mobile/objects-winter-winter_inspection.png).

## What has improved since the earlier review

Concurrent editor work added bright Night authoring lighting and a Race lighting preview control. The fresh view shows a much more usable authoring surface; the earlier nearly-black Night capture should not be treated as the current default. See [current Night authoring](evidence/editor-experience-2026-10-28/mobile/objects-night_city-night_authoring_inspection.png) and [Race lighting preview](evidence/editor-experience-2026-10-28/mobile/objects-night-race-preview.png).

Other correctness changes are also underway. This report does not restate the earlier cancel/admission/overlapping-control defects as freshly reproduced current findings. Its conclusions focus on the UX and visual issues actually inspected here.

## Recommended order

1. Preserve object choices when opening properties and make selection choose the intended object.
2. Make the active tool, next action, variant and dimensions visible through a compact contextual inspector.
3. Preserve object identity in overview and offer finer snapping plus basic group operations.
4. Refine biome-specific labels, thumbnail framing, small text and background contrast.
5. Spend asset-refinement effort on wrecked vehicles, cliff transitions, variation and small-prop readability before expanding the library.

## Evidence and limitations

UXR01–UXR08 cover interaction and UI findings; OQR01 covers the 55-variant visual review; UXR-Q01 covers evidence. [`report.json`](evidence/editor-experience-2026-10-28/report.json) records the current walkthrough, selection probe, executions and source hashes. The native helper records 17 walkthrough captures plus three contact sheets. The final walkthrough and selection probe finish with zero script errors; source hashes are stable within the accepted final runs. The sandbox certificate-store diagnostic remains in the engine logs.

The first two App walkthrough attempts encountered an intermediate concurrent `editor_history.gd` parse/dependency failure. Those attempts remain archived and are not used as a clean-run claim. A later history parse control passes, and the final native walkthrough is clean. One completed runner also hit a Windows console Unicode-print error after saving successful engine receipts; the runner output encoding is corrected. The review helper's distinct Nature/Trackside output filenames were corrected to avoid retaining older captures under a reused filename.

Production files, owner saves and processes are untouched by this review. Only a review helper, evidence runner and report are added. No device query/test, APK, backend write/deployment, authentication, purchase, clipboard sharing, or main-index staging/commit/merge was performed. Vulkan Mobile here means the desktop renderer on an RTX 3090. Actual phone readability, finger occlusion, touch accuracy and user learning remain acceptance work; no task-time or human error-rate claims are made.
