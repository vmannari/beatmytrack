# Development status

2026-09-30 V03/V04/Q01: lap strip uses white text for every non-fastest lap in all interaction states, gold for fastest, no collision markers and an 85%-opaque selected background (hover 30%). Graphical results: 493 checks pass; desktop screenshot inspected. No phone attached/export/device test. See docs/PREMIUM_RESULTS.md.

2026-09-30 R01/R03/R07/G01/T01-T04/V03/Q01: rules v13 fixes missed checkpoints on steep straight-road joins using physical apex gates, mitred widths and removal of intersecting neighbours. Checkpoint 266, native replay 167, start-line 27, records 53, rewind 51 and graphical 15 checks pass. Shared v12 tracks retain content/history and get separate v13 boards. No phone attached/export/device test. See docs/SHARP_JOIN_CHECKPOINTS.md.

2026-09-30 V03/R01/Q01: only the single fastest eligible flying lap can claim a new Personal best; earlier equal-time lap wins ties. Removed secondary LAP PB claims when several laps beat the old record. Graphical results suite: 493 checks pass, including first race/multiple improvements/ties/unbeaten records. No phone attached/export/device test. See docs/PREMIUM_RESULTS.md.

2026-09-30 V03/V04/R01/Q01: results lap selection now preserves map/route/strip geometry across hover and selection; race-wide incident framing, fixed sector columns, equal button padding, no selection underlines (including shared tabs), and new flying-lap records say Personal best. Headless 391, graphical 408 and menu 26 checks pass. No phone attached/export/device test; see docs/PREMIUM_RESULTS.md.

2026-09-30 V03/V04/R01/Q01: premium results presentation uses an open blurred race scene, dominant time/direct PB comparison, one factual achievement, enlarged annotated route, Track/Sectors/Speed modes, horizontal lap strip and race-wide speed/incident summary. Desktop capture checks pass; no phone attached or Android export/device test. See docs/PREMIUM_RESULTS.md.

2026-09-29 V02/V04/V05/Q01: kit 89 fairs tight internal road contours and builds creator kerb visuals from the same outline, omitting isolated decorative slivers. Ajorata and Curvy desktop captures inspected; shoulder regression, 71 join, 18 contour, 31 kerb and 928 surface checks pass. Canonical contacts/cells unchanged. No phone attached/export/device test. See docs/AJORATA_JOINS.md.

2026-09-29 V02/V04/V05/Q01: Curvy inner joins now use the same one-metre cosmetic rounding as outer joins, measured along the edge across short mesh segments. Shoulder regression, 71 join and 928 surface checks pass; desktop capture inspected, native cells unchanged. No phone attached/export/device test. See docs/CURVY_JOINS.md.

2026-09-29 V02/V04/V05/Q01: Curvy angled joins use shared cosmetic quadratic fillets and matching shoulder/marking normals. Sand gaps close and road/white-line corners soften without modifying canonical outlines. Shoulder overlap regression, 55 join checks and 928 surface checks pass; before/after desktop capture inspected. No phone attached/export/device test. See docs/CURVY_JOINS.md.

2026-09-29 RW18-RW19/V03/V04/Q01: cleaner original vector ad icon now sits at the right end of the resume button. Rewind snapshots retain accumulated windshield damage: Resume removes only skipped collisions, while older cracks remain and Cancel restores entry damage. Graphical rewind 57, impact 9, presentation/performance 16 checks and real HTTP replay test pass. Screenshots inspected; no phone attached/export/device test. See docs/REWIND.md for evidence and commands.

2026-09-29 RW16-RW17/V03/B19/Q01: reference resume toolbar adds race-use circles and a ticket/count or ad-icon action. Banked resumes spend first, then daily allowance; the owner-authorized temporary ad path resumes immediately without claiming an ad or adding banked credit. Three/race and ten-second bounds remain server-enforced. Native 44 / graphical 49 checks, focused HTTP/SQLite/PostgreSQL tests and receipt tamper checks pass. Local API restarted healthy. No phone attached/export/device test. See docs/REWIND.md for commands, evidence and integration cutover.

2026-09-29 RW12-RW15/V03/Q01: rewind now opens at the current position, shows only recorded ghosts on both sides of the selection, and limits new resumes to ten seconds in client/server. One compact toolbar holds Cancel, scrubber and play-to-resume; Live/extra transport and side cards removed. Native 41, graphical 45 checks and 13 focused backend tests pass (6 PostgreSQL variants deselected). PC services updated healthy; existing receipt replay compatibility retained. No phone attached/export/device test. See docs/REWIND.md for commands, screenshots and limitations.

2026-09-29 B01-B07/B18/B21/B23/B28/RW01-RW08/V03/Q01: owner-supplied backend concept implemented as a live Control Room at /admin: searchable players/tracks/races, pinned evidence, real operational counts, resume grants, owner/analyst authorization and atomic audited restriction/visibility commands. PC stack migrated to 0007; 177 backend tests pass / 6 expected skips, PostgreSQL concurrency and desktop/mobile-width browser checks pass. No physical-phone test or production deployment; unsupported prototype services remain explicitly unavailable. See docs/BACKEND_UI.md for commands, screenshots, scope and acceptance.

2026-09-29 RW09-RW11/V03/R01/B19/Q01: reference-inspired rewind screen with gold timeline/transport, live endpoint, minimap and actual blue history cars. Resume uses a 300 ms fixed-step pacing ramp; Cancel uses only 60 ms camera easing and leaves simulation/input at full speed. Rewind 40, graphical 43 and driving 74 checks pass; real HTTP/outbox rewind verification retains 12,757 ticks. Desktop captures inspected; no phone attached, Android export or device test. See docs/REWIND.md for commands, evidence and remaining feel/device acceptance.

2026-09-29 V01/V04/Q01: independent kerb tyre travel and stronger damped body pitch/roll, including asymmetric contacts. Presentation-only; canonical handling unchanged. Suspension 59, driving 74 and graphical kerb 40 checks pass. Desktop crossing inspected; no Android export or physical-device test. See docs/KERB_SUSPENSION.md for commands, evidence and acceptance limits.

2026-09-29 RW01-RW08/R01/R03/B19/V03/Q01: selectable twenty-second rewind, three resumes per race, one non-stacking UTC daily free resume and permanent server credits. Rewind-assisted runs remain leaderboard eligible by explicit owner override; v2 replay retains discarded inputs and requires race-bound receipts. Native rewind 26 / graphical 29, driving 74, practice 49, results 191 checks pass; full backend coverage 170 passed / 6 expected SQLite concurrency skips. Local PC API/worker migrated and updated; Linux original/rewind replay parity passes at 12,757 ticks. Ad provider/billing products and verified fulfillment remain unconfigured and unavailable. No phone attached, Android export or device test. See docs/REWIND.md for evidence, commands, initial failures and remaining acceptance.

2026-09-29 R01/T01-T04/B02/B19/Q01: upload failure traced to the running PC backend still using compiler 19. Rebuilt/restarted API and worker with compiler 20; both accept the same overlapping-bridge fixture/hash. BackendStart now builds/verifies the shared image before replacement. Construction: 102 checks; focused backend: 37 passed. Existing data retained; no production deployment, phone test or export. User upload retry remains. See docs/BACKEND_BRIDGE_VALIDATION.md.

2026-09-29 T01/T04/R01/Q01: editor autosaves are now recovery-only. Closing, starting New or loading another track with unsaved changes asks Save / Discard / Cancel; Save requires a real name and Discard removes only the WIP copy. Script parse and focused creator persistence checks pass. Full TestApp remains blocked by its pre-existing account-screen startup expectation before reaching the new assertions. No Android export or device test. See docs/EDITOR_DRAFT_SAVING.md.

2026-09-29 R01/T01-T04/V04/V05/Q01: reproduced post-approval scenery stall (1143.9 ms frame). Editor replacement scenery now builds in cooperative slices, retains the displayed scene/pending road overlays and swaps after active gestures. Same desktop fixture: 28.8 ms worst frame, 10.9-13.9 ms approval handlers; full detail takes 1.94 s while editing stays responsive. Three-theme mesh equivalence, supersession/exit, workflow, surface, placement and shoulder checks pass. No phone attached/export/device test. See docs/ROAD_APPROVAL_SLICES.md.

2026-09-29 V01/V04/Q01: rear lamps now initialize lit on all five vehicles and stay lit in daylight/night; running emission 0.65, braking 2.2. TestHeadlights and CaptureHeadlights each pass 61 checks. Desktop evidence inspected; no Android export or physical-device test. See docs/REAR_RUNNING_LIGHTS.md.

2026-09-29 R01/T01-T04/V04/V05/Q01: same-height creator bridge overlaps form drivable elevated junctions with clipped internal rails. Undo/redo preserve the viewport, compile previews asynchronously and reuse bounded track/scenery caches; shape/deletion edits use the same path and skip the unused map raster. Desktop fixture: 45.1 ms undo / 13.3 ms redo versus 1368.6 ms reconstructed synchronous undo. Bridge, replay, editor and raster checks pass; no phone attached, Android export or device test. See docs/BRIDGE_JUNCTIONS_AND_EDITOR_PERFORMANCE.md.

2026-09-29 V01/V04/Q01: owner follow-up lowers/deepens the compact rear bumper (bottom 0.435 to 0.320, top 0.630 to 0.600 model units), with a flatter rear-specific wrap to cover the lower valance cleanly. CaptureCompactDetail succeeded with 10 refreshed desktop views; final rear inspected. No physical-device test or Android export. See docs/COMPACT_REAR_FIT.md.

2026-09-29 V01/V04/Q01: compact rear lamps now follow the tapered/chamfered body; bumper moved inward 0.14 model units and hatch handle seated against the hatch. CaptureCompactDetail saved 10 desktop views; rear/high-rear inspected. TestHeadlights passed 56 checks. No Android export or physical-device test performed; owner visual acceptance remains. See docs/COMPACT_REAR_FIT.md.

2026-09-29 V02/V04/V05/Q01: Spiral shoulder seams fixed in visual kit 86: continuous sand beneath kerb tips and spatially indexed overlap clipping with nearest-road blend ownership. Focused geometry, 928 surface-profile and 53 desert checks pass; desktop Spiral captures inspected. No phone attached, Android export or device test; mobile mesh/build cost and in-motion acceptance remain. See docs/SPIRAL_SHOULDERS.md.

2026-09-29 B02–B07/B19/R01/V03/Q01: Play now reads backend track metadata, lazily downloads SHA-256-checked immutable documents and caches them for offline play. Name/creator/biome/favorite filters, server ratings, per-car paginated high scores, around-me, verified race capture/outbox, cloud publishing and results rank are connected. Real HTTP/worker/game integration passes 47 checks; actual five-lap capture matches 12,757 server ticks. PC backend updated; existing local maps preserved pending catalog-migration preference. No phone attached/export/device or production deployment. See docs/CLOUD_TRACKS.md for commands, screenshots and limits.

2026-09-29 B01/B19/R01/Q01: racing names now have a unique normalized database key, preserving UUID as master identity. Case/whitespace/Unicode-compatible duplicates rejected with actionable UI feedback; concurrent claims tested, pending users choose before sharing, developer name reserved. Migration 0005 preserves both PC profiles. 120 backend, 5 PostgreSQL, 8 focused username tests and 67 native checks pass. No phone/export/production deployment. See docs/UNIQUE_USERNAMES.md.

2026-09-28 B01/B19/V03/Q01: remembered startup now uses a neutral loading screen and enters Home after successful restoration without constructing/flashing login controls. New users and failed restoration retain sign-in. Frame-by-frame native startup assertions passed; loading screenshot inspected. No phone/export/backend change. See docs/REMEMBERED_SIGN_IN.md.

2026-09-28 V02/V04/V05/Q01: owner rejects lighting-only grass preview; removed prototype shader/capture branch, retaining static meadow without generated blades. Source PNG car pixels were stable but GIF palette conversion changed colours; preview rejected. See docs/GRASS_WIND.md. No Android export/device test.

2026-09-28 B02/B19/R01/Q01: race results now includes shared circuits and loads recommendation documents from their actual source directory, matching Play. Common catalog setup; empty-private/shared-library regression covers cold results, after-Play results and launching the selected shared track. CaptureResults passed 207 checks; screenshot inspected. No phone/export/physics change. See docs/ACCOUNT_OWNERSHIP.md.

2026-09-28 G01/V01/V04/Q01: resolved collision impulses now drive the car's existing visual suspension spring. Side impacts roll the body, longitudinal impacts pitch it and all meaningful impacts briefly compress it; response is bounded and presentation-only. Script parses, suspension 35, driving 74 and track/collision 167 checks pass. No phone/export or subjective in-motion acceptance; see docs/CAMERA_SHAKE.md.

2026-09-28 G01/V01/V04/Q01: off-track travel now adds a subtle speed-scaled heave and roll to the car body, in addition to the existing loose-surface camera rumble. The effect is tick-derived, bounded and presentation-only. Both changed scripts parse; suspension 32, driving 74 and soil 163 checks pass. No phone/export or subjective in-motion acceptance; see docs/CAMERA_SHAKE.md.

2026-09-28 B01-B07/B19/R01/Q01: local ratings, records, preferences and editable track storage now follow stable account identity. Creator names are account-derived and server-stamped; developer races as Beat My Track (migration 0004). Fixed initial visibility regression: all 20 existing PC circuits remain playable as shared content, without inheriting ownership or votes. Native account, records/catalog and actual-PC checks passed; no device test/cloud sync added. See docs/ACCOUNT_OWNERSHIP.md.

2026-09-28 V02/V04/V05/Q01: opt-in lighting-only grass prototype keeps texture coordinates fixed and blades removed; normal angles plus gentle brightness gusts. Default strength zero keeps gameplay static. Knot preview 65 checks and final static capture 21 checks pass. Preview: docs/GRASS_WIND.md. No phone attached/export/device test; awaiting visual review.

2026-09-28 V02/V04/V05/Q01: owner rejects grass wind and blades. Kit 85 removes generated blade batches and restores static meadow colour/normals. Static Knot capture passes 21 checks (zero changed grass/road pixels); surface-profile 928 passes. Screenshot inspected. No phone attached, export or device test. See docs/GRASS_WIND.md; this supersedes both wind revisions.

2026-09-28 V02/V04/V05/Q01: grass wind revision 2 fixes owner-rejected static-looking meadow. Kit 84 animates visible grass pigment/normals plus taller, spread-out blades. Fixed-phase, cloud-isolated driving captures pass 53 fixture/54 Knot checks with 72–74% grass samples moving and zero road samples; surface-profile 928 passes. Evidence and limits: docs/GRASS_WIND.md. No phone attached/export/device test; owner visual acceptance remains.

2026-09-28 V02/V04/V05/Q01: owner-requested stronger grass wind increases tip sway to 45 mm with shared world direction and travelling gusts; density unchanged. CaptureGrass -Screen wind passes 51 checks; desktop frames inspected and animated preview saved. No Android export/device performance test; owner and phone acceptance remain. See docs/GRASS_WIND.md.

2026-09-28 B01/B19/R01/Q01: startup now opens sign-in for guests and restores a server-validated remembered session before entering Home. Rotating refresh token is stored separately from local records; menu account offers logout and clears saved credentials. Native restart/rotation/logout checks and actual-PC account checks passed. See docs/REMEMBERED_SIGN_IN.md; real Google and physical-device acceptance remain.

2026-09-28 B01/B19/R01/V03/Q01: provider-first sign-in redesign separates Google authentication from first-time racing-name selection; fixed developer and local guest options remain independent. Original alpine backdrop, dedicated card and editable controls; existing names preserved by migration 0003. 112 non-PostgreSQL tests, 4 PostgreSQL auth tests, 38 native account checks and 8 actual-PC checks passed; desktop screenshots inspected. PC API migrated/restarted. Real Google interaction and physical-phone acceptance remain; no Android export or production deployment. See docs/SIGN_IN_REDESIGN.md.

2026-09-28 B01/B19: owner-supplied Google Web client ID configured in ignored PC settings; BackendStart recreated the healthy API/worker. Live readiness, enabled providers, browser handoff, exact client ID/nonce and pending-poll checks passed; diagnostic cancelled. Interactive Google sign-in and console origin acceptance remain for owner testing. No phone/export/production deployment. See docs/ACCOUNT_SIGN_IN.md.

2026-09-28 B01/B19/R01/V03/Q01: PC sign-in failure traced to port 8080 serving Crane CMS and missing local auth configuration. Dedicated persistent PC stack now runs on loopback18181; BackendStart/Stop and saved editor config added. Development verified against actual PostgreSQL/API (8 live checks), wrong-service credential guard and 43 auth/4 follow-up tests pass. Official Google button artwork and real-PC screenshots inspected. Google awaits owner-created OAuth client ID; no phone/export/NAS test. See docs/ACCOUNT_SIGN_IN.md.

2026-09-28 B01/B19/R01/V03/Q01: account menu adds Google browser sign-in with the chosen username and a fixed temporary `developer` login. Session/logout/cancellation and server-side development retirement tested; PostgreSQL concurrency, backend suite, real HTTP/Godot account flow and menu presentation pass. Desktop screenshots inspected. Old TestApp still fails obsolete navigation labels. OAuth client/origin configuration and real-Google/NAS/phone acceptance remain; no Android export/device test. See docs/ACCOUNT_SIGN_IN.md.

2026-09-28 B01-B07/B19-B20/B23/B27-B28/R01/R03/R07: first backend adds Google identity plus an explicit isolated development bypass, immutable shared tracks, qualified ratings and canonically verified leaderboards. PostgreSQL concurrency, signed-token/session security, Windows/Linux pinned replay/manifest parity, full Docker API/worker flow and backup/restore pass; 74 driving checks and import pass. Backend client adapter is optional and menus remain local. NAS deployment, real Google login, mobile integration and phone acceptance remain; no Android export/device test. See docs/BACKEND_V1.md for commands, outcomes, architecture and limits.

2026-09-28 MUS03/MUS06/MUS09/MUS10/R01/V03/V05/Q01: soundtrack packages define compatible per-state pools with package-first fixed drive selections; custom 1-12 states, saved-track Trash/restore and shared Mix Lab sidebar. Schema-2 migration; 14 service, 10 toolkit, 11 package-browser and existing browser regressions pass. Desktop/390px evidence inspected. Local authoring only; no new generation, game/device test or musical approval. See docs/MUSIC_PACKAGES.md.

2026-09-28 MUS03/MUS06/MUS09/MUS10/R01/V03/V05/Q01: redesigned local music studio adds direct Magenta RT2 prompts, persistent take inbox, audition/save/discard/restore, editable saved-track states and a separate Mix lab. Two real GPU renders; 8 service, 10 toolkit, 10 real-browser groups, 5 simulated-failure groups and all four existing browser suites pass. Desktop/tablet/390px evidence inspected; owner UX/music acceptance remains. No runtime or physical-device test. See docs/MUSIC_STUDIO.md.

2026-09-28 MUS03/MUS06/MUS09/MUS10/V03/V05/Q01: rejected high/short acoustic opening replaced by low sustained cello in fixed and evolving modes; all three alternatives and six tempos revised. Rejected takes excluded from catalog. Nine opening checks, six fixed/five tempo export checks, 15/19 browser checks and 10 toolkit tests pass. Listening approval pending; no runtime/device test. See docs/music/rounds/2026-09-28-low-opening-r5.md.

2026-09-27 MUS03/MUS06/MUS09/MUS10/V03/V05/Q01: evolving-tempo audition mode preserves the R3 score and choices across 90/102/114/126/138/150 BPM. 108 pitch-preserving renders; synchronized phrase transitions, BPM display and persisted mode. Five export checks, 19 R4 browser checks and existing workbench/R2/R3 regressions pass; default renderer byte-identical. Listening approval pending; no game change or phone test. See docs/music/rounds/2026-09-27-evolving-tempo-r4.md.

2026-09-27 MUS03/MUS06/MUS09/MUS10/V03/V05/Q01: additive music R3 adds six synchronized instruments with three alternatives each (729 combinations), original shared score, sampled offline rendering and random/manual workbench selection. Six export/score checks, 15 R3 browser checks, existing 19 workbench/9 R2 checks and 10 toolkit tests pass. Artistic approval and shipping provenance review pending; no runtime change or phone/device test. See docs/music/rounds/2026-09-27-additive-r3.md.

2026-09-27 MUS03/MUS06/MUS09/MUS10/V03/V05/Q01: reference arc R2 generates two options at each of six stages (12 distinct 16-second mixes). Per-stage A/B loudness comparisons and All A/All B/New drive workbench controls; choices remain fixed per drive. 10 toolkit tests and 9 R2 browser checks pass; screenshot and manifests retained. Musical approval/compatibility pending; runtime unchanged, no Android/device test. See docs/music/rounds/2026-09-27-reference-arc-r2.md.

2026-09-27 MUS03/MUS06/MUS09/MUS10/R01/V03/V05/Q01: offline Magenta workflow and standalone browser music workbench. Reused WSL GPU/model; corrected prompt truncation that produced duplicate recordings. Four distinct concepts, Focus/Breakthrough and prepared audition pair; 9 toolkit tests and 19 browser checks pass with screenshots. Runtime unchanged; musical approval and compatible stems remain pending. No Android/device test. See docs/MUSIC_TOOLKIT.md.

2026-09-25 MUS01/MUS03/MUS06/MUS09/MUS10: owner requests interchangeable per-race phrases and unobtrusive background music after rejecting v6 timbres. Offline bank v1 provides three options for five compatible roles (243 combinations), with brisk rounded notes and no rock finale. All 243 structural/render checks and four 30 s auditions pass numeric checks (10/24 peak voices). Production unchanged pending listening; no UI, Android export or device test. See docs/MUSIC_MODULAR_BANK.md.

2026-09-25 MUS01/MUS03/MUS08-MUS10: v6 replaces the rejected opening beat with a single sustained low-register melody, then adds inner harmony, bass, drums, guitar and an answering line as clean-driving intensity rises. Collision recovery returns to solo. Production-core 48 s preview, native layer/allocation/timing tests, 36 music / 38 driving checks and quick Android export pass. No phone attached; no installation or device/listening acceptance. See docs/MUSIC_ENSEMBLE.md.

2026-09-25 MUS01/MUS03/MUS05/MUS08-MUS10: music v5 starts calmly and builds from sustained clean forward speed (3 s average, 36 km/h threshold, 4 s qualification, 24 s build). Collisions reset into a 5 s recovery and sparse descending minor phrase; final lap cannot override it. Native tests, 35 music / 37 driving checks and quick Android export pass. ADB has no attached device; new APK not installed or phone-tested. Tuning/ear acceptance remains; see docs/MUSIC_DRIVING_PROGRESSION.md.

2026-09-25 MUS01-MUS10/R01/V03/V05/Q01: owner accepts original rock audition for driving trial. Runtime v4 replaces high synth voices with physical strings/amp, bass and dry drums at 128 BPM, retaining predictive track controls. Native safety/timing/rate tests, 24 music and 26 graphical drive checks, three exit stress runs and quick Android export pass. Installed on attached DN2103; 20-second driving smoke advances 176.597 m with zero observed render-budget overruns. Normal play restored. Listening/thermal acceptance remains; see docs/PROCEDURAL_MUSIC.md.

2026-09-25 V02/V04/V05/Q01: owner requests brighter sun and slower clouds. Grass sun energy 1.06 to 1.20, cloud drift 0.91 to 0.30 m/s; contrast retained, contact-lighting-5 / kit 83. CaptureContactShading 45 and quick deployment checks pass, desktop screenshot inspected. Updated APK installed/launched on DN2103; no fresh phone driving/profile test. See docs/CONTACT_LIGHTING.md.

2026-09-25 MUS01/MUS03/MUS09: owner sets Peer Gunt Backseat as inspiration. Added an isolated original 15-second riff-led rock audition: physically modelled strings, amp/cabinet, bass and dry drums; no upper synth melody. Deterministic/finite/bounded render passes, 12/24 peak string voices. Not integrated; ear/mobile acceptance pending, no Android/device test. See docs/MUSIC_REFERENCE_REVISION.md.

2026-09-25 MUS01/MUS03/MUS09: owner rejected revision 2 instruments, especially the higher voice. Offline revision 3 removes upper lead/pluck/tension activity and delay, softens percussion, and supplies two 8-second same-gain backing/low-register-keyboard comparisons. Native safety/timing/determinism checks pass (11 peak voices). Ear acceptance remains open; production audio unchanged, no Android/device test. See docs/MUSIC_REFERENCE_REVISION.md.

2026-09-25 MUS01/MUS03/MUS09: owner rejected the whole soundtrack and supplied a WAV reference. Added an isolated original v2 composition/DSP audition at 120 and 128 BPM: coherent minor-key motif, explicit chord releases, fuller bass/pads and reduced metallic activity. Native determinism/allocation/timing/bounds tests pass, peak 13 voices. Production music remains v1 pending ear review; no runtime rebuild, Android export or device test. See docs/MUSIC_REFERENCE_REVISION.md.

2026-09-25 MUS01-MUS10/R01/V03/V05/Q01: Grass procedural-music listening slice adds native 32-voice synthesis, sample clock/sequencer, track fingerprint/map, predictive controller and F8 diagnostics/Music Lab. Native determinism/allocation/bounds/timing tests, 23 music checks, 25 graphical driving checks, 12x64 immediate-exit stress runs and quick Android export pass. Final desktop mix 170 us (peak 316 us), zero render overruns; attached phone not tested or installed. Immediate-exit pending-object warnings and ear/device acceptance remain. See docs/PROCEDURAL_MUSIC.md.

2026-09-25 V02/V04/V05/Q01: owner clarified brighter sunlit areas, restoring 24% cloud contrast and raising Grass direct sun 6%; contact-lighting-4 / kit 82. CaptureContactShading 45 passes. Concurrent music broke shared export; isolated quick export/install/launch succeeds on DN2103 with existing winter frost preserved. No new phone driving/profile test. See docs/CONTACT_LIGHTING.md (Brighter sunlit areas).

2026-09-25 V02/V04/V05/Q01: owner brightness adjustment lowers Grass cloud opacity from 24% to 20%; patch size/motion unchanged, contact-lighting-3 / kit 81. CaptureContactShading 45 and quick deployment checks pass; desktop capture inspected, APK installed/launched on attached DN2103. No fresh phone driving/profile test. See docs/CONTACT_LIGHTING.md (Slightly brighter cloud shade).

2026-09-25 V02/V04/V05/Q01: owner could not see clouds; contact-lighting-2 / kit 80 increases cloud opacity to 24%, reduces patch scale to 18 m and doubles drift speed. CaptureContactShading 45 and quick Android export checks pass. Installed/tested on DN2103: 176.2 m, median 16.555 ms/p95 20.456 ms; desktop/phone captures inspected, normal play restored. Grass only. See docs/CONTACT_LIGHTING.md (Cloud visibility follow-up).

2026-09-25 V02/V04/V05/Q01: contact-lighting-1 / kit 79 adds car and fixed-scenery contact shading, layer-aware bridge under-shadows and Grass-only drifting cloud shadows. CaptureContactShading 44, bridge contacts 16, construction 82, vehicle batch 35 and quick export checks pass. Installed/tested on DN2103: enabled median 16.599/16.675 ms vs hidden 16.622 ms on Knot; desktop/phone evidence inspected, normal play restored. See docs/CONTACT_LIGHTING.md for measured limits and owner acceptance.

2026-09-25 V02/V04/V05/Q01: winter-only transparent screen-edge frost beneath the HUD. CaptureWinter 167 checks pass, driving/compact desktop evidence inspected. No Android export or device test; owner/device acceptance pending. See docs/WINTER_FROST.md.

2026-09-25 R01/V04/V05/Q01: Knot profiling reproduces steering-haptic stalls without collisions; bounded Android worker reduces 30-second frames >33 ms from 184 to 0/2. Stationary tyre solver saves ~20% in an 85-stack desktop microbenchmark; 13,200 exact equivalence checks pass. Corrected synthetic-touch probe, installed APK, phone evidence and known editor/model test failures: docs/KNOT_PERFORMANCE.md.

2026-09-25 R01/V03/V05/Q01: Settings directly exposes Buttons, Analog slider and Analog joystick, preserving saved layout geometry. Layout 211 + 72 synthetic and graphical menus 502 checks pass; compact screenshot inspected. Quick Android export/install/launch succeed; physical touch acceptance pending. See docs/ANALOG_STEERING_MENU.md.

2026-09-25 R01/V03/V05/Q01: Settings adds saved Off/Light/Medium/Strong steering haptics with preview. Menu 26, records 53, layout 199 + 72 synthetic and graphical menus 493 checks pass; compact evidence inspected. Android quick export/install/launch succeed; physical feel pending. See docs/STEERING_HAPTICS.md.

2026-09-25 R01/V03/V05/Q01: subtle steering-touch haptics (12 ms, amplitude 0.2), handheld adapter and Android vibration permission. Mobile input 555, layout 199 plus 72 synthetic checks and quick Android export pass; APK installed on attached phone. Physical haptic feel remains owner acceptance. See docs/STEERING_HAPTICS.md.

2026-09-25 V02/V04/V05/Q01: physical DN2103 winter profiling found bank-query overhead; presentation-only optimisation cuts stress particle CPU mean 21.3% and p99 29.7%, retaining 25 bank bursts. Final two-minute drive median 16.812 ms; actual-present window median 16.838/p99 17.057 ms. CaptureWinter 156 and quick export checks pass; APK installed, diagnostics removed, normal play restored. See docs/WINTER_PHONE_PERFORMANCE.md.

2026-09-25 V02/V04/V05/Q01: winter-spray-3 removes ice-drift tyre powder and replaces bank cloud billboards with immediate directional snow fragments. CaptureWinter 156 and TestSoil 163 checks pass; desktop evidence inspected. No device test/export. See docs/WINTER_TYRE_EFFECTS.md.

2026-09-25 V02/V04/V05/Q01: winter-spray-2 uses off-track snow chips during ice drift and a short 0.42-second burst at the swept body/bank contact. CaptureWinter 153, TestSoil 163 and TestIce 69 checks pass. Desktop captures inspected; no phone test/export. See docs/WINTER_TYRE_EFFECTS.md.

2026-09-24 V02/V04/V05/Q01: kit 78 adapts desert worn/translucent finish checkers to winter frost-white and slate-blue pigments. CaptureWinter 143 and TestDesert 53 checks pass; desktop screenshot inspected. No phone test/export. See docs/WINTER_SURFACES.md.

2026-09-24 V02/V04/V05/Q01: winter-specific ice scuffs, loose/packed snow ruts, slush wakes, tyre chips/powder and pooled snowbank-impact clouds. CaptureWinter 138, TestSoil 163, TestIce 69 and TestDesert 53 checks pass; desktop effects evidence inspected. No phone test/export. See docs/WINTER_TYRE_EFFECTS.md.

2026-09-24 R01/G01/V03/V05/Q01: Play selection removes duplicate raster coverage work and improves four-track LRU/cache supersession. Final desktop cold selection 510→375 ms (Speedy), 601→481 ms (Knot); attached DN2103 cold 691/874 ms, cached 36 ms. Compiler equivalence 27, menu loading 19, road pieces 362 and quick Android checks pass; APK installed and normal play restored. Older free-editor UI assertion still fails. Race hitch remains unconfirmed. See docs/MENU_SELECTION_2026_09_24.md.

2026-09-24 V02/V04/V05/Q01: kit 77 restores a faint blue tint to the pale winter road, retaining subdued texture. CaptureWinter 11 checks pass; desktop driving screenshot inspected. No phone test/export. See docs/WINTER_SURFACES.md.

2026-09-24 V02/V04/V05/Q01: kit 76 shifts winter roads from blue to pale neutral icy white using luminance-only artwork detail. CaptureWinter 11 checks pass; desktop driving evidence inspected. No Android export/device test. See docs/WINTER_SURFACES.md.

2026-09-24 V02/V04/V05/Q01: kit 75 reduces winter road artwork contrast to 28%, adds varied piled-snow crowns and clustered outer deposits while retaining the smooth road toe. CaptureWinter 11, TestIce 69, TestSurfaces 50 pass; desktop evidence inspected. No phone test/export. See docs/WINTER_SURFACES.md.

2026-09-24 V02/V04/V05/Q01: kit 74 refines winter ice scale, replaces sawtooth road-piece banks with rounded analytic profiles and blends ice gradually into snow. CaptureWinter 10, TestIce 69 and TestSurfaces 50 checks pass; driving/hairpin screenshots inspected. No Android export/device test. See docs/WINTER_SURFACES.md.

2026-09-24 Q01/V05/G01: investigating owner-reported race-start freeze. Added full-start desktop diagnostic; Speedy desktop and attached DN2103 runs did not establish a repeatable five-second hitch. No gameplay fix claimed. Phone maximum 31.564 ms in measured driving window; normal play restored. See docs/RACE_START_HITCH.md for commands, evidence and reproduction limits.

2026-09-24 V02/V04/V05/Q01: visual kit 73 adds original directional winter ice, detailed snow ground and irregular batched snowbank clumps; removes winter edge stripes. Ice 69, surfaces 50, shader profile 928 and final winter capture 11 checks pass. Desktop driving/hairpin evidence inspected. No Android export/device test. See docs/WINTER_SURFACES.md.

2026-09-24 V02/V04/V05/Q01: owner headlight tuning sets range to 20.4 model metres (1.7x) and narrows cone from 48 to 42 degrees, retaining hood clearance. CaptureHeadlights 56 and quick export checks pass. Installed/tested on DN2103: 160.5 m, median 16.722 ms/p95 20.449 ms; desktop/phone evidence inspected, normal play restored. See docs/NIGHT_HEADLIGHTS.md.

2026-09-24 V02/V04/V05/Q01: corrected headlight hood spill by moving the source ahead of the nose, raising/widening its road footprint and shortening range to 12 model metres. CaptureHeadlights 56 and quick Android export checks pass. Updated APK tested on DN2103: 160.1 m driven, median 16.739 ms/p95 20.506 ms; desktop/phone screenshots inspected and normal play restored. See docs/NIGHT_HEADLIGHTS.md.

2026-09-24 V02/V04/V05/Q01: faint night rear lamps reuse emissive brake materials; braking brightens them and release restores running glow. Kart gains two batched rear lenses; no added dynamic lights. CaptureHeadlights 51, vehicle batch 35 and quick export checks pass. Installed/tested on DN2103: 213.6 m, median 16.785 ms/p95 20.511 ms. Desktop running/braking and phone captures inspected; normal play restored. See docs/NIGHT_HEADLIGHTS.md.

2026-09-24 V02/V04/V05/Q01: night headlight cone begins wider at the bumper using a recessed virtual origin and softer angular falloff, retaining one shadow-free light. Final CaptureHeadlights 31 and quick export driving/catalog/menu checks pass; desktop comparison inspected. Revised APK installed/tested on DN2103: on medians 16.732/16.789 ms, off 16.760 ms; no material difference. Phone evidence inspected, normal play restored. See docs/NIGHT_HEADLIGHTS.md.

2026-09-24 V02/V04/V05/Q01: night headlights use one bounded shadow-free spotlight and batched illuminated lenses across five vehicles. Headlights 31 headless/31 graphical, biomes 107, vehicle batching 35 and quick Android export checks pass. Installed/tested on DN2103: moving on 16.659/16.682 ms median versus off 16.779 ms; p95 20.11-20.51 ms. Initial paused sample excluded. Screenshots inspected, normal play restored; no thermal-soak/fleet acceptance. See docs/NIGHT_HEADLIGHTS.md.

2026-09-24 R01/V03/V05: Create biome cards use one image-independent selected treatment: full-bright artwork and a square yellow label band; unselected artwork is uniformly subdued, with no selected outer-border highlight. CaptureBiomes passes 107 checks and desktop evidence was inspected. No phone test/export. See docs/BIOME_CREATION.md.

2026-09-24 R01/V03/V05/Q01: Race Complete Next Tracks cards show saved local star ratings and vote counts, matching Play. CaptureResults passes 204 checks across three sizes; desktop evidence inspected. No phone test/export. See docs/TRACK_RATINGS.md.

2026-09-24 V02/V04/V05/Q01: desert-bridge-2 fixes recessed-looking railing caps with flat face normals and narrower stone bevels. CaptureDesertBridge passes; desktop evidence inspected, collision/clearance assertions pass. No phone test/export. See docs/DESERT_BRIDGES.md.

2026-09-24 V02/V04/V05/Q01: grass-clippings-2 replaces bright box debris with folded tapered blades, natural lit colours and low two-axis tumbling; capacity reduced 20%. Soil 163, graphical soil 172, desert 53 and graphical grass 32 checks pass. Desktop evidence inspected; no device test/export. See docs/GRASS_CLIPPINGS.md.

2026-09-24 V02/V04/V05/Q01: desert-bridge-1 replaces desert steel rails with sandstone parapets, bevelled coping, capped posts and clearance-preserving shallow arches. Construction 82, bridge contacts 16 and desert 53 checks pass; two desktop captures inspected. No phone test/export. See docs/DESERT_BRIDGES.md.

2026-09-24 V02/V04/V05/Q01: desert road-edge kerb cells now select sand trails/dust instead of dark rubber/smoke. Saved-track CaptureDesert 79 and TestSoil 163 checks pass; desktop capture inspected. No phone test/export. See docs/DESERT_OFF_TRACK.md.

2026-09-24 V02/V04/V05/Q01: desert-dust-9 fixes green off-track tyre marks and grass clippings with sandy grooves, low tan grain spray and lingering dust. CaptureDesert 67 and TestSoil 163 checks pass; two desktop captures inspected. No phone test/export or performance measurement. See docs/DESERT_OFF_TRACK.md.

2026-09-24 V02/V04/V05/Q01: vehicle shells now have opaque black underside caps; kart floor is black. TestVehicleBatch: 35 checks pass; all five inverted desktop captures inspected. No phone test/export. See docs/VEHICLE_UNDERSIDES.md.

2026-09-24 V02/V04/V05/Q01: kit 72 enlarges desert finish checker pitch 29%, cools the sand pigments and adds patchy abrasion/eroded edges after owner rejection of kit 71. Final CaptureDesert: 61 checks pass, desktop evidence inspected. No phone test/export. See docs/DESERT_START_FINISH.md.

2026-09-24 V02/V04/V05/Q01: kit 71 uses two rows of translucent, grain-worn sand finish checkers. CaptureDesert: 61 checks pass; desktop screenshot inspected. No phone test/export. See docs/DESERT_START_FINISH.md.

2026-09-24 V02/V04/V05/Q01: visual kit 70 follows the owner's in-game reference with a faded, low-contrast three-row sand checker and worn exposed-sand edges. See docs/DESERT_START_FINISH.md.

2026-09-24 V02/V04/V05/Q01: desert-dust-8 gives each particle a stable randomized 10-14 degrees/s birth speed, slowing with growth to 2.6-3.64 degrees/s for mature clouds. CaptureDesert 61 and Android quick export pass; APK installed, no phone driving/profile test. See docs/DESERT_DUST.md.

2026-09-24 R01/V03/V05/Q01: configurable touch layout editor, three steering methods, independent analog pedals, presets/reset, safe normalized geometry and atomic settings. 199 headless / 202 graphical layout checks (plus 72 synthetic viewport checks), 555 mobile-input and 53 record checks pass; final Android quick export passes and APK installed. Phone attached but locked; no physical multitouch/iOS test. Older TestApp stops on obsolete menu-button assumptions. See docs/TOUCH_CONTROL_LAYOUT.md.

2026-09-24 V02/V04/V05/Q01: visual kit 69 replaces the rejected filled Desert checker with an actual sand drawing: irregular raked grid grooves, diagonal stick marks and displaced sunlit ridges. See docs/DESERT_START_FINISH.md.

2026-09-24 V02/V04/V05/Q01: desert-dust-7 corrects angular-curve radian units and uses stronger size-dependent slowing (calculated mature maximum ~0.27 degrees/s). CaptureDesert 61 and quick Android export pass; APK installed on DN2103, no phone motion/profile test. See docs/DESERT_DUST.md.

2026-09-24 V02/V04/V05/Q01: visual kit 68 gives Desert a weathered sand-chalk/ochre start-finish marking with exposed packed-sand seams; other biomes and timing geometry remain unchanged. See docs/DESERT_START_FINISH.md.

2026-09-24 V02/V04/V05/Q01: desert-dust-6 slows cloud rotation with inverse growth: at most 12 degrees/s initially, about 3.1 degrees/s for mature clouds. CaptureDesert 57 and Android quick export pass; APK installed, no phone driving/profiling. See docs/DESERT_DUST.md.

2026-09-24 V02/V04/V05/Q01: desert-dust-4 brings cloud onset to the car: peak opacity at 0.108 s, earlier growth, stronger tyre puffs and narrower soft-intersection fade. Counts unchanged. CaptureDesert 57, soil 163 and quick Android export pass; APK installed, no phone driving/profiling. See docs/DESERT_DUST.md.

2026-09-24 V02/V04/V05/Q01: desert-dust-3 responds to owner rally-dust reference with a connected occluding beige plume, 256 lingering particles, stronger sustained density and soft depth intersections. CaptureDesert 55, soil 163 and Android quick export pass; APK installed. Phone remains locked; no performance measurement. See docs/DESERT_DUST.md.

2026-09-24 R01/T01-T04/V03/V05: creator Road palette adds asymmetric Taper pieces with one straight verge, a converging opposite verge, Flip side selection, direct wide/narrow/length controls, snapping, automatic-route widths and creator-track-v5 persistence. Focused road/workflow/capture checks pass; desktop evidence inspected. No phone test/export. See docs/ROAD_TAPERS.md.

2026-09-24 V02/V04/V05/Q01: desert-dust-2 splits short tyre puffs from 384 bounded lingering particles, softens shading and enables texture mipmaps. Final CaptureDesert 55, soil 163 and Android quick checks pass; final APK installed on DN2103. Phone profiling obtained no measurements while locked. See docs/DESERT_DUST.md for evidence and acceptance.

2026-09-24 V02/V04/V05/Q01: kit 67 replaces fine desert road-edge breakup with broader approximately 5.6 m variation, constrained to existing blend strip endpoints. CaptureDesert 53 and quick Android export checks pass; gameplay capture inspected. See docs/DESERT_EDGE_VARIATION.md.

2026-09-24 V02/V04/V05/Q01: kit 66 warms/darkens desert road pigment toward surrounding sand, extends shoulder blending 0.91 m farther inward and raises inner-bend clods 65%. CaptureDesert 53, TestSurfaces 50 and quick Android export checks pass. Desktop capture inspected. See docs/DESERT_COLOUR_HEIGHT.md.

2026-09-24 V02/V04/V05/Q01: kit 65 replaces continuous raised desert ribbons with flat original sandy-apron artwork and clustered independent sand clods in the shoulder batch. Three gameplay views captured; 809 clods/14,562 triangles on saved desert track. CaptureDesert 53, TestSurfaces 50 and corrected TestSurfaceProfile 928 checks pass. DN2103 installed/tested: repeated production median ~17.35 ms/p95 ~29 ms; particles-disabled 16.85/20.15 ms, initial run slower. Normal play restored. No old/new cost comparison. See docs/DESERT_APRON.md.

2026-09-24 V02/V04/V05/Q01: kit 64 tapers berm height over 3 m at actual curved-run boundaries, reduces coarse rib shading and broadens irregular outer shoulder blending. Approved directional road material retained. CaptureDesert 50 checks pass; screenshot inspected. See docs/DESERT_TAPER.md.

2026-09-24 V02/V04/V05/Q01: kit 63 restores the owner-preferred curve-bank pattern, leaves straight shoulders flat/darker and maps compacted road grain along/across each road piece. Bounded road subdivision avoids warped interpolation through bends. CaptureDesert 50 checks pass; gameplay evidence inspected. See docs/DESERT_DIRECTIONAL.md.

2026-09-24 V02/V04/V05/Q01: kit 62 replaces corrugated desert banks with a broader four-band transition: worn contact, low deposited sand ridge and loose grit into dunes. Road-edge blending widens to 0.56 m; shoulder width 1.8-2.4 m. CaptureDesert 50 and TestSurfaces 50 pass; screenshot inspected. See docs/DESERT_TRANSITION.md.

2026-09-24 V02/V04/V05/Q01: kit 61 replaces visible desert creator kerbs with low irregular sand banks, softens straight shoulders and adds road-axis filtered wear. CaptureDesert 50 and TestSurfaces 50 checks pass. Desktop evidence inspected; see docs/DESERT_BERMS.md for scope and device limits.

2026-09-24 V02/V04/V05/Q01: kit 60 restores a distinct rough gravel shoulder between desert road and dunes, including behind stone kerbs, and strengthens baked road grain/wear. CaptureDesert 50 and TestSurfaces 50 checks pass. Gameplay screenshot inspected. See docs/DESERT_SHOULDERS.md.

2026-09-24 V02/V04/V05/Q01: kit 59 gives desert roads muted compacted sand/gravel, sandstone kerbs and no white edge stripes. Normal daylight supersedes the sunset request; dune pigment is retuned for daylight. Saved-track CaptureDesert 50, TestSurfaces 50 and TestBiomes 92 pass; Android quick export passes 74 driving, 18 catalog and 22 menu checks. Desktop screenshot inspected. See docs/DESERT_DAYLIGHT.md for device status and acceptance.

2026-09-24 V02/V04/V05/Q01: kit 58 adds original dune/ripple sand artwork, baked slope lighting and sparse opaque dry scrub for desert ground. Roads, sunset, dust, camera and canonical handling remain unchanged. Desert 31, saved-track capture 52, surfaces 50, grass 15, biomes 92 and shader profile 928 checks pass. Desktop screenshots inspected; fresh Android APK exported and installed. DN2103 was locked, so phone profile timed out with 0/5 stages; diagnostics cleaned up, performance acceptance pending. See docs/DESERT_DUNES.md.

2026-09-23 V02/V04/V05/Q01: kit 57 adds original meadow blade/clump artwork and shaded opaque tufts instead of restoring old leafy grass. Fresh APK installed on DN2103; 18 comparison stages completed. Ajorata median unchanged; repeated Storm +0.20?0.24 ms (1.2?1.4%), lower p95. First Storm pass showed device-wide slowdown affecting original grass too; all results retained. Desktop/device evidence and acceptance limits: docs/GRASS_PERFORMANCE.md.

2026-09-23 V02/V04/V05/Q01: owner rejected plain hybrid grass. Kit 56 restores original painted vegetation detail, greatly reduces broad blotches and matches tuft colour to the ground. CaptureGrass 17, TestGrass 15 and TestSurfaces 50 checks pass; revised gameplay screenshot inspected. No phone test/deployment/profiling. See docs/HYBRID_GRASS.md.

2026-09-23 V02/V04/V05/Q01: grass-only hybrid material uses baked macro/albedo/normal maps and five opaque clustered MultiMesh tuft variants. Visual kit 55; 2,270 tuft origins in captured driving view. Grass 15/17 headless/graphical, surface 50, desert 24, biome 92 and shader-probe 928 checks pass. Desktop screenshots inspected. Phone attached; no device test/export/profiling. See docs/HYBRID_GRASS.md.

2026-09-23 R01/R03/V03/V05/Q01: Results Sectors route and table colours now encode each sector's time delta against the fastest valid lap (green gain, grey match, orange loss); transverse outlined lines mark every sector end. 185 headless and 204 graphical checks pass; three responsive captures refreshed and desktop capture inspected. No phone test/export. See docs/RACE_RESULTS.md.

2026-09-23 R01/V03/V05/Q01: rating stars centered on both axes; saved stars and score remain visible for 0.7 s, then finish cues fade over 0.4 s before Results. Confirmation blocks duplicate input. 198 graphical Results checks pass; desktop capture inspected. No phone test/export. See docs/TRACK_RATINGS.md.

2026-09-23 R01/V03/V05/Q01: Play track cards show saved personal rating and actual local vote count (0/1). 490 graphical menu checks pass across three sizes; desktop/compact captures inspected. Shared aggregate ratings remain unconnected; no phone test/export. See docs/TRACK_RATINGS.md.

2026-09-23 R01/V03/V05/Q01: owner correction moves delayed rating directly beneath the on-track Race Complete sign in black/gold styling; removes Results popup. Unrated finish waits for stars/Skip, rated tracks retain automatic transition. 184 graphical Results and 49 practice checks pass; existing two practice shutdown ObjectDB warnings. Corrected desktop capture inspected; no phone test/export. See docs/TRACK_RATINGS.md.

2026-09-23 R01/V03/V05/Q01: delayed skippable personal track rating after finish; atomic persistence suppresses rated tracks and editable stars sit beneath standings. 164 headless Results, 179 graphical Results and 53 record checks pass; desktop captures inspected. No phone test/export. See docs/TRACK_RATINGS.md.

2026-09-23 V03/V05: redrawn trash bin and explicit horizontal/vertical centering in square Delete button. CaptureTyresLoad: 68 checks pass; desktop capture inspected. No phone test/export. See docs/DRAFT_BROWSER.md.

2026-09-23 R01/T01-T04/V03/V05/Q01: selected-draft bottom actions, square Delete, grey gated Publish, one ordered untimed test lap, edit-invalidated Tested status and local publication/edit lock. 68 load/workflow, 49 practice and 92 biome checks pass; two practice shutdown ObjectDB warnings remain. Desktop captures inspected; no phone test/export. See docs/DRAFT_BROWSER.md.

2026-09-23 R01/T01-T04/V03/V05/Q01: Load track opens a scenic editing gallery with newest saved/autosaved versions, last-save metadata, search/pages, Continue editing and confirmed deletion. 44 load/tyre, 92 biome and 22 menu checks pass; desktop capture inspected. No phone test/export. See docs/DRAFT_BROWSER.md.

2026-09-23 R01/V03/V05/Q01: stacked incident legend with route exclusion gutter; laurel leaves connect to exact stem geometry and PB time is centered. 154 headless / 168 graphical checks pass; desktop evidence inspected. No phone test/export. See docs/RACE_RESULTS.md.

2026-09-23 R01/V03/V05: small biome icons recreated to follow supplied Create reference shapes/colour, with lightning added to Storm. CaptureBiomes passes 92 checks; enlarged and menu evidence inspected. No phone test/export. See docs/BIOME_CREATION.md.

2026-09-23 R01/V03/V05: replaced rejected biome line icons with filled leaf/cactus/moon-cloud/lightning-cloud silhouettes and mathematically symmetric Winter branches. Enlarged and menu captures inspected; CaptureBiomes passes 92 checks. No phone test/export. See docs/BIOME_CREATION.md.

2026-09-23 R01/T01-T04/V03/V05: Create biome selection gains five refined biome icons, selected border, descriptive bottom card, explicit yellow Create track action and upper-right Load track action to Saved tracks; heading is “Select biome.” 92 biome checks pass; refreshed desktop capture inspected. No phone test/export. See docs/BIOME_CREATION.md.

2026-09-23 R01/V03/V05/Q01: Play retains its shared 20 px bottom inset while restoring natural 8 px row spacing; smaller gallery cards, title footer and title type provide the vertical room. Both script checks and CaptureMenus (454 checks at three sizes) pass; desktop and compact evidence inspected. No phone test/export. See docs/PLAY_PAGE.md.

2026-09-23 R01/V03/V05/Q01: removed Play More menu and made Favorites use the track-card star icon in track_browser.gd. CaptureMenus passes 454 checks across three sizes; screenshot inspected. No phone test/export. See docs/PLAY_PAGE.md.

2026-09-23 V03/V05/Q01: Surprise me dice redrawn as a shaded, outlined three-face cube in menu_icon.gd. CaptureMenus passes 466 checks across three sizes; refreshed desktop evidence inspected. No phone test/export. See docs/PLAY_PAGE.md.

2026-09-23 R01/V03/V05/Q01: Play reference update adds filter icons, bottom dice/Surprise me and Home/Race actions, scenic selected-track panel, stacked records and side-by-side WHERE YOU STAND comparisons; removes Play edit/delete/remix actions. 22 menu and 466 graphical checks pass across three sizes. Desktop evidence inspected; no phone test/export. See docs/PLAY_PAGE.md.

2026-09-23 R01/V03/V05/Q01: Results back button uses an original thin yellow left arrow at the far left edge, with centered RESULTS text, matching the supplied action reference. Changed race_complete.gd and results_icons.gd; CaptureResults via scripts/dev.ps1 passed 163 checks and refreshed three-size evidence. Desktop screenshot inspected; no phone test/export.

2026-09-23 R01/V03/V05/Q01: Race Complete top-right home icon opens Main Menu; bottom-left < RESULTS returns to analysis; Tracks adds circuit icon. 163 graphical checks pass; desktop capture inspected. No phone test/export. See docs/RACE_RESULTS.md.

2026-09-23 R01/V03/V05/Q01: rewards show eligible rows only with sequential slide/fade, gold border accents and running total count-up. 149 headless / 163 graphical checks pass; desktop evidence inspected. No phone test/export. See docs/RACE_RESULTS.md.

2026-09-23 R01/V03/V05/Q01: Race Complete replaces placeholder with provisional rewards, real measured times and local next-track selection. Consistency omitted; clean requires no collision/off-track incidents. Percentile model rewards only new higher tiers; unavailable standings/history/challenges remain explicit, no wallet writes. 144 headless / 157 graphical checks pass; three-size evidence saved, desktop inspected. No phone test/export. See docs/RACE_RESULTS.md.

2026-09-23 R01/V03/V05/Q01: Results adds PB laurels, wider equal icon buttons, measured sector table, KPI icons/dividers and larger lap times. 127 headless / 138 graphical checks pass; refreshed desktop screenshot inspected. No phone test/export. See docs/RACE_RESULTS.md.

2026-09-23 R01/V03/V05/Q01: simplified Results to Race Again / Continue, shorter time panel, yellow right-side PB, taller lap rows and expanded analysis ordered Sectors / Time diff / Speed. Continue opens recommendations/rewards placeholder with results/library navigation. 120 headless, 131 graphical and 22 menu checks pass; desktop evidence inspected. No phone test/export. See docs/RACE_RESULTS.md.

2026-09-22 V03/V05/Q01: removed residual cumulative start-light scaling error. Source-boundary-derived centres map through the exact padded-crop scale, giving equal bezel clearance through the rightmost red lamp. 71 graphical checks pass; full-resolution capture inspected. No phone test/profiling.

2026-09-22 V03/V05/Q01: final start-light correction restores source-measured right/bottom gantry bounds with transparent padding and refines right-lamp centres. Both end tabs, lower trim and all five centred lenses are visible. 71 graphical checks pass; full-resolution capture inspected. One draw, ~159 KB atlas; no phone test/profiling.

2026-09-22 V03/V05/Q01: corrected remaining start-light lens drift exposed by owner device screenshot. Five independently measured overlay centres now align every red lens with its fixed bezel, including end housing. 71 graphical checks pass; full-resolution all-red capture inspected. No phone test or profiling.

2026-09-22 V03/V05/R01/Q01: owner-supplied 1024×341 race-complete panel replaces the procedural 120-cell waving flag. One canvas draw, capped responsive size, guarded touch/mouse continue and unchanged 1.8 s automatic fallback. 48 headless / 71 graphical checks pass; desktop capture inspected. No phone test or profiling. See docs/RACE_FLOW.md.

2026-09-22 V02/V04/V05/Q01: reference correction gives desert rust-red earth/amber light and much wider shaded dust billows; visual kit 54. Desert 24, soil 163 and graphical capture 25 checks pass. Refreshed desktop evidence inspected; no phone test/profiling. [Details](docs/DESERT_SUNSET.md).

2026-09-22 V03/V05/Q01: fixed supplied start-light atlas overlap seen in owner capture. All stages now retain one identical gantry and replace only aligned circular lens pixels; duplicate/offset housings are removed. Atlas reduced to ~146 KB; 69 graphical checks pass and refreshed captures inspected. No phone test or profiling.

2026-09-22 G01/V03/V05/Q01: owner-supplied start-light artwork replaces procedural lamps, normalized to the supplied green housing geometry. Six stages are a single 193 KB transparent atlas and one canvas draw; countdown/rules are unchanged. 46 headless and 69 graphical practice checks pass; desktop captures inspected. No Android export, phone test or device profiling. See docs/RACE_FLOW.md.

2026-09-22 G01/G03/R01/R03/R07/V02/V04/V05/Q01: desert firm-sand roads, dense nine-second dust and low red-orange sunset. Physics 0.39 / compiler 19 / visual kit 53. Focused behavior, creator, track, biome and soil checks pass; desktop captures saved. Full validation stopped on now-updated creator expectations; remaining chain and phone acceptance not completed. See [details](docs/DESERT_SUNSET.md).

2026-09-22 R01/V03/V05: Create biome cards now reuse the Tracks gallery scenery, with biome labels overlaid near the bottom and a thin artwork strip retained beneath; removed the permanence explanation. 62 biome checks pass and the refreshed desktop capture was inspected. No phone test or export.

2026-09-22 R03/R07/G01/V03/V05/Q01: rules v12 adds up to 6 m outside bend recovery; missed-checkpoint labels simplified, translucent road-only line plus faint removable acceptance margins. 122 checkpoint, 27 start-line, 167 track/replay, 53 record and 14 graphical checks pass. Desktop evidence inspected; no phone test/export. See docs/MOBILE_OPTIMIZATION_2026_09_22.md (Outside recovery and marker clarity).

2026-09-22 V02/V04/V05/Q01/R01: clearer dynamic side-window reflections, matching rear wraparound bumper and recessed rim barrels/spokes. 30 batching and 114 quick checks pass; updated APK installed/launched on DN2103. No profiling. [Evidence and limits](docs/WINDOW_REFLECTIONS.md#side-reflections-matching-rear-bumper-and-rim-depth---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: simple world-fixed sky/cloud reflections on compact glass respond to viewing angle and vehicle rotation. 30 batching and 114 deployment quick checks pass; APK installed/launched on DN2103, visible startup verified. Owner will test; no profiling performed as requested. [Evidence and limits](docs/WINDOW_REFLECTIONS.md).

2026-09-22 V02/V04/V05/Q01/R01: front bumper now continuous dark rubber with rounded corner/side returns; grey top strip removed, twin headlights retained. Six desktop views captured; 30 batching checks pass. No phone test. [Evidence](docs/COMPACT_LOOK.md#dark-wraparound-front-bumper---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: reference-led roof perimeter crease and tapered/rounded rear quarter windows with slim light surrounds. Six desktop captures saved; 30 batching checks pass. No phone test. [Evidence](docs/COMPACT_LOOK.md#reference-roof-edge-and-rear-quarter-windows---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: glass boundaries now curve visibly from overhead and front bumper projects farther with a taller face/top edge. Six desktop views including high rear captured; 30 batching checks pass. No phone test. [Evidence](docs/COMPACT_LOOK.md#visible-glass-curvature-and-front-bumper---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: compact loses black sill shell, gains deeper nose curve, rounded glazing/crowned windshield and faint roof pressings. 30 batching checks pass; desktop front/side captures inspected. No phone test. [Evidence and limits](docs/COMPACT_LOOK.md#rounded-glazing-nose-and-roof-detail---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: reduced compact front-fender lateral projection by 35% from its body attachment; rear fenders and wheels retained. 30 batching checks pass; updated capture inspected. No phone test. [Evidence](docs/COMPACT_LOOK.md#front-flare-projection-reduced-35-percent---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: compact nose gains a shallow curve across fascia/grille/bumper and twin round headlights per side matching owner menu reference. 30 batching checks pass; refreshed desktop captures inspected. No phone test. [Evidence and limits](docs/COMPACT_LOOK.md#curved-nose-and-twin-lamps---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: compact side cleanup removes block mirrors, redundant black strips and open-panel ink artifacts; tapered seams and broad silver-blue fender highlights improve reference fidelity. Both side captures inspected; 30 batching checks pass. No phone test. [Evidence and limits](docs/COMPACT_LOOK.md#side-cleanup-and-fender-highlights---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: compact front correction integrates grille into a solid fascia, shapes the bonnet and replaces detached arch strips with charcoal flares blending into painted fenders. 30 batching checks pass; refreshed desktop captures. No phone test. [Evidence and limits](docs/COMPACT_LOOK.md#front-hood-and-fender-correction---2026-09-22).

2026-09-22 V02/V04/V05/Q01/R01: owner-reference compact model gains rounded/wider tyres, recessed alloys, sculpted arches, layered lamps, dark glazing and body trim. 30 batching and 28 suspension checks pass; before/after desktop captures saved. No phone test. [Details and acceptance](docs/COMPACT_LOOK.md).

2026-09-22 R01/R03/V03/V05/Q01: pausing and shortcut history no longer invalidate an otherwise completed race, its local record, or completed-lap telemetry. Genuine editor practice remains unranked. The TOTAL RACE TIME card now contains only the total and personal best. 120 headless Results, 130 graphical Results and 22 menu checks pass; refreshed desktop capture inspected. No phone test or export. See docs/RACE_RESULTS.md.

2026-09-22 V03/V05/R01: removed the waypoint/checkpoint marker from the minimap while retaining the player marker, world missed-gate marker and return notice. 7 checkpoint-capture and 153 bridge/HUD checks pass; refreshed desktop capture inspected. No phone test. [Details and evidence](docs/MINIMAP_WAYPOINT_MARKER.md).

2026-09-22 G01/G03/R01/R03/R07/V01/Q01: off-road terrain steering texture is slightly stronger while remaining deterministic, contact/speed-scaled and bounded; continuous camera rumble uses a lower-frequency presentation profile without changing collision shake. Physics 0.38. Camera (7), soil (163), driving (74) and handling (88) checks pass; kart handling passes 32 checks, while its chained car-model suite retains four pre-existing visual-model failures. No phone test. See docs/OFF_TRACK_HANDLING.md and docs/CAMERA_SHAKE.md.

2026-09-22 V03/V05/Q01/RR02/RR05: Results sector leader lines stop at label edges, sector labels avoid the incident legend, and its wording is shortened to “Off track.” 116 headless and 126 graphical checks pass across three sizes; refreshed 1280x720 capture inspected. No phone test or export. See [details](docs/RACE_RESULTS.md#sector-leader-clearance--2026-09-22).

2026-09-22 V02/V04/V05/Q01: restored creator bridge asphalt by binding the shared baked surface texture. 157 graphical bridge/HUD checks pass; desktop screenshot inspected. No device test. See docs/MOBILE_OPTIMIZATION_2026_09_22.md, Bridge texture restoration.

2026-09-22 R03/R07/G01/V03/Q01: owner-requested checkpoint forgiveness adds up to 3 m inside gentle curves, tapering away on tighter bends; visible line matches asymmetric acceptance. Rules v11; 108 checkpoint checks pass including hairpin shortcuts. [Details and evidence](docs/MOBILE_OPTIMIZATION_2026_09_22.md#inside-recovery-allowance--2026-09-22-follow-up).

2026-09-22 R01/R03/R07/G01/V02/V03/V04/V05/Q01: baked road/sand detail, removed random cracks, reduced directional shadows and replaced route-history searches with ordered road gates. Owner follow-up reduces gate density to approximately 12 m and smooths bend normals. Missed sections require return; no +5s penalty. Rules v10 / compiler 18 / visual kit 52. See [actual tests, phone comparisons and acceptance](docs/MOBILE_OPTIMIZATION_2026_09_22.md).

2026-09-22 R01/R03/V03/V05/Q01/RR02: Results maps show collision crosses and all-four-tyres-off-track diamonds. 104 headless / 114 graphical checks pass; screenshot saved. No phone test or export. See [details](docs/RACE_RESULTS.md#incident-markers--2026-09-22).

2026-09-22 R01/R03/R07/V02/V04/V05/Q01: owner-suspected surface regression confirmed on DN2103. Alternating current/older shared asphalt detail saves 3.490 ms on Ajorata and 5.614 ms on Storm; directional grain costs 1.505 ms on dry Ajorata. Flat terrain/shoulder colouring saves 3.510/8.959 ms, with weather/shadows retained. Eighteen phone stages and 928 graphical uniform/geometry/restoration checks completed. Normal production visuals restored; no quality reduction shipped. [Evidence, interpretation and limits](docs/SURFACE_PERFORMANCE_2026_09_22.md).

2026-09-22 R01/R03/R07/G01/V03/V05/Q01: physical DN2103 feature profiling separates route timing, Results telemetry, trails, particles, weather and presentation CPU costs. Eighteen phone stages completed: Storm weather off saves 7.406 ms median; shadows off saves 2.899/6.071 ms on Ajorata/Storm. Results recording averages only 0.032/0.039 ms per frame; route validation 1.787/2.097 ms. Focused export, 94 Results and 22 performance/glass checks pass. Normal play restored; no production quality reduction. [Report, raw measurements, commands and limitations](docs/PERFORMANCE_2026_09_22.md).

2026-09-21 V02/V04/V05/Q01/R01: ramp suspension follow-up retains pitch velocity through touchdown, blends into damped body motion and softens heave/pitch for diminishing rebounds. 141 graphical suspension and 16 bridge checks pass; animation saved, no phone test. [Evidence](docs/BRIDGE_COLLISIONS.md#damped-suspension-follow-up--2026-09-21).

2026-09-21 G01/G03/R01/R03/R07/V02/V04/V05/Q01: bridge underside collisions, per-span rail isolation and exact ramp-end layer transitions fix Knit phantom contacts; bounded crest unloading and stronger suspension improve ramp motion. Physics 0.37, creator compiler 17. Focused checks and desktop captures pass; no phone test. [Implementation, commands and acceptance](docs/BRIDGE_COLLISIONS.md).

2026-09-21 R01/R03/G01/V03/V05/Q01: bounded saturated-glass overflow fixes a potential collision freeze; retained HUD geometry, inactive-emitter gating and early trail rejection reduce presentation CPU work. 9 glass, 13 performance, 160 soil, 555 touch and 157 graphical HUD checks pass. Physical DN2103 before/after: Ajorata median 20.806 to 19.943 ms; Storm 25.999 to 24.841 ms, still below 60 FPS. Optimized APK installed and normal play restored. [Evidence and limits](docs/PERFORMANCE_2026_09_21.md).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-51 makes white edge-line wear clearly visible with stronger fading and more frequent/deeper asphalt chips while preserving continuous readability. 390 checks and desktop captures pass. No phone test. [Evidence](docs/ROAD_REALISM.md#stronger-marking-wear---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-50 adds mild fading and sparse asphalt-coloured chips to white creator-road edge markings while retaining continuous readable lines. Focused checks and desktop captures pass. No phone test. [Evidence](docs/ROAD_REALISM.md#worn-white-edge-markings---2026-09-21).

2026-09-21 V03/V05/R01: tabular race/lap timer digits prevent width jitter; lap backing follows actual label bounds. 157 graphical HUD checks pass, capture saved. No phone test. [Evidence](docs/HUD_REFRESH.md#stable-timers-and-aligned-lap-backing--2026-09-21).

2026-09-21 V02/V03/V05/G01/R01: HUD follow-up adds soft translucent readout backings and depressed pedal geometry without active pedal highlights. 107 HUD and 555 touch checks pass; five-vehicle captures saved. No phone test. [Evidence](docs/HUD_REFRESH.md#subtle-backings-and-depressed-pedals--2026-09-21).

2026-09-21 G01/G03/R01/R03/R07/V05: sand now shares grass camera shake; both loose surfaces add small deterministic spatial steering disturbances alongside physical wheel drag. Physics 0.36; 381 focused checks pass, no phone test. [Details](docs/OFF_TRACK_HANDLING.md#loose-surface-shake-and-steering-texture---2026-09-21).

2026-09-21 V02/V03/V05/G01/R01/R03: owner-supplied HUD replacement with live lap/race clocks, circular placed-road minimap, semicircular speed gauge and supplied control artwork. 107 HUD, 555 touch, 33 practice and 114 quick-regression checks pass; desktop captures saved. No phone test. [Details and evidence](docs/HUD_REFRESH.md).

2026-09-21 R01/R03/V02/V03/V05/Q01: reference-led race results with completed-lap telemetry, interactive speed/time-diff/sector map, local next-race recommendations and navigation. Final graphical suite: 103 checks pass across 1280x720, 1920x1080 and 2400x1080. No phone test; older app navigation suite remains blocked before results. See [implementation, evidence and limits](docs/RACE_RESULTS.md).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-46 increases the accepted asphalt/sand fringe crossfade from ~5 cm to 10 cm without changing its shape or cutoff. 384 checks and desktop captures pass. No phone test. [Evidence](docs/ROAD_REALISM.md#10-cm-crossfade---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: accepted UV fringe shape retained; track-kit-45 adds a compact ~5 cm asphalt/sand crossfade for a smudged material transition. 334 checks and desktop captures pass. No phone test. [Evidence](docs/ROAD_REALISM.md#small-smudged-material-blend---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-44 replaces ineffective coarse-grid edge tuning with a continuous 0.20 m UV-controlled visual fringe along every exposed road edge. Width varies by a few pixels without curve stair-steps; white lines and physics remain unchanged. 384 checks and desktop captures pass. No phone test. [Evidence](docs/ROAD_REALISM.md#continuous-uv-edge-fringe-replacement---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-43 treats the owner-marked nearly smooth strip as baseline; transition width now varies continuously by only a few pixels, at 19% of the prior lobe amplitude. 334 checks and desktop captures pass. No phone test. [Evidence](docs/ROAD_REALISM.md#few-pixel-transition-width-correction---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: owner-marked target areas guide track-kit-42: filtered curve edges now use repeated shallow rounded lobes instead of nearly invisible fine noise, without restoring saw teeth. 334 checks and desktop captures pass. No phone test. [Evidence](docs/ROAD_REALISM.md#rounded-edge-lobe-correction---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: curve-edge refinement smooths the coarse mask staircase and changes breakup to smaller, more frequent, shallow variation. Track-kit-41; solid post-line asphalt and white markings retained. 334 checks and desktop captures pass. No phone test. [Evidence](docs/ROAD_REALISM.md#fine-curve-edge-correction---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: real-road-reference correction preserves a solid asphalt strip beyond the inset white line and confines reduced irregularity to the final asphalt/sand edge. Track-kit-40; 334 checks and desktop captures pass. No phone test. [Evidence](docs/ROAD_REALISM.md#real-road-edge-proportion-correction---2026-09-21).

2026-09-21 V02/V04/V05/Q01/R01: live-screenshot correction removes the smooth translucent verge ribbon. Track-kit-39 uses a real asphalt/sand coverage boundary shaped like the sand/grass fringe at half displacement, retaining white lines and joined geometry. 334 checks and desktop captures pass. No phone test. [Evidence](docs/ROAD_REALISM.md#coverage-shape-correction---2026-09-21).

2026-09-20 V02/V04/V05/Q01/R01: owner correction rejects the exaggerated verge. Track-kit-38 restores smooth white lines and continuous asphalt, leaving only a restrained outer-edge tint to slightly break mathematical smoothness. 334 checks and desktop captures pass. No phone test. [Evidence](docs/ROAD_REALISM.md#restrained-border-correction---2026-09-20).

2026-09-20 V02/V04/V05/Q01/R01: owner screenshot correction replaces hard asphalt teeth, join gaps and the white verge border with a narrow broken asphalt-to-sand material transition matching the sand/grass language. Track-kit-37; 384 checks and desktop captures pass. No phone test. [Evidence and limits](docs/ROAD_REALISM.md#natural-asphalt-to-sand-transition---2026-09-20).

2026-09-20 V02/V04/V05/Q01/R01: owner follow-up gives the cosmetic asphalt silhouette a denser, slightly sharper uneven edge than the sand/grass shoulder while preserving the smooth marking, collision and compiled road. Track-kit-35; 335 checks and desktop captures pass. No phone test. [Evidence and limits](docs/ROAD_REALISM.md#sharper-uneven-asphalt-contour---2026-09-20).

2026-09-20 V02/V04/V05/Q01/R01: reference-guided procedural road realism adds restrained world-space asphalt variation, deterministic repairs/sealed cracks and creator-road edge wear while retaining physics-driven four-wheel tyre marks. Track-kit-34; 662 focused checks pass and desktop captures succeed. No phone test. [Evidence and limits](docs/ROAD_REALISM.md).

2026-09-20 V01/V02/V04/Q01: persistent glass now accumulates independently on the collision-affected left/right/top/bottom edge. Damage spills to the least-fractured other edge only after the struck side is full; blended corner masks avoid seams. 8 focused checks pass; no phone test. [Details](docs/CAMERA_SHAKE.md#impact-glass-follow-up).

2026-09-20 V01/V02/V04/Q01: owner-reference persistent glass replaces the rejected fading starburst. An original transparent edge-shard texture accumulates with meaningful impacts, keeps the centre broadly clear and remains until restart/new race. 6 focused checks pass; no phone test. [Details](docs/CAMERA_SHAKE.md#impact-glass-follow-up).

2026-09-20 V01/V04/Q01: meaningful collisions now show a brief impulse-scaled branched glass fracture on the struck side; scrapes stay clean and the input-transparent overlay clears within 0.5 seconds or immediately on restart. 6 focused checks pass; no phone test. [Details](docs/CAMERA_SHAKE.md#impact-glass-follow-up).

2026-09-20 G01/R01/V01/V04/Q01: owner feedback replaces collision jitter with a directional resolved-impulse spring: sharp kick, small rebound and fast settlement. Off-track vibration is reduced to ~1.5 px, continuously blended and speed/resistance-scaled; HUD remains static. 6 camera, 167 track and 155 soil checks pass; no phone test. [Details](docs/CAMERA_SHAKE.md).

2026-09-20 G01/R01/V01/V04/Q01: collision camera shake scales from the resolved velocity impulse, while speed and loose-surface resistance drive a lighter continuous off-track rumble. Presentation-only bounded waves preserve canonical physics and framing. 5 camera, 167 track and 155 soil checks pass; no phone test. [Details](docs/CAMERA_SHAKE.md).

2026-09-20 V02/V04/V05: owner race screenshot identified 30 Hz emitter batching as the remaining asphalt-smoke gaps. Smoke now samples wheel motion at 120 Hz while other effects retain 30 Hz. 155 headless and 164 graphical checks pass; no phone profiling. [Details](docs/SAND_DUST.md#grass-and-asphalt-extension--2026-09-20).

2026-09-20 V02/V04/V05: asphalt smoke no longer reuses visible dust-puff silhouettes; a dedicated radial haze shader and 900 particles per wheel create a much more uniform continuous trail at lower opacity/cap. 154 headless and 163 graphical checks pass; no phone profiling. [Details](docs/SAND_DUST.md#grass-and-asphalt-extension--2026-09-20).

2026-09-20 V02/V04/V05: asphalt haze refined to 640 smaller particles per wheel at 0.055 peak alpha, lower 0.55 intensity cap and reduced expansion for a fainter, more continuous trail. [Details](docs/SAND_DUST.md#grass-and-asphalt-extension--2026-09-20).

2026-09-20 V02/V04/V05: grass overlay cards replaced by ballistic 3D blades/mud grains; asphalt smoke uses 420 smaller soft particles per wheel for a continuous ribbon instead of separated spots. 153 headless and 162 graphical checks pass; no phone profiling. [Details](docs/SAND_DUST.md#grass-and-asphalt-extension--2026-09-20).

2026-09-20 R01/V02/V04/V05/Q01: grass gains speed/slip-scaled clippings and rear mud flecks; dry asphalt gains modest thresholded smoke only under strong cornering/braking. 151 headless and 160 graphical checks pass; no phone profiling. [Evidence and limits](docs/SAND_DUST.md#grass-and-asphalt-extension--2026-09-20).

2026-09-20 V02/V04/V05: artificial/delayed dust cards replaced by an original authored billow sprite with useful opacity in ~0.13 seconds, visible tyre-level onset and rising clustered volume. 146 headless and 153 graphical checks pass; no phone test. [Details](docs/SAND_DUST.md).

2026-09-20 V02/V04/V05: removed immediate foreground dust override. New dust is tiny/transparent and depth-tested at exact tyre contact, then rises and expands until older clouds naturally cover the car. 145 headless and 152 graphical checks pass; no phone test. [Details](docs/SAND_DUST.md).

2026-09-20 V02/V04/V05: sand dust now originates at ground contact and slowly gains height through upward launch plus mild lift, instead of appearing at a fixed pre-suspended height. 145 headless and 151 graphical checks pass; no phone test. [Details](docs/SAND_DUST.md).

2026-09-20 V02/V04/V05: dust now composites over the opaque car, uses lighter sand colour, 360-particle wheel emitters, 2.05 m puffs, 5.2-second life and 3.65x expansion for a substantially larger/denser plume. 143 headless and 149 graphical checks pass; no phone performance test. [Details](docs/SAND_DUST.md).

2026-09-20 V02/V04/V05: rejected flat sand streaks replaced by dense camera-facing dust volume with 4.8-second persistence, surface/car-obscuring overlap, independent rotation/deceleration and a dedicated progressive slip response. 142 headless and 148 graphical checks pass; no phone performance test. [Details](docs/SAND_DUST.md).

2026-09-20 V02/V04/V05: owner follow-up enlarges sand dust and extends the main cloud to 2.1 seconds, with moderately larger/longer rear spray. 141 headless and 147 graphical checks pass; no phone test. [Details](docs/SAND_DUST.md).

2026-09-20 R01/V02/V04/V05/Q01: sand now has wheel-driven two-layer particles: restrained four-wheel expanding dust plus short, stronger rear spray tied to the tire-mark physics intensity and wheel-point velocity. 139 headless, 145 graphical and 74 driving checks pass; no phone test. [Evidence and limits](docs/SAND_DUST.md).

2026-09-20 R01/V02/V04/V05/Q01: final tire trails deployed to DN2103. Controlled empty/16,384-mark/empty phone probe measured 16.866/16.792/16.837 ms medians and 20.400/19.913/19.833 ms p95; saturation adds one draw call with no measured sustained regression. Debug marker removed and normal app relaunched. [Evidence and limits](docs/SURFACE_TIRE_TRACKS.md#physical-phone-performance-and-deployment--2026-09-20).

2026-09-20 G01/G03/R01/R03/R07: owner follow-up increases physics-based differential verge torque by 35% without changing soil deceleration or adding retained yaw. Physics 0.35; 345 focused checks pass, no phone test. [Details](docs/OFF_TRACK_HANDLING.md#stronger-physical-wheel-torque---2026-09-20).

2026-09-20 G01/G03/R01/R03/R07: replaces the rejected authored verge tug with differential wheel-drag torque derived from contact, mass, track width and rotational inertia. Physics 0.34; 345 focused checks pass, no phone test. [Details](docs/OFF_TRACK_HANDLING.md#differential-wheel-drag-correction---2026-09-20).

2026-09-20 G01/G03/R01/R03/R07: replaces the rejected scripted near-spin with a brief progressive, self-damping one-tyre verge tug. Physics 0.33; 343 focused checks pass, no phone test. [Details](docs/OFF_TRACK_HANDLING.md#natural-verge-tug-correction---2026-09-20).

2026-09-20 G01/G03/R01/R03/R07: a single off-track tyre now creates a 60-tick near-spin pivot response while balanced soil contact cancels yaw. Physics 0.32; 342 focused checks pass, no phone test. [Details](docs/OFF_TRACK_HANDLING.md#single-tyre-near-spin-follow-up---2026-09-20).

2026-09-20 G01/G03/R01/R03/R07: owner follow-up strengthens off-track deceleration and partial-wheel pull. Physics 0.31; 284 relevant focused checks pass. The chained car suite retains four unrelated visual-model failures; no phone test. [Details](docs/OFF_TRACK_HANDLING.md#stronger-follow-up---2026-09-20).

2026-09-20 R01/V02/V04/V05/Q01: reference-guided asphalt marks now follow all four wheel contacts, use tire-width feathered charcoal streaks, nonlinear slip/brake opacity, rear-biased oversteer response, distance-smoothed starts/ends and repeated-pass alpha accumulation. The fixed single batch retains ~1.31 km through 16,384 instances. Approved sand and dark brown-green grass remain. 134 headless, 139 graphical and 114 quick-regression checks pass; no phone test. [Details and acceptance](docs/SURFACE_TIRE_TRACKS.md).

2026-09-20 G01/G03/R01/R03/R07: all vehicles now use proportional four-wheel loose-surface drag, stronger full off-track slowdown and bounded pull toward escaped wheels. Physics 0.30; 363 focused checks pass, no phone test. [Metrics, commands and remaining acceptance](docs/OFF_TRACK_HANDLING.md).

2026-09-19 G01/R01/R03/R07: Drift+ 0.19 moderated to the requested midpoint between Original+ and the stronger rear-drive tune. Powered fixture: 29.46° versus 17.61° Original+ and 39.18° prior Drift+; power/coast distinction and recovery remain. [Metrics](docs/COMPACT_HANDLING_REFINEMENT.md).

2026-09-19 G01/R01/R03/R07: Drift+ 0.18 now has an explicit arcade rear-drive character: throttle adds rotation and cornering traction loss while coasting stays calmer; quick unwind recovery remains. 88 handling checks pass. [Metrics and limits](docs/COMPACT_HANDLING_REFINEMENT.md).

2026-09-19 G01/R01/R03/R07: owner found the initial Drift+ difference too subtle. Handling 0.17 makes breakaway, sustained angle and throttle rotation materially stronger while retaining quick unwind recovery; Original+ remains unchanged/default. [Metrics and checks](docs/COMPACT_HANDLING_REFINEMENT.md).

2026-09-19 R01/R04/R06/R07/V02/V03/V05: refined discovery menu, direct favorite stars, record/distribution/friend panel and cloud-ready read-model boundary. 460 graphical and 93 focused checks pass; no phone test. [Details and acceptance](docs/REFINED_DISCOVERY.md).

2026-09-19 G01/R01/R03/R07: separate compact Drift+ option adds more powered drift, calmer steering onset and quicker grip recovery while Original+ remains unchanged/default. Handling 0.16. [Metrics, commands and acceptance limits](docs/COMPACT_HANDLING_REFINEMENT.md).

2026-09-19 V02/V03/V05: dedicated generated Storm track-card background replaces Grass fallback. 397 menu capture checks pass. [Artwork and evidence](docs/DISCOVERY_MENU.md#dedicated-storm-artwork---2026-09-19).

2026-09-19 R01/T01/V05: added scripts/deploy-phone.ps1 for fresh APK deployment plus saved-PC-track sync with replacement backups/hash verification. Tested on DN2103: focused checks 70/18/11 pass, 20 tracks verified, phone-only track retained. Missing-source preflight rejected as expected. [Usage/limits](docs/ANDROID.md#deploy-game-and-all-saved-pc-tracks).

2026-09-19 R01/V05/Q01: optimized Storm verified on DN2103: ~47 FPS versus ~43; frames over 25 ms reduced 38% to 26%. Not steady 60 FPS. Normal play restored. [Evidence](docs/STORM.md#optimized-build-verified-on-phone---2026-09-19).

2026-09-19 R01/V05/Q01: cached Storm trail histories remove repeated path evaluation; desktop microbenchmark ~89x faster, 54 checks pass. Optimized APK installed; phone FPS comparison blocked by locked/asleep device. [Details](docs/STORM.md#trail-history-cpu-optimization---2026-09-19).

2026-09-19 R01/V05/Q01: current Storm build deployed/tested on DN2103. Warm driving sample ~43 FPS, 38% frames over 25 ms; not steady 60 FPS. Diagnostic cleaned up, normal app relaunched. [Evidence](docs/STORM.md#physical-phone-deployment-and-performance---2026-09-19).

2026-09-19 V02/V04/V05: erratic droplet spurts with brief catches and sharper lateral changes replace smooth falling arcs. 53 checks passed. [Evidence and limits](docs/STORM.md#erratic-falling-paths---2026-09-19).

2026-09-19 V02/V04/V05: heavier Storm rain, greater central water coverage and roughly doubled droplet refraction. 53 checks passed. [Evidence and limits](docs/STORM.md#heavier-rain-and-stronger-distortion---2026-09-19).

2026-09-19 V04/V05: Storm lightning now every 9-16 seconds, first strike after 6 seconds. 53 checks passed. [Details](docs/STORM.md#twice-as-frequent-lightning---2026-09-19).

2026-09-19 V02/V04/V05: moving-drop trails now scale with bead width and taper as they fade. 53 checks passed. [Evidence and limits](docs/STORM.md#trails-proportional-to-bead-width---2026-09-19).

2026-09-19 V02/V04/V05: randomized uneven Storm droplet silhouettes and much stronger lightning illumination. 53 checks passed. [Evidence and limits](docs/STORM.md#irregular-shapes-and-stronger-flash---2026-09-19).

2026-09-19 V02/V04/V05: rebuilt Storm wet-glass presentation from owner mockup/shader attempt: layered beads, stronger refraction and winding rivulets. 53 checks passed. [Evidence/limits](docs/STORM.md#wet-glass-reference-rebuild---2026-09-19).

2026-09-19 V02/V04/V05: Storm droplets cling/grow, slip in curved bursts and settle again; fading trails follow their travelled path. 53 checks passed. [Evidence and limits](docs/STORM.md#clinging-and-slipping-droplets---2026-09-19).

2026-09-19 V02/V04/V05: original refractive Storm lens shader replaces outlined beads, with sparse falling drops and soft highlights. 51 checks passed; [evidence and limits](docs/STORM.md#refractive-lens-water---2026-09-19).

2026-09-19 V02/V04/V05: more visible falling Storm lens droplets, accelerating trails and occasional centre placement. 51 checks passed; [captures and acceptance](docs/STORM.md#falling-lens-droplets---2026-09-19).

2026-09-19 V02/V04/V05: Storm lens droplets enlarged 4x and lightning illumination strengthened. 51 capture checks passed; updated screenshots/video, no device test. [Follow-up](docs/STORM.md#larger-droplets-and-brighter-lightning---2026-09-19).

2026-09-19 G01/R01/R03/R07/T02/V02-V05: Storm biome with mild wet-road grip, overcast light, rain, restrained lens droplets and delayed thunder/lightning. Physics 0.29. [Changes, commands, captures and limits](docs/STORM.md).

2026-09-18 R01/G01/V02/V03/V05/Q01: Easy night lamp cost confirmed on the attached phone; spatial light culling and a mobile-night 3D render budget improve sustained presentation. [Measurements, tests, visual tradeoff and acceptance](docs/NIGHT_LIGHTING_PERFORMANCE.md).

2026-09-18 R01/G01/V03/V05/Q01: Play menu performance pass: background track preparation, bounded caches, incremental static previews and metadata indexing. [Attached-phone measurements, changed files and actual tests](docs/PLAY_MENU_PERFORMANCE.md).

2026-09-18 R01/G01/V03/V05/Q01: Knot's 85-tyre impact slowdown reproduced on the attached phone; exact grid-query rejection and unchanged tyre-transform suppression reduce collision/render work. Differential state/replay checks pass. [Measurements, commands and remaining device acceptance](docs/KNOT_TYRE_PERFORMANCE.md).

2026-09-18 G01/R01/V02-V05: mechanical cel-shaded pedals with exposed mounts, bevelled plates, recessed grips and restrained wear. 216 capture/HUD checks passed. [Evidence and device limits](docs/VEHICLE_CONTROLS.md#mechanical-pedal-refinement--2026-09-18).

2026-09-18 G01/R01/R03/R07/T02/V02/V04/V05: milder winter traction and soft snowbanks along asphalt edges. Physics 0.28. [Changes, metrics, tests and device limits](docs/WINTER_ICE.md#milder-winter-handling-and-soft-snowbanks---2026-09-18).

2026-09-18 G01/R01/V02-V05: distinct illustrated steering/pedal controls for all five vehicles; 161 regression checks and 125 skin/target checks passed. [Captures, commands and phone acceptance](docs/VEHICLE_CONTROLS.md).

2026-09-18 G01/R01/R03/R07/T02/V02/V04/V05: winter asphalt now has icy traction and frost visuals, including bridges. Physics 0.27. [Commands, measured behavior and acceptance](docs/WINTER_ICE.md).

2026-09-18 V02/V04/V05: darker night outside street lamps; reduced ambient/moon lighting. 41 capture checks passed. [Evidence and device limits](docs/BIOME_CREATION.md#darker-night-follow-up---2026-09-18).

2026-09-18 R01/T01-T04/V02-V05: Grass/Desert/Night city/Winter replace the three-biome picker; warm street-lamp illumination and snow presentation. [Actual checks, captures and device limits](docs/BIOME_CREATION.md#four-biome-revision--2026-09-18).

2026-09-18 R01/T01?T04/V03/V05: Create/New require large biome cards before entering an empty track; biome locked and nature palette filtered. [Changes, checks, captures and device limits](docs/BIOME_CREATION.md).

2026-09-17 R01/T01-T04/V03/V05: closer-reference panel/card styling and larger previews; removed drawer settings icon, retained options through selected asset. [Changes and checks](docs/EDITOR_STYLE.md#reference-refinement--2026-09-17).

2026-09-17 R01/T01-T04/V03/V05/Q01: road approval uses immediate accepted-road drawing and background compilation; desktop click handling fell from 450–590 ms to 10–18 ms in the graphical fixture. 338 distinct checks passed. [Measurements, captures and device limits](docs/ROAD_APPROVAL_PERFORMANCE.md).

2026-09-17 R01/T01-T04/V03/V05: removed editor hint bar, balanced palette padding and separated Undo/Redo from track identity. [Layout follow-up](docs/EDITOR_STYLE.md#layout-follow-up--2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: road edits pivot on the single attached end and adjust the free end, including previews and endpoint dragging; connected grip shows a lock. 609 checks pass. [Commands and capture](docs/ROAD_PLACEMENT.md#adjust-the-free-end-2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: screenshot-guided editor styling, unified rail, slimmer asset drawer, selected-only cyan and green Test/play. [Changes, checks and acceptance](docs/EDITOR_STYLE.md).

2026-09-17 R01/T01-T04/V03/V05: road handles gain distinct action pictograms, shape/colour coding, separated touch targets and active geometry feedback without more labels. [Actual checks and previews](docs/ROAD_PLACEMENT.md#handle-affordances-without-labels-2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: S-curves and hairpins use endpoint, width and inner shape dots without separate dimension/rotation buttons or leader lines. [Actual checks and previews](docs/ROAD_PLACEMENT.md#consistent-s-curve-and-hairpin-dots-2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: normal curves gain a bounded inner curvature dot; circular default, fixed joins, persistent undoable shape. Compiler 16. [Tests, captures and limits](docs/ROAD_PLACEMENT.md#adjustable-curve-curvature-2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: S-curves have fixed 2 m straight ends with no lead-in/length control; endpoint resizing preserves both ends. Compiler 15. [Tests, evidence and limits](docs/ROAD_PLACEMENT.md#fixed-s-curve-ends-2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: simplified straight/curve endpoint and width dots, inner angle control and pure-arc curves. Compiler 14. [Commands, captures and remaining acceptance](docs/ROAD_PLACEMENT.md#straight-and-curve-dot-controls-2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: reference-style Free/Area/Line buttons in top controls, live brush-size slider and fine adjustment. [Captures, checks and device limits](docs/SURFACE_USABILITY.md#reference-style-top-paint-controls---2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: in-draft surface confirmation, separate placement toolbar, Oil spill in Objects and no Road in Surfaces. 315 checks pass. [Captures, commands and device limits](docs/SURFACE_USABILITY.md).

2026-09-17 V02/V04/V05/R01/T01-T04: removed stepped shoulder/painted-sand join with decorative-only sand blending. 34 graphical checks pass. [Close-up and device limits](docs/SURFACE_MODES.md#continuous-shoulder--painted-sand-join---2026-09-17).

2026-09-17 V02/V04/V05/R01/T01-T04: painted sand matches the road shoulder tint and shared granular texture. 33 graphical checks pass. [Close-up, commands and device limits](docs/SURFACE_MODES.md#matched-sand-color-and-grain---2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: corrected bright unpainted-road fringe regression; decorative verge replacement is now restricted to authored paint footprints. 63 checks pass after failing reproduction. [Captures and device limits](docs/SURFACE_MODES.md#unpainted-road-regression-correction---2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: protected surface paint now replaces decorative roadside grass; outer grass edges share the road shoulder fringe. 61 checks pass. [Screenshot, commands and device limits](docs/SURFACE_MODES.md#roadside-verge-follow-up---2026-09-17).

2026-09-17 R01/T01-T04/V03/V05: line/area/free surface modes, draggable draft points, explicit confirmation, rounded contours and blended material boundaries. [Actual tests, screenshots and Android limits](docs/SURFACE_MODES.md).

2026-09-17 R01/T01-T04/V03/V05/Q01: object placement renders props immediately, compiles snapshots in the background and reuses unchanged raster/road meshes. Same-circuit tyre click handling falls from 383-390 ms to 23-26 ms on desktop. [Actual checks, screenshots and device limits](docs/OBJECT_PLACEMENT_PERFORMANCE.md).

2026-09-17 R01/T01-T04/V03/V05/R03/R07: removed Waypoints menu; Start line lives under Track with direct drag and tap-to-reverse controls. Routes regenerate automatically. Compiler 12; 673 checks pass. [Actual commands, captures and phone limits](docs/START_LINE_EDITOR.md).

2026-09-17 R01/T01-T04/V03/V05: automatic-only waypoints; retired all 194 Slicks circuits from the playable/export catalog and unsupported native bases. Original starter keeps fresh installs playable. [Actual tests, screenshots and device limits](docs/AUTOMATIC_WAYPOINTS.md).

2026-09-16 G01/R03/R07/T02/V05: tight Silmukka islands now use constructed-hairpin crossing geometry, independent of the generic 8 m progress gate. Rules v8. [Actual failing reproduction, tests and corrected diagnostic limitations](docs/TIGHT_HAIRPIN_CROSSINGS.md).

2026-09-16 G01/R03/R07/T02/V05: screenshot-driven Silmukka hairpin correction uses the inside road boundary instead of borrowing outside width; removes approach-diluted percentage gate. Rules v7. 728 checks pass, including narrow crossings, grass stops and five repeated cuts. [Actual commands and remaining acceptance](docs/SILMUKKA_HAIRPIN_BOUNDARY.md).

2026-09-16 G01/R03/R07/T02/V05: Silmukka missed-cut follow-up replaces blanket outside forgiveness and skipped-corner credit with excursion distance gain plus retained driven-path evidence. Rules v6; eleven cuts at three rates receive one penalty during the cut or within one tick of rejoin. [Actual commands, regressions and limits](docs/SILMUKKA_SHORTCUTS.md).

2026-09-16 R01/T01-T04: explicit Save refreshes the selected compiled circuit so immediately pressing Race uses saved edits. 32 creator refinement checks pass. [Cause, commands and device limits](docs/SAVED_TRACK_REFRESH.md).

2026-09-16 G01/R03/R07/T02/V05: outside-corner false-positive follow-up adds directional inside-cut evidence and clears pending cut debt while running wide. Rules v5. [Reproduction, actual tests and remaining limitations](docs/OUTER_CURVE_SHORTCUTS.md). Earlier v4 results below are superseded for this issue.

2026-09-16 R01/T01-T04/V03/V05: all road types expose simultaneous labeled directional handles directly on previews and selections. [Actual checks, captures and device limits](docs/ROAD_PLACEMENT.md#direct-preview-controls-follow-up).

2026-09-16 R01/T01-T04/V03/V05: hairpins expose separate Straight length; new pieces default to zero straight arms. 285 checks pass. [Captures, commands and phone limits](docs/ROAD_PLACEMENT.md#hairpin-straight-length-follow-up).

2026-09-16 G01/R03/R07/T02/V05: owner rejected v3 shortcut validation. Replaced mandatory route coverage and delayed rejoin confirmation with swept progress plus spatial bypass evidence, same-tick penalties, a two-second prominent warning and counted laps with +5s. Kerb finishes accept car overlap. Rules v4; 1,369 targeted/capture checks pass and 21 saved-track trajectories finish without penalties. [Actual results, captures and remaining driving/device acceptance](docs/ROUTE_PROGRESS_VALIDATION.md).

2026-09-16 R01/T01?T04/V03/V05: independent S-bend height, equal hairpin arms and on-road tap/drag acceptance. Compiler-11. [Actual tests, screenshot and device limits](docs/ROAD_PLACEMENT.md).

2026-09-16 V02/V04/V05/Q01/R01: enabled gameplay 2x MSAA and recorded future graphics options on the wishlist. Desktop capture succeeds; five PB integration failures reproduce with AA off. No device test performed. [Commands, evidence and limitations](docs/GAMEPLAY_ANTIALIASING.md).

Superseded by owner feedback above: 2026-09-16 G01/R03/R07/T02 replaced per-tick shortcut heuristics with automatic ordered swept route coverage and road/kerb tolerance. Clear later-route rejoins confirm a shortcut after 0.4 s and 2 m; the finish catches remaining incomplete routes without duplicate penalties. Local rules v3 isolate prior PBs. 1,350 targeted checks pass, including hairpins, kerbs, early feedback, driven laps, exact replays and PBs; full Validate encountered a Godot parse-process crash. [Review, exact tests, changed files and acceptance limits](docs/ROUTE_PROGRESS_VALIDATION.md).

2026-09-15 G01/G03/V02/V03/V04/V05/R01/R03/R04/R06/R07: four-car local garage with persistent selection, original illustrated art, distinct gameplay models and authored handling. Formula leads the clean skidpad, pickup leads loose-surface acceleration, classic leads the long straight. [Actual tests, captures, balance limits and phone acceptance](docs/CARS.md).

2026-09-15 V02/V04/V05: warm grey bridge rails and finer asphalt flecks replace blue rails and soft mottling, track-kit-22. Final bridge capture passes 95 checks; road/native cells and normals verified. [Evidence and visual/device limits](docs/GREY_RAILS_ASPHALT.md).

2026-09-15 V02/V04/V05: readable asphalt aggregate and simpler bridge rails raised 20 cm (track-kit-21). 168 focused checks pass; creator/native bridge and road captures inspected. [Actual commands, evidence and limitations](docs/ROAD_RAIL_REFINEMENT.md).

2026-09-15 V02/V04/V05: owner reports patchy asphalt; track-kit-20 removes secondary patches/tonal thresholds and reduces macro contrast to +/-0.8%. [Corrected capture and actual verification](docs/ROAD_REFINEMENT.md). Phone testing remains pending.

2026-09-15 V02/V03/V05/Q01/R01: minimap roads cached separately from the player marker and reduced to thin placed-road lines. Desktop redraw callback ~6 ms to ~0.05 ms; 95 graphical checks pass. [Measurements, capture and device limits](docs/MINIMAP_PERFORMANCE.md).

2026-09-15 V02/V04/V05/Q01: broader asphalt tones, quieter grain and slower verge variation (track-kit-19). 332 focused checks pass; before/after and bridge captures inspected. [Changes, commands and remaining phone/visual acceptance](docs/ROAD_REFINEMENT.md).

2026-09-15 V02/V04/V05/Q01/R01: [road visual ideas reviewed](docs/ROAD_VISUAL_REVIEW.md) against existing shaders, shoulders and skid trails. Driving-data road wear recorded on the [wishlist](docs/WISHLIST.md) and explicitly deferred. Documentation only; no runtime or device tests.

2026-09-15 V02/V03/V04/V05/G01/R01/R07: reference-shaped HUD, icon menu, raised pedals and blue/concrete bridges; minimap exclusively follows placed road pieces on new creator tracks. 264 focused checks pass. [Evidence, commands and phone acceptance](docs/REFERENCE_HUD.md).

2026-09-15 G01/V03/V05/R01/R07: race starts clear of the finish stripe; countdown/GO raised above the car. [Changes, actual tests and screenshots](docs/RACE_START.md).

2026-09-15 V02/V03/V04/V05/G01/R01/R07: bridge steel rails and shaded deck fascia refined; racing HUD uses navy/cream/gold Barlow styling with separate lap, timer, actions and compact speed. 412 focused checks pass. [Actual captures, commands and phone limitations](docs/BRIDGE_HUD.md).

2026-09-15 V02/V04/V05: kerb crown/bevel/base shading strengthened for normal gameplay-camera readability; physical height and response unchanged. 195 focused checks pass. [Captures and acceptance limits](docs/KERB_READABILITY.md).

2026-09-15 G01/V02/V04/V05/R01/R03/R07: visual body suspension reacts to acceleration, braking, cornering, impacts, jumps and bridge transitions, with bounded hard-contact sparks. Canonical handling unchanged. [Actual checks, captures and acceptance limits](docs/VISUAL_SUSPENSION.md).

2026-09-15 G01/V02/V04/V05/R01/R03/R07: raised kerbs share 10 cm bevelled geometry with deterministic tyre contact and a small spring/speed response. Physics 0.21, compiler-10, recorder schema 7. [Actual checks, captures and device limits](docs/RAISED_KERBS.md).

2026-09-15 V02/V04/V05: owner-directed grass/road/lighting restoration and three-door hatchback model correction. 70 driving checks pass; gameplay and model captures saved. [Changes, evidence and acceptance limits](docs/HATCHBACK.md).

2026-09-15 V02/V04/V05: first illustrated gameplay pass adds cream/blue car detail, quieter grass/asphalt and revised race lighting. 70 driving and 158 road-piece checks pass; desktop capture inspected. [Evidence and remaining art/device acceptance](docs/ILLUSTRATED_WORLD.md).

2026-09-15 R01/R04/R06/R07: Tracks now displays the selected handling profile's saved PB, fixing hidden Original+ times. Owner confirmed existing Original+ startup default. Graphical app integration: 100 checks; persistence: 53 checks, zero failures. [Evidence and device limits](docs/LOCAL_BEST_FIX.md).

2026-09-14 G01/R01/R03/R07: Original+ keeps Original steering with slightly more slide and stronger nose-directed throttle. Unchanged Original remains selectable. Physics 0.20 / handling-0.15-original-slide. [Measured behavior, actual checks and remaining feel/device acceptance](docs/ORIGINAL_SLIDE.md).

2026-09-14 G01/R01/R03/R07: restored Original handling as startup default and exposed a visible handling selector in normal races and creator practice. [Behavior, 201 passing focused checks, screenshot and phone limits](docs/HANDLING_SELECTOR.md).

2026-09-14 V02/V03/G03: rejected procedural menu scenes replaced by original detailed vehicle illustration, with cleaner framing and retained functional controls. [Artwork, prompt, actual captures/checks and device limits](docs/ILLUSTRATED_MENUS.md).

2026-09-14 G01/R01/R03/R07: focused fun-handling iteration adds progressive steering/front traction, deliberate brake rotation, faster countersteer recovery, tyre scrub audio and Planted/Balanced/Playful/Baseline comparison. Handling-0.14 / physics 0.19. [Actual checks, controls, evidence and remaining human/phone acceptance](docs/HANDLING_FUN.md).

2026-09-14 V02/V03/G03/R01/R04/R06/R07: premium menu reference applied to Home, Garage, Tracks, Settings and Results with original scenery, navy/gold controls and bottom navigation. [Actual checks, captures and remaining art/device acceptance](docs/PREMIUM_MENUS.md).

2026-09-14 R01/T01-T04/V02/V04/V05: centred biome/rename dialogs, keyboard-aware rename placement, taller rail, transparent header and grey disabled Test. [Checks and captures](docs/EDITOR_WIP_WORKFLOW.md).

2026-09-14 R01/T01-T04/V02/V04/V05: centred editor rail, simplified header/menu, biome and waypoint tools, fixed object paging and independent WIP autosave. [Actual checks and captures](docs/EDITOR_WIP_WORKFLOW.md).

2026-09-14 R01/T01-T04/V02/V04/V05: Curvy follow-up removes folded marking tails and cap-directed kerb spikes. [Actual checks and closer captures](docs/KERB_JOIN_FIXES.md).

2026-09-14 R01/T01-T04/V02/V04/V05: reference layout follow-up: grouped raised rail, green text-only Test, track name, charcoal tiles, road glyphs and Jump in Objects. [Actual checks and captures](docs/EDITOR_PRESENTATION_REFINEMENT.md).

2026-09-14 G01/R01/V02/V04/V05: traversable water with gradual car submersion and separate long-lived oil / short-lived water tire coatings. [Behavior, actual verification and device limits](docs/SURFACE_RESPONSE.md).

2026-09-14 R01/T01-T04/V02-V05: unified editor controls, two-row asset browser, contextual options, direct object dragging and a mapped oblique planning view with refined prop meshes. [Actual captures, checks and remaining art acceptance](docs/EDITOR_PRESENTATION_REFINEMENT.md).

2026-09-14 R01/T01-T04/V02/V04/V05: shared road joins, gradual connected widths and road-aligned full-width start line. [Implementation, checks and Curvy/Blind spot captures](docs/ROAD_JOIN_FIXES.md).

2026-09-14 R01/T01-T04/V02/V04/V05/G01: reference-led object browser, grouped variants, single/line/curve/road-edge placement, movable lightweight props and a central future biome availability hook. [Implementation, tests, screenshots and bounds](docs/OBJECT_BROWSER.md).

2026-09-14 R01/T01-T04: editor Load now shows all saved tracks immediately; empty search no longer hides the list. [Fix, actual checks and screenshot](docs/EDITOR_LOAD_LIST.md).

2026-09-14 R01/T01-T04: saved tracks and unfinished drafts now have confirmed deletion, including recovery-file cleanup and library/selection refresh. [Actual checks, screenshots and limits](docs/USER_TRACK_DELETION.md).

2026-09-14 V02/V04/V05/R01/T01-T04/G01: tapered kerb tips, solid/selectable scenery trees, scalable rock/cliff variants, matching bridge asphalt/guardrails and deterministic ramps/oil/shallow water. Physics 0.16 / compiler-7 / track-kit-11. [Behavior, actual checks, screenshots and limits](docs/CREATOR_HAZARDS.md).

2026-09-14 V02/V04/V05: track-kit-10 gives each kerb run complete equal blocks with white beginnings/endings. Actual screenshot and 138 passing checks: docs/VISUAL_STYLE.md.

2026-09-14 V02/V04/V05: track-kit-9 integrates original painted grass, mipmapped detail, broad colour variation and a broken grass/gravel blend from the new texture direction. See docs/VISUAL_STYLE.md for actual captures/checks and PAINTED_GRASS_PROMPT.md for generation provenance.

2026-09-14 V02/V04/V05: track-kit-8 corrects flat-mesh normals, removes microscopic edge segments causing sand spikes, separates terrain layers and filters sand grain. Actual captures/tests: docs/VISUAL_STYLE.md.

2026-09-14 V02/V04/V05: track-kit-7 fixes kerb spacing along actual edge distance, closes segment seams, procedurally roughens shoulders and omits sand behind kerbs. Actual checks and Silmukka capture: docs/VISUAL_STYLE.md.

2026-09-14 V02/V04/V05 follow-up: corrected grass, branch shapes, decorative stone scale, grey tree footprints and creator roadside shoulders/inner kerbs. Track-kit-6 actual Silmukka screenshot and checks are recorded in docs/VISUAL_STYLE.md.

2026-09-14 V02/V04/V03/R01/V05: reference-led woodland visual revision, shared textured materials, irregular pines, selective outlines and driving-control icons. See [docs/VISUAL_STYLE.md](docs/VISUAL_STYLE.md) for actual evidence and acceptance limits.

2026-09-14 G01: tyre contact now supports sustained pushing, stronger impact slowdown and cumulative pile resistance (physics 0.15). [Implementation, measured checks and acceptance limits](docs/TYRE_PUSHING.md).

2026-09-14 tyre/load follow-up: stronger tyre sliding resistance and car impact (physics 0.14), searchable editor Load, same-ID resaving and correct unfinished-draft map previews. [Measured before/after response, checks and future shared-version lock policy](docs/TYRE_RESISTANCE_AND_LOADING.md).

2026-09-14 creator follow-up: solid placed trees/rocks, road-safe terrain painting, free tyre lines and deterministic movable stacks, explicit endpoint connection, variable curve angles, visible Save and recoverable local drafts/racing. [Implementation, tests and acceptance limits](docs/CREATOR_REFINEMENT.md).

2026-09-13 direct construction: body dragging, anchored endpoint dots, desktop pan/zoom/shortcuts and authorable two-level bridges implemented in creator-track-v5. [Behavior, validation and remaining acceptance](docs/CREATOR_CONSTRUCTION.md).

2026-09-13 creator usability review: eight reproducible issues recorded, led by race-route readiness, variable-width connections and invalid-drag persistence. Existing 96 workflow checks pass; new isolated review scenarios reproduce the gaps. No application fixes in this checkpoint. [Findings and proposed order](docs/CREATOR_USABILITY_REVIEW.md).

2026-09-13 wireframe creator revision: full-screen shared 3D scenery, Road/Surface/Objects/Race rail, contextual palettes, place-and-snap road sections, direct radius/lead-in/width handles, roadside barrier/tyre/fence runs, start-obstruction recovery and untimed practice with Edit here. V4 drafts retain free painting and separate lap routing. Ordinary races remain five laps. [Implementation and actual evidence](docs/WIREFRAME_EDITOR.md). Desktop acceptance checks pass; phone reach, safe areas and performance remain untested. Android prerequisites are missing.

2026-09-13 full-screen creator: Create now fills the viewport, with collapsible tool/settings overlays, anchored 16× zoom, crisp adaptive grid and 0.5 m detail brushes. Targeted UI/creator/replay checks pass; physical-phone acceptance remains open. [Full-screen editor evidence](docs/FULLSCREEN_EDITOR.md).

2026-09-12 race presentation: car-led pit scene, first-run invitation, returning-player PB target and precise retry debrief replace the generic dashboard. Five laps, searchable circuits and favorites remain. See [Race presentation](docs/RACE_PRESENTATION.md) for requirements, reviewed screenshots, actual tests and prototype-asset/phone limitations.

2026-09-12 free-form editor: the owner selected free-shaped roads, terrain, intersections and obstacles. Paint/Pan, round/square surface brushes, a separate lap route and native-track Remix replace the spline-only editing model. V3 creator format; five-lap crossing/replay and full regression checks pass. See [Free-form editor](docs/FREE_FORM_EDITOR.md) for commands, screenshots and unperformed phone acceptance.

2026-09-12 track discovery follow-up: visual route cards, a dedicated Tracks tab, persistent favorites, combined name/creator search, theme filtering, natural sorting and filtered random selection replace sequential browsing. The paged metadata index is checked with 5,000 entries and builds no more than six track cards. All ordinary races and creator test drives now use **five laps**, with separate record rules preserving old three-lap partitions. Current evidence, commands and remaining acceptance: [Track library and five laps](docs/TRACK_LIBRARY.md).

2026-09-12 editor follow-up: sharp/smooth corners, 6–20 m per-node widths, touch object stamping/moving/rotation/copy/delete, stable JSON identity and v2-only creator files are implemented. Full validation and 42 graphical editor checks passed. [Editor revision 2](docs/EDITOR_V2.md) records behavior, Slicks research, evidence and remaining phone acceptance.

2026-09-12 menu follow-up: adapted Hill Climb Racing 2's selected-event/Race structure into a direct circuit-and-car race hub with Race/Garage/Create tabs and separate Settings. Graphical integration passed 86 checks; screenshot and commands: [HCR2 menu review](docs/HCR2_MENU_REVIEW.md). Full validation passed driving/original/extra tracks but encountered six creator failures during concurrent creator-format work. No phone test performed; owner menu acceptance remains open.

Updated: 2026-09-12. The owner has **accepted car handling and collisions** and explicitly authorized **local menus, additional Slicks circuits, a phone-friendly creator and shared track themes**. This is the active slice, covering selected P1/P3 local features. Physical-phone handling, camera calibration and performance acceptance remain open; this does not complete all blueprint gates.

## Current slice: menus and track studio

The project now opens a vehicle-led Play menu with Garage, Tracks, Create and Settings. Seven Slicks-derived circuits are selectable, including Pine Loop, Dune Run and Coast Oval. The creator starts from a valid smooth loop: drag/add/remove large handles, move the start, choose Pine/Coast/Desert, asphalt/dirt and 8–14 m road width, undo/redo, pan/pinch/zoom, view native 3D scenery, test drive, save and import/export/share locally. All three themes use the same native cells and art kit in previews and driving. No power/progression sale or racing gate was added.

Production menu races use a separate three-second countdown, five laps, results, immediate retry and recoverable local PBs with a separate flying-lap record. They remain explicitly unverified local times using the current ordered practice checkpoints; competition-grade shortcut validation remains unfinished. Existing developer handling/replay tools remain available through explicit `-Track` launches.

Full implementation details, actual final validation, screenshots and remaining manual acceptance are recorded in [docs/MENUS_AND_CREATOR.md](docs/MENUS_AND_CREATOR.md), [creator format](docs/CREATOR_FORMAT.md), [additional Slicks conversions](docs/MORE_SLICKS.md), [shared themes](docs/TRACK_THEMES.md) and [local records](docs/LOCAL_RECORDS.md). Earlier sections below are historical checkpoints; their requests to approve handling are superseded by the owner's acceptance above.

Android Doctor was rerun: matching templates, SDK/ADB/build-tools and JDK remain missing. Device attachment could not be enumerated; **no physical-phone test or APK export was performed**.

Next acceptance: try the complete create → preview → test drive → return → save/share/import flow; evaluate the new track art and extra circuits. Then complete Android setup and the actual phone usability/thermal session. Online leagues, progression, commerce and hosted publication remain deferred.

## Completed

- Replaced the bootstrap screen with one drivable original compact car and a flat handling yard: braking lane/distance markers, two skid circles, concrete collisions and non-colliding slalom cones.
- Added isolated typed planar simulation, fixed 120 Hz quantized controls, acceleration/braking/delayed reverse, speed-sensitive steering, lateral/longitudinal grip, recoverable slip, mass/yaw inertia, countersteer assistance and throttle rotation.
- Handling parameters live in Resources. Stable/Balanced/Loose presets, F2 live tuning and F6 reload make comparisons quick. Restart restores the same initial state immediately.
- Added a high-oblique fixed-yaw camera, bounded look-ahead, render interpolation, original matte car geometry, steering wheels/brake lamps and a capped skid-trail pool. Initial framing uses baseline / 1.15; full reference calibration is pending.
- Keyboard and simultaneous touch adapters work. Focus/background loss pauses and clears inputs. Added optional speed/longitudinal/lateral/slip/input/yaw/grip/FPS/tick telemetry.
- F3 records up to two minutes of quantized controls with handling/physics metadata and periodic states, then saves a local diagnostic JSON. No backend/analytics.
- Added 56 passing driving/replay/input/lifecycle/tuning/camera checks to the validation wrapper. Exact same-engine replay passed for 2,400 ticks at four render batch sizes; Android remains untested.
- Inspected real Windows driving captures. Guide: `docs/DRIVING_PLAYGROUND.md`; evidence: `docs/evidence/driving-playground.png` and `docs/evidence/driving-tests.txt`.

- Reviewed the full blueprint package, all supplied visual references/UI screens, camera contracts, architecture, roadmap/backlog and nine-sheet financial model. The 71 manifest entries match their supplied SHA-256 hashes. Original package files are preserved unchanged.
- Documented definitive requirements, contradictions, exact repository/module structure and eight ordered tasks in `docs/PHASE_0_PLAN.md`.
- Found and pinned Godot standard `4.7.2.stable.official.ed1daf0bf`. PATH's 4.6.2 engine is deliberately rejected by the wrapper.
- Created `game/project.godot`, minimal runnable composition scene, module directories and keyboard input actions. Configured landscape, Compatibility baseline and 120 Hz physics setting.
- Added Git ignore/attributes/editor conventions, project agent instructions, asset provenance notes and developer README.
- Added `scripts/dev.ps1`: doctor, import/parse/startup validation, Windows run/editor/capture, Android debug export/install/launch/deploy. Export validates first and publishes an APK filename only after success.
- Added an arm64 Android Debug preset, SDK/template guidance and exact future device-test instructions. Android tooling setup and execution remain open.
- Captured and inspected actual Windows startup: `docs/evidence/bootstrap-windows.png`.

## Four-track handling fixtures completed (2026-09-11)

Implemented the explicit Slicks handoff request: `slicks_freeway_test`, `slicks_1way_test`, `slicks_66_test`, `slicks_offroad_test`. Development-only programmatic conversion produces native geometry at 0.25 m/source pixel (9 m reference road, five 1.8 m car widths). Source checkpoint order/start markers, layered crossings, native materials and deterministic surface/collision behavior are preserved or explicitly inferred. OFFROAD alone needed a data-driven post-pair spacing correction, 1 m outward per post. F5/Track selects fixtures; F4/F7 inspect geometry/source overlays; F9 runs diagnostic AI. The yard remains the default.

Actual final validation: import, 23 parses, startup, 56 driving checks and 48 track checks passed; four converter tests passed. Every track completed three laps with zero AI contacts. Complete three-lap JSON replays exactly matched states and lap times in eight-tick batches on Windows. Both bridge levels were traversed on 1WAY, 66 and OFFROAD. Actual graphical overviews were inspected against all four references, plus a moving 1WAY capture. FREEWAY is the recommended first benchmark. Full results, commands, changed modules, widths, known assumptions and remaining manual checks: [SLICKS_IMPORT.md](SLICKS_IMPORT.md). Evidence: `docs/evidence/slicks-*` and `slicks_*`.

This does not complete Phase 5: practice timing starts immediately; no countdown, persistent PB or competition-grade shortcut verification. Bridge height transitions were subsequently corrected with shared ramp geometry; collision remains a planar prototype (see docs/RAMP_FIX.md). Human playtesting, camera calibration and phone acceptance remain pending. Doctor actually failed missing templates/SDK/ADB/build-tools/JDK; attachment could not be enumerated and no physical-phone test or APK export occurred. Physics identity is now arcade-planar-0.5 for surface/layer support; diagnostic manifest schema 2 includes extended state and native content hash. Existing yard handling assertions remain unchanged and pass.

## Previous handling iteration

Inspected owner's speculative Slicks handling analysis and implemented a focused G01 pass: handling-0.7 / arcade-planar-0.4. Faster steering input/yaw response, progressive slip grip, and no preset throttle-induced yaw/grip loss or automatic countersteering. Retained moderate corner scrub and planted grip from prior feedback. Simulation/config/presets/HUD tuning range/tests changed; rationale and intentionally deferred suggestions documented in docs/DRIVING_PLAYGROUND.md. Validate passed import, 17 parses, startup and 56 checks. New tap/trajectory-lag and throttle-pull tests pass; powered slip 10.0 degrees, coasting turn ends at 100.6 from 108 km/h. Inspected scripted Windows capture docs/evidence/driving-momentum.png and updated test evidence. Restart F8/F5 and evaluate steering taps and turn-in/lift/unwind/throttle in Balanced. Original-game equivalence is not verified. Physical Android and owner acceptance remain pending.


## Smaller car and faster turning ? 2026-09-12

G01 / V01 owner feedback: the tracks still did not feel fun; car slightly too big and too slow to turn. Handling-0.8 scales the physical car to 88%: base body 3.74 x 1.584 m, wheelbase 2.244 m, circular collision radius 1.364 m. Shared BODY_SCALE drives car mesh, wheelbase/collision defaults, rear skid axle/spacing and mark width. This is the owner's explicit physical-size adjustment, not the earlier 1.15 camera-calibration operation. Camera, roads and source package remain unchanged. The reference 9 m road now spans about 5.68 body widths rather than five.

Steering angle increases 0.60 -> 0.65 rad, yaw limit 2.2 -> 2.7 rad/s, Balanced lateral grip 50 -> 58 m/s?; Stable/Loose grip 60/50. Quarter-turn radii at initial 43/65/86 km/h improve from 7.87/10.62/14.84 m to 6.38/8.73/12.40 m. Powered corner slip is 13.0 degrees (within the existing 18-degree guard); acceleration/top speed remain 2.13 s to 100 km/h and 165.6 km/h. Single-circle body approximation remains a limitation.

Actual `scripts/dev.ps1 Validate`: first attempt crashed natively during parsing (exit -1073741819); fresh invocation passed all 23 parses, startup, 56 driving checks and 48 track checks. All four diagnostic AI runs completed three laps with zero contacts and replay checks passed. No failed handling invariant was relaxed: the island overlap check now uses the configured physical radius, and the legacy steering comparison explicitly retains its original wheelbase. Graphical FREEWAY launch/capture succeeded and was inspected: docs/evidence/smaller-car.png. Updated driving and track evidence retained. No Android test was performed; human fun/handling acceptance remains open.

Restart the running project from the editor, select FREEWAY with the Track button/F5, then choose 2/Balanced. Try turning into its tight bends and switching left/right; compare available clearance and whether the car turns soon enough without sliding wide. F5 inside the running game selects tracks.

## Next

1. Owner drives Balanced, Stable and Loose on Windows; adjust response and recovery based on a concrete maneuver and preferred preset. This is the immediate feedback request.
2. Phase 3: precise reference-camera fixture/bounds measurement and comparison at 1672×941; evaluate every heading and wider screens.
3. Phase 4/5: owner evaluates the four authorized practice circuits; complete countdown, persistent PB and full race validation separately after handling feedback. Native circuits, ordered practice checkpoints and three laps now exist. No progression/store/backend.
4. Complete Android prerequisites and the actual APK/device loop, including safe areas and real simultaneous touch. Iterate phone feel before final art/content expansion.

## Unresolved decisions

- Physical target phone/model, Android version and USB availability. ADB is not installed/configured here, so no device was enumerated and attachment state is unknown.
- Actual camera projection/pitch/extent: calibrate to the supplied target, not invented camera metres. World yaw stays fixed for acceptance.
- Compatibility versus Mobile: baseline is Compatibility; final choice requires the same visual scene profiled on phone.
- Handling balance and touch layout require driving. No claim that generic drift code will satisfy the intended feel.
- Package p95 targets differ: ≤20 ms in Q01/master, ≤16.7 ms in visual acceptance. Report both, aim for the stricter visual target, and record actual traces.
- Cross-device replay equivalence remains an explicit future test gate.

Resolved override: **three laps**, per the current owner request, replaces the package's original four-lap first task. Package content remains unchanged. PB will mean best valid full race with a separate flying-lap record. Store/economy assumptions stay deferred.

## Technical debt and limitations

- Four practice circuits, checkpoints and three-lap timing now exist; countdown, persistent PB and competition validation remain absent. Handling yard itself has no lap-duration claim. No audio/haptics or final graphic-novel material/outline pipeline; default toon materials and simple geometry are stand-ins.
- Single circular car collision approximation does not match exact front/side body clearance. Cones are deliberately non-colliding. Real phone safe-insets/handedness/layout work remains.
- Diagnostic replay JSON is capped but not compact, not a trusted competition record, and not an atomic progress save. A new save replaces the diagnostic file. R/tuning/profile change discards unsaved recording; pause saves it. Cross-device float equivalence remains unproved.
- Android export preset and install/launch commands are prepared but cannot be end-to-end verified without matching templates, SDK/ADB and JDK. Minimum Android 10/arm64 is a prototype proposal, not a tested device-support claim.
- Godot import prints `Unable to open Android 'build-tools' directory.` because the configured SDK does not exist. Windows import/parse/startup still succeed; Doctor correctly fails Android readiness.
- Release signing/Play submission and production asset notices are later distribution gates. No release build or production asset is claimed.
- The isolated `.tools/review` Python environment was used only to inspect documents/images/workbook and run supplied contract examples. It is ignored and not a runtime dependency.

## Actual validation

Commands ran from `C:\Codes\Godot\Beat my track` with PowerShell `-NoProfile`:

| Command / check | Actual outcome |
|---|---|
| Godot 4.7.2 console `--version` | `4.7.2.stable.official.ed1daf0bf` |
| Package manifest SHA-256 comparison | 71 entries checked; zero mismatches |
| `.tools/review/Scripts/python.exe -X utf8 -m unittest discover -s Android_racing_game_blueprint_v2/technical/tests -v` | 24/24 pass; documentation/schema examples only |
| Initial bootstrap `scripts/dev.ps1 Capture` | Exit 0: one script, bootstrap startup and graphical capture; retained historical evidence |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Doctor` | Expected exit 1: matching Android template, SDK/ADB/build-tools and JDK missing |
| `Validate -GodotPath C:\apps\Godot\Godot_v4.6.2-stable_win64_console.exe` | Expected exit 1: exact engine pin mismatch |
| Temporary malformed GDScript through `Validate` | Expected exit 1: syntax error detected; probe removed afterward; evidence saved |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Validate` after removing the probe | Exit 0: clean import, one script parsed, main-scene startup passed |
| Driving `scripts/dev.ps1 Capture` | Exit 0: import, 17 script parses, `PLAYGROUND_READY`, driving regression checks and graphical capture |
| Godot `--headless --path game --script res://tests/test_driving.gd` | Latest suite: 56 checks, zero failures; includes JSON replay/diagnostic save and scene integration |
| Godot `--path game -- --demo --capture=.../build/driving-demo.png` | Exit 0: rendered 400 physics ticks of scripted acceleration/turn, screenshot inspected; synthetic demo, not human playtest |

The Windows capture reports NVIDIA GeForce RTX 3090 / OpenGL 3.3.0. This is desktop rendering evidence, not a phone performance measurement. The braking test covered 16.35 m versus 31.53 m coasting over 1.33 s from 24 m/s. Power produced -10.0 degrees corner slip versus -4.9 degrees lifting. Same-engine JSON replay had zero final-state divergence for batches of 1/2/4/8 ticks. No APK export, ADB installation, Android launch, physical-phone test or driving-feel approval was performed. Three-lap automated practice-circuit tests are recorded in the newer four-track section above.

## Manual tests needed from owner

Open `game/project.godot` in Godot 4.7.2 and press F5, or run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Run
```

Use W/Up throttle, A/D or Left/Right steering, S/Down/Space brake (hold at rest to reverse), R restart. F1 toggles telemetry, F2 tuning, 1/2/3 selects Stable/Balanced/Loose. First drive Balanced at 60–80 km/h, turn toward a circle, lift and countersteer, then repeat with the other presets. Report which preset you prefer and whether response is delayed, too twitchy or difficult to recover. See `docs/DRIVING_PLAYGROUND.md` for the detailed session and recording commands; Android setup remains in `docs/ANDROID.md`.

The first subjective evaluation is immediate steering response and whether deliberate countersteering/throttle changes reliably catch a slide. After the circuit exists, record ten consecutive lap times and whether braking/line choice visibly improve them. Stop expansion and tune handling if that loop is not enjoyable.

## Bridge ramp correction — 2026-09-12

G01/G02/V01/R02: replaced bridge height snaps with spatial ramp meshes, axle-sampled car height/pitch and slope-following skid marks. Validate passed 24 parses, startup, 56 driving checks and 57 track checks. All four tracks completed three AI laps with zero contacts and exact replay; all three bridge tracks retained ground-level underpasses. Actual Windows captures were inspected. Changed files, commands, measured continuity and remaining manual acceptance are recorded in [docs/RAMP_FIX.md](docs/RAMP_FIX.md). No phone test or APK export was performed. Canonical simulation and native track data remain unchanged.

## Soft objects and coherent track materials ? 2026-09-12

G01/G02/R03/V01/V02 owner feedback: vegetation and low obstacles now slow the car rather than colliding; substantial walls, structures, rails and deep water remain blocking. Native schema/content v2, physics arcade-planar-0.6 and refreshed golden fixtures accompany the surface change. The original matte track kit adds clearer surface contours, curb paint, low cover and clean barrier sides. Validate passed 24 parses, startup, 56 driving + 76 track checks; four converter tests and all four native schema validations passed. All tracks completed three zero-contact AI laps with exact replay and continuous ramps. Final Windows screenshots were inspected. Changed files, actual commands, intermediate test/capture limitations and remaining human/phone checks: [docs/TRACK_SURFACES.md](docs/TRACK_SURFACES.md). No physical-phone test or APK export occurred.

## Ramp overlap recovery - 2026-09-12

G01/G02/R03/R01: inspected the owner's stuck 1WAY window (281 contacts), reproduced outward-motion rejection on all three bridge tracks, and fixed existing-overlap escape plus collision checks before layer transitions. Physics is arcade-planar-0.7; native geometry, surfaces and visuals are unchanged. Validate passed 24 parses, startup, 56 driving + 94 track checks. Held reverse fully clears each tested rail with zero contacts; all four three-lap AI runs and exact replays remain unchanged. Live screenshot, before/after logs, changed files, actual commands and limitations: [docs/RAMP_RECOVERY.md](docs/RAMP_RECOVERY.md). The old running instance was preserved; close/relaunch to load the fix. No phone test or APK export occurred.

## Visible collision rebound - 2026-09-12

G01 owner feedback: handling-0.9 increases shared restitution from 0.12 to 0.38. Runtime change is confined to HandlingConfig; rebound regressions were added to test_tracks.gd. In the held-throttle head-on test, separation rises from 0.183 to 1.443 m. Glancing impacts retain tangential movement while losing energy. Validate passed import, 24 parses, startup, 56 driving + 96 track checks; all four AI three-lap runs, exact replays and ramp escape checks pass. Physics algorithm/version and native content remain unchanged. Actual commands, evidence, changed files and remaining manual/phone acceptance: [docs/DRIVING_PLAYGROUND.md](docs/DRIVING_PLAYGROUND.md#collision-rebound---2026-09-12). No phone test or APK export occurred. Close/relaunch to load the new defaults.

## Collision direction and larger bounce - 2026-09-12

G01 owner feedback: handling-0.10 / physics arcade-planar-0.8 adds a bounded, energy-budgeted impact yaw impulse and raises restitution to 0.55. Reverse-speed limiting preserves impact recoil while still capping powered reverse. Angled test hits rotate heading by 9.369 degrees in 0.2 s; powered head-on separation is 3.736 m versus the prior 1.443 m. Validate passed import, 24 parses, startup, 56 driving + 107 track checks, including full lap/replay, ramp escape, energy and reverse-limit tests. Changed files, actual commands, test-fixture correction and remaining manual/phone acceptance: [docs/DRIVING_PLAYGROUND.md](docs/DRIVING_PLAYGROUND.md#impact-rotation-and-stronger-recoil---2026-09-12). No phone test or APK export occurred.

## Sustained wall contact - 2026-09-12

G01: native barriers now preserve checked tangential movement; low-speed rubbing gently aligns the car while hard impacts keep their bounce. Handling-0.11 / arcade-planar-0.9. The mirrored standstill test travels 8.918 m in 3 seconds and aligns within 0.934 degrees without penetration. TestTracks passes 115 checks, including all four three-lap AI/replay and ramp-recovery fixtures. Details and remaining manual acceptance: docs/DRIVING_PLAYGROUND.md, Sustained wall sliding. Phone testing remains unperformed.
Final full Validate passed import, 24 parses, startup and 171 checks (56 driving + 115 track). Evidence: docs/evidence/wall-slide-*.txt.

2026-09-12 G01 recoil moderation: handling-0.12 reduces restitution 0.55 -> 0.45 following owner feedback. Measured rebound distance 3.736 -> 2.658 m; wall alignment, ramp recovery and three-lap AI/replay pass. Full Validate passed import, 24 parses, startup and 171 checks. Changed config/test acceptance, rationale and evidence: docs/DRIVING_PLAYGROUND.md (Moderate recoil). Close/relaunch for manual feel acceptance; no phone test performed.

2026-09-12 G01 tire contamination and softer recoil: handling-0.13 / physics arcade-planar-0.10 reduce restitution to 0.30 (measured separation 1.186 m) and add distance-based grass/dirt tire coating with up to 25% temporary traction loss. A full coating clears over 80 m; waiting does not clean tires. Diagnostic schema 3 appends tire_dirt to canonical snapshots. Full Validate passes import, 24 parses, startup and 189 checks (56 driving + 133 tracks), including three AI laps on all four fixtures, zero contacts, exact replay and ramp recovery. Commands, changed files, contract and limitations: docs/DRIVING_PLAYGROUND.md (Tire contamination and softer recoil); evidence: docs/evidence/tire-dirt-*.txt. Manual feel and phone tests remain pending; close/relaunch to load.

2026-09-12 G01/G02/R03/R01 rail-tip follow-up: inspected the owner's parked 1WAY window (759 contacts) and reproduced late upper-rail activation at ramp ends. Physics arcade-planar-0.11 extends rail detection along the bridge axis by the car footprint and allows decreasing overlap across layer boundaries. Native geometry/presentation and handling-0.13 are unchanged. Full Validate passed import, 24 parses, startup and 207 checks (56 driving + 151 tracks), with all four three-lap AI runs at zero contacts and exact replay. Both-end rail contact/retreat fixtures, original ramp escapes and underpasses pass. Live screenshot, actual commands, test-fixture isolation and remaining manual/phone acceptance: docs/RAMP_RECOVERY.md (Rail-tip activation). Parked instance remains intact; close/relaunch to load. No phone test performed.

2026-09-12 G01 wall-motion consistency: reproduced stationary velocity accumulation and sudden release (up to 35.46 m/s stored). Physics arcade-planar-0.12 groups coplanar wall cells for tangential overlap recovery, fixes corner entry normals and removes rejected slide velocity. Final powered-scrape tests limit tangential acceleration to normal engine acceleration, with at most 0.039 m/s residual tangential velocity while nearly stationary. Full Validate passes import, 24 parses, startup and 219 checks (56 driving + 163 tracks), including every original ramp/rail/lap/replay invariant. Changed files, actual commands, test correction, evidence and pending manual/phone acceptance: docs/DRIVING_PLAYGROUND.md (Wall motion and acceleration consistency). Close/relaunch to evaluate; no phone test performed.

2026-09-12 G02/R03/R01: owner-authorized bulk Slicks corpus adds 187 native tracks (194 total), native manifest discovery and 71 searchable author names. Five blank-author tracks have explicitly fictional attribution. Offline legacy normalization and source/hash provenance remain outside runtime. Commands, evidence and bulk QA limitations: docs/SLICKS_CORPUS.md. No phone test performed.
Final bulk verification: 194 conversions, zero failures; 781 runtime/search checks and 3 Python corpus tests pass; TestApp passes 80 checks. Three automatic spawn corrections and one uniform scale exception are recorded in SLICKS_CORPUS.md.

2026-09-12 G02/R03/R01: corrected YLIKULKU's wrong bridge axis using rail direction for parallel straight bridges. Regenerated 33 affected native tracks; original seven fixtures unchanged. TestCorpus passes 793 checks, YLIKULKU three ordered AI laps with zero contacts, and TestTracks passes 163 lap/replay/ramp checks. Evidence and remaining mixed-bridge/device limitations: docs/SLICKS_CORPUS.md (Bridge-direction correction). No phone test performed.

2026-09-17 R01/T01-T04/V03/V05: integrated all seven owner-supplied editor icons; graphical workflow 181 checks passed. [Assets, screenshots, commands and device limits](docs/EDITOR_ICONS.md).

2026-09-18 V02/V03/V04/V05/R01/T01-T04: shared object models and biome-aware creator thumbnails refined; 243 checks pass, 35-variant and gameplay captures saved. See [actual changes, evidence and device limits](docs/OBJECT_MODELS.md).


2026-09-18 V02/V03/V04/V05/R01/T01-T04: owner-directed original block/red-band barrier restoration and sharper inked trees, track-kit-29. 219 checks pass; captures and scoped patch in [OBJECT_MODELS](docs/OBJECT_MODELS.md#owner-directed-barrier-and-tree-correction--2026-09-18). No phone test.

2026-09-18 V02/V03/V04/V05/R01/T01-T04: inked fractured rocks and standalone Cliff tile with 8/16/24 m presets; 226 checks pass, captures and scoped patch saved. [Changes and device limits](docs/OBJECT_MODELS.md#rocks-and-larger-cliffs--2026-09-18).


2026-09-18 G01/V02/V04/V05: distance-based tire rotation for all five cars, with separate steering pivots. [Checks, captures and device limits](docs/TIRE_ROTATION.md).


2026-09-18 R01/V02?V05/G03/R04/R06/R07: reference-led top navigation, illustrated discovery cards and workshop backdrop. 331 graphical capture checks, 18 catalog, 11 menu and 19 deletion checks pass; broader app tests stalled. [Changes, screenshots and device limits](docs/DISCOVERY_MENU.md).


2026-09-18 R01/G01/V03/V05/Q01: first Android debug APK installed on authorized DN2103 / Android 13. Focused deployment checks pass; full validation fails in existing app navigation integration checks. [Toolchain, fixes, actual commands and device acceptance](docs/ANDROID_DEPLOYMENT_2026_09_18.md).


2026-09-18 R01/G01/T01-T04/V03/V05/Q01: copied PC tracks/drafts to DN2103; enlarged mobile artwork and independent invisible touch targets; mobile render scale and model/trail batching. Actual device median frames ~16.8 ms, occasional misses remain. [Commands, checks, measurements and limits](docs/MOBILE_FOLLOWUP.md).

2026-09-18 R01/G01/V03/V05/Q01: Ajorata CPU follow-up installed on DN2103. Exact tyre-state comparisons pass; clean two-minute display trace has 7,249 intervals and no missed refreshes. Four pre-existing model child-count assertions still fail. [Changes, evidence and limitations](docs/AJORATA_PERFORMANCE.md).

2026-09-18 R01/G01/V03/V05/Q01: reproduced racing stutter under full HUD plus touch input (740 missed refreshes/minute). Retained button artwork installed; final fast Ajorata test reaches 105 km/h with 3 misses in 141 seconds. 689 graphical controls checks and 20 exact artwork comparisons pass. [Evidence and remaining acceptance](docs/RACING_INPUT_PERFORMANCE.md).

2026-09-18 owner device follow-up: Ajorata is reported noticeably smoother after the retained touch-artwork fix. Rare measured refresh misses remain; see docs/RACING_INPUT_PERFORMANCE.md.

2026-09-21 V02/V04/V05/Q01/R01: track-kit-47 refines dry asphalt toward the owner reference with visible fine aggregate and restrained weathering. 384 focused checks pass; final desktop capture inspected. No phone test. See docs/ROAD_REALISM.md (Reference asphalt texture).

2026-09-21 V02/V04/V05/Q01/R01: track-kit-48 adds irregular asphalt grain density/weathering and subtle road-aligned detail on creator road pieces. 384 checks pass; final desktop capture inspected. No phone test. See ROAD_REALISM.md (Irregular road-aligned grain).


2026-09-21 V02/V04/V05/Q01/R01: track-kit-49 reduces cloudy asphalt weathering while retaining irregular, road-aligned grain. 50 surface checks pass; desktop capture retry succeeds and was inspected. No phone test. See ROAD_REALISM.md (Crisper asphalt follow-up).


2026-09-22 G01/V03/V05/R01/R03/R07/Q01: traffic-light start and separate 1.8-second finish coast with Results crossfade. Official time/state freeze at the line. Practice 40, graphical practice 44 and Results 116 checks pass; desktop evidence saved. No phone test/export. See docs/RACE_FLOW.md.


2026-09-22 G01/V03/V05/R01/R03/R07/Q01: five accumulating red race lights and simultaneous lights-out start replace road signals; waving chequered flag replaces finish banner. Refined vector housings/cloth. 45 headless / 68 graphical checks pass; evidence in docs/RACE_FLOW.md. No phone test/export.
