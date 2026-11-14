# Rivalry previews use the actual cars — 13 November 2026

RRP01–RRP05: owner rejects the generic faceted cars because they no longer resemble the actual vehicles. The Rivalry podium now displays small native renders of the real reduced stock models, retaining the body proportions, glazing, wheels, lights, Forklift structure, Hover fans and current Kart driver. Player body/accent/detail colours are applied through image masks. There is no runtime car geometry or 3D viewport in this podium view.

[All six updated cars](evidence/rivalry-real-previews-2026-11-13/gallery-gl_compatibility.png) · [Actual Rivalry page](evidence/rivalry-real-previews-2026-11-13/qualified-real-entry-gl/rivalry.png) · [Real model versus preview](evidence/rivalry-real-previews-2026-11-13/super_rally-comparison-gl_compatibility.png)

## Appearance and implementation

The offline baker constructs canonical CarVisual models with prepared caches disabled, stock kits, the original vertex positions/normals/UVs and actual materials under the Garage lighting rig. It captures a default-paint reference, a neutral-grey shaded image and a three-channel paint mask at the same camera/pose. Supersampling, straight-alpha resolution and mipmaps preserve fine edges. Runtime shading recolours only the painted regions and retains a small highlight for dark paints; glass, tyres, lamps and other fixed details remain photographed.

Each car has a 512×320 colour/mask pair. All twelve compressed native textures total 1,105,485 bytes. The six-car gallery measures twelve draw calls including six labels: one call and one quad per car. Immutable pictures are shared, while each player owns its pigment material. There is no per-frame script work or new persistent runtime cache. Stock photographs deliberately omit fitted-kit geometry, wraps/stickers and dirt; their source payloads remain intact. This is not a claim to render a fully equipped Garage replica.

The native comparison tests verify the alpha value at every pixel against the full actual-model reference, without an alpha tolerance. All six cars are exact on both desktop renderers. Average per-channel RGB differences over opaque pixels are about 0.6–3.7% from the tint approximation; these are averages, not a maximum-pixel bound or full pixel identity. The reference is a native OpenGL bake displayed on each renderer. Owner appearance acceptance and actual Android qualification remain.

Navigation treats these as ordinary canvas views and keeps the existing four-step radiance preparation for pages that own 3D SubViewports. Delayed membership, navigation cancellation, first-visible content and the actionable failure page pass on both desktop renderers. The previous unlit hue assumption in the fixture did not describe the real model’s bright roof/hood highlights and was updated.

## Loading and checks

| Desktop renderer | First actual App entry ms | Repeat ms | Rivalry feature load ms |
| --- | ---: | ---: | ---: |
| OpenGL Compatibility | 613.4 | 61.2 | 385.4 |
| Vulkan Mobile (desktop) | 535.5 | 72.2 | 318.7 |

Pinned official Godot 4.7.2 (`ed1daf0bf`), i7-11700K/RTX 3090, Windows, 1280×720 offscreen native windows, Dummy audio, offline API configuration, private profiles and suppressed optional Garage warming. Runs are sequential; renderer/OS caches and other owner work are uncontrolled. These are individual desktop observations, not statistical speedups, a pure GPU-time measurement or Android FPS/thermal results. The detailed 3D podium’s earlier native first-use stall is avoided by drawing photographs.

Selected checks total 1,115 passing runtime assertions plus 552 production scripts compiled in the private fixture: actual-source comparisons 36/0 each renderer, photo lifecycle/draw/colour isolation 54/0 each, custom appearance/layout/scope 204/0 each, actual App entry 6/0 each, delayed/cancelled/error entry 67/0 each and layout refresh 381/0. Every selected run records unchanged private inputs. The original vehicle scripts/configurations were not edited by this task; concurrent owner changes are listed separately in the protected-source receipt.

The final actual-source comparisons and gallery checks were repeated after concurrent vehicle-asset changes. The wider App matrix and timing rows describe the earlier pinned asset revision with the same preview implementation; they are not a whole-project qualification of every subsequent concurrent change.

Strict cleanup qualification is not universally clean: some GL App/profile/layout runs retain two ObjectDB instances and one resource at exit. The same diagnostics reproduce with the before-photo faceted view. Those strict runs are retained as cleanup-gate failures, not silently counted as clean passes; the functional assertions and timing rows still complete. Isolated photo/gallery tests, both readiness routes and the production parser are clean. Two earlier readiness observations were rejected after an overlapping retry changed the fixture; no measurements from them support the conclusions. See `retained-findings.json` and the raw receipts.

## Source parity, build integration and limits

The source-checked publication fence rejected concurrent model changes, then an immediate refresh/bake/publish sequence accepted all six current captures. The final live check verifies six vehicles, twelve exact textures and 21,297 input paths through 166 fingerprints. Tree fingerprints retain the hash of every path and content hash, reducing packaged provenance to 24,953 bytes. The Android export workflow now calls this freshness check; later car or lighting changes require a rebake. No export or device action was invoked.

A fresh bake uses `python scripts/qualify_rivalry_real_previews.py NAME --bake --renderer gl_compatibility`, followed by `python scripts/qualify_rivalry_real_previews.py NAME --publish` and `python scripts/check_rivalry_car_previews.py`. When reusing a fixture after art changes, run the helper with `--refresh` first. Native-only construction occurs offline in a real private source/assets/import copy; no frozen vehicle binary is published into live. Only the new thumbnail family is copied. Export validation fails closed on missing, changed or stale photographs.

[Evidence](evidence/rivalry-real-previews-2026-11-13/) includes actual-model references, native comparisons, stable input digests, strict exit diagnostics, publication fences, generated-asset hashes and a task-only source checkpoint. The source patch has exact forward/reverse validation in a small disposable fixture and leaves the main index unchanged. Native resources are listed separately, rather than embedding large binary payloads in the source checkpoint.

The temporary build pin is removed at completion and the owner’s retention cleaner applied. Project copies, profiles and shader caches remain disposable build output under normal active-work grace/retention, not permanent evidence. Relevant comparisons and concise receipts remain; `cleanup.json` records disposition. No Android query/test, APK, live backend request, deployment, owner-save edit or owner-process change was performed. Reload the game to see the updated previews.
