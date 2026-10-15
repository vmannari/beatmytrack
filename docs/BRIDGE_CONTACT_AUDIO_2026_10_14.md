# Bridge entrance and exit contact sound — 2026-10-14

The owner hears a glass-shattering collision sound while driving onto/off bridges without hitting anything, and requests a suitable contact cue. Requirements: BCA01 remove false bridge crash cues; BCA02 retain a quiet contact indication; BCA03 preserve real impacts, existing audio bounds/lifecycle and canonical driving. G01/R01/Q01 and the prior Desert sand sound remain supported.

The visible-body observer sampled its whole 2D outline on the centre's current collision layer. Before the centre entered an open ramp, the nose could touch that ramp's ground-layer underside cells. On departure, an elevated body could also sample rails belonging to a nearby disconnected span. These are not body collisions on the driving surface. The original methods reproduce **113 false crash cues in 180 physically clear sweeps** of the six Knit spans, with all five actual native cars, both directions and three lateral lines.

`VisibleContactAudio` now checks occupied cell centres against the same supporting-span boundary used by the resolver. At an aligned open mouth, a nose/rear already over the ramp road samples that road instead of its underside. Side approaches, actual upper rails, the central underpass and physical underside contacts retain their behavior. This changes presentation observation only; it does not change the resolver, grids, physics, collision counts, snapshots or track contracts.

`VehicleAudio` observes actual ground/deck transitions through a road mouth and dispatches one quieter recorded body/suspension thump at each entrance and exit. It uses the existing `chassis.wav` (Nox recorded truck-body movement), pitched to 0.86, with speed-scaled gain 0.09–0.22. Crash clips are excluded from this cue. Real collision/visible solid contact takes priority. Startup/duplicate ticks, no movement, side entry, pause/countdown/air/roll and rewind/retry are guarded. Legacy native deck transitions also have the bounded contact path.

The original **23 players**, four body-event/two debris slots, **24 MiB** stream cap and **128** outline probes are retained. All **118 audio-bank file hashes are exact**; no source audio is added or remastered. Dirt/washing, Desert sand, kerbs, car geometry/camera and canonical driving remain unchanged.

## Actual validation and recordings

Pinned Godot **4.7.2.stable.official.ed1daf0bf** runs through `scripts/dev.ps1`. The task runner isolates APPDATA and retains logs. Representative actual commands:

```powershell
python build/prepare_bridge_audio_baseline.py
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_bridge_contact_audio.ps1 -Baseline -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_bridge_contact_audio.ps1 -Baseline -CaptureOnly -Check test_bridge_audio_baseline
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_bridge_contact_audio.ps1 -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_bridge_contact_audio.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_bridge_contact_audio.ps1 -CaptureOnly
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_bridge_contact_audio.ps1 -Renderer mobile -Capture
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_bridge_contact_audio.ps1 -Headless -Check test_bridge_contacts
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_bridge_contact_audio.ps1 -Headless -Check test_bridge_scrape_audio
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_bridge_contact_audio.ps1 -Check test_racing_render_audio_regression
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_bridge_contact_audio.ps1 -Headless -Check test_desert_soft_sand_audio
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_bridge_contact_audio.ps1 -Headless -Check test_script_parse
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_bridge_contact_audio.ps1 -Headless -Check test_direct_hit_body_audio
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_bridge_contact_audio.ps1 -Baseline -Headless -Check test_bridge_audio_baseline_wall
python build/review_bridge_contact_audio.py
python build/checkpoint_bridge_contact_audio.py
```

- Final dedicated matrix/lifecycle/Game: **42,184 headless** checks; Compatibility **42,184 + 5** focused native-capture checks; Mobile/Vulkan **42,189** including capture. Both native renderers exit cleanly. Each renderer's 180 sweeps produces **zero physical collisions, zero crash sounds and 360 soft contacts**, with exact per-step snapshots. Actual Game crossings in both directions each produce two contacts and no crashes/canonical collisions, with coarse render presentation.
- Original bridge collisions **16** pass, including lower underside blocking and upper rails. Original bridge scrape **602** pass; actual Game has 46 audible rail-contact ticks and 0.4017 peak scrape level. Original vehicle audio/bank/lifecycle **1469** pass; prior Desert sound **67** pass. Parser **765** scripts, zero failures. Scoped whitespace check passes.
- The native before recording selects `impact_1` at a physically clear mouth; isolated crash peak **0.3028**. Both after recordings select exactly two `chassis` contacts, with **zero crash PCM and exactly silent final pause**. Isolated body peak is **0.09836**; full output peaks −18.49/−18.81 dBFS, with no clipping. These are desktop digital measurements.
- A separate existing direct-wall test still fails one of five checks: the canonical response produces physical hits at ticks 21 and 50, and both are audible. The preserved pre-task methods reproduce the **identical** impulses, amplitudes, pitches and ticks, including the unchanged downshift at tick 44. The assertion is retained; this unrelated physics/fixture issue is not fixed or counted as a pass here.

[Before mix](evidence/bridge-contact-audio-2026-10-14/before/gl_compatibility/bridge-driving.wav) · [After mix](evidence/bridge-contact-audio-2026-10-14/after/gl_compatibility/bridge-driving.wav) · [After isolated body contact](evidence/bridge-contact-audio-2026-10-14/after/gl_compatibility/bridge-body.wav) · [Vulkan after](evidence/bridge-contact-audio-2026-10-14/after/mobile/bridge-driving.wav) · [Audio report](evidence/bridge-contact-audio-2026-10-14/audio-review.json).

The roughly 5.5-second audition uses fixed 8 m/s engine/surface state and separately timed resolver samples just before the mouth, on the ramp, near the far end and after exit. Native output plays continuously between those contact samples. The separate sweep and Game tests execute continuous traversals. It is a controlled sound audition, not a phone driving capture.

## Initial diagnostics, scope and remaining acceptance

The first analytic underside filter left 68 false cues and failed 40 traversal assertions: the raster cell's authored centre must be used, and other-span rails must be excluded. The final filter passes the original matrix. One early graphical Game fixture reported zero forward cues; the explicit coasting driver and disabled fixture key input remove external desktop input from the check, while retaining both complete physical traversals. The initial recording loop could skip a whole bridge during a long display frame; native auditions now warm rendering and sample entrance/exit separately. Missing not-yet-produced Vulkan inputs also caused one initial review-script failure. None of these initial attempts is counted as a final pass. Original launcher logs retain them.

Changed runtime: `game/vehicle/visible_contact_audio.gd`, `game/vehicle/vehicle_audio.gd`. Dedicated test: `game/tests/test_bridge_contact_audio.gd`. Preserved baseline methods/runners are generated under export-excluded `game/tests/fixtures/bridge_audio_before/` and `game/tests/test_bridge_audio_baseline*.gd`; they subclass the current typed domain boundaries so the actual Game can check the original methods without swapping workspace runtime files. Supporting scripts live in `build/`; instructions/status/plan include the scoped follow-up. The isolated two-commit Git checkpoint preserves the main branch/index and other existing work, including the previous Desert sound and concurrent car/physics edits.

No physical-phone test, APK or deployment. Owner listening, bridge routes beyond this local matrix and physical-phone speaker/headphone balance remain acceptance checks. No performance improvement or general absence-of-hitches claim is made.
