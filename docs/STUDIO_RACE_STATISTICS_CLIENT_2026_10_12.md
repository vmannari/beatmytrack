# One package per race: client observations

Owner requirements (12 October 2026): drafts stay on the mobile; each race supplies one statistics package without continuous streaming; heatmaps expose actual device and OS context. This is the client portion of the Backend Studio monitor revision. It changes presentation observers and their bounded outbox, never canonical simulation.

The previous spatial collector waited ten minutes to flush, retained only sixteen spatial/segment cells, emitted one event per cell and cleared collected counters whenever foreground/support was unavailable. A normal short race could end before the timer, and leaving the game had no diagnostic flush. Frame summaries similarly waited five minutes. These paths explain a missing heatmap even when locally sampled positions existed. They do not establish that a particular deployed client ever supplied observations; the backend coverage investigation is separate.

`client_quality.gd` now begins a negotiated signed-in timed attempt and finalizes exactly one `race_statistics` event on finish, abandonment or restart. The event UUID is the preallocated attempt UUID, so upload retries preserve the same identity. A duplicate lifecycle callback cannot create a second package. One-Hz presentation sampling retains up to 128 twenty-metre spatial cells and 32 normalized route segments. Eight frame-time counters replace raw frame traces. The spatial sample uses inexpensive integer ranks; it reports discarded sampled seconds rather than inventing missing coverage.

The negotiated contract is `quality_schema_version=2`, nested package `schema_version=2`, with `race_id`, optional published `track_version_id`/`ticket_id`, `outcome`, `elapsed_ms`, `device_class`, actual `device_model`/`os_version`, `frame_buckets`, `cells`, `segments`, `position_samples` and `dropped_samples`. `cells` contains `[x,y,samples,slow]`; `segments` contains `[segment,samples,slow]`. A slow spatial/segment sample means its preceding sampled second contained a frame longer than 34 ms; it is not an exact percentile, collision measurement or count of slow frames. The frame histogram boundaries are 8/12/17/25/34/50/100 milliseconds.

Device/OS context comes from `OS.get_model_name()` and `OS.get_version()`, with eighty-character bounds and control characters removed. There is no unique hardware identifier. Without a published version, a timed local race can supply generic device/frame/outcome statistics only: no coordinates, segments, local track name, biome or document. Creator practice is excluded. Local editor/draft observations and unpublished track discovery observations have no client event contract. Publishing remains an explicit user action. Cosmetic dirt and paint are excluded.

Sampling does not enqueue individual frame or cell events. The race transport gate cancels optional requests, blocks new persistence workers and blocks network uploads, including application pause. A worker already started before the race gate may complete its bounded operation; there is no thread termination or simulation wait. Finished packages enter the same account/origin-partitioned atomic outbox. Temporary capability loss preserves the captured attempt and defers its package until schema 2 is available. Account changes cannot assign the captured attempt to a different player. Guest capture remains unavailable. An unfinished attempt lost to process termination remains unavailable; no periodic persistence or inferred final result is introduced.

The queue retains the existing 1,000-event, 2 MiB, 24-hour bounds, adding a conservative per-package byte budget. Identifier exhaustion and oldest-item eviction increment telemetry loss counters. A completed persisted package qualifies promptly for upload, subject to the existing minimum sixty-second request spacing. Multiple completed packages may share one packet; every race remains one event, not one event per spatial cell. Packets retain the fifty-event/64 KiB cap.

Changed files:

- `game/backend/client_quality.gd`
- `game/backend/product_telemetry.gd`
- `game/backend/backend_client.gd`
- `game/tests/test_client_quality.gd`
- `game/tests/test_product_telemetry.gd`
- `game/tests/test_race_statistics_app.gd`

The coordinating task owns `game/core/app.gd` lifecycle hooks and backend ingress, deduplication, projection and dashboards. This client task did not edit those files.

Actual commands and outcomes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://backend/client_quality.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_client_quality.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_product_telemetry.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_statistics_app.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
```

The script check passed. Final targeted tests passed: client quality **46 checks / zero failures**, existing product telemetry **55 checks / zero failures**, actual App lifecycle **14 checks / zero failures**. They verify one immutable event at each lifecycle end, no diagnostic event/disk worker/network while driving, pause behavior, temporary support loss, account changes, guest/practice exclusion, draft privacy, bounded counts, actual packet limits, atomic restart restoration, acknowledgement-only deletion and retained retry identity. The App test uses the actual composition and Game scene, calls the actual exit/retry/results callbacks, and sends no HTTP requests. Its manually completed TrackSession fixtures verify integration; they are not a claim of additional driven five-lap races. Final review also corrected legacy quality numeric restoration: Godot JSON numbers restore as floating variants, so bounded integer-valued floats are normalized to integers. An actual restart test confirms the queued OS-exit reason survives instead of being stripped.

The final native Windows run measured a full 128-cell/32-segment sample as **2,790 bytes per event / 3,061 bytes per complete JSON packet**. Mean frame update was **0.349 microseconds**, varied-cell update **57.7 microseconds** at one Hz, and package finalization **708 microseconds**. These are desktop observations, not phone/TLS/radio measurements. The published-track product fixture produced 15,070 bytes for a fifty-event packet and 460,343 bytes for its thousand-event queue. Its existing race-event enqueue p95 was 48 microseconds. A real generated fixture is retained at `build/studio-monitor-2026-10-12/client-test/statistics-sample.json`; all UUIDs/account values are local fixture data. Each native fixture run regenerates UUIDs and the sample fingerprint without changing the contract.

Earlier attempts encountered PowerShell execution policy and sandbox denial of Godot's normal outside-workspace log path. Tests were run with the pinned Godot through the build entry point under the existing test authorization. The first new quality test run had two fixture/context normalization failures; normalization and the assertion distinguishing RAM-only product events from diagnostic streaming were corrected. Later concurrent workspace changes introduced an unregistered `SpeedBumps` class. Import refreshed that class cache but itself stopped at another task's `CarVisual.gd:357` reference to missing `VehicleModels.config()`. Both targeted client suites passed after the refresh. The subsequent actual App test also compiled and passed after that task corrected its source; this task did not edit those files or claim a full Import/Validate pass.

Before snapshots are in `build/studio-monitor-2026-10-12/client-before/`. No phone attachment check, device test, Android export/install, live backend write or deployment occurred in this client task. Remaining acceptance is coordinated backend ingest/projection verification, owner heatmap review and a physical-device performance/network measurement. No historical heatmap data is fabricated.


## Communication review fixes 1, 2 and 4 ? 2026-10-13

Owner requirements COMM-01/COMM-02/COMM-04, B05/B07/Q01. Challenge result polling now honors server Retry-After, adds bounded jitter and resets consecutive failures on a valid result; malformed successes retain evidence and back off. The shared parser supports integer delays and all three HTTP-date forms, using server time where available.

The pinned scripts/dev.ps1 entry point stamps one deterministic shipping-source identity into game/core/build_identity.gd and application/config/version. Android version/name inherits that value. Uncommitted/new shipping sources participate; generated UID metadata and export-excluded tests/content do not. Stored observations retain their original build attribution. This labels source contents and is not an APK checksum.

New servers retain quality_schema_version=2 for existing clients and additionally advertise quality_schema_versions=[2,3]. Current clients prefer schema3, fall back to schema2 with older servers, and defer unchanged schema3 records after a downgrade. One bounded attempt package adds a versioned render context: actual renderer, applied car-detail mode, render-target pixel dimensions, 3D scale, explicit FPS cap, VSync and rounded reported display refresh. Start context stays frozen; one-Hz/end observations flag observed changes. Zero FPS cap means uncapped; zero refresh means unavailable. Short changes between samples are not guaranteed detected.

Migration0031 adds nullable context columns; historical settings remain unknown. Prepared Studio queries support renderer, exact setup and stable/changed/unknown context scopes. New selectors and the selected setup summary were exercised through real local HTTP ingestion/projection and browser rendering. No extra diagnostic endpoint or live streaming was added.

Actual targeted checks: SQLite113passed/2skips/33deselected; focused migration/context12passed/17deselected; owned PostgreSQL17 63passed and removed; native HTTP14/challenges165/telemetry55/App16/Compatibility quality58/Mobile quality58 all zero failures; deterministic identity7 and Studio browser28/presentation6 passed. Native fixtures use an isolated APPDATA profile. The final v3 packet is approximately3.3KB JSON; simulated hourly telemetry cadence remains20 active-menu/10 idle-menu requests. These are desktop/fixture results, not phone/TLS/radio cost. The initial JSON integer-restoration failure was corrected with its assertion preserved.

The workspace includes concurrent client vault/request-node/lifecycle and backend logging/storage work, which is preserved and excluded from this scope. No full regression, physical-device test, APK export/install, live data write or deployment occurred. Authorized backend rollout must apply0031; updated app export/install and physical-device acceptance remain. Actual commands, limits and scoped checkpoint: [review receipt](evidence/communication-fixes-124-2026-10-13/review.json).
