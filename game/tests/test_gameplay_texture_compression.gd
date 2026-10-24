extends SceneTree
const Inventory = preload("res://tests/profile_gameplay_textures.gd")
const ROOT: String = "res://../docs/evidence/gameplay-f05-f10-2026-10-23"
var checks: int = 0
var failures: int = 0
var originals: Dictionary = {}
var android_textures: Dictionary = {}
var rows: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func frames(count: int = 20) -> void:
	for index: int in range(count): await RenderingServer.frame_post_draw
func materials(node: Node, result: Array[Material]) -> void:
	if node is GeometryInstance3D and node.material_override!=null and node.material_override not in result: result.append(node.material_override)
	if node is MeshInstance3D and node.mesh!=null:
		for index: int in range(node.mesh.get_surface_count()):
			var material: Material = node.mesh.surface_get_material(index)
			if material!=null and material not in result: result.append(material)
	for child: Node in node.get_children(): materials(child,result)
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	root.size = Vector2i(1280,720); var folder: String = ProjectSettings.globalize_path(ROOT.path_join("texture-views/"+RenderingServer.get_current_rendering_method())); DirAccess.make_dir_recursive_absolute(folder)
	for name: String in Inventory.NAMES:
		var old := CompressedTexture2D.new(); check(old.load(ROOT.path_join("textures/"+name+".ctex"))==OK,"original complete mip chain loads: "+name)
		originals["res://assets/textures/"+name+".png"] = old
		var current: Texture2D = load("res://assets/textures/"+name+".png"); var image: Image = current.get_image()
		check(image.is_compressed(),"resident GPU source uses block compression: "+name)
		rows.append({"name":name,"width":image.get_width(),"height":image.get_height(),"format":image.get_format(),"bytes":image.get_data_size(),"mipmaps":image.has_mipmaps()})
		# Decode the verified ETC2 packets headlessly first: this desktop Vulkan
		# driver cannot upload ETC2 and its unsupported-format fallback errors.
		var android_image: Image = load(Inventory.DECODED.path_join(name+"-etc2.res"))
		check(android_image!=null and android_image.has_mipmaps(),"decoded Android artifact retains the full mip chain: "+name)
		android_textures[current.resource_path] = ImageTexture.create_from_image(android_image)
	for theme: String in TrackTheme.IDS:
		var document: Dictionary = TrackDocument.create_default(); document.theme = theme
		var track: NativeTrack = TrackCompiler.compile(document)
		var game: Node = load("res://core/game.tscn").instantiate(); game.production_mode = true; game.initial_track = track; game.process_mode = Node.PROCESS_MODE_DISABLED; game.hitch_diagnostics_enabled = false; root.add_child(game)
		game._process(0.0)
		var surfaces: Array[Material] = []; materials(game,surfaces)
		var changes: Array = []
		for material: Material in surfaces:
			if not material is ShaderMaterial: continue
			if material.shader.code.contains("TIME"):
				var fixed := Shader.new(); fixed.code = material.shader.code.replace("TIME","0.0"); material.shader = fixed
			for uniform: Dictionary in material.shader.get_shader_uniform_list():
				var texture: Variant = material.get_shader_parameter(uniform.name)
				if texture is Texture2D and originals.has(texture.resource_path): changes.append([material,uniform.name,texture,originals[texture.resource_path],android_textures[texture.resource_path]])
		await frames(60)
		for change: Array in changes: change[0].set_shader_parameter(change[1],change[3])
		await frames(); var before: Image = root.get_texture().get_image()
		before.save_png(folder.path_join(theme+"-before.png"))
		for variant: int in [2,4]:
			for change: Array in changes: change[0].set_shader_parameter(change[1],change[variant])
			await frames(); var after: Image = root.get_texture().get_image()
			var metrics: Dictionary = before.compute_image_metrics(after,false)
			var platform: String = "desktop" if variant==2 else "ETC2 decoded on desktop"
			check(metrics.mean<=2.04,"native-camera mean colour error stays below 0.8%: "+theme+" "+platform)
			after.save_png(folder.path_join(theme+("-after.png" if variant==2 else "-etc2.png")))
			rows.append({"theme":theme,"platform":platform,"image_metrics":metrics,"bindings":changes.size()}); print("TEXTURE_NATIVE_VIEW ",theme," ",platform," ",JSON.stringify(metrics))
		game.free(); await process_frame
	# Dust exercises the selected alpha texture separately from stationary races.
	var background := ColorRect.new(); background.color = Color(0.2,0.25,0.3); background.size = Vector2(1280,720); root.add_child(background)
	var puff := TextureRect.new(); puff.position = Vector2(480,200); puff.size = Vector2(320,320); puff.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; root.add_child(puff)
	puff.texture = originals["res://assets/textures/dust_puff_v1.png"]; await frames(); var dust_before: Image = root.get_texture().get_image()
	puff.texture = load("res://assets/textures/dust_puff_v1.png"); await frames(); var dust_after: Image = root.get_texture().get_image()
	var dust_metrics: Dictionary = dust_before.compute_image_metrics(dust_after,false)
	check(dust_metrics.mean<=2.04,"dust alpha artwork preserves the same 0.8% mean colour budget")
	dust_before.save_png(folder.path_join("dust-before.png")); dust_after.save_png(folder.path_join("dust-after.png")); rows.append({"theme":"dust-alpha","image_metrics":dust_metrics})
	puff.free(); background.free()
	var output := FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE); output.store_string(JSON.stringify({"rows":rows,"checks":checks,"failures":failures},"\t",true)+"\n"); output.close()
	print("GAMEPLAY_TEXTURE_COMPRESSION: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
