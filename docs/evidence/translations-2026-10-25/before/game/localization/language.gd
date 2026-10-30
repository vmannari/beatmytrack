class_name GameLanguage
extends Node
## Installation-local language. No account, network or canonical simulation state.
signal changed
const Store = preload("res://backend/atomic_json.gd")
const MANIFEST: String = "res://localization/languages.json"
var preference: String = "system"
var storage_path: String = ""
var locales: Dictionary = {"en":"English"}
var last_error: Error = OK

static func instance() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Language")

func configure(path: String) -> void:
	storage_path = path
	locales = {"en":"English"}
	var manifest: Dictionary = Store.read(MANIFEST,16384)
	for code: String in manifest.get("languages",{}):
		# Only reviewed, packaged translations may be offered to players.
		if code in TranslationServer.get_loaded_locales() and manifest.languages[code] is String:
			locales[code] = manifest.languages[code]
	var saved: Dictionary = Store.read(storage_path,4096)
	preference = str(saved.get("language","system")) if saved.get("schema") == 1 else "system"
	if not valid(preference): preference = "system"
	_apply()

func valid(code: String) -> bool:
	return code == "system" or locales.has(code)

func resolve(code: String, system_locale: String = "") -> String:
	if code != "system": return code if locales.has(code) else "en"
	if system_locale.is_empty(): system_locale = OS.get_locale()
	var wanted: String = TranslationServer.standardize_locale(system_locale)
	while not wanted.is_empty():
		if locales.has(wanted): return wanted
		var separator: int = wanted.rfind("_")
		if separator < 0: break
		wanted = wanted.left(separator)
	return "en"

func choose(code: String) -> Error:
	if not valid(code): return ERR_INVALID_PARAMETER
	if storage_path.is_empty(): return ERR_UNCONFIGURED
	# Commit first: an unwritable preference must not change the current language.
	if not Store.write(storage_path,{"schema":1,"language":code},4096):
		last_error = ERR_CANT_CREATE
		return last_error
	last_error = OK
	preference = code
	_apply()
	return OK

func _apply() -> void:
	TranslationServer.set_locale(resolve(preference))
	if OS.is_debug_build() and "--pseudo-localization" in OS.get_cmdline_user_args():
		TranslationServer.pseudolocalization_enabled = true
	GameText.refresh(get_tree())
	changed.emit()

