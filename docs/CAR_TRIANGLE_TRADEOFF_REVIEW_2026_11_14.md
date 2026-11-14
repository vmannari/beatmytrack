# Car triangle counts and further simplification — 14 November 2026

Further reduction is possible, but the useful amount differs considerably by
car. Prefer an additional racing detail level while retaining the current close
Garage mesh. Volt has the clearest remaining automatic master reduction;
Forklift and Rally have the strongest measured opportunity to use their existing
distance levels sooner. These are review candidates, not published model changes.

[Close comparisons](evidence/car-triangle-review-2026-11-14/gl_compatibility-front-comparison.png)
and [distant comparisons](evidence/car-triangle-review-2026-11-14/gl_compatibility-distant-comparison.png)
show current, mild, medium and coarse candidates. Equivalent desktop Vulkan
Mobile sheets and full measurements are in the
[evidence directory](evidence/car-triangle-review-2026-11-14/summary.json).

## Current production geometry

The fresh final inventory constructs all six selectable cars in full/reduced,
stock/fitted configurations and reads their six Garage templates: 30 cases,
zero failures. Each production reduced stock/fitted case hits its prepared base;
each fitted case hits four prepared modules. Racing and the Garage use reduced
geometry. The full column is the retained full-detail construction reference,
not the current Garage cost.

| Car | Full reference, stock | Production reduced, stock | Sampled fitted reduced | Stock visible surfaces | Stock mesh streams |
|---|---:|---:|---:|---:|---:|
| Rally | 102,556 | 26,496 | 37,154 | 52 | 936,762 B |
| Kart | 72,544 | 31,612 | 32,934 | 46 | 1,465,672 B |
| Forklift | 148,048 | 38,136 | 42,252 | 26 | 1,698,384 B |
| Volt | 114,648 | 34,690 | 43,758 | 38 | 974,700 B |
| Hover | 71,932 | 22,548 | 31,324 | 19 | 619,968 B |
| Challenger / Super Rally | 84,924 | 49,968 | 46,538 | 44 | 3,308,208 B |

Triangle counts sum active visible master meshes, including repeated instances,
before automatic distance selection. Shadow-only geometry is excluded. Stream
bytes count unique active mesh resources within each car, including LOD, morph
and shadow buffers; they exclude materials, textures, resource bookkeeping and
driver allocation. They are not process RAM or measured VRAM. Surface counts
indicate submission complexity but are not total frame draw counts.

Fitted samples select the final catalogue choice in each category. They are not
worst-case budgets: a replacement can remove more geometry than it adds, as in
the sampled Challenger. The Forklift and Volt stock counts include changes since
yesterday's simplification report. Do not use that report's older totals as the
current inventory.

## Measured additional master reductions

The same three engine error-key budgets were applied to eligible static meshes
in memory. No vertex positions, normals, UVs, materials, moving frames or surface
counts are intentionally changed; only triangle indices are selected. Animated
driver meshes, reflection layers and the established Hover exclusions are kept.

| Car | Current | Mild candidate | Medium candidate | Coarse candidate |
|---|---:|---:|---:|---:|
| Rally | 26,496 | 26,432 (−0.2%) | 25,960 (−2.0%) | 22,690 (−14.4%) |
| Kart | 31,612 | 31,612 (0%) | 30,508 (−3.5%) | 24,014 (−24.0%) |
| Forklift | 38,136 | 38,136 (0%) | 38,136 (0%) | 30,522 (−20.0%) |
| Volt | 34,690 | 34,380 (−0.9%) | 26,896 (−22.5%) | 20,568 (−40.7%) |
| Hover | 22,548 | 22,548 (0%) | 22,096 (−2.0%) | 22,096 (−2.0%) |
| Challenger | 49,968 | 48,486 (−3.0%) | 45,226 (−9.5%) | 40,090 (−19.8%) |

Mild/medium/coarse use local engine error keys 0.001/0.003/0.01. These are not
independently certified maximum displacements in millimetres. Node scale and
the engine simplifier affect their interpretation. Savings are relative to each
current master; they cannot be added to reductions already obtained by LODs.

The master comparison deliberately forces the car's highest stored level on
both sides. It answers how the proposed authored mesh looks and how many
triangles it contains, rather than how much faster an actual race becomes.
The prototype retains unused vertices, so its triangle saving is not a matching
memory/loading saving. A permanent master replacement would need compaction;
an additional distance level can instead increase stored index data.

## Appearance implications

Native stock front, rear and distant elevated comparisons run in the actual
CarShowroom at 1,000 × 760, with factory liveries, in Compatibility and desktop
Vulkan Mobile. The elevated studio view is a distance proxy, not an actual Game
race. The close Challenger camera clips a small part of the nose; its complete
silhouette remains visible in the distant view. Sheets preserve the entire
native frame. Reflections, moving poses, all kits, washing and other lighting
conditions are not newly qualified by this study.

At sheet scale the medium variants retain the overall designs closely. The
coarser differences are easier to find around small curved surfaces, wheels,
edge highlights and the Challenger body. The changes become less prominent in
the distant views. This is an inspection, not an owner appearance acceptance.
Glossy body highlights can expose a change before the outer silhouette does.

| Candidate | Worst changed pixels over 8/255, across the sampled views and both renderers |
|---|---:|
| Rally medium / coarse | 37 / 854 |
| Kart medium / coarse | 64 / 1,297 |
| Forklift medium / coarse | 0 / 184 |
| Volt medium / coarse | 129 / 894 |
| Hover medium / coarse | 37 / 37 |
| Challenger medium / coarse | 145 / 998 |

These are whole-image diagnostic counts, not perceptual scores or acceptance
thresholds. The background is large; the counts must be considered alongside
the car images. All 36 master-restoration images are pixel-exact. There are
108 master/candidate pairs and 72 production/earlier-LOD pairs across both
renderers, plus those 36 restoration controls: 216 measured pairs in total.

## Existing LODs already do substantial work

Keep the production viewport policy, halve only each car node's current LOD
bias, and observe the same distant studio view. This makes existing lower levels
activate sooner without replacing the close master or changing the studio's
own LOD policy. The result is identical primitive counts in both renderers:

| Car | Current main viewport primitives | Earlier car LOD | Additional main-view reduction | Main viewport draws, unchanged |
|---|---:|---:|---:|---:|
| Rally | 25,241 | 19,633 | 22.2% | 59 |
| Kart | 27,104 | 25,766 | 4.9% | 53 |
| Forklift | 32,756 | 20,820 | 36.4% | 33 |
| Volt | 21,988 | 20,724 | 5.7% | 45 |
| Hover | 22,836 | 22,596 | 1.1% | 22 |
| Challenger | 42,726 | 39,342 | 7.9% | 51 |

These viewport totals include the studio. The differences change only the car
LOD bias. They exclude other viewports, reflection/shadow passes and the rest
of a real race. They are not FPS improvements. The existing production LODs
already remove 16,746 primitives from Volt relative to the forced-master view;
its 40.7% coarse master opportunity therefore substantially overlaps work that
is already avoided at distance. Simply quoting the master saving would overstate
its additional racing benefit.

Do not apply the earlier bias globally to close Garage views. A racing-only
policy or a screen-size-dependent level needs motion, zoom, seam, shadow and
highlight checks. The tested second, still-earlier bias step gives different
returns per car; its measurements remain in summary.json.

## What this could mean for performance

Fewer triangles reduce geometry processing. They do not automatically reduce
draw calls, fragment shading, transparent layers, shadow-map pixel work, UI,
track scenery, physics or networking. Here the observed draw counts stay fixed.
Mobile GPUs can benefit especially from avoiding dense subpixel geometry, but
the actual bottleneck determines the frame-time gain.

For illustration only, suppose the affected car geometry accounts for a share
of the frame's limiting work, and that work falls in proportion to triangles:

| Further triangle reduction | If affected geometry is 10% of limiting frame time | If 25% | If 50% |
|---|---:|---:|---:|
| 10% | 1% shorter frame | 2.5% | 5% |
| 25% | 2.5% shorter frame | 6.25% | 12.5% |
| 40% | 4% shorter frame | 10% | 20% |

At a 20 ms frame, the 25% reduction means 0.5 ms saved in the first scenario,
or 2.5 ms in the last. These are sensitivity examples, not measured predictions.
CPU/GPU overlap, cache behaviour, tile load, unchanged draw cost and a frame cap
can change the outcome. Removing half a car's triangles cannot be interpreted
as doubling the game's FPS.

Godot documents the separate costs of
[geometry, pixels and submissions](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html)
and the resolution-aware selection and quality controls of
[mesh LOD](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html).

## Recommended next pass

1. **Trial earlier existing LODs for Rally and Forklift during racing.** They have
   the strongest measured incremental primitive savings without a new master.
   Retain the current Garage policy and check motion/zoom transitions first.
2. **Prototype a separate Volt racing body around the 26.9k candidate.** Its
   medium master saving is substantial and the sampled changes are limited.
   Measure against automatic production LODs; retain the existing close body.
3. **Treat Challenger as a careful 45.2k distance candidate.** Its recent nose,
   shoulder, bonnet, glazing and panel work is more valuable than forcing a
   universal target. Lock these boundaries before any permanent retopology.
4. **Investigate Kart's 24k coarse level at racing distance.** Preserve the
   moving suit, hands, contact points, steering and helmet/visor silhouette.
   The intermediate 30.5k level saves little; do not cut anatomy for that gain.
5. **Keep Hover's layered close hull.** The generic eligible candidate saves
   only 2%; its hull/canopy/duct exclusions are intentional. Larger savings need
   authored skirt, tube and fan-guard levels, with layer joins inspected. The
   November 13 review contains those separate, more visible experiments.

Before selecting a shipped quality level, compare current and candidate in an
identical actual race on the target device: same track/biome, resolution,
camera, kit, ghost count and warmed shaders. Record CPU/GPU frame time and
frame-time percentiles, including sustained warm-device behaviour. Use frozen
close views and moving race views for the appearance decision. Device testing
was not performed by this review; there is no measured FPS, thermal, battery,
VRAM or loading improvement claim.

## Requirements, commands, controls and limitations

- **CTR01:** fresh six-car stock/fitted/full/Garage inventory, 30 cases each in
  initial and final runs, zero failures.
- **CTR02:** three disposable master candidates per car, native close/rear/
  distant comparisons and exact restoration controls.
- **CTR03:** two earlier existing-LOD bias choices per car, native primitive and
  draw observations, and conditional performance interpretation.
- Native helper checks: **256/0 per renderer**, pinned Godot
  `4.7.2.stable.official.ed1daf0bf`, RTX 3090. Desktop Mobile means the renderer,
  not a physical phone/tablet. No actual race benchmark was run here.

```powershell
# Initial inventory used dev.ps1 TestScript with the same output argument.
python scripts/review_car_triangle_tradeoffs.py gl_compatibility
python scripts/review_car_triangle_tradeoffs.py mobile
python scripts/review_car_triangle_tradeoffs.py inventory
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compare_car_triangle_tradeoffs.ps1
python scripts/summarise_car_triangle_tradeoffs.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

The runner uses the standard dev.ps1 entry point, private APPDATA/LOCALAPPDATA
and empty backend URL/auth values. Its per-run 21,881-input fence covers vehicle
sources/resources, prepared assets, car configurations, Garage car templates,
the Git index, project configuration and generated build identity.

Concurrent Electric kit publication changed six resources during Compatibility
and 52 during Mobile; these are recorded and preserved. The native study uses
stock prepared bases, which remained unchanged. dev.ps1 also refreshed the
generated build identity/project version. No vehicle model, tune, production
geometry or quality setting was authored by this review, and no main-index write
was made.

The initial fitted Volt inventory hit no prepared modules and had no LODs while
the concurrent producer was working. The final inventory has four module hits,
32 LOD-bearing surfaces and the same 43,758 master triangles. Its prepared
surface count becomes 40. This closes the transient observation; it is not
reported as a remaining production defect. The final guarded inventory has no
vehicle/asset/configuration/index changes, only dev.ps1's generated identity
and version refresh.

Added review files are the native helper under game/tests, the runner,
PowerShell image comparator, Python summariser, this report and its evidence.
The repository status/agent notes receive a brief report link. No production
model files or player saves were edited, no owner processes were changed, and
no physical device query, export, install, backend request or deployment ran.

The Python image prototype could not run because Pillow was absent; an isolated
tool installation also failed certificate verification. The final comparator
uses the already available System.Drawing library, with no added dependency.
Its first array-construction attempt failed before comparisons and was corrected;
the final run measures all 216 pairs. Raw command logs and change receipts are
retained. Concise image hashes and selected full-resolution comparisons accompany
the four sheets; redundant captures are removed after reconciliation.

Final reconciliation confirms all 512 native helper checks, matching triangle
counts between renderers, unchanged candidate surface counts, 12 prepared-base
and 24 fitted-module hits, and 36 pixel-exact restoration controls. Both Python
helpers pass syntax parsing. The broad `git diff --check` reports existing final
blank lines in AGENTS.md and DEVELOPMENT_STATUS.md, outside this task's prepended
blocks; those unrelated endings are preserved.

Evidence is reduced from 165.1 MB to about 33.2 MB: four sheets, 52 selected
full-resolution comparisons, metrics and hashes for all 288 original captures.
The tool's automatic policy review rejected recursive deletion of the temporary
review profiles without supplying a more specific reason. No deletion workaround
was attempted. The prescribed retention cleaner ran separately and passed with
zero cleanup failures: 22.504 GiB remains, above the 20 GiB target because recent,
protected or locked output remains exempt. The temporary profiles remain in the
task's disposable build directory under the standard retention policy.
