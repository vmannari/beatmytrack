class_name TrackLibrary
extends RefCounted
## Local drafts have no count quota. Imported content is bounded plain JSON.

var directory: String
var last_error: String = ""


func _init(root: String = "user://tracks") -> void:
	directory = root.trim_suffix("/")


static func unique_id() -> String:
	return "track_" + Crypto.new().generate_random_bytes(8).hex_encode()


func list_documents() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var folder := DirAccess.open(directory)
	if folder == null:
		return result
	var ids: Array[String] = []
	for filename: String in folder.get_files():
		var base: String = filename.trim_suffix(".bak").trim_suffix(".tmp")
		if not base.ends_with(".json"):
			continue
		var id: String = base.trim_suffix(".json")
		if TrackDocument.valid_id(id) and id not in ids:
			ids.append(id)
	ids.sort()
	for id: String in ids:
		var document: Dictionary = load_document(id)
		if not document.is_empty():
			result.append(document)
	return result


func save_document(document: Dictionary) -> Error:
	var errors: Array[String] = TrackDocument.validate(document)
	if not errors.is_empty():
		last_error = errors[0]
		return ERR_INVALID_DATA
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		last_error = "Could not open the local track folder."
		return error
	return _atomic_write(document,directory.path_join(document.id+".json"))


func load_document(id: String) -> Dictionary:
	if not TrackDocument.valid_id(id):
		last_error = "The track identifier is invalid."
		return {}
	var path: String = directory.path_join(id+".json")
	# Prefer committed state, then last known good state, then a first-save
	# temporary. Reads recover even after a crash between the two renames.
	for candidate: String in [path,path+".bak",path+".tmp"]:
		var data: Dictionary = _read(candidate)
		if not data.is_empty() and data.id == id:
			last_error = ""
			return data
	last_error = "This saved track could not be read."
	return {}


func export_document(document: Dictionary, path: String) -> Error:
	if not TrackDocument.validate(document).is_empty():
		last_error = "Fix the route before exporting it."
		return ERR_INVALID_DATA
	return _atomic_write(document,path)


func import_document(path: String) -> Dictionary:
	return _read(path)


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		last_error = "Could not open the track file."
		return {}
	if file.get_length() > TrackDocument.MAX_BYTES:
		last_error = "This file is too large; creator tracks are at most 16 KB."
		file.close()
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		last_error = "This file is not valid track JSON."
		return {}
	var errors: Array[String] = TrackDocument.validate(parser.data)
	if not errors.is_empty():
		last_error = errors[0]
		return {}
	last_error = ""
	return parser.data


func _atomic_write(document: Dictionary, path: String) -> Error:
	var content: String = JSON.stringify(document,"\t",true)
	if content.to_utf8_buffer().size() > TrackDocument.MAX_BYTES:
		last_error = "This creator track exceeds 16 KB."
		return ERR_INVALID_DATA
	var temporary: String = path+".tmp"
	var backup: String = path+".bak"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		last_error = "Could not write the track file."
		return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or _read(temporary).is_empty():
		last_error = "The track write could not be verified."
		return ERR_FILE_CANT_WRITE
	if FileAccess.file_exists(path):
		# Never replace a recoverable good backup with a corrupt primary.
		if not _read(path).is_empty():
			if FileAccess.file_exists(backup):
				error = DirAccess.remove_absolute(backup)
				if error != OK:
					last_error = "Could not prepare the track backup."
					return error
			error = DirAccess.rename_absolute(path,backup)
		else:
			error = DirAccess.remove_absolute(path)
		if error != OK:
			last_error = "Could not preserve the previous track."
			return error
	error = DirAccess.rename_absolute(temporary,path)
	last_error = "" if error == OK else "Could not finish saving; the previous track is recoverable."
	return error
