extends RefCounted
## The engine supplies its own exact notices. Other texts travel with the game.
const COMMON: Array[Dictionary] = [
	{"id":"engine", "title":"Godot Engine"},
	{"id":"engine_libraries", "title":"Godot third-party libraries"},
	{"id":"fonts", "title":"Fonts", "files":[
		"res://assets/fonts/OFL.txt", "res://assets/fonts/libre_baskerville/OFL.txt",
		"res://assets/fonts/multilingual/notosansjp/OFL.txt",
		"res://assets/fonts/multilingual/notosanskr/OFL.txt",
		"res://assets/fonts/multilingual/googlesans/OFL.txt"]},
	{"id":"countries", "title":"Flags and country names", "files":[
		"res://assets/countries/LICENSE-flag-icons.txt", "res://assets/countries/UNICODE-LICENSE.txt"]},
	{"id":"audio", "title":"Sound and music credits", "files":["res://legal/audio_notices.txt"]},
	{"id":"cc0", "title":"CC0 1.0 Universal", "files":["res://assets/audio/locked_in_v1/CC0-LICENSE.txt"]},
	{"id":"native", "title":"Native libraries", "files":["res://platform/track_geometry/NOTICE.txt"]},
	{"id":"shader", "title":"Godot particle shader", "files":["res://vehicle/GODOT-DUST-SHADER-LICENSE.txt"]},
]
const WINDOWS_FILES: Array[String] = [
	"res://platform/windows/GODOT-CPP-LICENSE.txt",
	"res://platform/windows/GCC-COPYING3.txt",
	"res://platform/windows/GCC-RUNTIME-EXCEPTION.txt",
	"res://platform/windows/MINGW-CRT-LICENSE.txt",
	"res://platform/windows/WINPTHREADS-LICENSE.txt",
]
static var _engine_libraries: String = ""

static func entries(platform: String, debug_build: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = COMMON.duplicate(true)
	if platform == "Windows":
		result.append({"id":"windows", "title":"Windows runtime libraries", "files":WINDOWS_FILES})
	if platform == "Android":
		result.append({"id":"android", "title":"Android libraries", "files":["res://legal/android_notices.txt", "res://legal/ANDROIDX-LICENSE.txt", "res://legal/GOOGLEID-NOTICES.txt"]})
		if debug_build:
			result.append({"id":"admob", "title":"Google Mobile Ads", "files":["res://legal/admob_notices.txt", "res://legal/ADMOB-NOTICES.txt"]})
	return result

static func text_for(entry: Dictionary) -> String:
	match str(entry.id):
		"engine": return "Godot Engine\nhttps://godotengine.org/license/\n\n"+Engine.get_license_text()
		"engine_libraries": return _engine_library_text()
	var texts: PackedStringArray = []
	for path: String in entry.get("files", []):
		if not FileAccess.file_exists(path):
			push_error("Missing bundled licence notice: "+path)
			return ""
		texts.append(FileAccess.get_file_as_string(path))
	return "\n\n────────────────────────────────\n\n".join(texts)

static func _engine_library_text() -> String:
	if not _engine_libraries.is_empty(): return _engine_libraries
	var lines: PackedStringArray = []
	for component: Dictionary in Engine.get_copyright_info():
		lines.append(str(component.name))
		for part: Dictionary in component.parts:
			for owner: String in part.copyright: lines.append(owner)
			lines.append("License: "+str(part.license))
			for file: String in part.files: lines.append(file)
			lines.append("")
	var licences: Dictionary = Engine.get_license_info()
	for licence: String in licences:
		lines.append("\n"+licence+"\n")
		lines.append(str(licences[licence]))
	_engine_libraries = "\n".join(lines)
	return _engine_libraries
