Deep car geometry review — 2026-11-14

The best remaining low-visibility target is redundant height subdivision in straight cylinders. A disposable prototype removes 4,440 triangles from the Forklift without changing the radial outline or caps. Adding radius-aware simplification of small round fittings raises that saving to 7,128 triangles. Hidden faces, flat number-plate lettering and the personal ghost offer separate opportunities. No production models, generators, prepared assets, tuning or quality settings were changed by this review.

**CDR01 — Current models and scope.** The pinned engine is `4.7.2.stable.official.ed1daf0bf`. All six stock and six sample fitted cars load their actual prepared base; every fitted case records four prepared module hits. The source-piece fixture applies the current static/coarse recipes before inspection and matches each production stock master count. The final inventory passes 790 checks with zero failures. Fitted counts are Rally 29,730, Kart 25,944, Forklift 35,380, Volt 26,472, Hover 31,324 and Challenger 36,778. These sample builds are not every possible kit combination.

The current Challenger stock master is **39,368**, following concurrent refinements. The earlier coarse report's 25,918 is a historical snapshot; this review does not restore that geometry. Main-body contours, glazing, paint, wheels and the Kart driver's articulation remain important visual constraints.

| Stock car | Current master | Remove cylinder height rows | Combined small fittings | Combined reduction | Enclosed / zero-area faces |
| --- | ---: | ---: | ---: | ---: | ---: |
| Rally | 21,884 | 696 | 1,416 | 6.47% | 56 / 244 |
| Kart | 24,554 | 192 | 320 | 1.30% | 11 / 0 |
| Forklift | 34,484 | 4,440 | 7,128 | 20.67% | 820 / 0 |
| Volt | 21,042 | 672 | 1,056 | 5.02% | 0 / 0 |
| Hover | 22,068 | 0 | 0 | 0% | 0 / 0 |
| Challenger | 39,368 | 512 | 576 | 1.46% | 122 / 58 |

Combined fittings includes height-row removal, so those columns must not be added. Hidden-face counts can also overlap fitting work. The six masters together contain 163,400 triangles; cylinder rows account for 6,512 and the combined hardware candidate for 10,496. A sum across six different cars describes catalogue geometry, not a single race frame.

**CDR02 — What can be removed with little visual value.**

1. **Straight-cylinder height rows: first priority.** Existing reducers set `CylinderMesh.rings = 1`; the pinned engine also accepts **zero**. Zero keeps one straight side strip between the two end rings. The Forklift has 227 source cylinders, so this small oversight accumulates. The prototype preserves radii, radial segment count, height, caps, materials and bounds. It does not change a tyre's circular outline. Tiny raster differences remain, so this is not a pixel-identity claim. This matches [Godot's cylinder documentation](https://docs.godotengine.org/en/stable/classes/class_cylindermesh.html): height subdivisions have no visual effect without vertex deformation. A production change should keep deforming geometry excluded and cover stock/fitted outputs before publication.

2. **Small circular fittings: second priority.** Cylinders with radius at most 6 cm use eight radial sides rather than twelve; existing planar 96-segment rings use 24 segments below a 12 cm radius, otherwise 48. Outer/inner radii, widths and caps remain. This changes circular outlines slightly, so it has more appearance risk than removing height rows. The largest combined saving is Forklift 34,484 → 27,356. Rally becomes 20,468, Kart 24,234, Volt 19,986 and Challenger 38,792. Hover has no eligible source pieces. Use these measurements for the tested stock models, not a universal percentage for fitted cars.

3. **Enclosed faces and exact zero-area triangles: useful cleanup.** The conservative search finds 1,009 enclosed triangles and 302 strict zero-area triangles, with a union of 1,311. Examples include Forklift beam/rod ends and chain anchors, buried Rally roof faces, and Challenger paint/dark faces. Occluders must be opaque, closed, consistently wound and convex; every removed triangle lies at least 0.5 mm in model coordinates inside one qualified solid (0.44 mm at the sampled 0.88 world scale). Candidates must share render layers and the same body/wheel/steering/fan/kit frame, with compatible shadow casting. Driver/morph geometry is protected. All 24 enclosed-face native comparisons are identical across the **whole image**, including real directional shadows. Zero-area removal is exact in 11/12 images; the remaining Compatibility image differs by one pixel, maximum 7/255. This proof covers the sampled stock assemblies and views; fitted variants and moving clearances still need implementation qualification. This is not generic camera-facing backface deletion.

4. **Rally number plate: meaningful follow-up.** Two already-flat `TextMesh` objects cost **1,190 triangles**, 5.44% of the Rally master. At the sampled 720-pixel race projection, the header and registration span at most about 2.6 and 4.6 pixels across eight headings. Bake the same lettering into the existing opaque plate texture to retain close-view text while removing the glyph outlines. Reusing the plate material avoids introducing a transparent overlay and extra material work. This is a source/geometry finding; a replacement texture has not been generated or visually qualified.

5. **Tiny cockpit decoration: lower priority.** Hiding selected gauge needles, pedal ribs, seat stitching and LED internals saves only 26 Kart / 242 Forklift triangles. The native differences are small, but the return is poor compared with retaining their visual cues. Whole-part projection finds many subpixel fittings, but thin triangles can still form a useful silhouette or highlight. Do not remove every triangle smaller than a pixel.

**CDR03 — Ghosts and storage.** PersonalGhost flattens full visible master geometry into one indexed, translucent, non-shadowing mesh, with **no stored LOD levels**. Native prototypes using the actual ghost shader reduce each stock ghost to approximately half its original triangles: Rally 21,884 → 10,912; Kart 24,554 → 12,276; Forklift 34,484 → 17,242; Volt 21,042 → 10,506; Hover 22,068 → 11,034; Challenger 39,368 → 19,683. The prepared-car inventory's alternative index selections differ slightly from these unbatched native selections; both datasets are retained. Error keys 0.02/0.05/0.1 are engine simplifier selection metrics, not independently measured displacement bounds.

Ghost simplification is a separate appearance choice: translucent internal lines and brightness change even when the outside shape remains recognisable. At the distant studio proxy, Mobile car-crop means change by 0.33–1.02 on a 0–255 RGB scale, with 0.87–2.37% of crop pixels changing by more than eight. The Mobile ghost reference/restoration controls pass; Compatibility retains unstable exact controls, with reference/restoration differences up to 8/255 and no changed alpha pixels. These tiny control differences are much smaller than the candidate differences, but the Compatibility qualification still fails. An implementation should prefer a separate offline ghost mesh/LOD and check actual racing overlap before rollout. Deleting opaque-source hidden faces can also change transparent ghost internals, so those two changes need a combined comparison.

Exact encoded-corner checks also identify modest storage savings:

| Stock car | Unique active mesh buffer bytes | Extra vertex packing | Unused vertex compaction | Exact immutable sharing |
| --- | ---: | ---: | ---: | ---: |
| Rally | 804,266 | 0 | 0 | 0 |
| Kart | 1,277,372 | 12,792 | 1,088 | 0 |
| Forklift | 1,557,756 | 0 | 0 | 0 |
| Volt | 628,800 | 2,320 | 0 | 0 |
| Hover | 606,820 | 612 | 4,116 | 0 |
| Challenger | 1,414,416 | 32,864 | 0 | 97,192 |

These are separate experiments and may overlap. Bytes include active unique ArrayMesh vertex/index/LOD/morph payloads and shadow-only meshes; they are not measured process RAM or total VRAM. The current buffer baker excludes Challenger. Sharing candidates require identical encoded geometry/metadata and independent material overrides, preserving paint ownership. Fitted Challenger sharing saves 46,000 bytes. Identical LOD index pruning finds no further saving. A 0.02 shadow-proxy simplification finds no additional reduction either; existing shadows and prior static Kart morph splitting already cover those opportunities. Shader sharing is already implemented.

**CDR04 — Performance interpretation and native evidence.** Fewer triangles reduce geometry processing, index/vertex traffic and potentially repeated geometry in shadow passes. They do not imply an equal percentage improvement in frame rate. The production cars already have LODs and batching: stock colour surfaces are Rally 52, Kart 46, Forklift 26, Volt 38, Hover 19 and Challenger 44; surface counts are not measured draw-call counts. Removing triangles inside those batches generally leaves their submissions in place. Master-only prototype captures deliberately force the master to isolate geometry changes; existing distance LODs can already remove some of that work. Transparent ghost fill, track rendering, shadows, CPU work and shader cost can dominate. [Godot's GPU optimisation guide](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html) distinguishes these costs, and [mesh LOD documentation](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html) explains distance selection.

The native fixtures use 1000×760 frames, front/rear close views and a raised distant studio proxy, with separate reference/candidate/restoration captures. Opaque candidates preserve active surface materials and source bounds. Enclosed faces use real directional shadows; additional fitting runs also enable those shadows. Pixel metrics cover both the car crop and the whole frame, so a shadow outside the body crop cannot disappear from the analysis. Screenshots are inspection evidence, not an actual App/race/device acceptance run or a frame-time benchmark.

| Run | Checks / failures | Meaning |
| --- | ---: | --- |
| Final headless inventory (`geometry-final`) | 790 / 0 | Twelve prepared cases, exact packing/compaction/sharing checks, source counts, hardware/ghost candidates |
| Full Compatibility review (`native-gl-final`) | 380 / 25 | All failures are exact ghost reference/restoration controls; retained, not waived |
| Full desktop Mobile review (`native-mobile`) | 380 / 0 | 57 image pairs and their controls |
| Fittings, Compatibility (`hardware-gl-final`) | 772 / 0 | 30 image pairs and controls |
| Fittings, desktop Mobile (`hardware-mobile`) | 772 / 1 | Kart axial/front restoration differs on 189 crop pixels, max 2/255; candidate evidence retained |
| Fittings with real shadows, Compatibility | 772 / 0 | 30 image pairs and controls |
| Fittings with real shadows, desktop Mobile | Incomplete | Stopped task-owned child after 666 s; Kart restoration finding retained; no final pair manifest/pass |

The completed runs provide 204 native image pairs. Before extra real-shadow runs, the axial candidate's worst car-crop mean is 0.001529/255 and the combined fittings' worst mean is 0.039956/255. At most 0.104% of crop pixels exceed an eight-level RGB change for combined fittings. The completed Compatibility real-shadow fitting run has worst crop means 0.002221/255 axial and 0.039352/255 combined. These are measured differences, not an automatic appearance acceptance threshold. Visual inspection of the native contact sheet finds the fittings candidates retain the car identity and important contours. Ghost internals show the clearer tradeoff. The additional Mobile real-shadow run stopped progressing and was terminated after 666 seconds; its partial images/log and explicit stop receipt are retained, and it contributes no completed comparisons to those metrics.

Evidence: [native Mobile comparisons](evidence/car-deep-review-2026-11-14/mobile-comparisons.png), [Compatibility comparisons](evidence/car-deep-review-2026-11-14/gl_compatibility-comparisons.png), [inventory](evidence/car-deep-review-2026-11-14/inventory.json), [geometric analysis](evidence/car-deep-review-2026-11-14/geometry-analysis.json), [pixel metrics](evidence/car-deep-review-2026-11-14/native-pixel-metrics.json). Left is current; right is candidate. Full native frames and run receipts are beside those files.

Reproduction, from the repository root:

```powershell
python scripts/run_car_deep_review.py geometry-final --headless
python scripts/analyse_car_deep_geometry.py
python scripts/run_car_deep_review.py native-gl-final --rendering-method gl_compatibility
python scripts/run_car_deep_review.py native-mobile --rendering-method mobile
python scripts/run_car_deep_review.py hardware-gl-final --rendering-method gl_compatibility -- --hardware-only
python scripts/run_car_deep_review.py hardware-mobile --rendering-method mobile -- --hardware-only
python scripts/run_car_deep_review.py shadow-hardware-gl_compatibility --rendering-method gl_compatibility -- --hardware-only --shadow-hardware
python scripts/run_car_deep_review.py shadow-hardware-mobile --rendering-method mobile -- --hardware-only --shadow-hardware
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compare_car_deep_review.ps1
```

The initial inventory used an incomplete fitted customisation dictionary and was corrected to use defaults before selecting options. An initial hardware launch exposed a typed-array fixture error and was corrected; the failed receipt remains. Initial/final Compatibility ghost failures remain recorded. No production assertion or appearance limit was relaxed to obtain a pass.

The wrapper isolates APPDATA/LOCALAPPDATA under disposable build output, disables live API configuration, uses Dummy audio and never saves production resources. Per-run fences cover 24,348 inputs including models, configuration, assets and the main-index control. One Compatibility fitting fence records a concurrent `.git/index` change; it is preserved. Final model digests exclude the index so independent staging cannot mask model changes. Both final inventories and both additional real-shadow runs retain the same model digest `d6fc724f499aa939de4725f7749456e2e74dc4ee1a286e56f240e1ae6e51039c`, unchanged within every run. Direct full native invocations have no individual wrapper fence; surrounding inventories and later runs provide the scoped evidence, not an invented whole-tree stability claim. Concurrent Garage, Challenger, loader, effect and documentation changes are preserved.

Recommended implementation order: zero cylinder height rows, guarded hidden/zero-area cleanup, small fittings led by Forklift/Rally, then an opaque number-plate texture experiment. Evaluate ghost LODs separately. Qualify every affected fitted/base/prepared consumer and real race shadows before publishing. Device frame-time gains, every camera/kit, full-quality geometry, actual App behaviour and owner visual acceptance remain unmeasured in this review. No device query/test, APK/export, backend request, deployment, owner-save/process change or task-authored main-index staging occurred.

The review helpers, this report and only the new tracker blocks are preserved in a [source-only checkpoint](evidence/car-deep-review-2026-11-14/source.patch), with [round-trip receipt](evidence/car-deep-review-2026-11-14/source-checkpoint.json). The private checkpoint uses a small source-only repository under disposable build output; the real index is never staged. The prescribed `scripts/clean_build.ps1 -Apply` run reduces build output from 25.84 to 25.24 GiB across five entries; the 20 GiB target remains unmet because recent, protected or locked entries remain. See the [retention log](evidence/car-deep-review-2026-11-14/build-retention.log). Final source/input controls are in [final review validation](evidence/car-deep-review-2026-11-14/final-validation.json).
