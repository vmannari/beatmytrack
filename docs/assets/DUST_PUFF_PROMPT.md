# Dust puff asset provenance

- Asset: `game/assets/textures/dust_puff_v1.png`
- Created: 2026-09-20 with the built-in OpenAI image-generation tool.
- Purpose: original tire-dust particle sprite for the local game build.
- Owner rally photograph: visual behavior reference only; it was not edited, copied or shipped.

Final generation prompt:

> Use case: stylized-concept. Asset type: single game VFX particle sprite with alpha transparency. One isolated irregular rally dust puff, a compact cauliflower-like billow just thrown from a tire, with several overlapping rounded lobes, a denser lower core, feathered wispy edges, and soft volumetric internal shading. It must read clearly from a high-oblique overhead gameplay camera at small size. Fully transparent RGBA background. Polished hand-painted cel-shaded game VFX, natural soft dust, restrained detail, no outline. Pale warm desert sand and cream highlights with subtle ochre depth; light overall and suitable for engine tinting. Exactly one puff centered in a square canvas, roughly round/asymmetrical rather than a sideways trail, generous transparent padding. Soft daylight from upper left. Clean transparent edge; no vehicle, terrain, debris, rocks, text, grid, border, surface shadow, watermark or additional objects. Avoid sprite sheets, multiple clouds, chromatic fringe, hard rectangles, perfect circles, flat blurred discs, dark smoke, fire and photographic backgrounds.

The runtime shader uses the generated alpha silhouette and luminance only, applying the approved sand tint in-engine. This suppresses stray colour in transparent-edge RGB while retaining the authored billow structure.
