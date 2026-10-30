# Forklift Agile becomes the standard — 2026-10-30

The owner selected Agile for the Forklift. The standard forklift-5 resource uses the exact five Agile overrides from the task-start forklift-4 experiment: steering rate 8, countersteering rate 15, high-speed steering reduction 0.20, lateral grip 50 and lateral response 18. All other handling values remain unchanged. The Forklift no longer offers the experimental race dropdown; the remaining cars' choices are retained. A new handling version and config hash separate its records and online contract from forklift-4.

The local offline verifier fixture's forklift identity is now `forklift-5` / `35f199342d5fdc07471bb00bc4a39ae5c024fc08031fa5836610db5256e09d50`. The live backend was not changed: matching authorised backend and verifier rollout is required before the new tune can be verified online.

## Verification

Using pinned Godot 4.7.2 `ed1daf0bf` and isolated APPDATA/LOCALAPPDATA, offline:

- `--headless --path game --script res://tests/test_forklift_agile_locked.gd`: 8/0. A frozen task-start resource and retained earlier preset table reconstruct Agile. Every handling field except version matches; 1,200 mixed-input ticks from each of three initial speeds match exactly.
- `--headless --path game --script res://tests/test_handling_test_selector.gd`: 31/0; `res://tests/test_handling_test_integration.gd`: 20/0. Forklift has no selector and cannot directly select an experiment; other available choices remain.
- `--path game --rendering-method gl_compatibility --script res://tests/capture_forklift_lock.gd`: 4/0 at 960×540 and 1280×720 for actual Forklift and Pickup game views. [Forklift](evidence/forklift-agile-lock-2026-10-30/forklift-960x540.png) and [Pickup](evidence/forklift-agile-lock-2026-10-30/pickup-960x540.png) show the selector's intended absence and retention. The isolated capture logged cold race hitches, up to 20.3 seconds; it is not a performance measurement.
- A temporary copy of the unchanged historical high-speed test, with its output redirected, returned 112 checks / 18 failures against Agile: its two old identity/single-field assumptions and 16 former radius bands no longer describe the selected tune. A frozen forklift-4 control passes 112/0. All remaining historical recovery, speed, slip, replay and straight-line assertions pass for Agile; no historical assertion was relaxed.
- The historical Forklift suite, with evidence redirected, returned 93 checks / one failure for its forklift-4 version expectation, then encountered a nil thumbnail-size fixture error before its remaining App assertions. The focused actual-Game selector test above ran separately.
- In `backend`, `.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_forklift_agile_contract.py -q -k sqlite --tb=short` (with the executable path prefixed by `..`): one passed, one PostgreSQL case deselected. The test covers ticket issuance, worker fencing and separate board identities for the old and new forklift while preserving Compact's board identity. The existing forklift compatibility selection had three SQLite passes and three PostgreSQL setup errors because its configured local test service was unavailable; it does not specifically establish the new split.

The isolated Windows runs reported a root certificate-store warning; the focused test also reported objects/resources in use at exit. Device testing and reload/owner acceptance remain; no device test, APK, live/backend mutation or deployment was performed.
