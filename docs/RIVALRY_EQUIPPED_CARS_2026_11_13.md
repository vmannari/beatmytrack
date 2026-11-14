# Rivalry uses each player's real fitted appearance — 13 November 2026

The previous stock photographs retained paint colours but could not display wraps, stickers or fitted kits. Rivalry now builds each normalized player appearance through the actual reduced CarVisual model and uses the production livery shader include and uniforms. Hood, aero, rims and body selections are assembled by the same path as the actual car. Local Garage appearance overrides and remote validation remain intact.

[Stock / fitted / wrap / sticker comparison](evidence/rivalry-equipped-cars-2026-11-13/qualified-models-gl/compact-stock-kit-wrap-sticker.png) · [Actual Rivalry page](evidence/rivalry-equipped-cars-2026-11-13/qualified-custom-gl/gl_compatibility/hub-1280x720.png)

Lighting stays simplified: one shared unshaded preview shader with fixed directional shading, no light nodes, sky/radiance environment or reflection captures. Materials are per-instance overrides; model geometry and shared source materials are untouched. The small viewport renders once, then explicitly freezes. Resizing or showing the view redraws it. Stored car-local bounds fit the camera without querying detached 3D children while App parks/reparents the retained page. No frame/physics script loop is introduced.

This restores geometry/graphics fidelity at a loading cost compared with the stock-image shortcut:

| Desktop renderer | First entry ms | Return ms | Feature script load ms |
| --- | ---: | ---: | ---: |
| OpenGL Compatibility | 3415.1 | 77.0 | 1550.3 |
| Vulkan Mobile on desktop | 4970.7 | 61.4 | 1774.9 |

Pinned official Godot 4.7.2 (`ed1daf0bf`), Windows/i7-11700K/RTX 3090, 1280×720 offscreen native windows, Dummy audio, offline configuration and private profiles. These are individual observations with fresh private application caches, existing imports and uncontrolled OS/driver state; other owner processes were running. Optional Garage warming is suppressed. They are not statistical speedup or device FPS claims. Earlier error-bearing App measurements are rejected.

Selected checks pass 2,384 runtime assertions and compile 554 production scripts, with unchanged private inputs and clean strict exits. Both desktop renderers test all six models with identical pigments and visibly different kits/wraps, production graphic uniforms, player isolation and frozen rendering. Actual App first/return entry and delayed/cancelled/error navigation pass on both renderers; the custom player/layout/sync fixture passes on OpenGL. Mobile appearance ablation precedes the camera-bound-only fix; final Mobile App/readiness checks include it. Receipts pin each revision, rather than claiming all concurrent live work is qualified.

The Electric retains an existing production decal limitation: hood/roof cutoffs lie above its lowered painted surfaces, so its chosen sticker fixture remains invisible, as in the actual-car mapping. Its wrap and kits render correctly. The Forklift rear-cover sticker is verified from the rear; the podium's front angle hides it. Shared production mapping was not changed to invent preview-only positions. Colours and material response use simplified preview lighting, rather than exact Garage reflections. Dirt remains outside the shared Rivalry appearance payload.

The unused stock-photo freshness gate is removed from Android export; Rivalry no longer consumes that texture family. Historical baker/assets remain available for the prior investigation. No export, device query/test, live request, deployment, user-save edit, owner-process change or Git staging was performed. Reload the game to see the equipped previews. Owner appearance/device acceptance remains.

Evidence includes the selected native images, per-run source digests, retained failures and a forward/reverse checked source-only patch. Disposable fixture/profile output stays in build under normal retention. Both temporary task pins are removed and the prescribed retention cleaner applied at completion; cleanup.json records disposition.
