# Remaining car-picture delay investigated - 2026-11-17

CPI01 investigates the remaining startup delay. CPI02 investigates opening the
car dropdown, as clarified by the owner. CPI03 compares bounded improvements while
keeping this task an investigation. No production behaviour was changed.

The cache is working. The remaining delay has several distinct causes:

1. The dropdown deliberately fades from transparent over 220 ms, even with every
   picture already available. Its first draw was around 6–13 ms after opening in
   the final fixtures, at roughly 19–39% opacity. The second, settled opening took
   about 204–218 ms to reach full opacity. These are animation timings, not PNG
   loading. The first opening follows synchronous benchmark loops; the tween can
   consume that preceding long frame's delta and finish sooner. Its shorter
   107–123 ms wall time should not be interpreted as a stable opening target.
2. Cached pictures restore through one worker job per car. Each read completes
   cheaply, but the main thread publishes it and dispatches the next car on a
   later frame. The selected car already has priority; it does not wait behind
   all six. The other five pictures accumulate frame waits, especially at 30 fps.
3. Opening an already warm dropdown requests a full cache scan. Each scan emits
   six `changed` notifications despite unchanged textures. Retained header,
   dropdown and Garage views repeat their lookups and refreshes. Twenty repeated
   opens produced 120 extra notifications. This is avoidable CPU work, although
   it is smaller than the visible animation and multi-frame loading costs.
4. Startup also contains synchronous App setup before the cache's first process
   opportunity. In the final actual offline-App probes, `_ready` occupied
   212/260 ms on Compatibility/Mobile. The selected picture published at 229/280 ms;
   all six were published at 313/370 ms. These clocks start immediately before
   adding an already-loaded App script to the tree. They exclude engine launch,
   script loading before the probe and online account restoration, and are not
   whole-app startup measurements.

Final desktop samples, medians of three runs per row. Times end at the last
picture publication rather than the following test-observation frame:

| Renderer / frame cap | Current all six | Audit prototype all six | Warm dropdown CPU, current → prototype |
|---|---:|---:|---:|
| Compatibility / 60 | 103.6 ms | 72.4 ms | 4.88 → 1.31 ms |
| Compatibility / 30 | 197.7 ms | 132.8 ms | 4.96 → 1.00 ms |
| Mobile/Vulkan desktop / 60 | 101.3 ms | 69.3 ms | 4.71 → 1.23 ms |
| Mobile/Vulkan desktop / 30 | 197.2 ms | 132.6 ms | 4.78 → 1.13 ms |

The prototype reads the selected PNG first, then the other five in one worker
batch, publishing at most two textures per frame. It also avoids a full rescan
when all current pictures are already available. Its warm-open notifications
drop from six to zero. Selected-picture medians remain roughly 24–40 ms across
frame caps; this small sample does not establish a selected-picture speedup.
The combined prototype's maximum observed cache-process interval was 4.94 ms on
Compatibility and 3.67 ms on desktop Mobile, versus current maxima of 5.90/2.56 ms.
Batching can increase an individual frame's work even while reducing total wait.
The audit includes a batch-only variant to distinguish batching from reduced
refresh work; raw samples and ranges are retained in the report.

Direct warm-file read/decode probes were generally around 1.5–3 ms per PNG,
including the key lookup. Fixture PNGs are 36–88 KiB, using the six shipped image
files under private valid keys. Their assigned custom settings are intentional
IO fixtures; they do not qualify those images as correct painted-car artwork.
These timings do not measure cold filesystem storage or phone performance.

Another development-build issue is confirmed separately: the shared header
visual identity includes `game/editor/view_state.gd`,
`game/editor/object_properties.gd`, and the cache scheduling implementation itself.
Thus changes in those files invalidate every customised picture when generated
identity is refreshed. App layout and translations are already excluded. This
can cause fresh rendering on an updated development build despite unchanged car
pixels. One car's model changes also invalidate every car through the shared
revision. Narrowing that boundary needs a verified rendering dependency manifest;
this audit did not reuse or relabel stale images.

Recommended implementation order:

1. Stop redundant warm-dropdown requests/notifications and shorten the opening
   fade. The fade is the largest directly visible warm-open cost found here.
2. Integrate selected-first batched PNG reads, retaining a frame publication
   budget. The fixture prototype still needs production handling for misses,
   corrupt files, captures, foreground/race restrictions, account replacement,
   stale appearances, cancellation and memory pressure before publication.
3. Start the selected read during binding where safe, and separately profile
   synchronous App setup. Cache scheduling alone cannot eliminate that setup.
4. Audit and narrow nonvisual invalidation inputs, with changed-renderer/model
   negative controls. Do not weaken freshness checks to hide misses.

Changed files are diagnostic only: `game/tests/audit_car_picture_loading.gd`
(current path plus private hit-only prototypes),
`scripts/audit_picture_identity_inputs.ps1`,
`scripts/summarize_picture_loading_audit.py`, and this report. The production
profile, dropdown, carousel, cache, identities and settings were not authored.
Both desktop renderers complete 254 checks with zero rejections; all fixture
views share the same cached texture objects, and the actual App restores six
PNGs with zero captures. Production parser: 583 scripts, zero failures.

Actual commands:

```powershell
python scripts/run_shared_car_pictures.py gl_compatibility-loading-audit-2026-11-17 res://tests/audit_car_picture_loading.gd --direct
python scripts/run_shared_car_pictures.py gl_compatibility-loading-audit-paired-2026-11-17 res://tests/audit_car_picture_loading.gd --direct
python scripts/run_shared_car_pictures.py mobile-loading-audit-paired-2026-11-17 res://tests/audit_car_picture_loading.gd --direct
python scripts/run_shared_car_pictures.py gl_compatibility-loading-audit-final-2026-11-17 res://tests/audit_car_picture_loading.gd --direct
python scripts/run_shared_car_pictures.py mobile-loading-audit-final-2026-11-17 res://tests/audit_car_picture_loading.gd --direct
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/audit_picture_identity_inputs.ps1
python scripts/summarize_picture_loading_audit.py
python scripts/run_shared_car_pictures.py headless-loading-audit-parse-2026-11-17 res://tests/check_model_refinement_parse.gd --direct
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

The initial inline PowerShell identity probe was rejected by the shell's script
execution policy. The explicit process-local `-ExecutionPolicy Bypass -File`
invocation above completed without changing the user's execution policy.

[Summary, ranges and source hashes](evidence/car-picture-loading-audit-2026-11-17/report.json)
and [identity-input probe](evidence/car-picture-loading-audit-2026-11-17/identity-inputs.json).
Raw commands and logs remain in the linked evidence folders. The source-only
private checkpoint is checked in both directions and excludes concurrent work
and the shared index. Standard build retention applies.

No UI appearance change was applied, so no before/after appearance claim is made.
No physical-device query/test, owner-save access/edit, owner-process action,
export, backend/live service request or deployment was performed. Phone startup,
real cold launch, signed-in networking and owner acceptance remain unmeasured.
