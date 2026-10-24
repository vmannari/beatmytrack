extends RefCounted
## Presentation policy only. Race rules and valuable benefits remain server owned.
const DEFAULTS: Dictionary = {
	"ads.permitted":false,"ads.interstitial_enabled":false,"ads.trigger":"either",
	"ads.races":3,"ads.active_seconds":600,"ads.first_delay_seconds":0,
	"ads.min_races":0,"ads.min_seconds":0,"ads.rewarded_cooldown_seconds":0,
	"ads.session_cap":null,"ads.rewarded_resume_enabled":true,
	"features.challenge_creation":true,"features.rivalry_entry":true,
	"notice.message":"","notice.expires_at":0,
	"store_order":["ad_free_forever","ad_free_month","creator_slot_1","creator_slots_5","creator_slots_10"]}
const RANGES: Dictionary = {"ads.races":[1,100],"ads.active_seconds":[60,7200],
	"ads.first_delay_seconds":[0,7200],"ads.min_races":[0,100],"ads.min_seconds":[0,7200],
	"ads.rewarded_cooldown_seconds":[0,7200],"ads.session_cap":[1,100],"notice.expires_at":[0,4102444800]}

static func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == int(value) and value >= low and value <= high

static func valid(settings: Variant) -> bool:
	if not settings is Dictionary or settings.size() != DEFAULTS.size(): return false
	for key: String in DEFAULTS:
		if not settings.has(key): return false
		var value: Variant = settings[key]
		if key == "ads.session_cap" and value == null: continue
		if RANGES.has(key):
			if not whole(value,RANGES[key][0],RANGES[key][1]): return false
		elif key == "ads.trigger":
			if value not in ["either","both"]: return false
		elif key == "notice.message":
			if not value is String or value.length() > 256: return false
		elif key == "store_order":
			if not value is Array or value.size() != DEFAULTS.store_order.size(): return false
			var seen: Dictionary = {}
			for product: Variant in value:
				if not product is String or product not in DEFAULTS.store_order or seen.has(product): return false
				seen[product] = true
		elif not value is bool: return false
	return true

static func snapshot_valid(value: Variant, scope: String) -> bool:
	if not value is Dictionary or not whole(value.get("schema_version",0),1,1): return false
	if not whole(value.get("generation",-1),0,2147483647) or not whole(value.get("control_revision",-1),0,2147483647): return false
	if value.get("scope","") != scope or not valid(value.get("settings")): return false
	if not whole(value.get("server_now",0),1,4102444800) or not whole(value.get("expires_at",0),1,4103049600): return false
	if value.expires_at < value.server_now or value.expires_at > value.server_now+604800: return false
	if not value.get("assignments") is Array or value.assignments.size() > 2: return false
	var uuid: RegEx = RegEx.create_from_string("^[a-f0-9-]{36}$")
	var variant: RegEx = RegEx.create_from_string("^[a-z][a-z0-9_-]{0,23}$")
	for item: Variant in value.assignments:
		if not item is Dictionary or not item.get("experiment_id") is String or uuid.search(item.experiment_id) == null: return false
		if not item.get("variant") is String or variant.search(item.variant) == null or not whole(item.get("revision",-1),0,2147483647): return false
		if item.get("layer","") not in ["ads","presentation"]: return false
	return value.get("resolution_id") is String and RegEx.create_from_string("^[a-f0-9]{64}$").search(value.resolution_id) != null
