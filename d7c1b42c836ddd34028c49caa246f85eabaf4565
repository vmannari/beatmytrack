# Checkpoints cover the complete road and kerbs

2026-11-03. Local implementation of the owner's Star screenshot report.

| Requirement | Result |
| --- | --- |
| CWR01 | Every measured gate and finish spans the connected physical road, painted edge and kerbs. Inside shortcut fitting cannot reduce that minimum. |
| CWR02 | Additional 3 m candidates around folded spline hairpins retain an ordered legal corridor and block the reproduced large off-road bypasses. Ordinary recovery remains 2 m. |
| CWR03 | Rules24 fences cached layouts and new verification contracts. Native client/server geometry exports include the same asymmetric finish spans. |
| CWRQ01 | Independent surface sampling, edge crossings, shortcut sweeps, actual five-lap driving/replay, bridge controls and native comparison views. |

The old capped raster scan stopped before the physical edge, and the spline selector could subsequently shorten the inside span below the road itself. The initial Star-only regression reproduced **160 failures in 456 checks**. At the hairpin corresponding to the supplied screenshot, the inside marker span was 12.6723 m despite the connected road/kerb cross-section extending about 23.45 m. The final native span is **23.50 m**; the outside span changes from 6.125 m to 6.20 m.

`RoadGateCoverage` intersects the actual cleaned road contours/painted edges and kerb triangles with the gate plane, merges connected intervals and stops before disconnected returning branches. Spatial bins bound polygon lookup during preparation. The raster measurement no longer has an authored-width cap; upper-layer measurement uses actual deck cells rather than `cell_at`'s permissive empty-upper-cell fallback. Spline fitting can remove recovery space, but always retains the measured road span. Finish measurement, presentation and the server descriptor share the same asymmetric bounds.

Widening gates alone reopened several grass-gap hairpin cuts. Additional candidates around folded corners close those gaps without globally reducing recovery. Star now selects 105/107 gates in forward/reverse directions, compared with 38/38. The existing common-lane ordering still excludes intersecting requirements which would force artificial loops. New first preparation costs about 4.47/4.60 seconds in one headless observation; retained preparation took 64/1071 microseconds. These are local observations, not a phone/loading-speed claim.

Recovery lanes which themselves miss a mandatory apex no longer contribute partial approach protection to the notice envelope. This corrects the first new 4.86 m warning delay to 3.66 m, within the unchanged 4 m spline limit. No checkpoint is credited by notice logic.

## Changes

Runtime: `game/race/track_session.gd`, `spline_gate_corridor.gd`, `race_rules.gd`, new `road_gate_coverage.gd`, and `game/backend/runner.gd`.

Server contract: `backend/bmt_backend/contracts.py`, `rivalry.py`, `trajectory_verifier.py`. Current manifests upgrade through rules23 to rules24; historical board documents remain immutable. Rules23/24 retain the existing numeric-only server gate tolerance.

Tests: new `game/tests/test_checkpoint_road_coverage.gd` and `capture_checkpoint_road_coverage.gd`; existing checkpoint rules, bridge-exit version fence, notice-latency, Star consistency, backend gate-contract, verifier and manifest-upgrade fixtures. `scripts/run_checkpoint_coverage_checks.py` isolates profiles and bounds test execution; `scripts/verify_checkpoint_coverage.py` checks exported native geometry and canonical replay offline.

Two old Star expectations deliberately rejected an entirely paved taper path because of the shortened inside span. Those expectations now require the newly covered path to complete with no warning, verify that it stays paved, and retain the other wide-profile rejection checks. The prior notice fixture's exact-width equality was replaced with full-road containment; ordinary centres, directions, progress and layers remain checked exactly. Deep-cut, recovery, layer, timing and replay limits were not relaxed.

## Actual verification

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. Automated Godot children use `scripts/run_no_crash_dialog.py`; native captures and runner tests use workspace-local APPDATA/LOCALAPPDATA profiles.

| Check | Actual outcome |
| --- | --- |
| Road/kerb/finish coverage, independent support-polygon sampling and outermost legal crossing | **2787/0** headless, **2787/0** Compatibility, **2787/0** desktop Mobile |
| Retained hairpin regression | **65/0** headless and each desktop renderer |
| Real Compact Star drive | Five laps, **47712 ticks**, zero collisions and warnings; quantized replay exact, each renderer |
| Star shortcut sweep | 2575 forward + 2569 reverse candidates saving at least 3 m; zero accepted large off-road cuts, zero accepted beyond-recovery cuts, each desktop renderer |
| Ordinary road gates | **266/0** |
| Star consistency / ordinary recovery | **62/0**, **32/0** |
| Bridge layers / notices / Knot / notice latency / Compact rewind | **259/0**, **537/0**, **252/0**, **604/0**, **591/0** |
| Native before/after views | **7/0** each renderer; four final PNGs, same physical gate and fixed camera |
| Native server integration | Nine historical hairpin bypasses rejected; real five-lap sparse proof accepted; **47712** canonical ticks accepted under rules24 |
| Focused backend gate/speed/start/history contracts | **34 passed** |
| Disposable SQLite historical manifest upgrades | **40 passed**, 67 deselected |
| Scoped Ruff / Python compilation / task diff whitespace | Pass, with inherited Ruff issue below excluded from a clean claim |

The shortcut sweep still allows two small reverse recovery excursions saving approximately 3.49 m and 3.45 m; both remain within ordinary recovery. It also allows entirely paved cornering. This is not an exhaustive proof over every possible trajectory or creator document.

Actual command groups, expanded commands, durations and exit codes are retained in the `results*.json` receipts and `logs/` under [the evidence directory](evidence/checkpoint-road-coverage-2026-11-03/). Principal commands:

```powershell
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --version
python scripts/run_checkpoint_coverage_checks.py test_checkpoint_road_coverage
python scripts/run_checkpoint_coverage_checks.py test_checkpoint_notice_latency test_star_checkpoint_consistency test_checkpoint_forgiveness test_knot_checkpoint_notices
python scripts/run_checkpoint_coverage_checks.py test_hairpin_checkpoints:gl_compatibility test_hairpin_checkpoints:mobile test_checkpoint_road_coverage:mobile test_star_checkpoint_shortcuts:mobile
python scripts/run_checkpoint_coverage_checks.py capture_checkpoint_road_coverage:gl_compatibility capture_checkpoint_road_coverage:mobile
& '.tools/backend-secure-venv/Scripts/python.exe' scripts/verify_checkpoint_coverage.py
```

From `backend/`:

```powershell
& '../.tools/backend-secure-venv/Scripts/python.exe' -m pytest tests/test_hairpin_gate_contract.py tests/test_trajectory_integrity.py tests/test_verifier.py::test_spline_gate_rules_do_not_relabel_historical_boards -q
& '../.tools/backend-secure-venv/Scripts/python.exe' -m pytest tests/test_review_reliability.py -k 'full_manifest_upgrade and sqlite' -q
```

## Controls, intermediate failures and limits

The existing bridge-entry fixture has **9/258** vehicle transition failures; bridge-exit has **80/2527**. Saved pre-change gate/corridor controls reproduce the **same failure messages exactly** (9 and 80), without script errors. These suites are not counted as passes. [Control comparison](evidence/checkpoint-road-coverage-2026-11-03/inherited-bridge-failures.json). The first dynamic entry control needed a corresponding untyped local rewind adapter; its earlier type-error run is retained and excluded. These adapters live only in evidence/build files.

The first additional inside-margin restriction broke ordinary recovery and a real edge drive; it was removed. Initial 1 m candidates were reduced to 3 m after the shortcut sweep passed. A trial admitting all width-expanded, loop-trimmed lane profiles reopened large off-road cuts and was rejected. The first expanded coverage fixture needed a guard for Silmukka's missing independent `start_line`. Initial native captures omitted the staged world's render preparation; final captures run that exact preparation and show actual road/car geometry. These were fixture or intermediate findings, not final passes.

Godot reports the sandbox's Windows root-certificate-store restriction; initial manual commands also encountered user-log access errors. Final runner logs use explicit workspace paths. Offline native integration accepts only the specifically recorded certificate diagnostic and fails on other engine errors. No clean environment-log claim is made.

Ruff reports an existing `SIM102` at `backend/bmt_backend/rivalry.py:276`, reproduced with the saved pre-change source. Other changed backend files pass scoped Ruff. A broad backend review run was interrupted; only the completed focused and SQLite upgrade results above are claimed. The unavailable local catalog manifest prevented the optional catalog-wide fixture; no live catalog was fetched.

No physical-device query/test, APK/export/install, owner save/process change, authenticated backend/live mutation, deployment or main-index write was performed. Concurrent workspace work remains. Reload/rebuild, matching authorised client/API/worker rollout, owner driving/appearance acceptance and physical-device performance remain outstanding.

[Native before/after gallery](evidence/checkpoint-road-coverage-2026-11-03/comparison.html). [Task-only source checkpoint and hashes](evidence/checkpoint-road-coverage-2026-11-03/checkpoint.json).
