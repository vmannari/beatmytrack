# More varied 3x3 challenge circuits

The owner found the corrected v8 loops too plain. VT01-VT03 replace the forest and winter ovals with distinct winding circuit silhouettes while retaining complete visible loops, all three biome islands and three racing tickets. The forest course has a hairpin, an S section and a broad sweep; the winter course has a winding back stretch and offset front chicane. A second local image edit clears vegetation from the forest connector so the lap stays traceable.

The built-in image_gen tool edits original project-generated artwork only. Both exact prompts, provider paths and source provenance are in [three-by-three-varied-circuits-v9.json](../game/assets/menu/challenges/three-by-three-varied-circuits-v9.json). The image is `game/assets/menu/challenges/three-by-three-v9.png`; the sole runtime source change is its path in `ChallengeCreate.POSTERS`. The original card drawing/layout and lossless 1024-pixel mipmapped import remain. This changes menu artwork only; playable roads and challenge rules do not change. Previous images and evidence remain.

Native captures reuse the original format-page assertions: **39 checks, zero failures in Compatibility and 39 checks, zero failures in desktop Mobile/Vulkan**, at 1280x720, 1440x900, 960x540, 390x844 and 844x390, including the fully scrolled selected portrait card. Pinned import and the binary production patch reverse check pass. Illustration variety/continuity is reviewed visually; UI checks verify integration/layout. Actual outcomes, commands, hashes and the first draft are in [report.json](evidence/three-by-three-varied-circuits-2026-10-26/report.json).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/three-by-three-varied-circuits-2026-10-26/run.ps1 -Import
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/three-by-three-varied-circuits-2026-10-26/run.ps1 -Probe poster -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/three-by-three-varied-circuits-2026-10-26/run.ps1 -Probe poster -Mode mobile
python docs/evidence/three-by-three-varied-circuits-2026-10-26/record.py
```

This supersedes the plain oval composition of v8 while retaining the owner's continuous-loop requirement. Reopen challenge creation to see it. Owner appearance/readability acceptance remains. No device attachment check or device test was performed. No APK, real authentication/purchase, live mutation, deployment, Git staging/commit/merge or owner-process restart was performed; concurrent work is preserved. Earlier unrelated carousel failures remain documented in the preceding artwork evidence.
