extends RefCounted
## Display names and pigments for the existing, unchanged surface IDs.
static func title(surface: int, biome: String) -> String:
	if biome == "winter": return ["Ice","Snow","Packed snow","Water","Barrier","Kerb","Slush","Low obstacles"][clampi(surface,0,7)]
	if biome == "desert" and surface in [1,2]: return "Sand" if surface == 1 else "Loose sand"
	if biome == "night_city" and surface in [1,2]: return "Ground" if surface == 1 else "Gravel"
	return ["Road","Grass","Sand","Water","Barrier","Kerb","Rough ground","Low obstacles"][clampi(surface,0,7)]

static func glyph(surface: int, biome: String) -> String:
	if biome == "winter" and surface in [1,2]: return "terrain_snow"
	return "terrain_grass" if surface == 1 and biome not in ["desert","night_city"] else "terrain_dirt" if surface in [1,2] else "terrain_water" if surface == 3 else "terrain_road"
