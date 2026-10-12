# Tight spline fence correction — 2026-10-07

Requirements **T01–T04, R01, V03/V05, Q01**. The owner's follow-up screenshot identifies a case missing from the first [continuous barrier pass](CONTINUOUS_BARRIERS.md): a normal offset of a tight inside spline bend folds back, leaving crossing fences on the asphalt even though individual rail sections meet.

The retained steep spline reproduces this: the previous generator creates **62 sections/one self-crossing** on one side and **55 sections/two self-crossings** on the other. The correction creates **46 and 47 sections, zero crossings and zero sampled rail points on the asphalt**. The larger regression also checks both lateral edges of every section, including its full selected thickness.

Spline-containing road chains now build the exposed perimeter from the same variable-width sweep used for spline roads. Fence clearance is added to the sweep widths **before** its disk/segment union, so folded inside offsets and hidden return edges disappear together. Placement follows one continuous contour between the selected ends in the selected travel direction. Original spline knots and joined widths are retained; reversing a road chain also reverses their sample indices. Inner grass islands remain separate contours. Coincident taps fit a short perimeter run rather than dropping a full straight panel through a tight bend.

The editor-only cache holds at most four geometry entries and eight clearance variants per entry. Actual desktop first builds for four fixtures measured **25.644–33.465 ms**; repeated queries measured **1.741–2.911 ms**. This is an initial editor build cost, not proof of phone frame pacing. No time, file I/O or cache lookup was added to canonical simulation steps.

## Changed files

- `game/editor/roadside_boundary.gd` and `.uid`: exposed perimeter selection, clearance sweep, directional slicing and bounded cache.
- `game/editor/road_pieces.gd`: spline chain detection, preserved knot indices and the new placement branch.
- `game/tests/test_spline_barriers.gd` and `.uid`: owner-like folded fixture, thick/wide/mirrored/rotated/variable-width roads, both directions, wooden/wire fences/guardrails/concrete, exact joins, full-width asphalt clearance, grass islands, joined/reversed pieces, coincident taps, cap behavior, cache equivalence, unchanged authoring data and actual editor save/undo/redo.
- This document, the earlier barrier document, status/phase records and the evidence checkpoint.

No authoring-schema, physics/rules/compiler version, gameplay camera, prop-mesh or road-rendering change. Existing ordinary road runs and free Line/Curve behavior retain the first pass. Existing placed runs are stored individual objects: **Undo/delete and re-place a crossed run after restarting the app** to apply the corrected generation. Player files are not automatically rewritten.

## Actual checks

All engine commands use the pinned `4.7.2.stable.official.ed1daf0bf` via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with process-local `APPDATA=build/barrier-test-user` and separately injected fixture records/library/cloud roots. Approved elevated execution provides Windows certificate-store access. No service/account writes.

| Actual arguments | Outcome |
| --- | --- |
| `-Action Import` | Exit 0; new helper registered. |
| `-Action TestScript -ScriptPath res://tests/test_spline_barriers.gd -Graphical` | **6,656 checks, zero failures**, actual before/after editor output and save/undo/redo. |
| `-Action TestScript -ScriptPath res://tests/test_continuous_barriers.gd` | **7,715 checks, zero failures**. |
| `-Action TestPieces` | **377 checks, zero failures**; same creator golden `e2119106df24929d541890a8f600e3be7970947471cf09a5eec2db28f8fbc792`, two five-lap drives with zero contacts. |
| `-Action TestWorkflow` | **252 checks, zero failures**. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | **346 scripts, zero failures**. |
| `git diff --check -- game/editor/road_pieces.gd` | Exit 0; existing CRLF normalization notice. |

An intermediate polygon-offset approach removed the original crossings but failed three full-width checks on a narrow mirrored fence. It was replaced with clearance applied before sweep union; those assertions now pass. A diagnostic revision mistakenly checked coverage before subtracting hole contours, producing extra false failures; accounting was corrected without weakening the no-asphalt check. Final results above are actual completed runs, not planned verification.

## Evidence and remaining acceptance

- [Before: folded fence](evidence/spline-barriers-2026-10-07/before/steep-spline-fence-closeup.png).
- [After: exposed perimeter fence](evidence/spline-barriers-2026-10-07/after/steep-spline-fence-closeup.png).
- [After: complete editor view](evidence/spline-barriers-2026-10-07/after/steep-spline-fence.png).

Captures are actual 1280×720 engine output and were inspected. The supplied screenshot guided the reproduction; it is not claimed to be the owner's exact saved track. Pre-edit source, failed/passing logs, a task-only review patch and source hashes are retained under `docs/evidence/spline-barriers-2026-10-07/`.

Owner review on the actual map and physical Android finger feel/performance remain. **No phone/device test, attachment check, export/install, full Validate, backend deployment or production action was performed.** The existing 96-object limit remains. Unrelated physics, soundtrack and rivalry edits were preserved.
