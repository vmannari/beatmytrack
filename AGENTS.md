# Project agent instructions

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
