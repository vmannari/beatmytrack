extends SceneTree
const Pictures = preload("res://ui/rivalry_podium_pictures.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PODIUM_STORAGE_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var raw := Image.create(8,8,false,Image.FORMAT_RGBA8)
	raw.fill(Color(0.1,0.2,0.3,0.4))
	var key: String = "fixture".sha256_text()
	check(Pictures.write_picture(key,raw),"atomic raw write")
	var restored: ImageTexture = Pictures.read_picture(key,raw.get_size())
	check(restored != null and restored.get_image().get_data() == raw.get_data(),"exact native bytes restored")
	check(Pictures.read_picture(key,Vector2i(4,16)) == null,"equal byte length wrong extent rejected")
	check(Pictures.read_picture("../escape",raw.get_size()) == null,"only SHA256 filenames allowed")
	var path: String = Pictures.DIRECTORY.path_join(key+".bin")
	var file := FileAccess.open(path,FileAccess.READ_WRITE)
	file.seek(Pictures.HEADER_BYTES)
	file.store_8(255)
	file.close()
	check(Pictures.read_picture(key,raw.get_size()) == null,"corrupt pixel digest rejected")
	check(Pictures.write_picture(key,raw),"corrupt file can be atomically replaced")
	file = FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(PackedByteArray([0,1,2]))
	file.close()
	check(Pictures.read_picture(key,raw.get_size()) == null,"truncated data rejected without Variant decoding")
	var hdr := Image.create(8,8,false,Image.FORMAT_RGBAH)
	check(not Pictures.write_picture("hdr".sha256_text(),hdr),"HDR never quantized into cache")
	for index: int in range(Pictures.MAX_ENTRIES+3):
		check(Pictures.write_picture(str(index).sha256_text(),raw),"bounded small write "+str(index))
	check(DirAccess.get_files_at(Pictures.DIRECTORY).size() <= Pictures.MAX_ENTRIES,"entry bound enforced")
	var large := Image.create(1536,768,false,Image.FORMAT_RGBA8)
	large.fill(Color(0.8,0.2,0.4,1))
	for index: int in range(8):
		check(Pictures.write_picture(("large"+str(index)).sha256_text(),large),"bounded large write "+str(index))
	var total: int = 0
	for filename: String in DirAccess.get_files_at(Pictures.DIRECTORY):
		file = FileAccess.open(Pictures.DIRECTORY.path_join(filename),FileAccess.READ)
		total += file.get_length()
		file.close()
	check(total <= Pictures.MAX_BYTES,"disk byte bound enforced")
	print("PODIUM_STORAGE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
