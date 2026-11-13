# Garage reflections restored (2026-10-27)

The owner reports missing Garage reflections and lower visual quality. The task-start native reproduction confirms the cause: the responsive opening exposes unshaded temporary geometry while it prepares the original materials. The temporary floor and pedestal do not use the planar reflection shaders; car paint, glass, room lighting and shadows also differ. Passive pointer movement postpones that preparation.

The opening now keeps the existing stock photograph visible until the original live studio has finished its material draws and four settling draws of the main view and both reflections. It no longer creates or displays the flat substitute geometry. The page, seven cards and navigation still open before native construction. Car requests coalesce while covered, deferred paint/parts requests survive, hidden preparation pauses, and retained ready studios remain reusable. Passive hover no longer resets the idle timer; deliberate button, key and touch/drag input still does.

| Requirement | Result |
| --- | --- |
| GRR01 | First revealed live image uses the original geometry, materials, lighting, glass, shadows and both planar reflections. |
| GRR02 | Immediate picture/cards, latest preview, deferred tools, account ownership, cancellation and retained studio behavior remain. |
| GRR03 / R01 / Q01 | Native first-live captures, actual reflection pixel differences, original failure evidence, isolated profiles, commands and a task-only patch. |

This supersedes the preceding task's deliberately lower-quality early live view and its early-tools-before-full-materials timing requirement. Orbit and tools begin with the complete original studio. This is a quality correction with an explicit latency tradeoff: it does not claim equally early live interaction or hitch-free cold compilation.

## Measurements

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, RTX 3090 desktop, 1280 × 720, dummy audio, isolated APPDATA and an empty API URL. “Mobile” means the desktop Vulkan Mobile renderer, not a physical phone.

| Actual App, fresh shader profile | Navigation callback | Actual incoming picture | Full-quality live ready | Maximum active orbit frame |
| --- | ---: | ---: | ---: | ---: |
| Compatibility | 87.8 ms | 498 ms | 25.67 s | 8.58 ms |
| Desktop Mobile | 68.3 ms | 841 ms | 8.86 s | 9.67 ms |

The standalone Compact first-live test takes 26.96 s Compatibility / 8.91 s desktop Mobile with fresh profiles. Reusing the Compatibility shader profile in a new process reduces full-quality live readiness to 2.63 s. The existing ready studio is still retained within the App. Individual cold driver compilation can stall input; these runs do not establish phone latency, memory, frame-rate or owner acceptance.

## Implementation

Only two runtime sources change: `game/ui/garage_opening_showroom.gd` stops using the temporary facade, retains the opening cover, settles the original targets before reveal and distinguishes hover from deliberate input. `game/ui/garage_first_draw.gd` records all held originals separately from the shrinking pending-work queue so their visibility can be restored after every batch completes or the latest selection cancels that generation.

Original material resources are never rewritten. Geometry, shaders, camera, model caches, photographs, physics, economy, saves and backend sources are outside this patch. The old facade helper remains unchanged for historical diagnostics and is no longer used by the opening. Light copies and the temporary 64 × 64 preparation viewport are released; the steady studio retains its main view and two bounded reflection views.

The actual-App opening fixture now requests rapid previews during the covered preparation and asserts complete quality at first interaction. The former temporary-copy tools fixture is replaced with explicit covered-request, original paint/parts sweep, hidden suspension and destruction checks. The retained reflection fixture waits for the actual progressive studio before keeping all its existing pixel, orbit, replacement, visibility and persistence assertions.

## Verification and evidence

Run `python docs/evidence/garage-reflections-restored-2026-10-27/run_checks.py LABEL SCRIPT MODE`. The runner records the executable, full arguments, environment, output, duration and exit status under that label. `BMT_CACHE_PROFILE=fixed-native` explicitly reuses that isolated shader profile; otherwise labels have separate profiles. The initial `scripts/dev.ps1` invocation encountered the host execution policy; its process-scoped retry through `powershell.exe -NoProfile -ExecutionPolicy Bypass` successfully checked the opening script using the pinned engine. No machine execution policy was changed.

- Task-start focused reproduction: 12 headless / 18 Compatibility checks, five expected failures each. Native first-live capture visibly lacks reflections and lighting.
- Corrected focused checks: 12 headless / 18 Compatibility / 18 desktop Mobile pass. A separate cached Compatibility process also passes all 18.
- Native reflections change 46,150 pedestal-region / 22,837 floor-region pixels in Compatibility and 45,996 / 22,837 in desktop Mobile, using the retained 0.025 difference and greater-than-100-pixels bounds. Reflection images follow orbit. The corrected first-live and subsequently settled Compatibility captures are byte-identical PNGs.
- Actual-App opening: 195 headless / 199 Compatibility / 199 desktop Mobile checks pass. Existing callback <250 ms and active-orbit <150 ms bounds are unchanged; latest car, no equip/save on preview, retained studio and owner replacement checks remain.
- Deferred and live tools: 15 headless / 16 Compatibility checks pass, including original paint/parts animation, reflection retention and destruction during paused preparation.
- Retained actual-App reflections: 26 Compatibility checks pass, keeping the existing pixel bounds, orbit, car replacement, hide/show, drain, pedestal and no-cosmetic-save assertions.
- Full App: final 141 checks pass. The initial run has 141 passing assertions but five dummy-renderer RID errors and is retained as a failed run. The same suite with exact task-start runtime scripts restored only in memory passes cleanly; the corrected runtime recheck also passes cleanly. The initial RID errors are not represented as a reproduced baseline failure.
- Script parser: 1,319 scripts pass. Final retained/native results and scoped checkpoint verification are recorded in [report.json](evidence/garage-reflections-restored-2026-10-27/report.json).

Every engine run reports this sandbox's certificate-store error; the runner records it separately from test errors. The initial malformed multi-operation patch was rejected without changing files, and was reapplied as valid sequential patches. An optional Python image-comparison attempt could not import Pillow; no dependency was installed and no pixel-equivalence claim is derived from that attempt.

Native proof: [reproduced flat first view](evidence/garage-reflections-restored-2026-10-27/baseline-native/first-live.png), [corrected first live view](evidence/garage-reflections-restored-2026-10-27/fixed-native/first-live.png), [actual-App corrected Garage](evidence/garage-reflections-restored-2026-10-27/app-opening-native/live-studio.png), [desktop Mobile](evidence/garage-reflections-restored-2026-10-27/app-opening-mobile/live-studio.png).

Reload/rebuild and owner acceptance of restored appearance and the longer covered cold preparation remain. No device attachment check or physical-device test, APK, real authentication/purchase, owner-save/live backend mutation, deployment, main-index staging/commit/merge or owner-process restart was performed. Concurrent work is preserved and excluded from the checkpoint.
