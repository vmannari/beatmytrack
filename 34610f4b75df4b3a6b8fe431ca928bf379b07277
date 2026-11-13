# Compact custom-kit construction corrections — 2026-10-25

All three findings from the [compact-kit review](COMPACT_KIT_REVIEW_2026_10_25.md) are corrected in the actual detailed and simplified prepared models. Saved option IDs, the outer arch shells, original tyres, compact configuration, car assembly, production cameras and existing regression assertions remain.

Open the [native before/after gallery](evidence/compact-kit-fixes-2026-10-25/review.html). It contains sixteen matched Compatibility comparisons and the final sixteen views in desktop Mobile. Both renderers produce identical geometry measurements. Desktop Mobile means Windows Vulkan, not a physical-device test.

1. **CKR01 — Fitted roof-lip root.** A closed, continuous painted root joins the existing blade to the roof. Its lower return seats into the actual prepared roof, including the coarser simple roof; the blade silhouette stays exact. Sampled minimum roof embed is **4.275 mm detailed / 1.731 mm simple**, and minimum overlap into the blade underside is **9.207 / 8.121 mm**. The former visible gap is filled. Source: [compact_kits.gd:194](../game/vehicle/compact_kits.gd#L194). Views: [before](evidence/compact-kit-fixes-2026-10-25/baseline-gl_compatibility/roof-lip-side.png), [after](evidence/compact-kit-fixes-2026-10-25/attachments-gl_compatibility/roof-lip-side.png), [simple Mobile](evidence/compact-kit-fixes-2026-10-25/attachments-mobile/simple-roof-lip.png).

2. **CKR02 — Returned backing for all six arch packages.** Rally, Club sport, Heritage, Wide arch, Endurance and Gravel now have a closed backing between each unchanged flare and the original fender. All four arches, both sides and both detail levels are checked. Minimum sampled stock embed is **2.686 / 4.400 mm**, and minimum overlap into the flare return is **1.503 / 3.550 mm**. The original outer-surface clearance checks still pass unchanged. Source: [compact_body_kits.gd:65](../game/vehicle/compact_body_kits.gd#L65). Views: [before](evidence/compact-kit-fixes-2026-10-25/baseline-gl_compatibility/wide-arch.png), [after](evidence/compact-kit-fixes-2026-10-25/attachments-gl_compatibility/wide-arch.png), [simple Mobile](evidence/compact-kit-fixes-2026-10-25/attachments-mobile/simple-arch.png). Existing simple-model facets are still observable in extreme wheel-opening close-ups; the new backing closes the attachment gap.

3. **CKR03 — Dome accents follow the actual hood triangles.** The existing tapered accent outline is clipped against the final hood's UV triangles, then each clipped vertex is interpolated from its supporting triangle and lifted by the existing 1.2 mm analytical offset. This removes the independently sampled overlay that crossed the simple hood. Each hood/detail pair passes **4,385 matching ray samples**, with zero samples below the sheet and at least **1.103 mm** measured clearance across all four pairs. Both simplified domes are visibly continuous. Source: [compact_hood_kits.gd:39](../game/vehicle/compact_hood_kits.gd#L39). Views: [Power dome before](evidence/compact-kit-fixes-2026-10-25/baseline-gl_compatibility/simple-dome-insert.png), [after](evidence/compact-kit-fixes-2026-10-25/attachments-mobile/simple-dome-insert.png), [Vented dome after](evidence/compact-kit-fixes-2026-10-25/attachments-mobile/simple-vented-insert.png).

These distances are sampled axis measurements in unscaled model coordinates, not continuous minimum Euclidean distances or physical-car dimensions. The focused regression uses actual mesh intersections: 26 roof-root stations per detail level and 33 cross-sections per backing, plus closed-edge, real-thickness and original tyre-envelope checks. Native views show the complete car with no part hidden. Diagnostic cameras do not change production camera sources.

The catalogue now has **1,310 meshes**: 50 new attachment meshes and four replaced accent inserts. The other **1,256 original mesh binaries are byte-identical**, including every rim, visible arch shell, larger wing and hood sheet. Nine affected catalogue photos per renderer are refreshed and imported; the other 68 of 86 photographs remain byte-identical. Default compact artwork and livery photos show the unchanged stock model and require no refresh. The 16-photo runtime cache remains.

All **13,000 combinations per detail level** retain the existing 170,000-triangle limit. Independent part counts are summed across the complete catalogue, and the real maximum assembly is instantiated to verify the sum. Current maximum visible assemblies are **169,376 detailed / 66,420 simple triangles**. There is no phone performance claim.

Actual final checks:

| Check | Result |
|---|---|
| New attachment regression, generated source | 5,114 checks, 0 failures |
| New attachment regression, prepared Compatibility / desktop Mobile | 5,114 / 5,114 checks, 0 failures |
| Prepared geometry, winding, normals, hood boundaries, articulation, wash and roll | 5,323 checks, 0 failures |
| Prepared fabricated construction, tyre/plate clearance and wheel windows | 1,354 checks, 0 failures |
| Complete catalogue, source-array equivalence and all combination budgets | 1,593 checks, 0 failures |
| Retained aero fit/glazing/roll and editing | 836 checks, 0 failures |
| Independent replacement, original wheels, paint and condition | 346 checks, 0 failures |
| Current native Parts focus/preview/equip workflow | 646 checks, 0 failures |
| Imported-photo pixels, exact resources and bounded retained menus, Compatibility / Mobile | 1,446 / 1,446 checks, 0 failures |
| Final parser | 1,208 scripts, 0 failures |
| Local asset import | Exit 0; all 18 changed photographs imported |

The unmodified starting assets are retained under `before/`. The new initial regression ran against them before production edits: **58 checks, 54 failures**, because absent attachments skip the later station checks. Its detailed inserts also fail the new 1 mm safety margin, while the preceding review correctly reported those detailed inserts above the sheet. All original regression assertions are untouched. The 47 obsolete camera/hidden-control assertions documented in the preceding review are outside this model correction; that old suite was not rerun here, and no all-project-test pass is claimed.

Initial trials are retained. A typed-array error in the new accent builder was corrected. The first backing missed its return crest; explicit radial stations fixed that. Its simple angular sampling was then aligned with the original simple flare. A deeper simple lip return seats into the actual coarse roof. Four simple backing cap-closure failures revealed float64 cap parameters differing from the float32 surface UVs; the new backing sampler gives both identical float32 parameters. No failed bound or assertion was relaxed. The import's existing missing Android build-tools diagnostic is nonfatal; no Android export was requested or performed.

All engine runs use pinned Godot 4.7.2 through `scripts/dev.ps1`, approved certificate-store access and APPDATA/LOCALAPPDATA isolated under `build/compact-kit-fixes`. Representative actual commands:

```powershell
python docs/evidence/compact-kit-fixes-2026-10-25/snapshot.py
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/compact-kit-fixes-2026-10-25/run.ps1 -Job baseline
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/compact-kit-fixes-2026-10-25/run.ps1 -Job source -Attempt closed
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/compact-kit-fixes-2026-10-25/run.ps1 -Job bake -Category hood
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/compact-kit-fixes-2026-10-25/run.ps1 -Job bake -Category aero
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/compact-kit-fixes-2026-10-25/run.ps1 -Job bake -Category body
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/compact-kit-fixes-2026-10-25/run.ps1 -Job photos -Renderer mobile -Category body
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/compact-kit-fixes-2026-10-25/run.ps1 -Job attachments -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/compact-kit-fixes-2026-10-25/run.ps1 -Job catalog
python docs/evidence/compact-kit-fixes-2026-10-25/gallery.py
python docs/evidence/compact-kit-fixes-2026-10-25/finalize.py
```

[report.json](evidence/compact-kit-fixes-2026-10-25/report.json) records every final command, actual measurements, source/asset hashes, failed-iteration dispositions and an isolated baseline/final Git checkpoint with a checked task-only patch. The checkpoint changes three production generators, prepared resources/photos and provenance, adds `test_compact_kit_attachments.gd`/UID, and adds this report and scoped evidence helpers. The new test reuses the unchanged preceding-review diagnostic for insert rays and camera captures. The shared branch/index are untouched by the checkpoint.

Concurrent electric steering work changes shared `vehicle_simulation.gd` and `handling_config.gd`; both task-start and current hashes are recorded, and those edits are retained and excluded from the checkpoint. Compact configuration, car assembly, part IDs, production cameras and original model tests match their task-start hashes. No new physics validation or rollout acceptance is claimed for concurrent work.

CKR01–CKR03 are complete locally. R01 preserves original construction and editing invariants; G01 provides native evidence and a scoped checkpoint. Q01 leaves client reload and owner/device appearance, motion and cost acceptance. No device attachment check/test, APK, real purchase/authentication, live mutation/deployment or owner-process restart was performed.
