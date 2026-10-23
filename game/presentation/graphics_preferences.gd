extends RefCounted
## Local race presentation only. Auto retains the existing platform policy.

const DEFAULTS: Dictionary = {
	"shadow_quality":"auto", "render_resolution":"auto", "anti_aliasing":"auto",
}
const OPTIONS: Dictionary = {
	"shadow_quality":["auto","off","low","medium","high"],
	"render_resolution":["auto","50","67","75","100"],
	"anti_aliasing":["auto","off","fxaa","msaa_2x","msaa_4x"],
}
const LABELS: Dictionary = {
	"shadow_quality":["Auto","Off","Low","Medium","High"],
	"render_resolution":["Auto","50%","67%","75%","100%"],
	"anti_aliasing":["Auto","Off","FXAA","MSAA 2x","MSAA 4x"],
}

static func valid(field: String, value: Variant) -> bool:
	return value is String and value in OPTIONS.get(field,[])

static func preferences(settings: Dictionary) -> Dictionary:
	var result: Dictionary = DEFAULTS.duplicate()
	for field: String in DEFAULTS:
		if valid(field,settings.get(field)): result[field] = settings[field]
	return result

static func resolution(choice: String, automatic: float) -> float:
	return automatic if choice == "auto" else float(choice)/100.0

static func antialiasing(choice: String, automatic: Viewport.MSAA, safe_depth: bool) -> Dictionary:
	if safe_depth:
		return {"msaa":Viewport.MSAA_DISABLED,"fxaa":choice != "off"}
	match choice:
		"off": return {"msaa":Viewport.MSAA_DISABLED,"fxaa":false}
		"fxaa": return {"msaa":Viewport.MSAA_DISABLED,"fxaa":true}
		"msaa_2x": return {"msaa":Viewport.MSAA_2X,"fxaa":false}
		"msaa_4x": return {"msaa":Viewport.MSAA_4X,"fxaa":false}
	return {"msaa":automatic,"fxaa":false}

static func shadow_size(choice: String) -> int:
	return int({"low":512,"medium":1024,"high":2048}.get(choice,0))
