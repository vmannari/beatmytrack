# First task for Astra / Codex — P0 handling laboratory

Read AGENTS.md, master chapters 01–05 and 14, and requirements G01–G03/R01. Build only a playable handling laboratory. This is a development brief, not a report that implementation has occurred.

## Deliver
A pinned Godot standard project with one fictional car and one reference circuit whose baseline lap takes about 15–20 seconds. Four laps, standing start, ordered directed checkpoints, separate lap/total timing and immediate restart. Keyboard plus two-thumb steering/throttle/brake; an adjustable alternative steering layout. Include a simple car-data resource, grip/slip/heading telemetry and capture of quantized input ticks.

Use a real 3D presentation with a stable high-oblique overhead Camera3D matched to ui/Camera_contract.json. Show part of the compact track, no horizon, with 1.15x scene framing relative to the selected screenshot and unchanged car/road geometry. Use simple 3D stand-ins during the handling gate; do not substitute a chase camera. Keep car orientation legible. First investigate steering response, controlled sliding, countersteering, throttle influence and braking. No polished environment, currency, progression, account, store, network or league implementation.

## Tests to implement
Checkpoint order; wrong-way crossing; finish after exactly four laps; no timing during countdown; swept fast gate crossing; pause/reset marks practice; safe touch release; frame rate does not change simulated elapsed time. Produce one replay-format experiment and explicitly report any divergence rather than claiming cross-platform determinism.

## Build loop
Document the discovered executable paths, engine version and Android prerequisites. Provide scripts for import/check, tests, debug export, ADB install and launch. Keep release keystore/passwords outside the repo. Execute only commands available in the environment. When no physical phone is accessible, deliver the APK/build instructions and flag the phone acceptance as untested; never invent a device result.

## Owner acceptance session
Drive 20 minutes on a phone. Compare steering layouts; test corner entry, slide recovery, tight hairpin and wall contact. Record 10 consecutive lap times, misses caused by hidden touch zones and whether retry feels immediate. Adjust handling before adding content. After owner approval, ask ten external testers for a short instructed run and observe voluntary retries without coaching. The proposed continuation gate is seven choosing at least five more tries; record the result honestly.

Return changes, actual test outputs, known shortcomings and the next small handling experiment. Do not continue to P1 automatically.


## Next visual subgate: P0-V, not automatic scope expansion
After initial handling approval, build one reference-quality car/corner with the selected cel-shaded materials, a garage view and the race HUD. Compare renderer options, capture the matched frame and a complete lap, and profile on a real phone. Re-estimate full art/content effort before P1 content production. This package supplies no Godot project or production meshes.
