# Carousel car labels (2026-10-28)

The Garage presents the car name without its catalogue number. The large heading and carousel captions are centered while browsing cars. The owner's [follow-up correction](CAROUSEL_LABEL_OVERLAY_2026_10_28.md) places the translucent caption over the miniature garage picture, replacing the separate footer that exposed the full page background.

| Requirement | Implementation |
| --- | --- |
| CL01 | Remove the ` / 01` suffix from Garage names, tooltips and accessible button names using a local presentation helper. Shared catalogue data and vehicle identities remain unchanged. |
| CL02 | Center captions horizontally and vertically. Center the main heading in the available preview width while browsing, with bounded text and existing workshop-control clearance. |
| CL03 | Use 58% opaque caption/card backgrounds, 72% on hover and 82% while pressed. The main heading shade is 24% opaque. |
| CL04 | Round card corners, soften inactive borders, retain the gold selected name/border and keyboard focus, and add a subtle heading shadow. |

The only runtime source changed by this pass is `game/ui/garage_page.gd`. `game/tests/capture_carousel_label_review.gd` is a capture helper, with no new regression assertions. This pass does not edit existing tests. No new images, shaders, render worlds or dependencies are introduced.

Native views:

- [Full Garage](evidence/carousel-car-label-2026-10-28/native-compatibility-local/compact-1280x720.png).
- [960 × 540](evidence/carousel-car-label-2026-10-28/native-compatibility-local/compact-960x540.png).
- [Last car and final carousel cards, desktop Mobile](evidence/carousel-car-label-2026-10-28/native-mobile/electric-1280x720.png).
- [Keyboard focus](evidence/carousel-car-label-2026-10-28/native-compatibility-local/keyboard-focus.png).
- [Workshop clearance](evidence/carousel-car-label-2026-10-28/native-compatibility-local/workshop.png).

Actual commands and outcomes are in [report.json](evidence/carousel-car-label-2026-10-28/report.json), alongside logs, 13 captures per desktop renderer and a source-only `task.patch`. Run checks through the pinned Godot 4.7.2 wrapper:

```text
python docs/evidence/carousel-car-label-2026-10-28/run_checks.py parse res://ui/garage_page.gd check
python docs/evidence/carousel-car-label-2026-10-28/run_checks.py native-compatibility-local capture_carousel_label_review.gd gl_compatibility
python docs/evidence/carousel-car-label-2026-10-28/run_checks.py native-mobile capture_carousel_label_review.gd mobile
python docs/evidence/carousel-car-label-2026-10-28/run_checks.py retained-entry test_garage_entry_carousel.gd gl_compatibility
```

The first sandboxed native attempt stopped at Windows certificate-store/access errors. The isolated local native runs completed cleanly. Capture reviews cover all seven cars, four window sizes (including a desktop portrait diagnostic), workshop return, hover and keyboard focus. They are visual/layout evidence, not physical-device tests or performance measurements.

The preferred source check passes. The existing actual-App Garage entry regression passes 85 checks with zero failures. Both native capture runs exit cleanly and save 13 views each. Recorded layout values confirm all seven captions are centered and unnumbered with 58% opaque normal backgrounds; every browsing heading shares the preview's horizontal center. The source patch passes `git apply --check --reverse` and the runtime diff passes `git diff --check`.

Reload to see the changes. Owner appearance acceptance and Android touch/readability acceptance remain. No device attachment query or physical-device test, APK, live authentication/purchase, owner-save/backend mutation, deployment, owner-process restart, main-index staging, commit or merge was performed. Existing concurrent changes are preserved. Development-wrapper build metadata is archived and restored separately from the source checkpoint.
