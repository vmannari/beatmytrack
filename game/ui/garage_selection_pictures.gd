extends RefCounted
## Sharp native stock portraits. Saved paint, kits and wear retain exact previews.
const Build = preload("res://core/build_identity.gd")
const DIRECTORY: String = "res://assets/garage/selection_portraits_v1/"
const VERSION: String = "garage-selection-portrait-1"
static var _manifest: Dictionary = {}
static var _read: bool = false
static var _textures: Dictionary = {}

static func texture(view: Node) -> Texture2D:
	var service: Node = view.get("preview_service")
	if service == null or not service._default(view): return null
	if not _read:
		_read = true
		if FileAccess.file_exists(DIRECTORY+"provenance.json"):
			var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"provenance.json"))
			if value is Dictionary: _manifest = value
	if _manifest.get("version","") != VERSION or _manifest.get("revision","") != Build.HEADER_PREVIEW_SHA256: return null
	if _manifest.get("garage_revision","") != Build.GARAGE_PREVIEW_SHA256: return null
	var id: String = str(view.get("vehicle_id"))
	var path: String = DIRECTORY+id+".png"
	if not _manifest.get("pictures",{}).has(id): return null
	if not _textures.has(id):
		if FileAccess.get_sha256(path) != str(_manifest.pictures[id]): return null
		var pixels: Image = Image.load_from_file(path)
		if pixels == null or pixels.get_size() != Vector2i(512,288): return null
		pixels.generate_mipmaps()
		_textures[id] = ImageTexture.create_from_image(pixels)
	return _textures[id]
