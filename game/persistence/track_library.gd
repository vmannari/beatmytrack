class_name TrackLibrary
extends RefCounted
## Local drafts have no count quota. Imported content is bounded plain JSON.

var directory: String
var last_error: String = ""
var revision: int = 0


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
	if is_published(str(document.get("id",""))):
		last_error = "Published tracks are locked against editing."
		return ERR_UNAUTHORIZED
	var errors: Array[String] = TrackDocument.validate(document,false)
	if not errors.is_empty():
		last_error = errors[0]
		return ERR_INVALID_DATA
	var review_error: Error = invalidate_test_if_changed(document)
	if review_error != OK: return review_error
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		last_error = "Could not open the local track folder."
		return error
	error = _atomic_write(document,directory.path_join(document.id+".json"))
	if error == OK: revision += 1
	return error


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
		last_error = "This file is too large; creator tracks are at most 512 KB."
		file.close()
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		last_error = "This file is not valid track JSON."
		return {}
	var errors: Array[String] = TrackDocument.validate(parser.data,false)
	if not errors.is_empty():
		last_error = errors[0]
		return {}
	last_error = ""
	return parser.data


func _atomic_write(document: Dictionary, path: String) -> Error:
	var content: String = JSON.stringify(document,"\t",true)
	if content.to_utf8_buffer().size() > TrackDocument.MAX_BYTES:
		last_error = "This creator track exceeds 512 KB."
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


func delete_document(id: String) -> Error:
	if not TrackDocument.valid_id(id):
		last_error = "The track identifier is invalid."
		return ERR_INVALID_PARAMETER
	# Remove recovery files before the primary so a successful deletion cannot
	# reappear through backup recovery. Never enumerate or delete directories.
	for suffix: String in [".json.tmp",".json.bak",".json"]:
		var path: String = directory.path_join(id+suffix)
		if not FileAccess.file_exists(path): continue
		var error: Error = DirAccess.remove_absolute(path)
		if error != OK:
			last_error = "Could not delete the track. Check storage permissions."
			return error
	revision += 1
	last_error = ""
	return OK


func save_wip(document: Dictionary) -> Error:
	if is_published(str(document.get("id",""))):
		last_error = "Published tracks are locked against editing."
		return ERR_UNAUTHORIZED
	var review_error: Error = invalidate_test_if_changed(document)
	if review_error != OK: return review_error
	var drafts := TrackLibrary.new(directory.path_join("wip"))
	var error: Error=drafts.save_document(document)
	last_error=drafts.last_error
	return error

func load_wip(id: String) -> Dictionary:
	var drafts := TrackLibrary.new(directory.path_join("wip"))
	var result: Dictionary=drafts.load_document(id)
	last_error=drafts.last_error
	return result

func list_wips() -> Array[Dictionary]:
	return TrackLibrary.new(directory.path_join("wip")).list_documents()

func editable_entries() -> Array[Dictionary]:
	# Saved originals and editor autosaves are versions of the same local draft.
	var by_id: Dictionary = {}
	for source: String in ["saved","wip"]:
		var store := TrackLibrary.new(directory.path_join("wip") if source == "wip" else directory)
		for doc: Dictionary in store.list_documents():
			if is_published(str(doc.id)): continue
			var modified: int = 0
			for suffix: String in [".json",".json.bak",".json.tmp"]:
				var path: String = store.directory.path_join(str(doc.id)+suffix)
				if FileAccess.file_exists(path) and not store._read(path).is_empty():
					modified = FileAccess.get_modified_time(path)
					break
			var item: Dictionary = {"id":doc.id,"document":doc,"modified":modified,"source":source,
				"load_id":("wip:" if source == "wip" else "")+str(doc.id)}
			if not by_id.has(doc.id) or modified >= int(by_id[doc.id].modified): by_id[doc.id] = item
	var result: Array[Dictionary] = []
	for item: Dictionary in by_id.values(): result.append(item)
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.modified != b.modified: return a.modified > b.modified
		return str(a.document.name).naturalnocasecmp_to(str(b.document.name)) < 0)
	return result

func delete_editable(id: String) -> Error:
	if is_published(id):
		last_error = "Published tracks are locked."
		return ERR_UNAUTHORIZED
	var review_error: Error = _test_library().delete_document(id)
	if review_error != OK: return review_error
	var drafts := TrackLibrary.new(directory.path_join("wip"))
	var error: Error = drafts.delete_document(id)
	if error != OK:
		last_error = drafts.last_error
		return error
	return delete_document(id)

func _test_library() -> TrackLibrary:
	var version: String = (VehicleSimulation.PHYSICS_VERSION+RaceRules.KEY+TrackCompiler.VERSION).sha256_text().left(12)
	return TrackLibrary.new(directory.path_join(".tested-"+version))

static func draft_fingerprint(document: Dictionary) -> String:
	return JSON.stringify(document,"",true).sha256_text()

func is_tested(document: Dictionary) -> bool:
	if not TrackDocument.valid_id(document.get("id")): return false
	var snapshot: Dictionary = _test_library().load_document(str(document.id))
	return not snapshot.is_empty() and draft_fingerprint(snapshot) == draft_fingerprint(document)

func mark_tested(document: Dictionary) -> Error:
	if not TrackDocument.validate(document).is_empty(): return ERR_INVALID_DATA
	if not document.has("start_line") or not RoadPieces.route_from_pieces(document).ok:
		last_error = "Connect the roads and place a start line before completing a test."
		return ERR_INVALID_DATA
	var reviews := _test_library()
	var error: Error = DirAccess.make_dir_recursive_absolute(reviews.directory)
	if error == OK: error = reviews._atomic_write(document,reviews.directory.path_join(str(document.id)+".json"))
	last_error = reviews.last_error
	return error

func invalidate_test_if_changed(document: Dictionary) -> Error:
	var reviews := _test_library()
	var snapshot: Dictionary = reviews.load_document(str(document.id))
	if snapshot.is_empty() or draft_fingerprint(snapshot) == draft_fingerprint(document): return OK
	var error: Error = reviews.delete_document(str(document.id))
	last_error = reviews.last_error
	return error

func is_published(id: String) -> bool:
	if not TrackDocument.valid_id(id): return false
	return not TrackLibrary.new(directory.path_join(".published")).load_document(id).is_empty()

func publish_document(document: Dictionary) -> Error:
	if is_published(str(document.get("id",""))): return ERR_ALREADY_EXISTS
	if not is_tested(document):
		last_error = "Complete test run to publish"
		return ERR_UNAUTHORIZED
	var error: Error = save_document(document)
	if error != OK: return error
	var published := TrackLibrary.new(directory.path_join(".published"))
	error = published.save_document(document)
	last_error = published.last_error
	if error == OK: revision += 1
	return error
