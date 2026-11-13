# Thumbnail studio: seamless backdrop and reflected turntable — 2026-11-04

The owner rejected the plain matte studio and asked for a better background and reflections. The final carousel uses a soft, seamless navy studio backdrop, brighter car lighting and a polished graphite turntable with a restrained brass rim. The interim blue vertical light strips and their horizontal connector were removed after the owner's follow-up; the final background has no light-line geometry or shader stripes.

The turntable reflection is an actual planar capture of the current car, including its saved paint, pattern, fitted parts and condition. It shares the existing 3D world and model, with one 768×192 transparent capture at 2× MSAA. Its camera reflects across the deck surface while retaining right-handed face winding. The deck blends that image with a softened five-tap sample and a viewing-angle response. The contact shadows remain separate from the reflected car layer.

The main photograph remains 2048×512 at 4× MSAA. Each missing thumbnail now owns two viewports instead of one; it still builds no workshop or duplicate car. Cached thumbnails remain ordinary pictures and own no active 3D world. The existing scheduling, input/visibility gates and async PNG read/write overlap remain. The live full Garage and animated loading ghosts were not restyled.

`garage-thumbnail-studio-v5` invalidates old plain pictures and the intermediate version with blue lines. All five bundled factory pictures were regenerated using the final studio. The preview baker and build-source classification include the new reflection helper and shaders, so later builds and bakes retain correct picture provenance.

## Cost comparison

The actual production service prepared five customized uncached pictures in a private cache, with the same saved cosmetics, capture resolution, AA and scheduling before and after the change. The baseline and final run each contain one first batch and two later uncached batches:

| Compatibility desktop measurement | Plain studio | Final reflected studio |
| --- | ---: | ---: |
| First batch, all pictures published | 20.345 s | 25.756 s |
| Median of next two batches, pictures published | 1.450 s | 1.620 s |
| Median of next two batches, PNG writes completed | 1.878 s | 1.716 s |

The later picture preparation cost increased by about **0.17 s per five newly generated pictures (11.7%)** in this sample. PNG persistence completed sooner; compression and queued write overlap differ with picture content. The first-process sample was 5.41 s slower. These are small shared-desktop samples, not a statistical or isolated shader-compilation result. Build metadata changed during the final run; car/render sources were stable within the recorded runs. No complete-game-startup, phone, cold-driver or FPS claim is made.

Aggregate viewport pixels increase from 1,048,576 to 1,196,032 (+14.1%). The conservative referenced scene-resource estimate increases by 325,248 bytes per car (about 0.31 MiB), primarily the new deck geometry. This is not a measurement of incremental RAM or GPU allocation. The added reflection shares the full car's existing geometry, and its temporary resources are released after capture; cached reuse starts no 3D captures.

## Native verification

The source snapshots, native images, logs and per-run receipts are retained under `docs/evidence/thumbnail-studio-polish-2026-11-04/`. Native on/off/reflection-map captures cover all five car models with varied body colors and patterns. The final reflection changes 10,258–38,200 visible pixels, while repeated unchanged controls have zero changed pixels. Each reflection image has both real car pixels and transparent surroundings; each capture shares its owner's world and uses the car layer only. Resource-release and hidden/input pause checks are included.

**315 native Compatibility checks pass with zero failures**, with thirty accepted native captures and five regenerated bundled pictures. Counts: appearance/reflection proof 65/0, production service/migration 96/0, pipeline 3/0, persistence 78/0, actual-App deferred entry 61/0 and varied-color App captures 12/0. The preview checker passes five images and 153 current source hashes. [summary.json](evidence/thumbnail-studio-polish-2026-11-04/summary.json) records the accepted receipts, durable reuse, timing rows and source fingerprints. See the [actual five-car carousel](evidence/thumbnail-studio-polish-2026-11-04/gallery-accepted/garage-1920x900.png).

Baseline and interim previews remain separate from accepted final checks. `preview-v1` and `preview-v2` retain the discarded light-line appearance; `appearance/` and the final production/App captures show the seamless version.

The first persistence pair crossed a concurrent generated-build-identity update. Its reuse process correctly could not find the previous identity's PNGs while native rendering was intentionally prohibited by the fixture. The old fixture continued after its initial deadline failure and emitted secondary null-texture errors; these failures remain in `persistent-reuse.log` and are not counted as accepted checks. A normal cleanup attempt was denied by Windows; the subsequent guarded cleanup found that the recorded process had already exited and terminated nothing. A fresh seed/reuse pair with unchanged metadata passes all 78 checks, preserves all five decoded pixel hashes and starts zero captures on reuse (134.436 ms readiness in that fixture). No identity gate or rendering assertion was relaxed.

The first varied-color App capture fixture omitted creation of its private records directory; its two save/selected-car failures are retained. The next version waited for an offscreen custom car while the real production visibility gate correctly postponed its capture. The accepted fixture creates its directory, uses a wider initial view and scrolls to missing offscreen cards after visible cards finish, following the retained deferred-entry fixture. Production visibility/input gates remain intact. An early summary invocation before the pending App capture completed simply found no report yet; the completed summary uses accepted receipts only.

Commands, from the workspace root:

```powershell
python docs/evidence/thumbnail-studio-polish-2026-11-04/run_check.py appearance --script res://tests/test_thumbnail_studio_appearance.gd
python docs/evidence/thumbnail-studio-polish-2026-11-04/run_check.py production-final
python docs/evidence/thumbnail-studio-polish-2026-11-04/run_check.py bake-final --script res://../scripts/bake_garage_previews.gd
python docs/evidence/thumbnail-studio-polish-2026-11-04/run_check.py import-assets --import-assets
python scripts/check_garage_previews.py
python docs/evidence/thumbnail-studio-polish-2026-11-04/verify.py
python docs/evidence/thumbnail-studio-polish-2026-11-04/summarize.py
python docs/evidence/thumbnail-studio-polish-2026-11-04/checkpoint.py
```

Use new labels/cache directories when repeating to retain earlier receipts. The runner uses pinned Godot 4.7.2 through `scripts/run_no_crash_dialog.py`, private APPDATA, disabled backend configuration and bounded waits. The source/binary checkpoint applies, reverses and compares content in an isolated build directory without writing the main Git index. Native logs retain the Windows certificate-store environment error. Any other recorded failures are described in the adjacent receipts and summary.

Reload and owner appearance/device acceptance remain. No device query/test, APK/export, owner-save/process change, live/backend mutation or deployment occurred. Concurrent work was preserved.
