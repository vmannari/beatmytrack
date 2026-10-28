# Race menu HTML concept — 2026-10-25

Open [index.html](index.html) in a browser. It is a single self-contained file
(approximately 2.6 MB) with embedded fonts and artwork; no server or installation
is needed. This is a local menu prototype requested by the owner, not a change to
the public game website or the Godot client.

## Requirements and behavior

- **RMH01:** Four named, persistent mode buttons: Track of the Day, Weekly Rivalry,
  Free Race and Challenges. Keyboard arrows/Home/End work on the tab strip; mode
  touch targets remain at least 52 CSS pixels tall at the reviewed sizes.
- **RMH02:** The daily page presents a scenic track, route outline, car-specific
  sample best/record, seven-car picker and race-start preview.
- **RMH03:** Weekly Rivalry has equal podium cards, standings, five selectable
  tracks and a Race action for the selected track. Mode changes retain selection.
- **RMH04:** Free Race supports combined track/creator search, biome filters,
  favorites, random choice and recoverable empty states. Filters survive mode changes.
- **RMH05:** Challenges supports Discover/Friends/Joined/Created folders, local
  joining and local challenge creation. The 3×3 form fixes three tracks and three
  tries on each. Challenge races retain their pinned car.
- **RMH06:** Race buttons open the selected track/car preview. Five red lights
  illuminate, then extinguish; the return action restores the originating menu.
- **RMH07:** Navigation stays available when content scrolls. Responsive layouts
  cover desktop, landscape phone and portrait browser widths. The last mode is
  remembered for the browser session; other demo state is in memory.

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

Final real Edge/Playwright review: **96 checks passed, zero failed**, with no
JavaScript errors and no HTTP requests. Review sizes: 1440×1000, 1280×800,
960×540, 844×390, 390×844 and 320×568. The review exercises real buttons/forms,
mode state, car changes, challenge car pinning, filters, favorites, markup-safe
creation, five-light sequence, keyboard navigation, session return, horizontal
fit and persistent mode-button access after scrolling. The 844×390 daily Race
button is reachable without scrolling. Desktop browser emulation is not a
physical Android result.

The first probe retained in `evidence/initial-browser-report.json` stopped at a
case-sensitive text check against a visually uppercase label. Inspection also
found that the initial large PNG data URLs exceeded browser CSS-variable limits;
`initial-missing-scenery.png` records that visual defect. Smaller embedded WebP
assets corrected it, and the final review explicitly checks the applied scenery.
The form's hidden-state handling and compact navigation were corrected before
the passing final review. No checks or existing game assertions were weakened.

`evidence/browser-report.json` records the final results; PNG captures show all
four modes and compact layouts. Owner visual/touch acceptance remains.

`evidence/source-review.patch` is the task-only Git-checked checkpoint of the
editable sources, documentation, manifests and standalone HTML. The generated
WebP cache and review screenshots remain alongside it; the standalone HTML needs
neither to run. `evidence/deliverables.json` records final file hashes.

To rebuild from the cached assets, use ordinary Python. Refreshing the optimized
copies and running the review uses the already installed Playwright environment
and local Microsoft Edge.
