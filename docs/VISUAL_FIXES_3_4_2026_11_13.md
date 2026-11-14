# Visual review fixes 3 and 4

13 November 2026. The owner requested priorities 3 (material separation) and 4 (visible discontinuities) from [the visual review](VISUAL_QUALITY_REVIEW_2026_11_13.md). This pass preserves the accepted overhead camera, handling, vehicle silhouettes and opaque windows. It does not certify AAA quality or physical-device performance.

## Material finish — VQR03

Shared automotive paint has broader, quieter highlights; alloy, tyre rubber, industrial paint and seat polymer have distinct responses. The Forklift uses the industrial finish on its painted structure and a separate polymer seat. Volt and Challenger paint retain their own identities and all saved pigments.

Challenger glazing now starts from an opaque reflective material. The previous generic material disabled specular reflection before later glass settings were applied. Compact and Volt/Hover studio glazing use broad analytic reflections with nearby positional variation. Their existing racing day/night branches remain unchanged. These shaders do not capture another scene or read screen textures.

The Kart driver uses restrained suit panels, softly filtered stitching and fabric weave, darker boots, separate gloves and an opaque reflective visor. Per-instance material overrides retain the imported mesh buffers and all ten steering poses. Static and moving portions share the same suit material.

Native references:

- [Compact before](evidence/visual-fixes-2026-11-13/materials/before/gl_compatibility/compact-front.png) and [updated studio glass](evidence/visual-fixes-2026-11-13/materials/nearby-glass/gl_compatibility/compact-front.png).
- [Kart final Compatibility](evidence/visual-fixes-2026-11-13/kart/final/gl_compatibility/front.png) and [Mobile](evidence/visual-fixes-2026-11-13/kart/final/mobile/front.png).

## Surface discontinuities — VQR04

The Ellipse median defect was not a grass texture or lighting defect. Its two hairpin mouths share an infinite join plane. The road-edge code selected the first matching plane and applied that mouth's outward direction at the other mouth, leaving two hard shoulder wedges and pinched markings. Matching the finite cap span corrects this. A narrow scalar fallback covers coincident caps in the installed native-v1 library; ordinary and swept edges retain the native path. The matching C++ source is corrected for subsequent builds, but no platform binary was rebuilt. The visual-cache version changed so old road/world geometry is invalidated.

[Ellipse before](evidence/visual-fixes-2026-11-13/median/before.png), [fixed Compatibility](evidence/visual-fixes-2026-11-13/median/fixed-gl_compatibility.png), [fixed Mobile](evidence/visual-fixes-2026-11-13/median/fixed-mobile.png). The [median receipt](evidence/visual-fixes-2026-11-13/median/median-result.json) records the isolation probes, native controls and source hashes.

Volt contours had two causes: thin ribbons sampled as alternating pixels, and a few door segments whose chords crossed beneath the body at a crease. Adaptive subdivision retains the original 0.8 mm fitting offset while clearing those chords. Pixel-integrated contour coverage smooths the line at its actual projected width. The same treatment applies to the Challenger's door, handle and fuel contours. It retains depth testing, casts no contour shadows, and does not change the global antialiasing setting.

[Volt sampled](evidence/visual-fixes-2026-11-13/contours/gl_compatibility-electric-side-sampled.png) and [integrated coverage](evidence/visual-fixes-2026-11-13/contours/gl_compatibility-electric-side-integrated.png) are matched views from the same native process.

The Challenger bonnet gap required a separate fitted boundary ribbon because its original line was the actual gap between native painted panels. A 100-segment outline is derived from that bonnet boundary (maximum outline fit error 0.874 mm), then fitted above the real hood/body surfaces. Its 200 triangles join the existing contour surface; original exterior vertices and native resources remain exact. Totals are 49,968 reduced and 84,924 full triangles, within the existing 50,000/85,000 allocations. [Final native front view](evidence/visual-fixes-2026-11-13/contours/gl_compatibility-super_rally-front-integrated.png). This improves the gap's continuity; it is not a claim that every subpixel edge is alias-free in motion.

## Validation and integration

All engine runs use pinned `4.7.2.stable.official.ed1daf0bf`, disposable local profiles and offline configuration. `scripts/run_visual_finish.py` records commands, process exits and errors. Desktop renderer names are Compatibility/OpenGL and Mobile/Vulkan; the latter is not a tablet test.

| Check | Result |
| --- | --- |
| Material contracts and real constructor bindings | 115 checks, 0 failures |
| Kart finish, immutable mesh/morph data, material isolation and serialization | 64 checks, 0 failures |
| Actual CarVisual Kart steering integration | 157 checks, 0 failures |
| Driving and deterministic replay | 72 checks, 0 failures |
| Car washing | 1,655 checks, 0 failures |
| Finite join-cap regression | 51 checks, 0 failures; task-start control rejected with 14 failures |
| Existing native road geometry controls | 42 checks, 0 failures |
| Native C++ source syntax | Passed; binaries unchanged |
| Final contour geometry, original-data retention and backing clearance | 172 checks, 0 failures |
| Challenger opacity with a bright interior probe | 29 checks, 0 failures in each desktop renderer |
| Refreshed workshop equivalence and menu lifetime | 35 checks, 0 failures |
| Final production script parser | 562 scripts, 0 failures |
| All kit options during implementation | 8,995 checks, 0 failures across six cars |
| Final prepared vehicle resources | 551 resources, 2,267 checks, 0 failures |
| Packaged Garage thumbnails | Six exact pictures, 168 current source hashes |
| Native image imports and Rivalry textures | 318 source MD5s and 12 texture SHA-256 values verified; editor exited cleanly |
| Final actual App, all six Garage/race selections and Kart steering | 56 checks, 0 failures in each desktop renderer; no logged engine/script errors |

The static-reduction baker completed 883 observations before the prepared refresh. Material changes can alter batching keys, so existing reductions and prepared models must be refreshed together with their images. Artwork is refreshed before prepared models because the existing dependency system includes livery pictures in its source hashes. `scripts/refresh_visual_finish.py` uses the existing native bakers, source-change fences and strict prepared/picture provenance checks. `scripts/import_visual_finish_images.py` verifies imported image source digests.

An existing workshop provenance check rejected a stale `tests/support/car_refinement_lods.gd` dependency. The existing transactional architecture baker refreshed the prepared room without workshop source edits. Exact procedural/prepared room equivalence passes, and the workshop gate now verifies its scene plus all 27 declared sources.

The initial full script parser exposed unrelated concurrent test overrides of `App._start_race` with old argument signatures in `test_menu_quality.gd` and `test_metadata_race_preparation.gd`. That failed result remains recorded. The final production-only scan passed 562 scripts with no failures. Initial fixture errors and the first GL median cache-teardown diagnostics are retained; the corrected final median runs exited cleanly.

## Finalisation — 14 November 2026

The earlier refresh attempts were rejected after concurrent world-cache code, livery photographs and newly created Super Rally image-import metadata changed watched inputs or geometry revision keys. Those diagnostics are retained. Finalisation imported the images first, rebuilt all six bases, every kit, Garage rest scenes and the Compact header template, then published the six pictures using the transactional baker. The successful refresh watched 22,637 inputs with zero changes and passed the full prepared-resource and picture gates. The final client identity was regenerated after the images, with all vehicle revisions required to remain equal to the accepted bake revisions.

Concurrent Challenger corner geometry and loading-cache improvements are retained. The source-only checkpoint normalises three independently reviewed world-cache changes into both sides of the track-source patch, so applying or reversing this task does not remove that work. Exact original source baselines remain in `source-baselines`; the checkpoint records both the original and normalised hashes.

The original full-parser failure and rejected fixture/bake attempts remain diagnostic history; they are not counted as passes. The final production parser, material contracts and contour checks pass against the combined sources. The three superseded Kart candidate PNGs remain because automatic approval review rejected their removal with only "blocked by policy" as its reason; no alternative removal was attempted.

The first finalisation fence also detected 214 changed prepared/identity files, and the picture gate rejected their outdated scene hashes. Its input manifest and rejected-path list are preserved. Pictures were republished for the settled prepared scenes, imports reverified, and both actual-App renderer runs repeated. The accepted [closeout audit](evidence/visual-fixes-2026-11-13/closeout-audit.json) then verifies **23,237 unchanged inputs** across those runs, covering sources, prepared scenes and packaged pictures. Full prepared-resource, six-picture and workshop gates pass. [Final Garage](evidence/visual-fixes-2026-11-13/app-gl_compatibility/super_rally-garage.png) and [final race](evidence/visual-fixes-2026-11-13/app-mobile/compact-race.png) show the shipped UI paths. Exact native commands and exits are in `closeout-app-gl-final-receipt.json`, `closeout-app-mobile-final-receipt.json` and `closeout-prepared-final-receipt.json` beside the audit.

The [source checkpoint receipt](evidence/visual-fixes-2026-11-13/source-checkpoint.json) records byte-exact forward/reverse application, whitespace validation, the concurrent world-cache changes preserved in both directions, and the observed main-index hashes. No staging command was issued. It covers authored source, derived bonnet outline, tests, capture tooling and this report; generated mesh binaries and pictures are validated separately.

The task's active `.keep` marker was removed. The prescribed [retention cleanup](evidence/visual-fixes-2026-11-13/closeout-build-retention.log) completed successfully: 24.14 GiB remained because recent, protected or locked output is retained by the policy. No disposable project/profile copies were moved into permanent evidence.

No device query/test, APK/export, deployment, backend request, owner-profile operation or owner-process change was performed. Owner visual acceptance and sustained device performance remain open.
