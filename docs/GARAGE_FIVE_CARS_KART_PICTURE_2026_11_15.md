# Five Garage cards and matching Kart overalls - 2026-11-15

G5K01: the short Garage carousel now fits five complete cards at 1280 x 720, and four at 960 x 540. The responsive target changes from 280 px / maximum four cards to 200 px / maximum five. The sixth car remains reachable by scrolling. The row remains 115 / 96 px high and the actual live 3D view remains 423 / 269 px high at those window sizes. Existing titles, Selected badge, browsing and shared picture ownership remain.

G5K02: the plain dark suit came from the picture renderer's generic fallback for custom shader materials. Header/carousel captures now derive an unshaded garment shader from the actual live Kart cloth source, retaining its entire native pigment, panels, seams, zipper, weave and relief calculation. Only its lighting is adapted to the existing fixed picture lighting. This introduces one cached picture-shader resource and no extra light/world or per-frame widget render. It changes neither the live cloth shader nor driver geometry or steering.

Both the stock Kart picture and customised captures use this path. The stock shared 512 x 288 Kart PNG was actually rebuilt and its native import checked. A Kart-only picture-version suffix rejects the previous plain-suit memory/disk keys. Other vehicles keep their existing version in the current build identity. The offline baker now accepts `--vehicle=kart` and the direct test runner forwards that argument, so this refresh writes only the Kart image.

Changed implementation files:

- `game/ui/garage_page.gd`: responsive card width/count formula.
- `game/ui/header_icon_renderer.gd`: native garment adaptation for cached pictures.
- `game/ui/header_car_icons.gd`: Kart-only private picture-key revision.
- `game/tests/bake_header_car_thumbnails.gd`, `scripts/run_shared_car_pictures.py`: targeted native bake option.
- `game/assets/menu/header_cars_v1/kart.png`: refreshed shared stock picture.
- `game/tests/test_garage_five_kart_picture.gd`: actual-App visible-count, live/preview garment, old-key rejection and custom-capture controls.

Validation actually run:

| Check | Result |
|---|---|
| Actual App and garment capture, Compatibility | 122 checks, zero failures |
| Actual App and garment capture, desktop Mobile | 122 checks, zero failures |
| Existing native driver material/steering/resource controls, headless | 64 checks, zero failures |
| Existing Garage selection feedback, headless | 20 checks, zero failures |
| Production parser | 580 scripts, zero failures |
| Targeted stock bake and native import | One Kart image, native source MD5 verified; project settings unchanged |

Native App checks count five/four wholly visible cards, verify title/Selected-badge containment and retain the actual 3D area. The customised capture inspects both native suit surfaces and verifies that their complete production fragment body before ALBEDO is retained verbatim. It rejects an injected old picture key, captures once and reuses the resulting texture. Stock and custom views use the same cloth path. No assertion was removed or relaxed. The Compatibility App run retains the known two-object/one-resource shutdown diagnostic; the desktop Mobile run exits cleanly.

All protected driver meshes, the driver source, native cloth shader and generic Rivalry preview source remain byte-exact. Four of five unrelated header PNG controls remain exact; `compact.png` changed concurrently and is preserved and excluded from this task. Concurrent Garage camera-retention edits are also retained: the task-only checkpoint's baseline includes them on both sides, changing only this task's slot formula. The unmodified task-start source is retained separately. No main-index staging or car/model/handling authoring was performed.

Views:

- [Five cards and matching live Kart](evidence/garage-five-kart-picture-2026-11-15/gl_compatibility-five-kart/kart-live-and-shared-picture.png).
- [Compact four-card view](evidence/garage-five-kart-picture-2026-11-15/gl_compatibility-five-kart/stock-960.png).
- [Former plain suit](evidence/garage-five-kart-picture-2026-11-15/before/game/assets/menu/header_cars_v1/kart.png), [rebuilt stock picture](../game/assets/menu/header_cars_v1/kart.png), [customised picture](evidence/garage-five-kart-picture-2026-11-15/mobile-five-kart/kart-custom-picture.png).

Actual test commands:

```powershell
python scripts/run_shared_car_pictures.py gl_compatibility-five-kart-bake res://tests/bake_header_car_thumbnails.gd --direct --vehicle=kart
python scripts/run_shared_car_pictures.py gl_compatibility-five-kart res://tests/test_garage_five_kart_picture.gd --direct
python scripts/run_shared_car_pictures.py mobile-five-kart res://tests/test_garage_five_kart_picture.gd --direct
python scripts/run_shared_car_pictures.py headless-five-kart-material res://tests/test_kart_material_finish.gd --direct
python scripts/run_shared_car_pictures.py headless-five-kart-selection res://tests/test_garage_selection_feedback.gd --direct
python scripts/run_shared_car_pictures.py headless-five-kart-parse res://tests/check_model_refinement_parse.gd --direct
```

The verified pinned Godot 4.7.2 binary uses isolated APPDATA/LOCALAPPDATA and disabled backend settings, without rewriting the shared generated build identity. Native import command, full logs, protected input controls, bake hashes and checkpoint receipts are in [the report](evidence/garage-five-kart-picture-2026-11-15/report.json). Standard build retention uses the shared cleanup lock, with no task pin.

Reload the game to review the shared picture and five-card layout. Owner appearance and physical-device acceptance remain. No device attachment query/test, export, backend/deployment action, owner-save modification or owner-process restart was performed. No FPS, load-time or phone performance claim is made.
