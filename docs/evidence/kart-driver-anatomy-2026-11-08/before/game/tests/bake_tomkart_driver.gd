extends SceneTree
## Bake the enlarged seated driver with native matte cloth; no fabric texture.
const WORK: String = "res://../build/kart-driver-fit-style-2026-11-08"
const DEST: String = "res://assets/vehicles/kart_refined_v1/tomkart_driver_v1"
const GENERATED: String = "res://../docs/evidence/kart-tomkart-driver-2026-11-08/imagegen/"
var preview: bool = false

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
	if not preview: assert(original.save_png(DEST+"/textures/"+file) == OK)

func cloth(source: Mesh, surface: int, tool: SurfaceTool) -> void:
	var arrays: Array = source.surface_get_arrays(surface)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Foot meshes share the original suit atlas, but get plain rubber boots.
	var top: float = -INF
	for point: Vector3 in positions: top = maxf(top,point.y)
	var boot: bool = top < 0.4
	for index: int in indices:
		var color := Color("465861")
		if boot:
			color = Color("1d292e")
		elif surface in [7,10] and positions[index].y > 0.77:
			# Quiet shoulder yokes belong to the garment geometry; photographic
			# folds, logos and highlights are not sampled into the new material.
			color = Color("929c9a")
		elif surface == 11 and positions[index].y > 0.89:
			color = Color("26343a")
		tool.set_color(color)
		tool.set_normal(normals[index])
		tool.set_uv(uv[index])
		tool.add_vertex(positions[index])

func run() -> void:
	preview = "--preview" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST+"/textures"))
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
	assert(source.get_surface_count() == 21)
	var result := ArrayMesh.new()
	var tools: Dictionary = {}
	var materials: Dictionary = {}
	for surface: int in range(source.get_surface_count()):
		var material: StandardMaterial3D = source.surface_get_material(surface)
		var key: String = material.resource_name
		# The bulky source neck restraint obscures the seated silhouette.
		if key == "RT_HANS": continue
		if not tools.has(key):
			tools[key] = SurfaceTool.new()
			materials[key] = material
			if key == "RT_DriverSuit": tools[key].begin(Mesh.PRIMITIVE_TRIANGLES)
			if key in ["RT_DriverSuit","RT_Gloves","RT_HANS"]:
				material.albedo_texture = null
				material.albedo_color = Color.WHITE if key == "RT_DriverSuit" else Color("26343a")
				material.vertex_color_use_as_albedo = key == "RT_DriverSuit"
				material.vertex_color_is_srgb = true
				material.roughness = 1.0
				material.metallic_specular = 0.0
				material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			else:
				material.roughness = 0.42
				material.metallic_specular = 0.3
		if key == "RT_DriverSuit":
			cloth(source,surface,tools[key])
		else: tools[key].append_from(source,surface,Transform3D.IDENTITY)
	for key: String in tools:
		if key == "RT_DriverSuit": tools[key].index()
		tools[key].commit(result)
		result.surface_set_material(result.get_surface_count()-1,materials[key])
	assert(result.get_faces().size()/3 == 1343)
	assert(ResourceSaver.save(result,(WORK+"/candidate" if preview else DEST)+"/driver.res",ResourceSaver.FLAG_COMPRESS) == OK)
	scene.free()
	print("TOMKART_DRIVER_BAKE ",result.get_faces().size()/3," triangles; ",result.get_surface_count()," material surfaces; native matte cloth; preview=",preview)
	quit()
