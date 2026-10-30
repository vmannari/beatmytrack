# Night biome brightness (2026-10-28)

## Midpoint adjustment (2026-10-29)

The owner requests the average of the original and brighter settings. Current Night ambient energy is **0.055** = (0.045 + 0.065) / 2; moonlight is **0.030** = (0.025 + 0.035) / 2. Only those two values change in `game/track/track_theme.gd`. The original results below remain historical evidence for the brighter revision.

The unchanged Night lighting regression passes **15 checks, 0 failures** through the same isolated offline runner command listed below. The scoped midpoint patch, exact-change check and test log are retained under `evidence/night-brightness-midpoint-2026-10-29/`. No new rendered captures or physical-device tests were performed for this adjustment. Reload/rebuild and owner phone/tablet appearance acceptance remain.

## First brightness adjustment

NBR01: The owner finds Night too dark on phone and tablet. The shared Night lighting in `game/track/track_theme.gd` now uses ambient energy **0.065** (previously 0.045) and directional moonlight **0.035** (previously 0.025). This lifts the unlit road and industrial ground while retaining the existing cool colours and local lamp contrast. These are light-energy settings, not measured screen-brightness percentages.

NBR02: Only the two Night light-energy branches change, with one explanatory comment. Other biome settings, lamps/headlights, rendering budgets, camera, materials and canonical driving are preserved. The editor's Race lighting preview receives the same shared adjustment; its separate authoring light remains unchanged.

Changed runtime file: `game/track/track_theme.gd`. The new `game/tests/review_night_brightness.gd` helper captures the actual game with no player records. Its before views override only these two values with their exact previous settings. The paired views freeze the same camera, world, car and simulation state. Existing tests are unchanged.

Actual successful commands, using pinned Godot 4.7.2 through the normal entry point and workspace-isolated APPDATA/LOCALAPPDATA:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File docs/evidence/night-brightness-2026-10-28/run.ps1 -ScriptPath res://tests/test_night_lighting.gd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File docs/evidence/night-brightness-2026-10-28/run.ps1 -Graphical
powershell.exe -NoProfile -ExecutionPolicy Bypass -File docs/evidence/night-brightness-2026-10-28/run.ps1 -Graphical -Renderer mobile
python docs/evidence/night-brightness-2026-10-28/record.py
```

NBR-Q01: Existing Night lighting regression passes **15 checks, 0 failures**. Native Compatibility and desktop Mobile each save **8 before/after captures** at 1280×720 and 1280×800, using a 0.667 3D scale. Both report zero capture/camera/canonical-state failures and exit 0. Visual inspection finds more ground detail in the unlit areas while the warm lamp pools remain distinct. These desktop views represent aspect ratios and render settings, not physical-device validation.

The first shell invocation hit the host execution policy; the subsequent process-local Bypass avoids changing system policy. Restricted runs failed on user-log/certificate-store access; workspace-isolated profiles and approved local execution resolve those access issues. The first native helper encountered the concurrent cosmetic validator's `Array`/`Array[String]` error when using disposable records. The final helper uses no records and leaves that unrelated runtime source untouched. The failed native run and all subsequent receipts are retained under `evidence/night-brightness-2026-10-28/logs/`.

NBR-R01: Reload/rebuild is required. Phone/tablet appearance in ordinary viewing conditions remains for owner acceptance. No device attachment query/test, APK, owner-save write, live/backend operation, deployment, owner-process restart, or main-index staging/commit/merge was performed. Concurrent changes and newer generated build metadata are preserved and excluded from the task source patch.

Evidence: [report and source hashes](evidence/night-brightness-2026-10-28/report.json), [scoped source patch](evidence/night-brightness-2026-10-28/source.patch), [before](evidence/night-brightness-2026-10-28/mobile/1280x800-view-1-before.png), [after](evidence/night-brightness-2026-10-28/mobile/1280x800-view-1-after.png).
