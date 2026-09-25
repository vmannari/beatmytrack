# Phase 0: specification review and first slice

2026-09-25 R01/V04/V05/Q01: Knot profiling reproduces steering-haptic stalls without collisions; bounded Android worker reduces 30-second frames >33 ms from 184 to 0/2. Stationary tyre solver saves ~20% in an 85-stack desktop microbenchmark; 13,200 exact equivalence checks pass. Corrected synthetic-touch probe, installed APK, phone evidence and known editor/model test failures: docs/KNOT_PERFORMANCE.md.

2026-09-25 R01/V03/V05/Q01: Settings directly exposes Buttons, Analog slider and Analog joystick, preserving saved layout geometry. Layout 211 + 72 synthetic and graphical menus 502 checks pass; compact screenshot inspected. Quick Android export/install/launch succeed; physical touch acceptance pending. See docs/ANALOG_STEERING_MENU.md.

2026-09-25 R01/V03/V05/Q01: Settings adds saved Off/Light/Medium/Strong steering haptics with preview. Menu 26, records 53, layout 199 + 72 synthetic and graphical menus 493 checks pass; compact evidence inspected. Android quick export/install/launch succeed; physical feel pending. See docs/STEERING_HAPTICS.md.

2026-09-25 R01/V03/V05/Q01: subtle steering-touch haptics (12 ms, amplitude 0.2), handheld adapter and Android vibration permission. Mobile input 555, layout 199 plus 72 synthetic checks and quick Android export pass; APK installed on attached phone. Physical haptic feel remains owner acceptance. See docs/STEERING_HAPTICS.md.

2026-09-25 V02/V04/V05/Q01: physical DN2103 winter profiling found bank-query overhead; presentation-only optimisation cuts stress particle CPU mean 21.3% and p99 29.7%, retaining 25 bank bursts. Final two-minute drive median 16.812 ms; actual-present window median 16.838/p99 17.057 ms. CaptureWinter 156 and quick export checks pass; APK installed, diagnostics removed, normal play restored. See docs/WINTER_PHONE_PERFORMANCE.md.

2026-09-25 V02/V04/V05/Q01: winter-spray-3 removes ice-drift tyre powder and replaces bank cloud billboards with immediate directional snow fragments. CaptureWinter 156 and TestSoil 163 checks pass; desktop evidence inspected. No device test/export. See docs/WINTER_TYRE_EFFECTS.md.

2026-09-25 V02/V04/V05/Q01: winter-spray-2 uses off-track snow chips during ice drift and a short 0.42-second burst at the swept body/bank contact. CaptureWinter 153, TestSoil 163 and TestIce 69 checks pass. Desktop captures inspected; no phone test/export. See docs/WINTER_TYRE_EFFECTS.md.

2026-09-24 V02/V04/V05/Q01: kit 78 adapts desert worn/translucent finish checkers to winter frost-white and slate-blue pigments. CaptureWinter 143 and TestDesert 53 checks pass; desktop screenshot inspected. No phone test/export. See docs/WINTER_SURFACES.md.

2026-09-24 V02/V04/V05/Q01: winter-specific ice scuffs, loose/packed snow ruts, slush wakes, tyre chips/powder and pooled snowbank-impact clouds. CaptureWinter 138, TestSoil 163, TestIce 69 and TestDesert 53 checks pass; desktop effects evidence inspected. No phone test/export. See docs/WINTER_TYRE_EFFECTS.md.

2026-09-24 R01/G01/V03/V05/Q01: measured Play selection optimization with unchanged compiled track output, LRU cache and safe cached-choice supersession. Desktop/attached-phone measurements and regression outcomes, including the unresolved old free-editor UI assertion: [MENU_SELECTION_2026_09_24.md](MENU_SELECTION_2026_09_24.md). Intermittent race hitch remains a separate open investigation.

2026-09-24 V02/V04/V05/Q01: kit 77 restores a faint blue tint to the pale winter road, retaining subdued texture. CaptureWinter 11 checks pass; desktop driving screenshot inspected. No phone test/export. See docs/WINTER_SURFACES.md.

2026-09-24 V02/V04/V05/Q01: kit 76 shifts winter roads from blue to pale neutral icy white using luminance-only artwork detail. CaptureWinter 11 checks pass; desktop driving evidence inspected. No Android export/device test. See docs/WINTER_SURFACES.md.

2026-09-24 V02/V04/V05/Q01: kit 75 reduces winter road artwork contrast to 28%, adds varied piled-snow crowns and clustered outer deposits while retaining the smooth road toe. CaptureWinter 11, TestIce 69, TestSurfaces 50 pass; desktop evidence inspected. No phone test/export. See docs/WINTER_SURFACES.md.

2026-09-24 V02/V04/V05/Q01: kit 74 refines winter ice scale, replaces sawtooth road-piece banks with rounded analytic profiles and blends ice gradually into snow. CaptureWinter 10, TestIce 69 and TestSurfaces 50 checks pass; driving/hairpin screenshots inspected. No Android export/device test. See docs/WINTER_SURFACES.md.

2026-09-24 Q01/V05/G01: race-start hitch investigation and reproducible startup diagnostic; Speedy desktop/phone measurements completed, root cause and owner acceptance remain open. See [RACE_START_HITCH.md](RACE_START_HITCH.md).

2026-09-24 V02/V04/V05/Q01: visual kit 73 adds original directional winter ice, detailed snow ground and irregular batched snowbank clumps; removes winter edge stripes. Ice 69, surfaces 50, shader profile 928 and final winter capture 11 checks pass. Desktop driving/hairpin evidence inspected. No Android export/device test. See docs/WINTER_SURFACES.md.

2026-09-24 V02/V04/V05/Q01: owner headlight tuning sets range to 20.4 model metres (1.7x) and narrows cone from 48 to 42 degrees, retaining hood clearance. CaptureHeadlights 56 and quick export checks pass. Installed/tested on DN2103: 160.5 m, median 16.722 ms/p95 20.449 ms; desktop/phone evidence inspected, normal play restored. See docs/NIGHT_HEADLIGHTS.md.

2026-09-24 V02/V04/V05/Q01: corrected headlight hood spill by moving the source ahead of the nose, raising/widening its road footprint and shortening range to 12 model metres. CaptureHeadlights 56 and quick Android export checks pass. Updated APK tested on DN2103: 160.1 m driven, median 16.739 ms/p95 20.506 ms; desktop/phone screenshots inspected and normal play restored. See docs/NIGHT_HEADLIGHTS.md.

2026-09-24 V02/V04/V05/Q01: faint night rear lamps reuse emissive brake materials; braking brightens them and release restores running glow. Kart gains two batched rear lenses; no added dynamic lights. CaptureHeadlights 51, vehicle batch 35 and quick export checks pass. Installed/tested on DN2103: 213.6 m, median 16.785 ms/p95 20.511 ms. Desktop running/braking and phone captures inspected; normal play restored. See docs/NIGHT_HEADLIGHTS.md.

2026-09-24 V02/V04/V05/Q01: night headlight cone begins wider at the bumper using a recessed virtual origin and softer angular falloff, retaining one shadow-free light. Final CaptureHeadlights 31 and quick export driving/catalog/menu checks pass; desktop comparison inspected. Revised APK installed/tested on DN2103: on medians 16.732/16.789 ms, off 16.760 ms; no material difference. Phone evidence inspected, normal play restored. See docs/NIGHT_HEADLIGHTS.md.

2026-09-24 V02/V04/V05/Q01: night headlights use one bounded shadow-free spotlight and batched illuminated lenses across five vehicles. Headlights 31 headless/31 graphical, biomes 107, vehicle batching 35 and quick Android export checks pass. Installed/tested on DN2103: moving on 16.659/16.682 ms median versus off 16.779 ms; p95 20.11-20.51 ms. Initial paused sample excluded. Screenshots inspected, normal play restored; no thermal-soak/fleet acceptance. See docs/NIGHT_HEADLIGHTS.md.

2026-09-24 R01/V03/V05: Create biome cards use one image-independent selected treatment: full-bright artwork and a square yellow label band; unselected artwork is uniformly subdued, with no selected outer-border highlight. CaptureBiomes passes 107 checks and desktop evidence was inspected. No phone test/export. See BIOME_CREATION.md.

2026-09-24 R01/V03/V05/Q01: Race Complete Next Tracks cards show saved local star ratings and vote counts, matching Play. CaptureResults passes 204 checks across three sizes; desktop evidence inspected. No phone test/export. See TRACK_RATINGS.md.

2026-09-24 V02/V04/V05/Q01: desert-bridge-2 fixes recessed-looking railing caps with flat face normals and narrower stone bevels. CaptureDesertBridge passes; desktop evidence inspected, collision/clearance assertions pass. No phone test/export. See docs/DESERT_BRIDGES.md.

2026-09-24 V02/V04/V05/Q01: grass-clippings-2 replaces bright box debris with folded tapered blades, natural lit colours and low two-axis tumbling; capacity reduced 20%. Soil 163, graphical soil 172, desert 53 and graphical grass 32 checks pass. Desktop evidence inspected; no device test/export. See docs/GRASS_CLIPPINGS.md.

2026-09-24 V02/V04/V05/Q01: desert-bridge-1 replaces desert steel rails with sandstone parapets, bevelled coping, capped posts and clearance-preserving shallow arches. Construction 82, bridge contacts 16 and desert 53 checks pass; two desktop captures inspected. No phone test/export. See docs/DESERT_BRIDGES.md.

2026-09-24 V02/V04/V05/Q01: desert road-edge kerb cells now select sand trails/dust instead of dark rubber/smoke. Saved-track CaptureDesert 79 and TestSoil 163 checks pass; desktop capture inspected. No phone test/export. See docs/DESERT_OFF_TRACK.md.

2026-09-24 V02/V04/V05/Q01: desert-dust-9 fixes green off-track tyre marks and grass clippings with sandy grooves, low tan grain spray and lingering dust. CaptureDesert 67 and TestSoil 163 checks pass; two desktop captures inspected. No phone test/export or performance measurement. See docs/DESERT_OFF_TRACK.md.

2026-09-24 V02/V04/V05/Q01: closed vehicle shells with opaque black underside caps and black kart floor. TestVehicleBatch: 35 checks pass, five inverted desktop captures inspected. Live rollover/phone acceptance remains; no device test/export. See VEHICLE_UNDERSIDES.md.

2026-09-24 V02/V04/V05/Q01: kit 72 enlarges desert finish checker pitch 29%, cools the sand pigments and adds patchy abrasion/eroded edges after owner rejection of kit 71. Final CaptureDesert: 61 checks pass, desktop evidence inspected. No phone test/export. See docs/DESERT_START_FINISH.md.

2026-09-24 V02/V04/V05/Q01: kit 71 uses two rows of translucent, grain-worn sand finish checkers. CaptureDesert: 61 checks pass; desktop screenshot inspected. No phone test/export. See docs/DESERT_START_FINISH.md.

2026-09-24 V02/V04/V05/Q01: visual kit 70 follows the owner's in-game reference with a faded, low-contrast three-row sand checker and worn exposed-sand edges. See DESERT_START_FINISH.md.

2026-09-24 V02/V04/V05/Q01: desert-dust-8 gives each particle a stable randomized 10-14 degrees/s birth speed, slowing with growth to 2.6-3.64 degrees/s for mature clouds. CaptureDesert 61 and Android quick export pass; APK installed, no phone driving/profile test. See docs/DESERT_DUST.md.

2026-09-24 R01/V03/V05/Q01: configurable touch layout editor, three steering methods, independent analog pedals, presets/reset, safe normalized geometry and atomic settings. 199 headless / 202 graphical layout checks (plus 72 synthetic viewport checks), 555 mobile-input and 53 record checks pass; final Android quick export passes and APK installed. Phone attached but locked; no physical multitouch/iOS test. Older TestApp stops on obsolete menu-button assumptions. See docs/TOUCH_CONTROL_LAYOUT.md.

2026-09-24 V02/V04/V05/Q01: visual kit 69 replaces the rejected filled Desert checker with an actual sand drawing: irregular raked grid grooves, diagonal stick marks and displaced sunlit ridges. See DESERT_START_FINISH.md.

2026-09-24 V02/V04/V05/Q01: desert-dust-7 corrects angular-curve radian units and uses stronger size-dependent slowing (calculated mature maximum ~0.27 degrees/s). CaptureDesert 61 and quick Android export pass; APK installed on DN2103, no phone motion/profile test. See docs/DESERT_DUST.md.

2026-09-24 V02/V04/V05/Q01: visual kit 68 gives Desert a weathered sand-chalk/ochre start-finish marking with exposed packed-sand seams; other biomes and timing geometry remain unchanged. See DESERT_START_FINISH.md.

2026-09-24 V02/V04/V05/Q01: desert-dust-6 slows cloud rotation with inverse growth: at most 12 degrees/s initially, about 3.1 degrees/s for mature clouds. CaptureDesert 57 and Android quick export pass; APK installed, no phone driving/profiling. See docs/DESERT_DUST.md.

2026-09-24 V02/V04/V05/Q01: desert-dust-4 brings cloud onset to the car: peak opacity at 0.108 s, earlier growth, stronger tyre puffs and narrower soft-intersection fade. Counts unchanged. CaptureDesert 57, soil 163 and quick Android export pass; APK installed, no phone driving/profiling. See docs/DESERT_DUST.md.

2026-09-24 V02/V04/V05/Q01: desert-dust-3 responds to owner rally-dust reference with a connected occluding beige plume, 256 lingering particles, stronger sustained density and soft depth intersections. CaptureDesert 55, soil 163 and Android quick export pass; APK installed. Phone remains locked; no performance measurement. See docs/DESERT_DUST.md.

2026-09-24 V02/V04/V05/Q01: desert-dust-2 splits short tyre puffs from 384 bounded lingering particles, softens shading and enables texture mipmaps. Final CaptureDesert 55, soil 163 and Android quick checks pass; final APK installed on DN2103. Phone profiling obtained no measurements while locked. See docs/DESERT_DUST.md for evidence and acceptance.

2026-09-24 V02/V04/V05/Q01: kit 67 replaces fine desert road-edge breakup with broader approximately 5.6 m variation, constrained to existing blend strip endpoints. CaptureDesert 53 and quick Android export checks pass; gameplay capture inspected. See docs/DESERT_EDGE_VARIATION.md.

2026-09-24 V02/V04/V05/Q01: kit 66 warms/darkens desert road pigment toward surrounding sand, extends shoulder blending 0.91 m farther inward and raises inner-bend clods 65%. CaptureDesert 53, TestSurfaces 50 and quick Android export checks pass. Desktop capture inspected. See docs/DESERT_COLOUR_HEIGHT.md.

2026-09-24 V02/V04/V05/Q01: kit 65 replaces continuous raised desert ribbons with flat original sandy-apron artwork and clustered independent sand clods in the shoulder batch. Three gameplay views captured; 809 clods/14,562 triangles on saved desert track. CaptureDesert 53, TestSurfaces 50 and corrected TestSurfaceProfile 928 checks pass. DN2103 installed/tested: repeated production median ~17.35 ms/p95 ~29 ms; particles-disabled 16.85/20.15 ms, initial run slower. Normal play restored. No old/new cost comparison. See docs/DESERT_APRON.md.

2026-09-24 V02/V04/V05/Q01: kit 64 tapers berm height over 3 m at actual curved-run boundaries, reduces coarse rib shading and broadens irregular outer shoulder blending. Approved directional road material retained. CaptureDesert 50 checks pass; screenshot inspected. See docs/DESERT_TAPER.md.

2026-09-24 V02/V04/V05/Q01: kit 63 restores the owner-preferred curve-bank pattern, leaves straight shoulders flat/darker and maps compacted road grain along/across each road piece. Bounded road subdivision avoids warped interpolation through bends. CaptureDesert 50 checks pass; gameplay evidence inspected. See docs/DESERT_DIRECTIONAL.md.

2026-09-24 V02/V04/V05/Q01: kit 62 replaces corrugated desert banks with a broader four-band transition: worn contact, low deposited sand ridge and loose grit into dunes. Road-edge blending widens to 0.56 m; shoulder width 1.8-2.4 m. CaptureDesert 50 and TestSurfaces 50 pass; screenshot inspected. See docs/DESERT_TRANSITION.md.

2026-09-24 V02/V04/V05/Q01: kit 61 replaces visible desert creator kerbs with low irregular sand banks, softens straight shoulders and adds road-axis filtered wear. CaptureDesert 50 and TestSurfaces 50 checks pass. Desktop evidence inspected; see docs/DESERT_BERMS.md for scope and device limits.

2026-09-24 V02/V04/V05/Q01: kit 60 restores a distinct rough gravel shoulder between desert road and dunes, including behind stone kerbs, and strengthens baked road grain/wear. CaptureDesert 50 and TestSurfaces 50 checks pass. Gameplay screenshot inspected. See docs/DESERT_SHOULDERS.md.

2026-09-24 V02/V04/V05/Q01: kit 59 gives desert roads muted compacted sand/gravel, sandstone kerbs and no white edge stripes. Normal daylight supersedes the sunset request; dune pigment is retuned for daylight. Saved-track CaptureDesert 50, TestSurfaces 50 and TestBiomes 92 pass; Android quick export passes 74 driving, 18 catalog and 22 menu checks. Desktop screenshot inspected. See docs/DESERT_DAYLIGHT.md for device status and acceptance.

2026-09-24 V02/V04/V05/Q01: kit 58 adds original dune/ripple sand artwork, baked slope lighting and sparse opaque dry scrub for desert ground. Roads, sunset, dust, camera and canonical handling remain unchanged. Desert 31, saved-track capture 52, surfaces 50, grass 15, biomes 92 and shader profile 928 checks pass. Desktop screenshots inspected; fresh Android APK exported and installed. DN2103 was locked, so phone profile timed out with 0/5 stages; diagnostics cleaned up, performance acceptance pending. See docs/DESERT_DUNES.md.

2026-09-23 V02/V04/V05/Q01: kit 57 adds original meadow blade/clump artwork and shaded opaque tufts instead of restoring old leafy grass. Fresh APK installed on DN2103; 18 comparison stages completed. Ajorata median unchanged; repeated Storm +0.20?0.24 ms (1.2?1.4%), lower p95. First Storm pass showed device-wide slowdown affecting original grass too; all results retained. Desktop/device evidence and acceptance limits: docs/GRASS_PERFORMANCE.md.

2026-09-23 V02/V04/V05/Q01: owner rejected plain hybrid grass. Kit 56 restores original painted vegetation detail, greatly reduces broad blotches and matches tuft colour to the ground. CaptureGrass 17, TestGrass 15 and TestSurfaces 50 checks pass; revised gameplay screenshot inspected. No phone test/deployment/profiling. See docs/HYBRID_GRASS.md.

2026-09-23 V02/V04/V05/Q01: grass-only hybrid material uses baked macro/albedo/normal maps and five opaque clustered MultiMesh tuft variants. Visual kit 55; 2,270 tuft origins in captured driving view. Grass 15/17 headless/graphical, surface 50, desert 24, biome 92 and shader-probe 928 checks pass. Desktop screenshots inspected. Phone attached; no device test/export/profiling. See docs/HYBRID_GRASS.md.

2026-09-23 R01/R03/V03/V05/Q01: Results sector colours compare corresponding sector times with the fastest valid lap, consistently across route and table; visible transverse lines mark sector ends. TestResults passes 185 checks and CaptureResults passes 204 checks; desktop evidence inspected. No phone test/export. See docs/RACE_RESULTS.md.

2026-09-23 R01/V03/V05/Q01: rating stars centered on both axes; saved stars and score remain visible for 0.7 s, then finish cues fade over 0.4 s before Results. Confirmation blocks duplicate input. 198 graphical Results checks pass; desktop capture inspected. No phone test/export. See docs/TRACK_RATINGS.md.

2026-09-23 R01/V03/V05/Q01: Play track cards show saved personal rating and actual local vote count (0/1). 490 graphical menu checks pass across three sizes; desktop/compact captures inspected. Shared aggregate ratings remain unconnected; no phone test/export. See docs/TRACK_RATINGS.md.

2026-09-23 R01/V03/V05/Q01: owner correction moves delayed rating directly beneath the on-track Race Complete sign in black/gold styling; removes Results popup. Unrated finish waits for stars/Skip, rated tracks retain automatic transition. 184 graphical Results and 49 practice checks pass; existing two practice shutdown ObjectDB warnings. Corrected desktop capture inspected; no phone test/export. See docs/TRACK_RATINGS.md.

2026-09-23 R01/V03/V05/Q01: delayed skippable personal track rating after finish; atomic persistence suppresses rated tracks and editable stars sit beneath standings. 164 headless Results, 179 graphical Results and 53 record checks pass; desktop captures inspected. No phone test/export. See docs/TRACK_RATINGS.md.

2026-09-23 V03/V05: refined trash icon, centered in square Delete action; 68 capture checks pass, desktop evidence inspected. No phone test/export. See [DRAFT_BROWSER.md](DRAFT_BROWSER.md).

2026-09-23 R01/T01-T04/V03/V05/Q01: selected-draft bottom action panel and persistent test/publish workflow; Publish locks local track and removes it from editing gallery. 68 workflow, 49 practice, 92 biome checks pass; practice shutdown reports two leaked ObjectDB instances. Desktop evidence inspected, no phone test/export. See [DRAFT_BROWSER.md](DRAFT_BROWSER.md).

2026-09-23 R01/T01-T04/V03/V05/Q01: dedicated local draft gallery replaces incorrect racing-library Load action; restores latest editing work and supports creation metadata/search/pages/confirmed deletion. 44 load/tyre, 92 biome, 22 menu checks pass; desktop evidence inspected. No phone test/export. See [DRAFT_BROWSER.md](DRAFT_BROWSER.md).

2026-09-23 R01/V03/V05/Q01: stacked incident legend with route exclusion gutter; laurel leaves connect to exact stem geometry and PB time is centered. 154 headless / 168 graphical checks pass; desktop evidence inspected. No phone test/export. See docs/RACE_RESULTS.md.

2026-09-23 R01/V03/V05: small biome icons follow owner Create reference, with pale blue tint and Storm lightning. CaptureBiomes: 92 checks pass; desktop evidence inspected. No phone test/export. See [BIOME_CREATION.md](BIOME_CREATION.md).

2026-09-23 R01/V03/V05: biome glyphs rebuilt as filled silhouettes, reference-informed moon/cloud and sixfold symmetric snowflake; 92 capture checks pass. Enlarged and menu evidence inspected, no phone test/export. See [BIOME_CREATION.md](BIOME_CREATION.md).

2026-09-23 R01/T01-T04/V03/V05: Create biome selection gains five refined icons, selected state, descriptive bottom card, explicit Create track and Load track actions, plus the “Select biome” heading. 92 checks pass; desktop evidence inspected. No phone test/export. See [BIOME_CREATION.md](BIOME_CREATION.md).

2026-09-23 R01/V03/V05/Q01: removed Play More menu and made Favorites use the track-card star icon in track_browser.gd. CaptureMenus passes 454 checks across three sizes; screenshot inspected. No phone test/export. See docs/PLAY_PAGE.md.

2026-09-23 V03/V05/Q01: Surprise me dice redrawn as a shaded, outlined three-face cube in menu_icon.gd. CaptureMenus passes 466 checks across three sizes; refreshed desktop evidence inspected. No phone test/export. See docs/PLAY_PAGE.md.

2026-09-23 R01/V03/V05/Q01: Play reference update adds filter icons, bottom dice/Surprise me and Home/Race actions, scenic selected-track panel, stacked records and side-by-side WHERE YOU STAND comparisons; removes Play edit/delete/remix actions. 22 menu and 466 graphical checks pass across three sizes. Desktop evidence inspected; no phone test/export. See docs/PLAY_PAGE.md.

2026-09-23 R01/V03/V05/Q01: Results back button uses an original thin yellow left arrow at the far left edge, with centered RESULTS text, matching the supplied action reference. Changed race_complete.gd and results_icons.gd; CaptureResults via scripts/dev.ps1 passed 163 checks and refreshed three-size evidence. Desktop screenshot inspected; no phone test/export.

2026-09-23 R01/V03/V05/Q01: Race Complete top-right home icon opens Main Menu; bottom-left < RESULTS returns to analysis; Tracks adds circuit icon. 163 graphical checks pass; desktop capture inspected. No phone test/export. See docs/RACE_RESULTS.md.

2026-09-23 R01/V03/V05/Q01: rewards show eligible rows only with sequential slide/fade, gold border accents and running total count-up. 149 headless / 163 graphical checks pass; desktop evidence inspected. No phone test/export. See docs/RACE_RESULTS.md.

2026-09-23 R01/V03/V05/Q01: Race Complete replaces placeholder with provisional rewards, real measured times and local next-track selection. Consistency omitted; clean requires no collision/off-track incidents. Percentile model rewards only new higher tiers; unavailable standings/history/challenges remain explicit, no wallet writes. 144 headless / 157 graphical checks pass; three-size evidence saved, desktop inspected. No phone test/export. See docs/RACE_RESULTS.md.

2026-09-23 R01/V03/V05/Q01: Results adds PB laurels, wider equal icon buttons, measured sector table, KPI icons/dividers and larger lap times. 127 headless / 138 graphical checks pass; refreshed desktop screenshot inspected. No phone test/export. See docs/RACE_RESULTS.md.

2026-09-23 R01/V03/V05/Q01: simplified Results to Race Again / Continue, shorter time panel, yellow right-side PB, taller lap rows and expanded analysis ordered Sectors / Time diff / Speed. Continue opens recommendations/rewards placeholder with results/library navigation. 120 headless, 131 graphical and 22 menu checks pass; desktop evidence inspected. No phone test/export. See docs/RACE_RESULTS.md.

2026-09-22 V02/V04/V05/Q01: reference correction gives desert rust-red earth/amber light and much wider shaded dust billows; visual kit 54. Desert 24, soil 163 and graphical capture 25 checks pass. Refreshed desktop evidence inspected; no phone test/profiling. [Details](DESERT_SUNSET.md).

2026-09-22 G01/G03/R01/R03/R07/V02/V04/V05/Q01: desert firm-sand roads, dense nine-second dust and low red-orange sunset. Physics 0.39 / compiler 19 / visual kit 53. Focused behavior, creator, track, biome and soil checks pass; desktop captures saved. Full validation stopped on now-updated creator expectations; remaining chain and phone acceptance not completed. See [details](DESERT_SUNSET.md).

2026-09-22 R01/V03/V05: Create biome cards reuse Tracks gallery scenery, with lower overlaid labels and a thin artwork strip beneath; permanence explanation removed. 62 checks pass and desktop evidence was inspected. No phone test/export. See [BIOME_CREATION.md](BIOME_CREATION.md).

2026-09-22 R03/R07/G01/V03/V05/Q01: rules v12 adds up to 6 m outside bend recovery; missed-checkpoint labels simplified, translucent road-only line plus faint removable acceptance margins. 122 checkpoint, 27 start-line, 167 track/replay, 53 record and 14 graphical checks pass. Desktop evidence inspected; no phone test/export. See docs/MOBILE_OPTIMIZATION_2026_09_22.md (Outside recovery and marker clarity).

2026-09-22 V02/V04/V05/Q01/R01: clearer dynamic side-window reflections, matching rear wraparound bumper and recessed rim barrels/spokes. 30 batching and 114 quick checks pass; updated APK installed/launched on DN2103. No profiling. [Evidence and limits](WINDOW_REFLECTIONS.md#side-reflections-matching-rear-bumper-and-rim-depth---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: simple world-fixed sky/cloud reflections on compact glass respond to viewing angle and vehicle rotation. 30 batching and 114 deployment quick checks pass; APK installed/launched on DN2103, visible startup verified. Owner will test; no profiling performed as requested. [Evidence and limits](WINDOW_REFLECTIONS.md).

2026-09-22 V02/V04/V05/Q01/R01: front bumper now continuous dark rubber with rounded corner/side returns; grey top strip removed, twin headlights retained. Six desktop views captured; 30 batching checks pass. No phone test. [Evidence](COMPACT_LOOK.md#dark-wraparound-front-bumper---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: reference-led roof perimeter crease and tapered/rounded rear quarter windows with slim light surrounds. Six desktop captures saved; 30 batching checks pass. No phone test. [Evidence](COMPACT_LOOK.md#reference-roof-edge-and-rear-quarter-windows---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: glass boundaries now curve visibly from overhead and front bumper projects farther with a taller face/top edge. Six desktop views including high rear captured; 30 batching checks pass. No phone test. [Evidence](COMPACT_LOOK.md#visible-glass-curvature-and-front-bumper---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: compact loses black sill shell, gains deeper nose curve, rounded glazing/crowned windshield and faint roof pressings. 30 batching checks pass; desktop front/side captures inspected. No phone test. [Evidence and limits](COMPACT_LOOK.md#rounded-glazing-nose-and-roof-detail---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: reduced compact front-fender lateral projection by 35% from its body attachment; rear fenders and wheels retained. 30 batching checks pass; updated capture inspected. No phone test. [Evidence](COMPACT_LOOK.md#front-flare-projection-reduced-35-percent---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: compact nose gains a shallow curve across fascia/grille/bumper and twin round headlights per side matching owner menu reference. 30 batching checks pass; refreshed desktop captures inspected. No phone test. [Evidence and limits](COMPACT_LOOK.md#curved-nose-and-twin-lamps---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: compact side cleanup removes block mirrors, redundant black strips and open-panel ink artifacts; tapered seams and broad silver-blue fender highlights improve reference fidelity. Both side captures inspected; 30 batching checks pass. No phone test. [Evidence and limits](COMPACT_LOOK.md#side-cleanup-and-fender-highlights---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: compact front correction integrates grille into a solid fascia, shapes the bonnet and replaces detached arch strips with charcoal flares blending into painted fenders. 30 batching checks pass; refreshed desktop captures. No phone test. [Evidence and limits](COMPACT_LOOK.md#front-hood-and-fender-correction---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: owner-reference compact model gains rounded/wider tyres, recessed alloys, sculpted arches, layered lamps, dark glazing and body trim. 30 batching and 28 suspension checks pass; before/after desktop captures saved. No phone test. [Details and acceptance](COMPACT_LOOK.md).

2026-09-22 R01/R03/V03/V05/Q01: pausing and shortcut history no longer invalidate completed race results, records or lap telemetry; editor practice remains unranked. Removed explanatory copy from TOTAL RACE TIME. Results suites pass 120 headless / 130 graphical checks, plus 22 menu checks; refreshed 1280x720 capture inspected. No phone test or export. See [RACE_RESULTS.md](RACE_RESULTS.md#result-eligibility-and-summary-simplification--2026-09-22).

2026-09-22 V03/V05/R01: minimap waypoint/checkpoint marker removed; road and player display remain. World missed-gate recovery feedback is unchanged. 160 focused checks pass, desktop capture inspected, no phone test. See [MINIMAP_WAYPOINT_MARKER.md](MINIMAP_WAYPOINT_MARKER.md).

2026-09-22 G01/G03/R01/R03/R07/V01/Q01: deterministic loose-terrain tyre deflection strengthened and continuous off-road camera shake lowered in frequency. Physics 0.38; 332 focused checks pass plus 32 kart checks. The chained kart command retains four unrelated detailed-model failures. No phone test. See [OFF_TRACK_HANDLING.md](OFF_TRACK_HANDLING.md) and [CAMERA_SHAKE.md](CAMERA_SHAKE.md).

2026-09-22 V02/V04/V05/Q01: restored creator bridge asphalt by binding the shared baked surface texture. 157 graphical bridge/HUD checks pass; desktop screenshot inspected. No device test. See docs/MOBILE_OPTIMIZATION_2026_09_22.md, Bridge texture restoration.

2026-09-22 R03/R07/G01/V03/Q01: owner-requested checkpoint forgiveness adds up to 3 m inside gentle curves, tapering away on tighter bends; visible line matches asymmetric acceptance. Rules v11; 108 checkpoint checks pass including hairpin shortcuts. [Details and evidence](MOBILE_OPTIMIZATION_2026_09_22.md#inside-recovery-allowance--2026-09-22-follow-up).

2026-09-22 R01/R03/R07/G01/V02/V03/V04/V05/Q01: baked road/sand detail, removed random cracks, reduced directional shadows and replaced route-history searches with ordered road gates. Owner follow-up reduces gate density to approximately 12 m and smooths bend normals. Missed sections require return; no +5s penalty. Rules v10 / compiler 18 / visual kit 52. See [actual tests, phone comparisons and acceptance](MOBILE_OPTIMIZATION_2026_09_22.md).

2026-09-22 R01/R03/V03/V05/Q01/RR02: Results incident markers implemented; 104 headless / 114 graphical checks pass. No physics changes or phone test. See [commands and evidence](RACE_RESULTS.md#incident-markers--2026-09-22).

2026-09-22 R01/R03/R07/V02/V04/V05/Q01: road/terrain follow-up confirms recent shared asphalt-shader regression in eighteen DN2103 stages: old detail saves 3.490/5.614 ms on Ajorata/Storm; terrain simplification saves 3.510/8.959 ms. 928 graphical checks pass, normal visuals/play restored. [Actual comparisons, commands and remaining acceptance](SURFACE_PERFORMANCE_2026_09_22.md).

2026-09-22 R01/R03/R07/G01/V03/V05/Q01: owner-requested in-game profiling, including Results time/speed telemetry, completed on physical DN2103 across eighteen controlled stages. Weather/shadows dominate observed rendering improvements; route validation costs 1.787/2.097 ms per frame versus telemetry 0.032/0.039 ms. Focused export, Results and performance checks pass; normal play restored. [Actual evidence and acceptance limits](PERFORMANCE_2026_09_22.md).

2026-09-21 V02/V04/V05/Q01/R01: owner-directed ramp damping refinement adds continuing, diminishing suspension rebound through touchdown. 141 graphical suspension and 16 bridge checks pass; no phone test. [Evidence](BRIDGE_COLLISIONS.md#damped-suspension-follow-up--2026-09-21).

2026-09-21 G01/G03/R01/R03/R07/V02/V04/V05/Q01: owner-requested bridge underside/Knit collision fixes and visual ramp unloading. Physics 0.37, compiler 17; focused checks and desktop captures pass, no phone test. See [BRIDGE_COLLISIONS.md](BRIDGE_COLLISIONS.md) for commands, regression status and remaining acceptance.

2026-09-21 R01/R03/G01/V03/V05/Q01: bounded saturated-glass overflow fixes a potential collision freeze; retained HUD geometry, inactive-emitter gating and early trail rejection reduce presentation CPU work. 9 glass, 13 performance, 160 soil, 555 touch and 157 graphical HUD checks pass. Physical DN2103 before/after: Ajorata median 20.806 to 19.943 ms; Storm 25.999 to 24.841 ms, still below 60 FPS. Optimized APK installed and normal play restored. [Evidence and limits](PERFORMANCE_2026_09_21.md).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-51 strengthens creator edge-line fading and asphalt chips while preserving readable continuous markings. 390 focused checks and desktop captures pass; no phone test. See [ROAD_REALISM.md](ROAD_REALISM.md#stronger-marking-wear---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-50 adds restrained procedural wear to white creator-road edge markings without changing their geometry. Focused checks and desktop captures pass; no phone test. See [ROAD_REALISM.md](ROAD_REALISM.md#worn-white-edge-markings---2026-09-21).

2026-09-21 V03/V05/R01: tabular race/lap timer digits prevent width jitter; lap backing follows actual label bounds. 157 graphical HUD checks pass, capture saved. No phone test. [Evidence](HUD_REFRESH.md#stable-timers-and-aligned-lap-backing--2026-09-21).

2026-09-21 V02/V03/V05/G01/R01: HUD follow-up adds soft translucent readout backings and depressed pedal geometry without active pedal highlights. 107 HUD and 555 touch checks pass; five-vehicle captures saved. No phone test. [Evidence](HUD_REFRESH.md#subtle-backings-and-depressed-pedals--2026-09-21).

2026-09-21 V02/V03/V05/G01/R01/R03: owner-supplied HUD replacement with live lap/race clocks, circular placed-road minimap, semicircular speed gauge and supplied control artwork. 107 HUD, 555 touch, 33 practice and 114 quick-regression checks pass; desktop captures saved. No phone test. [Details and evidence](HUD_REFRESH.md).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-46 doubles the accepted edge material crossfade to 10 cm while retaining its geometry and variation. 384 focused checks and desktop captures pass; no phone test. See [ROAD_REALISM.md](ROAD_REALISM.md#10-cm-crossfade---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-45 retains the accepted fringe shape and adds a small ~5 cm asphalt/sand crossfade. 334 road checks and desktop captures pass; no phone test. See [ROAD_REALISM.md](ROAD_REALISM.md#small-smudged-material-blend---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-44 replaces the coarse surface-grid road edge with a continuous UV-controlled cosmetic fringe, providing consistent few-pixel width variation throughout straights and curves. 384 focused checks and desktop captures pass; no phone test. See [ROAD_REALISM.md](ROAD_REALISM.md#continuous-uv-edge-fringe-replacement---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-43 reduces edge displacement to a few-pixel transition-width variation repeated throughout the track, matching the owner-marked baseline. 334 road checks and desktop captures pass; no phone test. See [ROAD_REALISM.md](ROAD_REALISM.md#few-pixel-transition-width-correction---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-42 follows the owner-marked edge examples with broader shallow rounded variation over the retained filtered mask. 334 road checks and desktop captures pass; no phone test. See [ROAD_REALISM.md](ROAD_REALISM.md#rounded-edge-lobe-correction---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-41 replaces curve saw teeth with a filtered, higher-frequency and 70% shallower edge pattern while retaining post-line asphalt. 334 road checks and desktop captures pass; no phone test. See [ROAD_REALISM.md](ROAD_REALISM.md#fine-curve-edge-correction---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-40 follows the real paving reference by retaining opaque asphalt after the white line and reducing variation to the final narrow physical edge. 334 road checks and desktop captures pass; no phone test. See [ROAD_REALISM.md](ROAD_REALISM.md#real-road-edge-proportion-correction---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-39 replaces the remaining translucent road-edge band with a true asphalt/sand coverage boundary based on the sand/grass fringe at half displacement. White lines remain. 334 road checks and desktop captures pass; no phone test. See [ROAD_REALISM.md](ROAD_REALISM.md#coverage-shape-correction---2026-09-21).

2026-09-20 V02/V04/V05/Q01/R01: track-kit-38 restores the white edge lines and replaces the rejected exaggerated transition with only a subtle outer-edge tint. 334 road checks and desktop captures pass; no phone test. See [ROAD_REALISM.md](ROAD_REALISM.md#restrained-border-correction---2026-09-20).

2026-09-20 V02/V04/V05/Q01/R01: track-kit-37 supersedes geometry scalloping and the continuous white verge border with a joined, narrow asphalt-to-sand transition matching the existing sand/grass edge. 384 focused checks and desktop captures pass; no phone test. See [ROAD_REALISM.md](ROAD_REALISM.md#natural-asphalt-to-sand-transition---2026-09-20).

2026-09-20 V02/V04/V05/Q01/R01: track-kit-35 adds the requested sharper uneven visual asphalt contour outside the unchanged white marking; collision and canonical cells remain unchanged. 335 road-piece checks and desktop captures pass; no phone test. See [ROAD_REALISM.md](ROAD_REALISM.md#sharper-uneven-asphalt-contour---2026-09-20).

2026-09-20 V02/V04/V05/Q01/R01: owner-reference procedural road realism is implemented as track-kit-34: shared dry-asphalt macro variation, sparse deterministic repairs/sealed cracks, creator-road edge wear and retained physics-driven tyre marks. 662 focused checks and desktop Compatibility captures pass. No phone/device performance test; see [ROAD_REALISM.md](ROAD_REALISM.md).

2026-09-20 V01/V02/V04/Q01: persistent glass reveal is split into four gradual affected-side channels; overflow reaches another edge only after the struck edge is full. Eight focused checks pass; no phone test. See [CAMERA_SHAKE.md](CAMERA_SHAKE.md#impact-glass-follow-up).

2026-09-20 V01/V02/V04/Q01 owner correction: an original transparent edge-heavy broken-glass asset replaces procedural fading cracks; meaningful impact damage accumulates and persists through the race until restart. Six focused checks pass; no phone test. See [CAMERA_SHAKE.md](CAMERA_SHAKE.md#impact-glass-follow-up).

2026-09-20 V01/V04/Q01: meaningful collision impulses add a brief directional screen-glass fracture with thresholded scale and a half-second lifetime. Six focused checks pass; no phone test. See [CAMERA_SHAKE.md](CAMERA_SHAKE.md#impact-glass-follow-up).

2026-09-20 G01/R01/V01/V04/Q01 owner correction: traditional collision jitter is replaced by a directional resolved-impulse spring with bounded trauma texture; off-track vibration is subtler and smoothly blended. Six camera, 167 track and 155 soil checks pass; no phone test. See [CAMERA_SHAKE.md](CAMERA_SHAKE.md).

2026-09-20 G01/R01/V01/V04/Q01: bounded presentation-only camera shake uses resolved collision velocity change for impacts and speed-weighted surface resistance for off-track rumble. Canonical simulation and camera framing are unchanged. Five camera, 167 track and 155 soil checks pass; no phone test. See [CAMERA_SHAKE.md](CAMERA_SHAKE.md).

2026-09-20 V02/V04/V05: asphalt smoke emitter cadence raised from 30 to 120 Hz after the owner capture exposed discrete high-speed emission batches. See [SAND_DUST.md](SAND_DUST.md#grass-and-asphalt-extension--2026-09-20).

2026-09-20 V02/V04/V05: asphalt smoke uses a dedicated uniform haze material instead of distinct billow sprites, with higher sampling density and lower opacity. See [SAND_DUST.md](SAND_DUST.md#grass-and-asphalt-extension--2026-09-20).

2026-09-20 V02/V04/V05: asphalt smoke follow-up increases sampling density while substantially reducing per-particle opacity, cap and expansion. See [SAND_DUST.md](SAND_DUST.md#grass-and-asphalt-extension--2026-09-20).

2026-09-20 V02/V04/V05: grass debris now uses physical 3D fragments from wheel contacts and asphalt smoke uses densely overlapping soft puffs for continuity. See [SAND_DUST.md](SAND_DUST.md#grass-and-asphalt-extension--2026-09-20).

2026-09-20 R01/V02/V04/V05/Q01: extended wheel-contact particles to grass clippings/mud and thresholded dry-asphalt smoke, with dedicated desktop evidence and no physics changes. See [SAND_DUST.md](SAND_DUST.md#grass-and-asphalt-extension--2026-09-20).

2026-09-20 V02/V04/V05: generated an original transparent dust-puff asset and replaced the artificial procedural cloud; tyre onset now appears in about 0.13 seconds while retaining later rise/dispersion. See [SAND_DUST.md](SAND_DUST.md).

2026-09-20 V02/V04/V05: corrected sand-cloud depth progression: ground-level birth stays behind the car, delayed opacity/scale follows ascent, and only raised mature dust can fill the vehicle silhouette. See [SAND_DUST.md](SAND_DUST.md).

2026-09-20 V02/V04/V05: sand particles now have explicit vertical evolution: ground-level birth, gradual rise, expansion and fade. See [SAND_DUST.md](SAND_DUST.md).

2026-09-20 V02/V04/V05: sand-cloud compositing now permits foreground dust to obscure the car; cloud density, footprint, persistence, expansion and colour brightness were increased after owner review. See [SAND_DUST.md](SAND_DUST.md).

2026-09-20 V02/V04/V05: sand effect rebuilt after owner rejection: camera-facing overlapping puffs, 4.8-second cloud, intentional partial obstruction and dedicated speed/slip/yaw emission behavior replace ground-like particle streaks. See [SAND_DUST.md](SAND_DUST.md).

2026-09-20 V02/V04/V05: sand dust follow-up increases cloud footprint, expansion and persistence; rear spray is also moderately larger and longer. See [SAND_DUST.md](SAND_DUST.md).

2026-09-20 R01/V02/V04/V05/Q01: implemented sand-only two-layer wheel particles with shared tire-mark intensity, surface gating and desktop visual evidence. No phone/device acceptance was performed. See [SAND_DUST.md](SAND_DUST.md).

2026-09-20 R01/V05/Q01: tire-track build installed on DN2103; an empty/saturated/empty worst-case probe found no median or percentile regression from the full 16,384-instance batch. Normal play restored after diagnostic cleanup. [SURFACE_TIRE_TRACKS.md](SURFACE_TIRE_TRACKS.md#physical-phone-performance-and-deployment--2026-09-20).

2026-09-20 R01/V02/V04/V05/Q01: bounded race-persistent tire tracks use one 16,384-instance batch, four actual wheel paths, continuous physics-derived intensity, feathered/streaked asphalt with repeated-pass accumulation, and faceted loose-surface rut relief. [SURFACE_TIRE_TRACKS.md](SURFACE_TIRE_TRACKS.md) records checks and remaining phone acceptance.

2026-09-19 G01/R01/R03/R07: owner requested Drift+ between Original+ and the strong rear-drive revision. Handling 0.19 targets a 25–32° powered midpoint while retaining power-oversteer contrast and quick recovery. [COMPACT_HANDLING_REFINEMENT.md](COMPACT_HANDLING_REFINEMENT.md).

2026-09-19 G01/R01/R03/R07: Drift+ 0.18 responds to rear-drive feedback with power-on rotation and cornering traction loss, calmer coasting and retained unwind recovery. Original+ remains unchanged/default. [COMPACT_HANDLING_REFINEMENT.md](COMPACT_HANDLING_REFINEMENT.md).

2026-09-19 G01/R01/R03/R07: owner found the first Drift+ comparison too subtle. Drift+ handling 0.17 now targets at least 25% more powered slip than Original+, with stronger throttle rotation and fast unwind recovery; Original+ remains unchanged/default. [COMPACT_HANDLING_REFINEMENT.md](COMPACT_HANDLING_REFINEMENT.md).

2026-09-19 R01/R04/R06/R07/V02/V03/V05: refined discovery menu, direct favorite stars, record/distribution/friend panel and cloud-ready read-model boundary. 460 graphical and 93 focused checks pass; no phone test. [Details and acceptance](REFINED_DISCOVERY.md).

2026-09-19 V02/V03/V05: dedicated generated Storm track-card background replaces Grass fallback. 397 menu capture checks pass. [Artwork and evidence](DISCOVERY_MENU.md#dedicated-storm-artwork---2026-09-19).

2026-09-19 R01/T01/V05: added scripts/deploy-phone.ps1 for fresh APK deployment plus saved-PC-track sync with replacement backups/hash verification. Tested on DN2103: focused checks 70/18/11 pass, 20 tracks verified, phone-only track retained. Missing-source preflight rejected as expected. [Usage/limits](ANDROID.md#deploy-game-and-all-saved-pc-tracks).

2026-09-19 R01/V05/Q01: optimized Storm verified on DN2103: ~47 FPS versus ~43; frames over 25 ms reduced 38% to 26%. Not steady 60 FPS. Normal play restored. [Evidence](STORM.md#optimized-build-verified-on-phone---2026-09-19).

2026-09-19 R01/V05/Q01: cached Storm trail histories remove repeated path evaluation; desktop microbenchmark ~89x faster, 54 checks pass. Optimized APK installed; phone FPS comparison blocked by locked/asleep device. [Details](STORM.md#trail-history-cpu-optimization---2026-09-19).

2026-09-19 R01/V05/Q01: current Storm build deployed/tested on DN2103. Warm driving sample ~43 FPS, 38% frames over 25 ms; not steady 60 FPS. Diagnostic cleaned up, normal app relaunched. [Evidence](STORM.md#physical-phone-deployment-and-performance---2026-09-19).

2026-09-19 V02/V04/V05: erratic droplet spurts with brief catches and sharper lateral changes replace smooth falling arcs. 53 checks passed. [Evidence and limits](STORM.md#erratic-falling-paths---2026-09-19).

2026-09-19 V02/V04/V05: heavier Storm rain, greater central water coverage and roughly doubled droplet refraction. 53 checks passed. [Evidence and limits](STORM.md#heavier-rain-and-stronger-distortion---2026-09-19).

2026-09-19 V04/V05: Storm lightning now every 9-16 seconds, first strike after 6 seconds. 53 checks passed. [Details](STORM.md#twice-as-frequent-lightning---2026-09-19).

2026-09-19 V02/V04/V05: moving-drop trails now scale with bead width and taper as they fade. 53 checks passed. [Evidence and limits](STORM.md#trails-proportional-to-bead-width---2026-09-19).

2026-09-19 V02/V04/V05: randomized uneven Storm droplet silhouettes and much stronger lightning illumination. 53 checks passed. [Evidence and limits](STORM.md#irregular-shapes-and-stronger-flash---2026-09-19).

2026-09-19 V02/V04/V05: rebuilt Storm wet-glass presentation from owner mockup/shader attempt: layered beads, stronger refraction and winding rivulets. 53 checks passed. [Evidence/limits](STORM.md#wet-glass-reference-rebuild---2026-09-19).

2026-09-19 V02/V04/V05: Storm droplets cling/grow, slip in curved bursts and settle again; fading trails follow their travelled path. 53 checks passed. [Evidence and limits](STORM.md#clinging-and-slipping-droplets---2026-09-19).

2026-09-19 V02/V04/V05: original refractive Storm lens shader replaces outlined beads, with sparse falling drops and soft highlights. 51 checks passed; [evidence and limits](STORM.md#refractive-lens-water---2026-09-19).

2026-09-19 V02/V04/V05: more visible falling Storm lens droplets, accelerating trails and occasional centre placement. 51 checks passed; [captures and acceptance](STORM.md#falling-lens-droplets---2026-09-19).

2026-09-19 V02/V04/V05: Storm lens droplets enlarged 4x and lightning illumination strengthened. 51 capture checks passed; updated screenshots/video, no device test. [Follow-up](STORM.md#larger-droplets-and-brighter-lightning---2026-09-19).

2026-09-19 G01/R01/R03/R07/T02/V02-V05: Storm biome with mild wet-road grip, overcast light, rain, restrained lens droplets and delayed thunder/lightning. Physics 0.29. [Changes, commands, captures and limits](STORM.md).

2026-09-18 R01/G01/V02/V03/V05/Q01: Easy night lamp cost confirmed on the attached phone; spatial light culling and a mobile-night 3D render budget improve sustained presentation. [Measurements, tests, visual tradeoff and acceptance](NIGHT_LIGHTING_PERFORMANCE.md).

2026-09-18 R01/G01/V03/V05/Q01: Play selection no longer synchronously compiles and rebuilds a live circuit preview. [Changes, phone timings and acceptance limits](PLAY_MENU_PERFORMANCE.md).

2026-09-18 R01/G01/V03/V05/Q01: attached-phone Knot tyre-pile performance pass; preserve exact collision results and reduce redundant presentation uploads. [Implementation, measured limits and acceptance](KNOT_TYRE_PERFORMANCE.md).

2026-09-18 G01/R01/V02-V05: mechanical cel-shaded pedals with exposed mounts, bevelled plates, recessed grips and restrained wear. 216 capture/HUD checks passed. [Evidence and device limits](VEHICLE_CONTROLS.md#mechanical-pedal-refinement--2026-09-18).

2026-09-18 G01/R01/R03/R07/T02/V02/V04/V05: milder winter traction and soft snowbanks along asphalt edges. Physics 0.28. [Changes, metrics, tests and device limits](WINTER_ICE.md#milder-winter-handling-and-soft-snowbanks---2026-09-18).

2026-09-18 G01/R01/V02-V05: distinct illustrated steering/pedal controls for all five vehicles; 161 regression checks and 125 skin/target checks passed. [Captures, commands and phone acceptance](VEHICLE_CONTROLS.md).

2026-09-18 G01/R01/R03/R07/T02/V02/V04/V05: winter asphalt now has icy traction and frost visuals, including bridges. Physics 0.27. [Commands, measured behavior and acceptance](WINTER_ICE.md).

2026-09-18 V02/V04/V05: darker night outside street lamps; reduced ambient/moon lighting. 41 capture checks passed. [Evidence and device limits](BIOME_CREATION.md#darker-night-follow-up---2026-09-18).

2026-09-18 R01/T01-T04/V02-V05: Grass/Desert/Night city/Winter replace the three-biome picker; warm street-lamp illumination and snow presentation. [Actual checks, captures and device limits](BIOME_CREATION.md#four-biome-revision--2026-09-18).

2026-09-18 R01/T01?T04/V03/V05: Create/New require large biome cards before entering an empty track; biome locked and nature palette filtered. [Changes, checks, captures and device limits](BIOME_CREATION.md).

2026-09-17 R01/T01-T04/V03/V05: closer-reference panel/card styling and larger previews; removed drawer settings icon, retained options through selected asset. [Changes and checks](EDITOR_STYLE.md#reference-refinement--2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: removed editor hint bar, balanced palette padding and separated Undo/Redo from track identity. [Layout follow-up](EDITOR_STYLE.md#layout-follow-up--2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: screenshot-guided editor styling, unified rail, slimmer asset drawer, selected-only cyan and green Test/play. [Changes, checks and acceptance](EDITOR_STYLE.md).

2026-09-17 R01/T01-T04/V03/V05: reference-style Free/Area/Line buttons in top controls, live brush-size slider and fine adjustment. [Captures, checks and device limits](SURFACE_USABILITY.md#reference-style-top-paint-controls---2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: in-draft surface confirmation, separate placement toolbar, Oil spill in Objects and no Road in Surfaces. 315 checks pass. [Captures, commands and device limits](SURFACE_USABILITY.md).

2026-09-17 V02/V04/V05/R01/T01-T04: removed stepped shoulder/painted-sand join with decorative-only sand blending. 34 graphical checks pass. [Close-up and device limits](SURFACE_MODES.md#continuous-shoulder--painted-sand-join---2026-09-17).

2026-09-17 V02/V04/V05/R01/T01-T04: painted sand matches the road shoulder tint and shared granular texture. 33 graphical checks pass. [Close-up, commands and device limits](SURFACE_MODES.md#matched-sand-color-and-grain---2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: corrected bright unpainted-road fringe regression; decorative verge replacement is now restricted to authored paint footprints. 63 checks pass after failing reproduction. [Captures and device limits](SURFACE_MODES.md#unpainted-road-regression-correction---2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: protected surface paint now replaces decorative roadside grass; outer grass edges share the road shoulder fringe. 61 checks pass. [Screenshot, commands and device limits](SURFACE_MODES.md#roadside-verge-follow-up---2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: line/area/free surface modes, draggable draft points, explicit confirmation, rounded contours and blended material boundaries. [Actual tests, screenshots and Android limits](SURFACE_MODES.md).

2026-09-17 R01/T01-T04/V03/V05: automatic-only waypoints; retired all 194 Slicks circuits from the playable/export catalog and unsupported native bases. Original starter keeps fresh installs playable. [Actual tests, screenshots and device limits](AUTOMATIC_WAYPOINTS.md).

2026-09-16 R01/T01-T04: fixed stale selected geometry after explicit creator Save; immediate Home Race regression passes. [Actual checks and acceptance limits](SAVED_TRACK_REFRESH.md).

2026-09-16 R01/T01-T04/V03/V05: all road types expose simultaneous labeled directional handles directly on previews and selections. [Actual checks, captures and device limits](ROAD_PLACEMENT.md#direct-preview-controls-follow-up).

2026-09-16 R01/T01-T04/V03/V05: hairpins expose separate Straight length; new pieces default to zero straight arms. 285 checks pass. [Captures, commands and phone limits](ROAD_PLACEMENT.md#hairpin-straight-length-follow-up).

2026-09-16 R01/T01?T04/V03/V05: independent S-bend height, equal hairpin arms and on-road tap/drag acceptance. Compiler-11. [Actual tests, screenshot and device limits](ROAD_PLACEMENT.md).

2026-09-16 V02/V04/V05/Q01/R01: owner-requested gameplay 2x MSAA enabled; graphics controls deferred on wishlist. [Actual checks, screenshot and mobile acceptance](GAMEPLAY_ANTIALIASING.md).

2026-09-15 V02/V04/V05: owner-directed grey handrails and asphalt material revision, track-kit-22. [Actual captures, checks and remaining acceptance](GREY_RAILS_ASPHALT.md).

2026-09-15 V02/V04/V05: owner-directed asphalt texture restoration and simpler/higher handrails implemented. [Changes, 168 passing checks and remaining acceptance](ROAD_RAIL_REFINEMENT.md).

2026-09-15 V02/V04/V05: patchy-asphalt owner correction, track-kit-20; more even shared asphalt with retained verge refinement. [Capture and acceptance limits](ROAD_REFINEMENT.md).

2026-09-15 V02/V03/V05/Q01/R01: minimap roads cached separately from the player marker and reduced to thin placed-road lines. Desktop redraw callback ~6 ms to ~0.05 ms; 95 graphical checks pass. [Measurements, capture and device limits](MINIMAP_PERFORMANCE.md).

2026-09-15 V02/V04/V05/Q01: owner-authorized road review items 1 and 2 implemented in track-kit-19. Shared asphalt tonal refinement and slower creator verge variation; 332 focused checks pass. [Actual evidence and acceptance limits](ROAD_REFINEMENT.md). Driving-data wear remains deferred.

2026-09-15 V02/V03/V04/V05/G01/R01/R07: reference-shaped HUD, icon menu, raised pedals and blue/concrete bridges; minimap exclusively follows placed road pieces on new creator tracks. 264 focused checks pass. [Evidence, commands and phone acceptance](REFERENCE_HUD.md).

2026-09-15 V02/V03/V04/V05/G01/R01/R07: bridge steel rails and shaded deck fascia refined; racing HUD uses navy/cream/gold Barlow styling with separate lap, timer, actions and compact speed. 412 focused checks pass. [Actual captures, commands and phone limitations](BRIDGE_HUD.md).

2026-09-15 V02/V04/V05: kerb crown/bevel/base shading strengthened for normal gameplay-camera readability; physical height and response unchanged. 195 focused checks pass. [Captures and acceptance limits](KERB_READABILITY.md).

2026-09-15 G01/V02/V04/V05/R01/R03/R07: visual body suspension reacts to acceleration, braking, cornering, impacts, jumps and bridge transitions, with bounded hard-contact sparks. Canonical handling unchanged. [Actual checks, captures and acceptance limits](VISUAL_SUSPENSION.md).

2026-09-15 G01/V02/V04/V05/R01/R03/R07: raised kerbs share 10 cm bevelled geometry with deterministic tyre contact and a small spring/speed response. Physics 0.21, compiler-10, recorder schema 7. [Actual checks, captures and device limits](RAISED_KERBS.md).

2026-09-15 V02/V04/V05: owner-directed grass/road/lighting restoration and three-door hatchback model correction. 70 driving checks pass; gameplay and model captures saved. [Changes, evidence and acceptance limits](HATCHBACK.md).

2026-09-15 V02/V04/V05: first illustrated gameplay pass adds cream/blue car detail, quieter grass/asphalt and revised race lighting. 70 driving and 158 road-piece checks pass; desktop capture inspected. [Evidence and remaining art/device acceptance](ILLUSTRATED_WORLD.md).

2026-09-19 G01/R01/R03/R07: owner requested a more accessible, intuitive and fun compact with a little more drift, then requested it as a comparison option. Separate Drift+ handling 0.16 adds powered slip, calmer steering onset and quicker recovery; Original+ remains unchanged and default. [COMPACT_HANDLING_REFINEMENT.md](COMPACT_HANDLING_REFINEMENT.md) records metrics, verification and remaining human/device acceptance.

2026-09-14 G01/R01/R03/R07: owner prefers Original and requests more slip plus strong forward drive while sliding. Original+ is the focused tune; unchanged Original remains selectable. [ORIGINAL_SLIDE.md](ORIGINAL_SLIDE.md) records configuration, bounded power recovery, measured behavior and actual verification.

2026-09-14 V02/V03/G03: owner rejects blocky menu art and selects detailed automotive ink/cel style. Original illustrated Home/Garage hero replaces procedural menu scenery. [ILLUSTRATED_MENUS.md](ILLUSTRATED_MENUS.md) records assets, actual checks/captures and remaining visual/device acceptance.

2026-09-14 G01/R01/R03/R07: owner reopens focused handling iteration with supplied fun-handling notes. Progressive steering, brake rotation and recovery are implemented with an old-physics comparison preset. See [HANDLING_FUN.md](HANDLING_FUN.md) for actual checks, identity changes and pending human/phone acceptance.

2026-09-14 V02/V03/G03/R01/R04/R06/R07: owner-supplied premium menu board authorizes the local presentation revision and warm yellow primary-action override. [PREMIUM_MENUS.md](PREMIUM_MENUS.md) records behavior, actual evidence and remaining visual/device acceptance. Reference online/economy panels do not expand the current slice.

2026-09-14 R01/T01-T04/V02/V04/V05: centred biome/rename dialogs, keyboard-aware rename placement, taller rail, transparent header and grey disabled Test. [Checks and captures](EDITOR_WIP_WORKFLOW.md).

2026-09-14 R01/T01-T04/V02/V04/V05: centred editor rail, simplified header/menu, biome and waypoint tools, fixed object paging and independent WIP autosave. [Actual checks and captures](EDITOR_WIP_WORKFLOW.md).

2026-09-14 R01/T01-T04/V02/V04/V05: Curvy follow-up removes folded marking tails and cap-directed kerb spikes. [Actual checks and closer captures](KERB_JOIN_FIXES.md).

2026-09-14 R01/T01-T04/V02/V04/V05: reference layout follow-up: grouped raised rail, green text-only Test, track name, charcoal tiles, road glyphs and Jump in Objects. [Actual checks and captures](EDITOR_PRESENTATION_REFINEMENT.md).

2026-09-14 G01/R01/V02/V04/V05: traversable water with gradual car submersion and separate long-lived oil / short-lived water tire coatings. [Behavior, actual verification and device limits](SURFACE_RESPONSE.md).

2026-09-14 R01/T01-T04/V02-V05: owner rejects inconsistent editor controls and blockout graphics. [EDITOR_PRESENTATION_REFINEMENT.md](EDITOR_PRESENTATION_REFINEMENT.md) records this presentation/input slice and its uncompleted AAA art target.

2026-09-14 R01/T01-T04/V02/V04/V05: shared road joins, gradual connected widths and road-aligned full-width start line. [Implementation, checks and Curvy/Blind spot captures](ROAD_JOIN_FIXES.md).

2026-09-14 R01/T01-T04/V02/V04/V05/G01: owner supplied category/asset references, confirmed movable tyres and requested movable light props with future biome-specific palettes. [OBJECT_BROWSER.md](OBJECT_BROWSER.md) records this local slice.

2026-09-14 R01/T01-T04: editor Load now shows all saved tracks immediately; empty search no longer hides the list. [Fix, actual checks and screenshot](EDITOR_LOAD_LIST.md).

2026-09-14 R01/T01-T04: saved tracks and unfinished drafts now have confirmed deletion, including recovery-file cleanup and library/selection refresh. [Actual checks, screenshots and limits](USER_TRACK_DELETION.md).

2026-09-14 V02/V04/V05/R01/T01-T04/G01: owner-authorized scenery, scaling and hazard slice. [CREATOR_HAZARDS.md](CREATOR_HAZARDS.md) records tapered kerbs, solid editable trees, shared bridge style and deterministic jump/oil/water behavior, with actual checks and remaining phone acceptance.

2026-09-14 V02/V04/V05: track-kit-10 gives each kerb run complete equal blocks with white beginnings/endings. Actual screenshot and 138 passing checks: VISUAL_STYLE.md.

2026-09-14 V02/V04/V05: track-kit-9 integrates original painted grass, mipmapped detail, broad colour variation and a broken grass/gravel blend from the new texture direction. See VISUAL_STYLE.md for actual captures/checks and PAINTED_GRASS_PROMPT.md for generation provenance.

2026-09-14 V02/V04/V05: track-kit-8 corrects flat-mesh normals, removes microscopic edge segments causing sand spikes, separates terrain layers and filters sand grain. Actual captures/tests: VISUAL_STYLE.md.

2026-09-14 V02/V04/V05: track-kit-7 fixes kerb spacing along actual edge distance, closes segment seams, procedurally roughens shoulders and omits sand behind kerbs. Actual checks and Silmukka capture: VISUAL_STYLE.md.

2026-09-14 V02/V04/V05 follow-up: corrected grass, branch shapes, decorative stone scale, grey tree footprints and creator roadside shoulders/inner kerbs. Track-kit-6 actual Silmukka screenshot and checks are recorded in VISUAL_STYLE.md.

2026-09-14 V02/V04/V03/R01/V05: reference-led woodland visual revision, shared textured materials, irregular pines, selective outlines and driving-control icons. See [VISUAL_STYLE.md](VISUAL_STYLE.md) for actual evidence and acceptance limits.

2026-09-14 G01: owner requests stronger initial tyre impacts, pushable individual stacks and torque-limited piles. [TYRE_PUSHING.md](TYRE_PUSHING.md) records implementation and actual validation.

2026-09-14 G01/R01/T02-T04: owner requests more resistant tyres and direct loading for continued local editing. Shared-version immutability is recorded for the later publication lifecycle. [TYRE_RESISTANCE_AND_LOADING.md](TYRE_RESISTANCE_AND_LOADING.md) records implementation and actual validation.

2026-09-14 R01/T01-T04/V05/G01: owner requests practical creator refinements and moving tyres. Implemented with compiler-6 / arcade-planar-0.13 and bounded optional v5 fields. [CREATOR_REFINEMENT.md](CREATOR_REFINEMENT.md) records actual commands and outstanding device acceptance.

2026-09-13 R01/T01?T04/V05: owner authorizes direct body/end-dot editing, PC controls and bridge authoring, superseding the ground-only bridge restriction. [CREATOR_CONSTRUCTION.md](CREATOR_CONSTRUCTION.md) records implementation and actual evidence.

2026-09-13 R01/T01–T04/V05 review: owner requests a usability review after accepting the improved editor direction. [CREATOR_USABILITY_REVIEW.md](CREATOR_USABILITY_REVIEW.md) records eight reproduced findings and proposes edit protection, race readiness and connected editing as the next slice. This checkpoint changes review tooling/documentation only; implementation decisions remain outstanding.

2026-09-13 R01/T01–T04/V03/V05: owner wireframe directs compact overlays over the full-screen track, place-and-connect road pieces, local geometry controls, roadside props and visual issue recovery. Implemented in creator-track-v4 with retained free painting and independent lap route. Wireframe untimed practice overrides editor-only five-lap runs; regular races stay five laps. [WIREFRAME_EDITOR.md](WIREFRAME_EDITOR.md) records commands, captures and remaining phone/visual acceptance.

2026-09-13 R01/T02/V03/V05: owner requests full-screen creator and usable detail editing. Dedicated canvas with overlay tools, anchored close zoom and fine brushes implemented; actual commands, checks and unperformed phone acceptance are in [FULLSCREEN_EDITOR.md](FULLSCREEN_EDITOR.md). No physics/camera/content expansion.

2026-09-12 V03/G03/R01/R04/R06/R07: owner requests stronger menu presentation and player motivation. Race invitation, persistent last circuit, explicit PB target and improvement debrief are implemented; see [RACE_PRESENTATION.md](RACE_PRESENTATION.md). No progression or online-service expansion.

2026-09-12 T01–T04 / V05 / R01: owner rejects spline-only editing and selects free-shaped roads, terrain, intersections and obstacles. Independent painting/lap-route authoring and native remixes are implemented in v3; see [FREE_FORM_EDITOR.md](FREE_FORM_EDITOR.md) for actual checks, evidence and phone limitations. Existing handling and five-lap rules are preserved.

2026-09-12 latest owner override: **five laps** for ordinary races and creator test drives, replacing the historical three-lap selection below. Track discovery now uses a visual library, favorites, name/creator search, theme/sort filters and random selection. See [TRACK_LIBRARY.md](TRACK_LIBRARY.md) for V03/R01/R04/R06/R07 coverage, actual validation and phone acceptance still outstanding. Historical diagnostic replay fixtures explicitly retain three laps.

2026-09-12 V03/G03/R01/R06 menu follow-up: owner explicitly selected Hill Climb Racing 2 as navigation reference. Direct race hub and simplified tabs implemented; 86 graphical app checks pass. Full validation has six creator failures during concurrent format work; phone and owner acceptance remain pending. See [HCR2_MENU_REVIEW.md](HCR2_MENU_REVIEW.md) for actual commands, scope and screenshot.

## Current owner authorization: 2026-09-12

The owner now accepts the car's handling and collisions and explicitly asks to advance to menus, several more Slicks circuits, a phone-friendly map creator and shared visual themes. This later request overrides the earlier editor/content restriction for one local slice. Implemented scope is the local Play/Garage/Tracks/Create/Settings/results flow, three more native circuits, bounded local authoring/sharing and Pine/Coast/Desert presentation. The initial creator uses simple draggable handles over a starter loop rather than exposing advanced spline tangents; this is the current phone-usability proposal under the owner's request.

See [MENUS_AND_CREATOR.md](MENUS_AND_CREATOR.md) for changed files, requirements, actual commands/outcomes and screenshots. The history below remains the original inspection/order. It no longer means handling is unapproved. Physical-phone/camera/performance gates and competition-grade timing validation are still pending; backend, store, progression and hosted UGC are not part of this authorization.

## Owner-authorized handling fixture update, 2026-09-11

The later explicit request for `slicks_codex_handoff.zip/CODEX_TASK.md` authorizes four native test circuits inside the handling gate, overriding the one-circuit quantity for these development fixtures only. Inspection preceded implementation: the yard had no native circuit/importer/surfaces/laps/AI. A small `PlaygroundData` subclass, practice lap session and diagnostic driver now provide those foundations; they do not complete the full Phase 5 countdown/PB/competition validator or imply handling approval. Three laps still applies. No store/backend/editor expansion occurred.

Actual commands, source semantics, scale measurements, correction, full replay results, screenshots and manual checks are current in [SLICKS_IMPORT.md](../SLICKS_IMPORT.md). Validation passes 56 driving and 48 track checks plus four offline converter tests. The regular follow-camera calibration is still pending; F4's requested overview is a separate debug view. Android Doctor still fails missing prerequisites; no device test or export occurred.

Reviewed 2026-09-11. The current owner request narrows the active work to proving driving on Windows and a physical Android phone. Phase numbers in that request (0–7) are implementation steps inside the blueprint's P0/P0-V gates; they are not permission to start the blueprint's later P1–P7 product expansion.

## Source review

The extracted `Android_racing_game_blueprint_v2/` is the supplied package. All 71 files listed in its manifest match SHA-256. Reviewed the 22-chapter maintainable master, reading editions, architecture, rendering handoff, agent/first-task instructions, API/schema examples, roadmap, 51 requirements and corresponding backlog, planning/economy records, launch plan, validation reports, reference gallery and HTML prototype. Inspected every supplied PNG and all 16 pages of the UI guide. Opened all nine financial workbook sheets, including assumptions, cohort formulas, cash timing and founder-time treatment. The financial workbook remains byte-identical to the supplied baseline. No prices or commercial forecasts are adopted as gameplay requirements.

The gameplay source and derived 1.15x image were inspected separately at full size. The six menu crops, menu-only board, source board, material reference, asset crops and eleven UI screens have distinct roles. The menu board's chase cameras are explicitly rejected. The HTML interactions and its sample records are illustrative; no online or commerce code belongs in this slice.

## Definitive requirements

- Local-first, Godot standard, typed GDScript and minimal dependencies. Windows is the development platform; physical Android driving is a completion gate.
- One fictional, proportionate car. Compact arcade planar simulation: prompt steering, meaningful throttle/brake, momentum, recoverable slip, countersteering and collision energy loss. No wheel/rigid-body tire solver.
- Handling Resource owns mass, engine/brake force, drag, rolling resistance, speed cap, steering rate/high-speed reduction, lateral and longitudinal grip, front/rear balance, slip threshold, recovery, yaw inertia, assistance, throttle rotation and collision loss. Document units and bounds when implemented.
- One circuit: short straight, fast bend, braking corner, hairpin, chicane and an oversteer opportunity. Aim for 15–20 seconds per lap within the accepted 10–30-second envelope. Exactly three laps in the first slice.
- Standing countdown; time starts at GO. Ordered directed swept gates reject shortcuts and reverse crossings. Keep standing first lap separate from flying-lap PB. Current, previous and best lap, race total, persistent local PB and essentially immediate retry.
- Fixed 120 Hz simulation proposal, quantized input and explicit physics/rules/content identities. Timing derives from ticks plus swept crossing fraction and is stored as integer milliseconds. Rendering does not determine time. Fixed-step floating point is not a claim of cross-device determinism.
- Keyboard and four simultaneous touch inputs. Cancellation/backgrounding releases all input. UI is a view of race state, never the timing authority. Debug telemetry is optional and excluded from release presentation.
- High-oblique follow camera, no horizon, stable yaw, local track coverage. Adjustable projection/height/pitch/look-ahead/smoothing; no dynamic zoom during calibration. World extent becomes baseline / 1.15 for orthographic projection. Car mesh, road geometry and HUD retain scale.
- Mature graphic-novel cel-shaded 3D: matte planes, restrained colours, stepped light and selective contours. Original stand-ins are acceptable for handling; polish follows feel approval. Reference crops are not shipping assets.
- No energy, lives, paid retry or progression block. No backend, account, store, SDK analytics, ads, payments, leagues, upgrades or editor implementation at this gate.

## Differences, risks and decisions

| Item | Evidence and action |
|---|---|
| Three versus four laps | Blueprint first task/default says four; latest owner instruction explicitly says three. Use three in the slice. Preserve original package and record this override in root AGENTS.md. Future lap count remains data-driven. |
| Engine discovery | PATH resolves 4.6.2, but `C:/apps/Godot 4.7.2/` contains the blueprint's 4.7.2 standard engine. Verified `4.7.2.stable.official.ed1daf0bf`; pin the full build and matching 4.7.2.stable templates. Never silently fall back to PATH's older binary. |
| Renderer | Compatibility is a reversible bootstrap baseline for simple 3D. Compare it with Mobile using the same scene on the actual phone before deciding the visual pipeline. |
| Camera angle/extent | The package approves image proportions, not a numeric pitch or physical height. Calibrate a repeatable pose at 1672×941, measure projected car bounds before/after (1.15 ±0.03), then check every heading and wider landscape ratios. |
| Rotation controls | Developer-adjustable rotation experiments can exist, but default and acceptance profile keep world yaw stable. Heading-locked rotation needs an explicit reviewed experiment. |
| Timing/PB | Interpret PB as best valid full race; show a separate flying-lap best. Pause/respawn marks an attempt practice. Restart creates a fresh standing-start attempt. Countdown is deliberately excluded from the warm reset cost. |
| Performance target | Requirements Q01/master give p95 ≤20 ms; visual acceptance suggests ≤16.7 ms. Record both; target ≤16.7 ms for the visual gate without claiming it is measured or silently weakening either. |
| Touch sequencing | Input actions are established in bootstrap, keyboard in the playground, reusable touch sampling next to keyboard before phone evaluation. Final layout/device testing follows the requested Phase 6. No mouse-emulated touch acceptance. |
| Fun cannot be automated | Physics invariants and telemetry can find faults; only driving can approve feel. Stop expansion for a focused handling iteration when the owner finds it unsatisfying. |
| Replay | Use an isolated typed planar core and input capture experiment. Cross-platform equivalence remains unproved until replay corpus tests on Windows and Android. No premature fixed-point framework. |
| Track schema | Starter schema covers geometry, not every future metadata field. Keep authored Resource metadata separate and map to a deliberately versioned export schema later. Do not claim imported Resources are safe user content. |
| Art cost | Workbook assumes 1,000 prelaunch hours and predates the additional P0-V allowance. The 2–4 added person-weeks do not estimate every finished car/track. Preserve the model; measure one car/corner before scaling. |
| Android prerequisites | No configured SDK/ADB, JDK or matching export templates were found in the inspected locations. Bootstrap supplies checks and commands; APK/install/phone acceptance remain open until those exist. |

## Exact repository structure

```text
AGENTS.md                        current project instructions and explicit overrides
README.md                        run/build loop and scope
DEVELOPMENT_STATUS.md            actual progress, tests, decisions and debt
godot-version.txt                exact engine build
Android_racing_game_blueprint_v2/ unchanged authoritative source, outside res://
docs/
  PHASE_0_PLAN.md                this review and implementation order
  ANDROID.md                    setup and physical-phone acceptance
  evidence/                     reviewed screenshots and command results
licenses/                       original asset ledger and engine notices
scripts/dev.ps1                 doctor, validate, run, export, install and launch
game/
  project.godot
  export_presets.cfg
  core/                         composition root and lifecycle
  vehicle/                      canonical planar state/step, separate 3D presenter
  input/                        quantized frame + keyboard/touch adapters
  track/                        metadata, surface/collision/gates, mesh builder
  race/                         RaceSession and immutable run manifest
  timing/                       clock and directed swept-gate evaluation
  camera/                       presentation-only rig and calibration fixture
  ui/                           race HUD, touch views and debug telemetry
  persistence/                  local atomic PB save and replay/telemetry files
  resources/                    authored handling/car/track/camera profiles
  tests/                        headless domain tests and replay fixtures
build/                          ignored APKs, screenshots and logs
.tools/                         ignored document-review tooling
```

Bootstrap creates module directories; implement classes only as needed. `Game` composes modules. `RaceSession` receives quantized input, canonical vehicle state and track data; timing consumes swept movement. UI observes state/signals. Persistence runs outside the simulation step. Map simulation `(x,y)` to world `(x,0,-y)`, with zero heading along simulation +Y/world -Z. Document heading sign before physics code. Share track definitions between visual and collision builders.

Online work later consumes versioned run manifests through adapters, without changing the local step. Replay inputs/snapshots enable ghosts later. Track identity, creator, immutable geometry version, spawn, gates, surfaces, theme and validation metadata belong to authored content data. Upgrade/tuning definitions will be Resources when progression is implemented; no empty backend or upgrade framework now.

## First eight implementation tasks

| # | Work | Requirements | Evidence to finish |
|---|---|---|---|
| 1 | Phase 1 bootstrap: pinned project, input map, module boundaries, Git, build scripts, Android preset and README | G01, R01, Q01 foundations | CLI import, all scripts parse, main-scene startup, graphical Windows capture; explicit Android prerequisite report |
| 2 | Phase 2 playground: flat surface, one original car, typed state + handling Resource, keyboard driving, collision fixtures and rapid parameter reload | G01 | Acceleration/braking, steering reversal, lateral recovery and collision tests; executable playground |
| 3 | Phase 2 instrumentation: toggle telemetry, parameter variants, quantized input log and replay-format spike; reusable simultaneous touch adapter | G01, R01, A02 preparation | HUD values, safe release/cancel, same-input repeatability report and explicit divergence if any |
| 4 | Phase 3 camera: adjustable fixed-yaw rig, calibration pose and matched screenshots | R02, V01 | 1672×941 source/target/engine comparison and projected bounds; no car-only scaling; all-heading visibility |
| 5 | Phase 4 test circuit, shared visual/collision/gate data and versioned metadata | G01, G02, R03 foundations | Hairpin/chicane/braking/fast bends; measured 15–20-second baseline laps; no scenery polish |
| 6 | Phase 5 three-lap session, countdown, swept gates, separate timers, local PB and reset | G02, R03, R04, R06, R07 | Wrong-way/cut/order/high-speed tests, exactly three laps, no countdown time, frame-rate independence, practice invalidation and save recovery |
| 7 | Phase 6 phone: APK, ADB install/launch, four-button layout, safe insets and 20-minute driving session | G01, R01, Q01 | Named physical phone/build, ten consecutive lap times, slide/restart/touch feedback and frame pacing; iterate feel before expanding |
| 8 | Phase 7 initial material pipeline after handling approval; one representative car/corner and renderer comparison | V02, V04 | Matte stepped shading/selected contours, matched engine capture, moving full lap and device profile; no full art/content production |

The first subjective question is whether steering, braking and catching a slide feel immediate and learnable. It is not whether a boot screen looks polished. Full visual P0-V, garage compositions and external test recruitment follow owner handling approval; do not contact testers automatically.

2026-09-12, current handling gate: corrected bridge approach presentation on the authorized fixtures without extending the canonical simulation. Shared ramp geometry, car pitch and skid height passed Windows validation (24 parses, 56 driving + 57 track checks); three AI laps per fixture and exact replays passed. See [RAMP_FIX.md](RAMP_FIX.md) for commands, screenshots and remaining off-route/manual/phone acceptance. No phone test was performed.

2026-09-12 owner feedback authorizes a focused surface/presentation revision of the existing four handling fixtures: low obstacles become speed penalties and the matte terrain kit is improved. This does not advance the handling gate or authorize broader content. Native schema/content v2 and physics 0.6 are tested with 56 driving + 76 track checks, four converter checks and four schema validations. Current commands, screenshots and acceptance limits: [TRACK_SURFACES.md](TRACK_SURFACES.md). No phone test was performed.

2026-09-12: investigated the owner's live stuck ramp state and corrected collision recovery within G01. Native overlaps now permit safe outward movement; swept transitions test the destination layer before commitment. No content or camera expansion. Physics 0.7 passed 56 driving + 94 track checks and full three-lap replays. Evidence and manual restart/acceptance instructions: [RAMP_RECOVERY.md](RAMP_RECOVERY.md). No phone test was performed.

2026-09-12: G01 owner-requested collision rebound tuning is implemented as a shared parameter change (handling-0.9, restitution 0.38). No architecture/content expansion. Validate passed 56 driving + 96 track checks, including visible-separation metrics, energy loss, ramp recovery and full replays. See [DRIVING_PLAYGROUND.md](DRIVING_PLAYGROUND.md#collision-rebound---2026-09-12) for actual commands and remaining feel/phone acceptance; no phone test was performed.

2026-09-12: G01 impact tuning now rotates the car after oblique collisions and increases rebound, per both owner requests. Handling-0.10 / physics 0.8 passed 56 driving + 107 track checks with replay, ramp recovery, bounded energy and powered-reverse safeguards. Existing track/art scope is unchanged. Details and manual/phone acceptance remain in [DRIVING_PLAYGROUND.md](DRIVING_PLAYGROUND.md#impact-rotation-and-stronger-recoil---2026-09-12); no phone test was performed.

## G01 wall-slide iteration - 2026-09-12

Owner requests continued tangential travel and gradual alignment while pushing against a barrier. Implemented within the handling gate using the existing native collision resolver and shared response; no architectural expansion or track format changes. TestTracks passes 115 checks; measured mirrored powered wall starts travel 8.918 m in 3 seconds and align within 0.934 degrees. See docs/DRIVING_PLAYGROUND.md (Sustained wall sliding) for changed files, commands and limitations. Windows owner feel and physical-phone acceptance remain pending.
Final full Validate passed import, 24 parses, startup and 171 checks (56 driving + 115 track). Evidence: docs/evidence/wall-slide-*.txt.

2026-09-12 G01: owner requests less recoil; handling-0.12 tunes restitution to 0.45, preserving wall-slide algorithms. Full Validate passed 171 checks and measured 29% shorter rebound. Commands, changed files, revised owner balance target and evidence are in DRIVING_PLAYGROUND.md (Moderate recoil). Manual feel/phone acceptance remains pending.

2026-09-12 G01: owner-authorized softer recoil and temporary dirty-tire grip loss implemented within the handling gate. Pickup/recovery follow distance, with grass depositing less than dirt/sand and full cleanup after 80 m. Handling-0.13, physics arcade-planar-0.10 and diagnostic schema 3 version the state extension. Validate passed all 189 checks, four three-lap AI runs, exact replay and ramp recovery. See DRIVING_PLAYGROUND.md (Tire contamination and softer recoil) for commands, files, evidence and pending owner/phone acceptance. No track format or content expansion.

2026-09-12 G01 ramp follow-up: live 1WAY inspection led to footprint-aware rail-tip activation and consistent overlap recovery across collision layers (physics arcade-planar-0.11). Scope remains existing handling fixtures; no art/content/schema expansion. Validate passes 207 checks, all four three-lap AI/replays, original ramp recovery and both-end isolated rail tests. Commands, changed files, live evidence and pending owner/phone acceptance: RAMP_RECOVERY.md (Rail-tip activation).

2026-09-12 G01: owner-reported stop/turn/surge reproduced and corrected in native collision handling (physics arcade-planar-0.12). Coplanar-wall overlap now permits tangential motion; rejected velocity cannot accumulate for later release. Validate passed 219 checks and all original ramp/rail/lap/replay safeguards. Actual commands, files, before/after metrics and pending owner/phone acceptance: DRIVING_PLAYGROUND.md (Wall motion and acceleration consistency). No content/schema/art expansion.
## Editor follow-up: 2026-09-12

Owner authorizes sharp bends, per-node widths and built-in object editing (T01–T04 / V05 / R01), explicitly waiving backward compatibility for user tracks. The v2 contract and revised bend rules supersede initial creator limits. See [EDITOR_V2.md](EDITOR_V2.md) for actual commands, passing validation, screenshots and unperformed phone acceptance.

2026-09-12 G02/R03/R01: owner extends native test content to all 194 distinct locally supplied Slicks tracks. Author search uses retained source attribution or flagged deterministic fictional names. See SLICKS_CORPUS.md for actual commands/results, eight unresolved route-planner cases and remaining individual lap/bridge/device checks.

2026-09-12 G02/R03/R01: bulk straight-bridge axis correction fixes YLIKULKU overpass/underpass layering. Actual validation: 793 corpus checks, 163 original track checks, three YLIKULKU AI laps with zero contacts. See SLICKS_CORPUS.md and bridge-axis evidence; mixed-orientation bridges remain a separate limitation.
# 2026-09-15 local PB follow-up

Tracks PB lookup now matches the selected handling used to save races. Original+ remains the owner-confirmed startup default. Requirements R01/R04/R06/R07; actual checks, screenshot and remaining device acceptance: [LOCAL_BEST_FIX.md](LOCAL_BEST_FIX.md).
# Race-start follow-up, 2026-09-15

G01/V03/V05/R01/R07: owner-requested start clearance and raised countdown/GO implemented. See [RACE_START.md](RACE_START.md) for actual checks, screenshots and remaining phone acceptance.

2026-09-15 owner handling follow-up: stronger soil penalties, visible dirty-tire cleaning and self-righting rollover implemented within G01/R01/R03/R07/V02/V04/V05. See [SOIL_RECOVERY.md](SOIL_RECOVERY.md) for actual validation and outstanding owner/device acceptance.

2026-09-15 handling correction: rollover now follows sideways travel and completes in 0.6 seconds. Requirements, actual checks and pending owner/phone acceptance: [ROLLOVER_CORRECTION.md](ROLLOVER_CORRECTION.md).

2026-09-15 visual handling follow-up: grounded rollover and landing suspension. Canonical timing/physics unchanged; 156 focused checks pass. See [GROUNDED_ROLLOVER.md](GROUNDED_ROLLOVER.md).

## Four-car local slice, 2026-09-15

Owner authorizes three additional car classes and complete menu/art/model/handling support. Requirements G01/G03/V02-V05/R01/R03/R04/R06/R07; see [CARS.md](CARS.md) for changed files, version contracts, measured balance, commands, actual screenshots and remaining manual/phone acceptance. No commerce, online services or gameplay camera expansion.

## Shortcut validation correction, 2026-09-16

G01/R03/R07/T02: owner reports false hairpin/kerb penalties. Replaced nearest-progress jump heuristics with automatic ordered swept route coverage, local road/kerb tolerance and early shortcut feedback after 0.4 s / 2 m of confirmed later-route rejoin, with finish-time fallback. Five valid laps and local-only scoring remain. See [ROUTE_PROGRESS_VALIDATION.md](ROUTE_PROGRESS_VALIDATION.md) for review, changed files, actual commands/results, full-validation engine crash and remaining owner/device acceptance.

## Owner rejection of shortcut v3, 2026-09-16

G01/R03/R07/T02/V05: rejected dense coverage and delayed feedback are superseded by signed swept progress with spatial bypass proof, immediate +5s feedback, a persistent two-second HUD notice and counted penalized laps. Rules v4. Actual tests, saved-track trajectories, screenshots and manual/device limits: [ROUTE_PROGRESS_VALIDATION.md](ROUTE_PROGRESS_VALIDATION.md).


## Outside-corner shortcut follow-up, 2026-09-16

G01/R03/R07/T02/V05: owner reports penalties while slightly wide at outer curves. Directional bypass evidence and an explicit outside-bend debt reset replace distance-only evidence. Rules v5, same-tick warning retained. See [actual reproduction, checks and remaining acceptance](OUTER_CURVE_SHORTCUTS.md).

## Go-kart local vehicle, 2026-09-16

Owner authorizes a fifth selectable vehicle with smaller wheel span, short turning radius, high grip and acceleration but low top speed. Dedicated kart-1 Resource, original model/art and existing selection/records/practice integration. Requirements G01/G03/V02-V05/R01/R03/R04/R06/R07. [Actual tests, captures and remaining acceptance](KART.md).


## Silmukka missed cuts, 2026-09-16

G01/R03/R07/T02/V05: rules v6 removes blanket outside forgiveness and skipped-corner credit; retained driven approach plus excursion savings identifies inside bypasses. [Fixture, actual checks, timing and outstanding owner/device acceptance](SILMUKKA_SHORTCUTS.md).

2026-09-16 owner handling follow-up: multiple flips driven by remaining lateral speed, preserving grounded presentation and upright recovery. See [MULTIPLE_ROLLOVERS.md](MULTIPLE_ROLLOVERS.md) for requirements, evidence and remaining acceptance.


## Silmukka screenshot hairpin, 2026-09-16

G01/R03/R07/T02/V05: v7 uses directional inside boundary and removes approach-diluted percentage gating. Narrow grass crossings, stop/resume and five repeated cuts tested. [Actual commands, outcomes and owner/device limits](SILMUKKA_HAIRPIN_BOUNDARY.md).

2026-09-16 G01/G03/R03/R07: owner requests stronger kart grass/dirt slowdown. kart-2 tuning and 59 passing checks; [actual commands, evidence and acceptance](KART.md#stronger-grassdirt-penalty-2026-09-16).

2026-09-16 V02/V03/V05: owner screenshot requests kart model alignment correction. Centered cockpit, joined nose stripe and corrected bevel; [actual checks and evidence](KART.md#model-alignment-correction-2026-09-16).

2026-09-16 G01/G03/R03/R07: owner requests faster kart dirt deceleration on partial contact. Versioned wheel probes and stronger drag; [302 checks and remaining acceptance](KART.md#wheel-contact-dirt-slowdown-2026-09-16).


## Tight hairpin island screenshot, 2026-09-16

G01/R03/R07/T02/V05: constructed-hairpin interior crossing detection bypasses the inappropriate 8 m gate for small islands. Rules v8. [Actual geometry tests, diagnostic corrections and remaining owner/device acceptance](TIGHT_HAIRPIN_CROSSINGS.md).

2026-09-17 G01/G03/R03/R07: owner requests shorter kart turning radius; kart-4 steering tuning, [73 passing checks and remaining acceptance](KART.md#shorter-turning-radius-2026-09-17).


2026-09-17 R01/T01-T04/V03/V05/R03/R07: Track start-line placement and direct direction control replace the Waypoints menu. Compiler 12; [673 passing checks, captures and remaining device acceptance](START_LINE_EDITOR.md).


2026-09-17 R01/T01-T04/V03/V05/Q01: object placement latency optimization with immediate props, bounded background compilation and exact cached/uncached equivalence. [Measurements, commands and phone limits](OBJECT_PLACEMENT_PERFORMANCE.md).

2026-09-17 R01/T01-T04/V03/V05: owner-supplied illustrated editor icons integrated. [Actual validation and remaining acceptance](EDITOR_ICONS.md).


2026-09-17 R01/T01-T04/V03/V05: endpoint-only size/rotation, direct width dots and inner curve angle dot; pure arcs, compiler 14. [Actual checks and device limits](ROAD_PLACEMENT.md#straight-and-curve-dot-controls-2026-09-17).


2026-09-17 R01/T01-T04/V03/V05: fixed 2 m S-curve ends and removal of their length control, compiler 15. [Actual checks and acceptance](ROAD_PLACEMENT.md#fixed-s-curve-ends-2026-09-17).


2026-09-17 R01/T01-T04/V03/V05: inner curvature dot for normal curves, circular default and preserved endpoints/tangents. Compiler 16. [Actual checks and acceptance](ROAD_PLACEMENT.md#adjustable-curve-curvature-2026-09-17).


2026-09-17 R01/T01-T04/V03/V05: consistent direct-dot controls for S-curves and hairpins. [Actual checks, captures and acceptance](ROAD_PLACEMENT.md#consistent-s-curve-and-hairpin-dots-2026-09-17).


2026-09-17 R01/T01-T04/V03/V05: distinguish handle actions through glyphs, shapes, spacing and active geometry feedback without labels. [Checks and remaining owner/device acceptance](ROAD_PLACEMENT.md#handle-affordances-without-labels-2026-09-17).


2026-09-17 R01/T01-T04/V03/V05: preserve the single attached endpoint while modifying free-end geometry. [609 checks, capture and remaining acceptance](ROAD_PLACEMENT.md#adjust-the-free-end-2026-09-17).

2026-09-17 R01/T01-T04/V03/V05/Q01: immediate road approval with background compilation, current-snapshot checks and gesture-idle scene application. [338 checks, before/after measurements, captures and phone limits](ROAD_APPROVAL_PERFORMANCE.md).

2026-09-18 V02/V03/V04/V05/R01/T01-T04: shared object models and biome-aware creator thumbnails refined; 243 checks pass, 35-variant and gameplay captures saved. See [actual changes, evidence and device limits](OBJECT_MODELS.md).


2026-09-18 V02/V03/V04/V05/R01/T01-T04: owner-directed original block/red-band barrier restoration and sharper inked trees, track-kit-29. 219 checks pass; captures and scoped patch in [OBJECT_MODELS](OBJECT_MODELS.md#owner-directed-barrier-and-tree-correction--2026-09-18). No phone test.

2026-09-18 V02/V03/V04/V05/R01/T01-T04: inked fractured rocks and standalone Cliff tile with 8/16/24 m presets; 226 checks pass, captures and scoped patch saved. [Changes and device limits](OBJECT_MODELS.md#rocks-and-larger-cliffs--2026-09-18).


2026-09-18 G01/V02/V04/V05: rolling tires on all five cars. [Implementation, evidence and acceptance](TIRE_ROTATION.md).


2026-09-18: owner reference-led discovery menu presentation; [requirements, actual commands, screenshots and pending phone acceptance](DISCOVERY_MENU.md).


2026-09-18 R01/G01/V03/V05/Q01: first Android debug APK installed on authorized DN2103 / Android 13. Focused deployment checks pass; full validation fails in existing app navigation integration checks. [Toolchain, fixes, actual commands and device acceptance](ANDROID_DEPLOYMENT_2026_09_18.md).


2026-09-18 R01/G01/T01-T04/V03/V05/Q01: copied PC tracks/drafts to DN2103; enlarged mobile artwork and independent invisible touch targets; mobile render scale and model/trail batching. Actual device median frames ~16.8 ms, occasional misses remain. [Commands, checks, measurements and limits](MOBILE_FOLLOWUP.md).

2026-09-18 R01/G01/V03/V05/Q01: measured Ajorata CPU optimisation deployed; [commands, regression outcomes, clean display trace and remaining human acceptance](AJORATA_PERFORMANCE.md).

2026-09-18 R01/G01/V03/V05/Q01: full-HUD touch redraw bottleneck reproduced and fixed on attached phone. [Measurements, commands, checks and remaining acceptance](RACING_INPUT_PERFORMANCE.md).


2026-09-21 R01/R03/V02/V03/V05/Q01: reference-led race results with completed-lap telemetry, interactive speed/time-diff/sector map, local next-race recommendations and navigation. Final graphical suite: 103 checks pass across 1280x720, 1920x1080 and 2400x1080. No phone test; older app navigation suite remains blocked before results. See [implementation, evidence and limits](RACE_RESULTS.md).

2026-09-22 V03/V05/Q01/RR02/RR05: sector annotation leaders terminate at label edges and labels avoid the compact “Off track” incident legend. Focused Results and three-size graphical capture suites pass; no phone test. See [RACE_RESULTS.md](RACE_RESULTS.md#sector-leader-clearance--2026-09-22).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-47 refines dry asphalt toward the owner reference with visible fine aggregate and restrained weathering. 384 focused checks pass; final desktop capture inspected. No phone test. See docs/ROAD_REALISM.md (Reference asphalt texture).


2026-09-21 V02/V04/V05/Q01/R01: track-kit-48 adds irregular asphalt grain density/weathering and subtle road-aligned detail on creator road pieces. 384 checks pass; final desktop capture inspected. No phone test. See ROAD_REALISM.md (Irregular road-aligned grain).


2026-09-21 V02/V04/V05/Q01/R01: track-kit-49 reduces cloudy asphalt weathering while retaining irregular, road-aligned grain. 50 surface checks pass; desktop capture retry succeeds and was inspected. No phone test. See ROAD_REALISM.md (Crisper asphalt follow-up).


2026-09-22 G01/V03/V05/R01/R03/R07/Q01: traffic-light start and separate 1.8-second finish coast with Results crossfade. Official time/state freeze at the line. Practice 40, graphical practice 44 and Results 116 checks pass; desktop evidence saved. No phone test/export. See docs/RACE_FLOW.md.


2026-09-22 G01/V03/V05/R01/R03/R07/Q01: five accumulating red race lights and simultaneous lights-out start replace road signals. Owner-supplied lamp artwork replaces procedural housings via one precomposited atlas draw, normalized to the supplied green housing geometry. The later owner-supplied race-complete panel replaces the waving flag with one texture draw and guarded tap-to-continue while retaining the automatic Results fallback. Evidence in docs/RACE_FLOW.md. No phone test/export.
