# Race menu HTML concept — 2026-10-25

Open [index.html](index.html) in a browser. It is a single self-contained file
(approximately 2.6 MB) with embedded fonts and artwork; no server or installation
is needed. This is a local menu prototype requested by the owner, not a change to
the public game website or the Godot client.

## Requirements and behavior

- **RMH01:** Race opens on a combined overview. Track of the Day and Weekly
  Rivalry appear side by side in landscape, with Free Race and Challenges below.
  Only the original main navigation bar remains; there is no second tab strip.
  Portrait layouts stack the featured panels without horizontal clipping.
- **RMH02:** The daily page presents a scenic track, route outline, car-specific
  sample best/record, seven-car picker and race-start preview.
- **RMH03:** Rivalry's overview card includes your position, points gap, a compact
  podium and all five track choices. A track opens Rivalry with that selection;
  Continue rivalry opens its retained detail view. Detailed standings and the
  Race action remain available there.
- **RMH04:** Free Race supports combined track/creator search, biome filters,
  favorites, random choice and recoverable empty states. Filters survive mode changes.
- **RMH05:** Challenges supports Discover/Friends/Joined/Created folders, local
  joining and local challenge creation. The 3×3 form fixes three tracks and three
  tries on each. Challenge races retain their pinned car.
- **RMH06:** Race buttons open the selected track/car preview. Five red lights
  illuminate, then extinguish; the return action restores the originating menu.
- **RMH07:** The main Race navigation stays available when content scrolls.
  Detail pages also have Back to Race actions. A fresh opening starts on the
  overview; filters, car, challenge folder and track selection survive internal
  navigation. Demo state remains in memory.

The footer identifies sample content. Counts, events, routes, names, standings and
times are illustrative, not live game data. The countdown uses the UTC day/week;
the sample featured track does not rotate. Preview start demonstrates the menu
transition and does not run racing physics. Challenge creation does not send an
invitation or persist an online challenge. No network/account/game-data access,
physical-device test, APK, deployment or owner-process restart was performed.

## Sources and assets

Editable source: `index.template.html`. `build_demo.py` embeds existing project
fonts/artwork into `index.html`. `embedded-assets/` contains browser-encoded WebP
copies used only by this concept; no source game asset is modified.
`assets.json` records original and embedded SHA-256 hashes; `optimized-assets.json`
fences reuse of cached copies against their original source hashes.

The existing `discovery-biomes.png`, workshop backdrop, vehicle pictures and
approved challenge illustrations provide the visuals. Route diagrams and icons
are native SVG in the HTML. No new artwork provider or external dependency is
used by the resulting file.

## Actual validation

Commands run from the repository root:

```powershell
python docs/race-menu-demo-2026-10-25/build_demo.py
.tools/backend-venv/Scripts/python.exe docs/race-menu-demo-2026-10-25/build_demo.py --optimize
.tools/backend-venv/Scripts/python.exe docs/race-menu-demo-2026-10-25/review_demo.py
```

Final real Edge/Playwright overview review: **97 checks passed, zero failed**, with no
JavaScript errors and no HTTP requests. Review sizes: 1440×1000, 1280×800,
960×540, 844×390, 390×844 and 320×568. The review exercises real buttons/forms,
overview/detail state, car changes, challenge car pinning, filters, favorites,
markup-safe creation, five-light sequence, fresh overview entry, horizontal fit,
side-by-side/equal-height panels, heading/countdown fit and persistent main-menu
access after scrolling. All four choices fit without scrolling at 1280×800,
960×540 and 844×390. Desktop browser emulation is not a
physical Android result.

The first probe retained in `evidence/initial-browser-report.json` stopped at a
case-sensitive text check against a visually uppercase label. Inspection also
found that the initial large PNG data URLs exceeded browser CSS-variable limits;
`initial-missing-scenery.png` records that visual defect. Smaller embedded WebP
assets corrected it, and the final review explicitly checks the applied scenery.
The form's hidden-state handling and compact navigation were corrected before
the passing final review. No checks or existing game assertions were weakened.

`evidence/home-layout/browser-report.json` records the current results; its PNG
captures show the revised overview and retained details. The earlier tabbed
prototype's results and captures remain historical evidence. Owner visual/touch
acceptance remains. Initial revised-layout checks found the lower two choices
slightly below the fold at 844×390 and 960×540; compact spacing corrected this
while retaining the original no-scroll assertion.

`evidence/source-review.patch` is the task-only Git-checked checkpoint of the
editable sources, documentation, manifests and standalone HTML. The generated
WebP cache and review screenshots remain alongside it; the standalone HTML needs
neither to run. `evidence/deliverables.json` records final file hashes.

To rebuild from the cached assets, use ordinary Python. Refreshing the optimized
copies and running the review uses the already installed Playwright environment
and local Microsoft Edge.
