extends RefCounted
## Exact native podium readbacks. No retained worlds or process texture cache.
const SCHEMA: String = "rivalry-podium-raw-1"
const MAGIC: String = "BMTPOD01"
const HEADER_BYTES: int = 80
const DIRECTORY: String = "user://rivalry_podium_pictures_v1"
const MAX_ENTRIES: int = 24
const MAX_BYTES: int = 32*1024*1024
const MAX_IMAGE_BYTES: int = 1536*768*4
const Build = preload("res://core/build_identity.gd")
static var enabled: bool = true
static var hits: int = 0
static var writes: int = 0
static var _source_revisions: Dictionary = {}

static func remember(owner: WeakRef) -> void:
	# prepare() has requested its final original radiance draw. Read only after
	# that draw, and reject resizing/navigation/cosmetic changes during the wait.
	var view: Control = owner.get_ref() as Control
	if view == null: return
	var key: String = identity(view,view.viewport.size)
	view = null
	await RenderingServer.frame_post_draw
	view = owner.get_ref() as Control
	if view == null or view.is_queued_for_deletion() or not view.is_visible_in_tree() or not view.presentation_ready: return
	if identity(view,view.viewport.size) != key: return
	write_picture(key,view.viewport.get_texture().get_image())

static func identity(view: Control, dimensions: Vector2i) -> String:
	if not enabled or not view.podium_presentation or DisplayServer.get_name() == "headless" or dimensions.x <= 1 or dimensions.y <= 1: return ""
	var value: Array = [SCHEMA,source_revision(view.vehicle_id),Engine.get_version_info(),OS.get_name(),RenderingServer.get_current_rendering_method(),RenderingServer.get_current_rendering_driver_name(),RenderingServer.get_video_adapter_name(),RenderingServer.get_video_adapter_vendor(),RenderingServer.get_video_adapter_api_version(),dimensions,view.vehicle_id,view.simple_model,view.fit_to_frame,view.header_template,view.livery,view.customisation,view.condition,Viewport.MSAA_4X]
	return digest(var_to_bytes(value))

static func source_revision(vehicle: String) -> String:
	if _source_revisions.has(vehicle): return _source_revisions[vehicle]
	var sources: Array = [Build.SOURCE_SHA256]
	# Standard builds pin all source/assets. A source checkout also rejects edits
	# made before regenerating that identity, using the existing car source guard.
	if OS.has_feature("editor"):
		sources.append(preload("res://vehicle/prepared_asset_sources.gd").runtime_hashes(vehicle))
		for path: String in ["res://project.godot","res://ui/rivalry_podium_pictures.gd","res://ui/rivalry_cached_podium.gd","res://ui/rivalry_victory_car.gd","res://ui/rivalry_podium_studio.gd","res://ui/rivalry_car_composite.gdshader","res://ui/garage_environment.gd","res://ui/showroom_studio.gd","res://ui/studio_sky.gdshader","res://ui/studio_contact.gdshader"]:
			sources.append([path,FileAccess.get_sha256(path)])
	var revision: String = digest(var_to_bytes(sources))
	_source_revisions[vehicle] = revision
	return revision

static func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func read_picture(key: String, dimensions: Vector2i) -> ImageTexture:
	if not _valid_key(key) or dimensions.x <= 1 or dimensions.y <= 1 or dimensions.x > 1536 or dimensions.y > 768: return null
	var file := FileAccess.open(DIRECTORY.path_join(key+".bin"),FileAccess.READ)
	if file == null or file.get_length() != HEADER_BYTES+dimensions.x*dimensions.y*4: return null
	if file.get_buffer(8).get_string_from_utf8() != MAGIC or file.get_buffer(32).hex_encode() != key: return null
	if Vector2i(file.get_32(),file.get_32()) != dimensions: return null
	var expected: String = file.get_buffer(32).hex_encode()
	var bytes: PackedByteArray = file.get_buffer(dimensions.x*dimensions.y*4)
	if expected != digest(bytes): return null
	var picture := Image.create_from_data(dimensions.x,dimensions.y,false,Image.FORMAT_RGBA8,bytes)
	if picture == null or picture.is_empty(): return null
	hits += 1
	return ImageTexture.create_from_image(picture)

static func write_picture(key: String, image: Image) -> bool:
	# Only the exact supported native format is persisted; never quantize HDR.
	if not _valid_key(key) or image == null or image.is_empty() or image.get_format() != Image.FORMAT_RGBA8 or image.has_mipmaps(): return false
	var bytes: PackedByteArray = image.get_data()
	if image.get_width() > 1536 or image.get_height() > 768 or bytes.size() > MAX_IMAGE_BYTES: return false
	if DirAccess.make_dir_recursive_absolute(DIRECTORY) != OK: return false
	var destination: String = DIRECTORY.path_join(key+".bin")
	var temporary: String = destination+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(MAGIC.to_utf8_buffer())
	file.store_buffer(key.hex_decode())
	file.store_32(image.get_width())
	file.store_32(image.get_height())
	file.store_buffer(digest(bytes).hex_decode())
	file.store_buffer(bytes)
	file.flush()
	var valid: bool = file.get_error() == OK
	file.close()
	if not valid or DirAccess.rename_absolute(temporary,destination) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	writes += 1
	_trim()
	return true

static func _valid_key(key: String) -> bool:
	return enabled and key.length() == 64 and key.is_valid_hex_number()

static func _trim() -> void:
	var entries: Array[Dictionary] = []
	var total: int = 0
	for filename: String in DirAccess.get_files_at(DIRECTORY):
		var base: String = filename.trim_suffix(".tmp")
		if not base.ends_with(".bin") or not _valid_key(base.trim_suffix(".bin")): continue
		var path: String = DIRECTORY.path_join(filename)
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null: continue
		var bytes: int = file.get_length()
		file.close()
		total += bytes
		entries.append({"path":path,"bytes":bytes,"time":FileAccess.get_modified_time(path)})
	entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.time < b.time)
	while not entries.is_empty() and (entries.size() > MAX_ENTRIES or total > MAX_BYTES):
		var oldest: Dictionary = entries.pop_front()
		if DirAccess.remove_absolute(oldest.path) == OK: total -= int(oldest.bytes)
