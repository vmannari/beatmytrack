# Panama custom-paint liveries - 2026-11-15

DR01-DR04 follow the owner's reference to Panama's custom-painted school buses, with the explicit constraint **no portraits**. The current premium review collection is replaced with **18 original mural liveries, three per car**. [Open the native gallery](evidence/diablo-liveries-2026-11-15/collection.html) or [see all 18](evidence/diablo-liveries-2026-11-15/collection.png). Each card includes five native angles, Stock paint and the original Artwork.

| Car | Designs |
| --- | --- |
| Rally | Ruta del Sol / Camino Bravo / Selva Brava |
| Kart | Pura Candela / Ritmo Callejero / Rayo Loco |
| Forklift | Fuerza del Puerto / Hierro Ardiente / Acero Fino |
| Volt | Ciudad Electrica / Luz de Medianoche / Aurora Tropical |
| Hover | Marea Brava / Islas del Fuego / Brisa del Caribe |
| Super Rally | Fuego Sagrado / Noche de Acero / El Trueno |

Rally carries coastal roads, mountain passes and rainforest scenery. Kart uses flames, street instruments and lightning. Forklift has port infrastructure, furnaces and polished machinery. Volt uses neon cities, moonlight and tropical sunrise. Hover shows Pacific surf, volcanic islands and Caribbean bays. Super Rally uses hot-rod fire, engines and desert storms. Saturated airbrushing, shaded nickname lettering, pinstripes, scallops and bright framed borders give the collection its bus-paint character. All 18 atlases were visually inspected for the portrait exclusion; generation prompts additionally exclude people, faces, animals, masks and skulls. This is original inspired artwork, not a claim of work by Panamanian bus painters.

Reference study used [La Estrella's report and bus-paint photographs](https://www.laestrella.com.pa/vida-y-cultura/diablos-rojos-legado-vivo-del-arte-popular-panameno-GC14252620) and [La Prensa's account of bus painting](https://www.prensa.com/vivir/el-que-no-conoce-un-diablo-rojo-no-es-panameno-29-anos-pintando-la-historia-sobre-ruedas/). Two photographs were passed to generation as **style-only** references, with explicit instructions not to reproduce their portrait/character subjects. Reference URLs and roles are recorded in provenance; the photos remain disposable authoring references under `build/diablo-style-study/` and are not included as game assets.

Each artwork was generated separately using the **built-in image_gen tool**, with [exact prompts](evidence/diablo-liveries-2026-11-15/generation-prompts.json) and [creative briefs](../scripts/diablo_livery_briefs.json). The 18 source PNGs in `game/assets/liveries/diablo_v3/` are unchanged 1536x1024 copies of generated originals. No raster painting, recolouring or retouching followed generation. The six-tile source layout carries bonnet, left, right, front, rear and ornamental ground art. Shader charts fit the source to each vehicle: readable side lettering, upright bonnet nicknames, decorative roof/fender coverage and a narrower dedicated Kart nose. Side height/width vary by car to retain the intended composition. Original paint geometry, glazing, tyres, trim and physical paint finish are retained; weathering remains above the full-RGB art. Printed chrome and candy effects belong to the illustration. These designs use fixed palettes.

Headless **372/0**, Compatibility **498/0**, desktop Mobile **498/0**, production parser **580/0**. Each desktop renderer has 90 art views and six matched stock controls: **192 native images**. Checks cover 18 distinct colour-rich textures, portrait-free metadata, three designs per car, vehicle restrictions, old IDs, exact meshes/transforms, original ordinary shader source/program/pixels, dirt, washing, factory restoration, mipmaps and four-texture/four-shader bounds. Native pilot reviews corrected the Kart bonnet crop before final captures. Gallery links and JavaScript syntax were also checked. Logs and command records remain alongside the machine-readable receipt.

```powershell
python scripts/import_diablo_liveries.py
python scripts/run_diablo_review.py headless
python scripts/run_diablo_review.py gl_compatibility
python scripts/run_diablo_review.py mobile
python scripts/run_diablo_review.py parse
# Presentation uses the available Pillow authoring runtime.
python scripts/present_diablo_liveries.py
python scripts/finalize_diablo_liveries.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Import uses a small art-only native project and lossless mipmapped PNGs, without touching the owner's editor/library. Native reviews use isolated application-data directories and current authored models. Both earlier collections, their 36 IDs and the 48 released coin wraps are retained. This replaces the active art-review catalogue; Garage availability and real-money product integration remain a release step. No prices, purchases, grants, live account changes, backend, export or deployment were performed.

Three runtime files change: `livery_catalog.gd`, `livery_graphics.gd` and the premium-only shader include. Ordinary livery shader/include files are byte-exact. New art assets, import settings, briefs, exact prompts, provenance and import/review/presentation/checkpoint scripts are included. The [receipt](evidence/diablo-liveries-2026-11-15/report.json) fences original art, task source and native frames by hash. `task-source.patch` is a forward/reverse-verified text-source checkpoint; source PNGs are delivered directly and hashed separately to avoid binary duplication. The shared index and concurrent work are preserved. Standard build retention runs without a task pin.

Owner appearance review, physical-device and fitted-kit/gameplay-distance review remain before paid release. There is no phone, FPS, whole-project or prepared-cache readiness claim. No owner save/process changes were made.
