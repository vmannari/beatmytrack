# Header pictures and first Garage entry regression — 2026-11-06

The owner identified the desktop header/profile-button car and its picker, rather than the five Profile-page cards. Missing custom pictures can now be generated after the initial menu has drawn and input has been idle for 750 ms. They no longer require opening each car's Garage. Cheap queued disk reads precede native rendering, with the selected car first within each group; one native header world remains the limit. The first menu still does not await these pictures.

Garage preparation can start from the initial menu again. Its previous `CarVisual`-already-loaded requirement became a circular dependency after the menu-shell split. Header generation precedes live Garage preparation, and unrelated custom carousel photographs no longer hold the live studio. Ordinary Garage entry also no longer eagerly loads the parking-hall Test drive scene; that resource loads after the explicit Test drive loading cover.

Known non-rendering changes to Profile, menu consumers, localization, feature navigation and record persistence no longer invalidate the header/carousel photograph identities. Models, shaders, native code, rendering settings, capture factories and unknown dependencies still invalidate them. Appearance, owner and renderer keys remain. This narrows known exclusions rather than replacing the conservative dependency guard with an unreviewed allowlist. A normal build refreshes the generated identity; this change can therefore require one initial regeneration of older pictures.

## Requirements and changed sources

| ID | Change | Sources |
|---|---|---|
| HGR01 | Resolve custom header/picker images in settled menus, selected first; retain first-menu independence, exact disk reads, owner/appearance/navigation guards and bounded native ownership. | `game/core/app.gd`, `game/ui/header_car_appearance_cache.gd` |
| HGR02 | Restore initial-menu idle Garage preparation, prioritize the live studio and arbitrate header/carousel render ownership without a queued-job deadlock. | `game/ui/garage_preloader.gd`, `game/core/features/garage.gd` |
| HGR03 | Recheck ownership after asynchronous preparation before taking a graphics receipt or advancing settling draws. An interrupted/pre-empted studio cannot use a detached camera. | `game/ui/garage_preloaded_studio.gd` |
| HGR04 | Preserve saved pictures across reviewed non-visual changes; retain visual and unknown-source invalidation. | `scripts/build_identity.ps1`, `scripts/garage_preview_identity.ps1`, `scripts/test_build_identity.ps1` |
| HGRQ01 | Actual-App before/candidate measurements, all-five custom picker/restart, lifecycle, shell and Garage checks; private offline profiles and source receipts. | `game/tests/profile_header_garage_regression.gd`, `game/tests/test_header_capture_fences.gd`, `game/tests/test_deferred_header.gd`, retained fixtures and [evidence](evidence/header-garage-regression-2026-11-06/) |

This supersedes the November 5 restriction that allowed missing header captures only inside Garage. It retains the fast first-menu contract. Active input, held touches, text editing, page motion, foreground loss, memory pressure, race/loading state and account/appearance changes continue to gate work. Native rendering remains on the main/render threads: idle scheduling does not eliminate shader compilation or guarantee hitch-free interaction. Header and carousel captures do not run concurrently. The existing Garage cover remains for an admitted in-Garage header capture.

## Desktop observations

Stock pinned Godot `4.7.2.stable.official.ed1daf0bf`, Compatibility, RTX 3090, 1280×720, Dummy audio. The task-owned project freezes mutable sources and current prepared assets; static/imported/native resources use the existing shared-directory scheme. Each process uses a private offline profile except the explicit persisted-picture restart. Before/after source receipts contain no changes during accepted runs. These are individual observations, not medians, cleared-driver-cache tests or device claims. Other desktop activity was not controlled.

| Run | Header result on initial menu | Idle before Garage | Garage call through live studio + header readiness |
|---|---|---:|---:|
| Task-start runtime, one custom car | Still missing; zero captures | 30.016 s | 50.523 s |
| Candidate with corrected interrupted-preload handling, one custom car | Ready after 25.052 s; one capture | 30.354 s | 32.759 s |
| Five custom cars, complete idle preparation | All five ready; five captures | 58.521 s | 3.416 s |
| Separate restart reusing those exact PNGs, final lazy Test drive load | Selected picture ready after 62 ms; five disk hits, zero captures | 10.751 s | 1.722 s |

The first two runs retain the same 30-second idle target; a native frame can overrun a deadline. The latter two wait for complete preload and are **not** a like-for-like speedup ratio against the first row. The final restart's entry dispatch itself is 1.675 s, versus 3.339 s before the parking-hall resource became lazy. The five-car fresh and cached runs differ in both cache state and that last resource change; they do not isolate either saving.

The live-studio readiness metric does not include completion of every large Garage carousel photograph. Their placeholders remain until the existing independent thumbnail service finishes. First-menu measurements in these probes begin before loading App inside the already-running script (roughly 3.4–4.5 seconds); they exclude engine/test-script startup and are not full application launch times. The single custom header still needs substantial first-use native work on an empty cache. Total session work, smooth frame pacing, memory/thermal behavior and phone speed were not established.

Inspected native views: [final Garage](evidence/header-garage-regression-2026-11-06/cached-restart/garage.png), [all custom picker pictures](evidence/header-garage-regression-2026-11-06/cached-restart/picker.png). The persisted/reloaded selected header PNGs are byte-identical. Independent before/after renders differ at two of 19,712 pixels, with a maximum channel difference of 12/255; no pixel-exact independent-render claim is made. No camera, model, material, lighting, sampling or capture dimensions changed.

## Verification and retained findings

Completed checks include:

- Build identity: **33 checks passed**, including preserved menu/localization keys, visual/unknown-source invalidation and the full build identity.
- Production policy, input, owner, race, late-draw and render-exclusion fences: **28/0** frozen headless and through the normal entry point. The final current-source run adds real disk-read precedence over an eligible selected-car capture and passes **30/0** through `scripts/dev.ps1`.
- Retained first-menu dependency closure: **22/0**.
- Actual-App covered capture, disk-read fairness, exact PNG reload, save invalidation, account switch and navigation cancellation: **43/0** native Compatibility.
- All-five custom picker and fully prepared Garage: **13/0**; final separate-process cached restart: **14/0**.
- Retained native Garage warm scheduling, interrupted/resumed draws, view quality and adoption: **16/0**.
- Actual native electric Test drive, driving controls, pause/reset/background handling and return to the retained Garage: **25/0** after the lazy scene-load change.

The initial candidate exposed detached-camera errors after an incomplete preload was retired during entry. Its 15.553-second result is retained in `after-idle-initial` but excluded from the accepted performance comparison. The corrected run has no such diagnostics. Sandbox runs retain the environment's root-certificate-store error. The normal wrapper fails fast on that error; its initial receipt is retained as `entry-sandbox*`. The same isolated verification passed with native Windows access, through `scripts/dev.ps1`, and refreshed generated build identity normally. An incidental Pillow-based image comparison was unavailable; the recorded comparison uses Windows System.Drawing instead. No test invariant was removed to conceal these findings.

The first patch whitespace check rejected Windows CRLF in the newly generated validation JSON. `task-initial.patch` retains that attempt; the task's JSON writer now emits LF explicitly, and the same strict patch check and byte-exact round-trip are repeated. Existing runtime/source line endings are unchanged.

## Commands and review

Each `run.json` records the full engine command, profile, result, diagnostics and source changes; `sources.json` records the frozen sources. The runtime-under-test executable matches `godot-version.txt`. Frozen comparisons use that executable directly so the standard wrapper cannot regenerate build identity between variants. The final current-source check uses the normal entry point.

```powershell
python docs/evidence/header-garage-regression-2026-11-06/freeze_project.py
# Pass the project from frozen-project.json to these bounded private-profile runs:
python docs/evidence/header-garage-regression-2026-11-06/run_case.py <name> <fixture.gd> --project <frozen-game> --native
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_build_identity.ps1
python docs/evidence/header-garage-regression-2026-11-06/run_entry.py
```

Runtime/test snapshots and the [task-only patch](evidence/header-garage-regression-2026-11-06/task.patch) are kept with the evidence. [Validation](evidence/header-garage-regression-2026-11-06/validation.json) and [patch round-trip](evidence/header-garage-regression-2026-11-06/checkpoint.json) receipts record the checked outcome. The main Git index is not used. Existing concurrent work is preserved. Reload the local game to apply the changes. Owner acceptance, immediate-entry/cache-miss performance across other hardware and Mobile/Android validation remain. No device query/test, APK/export, owner-save or owner-process modification, live/backend request or deployment was performed.
