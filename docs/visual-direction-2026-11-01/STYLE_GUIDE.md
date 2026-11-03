# Beat my track: visual direction

**Superseded in scope:** the owner clarified that the goal is visual consistency using the current game and feasible user-created-track data, not a more elaborate generated world. Use [the grounded direction](GROUNDED_DIRECTION.md) as the primary resource. The material and palette notes below are optional context, not a request to create new scenery, remake vehicles or add landmarks.

**Status: proposal for review, 1 November 2026.** This is a design resource, not an approved specification, a description of the current build, or a production change. The accompanying [simplified race concept](race-simplified-concept.png), [detailed race concept](race-concept.png) and [visual coherence concept](visual-coherence-concept.png) are AI-generated illustrations of imagined tracks, not screenshots or ready-to-ship assets. The detailed images are deliberately aspirational and their foliage, water, lighting and geometry have not been shown to fit the game's performance budget. The simplified image is a closer starting point for world detail, not an approved low-poly style or a performance guarantee. Neither race image specifies functional controls: the simplified view omits them, and the detailed one omits pedals and other necessary information. The written rules below take precedence where an image conflicts with them. See the [resource index](README.md) for how to use each image and the original prompts.

## Creative direction

**Tactile miniature motorsport.** Give the game the warmth and clarity of a carefully made miniature racing world, with believable paint, rubber, asphalt, weather and mechanical details. Keep the existing yellow-and-dark identity, the playful variety of vehicles, the distinctive logo, and the creative track-building spirit. Cars, props and scenery should feel like they belong to the same world even when a biome changes.

- Favor recognizable silhouettes, a few confident shapes, clean edges, and controlled surface detail over photorealistic noise. Let material and lighting create depth; avoid a flat, toy-block finish.
- Make the player's car, the upcoming road and important feedback easy to see first. Give landmarks visual character without competing with the road.
- Use the same visual language through discovery, garage, creation, race and results. A preview can be more cinematic than gameplay, but it must truthfully represent the actual track, biome, landmarks and atmosphere that the player will encounter.
- Retain each car's proportions and character, existing user liveries, vehicle identifiers and gameplay. This direction does not authorize replacing a model or changing camera, controls, handling or content.

## Palette and contrast

These are **proposed sRGB starting values**, not measurements or existing game tokens. Adjust colors only after checking actual rendered contrast across states and backgrounds.

| Role | Proposed value | Use |
| --- | --- | --- |
| Canvas / dark ink | `#091722` | Outer background; text on the yellow action |
| Surface | `#102331` | Cards, HUD backing, panels |
| Border | `#345264` | Quiet boundaries; do not rely on it alone for essential state |
| Primary text | `#F2F5F5` | Main labels, timing and icons |
| Secondary text | `#ADC1CC` | Supporting labels and metadata |
| Racing yellow | `#FFD646` | Primary action, current selection and important achievement |

For these *opaque* pairs, calculated WCAG relative-luminance contrast ratios are: primary text on surface **14.66:1**, secondary text on surface **8.63:1**, dark ink on yellow **12.93:1**, and yellow on surface **11.45:1**. These calculations do not establish the contrast of translucent HUD panels over changing scenery, gradients, disabled controls or other combinations. Check those actual composites separately. Use at least **4.5:1** for normal text and **3:1** for large text and necessary non-text controls as initial review targets. Always pair color with a label, shape or other cue for selection and status.

Yellow means something: use one dominant yellow action per view and reserve other yellow marks for useful emphasis. Give biomes their own colors in the world rather than recoloring the interface wholesale. Bright road markings and effects remain distinct from primary UI actions.

## Materials, light and scale

The target is a coherent material family, not one identical shader on every object. Use broad, legible color regions and restrained roughness variation. Painted metal should hold a soft highlight; rubber should be darker and rougher; glass should read as glass without becoming a mirror; trackside wood, concrete and metal should each have a recognizable finish. Avoid razor-sharp highlights, dark outlines around everything, and excessive micro-scratches.

At the driving camera, asphalt should be quiet enough to see the car, road edge and markings; terrain should have a clear medium-scale shape without a glittery or strongly repeating pattern. Check texture frequency at race zoom and phone size, not just in a close-up. Use lighting to separate car, road and surroundings in both day and night; keep night atmospheric while making the upcoming corner visible. Rain, dust and snow may enrich the scene but must leave the driving line and hazards readable. Do not introduce costly effects without measuring target-device performance.

Use consistent perceived object scale and sensible ground contact. Shared props may have slightly softened edges and simple materials, but retain enough silhouette and color separation to be recognizable from above. Group objects into plausible places, leaving open space around the racing line.

## Vehicles and garage

Give every vehicle the same level of care in paint, glazing, lights, tyres and contact shadows without making the Compact, kart, forklift, hovercraft and other cars resemble one another. At race scale, emphasize each vehicle's roof, shape, color blocking and direction of travel. At garage scale, use smooth formed surfaces and readable fitted parts; avoid adding fine seams and mesh detail that do not improve either view.

The garage is a welcoming workshop and a place to celebrate the player's car. Keep its existing identity and the selected vehicle as the visual hero. Make thumbnails large enough to compare the vehicles rather than repeating the room at the expense of the car. For paint, patterns, parts and stickers, show the appearance directly on the car and use clear selection states. Preserve the owner's chosen liveries and preview/camera interactions.

## Biomes, tracks and preview images

Each biome needs a distinct but related palette and material treatment: grass can be lush and warm; desert dusty and sunlit; winter cool and crisp; storm muted and wet; night legible with controlled light. These are starting points, not a new biome list or content mandate. Use a small number of strong landmark silhouettes, grouped into one or two memorable places along a featured course. Do not fill empty space simply to increase object density.

For a track card, render or derive the image from the actual track revision and its real biome, geometry and authored objects. Use a higher or more cinematic camera if useful, but do not invent mountains, forests, buildings or weather absent from that course. Keep the route diagram and text legible over the image using a predictable backing or gradient. Generated concepts can inform composition; they are not a substitute for a truthful track preview.

The editor should use the same terrain and object vocabulary as the race, with a clear distinction between authoring overlays and the world. Handles, selected objects, snap indicators and errors must remain visually obvious over every biome. Keep the creator's actual authored layout and the current functional workflow intact.

## Menus, race HUD and results

Menus retain the existing dark surfaces, strong logo, recognizable yellow action and concise hierarchy. Use one primary action, clear section titles and quiet secondary information; expose complex detail progressively where appropriate. Add understandable labels to unfamiliar icons and maintain consistent icon weight, corner treatment and spacing. Use a readable body face with a condensed display face only where it remains legible; use tabular numerals for changing times. Preserve script coverage and allow labels to wrap or reflow in all supported languages rather than forcing uppercase or shrinking indefinitely.

The race HUD should feel related to the menu: simple light icons, quiet dark translucent backings where needed, and restrained yellow for meaning. Replace the visual impression of separate chrome widgets with a shared, consistent treatment, while preserving configurable controls, their placement and touch behavior. Keep the central road and car visible, account for the user's fingers and device safe areas, and ensure each control has an identifiable pressed state.

Results should celebrate the player's actual achievement with one clear result, a useful next step and supporting detail available without overwhelming the screen. Apply the same typography, icon and color roles used in menus and on the track. Do not imply an award, standing or progress that the data does not support.

## Review and acceptance

Before implementation, review the proposed direction with the owner. After any later implementation, compare a real first-race journey: track selection, garage, countdown, driving, finish and return. Use the same track and car for the preview and race comparison. Include the track editor, an empty/offline state, customisation, an achievement, and long translated labels.

Review captures at desktop size and at landscape phone dimensions including **844 × 390** and a smaller supported viewport. These are comparison sizes, not proof of physical readability: test on actual phones at ordinary viewing distance and brightness, with fingers on the controls. As starting targets, aim for **48 × 48 density-independent pixels** for touch targets, preserve existing adjustable layouts and system safe areas, and verify the real physical size rather than equating screenshot pixels with dp. Confirm that the car, road edges and next turn are identifiable in daylight, rain, desert glare and night; test overlays against both the lightest and darkest relevant scenery. Confirm text and essential icons meet the contrast targets above in every state. Ask a first-time player to identify the next action and current mode without coaching.

Capture with the actual game on each supported renderer and relevant device; image concepts do not establish runtime appearance, accessibility, frame rate or cost. Check frame time, memory and texture costs before accepting art changes. Record unresolved issues and compare like-for-like screenshots; do not infer an improvement from a different camera, track or lighting alone.

## Suggested sequence for later work

1. Agree on this direction and choose one starter car, one representative track and the core selection-to-result journey.
2. Prototype a truthful track card and race view with shared materials, HUD and lighting; keep the actual mechanics and content intact.
3. Test the complete slice on a real phone, including readability, controls, translations and performance. Refine the guide from observed results.
4. Apply the accepted rules to garage, editor, other cars and biome kits in small batches, checking compatibility with existing saves and player-created tracks.

## Existing visual references

These are dated native captures used for design context, not proof of the latest build or a physical-phone test:

- [Daily page, desktop](../evidence/daily-medal-page-2026-10-31/silver-1280x720.png) and [phone-like resolution](../evidence/daily-medal-page-2026-10-31/silver-844x390.png): strong page hierarchy and a scenic card to reconcile with the real race.
- [Race view and HUD](../evidence/renderer-comparison-2026-10-31/mobile/star-0.png): actual camera and HUD visual language.
- [Garage and car lineup](../evidence/hovercraft-sport-redesign-2026-10-29/app-gl_compatibility/garage-lineup.png): vehicle presentation and workshop identity.
- [Storm race view](../evidence/storm-five-tracks-2026-10-25/gl_compatibility/storm_freight-drive.png): weather, road, props and race-camera scale.
- [Night race view](../evidence/night-terrain-2026-10-16/gl_compatibility-Windows/view-0-after.png) and [desert race view](../evidence/desert-sand-terrain-2026-10-23/gl_compatibility/calm.png): lighting and material readability examples to recheck in the current build.
- [Track editor](../evidence/track-editor-fixes-2026-10-28/native/gl_compatibility/01-separated-road-controls.png) and [sticker workbench](../evidence/sticker-workbench-2026-10-29/after/gl_compatibility/gallery-844x390-top.png): authoring overlays and customisation at phone-like resolution.
