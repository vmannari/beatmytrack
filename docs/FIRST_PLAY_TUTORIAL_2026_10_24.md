# First-play tutorial — 2026-10-24

New players receive a short, skippable driving tutorial after the existing account setup or **Play as guest** choice. The real parking hall teaches acceleration, steering and braking through actions, followed by an offline five-lap Starter Circuit race and a personal-best explanation. Existing saves keep their normal startup. **Settings → Help → Replay tutorial** opens the lesson for any player.

| Requirement | Delivered behavior |
| --- | --- |
| FPT01 | Welcome follows account/Guest setup. Existing save files and prior racing suppress automatic enrollment. Start, Controls and Skip remain explicit; returning from Controls restores the choice. Pending invitations take precedence. |
| FPT02 | Three parking-hall objectives observe actual movement, steering and stopping at gold targets. Instructions follow buttons, relative slider/joystick pedals, keyboard or gamepad, saved positions and handedness. No target time or failure penalty. A stalled player can reset the car. Practise more leaves a compact First race action available. |
| FPT03 | First race opens the existing bundled Starter Circuit without a network dependency. It retains the real car, canonical simulation, ordered checkpoints, countdown, five laps, local PB and normal offline completion effects. The exact in-memory lesson document and account scope authorize this one local entry; same-ID copies cannot bypass published-track discovery. No online ticket/upload, interstitial ad or resource-consuming resume is offered by the lesson. Normal online modes retain their existing authority. |
| FPT04 | Small first-entry tips explain Garage, Rivalry and Challenges. Creator has an optional three-card Road → Start line → Practice walkthrough. First ordinary rewind opening explains Cancel and explicit Resume confirmation; the tutorial never confirms, funds or consumes a resume. Help reopens every topic. |
| FPT05 | Bounded, validated installation-local progress persists steps, skips, completion and dismissed topics with atomic replacement and backup recovery. It contains no account identifiers. Storage failure permits continued play with a save warning. Backgrounding, pause, account changes, interrupted loads and navigation cannot complete an objective or silently start a race. |
| R01 / G01 / Q01 | Retained native views, actual commands, initial failures, source hashes and a task-only Git-applicable checkpoint accompany the implementation. Existing unrelated work and owner processes remain. |

## Presentation and input

One instruction is shown at a time. Floor markers draw below the driving HUD; the instruction card and real-control outlines draw above it. Cards respect viewport safe insets and avoid current touch controls and HUD actions. Results guidance moves clear of live achievement banners. The tutorial's own first-race results gain a native scroll fallback on short windows, keeping Race Again reachable.

The menu carousel and page-swipe handlers accept an optional input-exclusion callback. Only a press starting over the visible tutorial card (or welcome cover) yields to its native GUI buttons. A gesture already owned by a carousel remains its gesture. Other menu areas and hidden tutorial layers retain their normal behavior. This addresses an actual native failure where Garage's carousel consumed the tip's Got it press.

There are no new bitmap/audio assets, runtime AI calls, network services, dependencies, analytics events or backend/schema changes. Existing fonts, native controls, palette, cars and track assets are reused. The parking lesson does not write PBs, car condition, race proof or rewards; the full five-lap race uses the existing local completion path.

## Files and evidence

Runtime additions are [tutorial_controller.gd](../game/tutorial/tutorial_controller.gd), [tutorial_overlay.gd](../game/tutorial/tutorial_overlay.gd) and [tutorial_progress.gd](../game/tutorial/tutorial_progress.gd). Integration touches App, Game's rewind entry, Settings and the two menu gesture handlers. The focused harness is [test_first_play_tutorial.gd](../game/tests/test_first_play_tutorial.gd); [the control harness](../game/tests/test_tutorial_swipe_control.gd) reloads five exact task-start scripts only in a disposable engine process for regression comparisons.

See the [machine report](evidence/first-play-tutorial-2026-10-24/report.json), [native gallery](evidence/first-play-tutorial-2026-10-24/report.html) and [scoped checkpoint](evidence/first-play-tutorial-2026-10-24/task-only.patch). The report records source hashes, commands and retained logs.

## Actual verification

Pinned engine: `4.7.2.stable.official.ed1daf0bf`, through `scripts/dev.ps1`. Every run uses workspace-local APPDATA and disposable records, libraries and cloud caches, with the API URL empty. Windows certificate-store access required running the isolated native test commands outside the filesystem sandbox; no owner save was used.

| Check | Observed result |
| --- | --- |
| Focused tutorial, headless | 145 checks, zero failures |
| Focused tutorial, native Compatibility | 178 checks, zero failures |
| Focused tutorial, desktop Mobile/Vulkan | 178 checks, zero failures |
| Actual five-lap diagnostic drive | All five ordered laps finish in every mode, using 12,753 real quantized driving ticks; no result is fabricated |
| Existing records / control layout / App | 54 / 407 / 141 checks, zero failures |
| Existing rewind / ad breaks / results | 61 / 63 / 515 checks, zero failures |
| Pinned import / complete script parser | Import passes; 1,119 scripts, zero failures |

The focused checks exercise Guest and actual native button presses; skip/replay and control setup; all three touch methods with left-handed layouts; moved pedals and notched-screen insets; 960×540, 1280×720 and 1600×720 layouts; real parking objectives; an already-stopped driver's brake action; pause/background/resume; persisted progress and damaged-file recovery; first-race resource fences; real five-lap completion, local PB and retry; result/footer reachability; ordinary rewind opening and cancellation; feature tips; and account/invitation fences.

Representative commands (executed with a workspace-local `$env:APPDATA`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_first_play_tutorial.gd -TestArgument '--evidence-root=res://../docs/evidence/first-play-tutorial-2026-10-24/verified-headless' -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_first_play_tutorial.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-root=res://../docs/evidence/first-play-tutorial-2026-10-24/verified-gl_compatibility' -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_first_play_tutorial.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence-root=res://../docs/evidence/first-play-tutorial-2026-10-24/verified-mobile' -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd
```

## Retained corrections and limits

Initial runs retain the sandbox log/certificate failure, corrupt-JSON diagnostic correction, typed-array error, test layout timing and zero-strength diagnostic-finger fixture corrections. Native review retains the original floor-marker/HUD and achievement/tip overlaps; the corrected views keep the original layout thresholds. One Mobile run legitimately entered the existing background pause after window recreation; the harness now restores foreground and uses the real Resume action. Native Garage-tip failures led to the scoped gesture exclusion. Later screenshot review caught cards compositing below menu/result canvases; final border-pixel checks prove they draw above those canvases. No failing assertion was removed. A concurrent import encountered a temporary native-DLL copy failure; a separate complete pinned import and both final parser runs pass.

The broader legacy page-swipe suite stops at three live-slide assertions and then a null-tween call. The same assertions and stop reproduce with all five changed shared runtime scripts restored to their exact task-start source in isolated memory. The broader Garage carousel suite retains three short-layout assertions and a missing-action stop. Its pre-change control also stops on a short-layout assertion and the same missing-action call, although the individual fit labels differ. These checks remain unresolved; neither suite has been represented as passing or weakened. The focused native tutorial exercises the actual current Garage entry and its carousel's input priority.

The compressed diagnostic-driving loops deliberately run hundreds of physics ticks between render frames, which produces `RACE_HITCH` diagnostic lines. They are functional evidence, not Android frame-time or thermal measurements. The ordinary-rewind fixture temporarily removes the local-lesson marker only inside the test and cancels the real panel; shipping tutorial races keep rewind disabled.

Restart/reload the client to load the scripts. Owner review of instruction pacing, marker clarity and overall feel remains, along with physical phone/tablet touch, safe-area and sustained-cost acceptance. Phone/tablet attachment was not checked and no physical-device test, APK build/install, owner-process restart, purchase, social send, live mutation or deployment was performed by this task.
