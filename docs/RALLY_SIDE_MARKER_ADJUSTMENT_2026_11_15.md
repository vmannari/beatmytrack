# Rally reflector placement revision — 15 November 2026

RSM02 supersedes the RSM01 placement after owner review: both amber side reflectors move 25 mm down and 50 mm rearward. Final centres are Y=0.870 m, Z=-0.940 m. The original 20×32×66 mm lens size, materials and mirrored placement remain; X follows the existing body-width function at the revised height and depth.

The nearest lens corner remains more than 10 mm outside the conservative maximum fitted-fender envelope in side projection. Stock, Rally and wide kit views retain a visible gap. Four new complete-frame recipes preserve all non-marker member codes and all previous reduction rows. The body builder is `game/vehicle/compact_detail.gd`; the supporting scripts and native review entry point use the `rally_marker_adjustment` suffix.

- [Previous position](evidence/rally-marker-adjustment-2026-11-15/before-gl_compatibility-wide--1.0.png)
- [Revised position, wide fender](evidence/rally-marker-adjustment-2026-11-15/after-gl_compatibility-wide--1.0.png)
- [Revised position, other side](evidence/rally-marker-adjustment-2026-11-15/after-gl_compatibility-wide-1.0.png)
- [Revised position, Rally kit](evidence/rally-marker-adjustment-2026-11-15/after-gl_compatibility-rally--1.0.png)

Actual commands already completed:

```text
python scripts/run_rally_marker_adjustment.py before res://tests/review_rally_marker_adjustment.gd --rendering-method gl_compatibility
  Four original frames recorded; six native side views saved.
python scripts/run_rally_marker_adjustment.py migrate res://tests/review_rally_marker_adjustment.gd --headless -- --mode=migrate
  Four retained-member recipe migrations; eight marker observations pass.
python scripts/run_rally_marker_adjustment.py after-gl res://tests/review_rally_marker_adjustment.gd --rendering-method gl_compatibility -- --mode=after
python scripts/run_rally_marker_adjustment.py after-mobile-ready res://tests/review_rally_marker_adjustment.gd --rendering-method mobile -- --mode=after
  Source and clearance review pass both desktop renderers, six images each.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
  Standard retention applied; no task pin.
```

The first rebuild encountered a concurrent `livery_catalog.gd` edit referencing a not-yet-present premium catalogue. Its generated files subsequently appeared. An owned headless editor import completed but the project-settings checksum guard rejected that attempt; concurrent settings were preserved. An initial Mobile review stalled during these changes and only that task-owned process was stopped. The later complete Mobile review passed without weakening assertions. Attempts to run the existing premium artwork builder could not import its newer fontTools dependency under the installed Python 3.10; no artwork was authored by this reflector task.

Further actual commands and outcomes:

```text
python scripts/refresh_rally_marker_adjustment.py
  Both affected cars' four base variants, 78 kits each, Garage and header consumers rebuilt.
  Repeated 18,776-input fences reject continuing edits to eighteen premium SVGs;
  the later fence also rejects a concurrent vehicle_livery.gd edit.
python scripts/run_rally_marker_adjustment.py prepared-gl res://tests/review_rally_marker_adjustment.gd --rendering-method gl_compatibility -- --mode=after --prepared
  Actual prepared-base hits and retained-member/clearance assertions pass.
python scripts/artwork_rally_marker_adjustment.py --skip-identity
  Two scoped catalogue pictures and one header picture regenerated.
  Scoped catalogue check passes: two native images, 176 current source hashes.
  Three native imports verified, zero editor diagnostics, project settings unchanged on retry.
  Prepared preflight rejects 82 current-source findings across 167 resources/691 checks
  after the concurrent livery files change. No assertion is relaxed.
python scripts/run_rally_marker_adjustment.py app-gl res://tests/test_rally_marker_adjustment_app.gd --rendering-method gl_compatibility
  Actual Garage/race integration: eight checks, zero failures.
python scripts/checkpoint_rally_marker_adjustment.py
  Private task-only Git checkpoint and source.patch, with forward/reverse byte checks.
```

The source placement and native/App checks are complete. Prepared outputs and pictures were rebuilt, but continued livery authoring invalidates their full source/key readiness. This task makes no final current-cache or whole-project validation claim. The normal current-source fallback retains the authored placement; final cache refresh must follow the concurrent livery work. Initial concurrent-fence and prepared-failure logs are retained separately. The latest source fence also lists `vehicle_livery.gd`; its changes remain outside this source checkpoint.

Command arguments, pinned engine build, exit status, timing and diagnostics are retained in the evidence directory. Runners use isolated APPDATA/LOCALAPPDATA and disabled API settings. No owner-process restart, owner-save action, device test, export, backend change, deployment or shared-index staging was performed. Owner appearance and physical-device acceptance remain.
