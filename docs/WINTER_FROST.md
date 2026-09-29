# Winter screen frost

2026-09-25; requirements V02/V04/V05/Q01. Owner requested screen-edge frost matching their winter gameplay reference.

Original transparent branching ice artwork surrounds the viewport at 72% opacity. A static TextureRect on weather layer 0 sits beneath the HUD, ignores input and resizes with the viewport. Winter races and practice use it; switching to other biomes removes it through the existing weather lifecycle. No per-frame script, simulation, handling or camera changes. One full-screen transparent texture draw; GPU cost has not been measured on phone. Aspect-ratio scaling stretches the artwork with the viewport.

Changed files: `game/core/game.gd` (weather lifecycle only), `game/camera/winter_frost.gd` and UID, `game/assets/textures/winter_frost_v1.png` and import, `game/tests/capture_winter.gd`, status/plan, this report, prompt provenance and `docs/evidence/winter-frost/`. Concurrent contact-lighting and phone-profiling changes are outside this work.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import` passed with existing Android build-tools fallback notice; `-Action CaptureWinter` initially passed 156 checks, final run passed 167 checks with zero failures. Added checks cover transparent center, HUD ordering, input pass-through and winter/pine/desert/storm switching. `git diff --check` passed with line-ending notices. A Python alpha inspection could not run because Pillow was absent; System.Drawing inspection succeeded (center alpha 0, corner alpha 252).

Desktop evidence: [1280 x 720 driving](evidence/winter-frost/driving.png), [960 x 540 compact](evidence/winter-frost/compact.png), [bend detail](evidence/winter-frost/bend-detail.png). Driving and compact screenshots visually inspected; controls and center remain readable. Historical evidence overwritten by the capture fixture was restored.

No Android export, installation or physical-device test performed. Phone connection was not verified. Owner visual acceptance, moving gameplay, ultrawide layouts and phone GPU/thermal performance remain. Asset generated with built-in imagegen; exact prompt and provenance: [WINTER_FROST_PROMPT.md](WINTER_FROST_PROMPT.md).
