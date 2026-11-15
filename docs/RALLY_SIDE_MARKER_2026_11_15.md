# Rally side reflector clearance — 15 November 2026

RSM01: move the amber side reflectors clear of the front fenders shown in the owner's screenshot.

Both existing markers now sit at Y=0.895 m instead of 0.820 m, a 75 mm lift. Z=-0.990 m and the original 20×32×66 mm lens size remain. Their lateral coordinates follow the original body-width function at the new height. The nearest lens corner is beyond the conservative 0.557 m maximum fitted-arch radius by over 10 mm in side projection. Stock, Rally and wide kits retain a visible gap on both sides.

The authored change is in `game/vehicle/compact_detail.gd`. Four new complete-frame recipe JSON files in `car_detail_v1` and `car_surface_v1` retain every non-marker member code and every previous reduction row. The two markers have no reduction rows. Fixed and editable contexts retain 166/216 other members respectively; the opaque recipes retain 61/62 rows and the surface recipes 24/25 rows. No reduction gate is relaxed. Lens mesh, materials, topology and car handling remain unchanged.

Prepared base, kit, Garage and header consumers were actually rebuilt. The existing shared dependency also requires refreshing Challenger caches; its model sources were not authored. Two catalogue photographs and the Rally header photograph were regenerated and all three native imports checked against their PNG MD5s. Source and final prepared side views were reviewed on Compatibility and desktop Mobile/Vulkan.

- [Before, wide fender](evidence/rally-marker-2026-11-15/before-gl_compatibility-wide--1.0.png)
- [After, wide fender](evidence/rally-marker-2026-11-15/after-gl_compatibility-wide--1.0.png)
- [After, opposite side](evidence/rally-marker-2026-11-15/after-gl_compatibility-wide-1.0.png)
- [After, Rally kit](evidence/rally-marker-2026-11-15/after-gl_compatibility-rally--1.0.png)
- [After, stock](evidence/rally-marker-2026-11-15/after-gl_compatibility-stock--1.0.png)

Actual commands and results:

```text
python scripts/run_rally_marker.py before res://tests/review_rally_marker.gd --rendering-method gl_compatibility
  Four original frames recorded; six native side views saved.
python scripts/run_rally_marker.py migrate res://tests/review_rally_marker.gd --headless -- --mode=migrate
  Four exact retained-member recipe migrations; eight marker observations pass.
python scripts/run_rally_marker.py after-gl res://tests/review_rally_marker.gd --rendering-method gl_compatibility -- --mode=after
python scripts/run_rally_marker.py after-mobile res://tests/review_rally_marker.gd --rendering-method mobile -- --mode=after
  Source review passes both renderers; six images each.
python scripts/refresh_rally_marker.py
  Both affected cars' bases, 78 kits each, Garage and header rebuild successfully.
  18,752-input source fence unchanged. Identity-before and identity-after car keys exact.
  Initial whole-project preflight: 551 resources, 2267 checks, 468 failures, all Forklift/Volt key/source findings.
python scripts/run_rally_marker.py prepared-gl-final res://tests/review_rally_marker.gd --rendering-method gl_compatibility -- --mode=after --prepared
python scripts/run_rally_marker.py prepared-mobile res://tests/review_rally_marker.gd --rendering-method mobile -- --mode=after --prepared
  Actual prepared-base hits required; stock/Rally/wide views pass both renderers.
python scripts/artwork_rally_marker.py
  Two scoped catalogue pictures and one header picture regenerated; three imports verified.
  Scoped catalogue check: two exact native images, 176 current source hashes.
  Final prepared validation: 167 resources, 691 checks, zero failures.
python scripts/run_rally_marker.py parser res://tests/check_model_refinement_parse.gd --headless
  580 production scripts, zero failures.
python scripts/run_rally_marker.py app-gl res://tests/test_rally_marker_app.gd --rendering-method gl_compatibility
python scripts/run_rally_marker.py app-mobile res://tests/test_rally_marker_app.gd --rendering-method mobile
  Actual Garage/race integration: eight checks, zero failures on each desktop renderer.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
  Standard retention applied; receipt retained with this evidence.
python scripts/checkpoint_rally_marker.py
  Task-only private Git checkpoint and source.patch; forward/reverse byte checks and shared-index control.
```

The original first prepared-view attempt failed because the review script left its procedural-only cache switch disabled. Enabling the prepared cache fixes the fixture; the actual prepared-hit assertion remains and passes. The initial unscoped catalogue check also rejected other cars' stale revisions. Their Forklift/Volt cache findings are outside this reflector change; all scoped checks retain their original assertions. The refresh script now requests scoped validation. Historical failed preflight and prepared-view receipts remain in the evidence directory.

Full commands, engine paths, exit codes and diagnostics are in the adjacent `*-receipt.json` files. The engine is the exact build in `godot-version.txt`; runners use task-owned APPDATA/LOCALAPPDATA and disabled API settings. No owner-save/process action, export, backend change, deployment or shared-index staging was performed. No physical-device test was performed. Reload the running game to review the new marker position; owner appearance and phone acceptance remain.
