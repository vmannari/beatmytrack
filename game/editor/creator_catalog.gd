class_name CreatorCatalog
extends RefCounted
## One browser tile per asset family; variants are chosen after selection.
const BIOME_ASSETS: Dictionary = {}
const OBJECT_BIOMES: Dictionary = {"speed_bump":["pine","storm","night_city"]}
# Only nature families are restricted; equipment is shared across all biomes.
const NATURE_BIOMES: Dictionary = {
 "tree":["pine","winter","storm"], "broadleaf":["pine","night_city","storm"], "bush":["pine","night_city","storm"],
 "grass_clump":["pine","night_city","storm"], "flowers":["pine","night_city","storm"], "log":["pine","winter","storm"]
}
const CATEGORIES: Array[String] = ["Nature","Barriers","Trackside","Props","Buildings"]
const ASSETS: Array = [
 ["tree","Pine tree","Nature",["tree"]],
 ["broadleaf","Broadleaf","Nature",["broadleaf"]],
 ["bush","Bush","Nature",["bush"]],
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
 ["jump","Jump","Props",["jump"]],
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
 ["hut","Marshal hut","Buildings",["hut"]],
 ["grandstand","Grandstand","Buildings",["grandstand"]]
]
const DECORATIVE: Array[String] = ["bush","grass_clump","flowers","pebbles","flag","pallet"]
const SOFT: Array[String] = ["cone","chevron","braking_board","crate","barrel","hay_bale"]
const LINES: Array[String] = ["tyre_stack","tyre_wall","barrier","guardrail","fence","wire_fence","cone"]

static func family(kind: String) -> Array:
	for asset: Array in ASSETS:
		if kind in asset[3]: return asset
	return []

static func label(kind: String) -> String:
	return {"oil":"Oil spill","tree":"Pine tree","tyre_stack":"One stack","tyre_wall":"Six stacks","boulder":"Boulder","slate":"Low ridge","cliff":"Cliff","parked_car":"Utility car","van":"Van"}.get(kind,kind.replace("_"," ").capitalize())

static func behavior(kind: String) -> String:
	if kind == "hay_bale": return "Sheds harmless hay; becomes smaller and lighter"
	if kind == "crate": return "Movable; heavy impacts break it into loose wood"
	if kind == "speed_bump": return "Brake before it; accelerate as the nose rises"
	if kind == "oil": return "Oil spill / slippery; coats tyres and reduces grip"
	if kind == "jump": return "Ramp / launches the car in its facing direction"
	if kind in DECORATIVE: return "Decorative / no collision"
	if kind in SOFT: return "Light / moves on impact; small speed loss"
	if kind in ["tree","broadleaf"]: return "Solid / trunk collision"
	if kind in ["tyre_stack","tyre_wall"]: return "Movable / absorbs impact; piles resist pushing"
	if kind == "gantry": return "Solid supports / clear passage underneath"
	return "Solid / blocks the car"

static func filtered(category: String, query: String, recent: Array[String], biome: String = "", availability: Dictionary = BIOME_ASSETS) -> Array:
	var result: Array = []
	for asset: Array in ASSETS:
		if biome in TrackDocument.THEMES and OBJECT_BIOMES.has(asset[0]) and biome not in OBJECT_BIOMES[asset[0]]: continue
		if biome in TrackDocument.THEMES and NATURE_BIOMES.has(asset[0]) and biome not in NATURE_BIOMES[asset[0]]: continue
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
