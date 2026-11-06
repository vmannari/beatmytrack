extends RefCounted
const FIELDS: Array[String] = ["schema_version","context","biome","renderer","car","simple","graphics","status","observed","missing","dropped","late_compile_us","misses"]
const PHASES: Array[String] = ["loading","countdown","driving","results"]
static func integer(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == int(value) and value >= 0 and value <= maximum

static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != FIELDS.size() or not value.has_all(FIELDS): return {}
	var hex := RegEx.create_from_string("^[a-f0-9]{64}$")
	var mask := RegEx.create_from_string("^[a-f0-9]{16}$")
	if not value.context is String or hex.search(value.context) == null or not integer(value.schema_version,1) or value.schema_version != 1: return {}
	if value.biome not in ["pine","winter","desert","storm","night_city","unknown"] or value.renderer != "gl_compatibility" or value.status not in ["matched","unprofiled"]: return {}
	if value.car not in VehicleCatalog.IDS+["unknown"] or not value.simple is bool: return {}
	if not value.graphics is Dictionary or value.graphics.size() != 3: return {}
	for field: String in ["shadow_quality","render_resolution","anti_aliasing"]:
		if not preload("res://presentation/graphics_preferences.gd").valid(field,value.graphics.get(field)): return {}
	for field: String in ["observed","missing","dropped","late_compile_us"]:
		if not integer(value[field],3600000000 if field == "late_compile_us" else 1000000 if field == "dropped" else 4096): return {}
	if value.missing > value.observed or not value.misses is Array or value.misses.size() > mini(16,int(value.missing)): return {}
	var seen: Dictionary = {}
	for row: Variant in value.misses:
		if not row is Dictionary or row.size() != 8 or not row.has_all(["key","shader","variant","specialization","reason","phase","compile_phase","compile_us"]): return {}
		if not row.key is String or hex.search(row.key) == null or seen.has(row.key): return {}
		if not row.shader is String or hex.search(row.shader) == null or not integer(row.variant,255): return {}
		if not row.specialization is String or mask.search(row.specialization) == null: return {}
		if row.reason not in ["unlisted","late_compile"]: return {}
		if row.phase not in PHASES or row.compile_phase not in PHASES+["cached","outside"] or not integer(row.compile_us,60000000): return {}
		seen[row.key] = true
	var result: Dictionary = value.duplicate(true)
	for field: String in ["schema_version","observed","missing","dropped","late_compile_us"]: result[field] = int(result[field])
	for row: Dictionary in result.misses:
		row.variant = int(row.variant)
		row.compile_us = int(row.compile_us)
	return result
