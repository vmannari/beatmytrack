class_name PlayerCountry
extends RefCounted
## Offline profile metadata and bundled flag artwork; never simulation input.
const CATALOG: String = "res://assets/countries/countries.json"
static var _countries: Array[Dictionary] = []
static var _names: Dictionary = {}
static var _textures: Dictionary = {}
static var _localized: Dictionary = {}
static var _localized_loaded: bool = false

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
	if code.is_empty(): return GameText.message("Country not selected")
	var locale: String = TranslationServer.get_locale()
	if locale.begins_with("en"): return str(_names[code])
	if not _localized_loaded:
		_localized_loaded = true
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://localization/country_names.json"))
		if data is Dictionary and data.get("languages") is Dictionary: _localized = data.languages
	var base: String = locale.get_slice("_",0)
	if base == "no": base = "nb"
	var raw_labels: Variant = _localized.get(locale,_localized.get(base,{}))
	var labels: Dictionary = raw_labels if raw_labels is Dictionary else {}
	return str(labels.get(code,_names[code]))

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
	view.mouse_entered.connect(_refresh_flag_tooltip.bind(weakref(view)))
	return view

static func _refresh_flag_tooltip(reference: WeakRef) -> void:
	var view: TextureRect = reference.get_ref() as TextureRect
	if is_instance_valid(view): view.tooltip_text = country_name(str(view.get_meta("country_code","")))
