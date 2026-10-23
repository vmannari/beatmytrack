# Forgiving Garage washing requirement — 2026-10-16

The owner accepts small remaining dirt so customisation does not require hunting tiny hidden patches. This supersedes the strict native-epsilon gate in `GARAGE_CLEAN_CUSTOMISATION_2026_10_16.md`.

GCT01 allows faint remaining dirt and small missed exterior patches. The same bounded cached exterior inspection now accepts at most 5% of sampled points above 0.05 residue, with mean remaining residue at most 0.05. A completely faint coating up to 0.05 also passes immediately. These are normalised wash-field sample limits, not measured square metres or shader pixel coverage. Broad unwiped areas still fail. Both dirt/snow layers participate, and the existing missing-interior/underside exclusion remains.

GCT02 preserves the actual dirt and wash masks when accepting a car. Livery/colour/sticker/kit/reset/save guards share the forgiving decision; no automatic cleaning, geometry, material, camera, physics, storage-schema or backend change was made. The original wash-required message and direct Wash car action remain for cars exceeding the tolerance.

Implementation: `game/ui/garage_cleanliness.gd`. The existing focused test now checks all five cars with trace dirt (0.005), faint film (0.04), noticeable film (0.15), an actual missed dirty exterior interpolation cell, and a broadly unwiped half. It also verifies saved livery and kit selection with tolerated dirt, retaining the dirt mask. Headless/native results, native captures and source hashes are recorded under `docs/evidence/garage-clean-tolerance-2026-10-16/`.

Actual commands use the pinned engine through the existing entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_clean_customisation.gd -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_clean_customisation.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3 -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_clean_customisation.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 120
git diff --check -- game/ui/garage_cleanliness.gd game/tests/test_garage_clean_customisation.gd
```

Actual focused outcomes: 126 headless checks, 133 native Compatibility checks and 133 native Mobile checks, all with zero failures. Whole-project compilation passes 813 scripts with zero failures. Native captures include working livery and kit menus with a remaining dirty patch.

Only these focused checks and whole-project compilation were rerun for this follow-up. Prior Garage/washing regressions remain recorded as earlier results. No phone attachment check, phone test, APK, backend change/test or deployment was performed. Owner/phone washing-effort acceptance remains; the thresholds are an adjustable default.
