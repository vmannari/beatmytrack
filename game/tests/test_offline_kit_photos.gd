extends SceneTree
## Offline legacy photograph generator: intentionally excluded from production.
const OfflineKitThumbnail = preload("res://tests/support/offline_kit_thumbnail.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)
func run() -> void:
	OfflineKitThumbnail.images.clear()
	for category: String in VehicleCustomisation.CATEGORIES:
		for option: Array in VehicleCustomisation.OPTIONS[category]:
			var card: OfflineKitThumbnail = OfflineKitThumbnail.make(category,option,false,func() -> void: pass)
			root.add_child(card)
			check(card.viewport==null,"cold preview needs no car/world: "+category+"/"+str(option[0]))
			var path: String = CompactKits.ASSET_ROOT.path_join("previews/"+RenderingServer.get_current_rendering_method()+"/"+category+"_"+str(option[0])+".png")
			var original := Image.new()
			original.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
			var imported: Image = card.image.texture.get_image()
			imported.clear_mipmaps()
			original.convert(Image.FORMAT_RGBA8)
			imported.convert(Image.FORMAT_RGBA8)
			check(original.get_data()==imported.get_data(),"preview pixels exact "+category+"/"+str(option[0]))
			card.queue_free()
			await process_frame
	check(OfflineKitThumbnail.images.size()<=16,"preview byte budget retains sixteen images")
	print("OFFLINE_KIT_PHOTOS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
