class_name ContainerPaint
extends RefCounted
## Bounded colour data only; no UGC images/materials or simulation changes.
const DEFAULT: String = "#426878"
const SWATCHES: Array[String] = ["#426878","#8b4134","#58705b","#bd994d","#b6b6a4","#42484e"]

static func valid(value: Variant) -> bool:
	if not value is String or value.length() != 7 or not value.begins_with("#"): return false
	for i: int in range(1,7):
		if value.substr(i,1) not in "0123456789abcdefABCDEF": return false
	return true

static func value(object: Dictionary) -> String:
	return str(object.color).to_lower() if valid(object.get("color")) else DEFAULT

static func encode(color: Color) -> String:
	return "#"+Color(clampf(color.r,0,1),clampf(color.g,0,1),clampf(color.b,0,1),1).to_html(false)
