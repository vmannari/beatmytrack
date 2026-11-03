# Garage idle-work audit — 2026-11-01

Inspected the remaining Garage elements and fixed three further sources of unnecessary drawing. These are local source changes; no tablet/device query or test, APK, deployment, live backend access, owner-save/process mutation or main Git index write was performed. Tablet FPS and owner acceptance remain unmeasured.

| ID | Finding and resulting behavior |
|---|---|
| GIA01 | Audited static props/lights/shaders, car/trophy/record views, washing feedback, carousel, paint thumbnails, selected-part previews, News polling and hidden sections. All eight actual Garage sections settle without repeated main-view or reflection requests. |
| GIA02 | Snow kept redrawing an unchanged room while the affected car was outside every camera. Logical melting and persistence continue; subsequent uniform changes no longer invalidate a view that cannot contain them. First material installation/removal still receives its bounded preparation draws. |
| GIA03 | A stationary wash cursor rebuilt its canvas drawing every frame. It now rebuilds only when pointer/gesture state changes. Its displayed pixels remain exact. This saves CPU drawing construction; the retained cursor is still presented by the normal canvas renderer. |
| GIA04 | Holding the wash tool over empty space requested main/floor/car-reflection draws despite having no contact, foam or droplets. Invisible empty feedback no longer emits redraw signals or marks the scene animated. Genuine contact, visible tails and the final disappearance still update. |

The snow visibility cache uses the world bounds of actual weathered meshes, including wheels and fitted parts, against the main camera and both reflection cameras. Persisted wash-volume bounds intentionally omit some fitted geometry, so they are not used for culling. Camera, viewport, car, fitted parts, weathering ownership and reflection settings participate in the cache; explicit rendering invalidation clears it. A car visible only in reflection still updates. New material installation/removal remains a rendering-state change, preserving first-use material/shadow preparation even when the car is off camera.

The controls load the archived task-start versions of both runtime sources in their own processes. At 1280×720 on desktop Compatibility, a 30-frame observation gives:

| Situation | Task-start behavior | Final behavior |
|---|---:|---:|
| Snow melting outside the record view | 58 render requests; about 354,286 triangles/frame | 0 render requests; retained image only, 2 triangles/frame |
| Stationary wash cursor | 29 canvas `_draw()` executions | 0 canvas `_draw()` executions |
| Wash held over empty space | 58 render requests; about 402,610 triangles/frame | 0 render requests; retained image only, 2 triangles/frame |
| Visible or reflection-only snow | Continues drawing | Continues drawing |
| Settled clean car, trophy and record views | 0 repeated requests | 0 repeated requests |

Render-request counters include the existing bounded settling callbacks, so they are not counts of displayed frames. These desktop counters are evidence of removed work, not tablet FPS or energy measurements. Actual snow amounts continue falling in the off-camera samples.

Other inspected elements:

| Element | Audit result |
|---|---|
| Workshop shell, furniture, tools, plant, drain, lamps | Static geometry/lighting; no continuous scene animation found. Garage shaders contain no `TIME`-driven animation. Their lighting/shading still costs work whenever a legitimate render occurs. |
| Trophy/achievement display | Rebuilt on service/navigation updates; no spinning or pulsing idle loop. The settled Trophy section submits no repeated 3D requests. |
| LP sleeves and car/paint/part transitions | Input-driven, bounded tweens; hidden LP controls finish their motion. |
| Carousel and paint icons | Retained 2D pictures; native misses are bounded and visibility-gated. Paint-icon processing stops when its queue drains. |
| Selected-part detail | One-shot extra camera only when model state changes and the photo is visible. |
| News/Friends/ranking | Visibility/section-gated refresh; the News poll is one-shot, bounded and stopped when hidden. |
| Garage page layout and condition checks | Still polled while the page is visible. They remain possible CPU-profiling targets; this audit does not claim they are free or change their responsive layout behavior. |

Final verification:

- `test_garage_idle_elements.gd`: **48 checks, zero failures** with native Compatibility and **48/0** with desktop Vulkan Mobile. These include all eight sections, all five snowy cars at three zoom levels, reflection-only snow, hidden/finished effects, moving/stationary cursor, empty-space washing and byte-exact retained/forced image comparisons.
- Stationary cursor pictures match the corresponding renderer's original control. The off-camera room and all five frozen snowy-car images match a forced redraw exactly in the final runs. Captures include eight Garage sections, five cars, the cursor and the record-room comparison for each renderer.
- Existing hose regression: **81/0**, headless. Existing exterior/wash-surface regression: **45/0**, headless.
- Existing washing-animation regression: **139 checks, four failures**. The task-start source control reproduces all four: serialized completed-wash restart and three forklift pick/contact/clean assertions. No existing assertion was changed or weakened.

The initial stricter image checks exposed three one-level highlight differences after installing snow materials outside the view. Adding material-installed state to the render key retains that initial preparation draw; the unchanged exact-pixel assertions pass afterward. An earlier Mobile control also retained a frozen-Kart image mismatch; it is not counted as a passing control. Final source passes both renderers. Initial diagnostics and captures remain in the evidence folder.

All native launches use pinned Godot `4.7.2.stable.official.ed1daf0bf`, the scoped crash-dialog wrapper, empty `BMT_API_URL` and workspace-only `APPDATA`/`LOCALAPPDATA`. Normal local access was required for Godot's previously established Windows certificate-store startup limitation. Commands run include:

```powershell
$idleGodot = 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe'
python scripts/run_no_crash_dialog.py -- $idleGodot --path game --rendering-method gl_compatibility --position 10000,10000 --script res://tests/test_garage_idle_elements.gd -- --baseline --output=res://../docs/evidence/garage-idle-audit-2026-11-01/control
python scripts/run_no_crash_dialog.py -- $idleGodot --path game --rendering-method mobile --position 10000,10000 --script res://tests/test_garage_idle_elements.gd -- --baseline --output=res://../docs/evidence/garage-idle-audit-2026-11-01/control/mobile
python scripts/run_no_crash_dialog.py -- $idleGodot --path game --rendering-method gl_compatibility --position 10000,10000 --script res://tests/test_garage_idle_elements.gd -- --output=res://../docs/evidence/garage-idle-audit-2026-11-01/after/gl_compatibility
python scripts/run_no_crash_dialog.py -- $idleGodot --path game --rendering-method mobile --position 10000,10000 --script res://tests/test_garage_idle_elements.gd -- --output=res://../docs/evidence/garage-idle-audit-2026-11-01/after/mobile
python scripts/run_no_crash_dialog.py -- $idleGodot --path game --rendering-method gl_compatibility --position 10000,10000 --script res://tests/test_garage_wash_animation.gd -- --evidence-root=res://../docs/evidence/garage-idle-audit-2026-11-01/wash-animation-gl
python scripts/run_no_crash_dialog.py -- $idleGodot --path game --rendering-method gl_compatibility --position 10000,10000 --script res://tests/probe_garage_wash_idle_control.gd -- --evidence-root=res://../docs/evidence/garage-idle-audit-2026-11-01/wash-control
python scripts/run_no_crash_dialog.py -- $idleGodot --headless --path game --script res://tests/test_garage_hose.gd -- --evidence-root=res://../docs/evidence/garage-idle-audit-2026-11-01/hose
python scripts/run_no_crash_dialog.py -- $idleGodot --headless --path game --script res://tests/test_garage_wash_surfaces.gd
```

Only two runtime sources change: `game/ui/car_showroom.gd` and `game/ui/garage_wash_effect.gd`. Supporting files are the focused audit, archived-runtime control, this document and status entries. Geometry, materials, physics, washing rates, masks, UI layout and backend code are unchanged. The previous Garage LOD/record work and concurrent soundtrack/model changes are preserved.

[Results and hashes](evidence/garage-idle-audit-2026-11-01/report.json), [native captures](evidence/garage-idle-audit-2026-11-01/after), [logs](evidence/garage-idle-audit-2026-11-01/logs) and [scoped source checkpoint](evidence/garage-idle-audit-2026-11-01/task.patch). The checkpoint passes forward/reverse checks and exact-content round trips in an isolated Git directory; the main index is unchanged. The world-bound test uses Godot's documented [AABB support point](https://docs.godotengine.org/en/stable/classes/class_aabb.html#class-aabb-method-get-support).
