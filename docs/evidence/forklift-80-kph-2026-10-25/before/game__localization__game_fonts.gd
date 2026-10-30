class_name GameFonts
extends RefCounted
## Bundled script coverage; original Latin typography keeps its existing faces.
const JAPANESE: FontFile = preload("res://assets/fonts/multilingual/notosansjp/NotoSansJP[wght].ttf")
const KOREAN: FontFile = preload("res://assets/fonts/multilingual/notosanskr/NotoSansKR[wght].ttf")
const GOOGLE: FontFile = preload("res://assets/fonts/multilingual/googlesans/GoogleSans[GRAD,opsz,wght].ttf")
const LATIN: Array[Font] = [preload("res://assets/fonts/Barlow-Regular.ttf"),preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf"),preload("res://assets/fonts/libre_baskerville/LibreBaskerville.ttf"),preload("res://assets/fonts/libre_baskerville/LibreBaskerville-Italic.ttf"),GOOGLE]
static var _script: String = ""
static var _variations: Dictionary = {}

static func face(base: Font, weight: int) -> FontVariation:
	var key: String = str(base.get_instance_id())+":"+str(weight)
	if not _variations.has(key):
		var result := FontVariation.new()
		result.base_font = base
		result.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):float(weight)}
		_variations[key] = result
	return _variations[key]

static func configure(locale: String) -> void:
	var script: String = "ko" if locale.begins_with("ko") else "ja"
	if _script == script: return
	_script = script
	for index: int in LATIN.size():
		var weight: int = 600 if index == 1 else 400
		var japanese: Font = face(JAPANESE,weight)
		var korean: Font = face(KOREAN,weight)
		var fallback: Array[Font] = [korean,japanese] if script == "ko" else [japanese,korean]
		LATIN[index].fallbacks = fallback

