# Forklift high-speed turning - 2026-10-25

FHT01-FHT02/R01/Q01 implements the owner's request for slightly faster high-speed turning. `forklift-4` changes only `lateral_grip` from 42 to 45 and the handling version in `game/resources/cars/forklift.tres`. High-speed turning is already limited by available cornering grip, so increasing wheel angle alone would not meaningfully tighten the existing full-speed circle. Steering input rates, rear-wheel angles, power, braking, maximum speed, dimensions and model are retained.

The accepted forklift-3 source is saved in the evidence folder. Native candidate probes at grip 42/44/45/46 establish the selected modest change. Measurements below use actual velocity-path curvature, at the same powered speed cap, with both turn directions checked.

| Speed | Steering input | Old radius | New radius | Tighter | Old/new 90-degree entry time |
|---|---:|---:|---:|---:|---:|
| 50.4 km/h | 45% | 5.199 m | 5.040 m | 3.06% | 0.825 / 0.808 s |
| 50.4 km/h | Full | 4.668 m | 4.375 m | 6.28% | 0.775 / 0.750 s |
| 66.6 km/h | 45% | 8.209 m | 7.691 m | 6.31% | 0.925 / 0.883 s |
| 66.6 km/h | Full | 8.149 m | 7.606 m | 6.67% | 0.917 / 0.875 s |
| 80 km/h | 45% | 11.772 m | 10.994 m | 6.61% | 1.042 / 0.992 s |
| 80 km/h | Full | 11.758 m | 10.974 m | 6.67% | 1.042 / 0.992 s |

Steady-circle radii and entry-turn times are separate measurements. The entry run includes normal steering/yaw buildup and ends when the actual travel direction has turned 90 degrees. Low-speed circles at 10.8 and 28.8 km/h stay within one percent of the prior tune; straight acceleration, speed cap and full braking are tick-exact across 1,800 paired steps. Actual top speed remains 79.9999969482422 km/h, within float tolerance of 80. Tail swing increases by less than 1.5 degrees in all twelve high-speed entry cases and settles after steering release. The rear-steered vehicle naturally has larger body/travel angles than an ordinary front-steered car; this is not a claim of zero sideslip.

The new native regression covers twenty steady turns at partial/full left/right input, twelve real quarter-turns, recovery, speed retention and exact replay at 120 Hz / 30 Hz batches. Its baseline reports 112 checks / 13 expected failures before the change; the current tune passes all 112. Existing assertions remain. `test_forklift.gd` updates its version pin and adds an actual-Game assertion that the complete selected configuration reaches the race.

The config hash is `495947f7424e92c8b14f69c1de5b3a05bb2ab0ce85c4898c0f858e73b3d35003`. Only the Forklift vehicle entry in `backend/tests/fixtures/verified_oval.json` changes. Existing records retain their prior rules identity; the same-track old/new board digests differ. The six other car entries are exact. Shared physics is already `arcade-planar-0.70` at task start from concurrent Electric work, and its source/hash remains exact; this task does not revert it to older status entries.

Actual passing checks: focused turning112, clearance204 (54 bridge traversals and 20 earlier turning comparisons), all-car143 (three complete five-lap fixtures per car, exact replay), shared handling88, rewind61, actual Garage/race111 per renderer, parser1,175/import, and independent server verification of 12,578 Forklift inputs / five laps / 104,810 ms. Backend verifier module: 69 passed / one existing archived-ghost deselection, with its existing Starlette/httpx warning. Exact commands and outcomes are in the report. No extra exclusion or weakened invariant is introduced.

All engine commands use the pinned Godot 4.7.2 wrapper. The new offline export script delegates to the existing canonical fixture generator; the independent local server reader checks the resulting real run, version/hash, other cars and record-identity split. Model and all native artwork sources are unchanged, so no artwork is rebaked.

[Measurements, commands and source hashes](evidence/forklift-high-speed-turning-2026-10-25/report.json) · [Native actual Garage/race](evidence/forklift-high-speed-turning-2026-10-25/native/gl_compatibility/gameplay.png) · [Server receipt](evidence/forklift-high-speed-turning-2026-10-25/canonical-verification.json)

The task-only Git-checkable checkpoint preserves concurrent Kart, Electric, model, translation and backend work without touching the owner's index or HEAD. No attachment check or physical-device test, APK, purchase, live mutation, deployment or owner-process restart was performed. Reload the client; online use needs the matching verifier/configuration rollout. Owner/device driving feel and cost acceptance remain.
