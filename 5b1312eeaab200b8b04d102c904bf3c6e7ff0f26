# Guardrail ground terminals and post spacing — 27 October 2026

GF01–GF03/R01/Q01: Metal Guardrails now rise smoothly from ground at the exposed beginning and return to ground at the exposed finish. The normal taper spans three model metres per end, shortening for a small isolated section. Connected interior joins, branches and closed loops stay at normal height. Post spacing follows the whole connected run, independently of the editor's short fitted chords, with a three-metre target adjusted evenly to the available length. Scale still scales the model and its spacing.

The new presentation helper discovers matching endpoints within 2 mm and stations posts across each chain. Its temporary profiles never enter the document, compiler, collision cells or saved files. Editor mesh keys include the profiles, so moving/deleting/restoring a neighbouring section updates the remaining ends. Original wooden and wire fence mesh arrays remain exact. Winter snow is fitted to the same lowered rails and shortened posts. These are native geometry changes; no generated image assets are used.

Runtime files: `game/track/guardrail_visual.gd` (new), `creator_prop_visual.gd`, `prop_equipment.gd`, `winter_prop_finish.gd`, `native_track_visual.gd`, and `game/editor/placed_object_batches.gd`. The focused native fixture is `game/tests/test_guardrail_ends.gd`; its shared editor/race triangle comparison remains unchanged.

| Verification | Actual outcome |
| --- | --- |
| Focused headless | 89 checks, zero failures |
| Focused desktop Compatibility / desktop Mobile | 95 checks each, zero failures; five native captures each |
| Shared prop refinement | 849 checks, zero failures |
| All-script parser | 1,346 scripts, zero failures |
| Original spline regression | 6,645 checks, four capacity-fixture failures and corresponding null-object errors |
| Same spline assertions with a valid current-limit fixture | 6,645 checks, zero failures |

Actual terminal mesh vertices fall from the original 1.030 m abrupt face to 0 m, before the renderer's existing 14 mm ground offset. A 24 m run has eight posts instead of twelve per-section posts. The actual road-edge curve has twelve fitted sections, thirteen posts and a minimum 3.121 m post separation. Connected race/editor meshes have identical triangle multiplicity, colours, positions and normals, including after a deletion and restoration. Native App gestures exercise road-edge placement, exact WIP recovery data, one-step Undo and Redo.

Review the [new curved run](evidence/guardrail-ends-2026-10-27/accepted-mobile/pine-run-closeup.png), [matched original](evidence/guardrail-ends-2026-10-27/accepted-mobile/pine-original-closeup.png), [winter taper](evidence/guardrail-ends-2026-10-27/accepted-mobile/winter-run-closeup.png), [actual editor](evidence/guardrail-ends-2026-10-27/accepted-mobile/editor-curved-run.png), and [editor terminal](evidence/guardrail-ends-2026-10-27/accepted-mobile/editor-ground-terminal.png). These are native desktop captures. The Mobile renderer ran on the desktop GPU; no physical-device test or attachment check was performed.

Reproduce the retained commands through `python docs/evidence/guardrail-ends-2026-10-27/run_checks.py LABEL SCRIPT MODE`, where SCRIPT is `test_guardrail_ends.gd`, `test_prop_refinement.gd`, or `test_script_parse.gd`, and MODE is `headless`, `gl_compatibility`, or `mobile`. The harness uses the exact `godot-version.txt` engine, disposable offline profiles and Dummy audio. The development wrapper initially identified the correct engine but encountered execution-policy/default-user logging restrictions, then a stale concurrent JumpProfiles class cache. A pinned import refreshed that cache. The wrapper's incidental build-identity regeneration is excluded from this task's patch.

The original spline test resizes the object array to 94 null entries and expects the former 96-object limit. Its four failures are retained unchanged. `make_capacity_control.py` creates an evidence-only fixture using valid low-cost objects to fill the current limit minus two; every original assertion, including the exact two-section prefix, remains intact. Initial closeup test runs had a SubViewport/Node3D type error; corrected runs and the failed attempts are retained. A later Compatibility attempt completed 95 assertions but logged a concurrent, unimported `sign_in_mark.svg` dependency failure; this is retained as a failed run. A second pinned import refreshed that asset before the final native rerun. Offline runs also retain the existing sandbox certificate-store error, recorded separately from assertion outcomes.

Commands, logs, hashes and limits are in [report.json](evidence/guardrail-ends-2026-10-27/report.json). [task.patch](evidence/guardrail-ends-2026-10-27/task.patch) contains only this task's runtime/test sources and UIDs against exact task-start copies; `git apply --check --whitespace=error-all` passes in a disposable local repository with normalized text line endings. Concurrent editor/road/jump and other work is preserved. The main Git index was not staged or committed.

Reload the client/editor to use the new geometry. Owner appearance and physical-device acceptance remain. No APK, real authentication/purchase, backend mutation/deployment, owner-save mutation or owner-process restart was performed.
