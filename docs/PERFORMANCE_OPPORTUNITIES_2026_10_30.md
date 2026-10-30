# Performance investigation — 30 October 2026

This investigation builds on the existing performance work in the shared workspace. It does not establish a whole-game frame-rate, memory, or phone improvement.

## Editor grid allocation

`TrackCompiler.compile` now creates and fills a blank cell grid only when it is needed. A cached raster already supplies the cells, and a built-in base track supplies both cells and deck data. The previous initial arrays were immediately replaced in those cases. The same raster, base-track copies, stamping, cache and cancellation paths remain in use.

An instrumented, reconstructed task-start comparison passed 27 checks, including complete compiled track field equality for blank and built-in tracks on raster hits and misses and invalid-document rejection. The existing raster golden test passed 8 checks. In the exercised 228 × 188 blank cached grid this avoids allocating and filling 171,456 bytes per compile. In the 340 × 204 built-in case it avoids 554,880 bytes across the two discarded arrays. These are calculated cumulative allocations avoided, not measured process peak or resident-memory reductions.

The broader `test_editor_remaining.gd` reported 130 checks and one failed snapped-drag assertion. The same assertion and total reproduced with the task-start compiler in a separate project. The underlying canvas issue remains unresolved. Headless runs emitted a Windows root-certificate-store diagnostic.

The comparison helper is `game/tmp/test_raster_allocation_20261030.gd`; the reconstructed baseline is `game/tmp/raster_allocation_baseline.gd.txt`. Runs used the pinned Godot 4.7.2 console executable through `scripts/run_no_crash_dialog.py`, isolated `APPDATA`, and `--headless --path game --script`, with the helper or `res://tests/test_compiler_raster.gd`. The broad baseline used a separate copied project under `tmp/raster-baseline-isolated-project-20261030`.

## Garage saved-picture reads

Saved Garage PNGs are decoded synchronously during warm-up. An experiment moved those reads to the existing worker. A fresh Compatibility seed passed 68 checks, and a stable-revision restart reproduced the saved picture hashes with zero captures and observed 296 ms startup. However, it failed the existing immediate-entry check after memory-pressure eviction (130 passes, one failure). The control run had a changed visual fingerprint and recaptured six pictures, so it cannot establish a speedup. The experiment was reverted; asynchronous reads remain a candidate only if the recovery and navigation contract can be preserved and the improvement measured. A cancelled background read may also be treated as a missing picture and trigger an unnecessary capture after suspension; this needs a focused reproduction. Logs are under `docs/evidence/garage-ready-pictures-2026-10-28/menu-read-*`.

## Gameplay CPU candidate

An isolated headless experiment reused the vehicle soil-contact probe and cached the heading vectors. It compared 20,000 patterned contact cases and found equal results; eight alternating 50,000-call blocks measured medians of 17.483 and 8.884 microseconds per call. The approximately 8.6 microsecond per physics tick saving is about 0.017 ms per nominal 60 Hz frame at 120 ticks per second. This is a component benchmark, not a frame-rate or device measurement. Full canonical trajectory parity was not tested, and the replay-critical runtime code was not changed. The diagnostic script is `build/soil-probe-review/probe.gd`; its run emitted certificate-store and log-file access diagnostics.

## Larger outstanding costs

The existing [native shader investigation](NATIVE_SHADER_PREPARATION_2026_10_28.md) attributed most of a 5.2-second cold race frame to native compile/link calls. Its separate-process compiler prototype still failed first-draw and optional-memory gates and is not enabled. [Editor measurements](TRACK_EDITOR_FIXES_2026_10_28.md) also retain long cold practice and road-width preparation waits. These historical measurements describe their documented snapshots, not a fresh measurement of the current workspace.

Particle overdraw, Storm's full-screen effects and trail-buffer uploads are possible further frame-cost targets, but require scene-specific CPU/GPU and device attribution before changing their quality or behavior. Repeated device scenarios should distinguish cold and warm caches, monitor frame-time percentiles and memory over time, and preserve replay and visual checks. No physical-device run was performed in this investigation.
