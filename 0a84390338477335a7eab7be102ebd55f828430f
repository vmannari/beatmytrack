# Header car dropdown recovery (2026-11-08)

Opening the header car dropdown previously only read available textures. It did
not ask the appearance service to recover missing entries. After an entry was
evicted from the bounded memory cache, an idle service could leave that dropdown
picture missing indefinitely, until another appearance scan happened.

The picker now requests an appearance scan when populated. The service checks
that the requesting records object is still its current owner, then reuses the
existing coalesced disk-read/capture queue. Exact appearance keys, rendering
eligibility, Garage visibility, memory limits and account fences remain in place.
This fixes a reproduced recovery gap; the owner's precise occurrence has not
been observed on their running instance.

Owned source changes: `game/ui/header_car_picker.gd` (callback and demand),
`game/ui/header_car_appearance_cache.gd` (`request_pictures`), and the picker
callback binding in `game/core/app.gd`. Other existing changes in these files
are concurrent work.

Regression: `game/tests/test_header_dropdown_delivery.gd` runs an actual offline
App with private custom paints for every catalogue car, opens the popup during cold capture, clears
the memory entries to simulate eviction, then reopens and verifies exact-key
pictures return from disk without additional captures. It also checks that a
different records owner cannot request work. `--old-demand` disables only the
new picker callback before reopening: all four dropdown entries fail recovery.
The production callback passes on desktop Compatibility and Mobile renderers.
Concurrent catalogue work adds `super_rally` between the first controls and final
runs; both final runs cover all six current cars and five dropdown entries.
Capture-fence regression passes 32 checks headless.

Commands and raw receipts are in `build/carousel-preview-20261107/`, using the
existing isolated offline runner `scripts/check_carousel_preview.py`:

```
python scripts/check_carousel_preview.py dropdown-final-compatibility res://tests/test_header_dropdown_delivery.gd --rendering-method gl_compatibility
python scripts/check_carousel_preview.py dropdown-final-mobile res://tests/test_header_dropdown_delivery.gd --rendering-method mobile
python scripts/check_carousel_preview.py dropdown-no-demand-control res://tests/test_header_dropdown_delivery.gd --rendering-method gl_compatibility -- --old-demand
```

For `test_header_capture_fences.gd`, set `BMT_LOADING_OUTPUT` to an existing
output folder's report path. The initial invocation omitted this variable and
failed writing its report after assertions; `dropdown-fences-final` is the
corrected passing run. Existing certificate-store diagnostics are retained.
The original stock-only diagnostic was corrected to save the custom fixture
before startup; cold runs exercise the saved custom designs.

Reload/rebuild is required. No physical-device test, APK export/install,
owner-save change, owner-process restart, live request, deployment or main-index
write was performed. Concurrent workspace work is preserved.
