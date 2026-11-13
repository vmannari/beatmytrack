# Biome shader preparation and miss telemetry — 2026-11-06

BSP01–BSP04/Q01 implement biome-specific native preparation profiles, conservative fallback and scoped telemetry. In the final fresh-private-profile desktop Pine pair, actual race preparation fell from **35.872 to 8.633 seconds** (27.238 seconds / 75.9%). Native source compilations fell from **185 to 61**, and their combined compilation/link/uniform-setup time fell from **30.805 to 3.877 seconds**. Both runs completed the actual opening lap with zero contacts and zero late compilation. Their ready images are pixel-exact.

This is one controlled desktop Compatibility pair on an RTX 3090/NVIDIA 616.92, using the isolated custom engine, Compact/default graphics and the verified oval fixture. Timing starts at the actual-App race start after track compilation and ends when preparation completes; it excludes startup and live-service latency. It is not a fresh-driver measurement, a five-biome timing median, a phone result or an improvement already present in the installed stock engine.

## Implementation

- **BSP01 — Engine selection:** the pinned Godot 4.7.2 source module replaces eager default compilation only for exact known shader sources in the selected profile. Known sources can prepare their recorded specializations when shader code is installed, under the loading cover. Missing variants still compile through the original bind path. Unknown sources retain normal preparation. No GLSL, meshes, shader uniforms, effects, checkpoint rules or canonical physics are simplified.
- **BSP02 — Race scope:** `game/rendering/biome_shader_profile.gd` owns one native scope per Game. Profiles distinguish biome, car, detail, graphics settings, renderer, adapter/driver and engine source fingerprint. JSON numeric normalization preserves identities after disk reads. Cancellation, teardown and track cycling release the scope; stale tokens cannot replace or close another owner. Final reports close the scope atomically. Pause closes observation before pause-menu draws; resume opens a new scope using the race's applied graphics and car detail, not staged preferences. Unsupported engines/renderers and headless runs use normal preparation.
- **BSP03 — Observation:** all four GLES3 draw APIs record first use, including instanced, shadow, particle and offscreen draws. Empty draws and uniform-only binds do not establish coverage. The engine knows exact source/variant/specialization identities even for binary-cache imports and built-in shaders. Program IDs are transient and reused IDs cannot inherit coverage. Per-scope observations cap at 4,096 and the transient registry at 16,384; dropped observations remain explicit. No GPU objects are retained by the observer.
- **BSP04 — Telemetry:** an opt-in, account-scoped `shader_profile` event reports biome, car/settings, renderer, context identity, coverage/miss/drop counts, total late compilation cost and up to 16 variant details. Details prioritize late misses. Unlisted variants and listed variants that still compiled late are distinguished. Recreated programs cannot hide a later miss behind an earlier successful use of the same key. Captures enqueue without starting disk/network work; capability rollback also prevents transmission of previously queued unsupported events. Raw shader text and driver strings are excluded from event properties.

The negotiated backend capability is `product_telemetry.shader_profile_schema_version = 1`, controlled by the existing client-quality flag and analytics consent. `/v1/admin/shader-profiles` exposes authenticated, bounded recent receipts with biome/context filtering and explicit coverage limits. Migration `0074_shader_profile_receipts` adds only a partial reporting index. Existing account erasure and raw-receipt retention apply. No backend rollout or migration execution against a real service occurred.

## Reviewed profile inventory

The bundled manifest contains **nine exact desktop contexts / 604 entries / 119,238 bytes**: all five current cars in Pine, plus Compact in Desert, Night City, Winter and Storm. Common shaders remain shared by Godot; the profiles do not clone them. New cars, graphics settings, driver contexts, changed shader sources and other unrecorded combinations retain the fallback. Telemetry identifies gaps; it does not automatically promote new profile data.

The native module is source-integrated, not a GDExtension GL interception hook. [Build/collection instructions](../native/biome_shader_profiles/README.md) preserve installed engines and templates. The checked engine patch and original-source hashes are retained with the evidence. The custom Windows debug template is under `build/biome-shader-profiles-20261106/godot-4.7.2-stable/bin/`. Android export templates were not built. The current tablet installation is unchanged; it requires a matching custom-engine client and device-specific profile collection before any device gain can be claimed.

## Validation

| Accepted check | Result |
|---|---|
| Final native contract/lifecycle/JSON/consent/outbox tests | 39 checks, 0 failures |
| Full actual-App observation matrix | 133 checks, 0 failures |
| Full actual-App selective matrix, requiring matched profiles | 143 checks, 0 failures |
| Omitted-variant and deliberate driving-miss controls | 17 checks, 0 failures |
| Final fresh-profile Pine full/selective pair | 13 / 14 checks, 0 failures |
| Final pause/resume and staged-settings fence, native Pine opening lap | 16 checks, 0 failures |
| Backend ingestion, authorization, bounds, deduplication and SQLite index round trip, plus retained quality tests | 22 passed |
| Scoped Ruff | passed |

The full matrices retain existing first-emission, canonical freeze, countdown, emitter coverage, cancellation, pressure and teardown assertions. Each completes five zero-contact opening laps, one per biome. Every matched selective report has zero missing variants, zero dropped observations and zero late compilation. The final Pine pair adds two opening laps with the same guarantees. These are opening-lap checks, not full multi-lap/camera/kit/device coverage.

All five paired biome ready views are pixel-exact (518,400 pixels each). The final Pine timing pair and the deliberately omitted-variant control also match exactly. Pine and Winter native images were visually inspected: actual cars, road, scenery and HUD are visible. Engine time is frozen only for the six-frame image settle; driving resumes at normal time scale.

The positive control removed one actually used specialization while leaving its shader known to the profile. Rendering continued, the image stayed exact, and the omitted variant was reported with **88.542 ms** of loading compilation. A separate new canvas shader introduced during driving produced a **19.209 ms** late miss. Neither control is included in the bundled profile inventory.

The final Pine timing pair uses two previously absent private application profiles and the same frozen sources/manifest/engine. The earlier whole-matrix observation run reused binary caches; it is valid for coverage/images, **not** a cold performance baseline. Its 6.058-second Pine entry must not be compared as an equivalent cache condition with the 8.692-second first selective entry. The final pair explicitly corrects that issue. Global driver caches were not reset.

## Retained findings and remaining acceptance

Initial engine builds required missing include fixes and Godot's supported `disable_path_overrides=no` option. An unavailable shader-time API caused a fixture parse failure; the fixture now uses the existing supported time-scale settle. A preliminary 133/0 matrix exposed missing identities for built-in empty-code versions; that inventory was rejected by the promotion guard, retained separately, and rerun after correction. A JSON round-trip test exposed integer/float context inequality and now passes with canonical identities. The migration fixture required committing its own inspection transaction before downgrade. Initial Ruff/import/style and image-comparison helper errors remain in evidence. No failing acceptance gate was removed. The native Windows certificate-store diagnostic remains; no accepted run has a script/shader error.

Final summary aggregation adds a regression for a known program recreated and compiled late after its first successful use; the final native contract test and fresh Pine pair use that final source. The broader rendering matrix predates that reporting fix and the observation-only fixture switch. A final pause/resume telemetry fence also postdates the timing pair; its separate 16/0 native run retains a matched profile, zero misses/late compilations and pixel-exact Pine output. The native engine and variant-selection implementation are identical across these accepted runs.

Remaining acceptance: additional car/biome/settings/camera/ghost/kit combinations, full races and race completion, broader cold/warm and peak-memory measurement, Android template builds and device captures, and matching authorized backend/client rollout. No phone/device query or test, APK or exported game package, owner-save/process change, live/backend request, deployment or main-index write occurred. Concurrent work is preserved.

The task-only [patch](evidence/biome-shader-profiles-2026-11-06/task.patch) passes exact forward and reverse application in an owned scratch directory; [receipt](evidence/biome-shader-profiles-2026-11-06/checkpoint.json). The main Git index was not written.

## Evidence and reproduction

Evidence is under [the task directory](evidence/biome-shader-profiles-2026-11-06/). Key receipts: [engine build](evidence/biome-shader-profiles-2026-11-06/engine-build.json), [native matrix](evidence/biome-shader-profiles-2026-11-06/native-matrix.json), [fresh-profile commands](evidence/biome-shader-profiles-2026-11-06/final-checks.json), [profile inventory](evidence/biome-shader-profiles-2026-11-06/measured-profiles.json), [five-biome image comparison](evidence/biome-shader-profiles-2026-11-06/coverage-observe-vs-coverage-selective-images.json), [final Pine images](evidence/biome-shader-profiles-2026-11-06/pine-full-final-vs-pine-selective-final-images.json), [backend output](evidence/biome-shader-profiles-2026-11-06/backend-final-accepted.log).

Actual commands include `python native/biome_shader_profiles/build_engine.py`, the retained `freeze_project.py` and `sync_fixture.py`, `python docs/evidence/biome-shader-profiles-2026-11-06/run_matrix.py`, and `python docs/evidence/biome-shader-profiles-2026-11-06/final_checks.py`. The latter requires new private profile names if repeated. Native runs are serial. Backend checks use `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_shader_profiles.py backend/tests/test_client_quality.py -q`. Image comparisons use `.tools/review/Scripts/python.exe` and `compare_images.py`.
