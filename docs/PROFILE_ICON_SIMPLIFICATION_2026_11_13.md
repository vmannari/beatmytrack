> Completed 14 November: the missing prepared-model/LOD work is now qualified. See [the completion report](PROFILE_ICON_COMPLETION_2026_11_14.md) for current results; the stale-cache limitations below describe the earlier snapshot.

# Profile-button icons use a lighter renderer — 13 November 2026

The owner requests faster car icons through simpler models. Customized icons previously built a reflective Garage studio, staged its cold material programs and resolved five draws. A dedicated header renderer now requests existing lower-detail mesh levels, renders at native 176×112 resolution with fixed unshaded lighting and resolves two draws. It retains actual body/hood/aero/rim choices and production wrap/sticker uniforms. The profile button and dropdown remain cached 2D images; no 3D world stays attached after capture. Stock pictures retain their immediate bundled-image path.

[Actual profile button](evidence/profile-icon-simplification-2026-11-13/equipped-cache-trace-gl/gl_compatibility/equipped-header.png) · [Dropdown](evidence/profile-icon-simplification-2026-11-13/equipped-cache-trace-gl/gl_compatibility/equipped-dropdown.png)

Header captures use the real reduced CarVisual assembly with a 0.35 per-instance mesh LOD bias, GI disabled, no light nodes, sky, radiance or reflection capture, and the shared inexpensive finish. There is no runtime mesh simplifier, mesh-array readback added by the renderer, guessed kit overlay or generic car silhouette. The shared Rivalry widget gains constructor/build/scale hooks with its previous defaults unchanged. The general Profile renderer used by Garage/art/awards is untouched.

The appearance cache retains owner/epoch/appearance admission, race/input/navigation cancellation, one active world, fourteen-image memory/disk bounds and saved PNG reuse. Its schema changes to reject previous-style images. The generated header identity now excludes unrelated UI consumers and generated Garage/catalogue photographs, while retaining model, rendering, native and declared icon-renderer inputs. This avoids regenerating saved icons after unrelated menu work; normal build-identity generation applies the revised dependency policy.

| Native desktop case | First equipped icon ms, before → after | Six icons ms, before → after | Worst frame ms, before → after |
| --- | ---: | ---: | ---: |
| OpenGL Compatibility | 2574.9 → 1619.7 | 11848.0 → 8567.8 | 6026.7 → 5369.7 |
| Vulkan Mobile on desktop | 10354.9 → 8474.1 | 45083.8 → 42599.1 | 6327.7 → 7472.4 |

These are individual matched offline observations on pinned official Godot 4.7.2 (`ed1daf0bf`), Windows/i7-11700K/RTX 3090, private source/assets/import copies and fresh private application profiles. Imports, OS/driver caches and other owner processes are uncontrolled. They are not statistical speedups or Android/frame-rate qualification. Earlier 23.9→10.0-second exploratory fleet timings use a different revision and do not support the final table.

The measured source snapshot has stale shared car caches after concurrent model/material changes. Both matched cases record zero prepared-base/kit hits and use procedural fallback. Consequently the six-car triangle-budget check remains **unqualified**, and source fallback still causes multi-second stalls, especially on Vulkan. Its worst observed frame regresses in this small Vulkan sample. No guard was weakened or old binary published to disguise this. The smaller-mesh policy requires matching prepared assets, as the existing export preflight already enforces.

An independent stored-geometry control proves the native LOD setting selects fewer indices: stored Compact 26,496→13,950 drawn primitives (47.35% fewer) on both desktop renderers. This control does not certify that stored model's current source freshness. The actual-source six-car functional test retains the correct fallback shape/graphics and explicitly reports unavailable LOD qualification.

Selected checks pass 896 native assertions, ten source-admission checks and 556 production-script compilations, with stable per-run inputs and clean strict exits. Both renderers exercise appearance uniforms, shape visibility, frozen rendering, interrupted capture, PNG publication and disk reuse. The real App equipped-cache fixture passes 45 checks, including kit-only changes, dropdown delivery, eviction/corruption recovery and account replacement. The source-key and production capture-policy fixtures pass 14/32. Initial measurement/API/fixture failures and a non-reproduced broad App timeout are retained separately.

The actual startup fixture presents its first menu at 587 ms and receives the equipped icon at 3780 ms without another navigation. A separate-process restart receives it at 829 ms, with zero model captures and no visible factory-livery frames. These remain individual controlled desktop observations.

Current-model prepared-cache readiness, owner appearance and device qualification remain separate. No vehicle geometry/physics source or binary was authored by this task; concurrent fixes and generated assets were preserved. No APK/export, device query/test, backend request, user-save edit, owner-process change or Git staging was performed. Reload to use the new renderer.

Evidence includes native captures, source/asset digests, retained failures, cache/source-key checks and a task-only patch with exact forward/reverse and whitespace validation. Complete fixtures/profiles stay disposable inside build; temporary pins are removed and the owner-prescribed retention cleaner runs at completion. cleanup.json records disposition.
