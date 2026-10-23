# Achievement medal artwork

Original project SVG artwork, authored in `scripts/build_achievement_art.py`.
No third-party artwork, image service or runtime generation is used.

Run `python scripts/build_achievement_art.py` to rebuild `medals.svg`. Output is
deterministic. The catalog's forty family IDs must match the forty authored
emblems. The atlas contains 200 cells of 128 × 128 pixels in a 1280 × 2560 image:

- Column: family index modulo 10.
- Row: floor(family index / 10) × 5 + earned tier, from locked (0) to platinum (4).
- Prestige families use their gold honor seal for the earned state.

The UI crops this shared atlas with `AtlasTexture`. The physical wall uses the
same cells in one instanced face draw per collection/featured group, with
separate instanced minted edges for earned medals. Missing wall medals use the
locked artwork at 0.48 linear brightness. Four levels of inset diamonds identify
the regular tiers; the ten prestige seals have a pointed rim and laurel relief.

Mipmaps are enabled for stable display at the wall's smaller size. The fixed
RGBA8 texture plus full mip chain has a theoretical 16.7 MiB memory footprint;
this is an asset bound, not a device performance measurement. The actual native
Compatibility and Mobile captures are recorded in
`docs/ACHIEVEMENT_WALL_2026_10_17.md` outside the export root.
