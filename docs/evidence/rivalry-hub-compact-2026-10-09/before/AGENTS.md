# Project agent instructions

## Rivalry track-entry override (2026-10-09)
The owner requests overview track rows/arrows to open the existing track detail, with races started from its Race action and Back to Rivalry returning to the overview. Remove redundant Tracks/Standings tabs, the single Overview tab and overview race starts; keep the podium, five immediately visible tracks and scrollable standings in the hub. Completed-week details remain inspectable with racing disabled. This supersedes the separate rivalry sections and direct overview races in earlier overrides. Preserve five-lap racing, ghost choice, normal results first, best-only verified scoring and internal development/public-population isolation. See `docs/RIVALRY_NAVIGATION.md` for actual files, commands, screenshots and remaining acceptance.

## Rivalry track result reference override (2026-10-08)
The owner requests competition-first rivalry feedback after the normal race summary: roughly 37% race details and 63% full track standings, eight visible scrollable rows, a yellow player row, signed time gaps, brighter original preview/actual route outline, personal PB improvement/previous time and actual lap/distance/weather/surface facts. Compact track rank/weekly points and overall movement replace the large expected-position display. Use a small provisional status and horizontal bottom-right Race Again/Back to Rivalry actions. Preserve normal PB/lap/histogram results first, best-only competitive scoring, actual five-lap races, internal development gates and public-population isolation. Reference example identities, times, three laps and sunset are not live values. See `docs/RIVALRY_TRACK_RESULTS.md` for files, commands, evidence and remaining acceptance.

## Unified histograms and restrained UI override (2026-10-08)
The owner requires one histogram view containing every available comparable real and artificial driver, with the player's time marked in that same view. Do not offer Player data/Test data views, source selectors, TEST badges, simulated-driver descriptions or sample-count captions in discovery or results. Deduplicate each driver across the compatible public/development boards; keep artificial identities out of public competitive rankings, ratings and eligibility, and retain development configuration/session gates internally.

Never add redundant player-facing UI text. Add a label only when it identifies a necessary action/value or communicates an actionable state that is not already clear from the layout, icon or another label. Do not surface implementation details, test/source classifications, diagnostic counts or repeated explanations in ordinary game screens. Keep such information in logs, documentation or explicitly requested diagnostic tools. Review new UI for redundant text before capturing evidence. This overrides earlier histogram source switches and visible test-data labeling requirements.

## Illustrated menu art override (2026-09-14)
The owner rejected the procedural menu graphics and supplied a detailed inked/cel-shaded vehicle reference. Home and Garage now use an original generated fictional compact-car illustration with retained editable UI. This supersedes procedural menu scenery; it does not replace the gameplay vehicle mesh or camera. The source reference is not a shipping asset. See `docs/ILLUSTRATED_MENUS.md` and the saved generation prompt for actual assets, evidence and remaining acceptance.

## Premium menu reference (2026-09-14)
The owner supplied a nine-screen menu board and requested a more premium feel. This authorizes the Home/Garage/Tracks/Results/Settings presentation pass, including warm yellow primary actions, deep navy panels, bottom navigation and original scenic menu environments. The new yellow action reference supersedes the older white-primary menu token. Reference commerce, currencies, progression and online standings remain outside the current local slice. Gameplay camera and canonical handling are independent. See `docs/PREMIUM_MENUS.md` for actual evidence and remaining visual/device acceptance.

## Wireframe editor override (2026-09-13)
The owner supplied a phone-editor wireframe directing a full-screen world, Road/Surface/Objects/Race rail, contextual bottom palette, directly placed road sections, local geometry handles, roadside object runs and actionable issues. Creator-track-v4 adds independent road pieces alongside free paint and the separate lap route; older user formats need not be maintained. The wireframe's **Practice (untimed)** and **Edit here** supersede five-lap creator test drives only. Ordinary races remain five laps. Practice-start placement is independent of the timed lap start. See `docs/WIREFRAME_EDITOR.md` for implemented behavior and acceptance limits.

## Free-form editor override (2026-09-12)
The owner rejected spline-only editing and explicitly prioritized free-shaped roads, terrain, intersections and obstacles. The map and lap route are separate in creator-track-v3; at-grade route crossings are permitted. This supersedes v2-only and no-crossing authoring rules below. No user-track backward compatibility is required. Existing bridge geometry may be retained in native remixes; new bridge tooling is outside this ground-editing slice.

## Current owner request and path mapping
- On 2026-09-12 the owner requested conversion of all locally supplied Slicks tracks, with artificial names for missing authors to exercise author search. This authorizes the 194-track native test corpus; see `docs/SLICKS_CORPUS.md` for provenance, conversion assumptions and validation limits.
- On 2026-09-12 the owner requested **five laps** and a visually stronger track library with favorites, name/creator search and random selection. Five laps supersede the earlier three-lap production rule. Historical replay/handling fixtures may explicitly run three laps to preserve their diagnostic corpus; all ordinary races and creator test drives use five.
- On 2026-09-12 the owner accepted handling and collisions and explicitly authorized the next local slice: proper menus, three more Slicks circuits, a phone-friendly map creator and shared track themes. This overrides the earlier editor/content restriction for this slice. Phone handling, camera calibration and performance acceptance remain outstanding; online services, progression and commerce remain deferred.
- The owner request dated 2026-09-11 explicitly selects **three laps** for this first slice, overriding the package's original four-lap brief. The supplied package itself remains unchanged.
- The later 2026-09-11 Slicks handoff request explicitly authorizes four native handling-test fixtures (FREEWAY, 1WAY, 66, OFFROAD) within the handling gate. This overrides the one-circuit quantity for these fixtures only; see `SLICKS_IMPORT.md` for tested scope and inferred semantics.
- Implement the owner's Phase 0–7 sequence inside the blueprint's P0/P0-V scope. Complete inspection and bootstrap before the physics playground. Handling approval precedes feature/content expansion.
- Specification paths below (`ui/`, `technical/`, etc.) are relative to `Android_racing_game_blueprint_v2/`. Runtime code lives in `game/`; the blueprint is outside the export root.
- Read `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md` before continuing. Keep actual commands, outcomes, limitations and manual tests current.
- Use the exact build in `godot-version.txt` and matching templates. `scripts/dev.ps1` is the build/run entry point. Do not use the older Godot PATH alias on this machine.

## Product invariants
- Android high-overhead 2.5D active racer; typical LAP is 10–30 seconds, 3–5 laps per race.
- Unlimited legitimate racing with ongoing base rewards. No energy, tickets, paid retries, waiting gates or daily exhaustion of earned base progression.
- All performance cars/parts/tuning are obtainable by driving. No sales of power, credits, XP or competitive boosts.
- Player-created tracks are shareable; recipients race free. Local drafts/export are not a paywall.
- Global comparisons use one verified PB per player per pinned rules key. Neighbourhood means adjacent performance, not location.
- League points reward best performance, not raw attempts. Never silently modify these invariants.

## Latest physical-size override
- On 2026-09-12 the owner requested a slightly smaller car and quicker turning on the practice tracks. Handling-0.8 uses 88% physical body scale with matching collision, wheelbase and trails. This overrides car-size preservation for this handling adjustment only; the camera calibration contract and source package remain unchanged.

## Visual invariants / revision 2
- Read `ui/UI_Art_Direction.md`, `ui/Camera_contract.json` and `technical/Rendering_and_camera.md` before any camera or art task.
- Gameplay is high-oblique overhead with no horizon or rear chase view. The car/world framing is 1.15x the selected screenshot; never enlarge just the mesh or change track dimensions.
- Menu reference is for menus only. Ignore its top-row chase cameras when implementing racing.
- Mature cel-shaded 3D, restrained natural colours and believable car proportions. No glossy/toy-like substitute.
- Reference images and generated posters are not licensed production assets. Keep fictional/cleared vehicle identities and provenance.

## Delivery scope
Implement the active roadmap gate only. P0 is one car, one circuit, three laps (current owner override), active controls, phone build, timing and a replay spike. Do not build the store/backend/editor while handling is unapproved. Treat numerical balance values, quotas, prices and UI layouts as proposed until accepted.

## Engineering rules
Use typed GDScript with explicit domain boundaries; pin engine and export templates. No network, wall clock, file I/O, iteration-order randomness or display-rate dependency inside the canonical simulation step. Quantize inputs; version physics/rules/content. Keep Android/platform SDKs behind adapters. Do not trust client currency, times or entitlements. All reward and purchase writes must be idempotent. Use atomic saves, migrations and persistent outbox retries.

Do not hardcode real credentials, release-signing secrets or player data. Do not add runtime AI/API calls, analytics vendors or external dependencies without approval. Maintain asset/license provenance. No user-supplied scripts/images/chat in initial UGC. No production deployment or purchases without explicit owner authorization.

## Task completion
Each task must identify requirement IDs, changed files, actual commands run, actual test outcomes, known limitations and remaining acceptance checks. Include screenshots/video for visible UI changes. State explicitly when no phone is attached or a device test was not performed. Never report planned tests as passed. Do not remove or weaken a failing invariant to make a test green. Ask for a decision when two approved requirements conflict.

One vertical slice and one reviewable Git checkpoint at a time. Update schemas, golden fixtures and docs when contracts change. Run quick tests before export and full replay/regression tests before merging a physics change. No unrequested scope expansion.
## Creator follow-up override (2026-09-12)

The owner accepted handling and authorized menus/editor/content. Sharp turns, per-node widths and built-in objects supersede initial creator minimum bend-radius and shoulder-clearance proposals. The owner explicitly waives backward compatibility for user-created tracks: support creator-track-v2 without deleting existing files.

## Creator construction override (2026-09-13)
The owner explicitly requested inside-area whole-piece dragging, endpoint-dot editing, desktop alternatives to touch gestures, and bridge authoring for overpasses. This authorizes new bridge tooling and supersedes the earlier exclusion. Current creator documents use creator-track-v5; backward compatibility is not required and existing files must not be deleted.

## Creator scenery and hazards override (2026-09-14)
The owner explicitly requested tapered kerbs, solid/deletable trees, visually consistent bridges, scalable rock/cliff variants and gameplay-affecting jumps, oil and water. This authorizes the local creator-object and deterministic hazard slice; online services and unrelated progression remain deferred. See docs/CREATOR_HAZARDS.md for bounds and acceptance.

## Multi-car override (2026-09-15)
The owner explicitly authorized a pickup, rear-heavy classic sports car and classic Formula car alongside the compact, including menus, pictures, gameplay models and track-dependent handling balance. Fictional vehicle identities and the established illustrated/cel-shaded style remain required. This supersedes the one-car quantity for the local slice. See docs/CARS.md for implementation, evidence and remaining human/device acceptance.

## Go-kart override (2026-09-16)
The owner authorizes a fifth local vehicle: a go-kart with narrower wheel span, shorter turning radius, very good grip, strong acceleration and relatively low top speed. It uses the established illustrated/cel-shaded style and existing local selection/records flow. See docs/KART.md for actual behaviour, tests and remaining acceptance.

## Automatic waypoint and legacy collection override (2026-09-17)
The owner removed manual waypoint authoring: expose only automatic route generation from connected road pieces. Untimed practice-start positioning remains independent. The owner also retired the Slicks collection from the playable/shipping catalog and creator bases, superseding the earlier 194-track content requirement. Original local creator tracks remain supported; do not delete player files. Legacy native data is retained only under export-excluded test fixtures for existing physics regressions. See docs/AUTOMATIC_WAYPOINTS.md.


## Direct start-line override (2026-09-17)
The owner removed the whole Waypoints menu and moved Start line under Track, with direction adjustment on the placed object. Generate the route automatically from connected roads; the placed start line controls timed start/finish, route direction and practice spawn. This supersedes the independent practice-start UI; old practice_start data remains a fallback only. See docs/START_LINE_EDITOR.md.


## Discovery menu reference override (2026-09-18)
The owner supplied a track-discovery menu reference. Top navigation, original workshop backdrop, scenic route cards and yellow actions supersede bottom navigation for the local menus. Online friend rematches, ratings, currencies and progression remain deferred. See docs/DISCOVERY_MENU.md for actual checks and limitations.


## Mobile optimization and checkpoint override (2026-09-22)
The owner authorizes removing random road cracks, baking surface detail and reducing shadow quality for mobile performance. Timed laps require all road gates in order; missing a section requires returning, with no automatic +5s shortcut penalty. Gates must prevent hairpin shortcuts without excessive/intersecting dense gates impeding legitimate inside lines. Rules v10 replaces the old penalty contract. See docs/MOBILE_OPTIMIZATION_2026_09_22.md for implementation, physical-device measurements and remaining acceptance.

## Desert sand and sunset override (2026-09-22)
The owner requests desert roads to always be a distinct, more drivable compacted sand, with dense dust during ordinary driving that causes considerable obstruction and lingers. This explicitly supersedes the earlier brief/unobstructive dust art constraint for desert. Desert lighting uses a red-orange sunset and longer shadows. See docs/DESERT_SUNSET.md for implementation and acceptance limits.

## Desert daylight and road override (2026-09-24)
The owner accepted dune ground and requests reference-informed compacted desert roads and suitable kerbs. Normal daylight supersedes the red-orange sunset until a later lighting pass. Dust and canonical packed-sand driving remain unchanged. See docs/DESERT_DAYLIGHT.md.

## Desert berm reference override (2026-09-24)
The owner supplied a sand-berm reference, superseding striped/stone desert kerb presentation. Use irregular low sand banks at bends, compacted shoulders and soft straight transitions. See docs/DESERT_BERMS.md.

## Desert apron approach override (2026-09-24)
The owner rejected continuous raised berm ribbons and requested a different approach closer to the supplied reference. Kit 65 uses a flat textured sandy apron with independent clustered opaque sand clods. The approved directional road texture is retained. See docs/DESERT_APRON.md.

## Backend first-version override (2026-09-28)
The owner authorizes the first backend for authentication, immutable track sharing, ratings and verified leaderboards, targeting the DS925+ first and cloud hosting later. Google sign-in is the selected first provider. The owner explicitly requests development authentication without Google validation; keep that bypass explicitly configured for development and separate from real Google identities. This supersedes the earlier online-service deferral for this slice. The supplied future requirements inventory does not authorize economy, commerce, social or real-time multiplayer implementation. See docs/BACKEND_V1.md and backend/deploy/README.md for architecture, actual verification and outstanding client/NAS acceptance. Production deployment still requires owner authorization.

## Account-menu override (2026-09-28)
The owner requests Google and Development sign-in choices. Development uses the fixed `developer` account and is temporary; Google uses the player's selected username. This authorizes account-menu/backend integration and browser-based Google sign-in. Keep development identities separate, never ship their key, and make disabling development authentication reject existing development sessions as well as hide the option. See docs/ACCOUNT_SIGN_IN.md for setup, migration, actual tests, screenshots and remaining real-Google/device acceptance.


## Bridge junction and creator performance override (2026-09-29)
The owner requests overlapping bridges with drivable intersections and creator performance improvements, especially undo. Same-height creator spans may overlap as one elevated road area; this supersedes the earlier nonoverlapping-span restriction. Unequal ramp heights and legacy native-deck merges remain unsupported. See docs/BRIDGE_JUNCTIONS_AND_EDITOR_PERFORMANCE.md for behavior, desktop timing evidence, tests and remaining device acceptance.

## Rewind and resume override (2026-09-29)
The owner authorizes selecting a resume point within the last 10 seconds, with at most three confirmed resumes per race. One free resume per UTC day expires that day without rollover. Each completed rewarded ad grants one resume, with no daily ad limit; purchased and otherwise awarded resumes never expire. Rewind-assisted races remain eligible for verified leaderboards, explicitly overriding the earlier paid-retry/competitive-boost restriction for resumes only. Ordinary racing/restarting remains unlimited and free. Credits must be server-authoritative for authenticated players; rewards and purchases require verified, idempotent fulfillment. Ad provider and store products require configuration; never substitute simulated ads or purchases in shipping UI. See docs/REWIND.md for implementation and acceptance.

## Compact rewind override (2026-09-29)
The owner reduces rewind to ten seconds, opens at the current position, and requests recorded ghosts before and after the selection without extrapolation. A single compact toolbar contains Cancel, the scrubber and a play-shaped Resume action; remove the separate Live button, playback controls and right-side cards. Existing return easing, credit rules and leaderboard eligibility remain. See docs/REWIND.md.

## Resume resource toolbar and temporary ad override (2026-09-29)
The owner supplies a toolbar with race-resume indicators and a resource button. Banked resumes are consumed first and their count is shown on the ticket button. With no banked resumes, show an ad icon; retain the daily free allowance separately, then allow an immediate free resume until ad integration exists. This explicitly supersedes the earlier unavailable-ad restriction for this temporary path only. Do not claim an ad was watched or mint banked rewards; server receipts identify the temporary source. Ten-second rewind, three resumes per race and leaderboard eligibility remain. See docs/REWIND.md.


## Race discovery reference override (2026-10-01)
The owner renames Play to Race and requests the supplied discovery composition, a bottom track carousel with mobile swiping, Search beside Filters, and an icon-only right rail whose non-Free-race modes may remain placeholders. This supersedes paged track browsing for this screen. See docs/RACE_DISCOVERY.md for implementation, actual evidence and remaining device/visual acceptance.


## Race discovery correction (2026-10-01)
The owner corrects the mode rail to the left, requires stable section dimensions during track changes, removes the duplicate hero Race and sidebar Random actions, requests equal spacious Random/Filters/Search buttons, and replaces carousel arrows with smooth scrolling that settles on full cards. This supersedes the right-rail portion of the preceding override. See docs/RACE_DISCOVERY.md.


## Race filter drawer override (2026-10-01)
The owner requests a reference-led right-side filter drawer over the Race menu, retaining the left mode rail and stable layout. Reuse existing icons, especially biome glyphs. Minimum rating uses a slider in 0.1 increments instead of the reference's rating buttons. See docs/RACE_DISCOVERY.md for implementation, actual checks and missing race-count data/device acceptance.

## Camera options override (2026-10-03)

The owner authorizes two optional driving-camera experiments: delayed car-heading rotation with a slightly lower overhead angle, and fixed-world rotation with more road shown in the travel direction. The rotating option supersedes stable-world yaw and preserved pitch for that selected mode only. Keep the original Overhead option/default, scene magnification, no horizon, HUD scale and canonical driving contracts. See docs/CAMERA_OPTIONS.md for parameters, controls, actual checks and remaining owner/device acceptance.

## Speed-dependent camera override (2026-10-03)

The owner additionally requests a slight camera pullback at higher speeds. This authorizes smoothly bounded whole-scene speed zoom with any driving view, superseding constant live magnification when Speed zoom is enabled. Keep the 1.15x baseline at low speed and with Speed zoom off, unchanged HUD/mesh/collision scale, no horizon and canonical simulation separation. See docs/CAMERA_OPTIONS.md for parameters, actual evidence and remaining owner/device acceptance.

## Weekly Rivalry override (2026-10-04)

The owner authorizes Weekly Rivalry inside Race, selected from the left trophy rail, with Overview/Tracks/Standings, rival-focused detail, verified race feedback and an Overview finale state. Five randomly chosen tracks, roughly 10–20 actual similar-skill drivers and Monday–Sunday UTC weeks are confirmed defaults. This supersedes the rivalry placeholder and authorizes the associated backend membership, matching, weekly verified PB scoring and ghost APIs. Community tracks require rating >4.0 and >100 distinct verified finishers; trusted official Beat my track authorship is an alternative. Preserve shared menu art/style and the canonical racer. Division/progression balance remains provisional; do not invent entrants, scores or rewards. Production deployment still requires authorization. See docs/WEEKLY_RIVALRY.md for actual tests, evidence and acceptance limits.

## Weekly Rivalry results correction (2026-10-04)

The owner requires normal race results first, including personal-best feedback and lap analysis. Continue opens weekly rivalry position/points feedback. Backend verification must never interrupt the normal summary. See docs/WEEKLY_RIVALRY.md.

## AdMob development override (2026-10-04)

The owner selects AdMob and requests Settings → Development → Show ads. Off retains the temporary free resume; On uses real Google rewarded demo ads after banked and daily allowances. Debug completion gates existing `ad_preview` receipts only, never unverified banked grants. Native SDK/code and the development menu are excluded from release behavior. The owner explicitly approved the existing Windows-trusted Avast public CA for local debug emulator testing, restricted to Google ad/resource domains, with generated CA/configuration outside Git and release builds. Production placements, consent and signed idempotent SSV fulfillment remain unconfigured. See docs/ADMOB_DEVELOPMENT.md.


## Artificial test drivers override (2026-10-04)

The owner explicitly authorizes artificial development drivers for Weekly Rivalry. Persistent traits, canonical recorded input generation, verified submissions, focused 14-driver fixtures and larger 150-driver matching populations supersede the no-invented-entrant restriction for explicitly labeled test championships only. Keep the feature configured for development, isolate test boards/membership contracts, exclude artificial identities from public rankings, ratings and community eligibility, and reject their existing sessions when disabled. Normal rivalries still contain real entrants only. See docs/TEST_DRIVERS.md for tools, actual tests, evidence and remaining acceptance.

## Automatic rivalry drivers and race hub override (2026-10-07)

The owner requests test drivers without a separate enable step, running canonical races against the backend and returning verified results to the app. Development clients automatically enter the configured test population; the idle backend worker manages persistent test fields and their ordinary ticket/upload/verification flow. Keep test labels, development gates and public-population isolation. Overview must expose all five tracks immediately with direct race choices, using the supplied results screen as presentation guidance. This supersedes the manual Test Rivals selector and single-opportunity Overview. Normal results remain first. See docs/RIVALRY_HUB.md for actual commands, staging evidence and remaining acceptance.

## Weekly Rivalry reference presentation override (2026-10-07)

The owner supplies the corrected podium/standings reference and explicitly removes visible TEST badges, the TEST RIVALRY/debug footer and browsing lap-count labels. This supersedes earlier visible test-label requirements for this presentation; retain development-only configuration, raw server identity markers and public-population isolation. Pair Week/time beneath the title, float the tabs, emphasize the taller gold winner with fictional car art, show the player in the clean four-column standings and align the five-track panel/action. Actual rank/points/time/biome values remain data-driven; do not insert the reference examples into live scores. Actual races still use five laps. See docs/RIVALRY_REFERENCE.md for files, generated-asset provenance, commands, screenshots and remaining device/visual acceptance.

## Stronger configurable speed zoom override (2026-10-08)

The owner requests a stronger speed-dependent pullback and configurable effect strength. This supersedes the former 12% enabled-zoom bound: the local default is 30% extra linear world coverage, selectable from 0–50% in Camera Settings and the race pause menu. Keep the 1.15x low-speed/disabled baseline, whole-scene scaling, overhead/no-horizon view, HUD/physical scale and canonical simulation separation. See docs/CAMERA_OPTIONS.md for actual tests, screenshots and remaining owner/device acceptance.

## Race challenges override (2026-10-08)

The owner accepted the challenge plan and authorized Beat my time and Group challenges within the Race target rail, including creation from the menu/results, racing first to set a verified target, code/link invitations, ghosts, best-only standings, normal results first and explicit rematches. Defaults are five pinned laps, the same car/setup/rules/track version, 24-hour/3-day/7-day durations (seven default), two-person duels and groups up to twenty actual drivers. Guests may preview/try; authenticated canonical races determine competitive results. Artificial identities remain excluded, development authentication gates remain internal, and no test/source classifications or redundant text belong in game screens. Native sharing and optional link/preview infrastructure are authorized; production deployment still requires authorization. Push/friend directories, automatic rematches, lifetime statistics and share media are later work. See docs/CHALLENGES.md for contracts, files, commands, evidence and remaining deployment/device acceptance.

## Admin support and data population override (2026-10-08)

The owner authorizes the player support workspace, audited development purchase/access controls and date/missing-value corrections. Keep artificial drivers included as ordinary players in administrative data for now; do not add population/source filters or classifications to this slice. Internal development authentication, simulation gates and public competitive/rating/eligibility isolation remain. Broader analytics and new telemetry follow separately. See docs/BACKEND_UI.md.

## Post-race challenge correction (2026-10-09)

The owner requires Create challenge after a race to use that exact completed result, including a slower-than-PB finish, with its track and car fixed. Pending verification or service failure must never substitute a personal best or ask the player to drive again. Use a compact custom menu-styled sheet with challenge type/duration, actual finish and original route preview; track/search/car selection remains for general menu creation only. The owner explicitly removes the unrequested Compare tab from race results: retain Track/Sectors/Speed and the original separate histogram page. See docs/CHALLENGES.md for exact-ticket contract, development rollout, evidence and remaining acceptance.

## Vertical Race modes and populated Rivalry entry (2026-10-09)

The owner requests a vertical carousel effect when changing Race mode pages and removes the empty Rivalry flash on first load. Follow the left rail's Weekly Rivalry/Free Race/Challenges order; keep the rail/top navigation stationary and primary menu/track carousel gestures horizontal. Preload authenticated membership and retain the current page until initial rivalry data or an actionable failure is ready; never fabricate entries or show an empty rivalry before the first response. Preserve five laps, normal results first, best-only scores, development gates and public isolation. See docs/RACE_MODE_CAROUSEL.md for implementation, actual checks, screenshots and device/latency acceptance.
