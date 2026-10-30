# Performance review fixes — 30 October 2026

This pass reduces several identified costs without changing the intended pictures, road geometry or race physics. It does not establish that cold Garage startup or first editor practice is fast enough on a phone.

## Changes

- Challenge track compilation runs on the existing background worker using the validated download, with selection and loading fences checked again after the await.
- Race presentation shares a conservative spatial query for wheel and contact-shadow speed-bump samples. Exact height evaluation remains unchanged; disabled contact lighting skips its shadow update.
- Race render preparation groups geometry by its existing material/program key instead of repeatedly scanning the full queue. Its bounded initial draw and covered final draw remain.
- The editor compiler stamps only the grid perimeter. Grass verge generation batches collected triangles while preserving triangle order, details and cancellation checkpoints.

## Verification and measurements

Tests used pinned Godot 4.7.2 with isolated offline workspace profiles. Headless App: 141 checks, zero failures; challenge race flows: 38, zero; challenge result action: 27, zero. Bump presentation: 1,925 exact comparisons, zero; contact shading: 26, zero; speed bumps: 9,868, zero. Render buckets: 41, zero in headless and Compatibility. Editor graphics preparation: 90, zero headless; 91, zero in each of Compatibility and desktop Mobile, including pixel checks. Editor perimeter: 86, zero; compiler raster: 8, zero; grass emission: 48, zero; native road geometry: 115, zero. Windows sandbox runs emitted a root-certificate-store diagnostic.

Synthetic headless samples are component measurements, not whole-frame or phone claims. On a 642-bump fixture, six full scans took 7,883 microseconds per sample versus 156 microseconds with the spatial candidate path. For 2,500 meshes in 50 program groups, queue handling took 20.0–29.3 ms before and 2.55–3.02 ms after, excluding GPU draws. Alternating grass-emission samples took 7.41–7.68 ms before and 5.64–6.00 ms after for 2,160 triangles. Full 96-piece editor road preparation samples were sequential and cache-sensitive; they do not demonstrate an end-to-end latency improvement.

The historical speed-bump contract fixture reported 689 failures among 1,818 checks; an isolated control without this task's track-query addition produced the same ordered failures. The speed-bump width fixture reported 346 passing assertions but also emitted editor script errors, so it is not a clean pass. The prepared-race test reported one failure among 85 checks: it expects a removed local document to be unavailable, but this fixture is also present in the current bundled exact-hash catalogue. These failures are not claimed as fixed.

## Remaining work

The Garage capture-reuse prototype changed three of six native picture hashes against a matched control and was reverted. The prior capture source was restored exactly. Further work should profile cold shader, rendering, capture and resource construction costs without sacrificing exact owner appearances. First practice and road-width completion also remain open: the existing [editor report](TRACK_EDITOR_FIXES_2026_10_28.md) records substantial cold rendering and road-preparation waits. No Android device test, deployment, owner-save mutation or main-index operation was performed in this pass.
