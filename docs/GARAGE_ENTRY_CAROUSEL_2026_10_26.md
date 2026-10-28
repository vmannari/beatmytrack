# Garage entry and carousel correction — 2026-10-26

GEC01–GEC03/R01/Q01 address the owner's reports that selecting Garage introduces a loading screen and that many carousel cars have no picture.

Garage now uses the normal menu transition on both first entry and an account change. The forced `restoring` detour and four covered preparation frames are removed. Startup still reaches Account/Race without constructing Garage, and subsequent visits retain the original interactive showroom. Account changes continue to replace the old page and its appearance cache.

Every carousel card immediately uses the packaged native photograph of its own car. Saved paint, fitted parts and condition still request an exact capture; a separate displayed identity marks when that capture replaces the catalogue picture. A cache miss or changed finish therefore cannot blank a card, and a superseded capture cannot publish. Catalogue pictures can temporarily show the factory finish while the exact saved appearance is being prepared. The main showroom remains authoritative and interactive. The seven cards still own no worlds; the main Garage retains three viewports, one temporary capture renderer and the original 14-file cache bound.

The cached thumbnail also accepts the optional paint-animation argument added concurrently to its parent. The animation implementation, other Garage work, Rivalry changes, track changes and race preparation work are preserved and excluded from this task's runtime patch.

The normal transition still constructs the live room synchronously and performs its first shader draws. **This change removes the loading screen; it does not make cold Garage preparation asynchronous or guarantee instant first entry.** Fresh-profile desktop draw times varied substantially during concurrent native work. Raw timings remain in the report and are not comparable performance benchmarks or phone measurements.

Verification uses Godot `4.7.2.stable.official.ed1daf0bf`, isolated local profiles, a dummy audio driver and no configured live API:

- Focused real-App regression: 37 headless, 46 Compatibility and 46 desktop Mobile checks pass. These cover saved condition on all seven cars, immediate pictures with an empty cache, stale capture protection, exact appearance replacement, renderer cleanup, retained navigation and account replacement.
- Staged task-start behavior: 30 headless / 33 Compatibility checks reproduce nine failures: two loading-screen cases and seven empty pictures. Only the old thumbnail's optional method argument is adapted for the concurrent parent signature; its behavior is unchanged. Original bytes are retained in `before/`.
- Retained mobile audit: 253 headless / 263 Compatibility checks pass, including exact custom image content, disk reuse, three retained viewports, reflection guards, hidden-page cleanup and account fences. Its exact-image wait now checks the displayed identity, because a catalogue fallback is already nonblank. The obsolete cancellation-before-construction expectation is replaced by direct-entry retention.
- Existing App: 141 checks pass. Parser: 1,260 scripts pass in the recorded run. Final source parsing and packaged-photo provenance results are recorded in the report.
- Seven native photographs were rebuilt. All seven PNG hashes remain byte-identical to task start; only provenance needs the current source identities. Concurrent presentation edits can invalidate that manifest again until their final bake.

Initial fixture mistakes and failed integration attempts are retained, including seeding settings before profile load, bypassing the condition store, counting earlier capture jobs as new paint jobs, and the concurrent method-signature mismatch. No original image-content, lifetime or account assertion is weakened. The sandbox certificate-store error is recorded separately from test failures.

[report.json](evidence/garage-entry-carousel-2026-10-26/report.json) records commands, outcomes, source hashes, initial failures, captures and the task-only review patch. Screenshots include the original blank-card case and fixed dirty/clean profiles. Desktop Mobile is Vulkan on this workstation.

Reload/rebuild the client to use the changes. Owner acceptance of navigation, pictures, touch and first-entry latency remains. No device attachment check or physical-device test, APK/AAB, authentication/purchase, live mutation, deployment, staging, commit or owner-process restart was performed.
