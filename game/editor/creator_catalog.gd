class_name CreatorCatalog
extends RefCounted
## One browser tile per object; shared scenery families retain their variants.
const JUMP_ASSETS: Dictionary = {
 "jump_low_ramp":"low_ramp_v1", "jump_kicker":"kicker_v1", "jump_tabletop":"tabletop_v1",
 "jump_rounded_bump":"roller_v1", "jump_sand_rise":"dune_v1"
}
const BIOME_ASSETS: Dictionary = {
 "desert":["pebbles","rock","slate","cliff","jump","jump_low_ramp","jump_kicker","jump_tabletop","jump_rounded_bump","jump_sand_rise","chevron","braking_board","flag","gantry","egypt_pyramid","egypt_obelisk","egypt_column","egypt_wall"],
 "winter":["tree","pebbles","rock","slate","cliff","log","tyre_stack","barrier","guardrail","fence","cone","chevron","braking_board","flag","light","gantry","shed","hut","igloo","snow_castle","snowman","snow_lantern","ice_lantern","ice_compact"]
}
const OBJECT_BIOMES: Dictionary = {"abandoned_warehouse":["night_city"],"burning_car":["night_city"],"firefly_bush":["night_city"],"burning_barrel":["night_city"],"lantern_post":["night_city"],"neon_arrow":["night_city"],"speed_bump":["pine","storm","night_city"],"egypt_pyramid":["desert"],"egypt_obelisk":["desert"],"egypt_column":["desert"],"egypt_wall":["desert"],"igloo":["winter"],"snowman":["winter"],"snow_castle":["winter"],"snow_lantern":["winter"],"ice_lantern":["winter"],"ice_compact":["winter"]}
# Curated biome kits further restrict the shared equipment and nature families.
const NATURE_BIOMES: Dictionary = {
 "tree":["pine","winter","storm"], "broadleaf":["pine","night_city","storm"], "bush":["pine","night_city","storm"],
 "grass_clump":["pine","night_city","storm"], "flowers":["pine","night_city","storm"], "log":["pine","winter","storm"]
}
const CATEGORIES: Array[String] = ["Nature","Barriers","Trackside","Props","Buildings"]
const ASSETS: Array = [
 ["tree","Pine tree","Nature",["tree"]],
 ["broadleaf","Broadleaf","Nature",["broadleaf"]],
 ["bush","Bush","Nature",["bush"]],
 ["firefly_bush","Firefly bush","Nature",["firefly_bush"]],
 ["burning_barrel","Burning barrel","Props",["burning_barrel"]],
 ["burning_car","Burning car","Props",["burning_car"]],
 ["lantern_post","Lantern post","Trackside",["lantern_post"]],
 ["neon_arrow","Neon arrow","Trackside",["neon_arrow"]],
 ["grass_clump","Grass clump","Nature",["grass_clump"]],
 ["flowers","Flowers","Nature",["flowers"]],
 ["pebbles","Pebbles","Nature",["pebbles"]],
 ["rock","Rock","Nature",["rock","boulder"]],
 ["slate","Outcrop","Nature",["slate"]],
 ["cliff","Cliff","Nature",["cliff"]],
 ["log","Fallen log","Nature",["log"]],
 ["tyre_stack","Tyres","Barriers",["tyre_stack","tyre_wall"]],
 ["barrier","Concrete","Barriers",["barrier"]],
 ["guardrail","Guardrail","Barriers",["guardrail"]],
 ["fence","Wood fence","Barriers",["fence"]],
 ["wire_fence","Wire fence","Barriers",["wire_fence"]],
 ["cone","Cone","Barriers",["cone"]],
 ["chevron","Chevron","Trackside",["chevron"]],
 ["braking_board","Brake board","Trackside",["braking_board"]],
 ["banner","Banner board","Trackside",["banner"]],
 ["flag","Flag","Trackside",["flag"]],
 ["light","Light pole","Trackside",["light"]],
 ["gantry","Start gantry","Trackside",["gantry"]],
 ["jump_low_ramp","Low ramp","Props",["jump"]],
 ["jump_kicker","Short kicker","Props",["jump"]],
 ["jump_tabletop","Tabletop","Props",["jump"]],
 ["jump_rounded_bump","Rounded bump","Props",["jump"]],
 ["jump_sand_rise","Sand rise","Props",["jump"]],
 ["speed_bump","Speed bump","Props",["speed_bump"]],
 ["oil","Oil spill","Props",["oil"]],
 ["hay_bale","Hay bale","Props",["hay_bale"]],
 ["crate","Wooden crate","Props",["crate"]],
 ["barrel","Barrel","Props",["barrel"]],
 ["pallet","Pallet","Props",["pallet"]],
 ["parked_car","Parked vehicle","Props",["parked_car","van"]],
 ["car_wreck","Car wreck","Props",["car_wreck"]],
 ["container","Container","Props",["container"]],
 ["shed","Garage","Buildings",["shed"]],
 ["abandoned_warehouse","Warehouse","Buildings",["abandoned_warehouse"]],
 ["hut","Marshal hut","Buildings",["hut"]],
 ["grandstand","Grandstand","Buildings",["grandstand"]],
 ["egypt_pyramid","Pyramid","Buildings",["egypt_pyramid"]],
 ["egypt_obelisk","Obelisk","Buildings",["egypt_obelisk"]],
 ["egypt_column","Lotus column","Buildings",["egypt_column","egypt_column_broken"]],
 ["egypt_wall","Temple wall","Buildings",["egypt_wall"]],
 ["igloo","Igloo","Buildings",["igloo"]],
 ["snow_castle","Snow castle","Buildings",["snow_castle"]],
 ["snowman","Snowman","Props",["snowman"]],
 ["snow_lantern","Snow lantern","Props",["snow_lantern"]],
 ["ice_lantern","Ice lantern","Props",["ice_lantern"]],
 ["ice_compact","Ice Compact","Props",["ice_compact"]]
]
const DECORATIVE: Array[String] = ["bush","grass_clump","flowers","pebbles","flag","pallet","firefly_bush"]
const SOFT: Array[String] = ["cone","chevron","braking_board","crate","barrel","hay_bale","snowman","snow_lantern","ice_lantern","burning_barrel"]
const LINES: Array[String] = ["tyre_stack","tyre_wall","barrier","guardrail","fence","wire_fence","cone"]

static func family(kind: String) -> Array:
	# Saved/canonical jump objects keep their original family and surface role.
	# The palette exposes each authored profile separately, using the IDs above.
	if kind == "jump": return ["jump","Jumps & bumps","Props",["jump"]]
	for asset: Array in ASSETS:
		if kind == asset[0] or kind in asset[3]: return asset
	return []

static func label(kind: String) -> String:
	if JUMP_ASSETS.has(kind): return JumpProfiles.label(str(JUMP_ASSETS[kind]))
	return {"ice_compact":"Ice Compact","egypt_pyramid":"Pyramid","egypt_obelisk":"Obelisk","egypt_column":"Lotus column","egypt_column_broken":"Broken column","egypt_wall":"Temple wall","oil":"Oil spill","tree":"Pine tree","tyre_stack":"One stack","tyre_wall":"Six stacks","boulder":"Boulder","slate":"Low ridge","cliff":"Cliff","parked_car":"Utility car","van":"Van"}.get(kind,kind.replace("_"," ").capitalize())

static func behavior(kind: String) -> String:
	if JUMP_ASSETS.has(kind): return JumpProfiles.description(str(JUMP_ASSETS[kind]))
	if kind=="burning_barrel": return "Movable / tips and rolls on impact"
	if kind == "abandoned_warehouse": return "Drive through the open ends / solid side walls"
	if kind == "snowman": return "Breaks into soft snow chunks and powder"
	if kind == "snow_lantern": return "Crumbles into snow; the candle goes out"
	if kind == "ice_lantern": return "Shatters into ice; the candle goes out"
	if kind == "hay_bale": return "Sheds harmless hay; becomes smaller and lighter"
	if kind == "crate": return "Movable; heavy impacts break it into loose wood"
	if kind == "speed_bump": return "Brake before it; accelerate as the nose rises"
	if kind == "oil": return "Oil spill / slippery; coats tyres and reduces grip"
	if kind == "jump": return "Original ramp / launches in its facing direction"
	if kind in DECORATIVE: return "Decorative / no collision"
	if kind in SOFT: return "Light / moves on impact; small speed loss"
	if kind in ["tree","broadleaf"]: return "Solid / trunk collision"
	if kind in ["tyre_stack","tyre_wall"]: return "Movable / absorbs impact; piles resist pushing"
	if kind == "gantry": return "Solid supports / clear passage underneath"
	return "Solid / blocks the car"

static func available(kind: String, biome: String) -> bool:
	var asset: Array = family(kind)
	if asset.is_empty(): return false
	if biome not in TrackDocument.THEMES: return true
	var id: String = asset[0]
	return (not OBJECT_BIOMES.has(id) or biome in OBJECT_BIOMES[id]) and (not NATURE_BIOMES.has(id) or biome in NATURE_BIOMES[id]) and (not BIOME_ASSETS.has(biome) or id in BIOME_ASSETS[biome])

static func filtered(category: String, query: String, recent: Array[String], biome: String = "", availability: Dictionary = BIOME_ASSETS) -> Array:
	var result: Array = []
	for asset: Array in ASSETS:
		if not available(asset[0],biome): continue
		if availability.has(biome) and asset[0] not in availability[biome]: continue
		if category == "Recent" and asset[0] not in recent: continue
		if category not in ["All","Recent"] and asset[2] != category: continue
		if not query.strip_edges().is_empty() and not (str(asset[1])+" "+str(asset[3])).to_lower().contains(query.strip_edges().to_lower()): continue
		result.append(asset)
	return result

static func default_scale(kind: String) -> float:
	return 2.0 if kind == "cliff" else 1.0

static func size_presets(kind: String) -> Array[float]:
	var result: Array[float] = []
	result.assign([1.0,2.0,3.0] if kind == "cliff" else [0.75,1.0,1.5])
	return result

static func jump_asset(profile: String, biome: String = "pine") -> String:
	var selected: String = profile if profile in JumpProfiles.IDS else JumpProfiles.default_for(biome)
	return str(JUMP_ASSETS.find_key(selected))
