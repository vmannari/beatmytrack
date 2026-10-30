# Garage picture preparation overlap (2026-10-30)

GL01: Saving a generated garage picture no longer blocks construction of the next native picture. One low-priority worker writes an immutable captured image while one showroom builds and renders. A pending read retains priority; a second finished image waits if a write and another queued write are already present. The existing memory estimate now includes queued writes. Cancellation, exact appearance keys and the full live showroom remain in place.

GL02: The showroom, camera, materials, lighting, reflections, saved liveries and picture resolution are unchanged. In the Compatibility control, all six custom-car pixel hashes match exactly before and after. Both renderers also verify exact saved pixels on restart.

R01/Q01: Pinned Godot 4.7.2, isolated records, empty backend URL and RTX 3090 desktop. The focused held-worker regression passed 3/3. The final Compatibility seed/restart passed 68/157 checks; the desktop Mobile seed/restart passed 68/157. These cover complete first-frame pictures, saved appearances, navigation cancellation, retained Garage, pressure recovery and restart. The Mobile seed ran while the two memory-accounting lines were edited; the Mobile restart and final Compatibility pair ran with the final sources. The original restricted Compatibility attempt failed at the Windows certificate store; normal-access isolated runs passed.

The Compatibility seed observed 18.234 seconds before and 3.423 seconds after, with 0.295 and 0.288 seconds on restart. These sequential runs can benefit from warmed driver/OS caches and do not establish a controlled speedup. The desktop Mobile seed observed 31.882 seconds and its restart 14.233 seconds; shader compilation and other startup work remain substantial. These are not Android timings. No phone test was performed; reload/rebuild and owner appearance and performance acceptance remain.

Commands:

```text
python docs/evidence/garage-ready-pictures-2026-10-28/run_pair.py gl_compatibility garage-opt-baseline-outside-20261030
python docs/evidence/garage-ready-pictures-2026-10-28/run_checks.py garage-opt-pipeline-20261030 test_garage_preview_pipeline.gd gl_compatibility
python docs/evidence/garage-ready-pictures-2026-10-28/run_pair.py mobile garage-opt-mobile-20261030
python docs/evidence/garage-ready-pictures-2026-10-28/run_pair.py gl_compatibility garage-opt-verified-20261030
python docs/evidence/garage-loading-2026-10-30/checkpoint.py
```

Receipts, output and first-frame screenshots are in the named directories under `docs/evidence/garage-ready-pictures-2026-10-28/`. The [scoped source patch](evidence/garage-loading-2026-10-30/task.patch) passes forward, reverse and exact-content checks against task-start source; it excludes unrelated work. The wrapper regenerated build identity files, which are excluded from the patch. No owner save, live service, device, deployment or main Git index was changed.
