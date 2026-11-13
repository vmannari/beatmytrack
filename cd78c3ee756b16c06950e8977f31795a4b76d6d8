# Volt Night window tint — 2026-11-06

The owner found the windows too light after the roof reflection fix. The Night environment was already active, but the windscreen/rear glass pigment `(0.10, 0.15, 0.19)` and side glass pigment `(0.095, 0.140, 0.175)` remained brighter than the panoramic roof `(0.026, 0.043, 0.055)`.

## Change and scope

- **VNW01 — darker Night windows.** `game/race/electric_glass_lighting.gd` caps each private Night material's display-space tint at the existing roof pigment. It preserves any already darker channel. The existing Night reflection, Fresnel response and geometry remain intact. No shader source, new shader variant, render pass or per-frame work is added.
- **VNW02 — retain other appearances and ownership.** The change uses the existing race-owned copies for the Volt in `night_city`. Restoring daylight returns the original materials. Prepared assets, source pigments, showroom materials, Hovercraft and the roof are retained. The full existing asset preflight passes without rebuilding anything.
- **VNWQ01 — native comparisons.** `game/tests/test_volt_night_windows.gd` extends the prior glass fixture, retaining its ownership/teardown checks. It compares the previous helper's pigments against the production helper on the same material instances, then uses separate window/roof masks. It covers full/simple prepared cars, four headings, ordinary race framing, day/studio, exact glass restoration, and unchanged track/simulation state. `game/tests/test_volt_night_glass.gd` now identifies the roof by its actual mesh name because several panes intentionally share its pigment. `game/tests/probe_volt_window_controls.gd` independently compares every changed pixel in the Mobile controls.

## Results and pictures

Final Compatibility: **398 checks, 0 failures**. Final desktop Mobile: **398 checks, 2 retained full-frame mask-restoration failures**. All window-darkness, exact roof-preservation, pane-restoration, day/studio, prepared-hit and canonical-state checks pass on both renderers. There are 76 captures per final renderer, 152 total.

Compatibility window mean RGB values fall from approximately **19.9–21.5 to 9.8–11.2** on a 0–255 scale. Mobile falls from **23.0–24.5 to 15.2–16.5**. The sampled roof pixels are byte-exact before/after in all sixteen views. Means include visible side windows, front/rear glass and mirror glass; they are image measurements, not physical light measurements.

- [Previous window tint](evidence/volt-night-windows-2026-11-06/final-compatibility/full-heading-270-before.png)
- [Darker windows](evidence/volt-night-windows-2026-11-06/final-compatibility/full-heading-270-after.png)
- [Ordinary race framing](evidence/volt-night-windows-2026-11-06/final-compatibility/full-race-after.png)
- [Desktop Mobile](evidence/volt-night-windows-2026-11-06/final-mobile/full-heading-270-after.png)

The first full-detail Mobile heading has the same 113 non-glass pixels change after each mask restoration. The previous-tint control records **398 checks, 10 failures**: eight expected window-darkness rejections plus those same two restoration failures. The independent pixel diagnostic passes **16 comparisons, 0 failures**, proving every changed coordinate and before/after colour matches between control and candidate. No assertion is removed or relaxed; the underlying whole-frame issue remains unresolved. This finding does not establish an engine-level cause.

Headless material checks pass **148/0**. The retained native Compatibility roof regression passes **290/0**, including the updated mesh-name selector. Complete prepared-asset verification passes **468 resources / 1,925 checks / 0 failures**; picture provenance passes **five exact native images / 156 current source hashes**. No asset bake or picture capture refresh is needed for this race-helper-only change.

The [summary](evidence/volt-night-windows-2026-11-06/summary.json) contains final receipts and the retained roof regression outcome. The [task-only patch](evidence/volt-night-windows-2026-11-06/task.patch) and [checkpoint receipt](evidence/volt-night-windows-2026-11-06/checkpoint.json) verify forward and reverse application with exact bytes in private Git repositories. The workspace Git index is untouched.

## Actual commands and retained findings

```powershell
python docs/evidence/volt-night-windows-2026-11-06/run_check.py headless res://tests/test_volt_night_windows.gd
python scripts/prepare_car_assets.py --verify --output docs/evidence/volt-night-windows-2026-11-06/preflight
python docs/evidence/volt-night-windows-2026-11-06/run_check.py compatibility res://tests/test_volt_night_windows.gd --native
python docs/evidence/volt-night-windows-2026-11-06/run_check.py mobile res://tests/test_volt_night_windows.gd --native --renderer mobile
python docs/evidence/volt-night-windows-2026-11-06/run_check.py dev-headless res://tests/test_volt_night_windows.gd --dev
python docs/evidence/volt-night-windows-2026-11-06/run_check.py mobile-before-control res://tests/test_volt_night_windows.gd --native --renderer mobile --verbose --before-windows
python docs/evidence/volt-night-windows-2026-11-06/run_check.py final-mobile res://tests/test_volt_night_windows.gd --native --renderer mobile --verbose
python docs/evidence/volt-night-windows-2026-11-06/run_check.py final-compatibility res://tests/test_volt_night_windows.gd --native
python docs/evidence/volt-night-windows-2026-11-06/run_check.py matched-mobile-controls res://tests/probe_volt_window_controls.gd
python docs/evidence/volt-night-windows-2026-11-06/run_check.py retained-roof res://tests/test_volt_night_glass.gd --native
python docs/evidence/volt-night-windows-2026-11-06/run_check.py final-headless res://tests/test_volt_night_windows.gd
python docs/evidence/volt-night-windows-2026-11-06/finalize.py
python docs/evidence/volt-night-windows-2026-11-06/checkpoint.py
```

The runner pins Godot `4.7.2.stable.official.ed1daf0bf`, isolates APPDATA/LOCALAPPDATA, disables backend URL access and uses Dummy audio through the crash-dialog wrapper. Receipts contain commands, exits, source hashes and script/shader error lists. Initial native runs record 382/0 Compatibility and 382/2 Mobile; later instrumentation adds exact pane-restoration checks and diagnostic evidence, retaining the same full-frame assertions.

The standard `scripts/dev.ps1` invocation refreshed generated build identity but its wrapper exited 1 with `Access denied`; its child subsequently wrote a 148/0 report. That invocation is not counted as a successful command. The direct pinned Dummy-audio headless command exited 0. Certificate-store errors occur in local runs. Mobile candidate and previous-tint control both retain identical shutdown warnings for 54 ObjectDB instances / 10 resources; verbose logs identify audio resources. The final Compatibility window fixture exits cleanly apart from the certificate-store message; the retained roof fixture reports two ObjectDB instances / one resource at shutdown. The initial attempt to view a capture before it existed was retried after rendering completed. Adding the final headless receipt exposed an empty pixel-summary list in the documentation helper; limiting pixel summaries to native runs corrected it without changing any test assertion.

## Delivery limits

This is a local source change and needs a newly loaded PC game instance or a newly built application. No owner process was restarted, no owner save was changed, and no device query/test, APK, backend request or deployment was performed. Physical-device appearance and owner acceptance remain outstanding. Generated build metadata and concurrent work are excluded from the scoped checkpoint.
