# Continuous grass and winter loops in the 3×3 picture

The owner identified disconnected-looking grass and winter circuits in the v7 challenge poster. CL01–CL03 correct the illustration: the grass circuit now has a continuous visible back straight and connected end curves, and the winter circuit has a fully visible asphalt ring around a low snowy infield. The winter mountain was removed because it hid the back straight. Three biome islands, the desert circuit and three racing tickets remain.

The built-in image_gen tool edited the original project poster. The first edit corrected the grass loop but still obscured the winter road behind the mountain; that rejected draft remains in the evidence folder. A second targeted edit exposes the complete winter lap. Both exact prompts, provider output paths and source provenance are in [three-by-three-continuous-loops-v8.json](../game/assets/menu/challenges/three-by-three-continuous-loops-v8.json). The final asset is `game/assets/menu/challenges/three-by-three-v8.png`.

The only runtime source change is the 3×3 poster path in `game/ui/challenge_create.gd`. The existing card drawing/layout, 1024-pixel lossless mipmapped import and challenge behavior remain. This changes the illustration, not playable track geometry. Previous posters are retained. The original v7 claim that all its loops were complete is superseded by the owner's correction and this revision.

Validation and native captures reuse the existing format-page assertions without changing them: **39 checks, zero failures in Compatibility and 39 checks, zero failures in desktop Mobile/Vulkan**, at 1280×720, 1440×900, 960×540, 390×844 and 844×390. The selected portrait card is scrolled fully into view. These UI checks verify integration/layout; continuity of the illustrated roads is a separate visual review. Pinned import and the production patch reverse check also pass. Actual results, commands, initial failures and hashes are recorded in [report.json](evidence/three-by-three-continuous-loops-2026-10-26/report.json).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/three-by-three-continuous-loops-2026-10-26/run.ps1 -Import
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/three-by-three-continuous-loops-2026-10-26/run.ps1 -Probe poster -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/three-by-three-continuous-loops-2026-10-26/run.ps1 -Probe poster -Mode mobile
python docs/evidence/three-by-three-continuous-loops-2026-10-26/record.py
```

The initial import failed while copying the native track-geometry library. A retry succeeded without modifying the library or restarting an existing process. No broader car-carousel regression rerun is needed for this image-only correction; the preceding task's retained failures remain documented in its own evidence.

Reopen challenge creation to see the corrected picture. Owner appearance/readability acceptance remains. Device attachment was not checked and no device test was performed. No APK, real authentication/purchase, live mutation, deployment, staging/commit/merge or owner-process restart was performed. Concurrent work is preserved.
