# Artistic livery collection - 2026-11-15

AL01-AL04 address the owner's rejection of the first collection as too close to plain paint. The current review collection is replaced by **18 full-colour illustrated artworks**, with three compositions for every current car. [Open the new native gallery](evidence/artistic-liveries-2026-11-15/collection.html) or [view the complete collection](evidence/artistic-liveries-2026-11-15/collection.png). Each card has five native angles, matched Stock paint and original Artwork views.

| Car | Artistic designs |
| --- | --- |
| Rally | Spirit of Pines / Solstice Stag / Wildflower Atlas |
| Kart | Kaiju Club / Comet Carnival / Rocket Koi |
| Forklift | Iron Garden / Golden Leviathan / Factory of Dreams |
| Volt | Liquid Ukiyo / Porcelain Moon / Prismatic Muse |
| Hover | Abyssal Oracle / Coral Cathedral / Celestial Manta |
| Super Rally | Jade Oni / Phoenix Atelier / Nocturne Panther |

The collection uses woodland woodcut/botanical storytelling for Rally, expressive comic and carnival imagery for Kart, surreal industrial murals for Forklift, porcelain/ink/stained-glass art for Volt, ocean mythology for Hover, and dramatic tattoo illustration for Super Rally. Each atlas was individually generated using the **built-in image_gen tool**, following [18 exact prompts](evidence/artistic-liveries-2026-11-15/generation-prompts.json) and [the creative briefs](../scripts/artistic_livery_briefs.json). All 18 PNGs in `game/assets/liveries/artistic_v2/` are unchanged copies of their generated originals; their paths, original output locations and exact hashes are in the provenance/receipt files. There were no reference photos, generated car mockups, external sponsor marks or raster retouching steps.

The new work uses a colour-correct full-RGB sampler; three-pigment mask recolouring is retained for the first collection. Physical chart scales keep the artwork from stretching, bonnet portraits face the nose, roofs use supporting motifs, and Kart's narrow nose and separate pods have dedicated charts. A soft edge blends out-of-panel artwork into a quiet ground colour rather than stretching the last texture row across the body. Source-generated art remains intact. Painting only replaces existing paint surfaces, beneath weathering, with original glazing, tyres, trim and geometry retained. Gold, porcelain and glass are illustration styles; the underlying car paint finish is unchanged. Full-colour designs have fixed palettes; the older mask liveries retain their original colour roles.

Final headless checks: **329/0**. Native Compatibility: **455/0**. Desktop Mobile: **455/0**. Production parser: **580/0**. There are 90 art views and six stock controls per renderer, **192 native images** overall. Controls cover distinct colour-rich imagery, per-car restrictions, exact meshes/transforms, original ordinary shader source/program/pixels, first-collection interpretation, live dirt, washing, factory restoration, mipmaps, the four-mask cache and four shader families. Gallery destinations and JavaScript syntax were checked. Prototype renders found edge stretching and incorrect portrait orientation; those were fixed in the chart mapping before final collection capture.

Actual commands:

```powershell
python scripts/import_artistic_liveries.py
python scripts/run_artistic_review.py headless
python scripts/run_artistic_review.py gl_compatibility
python scripts/run_artistic_review.py mobile
python scripts/run_artistic_review.py parse
# Presentation uses the available Pillow authoring runtime.
python scripts/present_artistic_liveries.py
python scripts/finalize_artistic_liveries.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1 -Apply
```

Art import uses a small native art-only project, with lossless 1536x1024 mipmapped outputs. No owner editor/library is changed. Review runs have isolated application-data directories and use current authored models; they do not republish unrelated prepared geometry. The first collection is preserved in `premium_v1/`, with its 18 IDs valid; the released 48 coin wraps and standard Garage menu remain intact. This collection remains a review surface, with no prices, SKUs, purchases, grants, backend allowlist update or deployment.

Changed runtime files are `livery_catalog.gd`, `livery_graphics.gd` and the premium-only shader include. New source assets are the 18 full-colour PNG atlases and import settings, catalogue/provenance/notice, creative briefs and exact prompts, native review, import/runner/presentation/checkpoint scripts, and this report. The original ordinary livery shader/include remain byte-exact. The [machine-readable receipt](evidence/artistic-liveries-2026-11-15/report.json) enumerates every art/source/native-view hash. `task-source.patch` is a forward/reverse-verified **text-source** checkpoint; PNG originals are delivered directly in the asset directory and fenced by hash rather than duplicated into the patch. The shared Git index is unchanged, and concurrent work is preserved.

Owner appearance acceptance, physical-device testing and fitted-kit/gameplay-distance review remain before paid release. There is no phone, FPS, whole-project, export, current prepared-cache or paid-store readiness claim. No owner save/process change, real purchase, live account mutation or deployment was performed. Standard build retention ran without a task pin; shared recent/protected output can remain above the 20 GiB target.
