# Kart handling refinement — 2026-10-29

Kart-7 tightens high-speed turns and gives the steering and cornering a more progressive feel. The steering input rate changes from 24 to 14 per second while the existing faster countersteering rate remains. Front and rear grip multipliers rise equally from 1.0 to 1.05; corner energy retention falls from 0.50 to 0.30 so sustained cornering scrubs more speed. The unchanged shared simulation, engine, brakes, maximum speed, and soil settings continue to apply. The new rules identity separates old personal bests.

The same-speed, full-steering circles below measure travelled distance divided by accumulated change in travel direction after three seconds of settling; a controller holds the requested speed. They compare the saved exact Kart-6 resource to Kart-7.

| Speed | Kart-6 radius | Kart-7 radius | Reduction |
| --- | ---: | ---: | ---: |
| 80 km/h | 6.183 m | 5.889 m | 4.76% |
| 100 km/h | 9.634 m | 9.168 m | 4.84% |
| 120 km/h | 13.875 m | 13.207 m | 4.81% |
| 140 km/h | 18.891 m | 17.984 m | 4.80% |

At 20–40 km/h the sampled radii differ by less than 0.15%. To isolate corner scrub, identical Kart-7 configurations apart from energy retention coast for two seconds from 80 km/h at 70% steering: the 0.50 control ends at 48.99 km/h and the 0.30 tune at 41.45 km/h. These are scripted inputs, not a claim about real tyre data. The current arcade simulation already allowed roughly 8 g of sustained lateral acceleration at 100 km/h; tightening the circle increases that figure, so this is a feel improvement rather than a physically realistic kart model.

The pinned Godot 4.7.2 headless tests pass: new matched-speed, symmetry, recovery, countersteer, scrub, straight-line and record identity regression 90/0; historical Kart-5-to-6 comparison 148/0; kart 42/0; cross-car and kart races 113/0; shared handling 88/0; rewind 61/0. The three kart test tracks each complete five laps without contacts and reproduce the same replay. An independently invoked canonical verifier accepts a 12,794-frame generated five-lap race in 106,610 ms and reports the same Kart-7 manifest as the local fixture. The existing backend five-lap replay test also passes.

The headless sandbox emitted a Windows root-certificate-store error even though the offline simulation tests passed. The verifier rejected that engine error in the sandbox, then passed in a normal-access offline run with a disposable APPDATA profile and empty API URL. No device testing or human driving-feel acceptance was performed. Online use requires a coordinated backend verifier rollout matching the new configuration hash `a87f3d73863d8dfe265db4121cd84fbfbadddbae24edd5ac1c21a80fd680e5e7`; no live service was changed.

Run tests with a disposable APPDATA and empty `BMT_API_URL`, using the pinned console executable with `--headless --path game --script res://tests/<script>`: `test_kart_realistic_turning.gd`, `test_kart_high_speed_turning.gd` (pass `-- --evidence-root=res://../tmp/kart-historical-review` to preserve its prior evidence), `test_kart.gd`, `test_cars.gd` (pass `-- --car=kart`), `test_handling.gd`, and `test_rewind.gd`. The historical comparison is pinned to the saved Kart-6 fixture so later tuning does not alter its assertions. The local backend fixture updates only the current kart identity.
