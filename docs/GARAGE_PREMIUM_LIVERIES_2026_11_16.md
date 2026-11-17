# Premium livery previews in Garage - 2026-11-16

GP01-GP03 fix the missing Garage entry for the 18 portrait-free liveries. The artwork previously existed only in the review catalogue and external gallery. After reloading the game, open **Garage > select a car > Appearance > Patterns > Premium**. [Actual App view](evidence/garage-premium-2026-11-16/gl_compatibility/app-premium-1280.png), [compact layout](evidence/garage-premium-2026-11-16/gl_compatibility/premium-960.png).

Patterns now has Standard/Premium selectors. Standard retains all 49 existing paint choices and its original purchase/equip flow. Premium shows exactly the current car's three designs, native model icons and a clear **Coming soon - Preview only** notice. Tapping a row uses the existing live-car paint animation. Restore equipped paint returns the exact saved palette and stickers. The selected collection survives car changes; its designs rebuild for the new car. Leaving Patterns, switching collection/car, hiding the Garage or changing account cancels the temporary preview through the existing preview lifecycle.

Premium has no purchase/equip action, ownership badge or coin price, and the generic equip callback also rejects this preview kind. The preview never mutates the draft appearance or saved records. Existing geometry, camera, fitted parts and paint artwork are retained. Visible icons reuse the normal 24-image paint cache and one temporary studio per active browser; hidden premium work is cancelled and its studio released. The 18 source PNGs and seven original paint/render inputs retain their exact hashes. No image regeneration, ordinary livery rendering, economy catalogue, backend allowlist or purchase integration changes were needed.

Final headless **495/0**, Compatibility with actual App **550/0**, desktop Mobile with actual App **550/0**. Existing standard paint-list checks **147/0**, production parse **581/0**. There are 22 final native captures per desktop renderer: all 18 designs on the actual Garage models, the Standard discovery view, two preview layouts and the complete actual App. Checks use real mouse/touch events, all six cars, 960x540 and 1280x720, exact saved palettes/stickers, meshes/camera, icon/cache bounds, wrong-car/unknown IDs, account/tab/collection cancellation and rejected purchase/save attempts.

Initial fixtures used a property available only on the progressive showroom and compared Vector2 with Vector2i; both were corrected without changing product assertions. The first App capture was taken during the existing paint animation; final captures wait for paint/car/kit transitions and check every premium paint binding. One Compatibility restore input observation failed in an earlier run. That failed log/receipt is retained; the final run retains the exact restore gate with per-car failure diagnostics. No assertion was relaxed.

```powershell
python scripts/run_garage_premium.py headless
python scripts/run_garage_premium.py gl_compatibility --app
python scripts/run_garage_premium.py mobile --app
python scripts/run_garage_premium.py standard
python scripts/run_garage_premium.py parse
python scripts/finalize_garage_premium.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Runs use isolated application-data directories and dummy audio. No owner profile or process is changed; the one stopped process was an owned failed test run. Production edits are limited to `garage_page.gd`, `garage_livery_menu.gd` and new `garage_premium_liveries.gd`. Focused tests and a runner/finalizer support the change. The [receipt](evidence/garage-premium-2026-11-16/report.json) records source/art/native-view hashes. `task-source.patch` is a forward/reverse-verified private source checkpoint. The shared index and concurrent car-stat work are preserved. Standard build retention runs without a task pin.

The designs are now inspectable in Garage. They remain previews pending paid-product setup and owner appearance acceptance. There is no physical-device, FPS, paid-release, export, backend or deployment claim.
