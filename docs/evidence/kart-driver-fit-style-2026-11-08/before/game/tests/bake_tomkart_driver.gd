extends SceneTree
## Bake the reviewed static source adaptation and imagegen logo-removal patches.
const WORK: String = "res://../build/kart-driver-tomkart-2026-11-08"
const DEST: String = "res://assets/vehicles/kart_refined_v1/tomkart_driver_v1"
const GENERATED: String = "res://../docs/evidence/kart-tomkart-driver-2026-11-08/imagegen/"

func _initialize() -> void: run.call_deferred()

func clean(file: String, generated: String, rectangles: Array[Rect2i], letterbox: bool = false) -> void:
	var original: Image = Image.load_from_file(ProjectSettings.globalize_path(WORK+"/source/textures/"+file))
	var edited: Image = Image.load_from_file(ProjectSettings.globalize_path(GENERATED+generated))
	assert(original != null and edited != null)
	# The image tool letterboxes 4:1 artwork to its supported aspect ratio.
	if letterbox:
		var height: int = edited.get_width()/4
		edited = edited.get_region(Rect2i(0,(edited.get_height()-height)/2,edited.get_width(),height))
	edited.resize(original.get_width(),original.get_height(),Image.INTERPOLATE_LANCZOS)
	original.convert(Image.FORMAT_RGBA8)
	edited.convert(Image.FORMAT_RGBA8)
	for rect: Rect2i in rectangles:
		for y: int in range(rect.position.y,rect.end.y):
			for x: int in range(rect.position.x,rect.end.x):
				var edge: int = mini(mini(x-rect.position.x,rect.end.x-1-x),mini(y-rect.position.y,rect.end.y-1-y))
				var blend: float = smoothstep(0,4,edge)
				original.set_pixel(x,y,original.get_pixel(x,y).lerp(edited.get_pixel(x,y),blend))
	assert(original.save_png(ProjectSettings.globalize_path(WORK+"/candidate/textures/"+file)) == OK)
	assert(original.save_png(DEST+"/textures/"+file) == OK)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST+"/textures"))
	clean("RT_DriverSuit_baseColor.png","suit.png",[
		Rect2i(230,332,205,48),Rect2i(170,426,57,54),Rect2i(455,426,54,55),
		Rect2i(780,78,36,169),Rect2i(779,758,39,207)])
	clean("RT_Gloves_baseColor.png","gloves.png",[
		Rect2i(68,205,50,50),Rect2i(905,206,55,55),Rect2i(154,343,105,107),Rect2i(770,342,108,108),
		Rect2i(318,413,126,83),Rect2i(582,413,126,83),Rect2i(378,345,81,91),Rect2i(575,345,81,91),
		Rect2i(124,154,68,31),Rect2i(837,154,62,29)])
	clean("RT_Helemt_trasparent_baseColor.png","helmet.png",[
		Rect2i(1250,46,126,53),Rect2i(908,132,100,78),Rect2i(1615,132,110,80)],true)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(ProjectSettings.globalize_path(WORK+"/candidate/driver.gltf"),state) == OK)
	var scene: Node3D = document.generate_scene(state)
	var nodes: Array[Node] = scene.find_children("*","MeshInstance3D",true,false)
	if scene is MeshInstance3D: nodes.push_front(scene)
	assert(nodes.size() == 1)
	var source: ArrayMesh = nodes[0].mesh
	var result := ArrayMesh.new()
	var tools: Dictionary = {}
	var materials: Dictionary = {}
	for surface: int in range(source.get_surface_count()):
		var material: StandardMaterial3D = source.surface_get_material(surface)
		var key: String = material.resource_name
		if not tools.has(key):
			tools[key] = SurfaceTool.new()
			materials[key] = material
			material.roughness = 0.85 if key in ["RT_DriverSuit","RT_Gloves","RT_HANS"] else 0.42
			material.metallic_specular = 0.08 if key in ["RT_DriverSuit","RT_Gloves"] else 0.3
		tools[key].append_from(source,surface,Transform3D.IDENTITY)
	for key: String in tools:
		tools[key].commit(result)
		result.surface_set_material(result.get_surface_count()-1,materials[key])
	assert(result.get_faces().size()/3 == 1445)
	assert(ResourceSaver.save(result,DEST+"/driver.res",ResourceSaver.FLAG_COMPRESS) == OK)
	scene.free()
	print("TOMKART_DRIVER_BAKE 1445 triangles; ",result.get_surface_count()," material surfaces; three unbranded texture atlases")
	quit()
