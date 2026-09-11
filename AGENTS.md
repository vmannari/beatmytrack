# Project agent instructions

## Current owner request and path mapping
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
