# Track editor usability and object-quality improvements — 28 October 2026

The editor now picks nearby objects predictably, supports precise placement and group editing, keeps short tool instructions visible, and preserves recognizable props in dense views. The actual native views and checks below cover the changes requested after the [UX/UI review](TRACK_EDITOR_UX_UI_REVIEW_2026_10_28.md).

| Review item | Result |
|---|---|
| UX01 — settings reset when inspecting | The current Properties workflow preserves variant, size and placement. Variant changes retain size/run defaults, and the family card renders the selected variant. A carried-over run setting can no longer break a non-run inspector. |
| UX02 — unreliable picking | Actual footprint hits precede nearby targets; distance determines priority, with topmost order breaking coincident ties. **Next object** and Tab cycle overlaps. The original cone-neighbour case now selects the tapped cone. |
| UX03 — unclear next step | Persistent contextual guidance, named road parameters with values/units, a direct **Save** action, clearer autosave wording, and disabled Start line on an empty map. Q/E also rotate selected objects or groups. |
| UX04 — anonymous overview boxes | Small planning meshes retain cabins, wheels, glass, roof shapes, barrel bands, cone colours and wood details. Every selected group member retains detailed geometry. **Map → Detailed scenery** restores the complete view. |
| UX05 — coarse placement and repetitive edits | **Snap: 1 m / 0.25 m / off** controls actual placement and dragging. **Multi-select** adds/removes members by tapping; dragging moves the group. Copy, Delete and rotation each form one undo step. Common bounds preserve group spacing, and admission rejects a whole copy before mutation. |
| UX06 — misleading previews and materials | Larger object cards show the selected family variant. Winter uses Snow/Packed snow and matching swatches; Desert distinguishes Sand/Loose sand. The concurrently delivered separate jump cards remain intact. |
| UX07 — irrelevant Area controls | Area omits brush size and brush shape. Undo point, Cancel and Place are visible together; point count and button availability update with the draft. |
| UX08 — small captions, weak hierarchy, clutter | Larger captions with ellipsis, clear Copy/Multi-select/Next object icons, a contrasting surface toolbar, and quiet planning ground without decorative flecks. The detailed view restores those ground decorations. |

The existing contextual Properties inspector, separate jump catalogue, admission/cancellation work and history/road preparation improvements were already being developed concurrently. This pass integrates them and preserves their current implementation. The checkpoint excludes 21 unrelated concurrent edit operations, including Garage work, jump selection changes and further Properties layout changes.

## Native appearance

Nine views were saved with each renderer, including the actual App at 1280×720, its controls in a 960×540 window with the 1280×720 logical layout, dense/full detail comparisons, and production model thumbnails. These are engine captures.

| Experience | Earlier review | Updated view |
|---|---|---|
| First entry | [Before](evidence/editor-experience-2026-10-28/mobile/01-first-entry.png) | [After](evidence/editor-ux-improvements-2026-10-28/mobile/01-first-use.png) |
| Object properties | [Before](evidence/editor-experience-2026-10-28/mobile/04-options-reset-size.png) | [Preserved Boulder choices](evidence/editor-ux-improvements-2026-10-28/mobile/03-preserved-boulder-properties.png) |
| Dense overview | [Earlier fixture](evidence/editor-experience-2026-10-28/mobile/09-dense-normal-overview.png) | [Updated fixture](evidence/editor-ux-improvements-2026-10-28/mobile/06-dense-overview.png) |
| Group editing | — | [Selection and actions](evidence/editor-ux-improvements-2026-10-28/mobile/04-group-selection.png) |
| Winter area | — | [Contextual controls](evidence/editor-ux-improvements-2026-10-28/mobile/05-winter-area-controls.png) |
| Shared model quality | [Original catalogue sheets](evidence/editor-experience-2026-10-28/mobile/atlas-02.png) | [Updated model study](evidence/editor-ux-improvements-2026-10-28/mobile/09-model-study.png) |

The earlier and updated dense fixtures contain different arrangements; they demonstrate readability rather than a pixel-matched performance comparison. Complete Compatibility and desktop Mobile observations are in each renderer's `report.json` under the evidence folder.

## Shared object meshes and resource cost

The utility car and van gain a slight roof crown with closed side joins. The wreck has an open recessed engine bay, a crushed asymmetric roof and sparse glazing/frame damage. Cliffs retain their base envelope but have tapered upper ends, varied strata and less repeated colouring. The hut, garage and grandstand control meshes remain exact in the independent before/after comparison.

| Model | Before triangles | After triangles |
|---|---:|---:|
| Utility car | 3,046 | 3,052 |
| Van | 3,188 | 3,194 |
| Wreck | 2,856 | 2,960 |
| Cliff | 206 | 206 |

The actual horizontal envelopes and ground contact stay within their previous bounds. The car/van roof gains 35 mm; the cliff's sampled overall height falls from 4.242 to 4.081 m. Geometry and normals are finite. The shared visual version and thumbnail version invalidate their old visual caches.

The 12 checked overview meshes use 68–600 triangles. They remain batched by kind/material; detailed source meshes stay retained, so this is a rendering-work reduction, not a claim that their memory was freed. Twenty-five affected biome/model memory estimates were refreshed from the real scene and batching streams; the largest increase is 4.685%. The existing 128 MiB admission budget and object/tyre limits remain in force. See [prop-quality.json](evidence/editor-ux-improvements-2026-10-28/prop-quality.json) and [cost refresh](evidence/editor-ux-improvements-2026-10-28/prop-cost-refresh.json).

A synthetic 1,000-object picking sample used 60 calls per run. Desktop p95 was 7.52–7.95 ms across the final runs. This measures picking alone under local test load; it does not establish a frame rate or Android cost.

## Verification

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. Every run uses a disposable workspace profile and offline backend configuration. No owner saves or owner processes were used.

| Check | Actual outcome |
|---|---:|
| New actual-App UX checks, headless | 74 assertions, 0 failures |
| Same UX checks, Compatibility | 81 assertions, 0 failures; 9 captures |
| Same UX checks, desktop Mobile/Vulkan | 81 assertions, 0 failures; 9 captures |
| Actual prop geometry and all changed memory estimates | 55 assertions, 0 failures |
| Existing editor workflow | 254 assertions, 0 failures |
| Existing editor T05–T11 / T11–T15 | 321 / 305 assertions, 0 failures |
| Existing creator capacity, including six-car 4,096-object fixture | 2,730 assertions, 0 failures |
| Existing editor review regressions | 69 assertions, 0 failures |
| Existing Properties / editor preparation / refinement | 80 / 269 / 33 assertions, 0 failures |
| Original App regression | 141 assertions, 0 failures |
| Preferred `scripts/dev.ps1` App dependency parse | Exit 0 |
| Changed translation copy | 24 messages × 12 languages; 288 exact-copy/placeholder checks pass |

Commands are reproducible through:

```powershell
python docs/evidence/editor-ux-improvements-2026-10-28/run_checks.py res://tests/test_editor_ux_improvements.gd headless
python docs/evidence/editor-ux-improvements-2026-10-28/run_checks.py res://tests/test_editor_ux_improvements.gd gl_compatibility
python docs/evidence/editor-ux-improvements-2026-10-28/run_checks.py res://tests/test_editor_ux_improvements.gd mobile
python docs/evidence/editor-ux-improvements-2026-10-28/run_checks.py res://tests/test_editor_prop_quality_2026_10_28.gd headless
python docs/evidence/editor-ux-improvements-2026-10-28/check_preferred.py
python docs/evidence/editor-ux-improvements-2026-10-28/build_checkpoint.py
```

The same runner receipts record the retained test commands, exits and source hashes. Final UX runs record matching runtime hashes before/after execution. The preferred parser's generated project/build identity was archived and restored only after checking it still exactly matched this task's generated output.

Initial findings are retained: the non-run inspector accessed a missing placement hint; the old cancelled-drag path released the pointer but left `dragging=true`; and the first model-cost checks exceeded old estimates. All three were corrected without changing original regression assertions. Initial walkthrough-harness errors involved a private thumbnail field, a nonexistent Map helper, a wrong variant family, and exact binary comparison after JSON float rounding; corrected checks use the real APIs and serialization precision. The new cancellation check verifies rollback and full capture release. Direct native logs retain the sandbox root-certificate-store diagnostic with zero script errors in the passing runs.

Broader checks remain limited. The full script scan reports one historical Garage fixture that calls missing `_build_wash_requirement()` (`parking_hall_before`); the preferred current-App parse passes. The global localization gate reports 1,056 obsolete/untranslated entries, and four of 22 translation tooling tests reject the concurrently added tab-delimited `track_editor_review_fixes.tsv` through the existing pipe-delimited loader. This pass's 24 affected messages validate independently; it does not claim complete project localization. The first Python unittest invocation used the wrong import directory; the recorded corrected invocation runs from `scripts/`.

## Review checkpoint and remaining acceptance

[task-only.patch](evidence/editor-ux-improvements-2026-10-28/task-only.patch) contains 13 runtime files, two focused regressions and the directly authored translation rows. It was forward-checked and applied in an isolated temporary Git repository, compared exactly with the intended result, reverse-checked there, and reverse-checked against the current workspace. The root index was not staged or committed. Generated catalogue derivatives retain concurrent source inventory and are excluded from this source-only patch. [checkpoint.json](evidence/editor-ux-improvements-2026-10-28/checkpoint.json) identifies the excluded concurrent operations and all included hashes.

Reload/rebuild is needed to use these changes. Owner appearance/feel acceptance and physical Android touch, layout, memory and performance checks remain; **no physical-device query or test was performed**. No APK, deployment, backend mutation, auth/purchase action or owner-process restart was performed. Multi-selection currently uses taps; it has no marquee/lasso control. Dense-view detail still deliberately simplifies distant small props.

The machine-readable [report](evidence/editor-ux-improvements-2026-10-28/report.json) records the files, command receipts, source stability and limitations.
