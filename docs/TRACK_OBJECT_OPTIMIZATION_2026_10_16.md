# Track editor object geometry review and optimization

Owner request, 2026-10-16: inspect all track editor objects for hidden surfaces and unnecessary structure, simplify where possible, and retain their appearance.

TOOPT01 covers every catalog family and variant; TOOPT02 removes only provably enclosed or zero-area triangles; TOOPT03 preserves visible surfaces, authored normals, material runs, outlines, movement and canonical data; TOOPT04 retains bounded shared preparation/caches; TOOPT05 records actual native evidence, costs and remaining device acceptance. The existing camera, collision, local saves, five-lap, road/bridge and authored Egyptian-material contracts remain.

The review covers the starting catalog of 39 families / 43 variants plus the legacy puddle, across all five biomes (220 combinations). Twenty variants benefit. The prepared catalog, including all breakable phases, changes from **85,067 to 82,560 triangles**, removing **2,507 (2.95%)**. A container loses 8.96%; the broken column loses 17.52%. These are triangles referenced by drawing, not a claim of reduced draw calls, large RAM savings or measured phone FPS.

Only complete triangles inside one closed, convex authored box are removed. The test includes the actual octagonal corner cuts and sloping bevels; all three vertices must be inside. A bounded transient grid accelerates these exact tests (8,192 entries maximum, with a broad-list fallback). Open foliage, holes, wire mesh, partial intersections and touching faces are retained. Inked geometry keeps 45 mm of local clearance, covering its 22 mm extrusion at the minimum 0.5 scale. Exact zero-area pole triangles are also omitted.

All original faces contribute to the original final normals before removal. Prepared mesh caches carry small triangle-ordinal plans; final native and editor assembly apply contiguous index slices. Original vertex streams and ordering remain intact, avoiding a GDScript copy of every attribute or extra normal/colour quantization. Editor joins keep full source arrays through shared normal generation, then prune. Cache admission counts retained removal indices; existing 96/32 entries, 32 MiB shared mesh and 16 MiB retained editor-model limits remain. Native kit203 and authored-props5 fence older prepared artifacts.

Winter keeps its ordinal-sensitive snow preparation intact. Movable/damaged props retain exposed undersides, separate phases, collision, replay/rewind and debris behavior. Tyres retain hollow beads and internal surfaces visible through them; fences/guardrails retain their open structures. Other unchanged entries have no safe enclosed-box or zero-area removal in this pass. No silhouette, material, object population, source pigment, collision footprint, camera, track document or canonical rule was deliberately simplified.

The editor review additionally found that overlapping ordinary and Egyptian components could enter the same material cluster. They now have separate cluster passes, preserving the new authored stone shader.

| Kind | Before triangles | After triangles | Removed |
| --- | ---: | ---: | ---: |
| tree | 1590 | 1550 | 40 |
| broadleaf | 1208 | 1208 | 0 |
| bush | 648 | 648 | 0 |
| grass_clump | 60 | 60 | 0 |
| flowers | 492 | 492 | 0 |
| pebbles | 819 | 819 | 0 |
| rock | 234 | 234 | 0 |
| boulder | 234 | 234 | 0 |
| slate | 585 | 585 | 0 |
| cliff | 1025 | 1025 | 0 |
| log | 1440 | 1440 | 0 |
| tyre_stack | 1200 | 1200 | 0 |
| tyre_wall | 7200 | 7200 | 0 |
| barrier | 468 | 468 | 0 |
| guardrail | 576 | 576 | 0 |
| fence | 672 | 626 | 46 |
| wire_fence | 832 | 832 | 0 |
| cone | 572 | 572 | 0 |
| chevron | 452 | 412 | 40 |
| braking_board | 772 | 716 | 56 |
| banner | 964 | 916 | 48 |
| flag | 170 | 170 | 0 |
| light | 356 | 334 | 22 |
| gantry | 2220 | 2220 | 0 |
| jump | 166 | 166 | 0 |
| speed_bump | 1880 | 1880 | 0 |
| oil | 120 | 120 | 0 |
| hay_bale | 2932 | 2892 | 40 |
| crate | 5140 | 5037 | 103 |
| barrel | 820 | 800 | 20 |
| pallet | 1420 | 1390 | 30 |
| parked_car | 3046 | 2970 | 76 |
| van | 3188 | 3112 | 76 |
| car_wreck | 2856 | 2774 | 82 |
| container | 8548 | 7782 | 766 |
| shed | 2210 | 2071 | 139 |
| hut | 1874 | 1747 | 127 |
| grandstand | 4920 | 4720 | 200 |
| egypt_pyramid | 6988 | 6988 | 0 |
| egypt_obelisk | 4458 | 4182 | 276 |
| egypt_column | 3802 | 3708 | 94 |
| egypt_column_broken | 1290 | 1064 | 226 |
| egypt_wall | 4500 | 4500 | 0 |
| puddle | 120 | 120 | 0 |

All measurements use pinned `4.7.2.stable.official.ed1daf0bf`. The actual executable is `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe`, with `--path game --log-file <absolute workspace log> --script res://tests/<script>`. Headless runs add `--headless`; graphical runs use `--rendering-method gl_compatibility --rendering-driver opengl3` or `--rendering-method mobile --rendering-driver vulkan`. The exact scripts, counts, logs, hashes and command forms are in [report.json](evidence/track-object-optimization-2026-10-16/report.json).

| Actual check | Result |
| --- | --- |
| test_prop_optimization.gd ? headless | 665 checks, 0 failures |
| test_prop_optimization.gd ? Compatibility | 1105 checks, 0 failures |
| test_prop_optimization.gd ? Mobile | 1105 checks, 0 failures |
| test_prop_optimization_editor.gd ? Compatibility | 20 checks, 0 failures |
| test_prop_optimization_editor_baseline.gd ? Mobile, eight settled frames | 10 checks, 0 failures |
| test_editor_incremental_objects.gd ? headless | 47 checks, 0 failures |
| test_prop_refinement.gd ? headless | 669 checks, 0 failures |
| test_breakable_props.gd ? headless | 46 checks, 0 failures |
| test_egypt_props.gd ? headless | 79 checks, 0 failures |
| test_script_parse.gd ? headless | 797 scripts, 0 failures |
| Frozen original catalog against concurrent Winter code ? headless | 665 checks, 0 failures |

The differential test renders the actual native object builders in one world, comparing against frozen original builders from before this task, with concurrent Egyptian art corrections mirrored into both sides. There are 440 exact settled object/view comparisons per renderer: four compass views, low views, underside views, near-top and oblique views. All five biomes preserve original document/cell data. The editor fixture also exercises nonuniform scales/rotations, independent runs, duplicate painted containers, intersections and superseded work. Its source positions, pigments and normals compare exactly.

Native evidence: [Compatibility catalog](evidence/track-object-optimization-2026-10-16/gl_compatibility/after-9.png), [Mobile catalog](evidence/track-object-optimization-2026-10-16/mobile/after-9.png), [retained editor](evidence/track-object-optimization-2026-10-16/editor-gl_compatibility/pine-incremental.png), [Mobile original editor](evidence/track-object-optimization-2026-10-16/editor-baseline-mobile/pine-editor-original.png), [Mobile optimized editor](evidence/track-object-optimization-2026-10-16/editor-baseline-mobile/pine-editor-optimized.png). Each renderer directory retains the before/after views and JSON observations.

The unchanged six-frame Mobile native-vs-retained diagnostic records four colour channels differing by one level in Pine and Night. Its geometry/normal checks pass exactly, and its failed pixel assertions are retained rather than relaxed. With eight settling frames, the separate unoptimized/optimized native pairs and unoptimized/optimized editor pairs are byte-exact for all five biomes. First/return images also record original-only first-material warm-up. Compatibility passes the original six-frame checks.

Cold preparation is a real tradeoff: the final headless synthetic first-catalog sums were 371.410 ms original and 494.407 ms optimized. That includes source inspection and cached removal-plan construction. This is desktop callback/build evidence, not a controlled phone latency or FPS benchmark. Cached and retained meshes reuse the plans; no inspection runs during settled rendering.

Initial failures remain in `initial`, `iteration-2`, `initial-mobile`, `initial-editor-gl` and `logs`: default user-log access denial, incorrect tangent stride in an intermediate compaction, early pruning affecting normal generation, mixed-material editor clustering, in-progress external parser errors, and the six-frame Mobile precision observations. The source-normal regression now compares the final source draw indices and every retained authored normal with the original >0.999 requirement; it does not require removed enclosed preparation faces to be drawn.

The legacy object-browser fixture stops on its old `test_button` reference after current UI changes. Its assertions were not changed. The current full incremental editor/save regression passes all 47 checks. No claim of a completely green legacy full-project Validate run is made.

New Winter craft objects arrived from concurrent work during finalization. Their additive changes and subsequent authored-props6 version are preserved. They are outside this pass's 43-variant before/after metrics; a frozen-catalog recheck against the combined code passes 665 checks.

No phone test, Android export/install, backend change or deployment was performed. Owner and physical-phone appearance, sustained frame pacing, memory and loading acceptance remain.

The task-only patch, baseline/final hashes and isolated two-commit Git checkpoint are recorded in the evidence report. Unrelated current work and the main repository index/branch are preserved.
