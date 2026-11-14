# Forklift operator fittings supported — 2026-11-13

FOS01 adds a floor-mounted seat plinth beneath the existing suspension.
FOS02 adds a dashboard pedestal carrying the console and steering-column assembly,
and a hydraulic-control console beneath all three lever gaiters. All three supports
overlap the operator floor and their fittings. Seat height, controls and handling
are unchanged. The only authored production change is five added lines in
`game/vehicle/forklift_model.gd`; existing dark finish and rounded-box detail tiers
are reused. FOS03 refreshes shadows, prepared assemblies and native photographs.

The new connection regression checks both full and reduced procedural models:
24 checks pass. Building from the saved task-start source rejects all six missing
supports across the two detail tiers (12 checks, six failures). The retained
model-finish regression passes 101 checks.
The final Garage/race fixture passes 131 checks and the production parser passes
all 557 scripts. These run with current sources and the stale-scene fallback;
they do not erase the separately retained prepared-cache or native App findings.

Native corrected views:

- [Compatibility side](evidence/forklift-operator-supports-2026-11-13/after/side.png)
- [Compatibility front quarter](evidence/forklift-operator-supports-2026-11-13/after/front-quarter.png)
- [Vulkan Mobile side](evidence/forklift-operator-supports-2026-11-13/after-mobile/side.png)
- [Close lever console and dashboard](evidence/forklift-operator-supports-2026-11-13/operator-close/controls.png)

The initial `before` capture ran while the builder was being edited and displays
the corrected model. It is **not** a qualified before-image; its four PNGs were
byte-identical to the corrected captures and were removed as duplicates. The original source
is preserved in `before/forklift_model.gd`, and the baseline regression uses it.

Commands run through the pinned `scripts/dev.ps1`, with private disposable test
profiles and an empty backend URL, are recorded beside each log in
[the evidence folder](evidence/forklift-operator-supports-2026-11-13).
The reproducible entry points are:

```text
python scripts/run_forklift_operator_supports.py support-final res://tests/test_forklift_operator_supports.gd
python scripts/run_forklift_operator_supports.py support-baseline res://tests/test_forklift_operator_supports.gd -TestArgument --baseline
python scripts/run_forklift_operator_supports.py geometry res://tests/test_forklift_model_finish.gd -TestArgument --evidence-dir=res://../docs/evidence/forklift-operator-supports-2026-11-13/finish
python scripts/refresh_forklift_operator_supports.py
python scripts/refresh_forklift_support_dependencies.py
python scripts/repair_forklift_operator_supports.py
```

The baseline command intentionally exits with six failures. The broader native
`test_forklift_app_entry.gd` Vulkan attempt has 23 checks and two failures:
“kart customisation opens first” and “forklift kit options”. These navigation and
option-count findings are retained; this model task does not claim that test passes.

The first 1,724-check prepared comparison retained 110 cache-hit failures. A later
attempt retained 118 cache-hit failures, including eight base-cache misses. Its
geometry/attribute comparisons do not report a difference. The native diagnostic
identifies a changed shared `game/vehicle/super_rally_model.gd` source and a mismatched
stored build revision. A source-fence comparison also finds concurrent
`game/ui/rivalry_simple_car.gd` edits. Both concurrent sources are preserved.
The broad dependency refresh was stopped at its task-owned Python orchestrator;
the in-progress Electric bake was allowed to finish. These attempts do not qualify
global prepared readiness. The scoped repair runner records a separate input
snapshot and source-equality receipt.

The scoped repair's initial stability fence rejected continuing shared-source
changes before starting any bake. The final concurrent-source receipt also records
Challenger mesh-buffer writes. No prior shared source/binary was restored. Current
global or scoped prepared readiness is unqualified; normal source-checkout guards
reject stale scenes and use procedural construction, which contains the supports.
The final cache-enabled close capture must therefore not be read as evidence of
a cache hit. The refresh scripts now put livery photographs before dependent bakes.

The source-only patch covers the production builder, connection regression,
capture entry point and task runners. Its forward and reverse application is
byte-exact and does not stage the main index. The patch and receipt are retained
beside the logs; the scratch tree is disposable build output.

No device query/test, APK/export, backend request/deployment, owner-save or
owner-process change was performed. Owner appearance acceptance after reload and
device qualification remain. Generated build output is subject to the owner’s
seven-day/20 GiB retention policy.
The completion cleanup command ran successfully with zero deletion failures;
24.084 GiB remains because recent/protected output exceeds the 20 GiB target.
Its concise receipt is retained as `build-cleanup.json`.
