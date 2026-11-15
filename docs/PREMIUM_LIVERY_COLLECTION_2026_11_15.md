# Premium livery Collection 01 — 2026-11-15

PL01–PL04 deliver 18 original designs, three for every current car. [Open the interactive native-render gallery](evidence/premium-liveries-2026-11-15/collection.html) or [view the collection sheet](evidence/premium-liveries-2026-11-15/collection.png).

| Car | Designs |
| --- | --- |
| Rally | Monte Rosso 73 / Nordic Works 09 / Mistral Tour 26 |
| Kart | Officina Corsa 21 / Apex Division 08 / Pocket Royale 88 |
| Forklift | Foundry No.04 / Signal / 12 / Night Shift 06 |
| Volt | Ion Atelier / Polar Vector / Orchid Circuit |
| Hover | Pelagic 07 / Abyssal Survey / Solaris Regatta |
| Super Rally | Obsidian Coachworks / Crimson Dominion / Silver Spectre |

Each identity has individually composed top, left, right, front and rear artwork. Opposite-side shapes mirror while the lettering stays readable; bonnet lettering faces the nose. Original insignia, race numbers, route/contour linework and industrial graphics are outlined vector paths. Barlow Condensed SemiBold comes from the repository's OFL font assets. The masks use the original three editable paint roles. They are individually authored compositions, with no raster generations, outside logos or downloaded reference artwork.

This is an art review collection. It is deliberately separate from the 48 released coin wraps and their unchanged menu and backend allowlist. There are no premium prices, product IDs, purchases or grants. Future real-money release still needs the chosen products, server entitlement integration and owner approval of the designs. The current Garage menu does not list these review designs; the gallery and native review runner are their review surfaces.

The new panel shader is selected only for this collection, including live weathering. It preserves mesh frames, paint and the complete wash state across shader changes. Both original clean shader files remain byte-exact against task-start evidence and Git. Released paint binds the original GPU program. Premium masks are 1536×1024, lossless, mipmapped and held in the existing four-mask cache. Four shared clean/toon/weathering shader families are the tested bound. No meshes, model geometry or additional drawing passes are added. Finish names describe colour/material direction; existing paint materials supply the actual finish.

Final checks: headless **322/0**; native Compatibility **436/0** and desktop Mobile **442/0**, 90 views each; production parser **580/0**. The native review checks source identity, stable original-program pixel comparisons, exact mesh/transform preservation, valid per-car appearances, car restrictions, mipmaps, distinct/covered masks, dirt, washing and factory restoration. Supplementary final placement checks, when present, are recorded in the JSON report. The gallery's JavaScript passes Node's syntax check. This is a desktop art review, with no physical-device, performance, export or full prepared-cache acceptance claim.

Actual commands included:

```powershell
# Authoring Python: fontTools available via PYTHONPATH=build/premium-livery-authoring-lib
python scripts/build_premium_liveries.py
python scripts/import_premium_liveries.py
python scripts/run_premium_livery_review.py headless
python scripts/run_premium_livery_review.py gl_compatibility
python scripts/run_premium_livery_review.py mobile
python scripts/run_premium_livery_review.py parse
# Presentation uses the available Pillow authoring runtime.
python scripts/present_premium_liveries.py
python scripts/finalize_premium_liveries.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

The initial dev Import command hit a locked editor hot-reload DLL. The successful replacement uses a small art-only import project and copies only its 18 native texture outputs. No owner process or library was changed. Early nested SVG panels rasterized incorrectly, and one design's detail coverage failed; translated clipped groups and stronger detail artwork corrected these without lowering gates. A driver comparison made from separately recompiled inlined shader text retained 1-LSB differences; final controls retain the original program identity, exact sources and pixel gate. The first Mobile reference also caught cold environment settling; the final comparison explicitly requires a stable repeated reference first. The broad parser retains unrelated historic fixture signature mismatches, while the unchanged production parser passes. Relevant rejected logs and one failed-art capture remain under `rejected/`.

Changed sources are the three livery catalogue/binding/validation files, one premium shader include, the 18 SVG masks/import settings plus catalogue/notice, native review script and five authoring/import/review/presentation/checkpoint scripts. [The machine-readable receipt](evidence/premium-liveries-2026-11-15/report.json) enumerates every source and native-view hash. `task-source.patch` is a source-only private Git checkpoint verified forward and reverse; no main-index staging or commit is performed. The dev wrapper's generated build identity is excluded. Concurrent workspace work is preserved.

Standard build retention ran; recent/protected/locked output keeps the shared build above its 20 GiB target, with no task pin. Owner visual acceptance and phone rendering/input/memory acceptance remain. No owner-save mutation, real purchase, live request, backend change or deployment was performed.
