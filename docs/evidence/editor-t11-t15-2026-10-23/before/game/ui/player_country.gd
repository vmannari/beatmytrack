class_name PlayerCountry
extends RefCounted
## Offline profile metadata and bundled flag artwork; never simulation input.
const CATALOG: String = "res://assets/countries/countries.json"
static var _countries: Array[Dictionary] = []
static var _names: Dictionary = {}
static var _textures: Dictionary = {}

static func countries() -> Array[Dictionary]:
	if _countries.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
		if value is Array:
			for row: Dictionary in value:
				_countries.append(row)
				_names[str(row.code)] = str(row.name)
	return _countries

static func valid_code(value: String) -> String:
	countries()
	if value.length() != 2: return ""
	for index: int in range(2):
		var character: int = value.unicode_at(index)
		if not (character >= 65 and character <= 90) and not (character >= 97 and character <= 122): return ""
	var code: String = value.to_upper()
	return code if _names.has(code) else ""

static func country_name(value: String) -> String:
	var code: String = valid_code(value)
	return str(_names.get(code,"Country not selected"))

static func texture(value: String) -> Texture2D:
	var code: String = valid_code(value)
	if not _textures.has(code):
		_textures[code] = load("res://assets/countries/"+(code.to_lower() if not code.is_empty() else "unset")+".svg")
	return _textures[code] as Texture2D

static func flag(value: String, width: int = 28) -> TextureRect:
	var code: String = valid_code(value)
	var view := TextureRect.new()
	view.name = "PlayerCountryFlag"
	view.set_meta("country_code",code)
	view.texture = texture(code)
	view.tooltip_text = country_name(code)
	view.custom_minimum_size = Vector2(width,width*0.75)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	view.mouse_filter = Control.MOUSE_FILTER_PASS
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return view
