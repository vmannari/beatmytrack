# Mobile audit evidence — 26 October 2026

Read the [audit report](../../COMPREHENSIVE_MOBILE_AUDIT_2026_10_26.md) first. This directory contains audit evidence, not production fixes.

- `report.json`: exact command records, result counts, known environment/fixture failures, source preservation and limitations.
- `coverage.csv`: 30 reviewed subsystem groups, source paths, verification and remaining gaps.
- `source-inventory.json`: baseline hashes for 1,997 source/configuration files.
- `backend-sqlite-junit.xml` and `backend-triage-junit.xml`: actual failed/passed/skipped cases. The broad available run stopped at its configured 20-failure limit; it was not an all-tests pass.
- `logs/` and `commands/`: actual outputs and argv/cwd/exit/time records, including unsuccessful attempts.
- `captures/`: current desktop Compatibility images. Store captures use a fake service. Other screens use a fresh isolated offline profile; the Race image is empty and Creator is captured during early preparation.
- `synthetic-trajectory-result.json` and `ellipse-geometry.json`: locally generated path acceptance and the pinned actual geometry/manifest. No score or wallet was written.
- `transition-results.json`: nine direct native race scene constructions and queued disposals. Godot static memory is not Android PSS/GPU memory.
- `native-elf-alignment.json`: ELF load-segment inspection of the two checked-in geometry SOs; final package alignment is still unverified.
- `probes/`: exact audit-only harness sources. They were executed from `build/mobile-audit-2026-10-26/`, outside production. To reproduce, copy them to that location and use the corresponding command record. Do not batch-run all repository tests without checking their prerequisites and mutation behavior. The recorded broad backend suite contains a nested native launcher that regenerates client identity; the audit restored both affected files to their exact baseline hashes.
- `artifact-hashes.json`: hashes of the evidence files; the audit report itself is reviewed separately.

The local `GodotVerifier` wrapper rejected the sandbox's root-certificate-store engine error. The geometry reproduction therefore uses the ordinary data-only runner's explicit response file and the actual Python acceptance function; it is not a successful end-to-end deployed-service verification. Earlier failed geometry/wrapper attempts remain in the logs.

MA04's unmuted callback probe explicitly enabled ordinary menu playback on a dummy audio device because headless runs normally suppress decoder playback. It counts render submissions; it does not measure GPU time or audible quality. MA13 separately measures the actual graphical App startup and covered Garage preparation without enabling a backend.

No production fix, deployment, APK/AAB, device attachment check, physical-device test, real purchase, successful external authentication, owner-process restart or Git stage/commit/merge was performed. An external concurrent change to `game/vehicle/handling_config.gd` was preserved. Final release acceptance must use a frozen source/build snapshot.
