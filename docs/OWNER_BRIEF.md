You are the lead developer for this Android racing game.

The attached `Android_racing_game_blueprint_v2.zip` is the authoritative product
specification. Read the entire package before making architectural or gameplay
decisions, including:

- game specification
- architecture
- roadmap
- requirements/backlog
- UI/visual design documentation
- camera calibration
- gameplay visual references
- menu/UI visual references
- financial/monetization assumptions

Where the package conflicts with generic assumptions about racing games, the package wins.

IMPORTANT: Do not attempt to implement the complete product immediately.

Our first objective is to create a technically clean, genuinely fun vertical slice
that runs on both Windows and a real Android phone. The first and most important
unknown to resolve is whether the driving itself is good enough.

────────────────────────────────────────
1. DEVELOPMENT ENVIRONMENT
────────────────────────────────────────

Use:

- Godot 4 stable
- GDScript with static typing wherever practical
- Git
- Android export
- Android SDK / ADB for direct phone deployment
- Windows as the primary development machine

Keep external dependencies to an absolute minimum.

The game must initially work completely locally without a backend.

Do not introduce:
- Unity
- Unreal
- C#
- unnecessary third-party frameworks
- cloud infrastructure
- account systems
- analytics SDKs
- ad SDKs
- payment SDKs

unless the specification explicitly requires them for the current milestone.

Design interfaces so online functionality can be added later without rewriting
the game architecture.

────────────────────────────────────────
2. CORE PRODUCT PRINCIPLES
────────────────────────────────────────

This is a mobile racing game inspired in driving feel partly by Slicks 'n' Slide,
not a realistic racing simulator.

The important characteristics are:

- very active driving
- immediate steering response
- throttle management matters
- controllable oversteer
- braking matters
- catching slides should be possible and satisfying
- racing line matters
- small mistakes visibly affect lap time
- deep skill ceiling
- easy initial accessibility
- extremely fast restart
- no long periods where the player is merely holding acceleration

Typical lap duration:
10–30 seconds.

Typical race:
3–5 laps.

Track areas should remain relatively compact.

The game should strongly encourage:
"one more attempt".

Longer-term product pillars are:

1. Driving mastery
2. Car progression and tuning
3. User-created tracks
4. Sharing tracks/challenges with friends
5. Global time distributions
6. Neighbourhood competitors and ghosts
7. Recurring league competition
8. Continuous rewarding progression

There must NEVER be an energy/lives/fuel mechanism preventing the player from
continuing to race.

A free player must be able to progress through the game without paying.

Do not implement monetization yet.

────────────────────────────────────────
3. CAMERA — CRITICAL REQUIREMENT
────────────────────────────────────────

Do NOT create a conventional third-person chase camera.

The definitive gameplay-camera reference is the latest high, oblique,
near-top-down screenshot in the package.

Study:

`ui/references/gameplay_approved.png`

and:

`ui/assets/gameplay_camera_115.png`

The second image represents the requested framing adjustment.

The desired camera is:

- high above the car
- oblique perspective
- looking substantially downward
- no visible horizon
- follows the player's car
- only a portion of the track is visible
- enough look-ahead to drive quickly
- approximately the perspective of the reference
- car approximately 15% larger on screen than in the original approved screenshot

Do NOT enlarge only the car model.

Achieve the framing through camera distance/FOV/orthographic-size calibration so
the entire world maintains believable proportions.

Initially make camera parameters developer-adjustable:

- height
- pitch
- FOV or orthographic size
- forward look-ahead
- velocity-dependent look-ahead
- smoothing
- rotation behaviour

Start with a fixed world orientation if that best matches the reference.
Do not automatically rotate the world behind the car unless testing demonstrates
that this is superior.

The approved reference is more important than standard racing-game convention.

────────────────────────────────────────
4. VISUAL DIRECTION — CRITICAL REQUIREMENT
────────────────────────────────────────

The final game is NOT low-poly, toy-like, glossy mobile-game art.

Use the visual reference included in the package.

Target:

- mature graphic-novel cel-shaded 3D
- believable vehicle proportions
- controlled dark outlines
- matte surfaces
- restrained natural colours
- crisp stepped lighting/shadow regions
- carefully simplified materials
- strong silhouettes
- visually sophisticated rather than childish
- attractive to younger players without looking like a children's game
- premium/AAA-level art direction despite simplified rendering

Avoid:

- generic AI-game aesthetics
- excessive gradients
- glossy plastic surfaces
- toy proportions
- giant wheels
- cartoonishly saturated environments
- Fortnite-like visual language
- excessive bloom
- photorealism
- busy scenery
- random decorative props

For the vertical slice, build procedural/simple placeholder geometry where needed,
but establish the actual shader/rendering pipeline early enough that we can judge
whether this visual direction is feasible.

Performance on a normal Android phone matters more than expensive rendering effects.

────────────────────────────────────────
5. FIRST VERTICAL SLICE
────────────────────────────────────────

Build ONLY the following first.

A. One drivable car

Use simple original placeholder geometry if necessary.

The car needs:

- acceleration
- braking/reverse
- steering
- lateral grip
- longitudinal grip
- controllable slip
- weight/inertia approximation
- speed-dependent steering behaviour
- tunable oversteer
- collision response

Do not start with a complex physical tire simulation.

Create a compact arcade vehicle model whose parameters can be tuned very quickly.

All important parameters must live in a Resource/configuration structure rather
than being scattered through scripts.

At minimum expose:

- mass
- engine force
- braking force
- drag
- rolling resistance
- maximum speed
- steering rate
- high-speed steering reduction
- lateral grip
- front/rear grip balance
- slip threshold
- grip recovery
- rotational inertia
- countersteer assistance if used
- throttle influence on rotation
- collision energy loss

B. One test track

Create one compact circuit suitable for approximately:

15–20 second laps
3 laps per race

Include:

- fast corner
- braking corner
- hairpin
- direction change/chicane
- short straight
- corner where controlled oversteer is useful

The course exists to expose weaknesses in vehicle handling.

C. Timing

Implement:

- countdown
- start/finish line
- checkpoints preventing shortcuts
- current lap
- lap time
- previous lap
- best lap
- total race time
- personal best
- restart

Persist PB locally.

Timing should be deterministic and based on the physics/game clock, not UI time.

D. Controls

Implement keyboard controls for rapid desktop testing.

Implement mobile touch controls from the start.

Initially support:

- left
- right
- accelerator
- brake

Buttons must support simultaneous input.

Keep controls visually minimal.

E. Camera

Implement the approved high-oblique camera before polishing the track.

F. Android

The milestone is not complete until the game runs correctly on a physical Android phone.

Provide a simple documented command/script for:

- validating project
- producing debug APK
- installing through adb
- launching the game

────────────────────────────────────────
6. ENGINE ARCHITECTURE
────────────────────────────────────────

Create clean separation between:

Game
Vehicle
Input
Track
RaceSession
Timing
Camera
UI
Persistence

Do not put the whole prototype in one giant script.

Suggested conceptual structure:

game/
  core/
  vehicle/
  race/
  track/
  camera/
  input/
  ui/
  persistence/
  resources/
  tests/

Use resources/data definitions for things that will later become content:

- vehicle definitions
- vehicle handling
- upgrade definitions
- track metadata
- tuning ranges

Keep runtime systems independent from UI.

Do not couple race logic to one particular track.

Do not couple vehicle physics to one particular car.

────────────────────────────────────────
7. DESIGN FOR FUTURE FEATURES, DON'T BUILD THEM YET
────────────────────────────────────────

The architecture must anticipate these features:

USER TRACKS
Players will eventually create tracks and share them.

Tracks need:
- stable ID
- creator
- version
- geometry definition
- checkpoints
- start position
- lap count
- surface information
- environment/theme
- validation metadata

Editing a published track must create a new version rather than invalidating old
competitive results.

GHOSTS
A run should eventually be serializable as compact replay input/state data.

GLOBAL DISTRIBUTION
Results will eventually populate a histogram of valid race times.

NEIGHBOURHOOD
Players immediately above/below the user's result will be shown and their ghosts
can eventually be challenged.

LEAGUES
Weekly/seasonal competition will eventually use selected tracks and promotion/
relegation.

CAR PROGRESSION
Driving earns Vehicle XP and credits.

Parts/upgrades are earned through playing.

Performance progression must have a sensible ceiling so veteran players do not
make competition meaningless.

Later upgrades include:
- engine
- gearbox
- tires
- suspension
- brakes
- differential

Tuning should involve meaningful trade-offs rather than a single optimal
"everything to maximum" configuration.

MONETIZATION
Do not implement now.

Expected philosophy:
- playing is unrestricted
- paying is never necessary to progress
- no paid competitive advantage
- creator/public track capacity is a possible premium feature
- cosmetics/convenience are potential monetization areas

────────────────────────────────────────
8. FIRST IMPLEMENTATION PHASE
────────────────────────────────────────

Proceed in this exact order:

Phase 0 — inspect and plan
1. Read the full specification package.
2. Inspect all reference images.
3. Inspect the roadmap/architecture.
4. Summarize your understanding.
5. Identify contradictions or implementation risks.
6. Propose the exact repository/project structure.
7. Propose the minimum vertical-slice plan.

Do NOT begin large-scale coding until this is done.

Phase 1 — bootstrap
1. Initialize Godot project.
2. Configure project settings.
3. Establish folders/modules.
4. Add Git ignore/configuration.
5. Create basic developer README.
6. Verify command-line project startup.
7. Configure Android export path/documentation.

Phase 2 — physics playground
1. Flat test surface.
2. One car.
3. Desktop input.
4. Physics telemetry overlay.
5. Rapid tuning controls/config.
6. Establish satisfying steering/sliding before building systems around it.

Phase 3 — camera
Reproduce the reference camera carefully.

Create screenshot comparison against the target reference.

Phase 4 — test circuit
Build the compact 15–20 s circuit.

Phase 5 — complete race
Implement timing, laps, checkpoints, PB and instant restart.

Phase 6 — phone
Touch controls.
Build/install/launch on Android.
Test actual driving feel on-device.

Phase 7 — initial visual pipeline
Implement the cel-shading approach and representative environment/car materials.
Do not attempt full final artwork.

────────────────────────────────────────
9. DEVELOPMENT TOOLS
────────────────────────────────────────

Create useful development instrumentation.

During physics development I want an optional debug HUD containing:

- speed
- longitudinal velocity
- lateral velocity
- slip angle
- steering input
- throttle
- brake
- yaw rate
- current grip state
- FPS

Make it easy to toggle.

Provide a simple way to capture lap telemetry later.

Do not put debug information in release UI.

────────────────────────────────────────
10. QUALITY RULES
────────────────────────────────────────

Do not treat "it runs" as completion.

Code must be:

- understandable
- modular
- statically typed where reasonable
- documented where behaviour is non-obvious
- deterministic where competition requires it
- easy for another developer/agent to modify

Avoid premature generalization.

Avoid unnecessary design patterns.

Prefer a small well-designed implementation over a large framework.

Every milestone must remain runnable.

Commit meaningful checkpoints to Git.

Do not silently change product requirements.

If a product decision is unclear:
1. inspect the specification,
2. choose the least irreversible implementation,
3. document the assumption.

────────────────────────────────────────
11. WHAT SUCCESS LOOKS LIKE FOR THE FIRST MILESTONE
────────────────────────────────────────

The first milestone is successful when:

- I can launch the project on Windows.
- I can launch the same project on an Android phone.
- The car is immediately enjoyable to control.
- Sliding is controllable rather than random.
- throttle/braking/line choice materially change lap time.
- a lap takes about 10–30 seconds.
- I can complete a 3-lap race.
- restart is essentially immediate.
- lap and race timing works.
- PB persists locally.
- the camera clearly matches the approved high-oblique reference.
- the car occupies approximately the requested size on screen.
- the initial cel-shading pipeline resembles the approved art reference rather
  than generic mobile-game graphics.
- the architecture leaves clear paths toward ghosts, user tracks, progression,
  leagues and online results.

Most importantly:

DO NOT optimize progression, menus, monetization, networking or content before we
prove that repeatedly driving the same small circuit is genuinely enjoyable.

If the driving loop is not fun, stop and improve the driving instead of building
more systems.

────────────────────────────────────────
12. START NOW
────────────────────────────────────────

First:

1. inspect the attached blueprint package,
2. summarize the definitive requirements you extracted,
3. point out any contradictions or unclear requirements,
4. propose the repository structure,
5. propose the first 5–10 implementation tasks,
6. then begin Phase 1.

Keep a DEVELOPMENT_STATUS.md file updated with:

- completed
- currently working
- next
- unresolved decisions
- technical debt
- manual tests needed from me

When you need me to test something, give exact instructions and tell me what
subjective property I should evaluate.

The first subjective evaluation I care about is driving feel.