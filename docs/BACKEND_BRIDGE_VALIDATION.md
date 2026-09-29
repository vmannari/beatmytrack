# Backend bridge validation follow-up - 2026-09-29

Requirements R01, T01-T04, B02/B19, Q01. Owner reported upload rejecting overlapping bridges after the editor junction fix.

## Cause and fix

The running local PC API image still contained creator-compiler-19 and its blanket bridge-overlap rejection. The editor already used creator-compiler-20. BackendStart reused the existing image: Python was bind-mounted, but canonical Godot code was baked into the container.

The PC Compose API now defines the pinned backend image build. The launcher builds and validates that shared image before replacing API, replay worker and migration containers. Build failure prevents replacement. Docker caching still reuses unchanged layers. Both local services were rebuilt/restarted; existing data volumes and account configuration were retained. Production/NAS deployment was not changed.

Changed files: backend/deploy/compose.pc.yaml, pc_development.py and README.md; backend/tests/test_pc_development.py, test_verifier.py and fixtures/bridge_junction.json; game/tests/test_construction.gd; this report and development status/phase plan.

## Actual checks

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BackendStart`: passed. Pinned Linux Godot checksum/version/import checks and exact 12,757-tick, five-lap golden replay passed before services were replaced. API/worker healthy.
- Same entry point, `-Action TestConstruction`: 102 checks, zero failures; five-lap bridge race, zero contacts, 24,570 ticks and exact replay. Two existing ObjectDB exit warnings remain. Writes the closed bridge-junction fixture with automatic route and placed start line.
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py backend/tests/test_pc_development.py -q`: 37 passed; existing Starlette/httpx deprecation warning. Covers real server validation of overlapping decks, startup ordering and build-failure preservation.
- Read-only `docker compose ... exec -T api/worker python -c ...` invoked GodotVerifier.validate_track on the new bridge-junction fixture in each running container. Both accepted it as creator-compiler-20, five laps, content hash `765879b4bc6e9358def9756997816406d2c481770998649fea6dd4c2ef2e3ebe`.
- HTTP `http://127.0.0.1:18181/readyz`: 200. No test track was published to the user library.

The initial backend fixture lacked a start line and failed the publication prerequisite. The construction test now generates a complete publishable fixture; the final tests above passed. An intermediate fixture assignment error was corrected before the successful construction run.

## Acceptance limits

Same-height deck junctions are allowed; mismatched ramp heights remain invalid. The user's actual track upload still needs retrying. No phone is attached; no device test or Android export was performed. This follow-up changes backend startup/testing only, with no new visible UI to capture. Desktop bridge visuals and editor performance evidence remain in BRIDGE_JUNCTIONS_AND_EDITOR_PERFORMANCE.md and ROAD_APPROVAL_SLICES.md.
