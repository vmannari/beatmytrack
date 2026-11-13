# Volt rear smoothing — 8 November 2026

VRS01 removes the separate overlapping trailing-lip sheet and forms its modest rise in the rear deck. VRS02 closes the tail to that deck and gives both surfaces identical GPU normals along their shared edge. VRS03 seats the rear lamp housing, light guide and hatch joints along the rounded tail's outward slope, keeping X fixed to preserve both hatch gaps. The former Z-only offset let the lamp housing intersect the body triangles near the almost horizontal upper tail. Hiding the lamp assembly in an isolated native capture removed the remaining sawtooth band; the final offset removes it with the lamps visible.

[Before](evidence/volt-rear-smoothing-2026-11-08/before/top-rear-silver.png) · [Revised rear](evidence/volt-rear-smoothing-2026-11-08/final-source/top-rear-silver.png) · [Rear quarter](evidence/volt-rear-smoothing-2026-11-08/final-source/rear-quarter-silver.png)

The production source change is in `game/vehicle/electric_reference_body.gd`. Cabin, glass, door/fender detail, other kit builders, fictional identity, livery and handling remain unchanged. The separate lip's removal reduces the actual full model by 512 triangles and the reduced model by 128, before the small shadow-proxy change. The 62 existing hood mesh binaries are byte-exact to task start; only their source manifest needs renewal. The source baker loses a pre-existing misindented, redundant quality assignment. The Volt shadow baker now disables restoration, waits for model readiness and builds unbatched source geometry before collecting the five frames.

## Verification

All checks use pinned Godot `4.7.2.stable.official.ed1daf0bf`, private task APPDATA/LOCALAPPDATA and empty `BMT_API_URL`. Commands and complete output are in `docs/evidence/volt-rear-smoothing-2026-11-08/*.log`. Reproduce with `python scripts/run_volt_rear.py <log-name> res://tests/<script>.gd <engine flags> -- <script flags>`.

| Check | Result |
| --- | --- |
| New rear geometry, prepared full/reduced | 4,308 checks, zero failures: one deck layer, finite mesh data, exact joins, exact packed edge normals, symmetry, actual lamp/body triangle clearance. |
| Same regression against task-start source | 4,308 checks, 238 failures. The original overlap, shading seam and lamp intersections are detected. |
| Rear lamp gaps/braking | 98 checks, zero failures. |
| Driving | 72 checks, zero failures. |
| Actual Garage/equip/reload/race flow | 54 checks, zero failures on each desktop renderer. |
| Final native source/bank captures | Compatibility full/reduced and desktop Mobile full/reduced, silver/blue, overhead/close overhead/rear quarter. |
| Actual prepared assembly captures | Full-detail Compatibility and reduced desktop Mobile, six views each; zero procedural mesh-cache entries in each car. |
| Complete prepared preflight | 468 resources, 1,925 checks, zero failures. |
| Exhaustive Volt prepared/source comparison | 1,792 checks, zero failures; all 120 full/reduced modules, bases, fitted race models and restoration paths. |
| Catalogue provenance | Five exact native images, 155 current source hashes. |

The initial edge-normal assertion compared compressed GPU normals to an uncompressed analytic vector with a 0.00001 tolerance. Measured encoding error is about 0.0000805. The final assertion compares the actual two GPU buffers for exact equality, preserving a stricter seam-continuity requirement without comparing different encodings.

The historical `test_volt_reference_redesign.gd --prepared` retains its triangle-budget failure: final 160 checks/1 failure, full/reduced 120,068/41,678 triangles. Archived task-start geometry reproduces the budget failure at 120,580/41,812 (plus its expected current-manifest mismatch). No budget is raised. The older rear-window fixture retains two exact `ReferenceRear` preservation failures because this task deliberately reshapes that panel. Its glass/deck, roof/seal, curvature and all other checks pass (62 checks/2 failures). These assertions are retained.

The legacy hood-bank fixture reports 351 checks/1 failure: its sharing assertion explicitly makes the first car full-detail but leaves the second at the newer reduced default. It therefore compares two different quality meshes. All exact 62-mesh geometry, manifest, fallback and independent-paint checks pass. The fixture is retained unchanged; direct before/final binary comparison independently confirms every hood resource is exact.

The first `scripts/dev.ps1` capture was rejected by its existing certificate-error fail-fast handling; the native captures were written, but that launch is not reported as a passing test. Subsequent runs use the existing crash-dialog wrapper with the same pinned executable and retain the Windows root-certificate diagnostic. An initial PowerShell execution-policy failure is retained; the isolated build-identity helper is then invoked with per-process `ExecutionPolicy Bypass`. A process-command-line query was denied; no owner process was stopped. Intermediate prepared checks rejected stale electric metadata while the lamp/source/hood/shadow refresh was still being finalized. Final prepared receipts are recorded separately.

The final complete refresh is `python scripts/prepare_volt_rear.py --resume-models --prefix=final-`, following `bake-source-lamps`, `bake-hood-final` and `bake-shadows-final`. The complete `final-prepared-check.log` passes all 1,925 checks, replacing the intermediate 249 stale-metadata failures. The pipeline then validates all five catalogue images and 155 source hashes. Both source manifests pin body SHA-256 `c20c00207a601d938b9b5ce9a2841b0a10d7aaa3e5243235191ac8bac33bbc07`.

## Delivery and limits

Prepared source meshes, five Volt shadow frames, four bases, 120 modules, the Volt Garage scene and catalogue provenance are refreshed in dependency order by `scripts/prepare_volt_rear.py`. New tests/capture tools and the runner are task-scoped. The evidence retains task-start inputs, intermediate failures, native isolation captures, final views and a task-only checkpoint. The main Git index is not written, and unrelated concurrent edits are preserved.

[Task-only checkpoint](evidence/volt-rear-smoothing-2026-11-08/task-only-checkpoint.zip) contains changed files before/after, with both sets of archive hashes verified. [Text patch](evidence/volt-rear-smoothing-2026-11-08/task-only-checkpoint.patch) and [delta manifest](evidence/volt-rear-smoothing-2026-11-08/task-delta.json) make the scope reviewable without staging or committing concurrent work.

The checkpoint contains 188 changed paths, including the generated models/pictures and task tools/documentation. Its text patch passes `git apply --check --reverse` against the final workspace. No patch is applied to the live tree or main index. The final exhaustive comparison is `python scripts/run_volt_rear.py modules-final res://tests/test_modular_car_assets.gd --headless -- --vehicle=electric --all-kits`.

The catalogue baker refreshes the five active pictures. Its task-start provenance was already behind the current shared showroom/car and Compact source revisions; the rebake also reconciles those existing differences. The three inactive catalogue PNGs remain exact. No other vehicle builder is edited by this task.

Reload the PC client to see refreshed models. Owner appearance acceptance and physical-device appearance/performance remain unverified. No device query/test, APK, owner save/process change, real purchase, live/backend request or deployment was performed.
