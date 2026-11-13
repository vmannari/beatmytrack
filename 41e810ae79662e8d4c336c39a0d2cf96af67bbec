# Carousel label overlays its garage picture (2026-10-28)

CL05: The owner clarifies that the miniature garage must show through the translucent car-name strip. Previously the label occupied a separate row below the picture, exposing the full page background. The picture now fills the card and a 36-pixel caption panel overlays its bottom edge. A two-pixel inset keeps the selected border visible.

The centered, unnumbered names remain. Caption opacity stays 58% normally, 72% on hover and 82% while pressed. The caption ignores pointer input so the original card selection and carousel gestures retain their existing targets. This is a layout change in `game/ui/garage_page.gd`; it adds no picture reads, capture worlds or assets.

The existing `capture_carousel_label_review.gd` helper runs unchanged through pinned Godot 4.7.2 with isolated storage and an empty backend URL:

```text
python docs/evidence/carousel-label-overlay-2026-10-28/run_checks.py native-gl capture_carousel_label_review.gd gl_compatibility
```

The native Compatibility run exits successfully with no script/runtime errors and saves 12 screenshots: all six catalogue cars, four viewport sizes, workshop return, hover and keyboard focus. The [normal Garage capture](evidence/carousel-label-overlay-2026-10-28/native-gl/compact-1280x720.png) visibly retains the miniature turntable and floor behind the caption. The portrait capture is a desktop layout diagnostic, not phone acceptance. No new regression tests are added for this reversible layout correction.

[report.json](evidence/carousel-label-overlay-2026-10-28/report.json) records the exact command, source hashes, existing capture output and source-only checkpoint. The patch includes this task's one runtime file change only; earlier Garage preparation and concurrent workshop changes stay in its baseline. Generated build metadata is archived, preserved and excluded.

Reload/rebuild and owner appearance acceptance remain. No physical-device query/test, APK, real authentication/purchase, owner-save/live mutation, deployment, owner-process restart, main-index staging, commit or merge was performed.
