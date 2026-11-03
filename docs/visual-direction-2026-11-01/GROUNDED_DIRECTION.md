# A consistent visual language for the existing game

**Design proposal, revised 1 November 2026.** The purpose is to make track selection and racing feel like the same game, including for player-created tracks. This is a presentation design only; no game functionality, track generation, published data, saves or assets are changed by this pack. The concepts use existing game captures and vector overlays. Nothing here implies that the game already generates per-track images.

## The design decision

Keep the game's existing tracks, scenery, cars and overhead camera as the visual truth. Use the clean, dark menu surfaces and yellow emphasis as the common interface language. Present track geometry honestly as a **track map**; do not surround it with scenery that looks like a literal depiction of that particular course. Simplify the race controls' finish to match the menus while keeping the player's control scheme and layout intact.

This is achievable in principle without making user-created tracks produce rich landscapes, generating art for every track, creating new biome objects or remodeling cars. It is a proposal based on source inspection, not a tested implementation plan or a promise about performance.

## Visual examples

- [Track-card concept](truthful-track-card-mockup.svg): a real captured track and route presented as a card, alongside the same track's race view. It is a static composition made from existing captures; it does **not** show a feature that currently exists for arbitrary user tracks.
- [Race HUD concept](race-hud-mockup.svg): the existing race scene with a proposed quieter, menu-related HUD. This is a design overlay, not an interactive or tested control layout.
- [Earlier token sheet](visual-tokens.svg): surface-treatment exploration only. Its colors were proposed independently; use the existing game palette listed below as the starting point instead.

The image-based concepts are from dated native desktop captures. The source and concept labels distinguish captures from designed overlays. They do not show every biome, car, viewport, language or touch configuration, and cannot prove usability or target-device performance.

## Track cards: map first

Today, [`TrackTile`](../../game/ui/track_tile.gd) draws route paths derived from saved `pieces` or `points` over shared biome illustration; [`TrackOfDayArt`](../../game/ui/track_of_day_art.gd) uses that same approach for the daily feature. The route and background are separate: the backdrop is biome artwork, not a unique rendering of the creator's authored objects. Cloud catalog data can be [metadata-only](../../game/backend/cloud_tracks.gd), so a card cannot assume it already has a complete creator document, road surface or object placements. The concern is the visual expectation created by the background, not the accuracy of the route.

**Recommended first design:**

1. Keep the actual saved route, its existing fitting behavior, direction/start indication where available, title, creator and biome label.
2. Put that route on a quiet navy/charcoal map surface with a restrained biome-tinted color field or clearly graphic texture. The surface should read as a *diagram*, not a photographic landscape or a promise that scenery is present.
3. Keep the map and track name prominent. Use the same framing, linework, type and yellow accents as the rest of the menu. Do not fabricate objects, geometry, track width or landmarks from the route line.
4. If no usable route is available, show an honest neutral placeholder and the known metadata. Do not substitute a generic route or hold up navigation for an image.

This first direction can use the kind of bounded metadata already drawn by the cards. Rendering and validating all track variants, malformed or absent routes, different aspect ratios, complex overlapping pieces and mobile cost still need implementation investigation. A route diagram does not show elevation, surface changes or scenery unless trustworthy data is explicitly available and legibly represented.

**Optional later enhancement:** where a reliable image of the exact track revision already exists, a card may use it behind or beside the map. A future capture pipeline would require separately solving track availability, creation cost, camera framing, caching, invalidation, device memory, offline and error states, and any publication/storage changes. Existing individual `TrackShowroom` code is not evidence that cheap, current images already exist for every local or remote card. A missing or stale image must fall back to the map. This enhancement is not required for the recommended first design.

## Race HUD: same visual family

Use the existing menu's flat dark-blue surfaces, clear light symbols, subtle borders and selective yellow accent for the HUD. Replace the *appearance* of photographic chrome, not its control behavior. Buttons can remain slightly translucent so the track remains visible, provided symbols and outlines stay legible over both bright and dark scenery.

The existing [`MenuStyle`](../../game/ui/menu_style.gd) provides concrete starting values: ink `#080F16`, panel `#101E29`, text `#F1F4F3`, muted text `#A4BAC7`, accent `#FFD348` and border `#344E5D`, with Barlow body and Barlow Condensed display fonts. The mockups are illustrative; actual translucent composites and states still need contrast checks.

- Keep the car, road and upcoming corner central. Use simple, consistent treatments for steering, pedals, handbrake, map, timer, lap, speed, reset and pause.
- Keep recognizable control silhouettes and labels where enabled. Give pressed controls a visible fill/outline or shape change in addition to color. Show disabled and hidden states correctly for the active vehicle and control mode.
- Respect existing configurable position, scale and opacity, button and analog/joystick alternatives, pedal modes, independent touches, optional labels and safe areas. Analog and single-pedal cars have different controls, including a D/R selector where applicable. The illustration shows only one illustrative configuration and does not specify hit boxes or new defaults.
- Check icons, text and translucency in motion against daylight, rain, desert and night; test normal and pressed states at real phone size. The same transparent panel can have very different contrast over different terrain.

Current art is drawn by [`TouchControlArt`](../../game/ui/touch_control_art.gd); control layouts and touch behavior are separately managed in [`TouchControls`](../../game/ui/touch_controls.gd) and [`ControlLayout`](../../game/input/control_layout.gd). Those boundaries are useful for discussing a visual-only change, but a future implementation would still need regression tests for configuration, interaction and performance.

## World, props and cars

The design does not require a new scenery generator or a global rebuild. Existing cars, props, weather, tracks and user-authored arrangements stay the reference for the world's level of detail. Any later polishing should happen selectively, based on the current assets and device budget. The main unifying changes here are in the **presentation around the world**: honest maps, matching UI materials, readable overlays and consistent colors and typography.

## Evaluation if the owner later chooses implementation

Compare the same real user-created track across selection and driving. Include sparse and dense tracks, each biome, missing route data, offline/cached states and a long title/translation. Verify that the map matches its source data and that any optional image matches the exact track revision; no extra scenery or route should be implied. Inspect actual gameplay at desktop and phone sizes, including landscape safe areas and all supported control modes, then test on real phones. Measure load time, memory and frame time; no per-card 3D rendering or new asset production is assumed. Capture results with actual current builds and record exceptions.
