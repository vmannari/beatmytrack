# Visual direction and UI specification / v2.0

Revision: 11 September 2026. This file supersedes the v1 light/teal visual proposal. It records the user's selected references and the latest 15% camera-framing adjustment. Reference-based mockups are not production engine screenshots, original vehicle assets or proof of AAA execution.

## 1. Reference authority

| Reference | Authoritative for | Not authoritative for |
|---|---|---|
| `references/gameplay_approved.png` | High, oblique overhead camera; distant car-to-viewport proportion; compact track; graphic-novel environment | Old HUD, obsolete 0%/000 KPH data, exact vehicle brand |
| `assets/gameplay_camera_115.png` | Requested next framing target: entire scene at 1.15 times the reference's linear image size | A newly rendered 3D scene or a larger car mesh |
| `references/menus_only.png` | Mature cel-shaded presentation; dark menu surfaces; quiet type; vehicle-led composition; restrained highlights | Final economy, timing, content names or approved screen behaviour |
| `references/menus_style_reference.png` | Unchanged source board for provenance | Its top-row rear chase cameras: explicitly rejected for gameplay |
| `references/cel_shading_reference.png` | Matte planes, restrained palette, selective contour lines, stepped light and believable vehicle proportions | A mandatory SUV, Rivian branding, night scene or setting |

In any conflict, the latest explicit user instruction and the gameplay framing target override the menu board. No newly generated poster, chase-camera render, glossy supercar illustration or v1 whole-circuit gameplay mockup is included as an active design target. CIRCUIT / 01 remains only the original package's working label; no new brand is introduced.

## 2. Camera and world presentation

Use a real 3D scene presented from a high, oblique overhead following camera. The car is a small but readable part of the viewport, not a hero vehicle filling the lower third. Show nearby track and the upcoming corner; do not require the whole circuit to fit. Keep the pitch/yaw character of the gameplay reference, with no horizon, sky band, rear chase angle, cinematic camera roll or large perspective expansion.

The approved adjustment is **15% larger in linear on-screen size**, achieved by tighter camera framing of the whole scene. Do not scale only the car mesh, change wheelbase, widen/narrow the road or change collision geometry to obtain the effect. A 1.15 linear zoom gives 1.3225 times the image area for the same object; it does not mean 15 percentage points of viewport height.

For an orthographic implementation, divide the baseline camera extent by 1.15 (multiply by 0.869565). Moving an orthographic camera closer by itself does not change object size. For perspective, begin with the same pitch and field of view and calibrate distance against the target; distance / 1.15 is a local approximation, not an exact whole-scene match for different depths. A field-of-view adjustment is another option, not permission to introduce a low chase camera. Camera3D supports both projection families. [S21]

The supplied 1672 × 941 image was scaled about a normalized (0.50, 0.76) anchor. This anchor is a calibration composition, not a demand that the live car remain at the bottom while driving south. Live follow/look-ahead must be checked through a complete lap in all headings. Keep world yaw stable; translate using interpolated car position and bounded velocity look-ahead. Disable dynamic zoom in the first framing comparison. Any later speed zoom needs owner review and cannot undo the accepted car visibility.

Calibrate at the reference aspect ratio first, then preserve vertical world coverage on wider landscape phones and reveal additional horizontal space. Do not stretch the rendered image. Keep UI safe insets separate from world framing. Camera settings and HUD sizes are independent; the 15% adjustment must not enlarge buttons or text. See `Camera_contract.json` for machine-readable acceptance values.

## 3. Mature cel-shaded art language

Use believable, clean vehicle geometry with distinctive silhouettes and readable noses, glass and wheels. Reduce detail at gameplay scale rather than giving the car toy proportions. Paint uses broad, controlled colour planes and limited stylized highlights. Avoid chrome-heavy reflections, wet showroom gloss, plastic sparkle, random scratches and high-frequency texture noise.

Use a small number of tonal bands as the initial art target, with crisp but stable lighting boundaries. Contour strokes emphasize silhouettes and selected structural edges, not every triangle or blade of grass. Outlines must remain readable without flickering while the camera moves. Trees and rocks need authored shapes and consistent scale, not cubic placeholders or oversized candy-like vegetation. Use restrained natural greens and stone colours; reserve a clear accent for a vehicle or relevant UI state.

Maintain separation between car, asphalt, curb and shadow. The selected reference establishes style, not a requirement to make every scene dark: tune values on a real phone under bright ambient light. The nose and heading must remain recognizable even in tree shadow. Smoke, dust and tire traces communicate slip briefly and may not conceal the next braking point. Do not add road arrows, glowing boost meters or decorative effects unless gameplay requires them.

AAA is the quality ambition, not the project size or a promise that generated reference images equal finished assets. Acceptance is coherent models/materials, legible motion, stable frame pacing, polished input/audio/UI and no visible procedural seams on the actual device. One finished car and one finished corner establish the bar before multiplying content.

## 4. General menu system

Menus use deep blue-charcoal surfaces, off-white text, quiet blue-grey separators and restrained rounded corners. A light, solid primary button carries the main action. Use gold only for league/reward emphasis and signed green/red deltas only where they mean improvement/regression. Do not use a rainbow of currencies, neon glows, glass cards, large sales badges or decorative gradients over text.

Use the menu reference's vehicle-led composition: a larger car is appropriate in the garage and home menu, but never changes gameplay framing. A menu can use an independent showroom camera over the same production car asset. Backgrounds remain subordinate to readable controls. Prototype art excerpts are low-resolution reference crops and must be replaced by original, licensed, in-engine assets for shipping.

The functional screen map remains Play, Garage, League, Tracks and Create, with Store/Settings secondary. The menu board is visual inspiration, not authority to remove the editor, global histogram, neighbourhood or free progression. No new premium currency, login-streak reward wall, nitro purchase or paid tune is added merely because an image contains a suggestive icon.

## 5. Screen contracts

| Screen | Composition and behaviour |
|---|---|
| Home / Play | Vehicle-led art with one prominent Race action; selected event and expected duration; one next earned upgrade; league cue; friend challenge accessible. No forced store visit. |
| Race | Full-bleed high-overhead world. Lap top-left, race timer near top-centre, pause top-right. Small rival gap; optional unobtrusive speed. Steering bottom-left; brake/throttle bottom-right; movable touch zones. No money or XP HUD. |
| Results | Race time and PB first. Preserve global histogram and performance neighbourhood; one PB per comparable driver. Rewards and Retry remain visible. The board's simple results table is inspiration, not a substitute for the distribution. |
| Garage | Large original vehicle render; earned level/XP and class; simple part list; selected part's trade-off, requirements and earned-credit install action. Optional car strip. |
| Tuning | Quiet part categories and a few labelled controls; effect/trade-off clear; Apply, Reset and Test drive. No charge to retune. Render and tuning sliders are illustrative until implemented. |
| League | Division and settlement state; three event rows; personal time, rules and standings. Best result affects rank; every legitimate attempt still earns. No time-locked event invented from the source board. |
| Tracks | Scenic preview, concise lap/rules/creator facts and navigable track list or gallery. Challenge code/import accessible. Receivers play for free. Preview camera may be scenic; driving camera may not be. |
| Editor | A separate overhead planning view is permitted so the complete route can be edited. Same dark UI language. Test drive switches to the approved follow camera; exact road/collision data shared. |
| Challenge | Sender, target, pinned version/rules, ghost and free Race action. Explicit unavailable/incompatible states. |
| Store | Creator capacity and cosmetics only under the existing proposed catalogue. State quota before payment, restore and cancellation. No sale of power or driving progression. |
| Settings | Controls, motion, audio and account/privacy. Touch sizing, handedness and reduced motion are independent of world camera zoom. |

## 6. Layout tokens / proposed implementation values

| Token | Value / rule |
|---|---|
| Background | #172129 |
| Raised surface | #24333E |
| Primary text | #EDF1F3 |
| Secondary text | #A6B1B8 |
| Separator | #35434E |
| Main action | #E0E7ED with #152129 text |
| Positive / negative | #A6CE91 / #D58A82, always accompanied by signed text |
| League accent | #DAB266, not a second purchase currency |
| Spacing | 8-unit base; 16 / 24 / 32 groups |
| Type | System sans in prototype; production font chosen with provenance. Tabular digits for timing. No supplied font files. |
| Touch | Minimum 48 logical units proposed, larger adjustable driving zones; validate on physical devices. |
| Typography | Body 16–18 logical units; key timers 40–56; do not scale a desktop screen down and call it phone-tested. |

## 7. Artifact status

`UI_reference_gallery.html` presents the reference authority and exact framing mockup. `UI_prototype.html` preserves navigation and simulated interactions in a restyled 11-view prototype. `screens/` and `UI_designs.pdf` are regenerated from this revision, not the v1 light interface. The HTML is not an executable game, online leaderboard, purchase integration or full track editor. Final UI compositions remain reviewable proposals under the selected art/camera direction.

[S21] Godot Camera3D, official stable documentation, checked 2026-09-11: https://docs.godotengine.org/en/stable/classes/class_camera3d.html
