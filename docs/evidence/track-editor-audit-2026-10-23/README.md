# Track editor audit evidence

Investigation dated 23 October 2026. The report is [TRACK_EDITOR_AUDIT_2026_10_23.md](../../TRACK_EDITOR_AUDIT_2026_10_23.md).

The GDScript files in this directory are diagnostic probes outside the shipping game. `run.ps1` verifies the pinned engine, redirects user storage to `build/track-editor-audit-2026-10-23`, disables backend configuration and uses synthetic fixture libraries. It deliberately avoids the build-identity mutation normally performed by `scripts/dev.ps1`.

- `audit.gd`: main complexity, editor operation, rendering, layout, save and three-cycle practice probe.
- `detail.gd`: selected-handle cost, maximum-paint history/copy/compile, crowded topology and five biome opens.
- `interactions.gd`: follow-up with handler-plus-frame input cycles, avoiding ambiguity in the main probe's post-handler waits.
- `winter-parity.gd`: isolates the existing grouped Winter rendering failure from individual object geometry and palette availability.
- `road-materials.gd`: records current/specialized material roles without changing the failing legacy assertions.
- `results-*.json`: numeric evidence; `.log` files preserve engine/test output.
- `reviewed-source/*.txt`, `source-manifest.json`: reviewed source snapshot and original recorded hashes. These are evidence, not compatibility implementations.
- `fixtures-*`, `detail-fixtures-*`, `interaction-fixtures`: synthetic local documents only. They are separate from owner data.

Reproduce from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-editor-audit-2026-10-23/run.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-editor-audit-2026-10-23/run.ps1 -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-editor-audit-2026-10-23/run.ps1 -Graphical -Detail
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-editor-audit-2026-10-23/run.ps1 -Graphical -ProbeName interactions.gd
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-editor-audit-2026-10-23/run.ps1 -ProbeName winter-parity.gd
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-editor-audit-2026-10-23/run.ps1 -ProbeName road-materials.gd
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-editor-audit-2026-10-23/run.ps1 -Regression
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-editor-audit-2026-10-23/run.ps1 -Regression -TestName test_editor_workflow
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-editor-audit-2026-10-23/run.ps1 -Regression -TestName test_local_draft_publication
```

The main headless and Compatibility runs completed with no probe failures. The detail and follow-up interaction probes also completed. Existing checks: workflow 252, preparation 270, practice 54, save/review 69, remaining 120, start line 27, local publication 31 passed their assertions. Incremental objects has 1 failure/47 checks; road pieces has 24 failures/377 checks. The report explains their scope. No live backend test was used.

Retained setup corrections: the first probe used the wrong enum type/order for render-info queries; the first fixture added a StringName key through dot assignment, which the plain-JSON validator correctly rejected. Those timings were excluded and the initial logs are retained. The corrected `start_line` uses a String key. Initial headless layout reads occurred before containers settled; graphical layout probes subsequently wait four process frames. The initial publication test name was wrong; the corrected local test passed 31 checks. A concurrent native/compiler signature edit briefly prevented parsing before both definitions matched; the corrected rerun passed. An earlier workflow shutdown exception in concurrently edited condition persistence did not repeat in the final workflow run. The startup certificate-store error is an offline sandbox/environment diagnostic, not a completed network test.

The workspace changed concurrently. Main measurements precede later paint-exclusion/cancellation work; follow-up interactions and final local publication checks follow it. Compare source manifests before treating any of these numbers as a baseline for a later build. No physical device, 30-minute soak, human study or Mobile renderer run was performed by this audit.
