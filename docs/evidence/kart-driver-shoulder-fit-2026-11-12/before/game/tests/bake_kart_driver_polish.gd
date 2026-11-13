extends SceneTree
## KDP01-KDP04: retained control fit, clean native helmet, smooth suit, steering poses.
const OUT: String = "res://../docs/evidence/kart-driver-polish-2026-11-12"
const DEST: String = "res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res"
const STEERING = preload("res://vehicle/kart_steering.gd")
const HELMET = preload("res://vehicle/kart_helmet.gd")
var body_source: Array = []
var static_vertex_count: int = 0
const RINGS: int = 20
const SIDES: int = 16

func _initialize() -> void: run.call_deferred()

func sleeve_center(t: float, shoulder: Vector3, elbow: Vector3, wrist: Vector3) -> Vector3:
	# Straight limb shafts meet in a short rounded elbow. Curving both entire
	# shafts into one spline made the old silhouette read as a rubber hose.
	var root: Vector3 = shoulder+Vector3(0,-0.010,-0.045)
	var entry: Vector3 = elbow+(root-elbow).normalized()*0.035
	var exit: Vector3 = elbow+(wrist-elbow).normalized()*0.035
	if t <= 0.45: return root.lerp(entry,t/0.45)
	if t >= 0.55: return exit.lerp(wrist,(t-0.55)/0.45)
	var u: float = (t-0.45)/0.10
	return entry*(1-u)*(1-u)+elbow*2*u*(1-u)+exit*u*u

func sleeve_radius(t: float) -> float:
	# Deltoid, upper arm, elbow, forearm muscle and narrow wrist/cuff.
	var profile: Array[Vector2] = [Vector2(0,0.064),Vector2(0.12,0.063),Vector2(0.35,0.053),Vector2(0.50,0.046),Vector2(0.62,0.050),Vector2(0.82,0.039),Vector2(0.94,0.033),Vector2(1,0.034)]
	for index: int in range(profile.size()-1):
		if t <= profile[index+1].x:
			return lerpf(profile[index].y,profile[index+1].y,smoothstep(profile[index].x,profile[index+1].x,t))
	return profile[-1].y

func sleeve(input: float, side: float) -> Array:
	var shoulder: Vector3 = STEERING.mirrored(STEERING.SHOULDER,side)
	var pole: Vector3 = STEERING.mirrored(Vector3(0.23,0.52,0.10),side)
	var rotation: Basis = STEERING.wheel_basis(input)*STEERING.REST.inverse()
	var wrist: Vector3 = STEERING.CENTER+rotation*(STEERING.mirrored(STEERING.WRIST,side)-STEERING.SOURCE_CENTER)
	var elbow: Vector3 = STEERING.elbow_for(shoulder,wrist,pole)
	var outer_elbow: Vector3 = ((elbow-shoulder).normalized()-(wrist-elbow).normalized()).normalized()
	var vertices := PackedVector3Array()
	var reference := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for row: int in range(RINGS+1):
		var t: float = float(row)/RINGS
		var point: Vector3 = sleeve_center(t,shoulder,elbow,wrist)
		var tangent: Vector3 = (sleeve_center(minf(1,t+0.001),shoulder,elbow,wrist)-sleeve_center(maxf(0,t-0.001),shoulder,elbow,wrist)).normalized()
		var across: Vector3 = (Vector3.RIGHT-tangent*tangent.dot(Vector3.RIGHT)).normalized()
		var up: Vector3 = tangent.cross(across).normalized()
		var radius: float = sleeve_radius(t)
		for column: int in range(SIDES+1):
			var a: float = TAU*column/SIDES
			var normal: Vector3 = across*cos(a)+up*sin(a)
			var inner: float = maxf(0,-normal.dot(outer_elbow))
			var fold: float = (0.003*exp(-pow((t-0.43)/0.024,2))-0.0025*exp(-pow((t-0.49)/0.020,2))+0.002*exp(-pow((t-0.55)/0.025,2)))*inner*inner
			var elbow_tip: float = 0.004*exp(-pow((t-0.50)/0.055,2))*pow(maxf(0,normal.dot(outer_elbow)),3)
			var cuff: float = 0.001*exp(-pow((t-0.96)/0.020,2))
			# The sleeve is slightly flatter across the arm than in its bend plane.
			var section: Vector3 = across*cos(a)*0.91+up*sin(a)
			vertices.append(point+section*radius+normal*(fold+elbow_tip+cuff))
			reference.append(normal)
			uv.append(Vector2(float(column)/SIDES,t))
			var color: Color = Color("465861").lerp(Color("26343a"),smoothstep(0.94,0.97,t))
			var elbow_panel: float = exp(-pow((t-0.5)/0.09,4))*maxf(0,normal.dot(outer_elbow))*0.55
			color = color.lerp(Color("354852"),elbow_panel)
			var seam: float = exp(-pow(wrapf(a-0.35,-PI,PI)/0.08,2))*smoothstep(0.02,0.10,t)*(1-smoothstep(0.88,0.94,t))
			color = color.lerp(Color("61767e"),seam*0.30)
			colors.append(color.lerp(Color("61767e"),(1-smoothstep(0.14,0.24,t))*smoothstep(0.2,0.8,sin(a))*0.45))
	for row: int in range(RINGS):
		for column: int in range(SIDES):
			var a: int = row*(SIDES+1)+column
			for triangle: Array in [[a,a+1,a+SIDES+2],[a,a+SIDES+2,a+SIDES+1]]:
				if (vertices[triangle[1]]-vertices[triangle[0]]).cross(vertices[triangle[2]]-vertices[triangle[0]]).dot(reference[triangle[0]]) > 0: triangle.reverse()
				for index: int in triangle: indices.append(index)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = reference
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_NORMAL] = welded_normals(arrays)
	return arrays

func garment(original: Array, input: float) -> Array:
	var result: Array = body_source.duplicate(true)
	var vertices: PackedVector3Array = result[Mesh.ARRAY_VERTEX]
	var reference: PackedVector3Array = result[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = result[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = result[Mesh.ARRAY_COLOR]
	var indices := PackedInt32Array()
	indices.append_array(result[Mesh.ARRAY_INDEX])
	# Keep the original physical boot soles and fitted zipper as separate islands.
	var retained_indices := PackedInt32Array()
	var original_indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
	assert(original_indices.size()/3 == 6780)
	for corner: int in range(original_indices.size()):
		if corner < 72*3 or corner >= original_indices.size()-544*3: retained_indices.append(original_indices[corner])
	var retained_map: Dictionary = {}
	for index: int in retained_indices:
		if not retained_map.has(index):
			retained_map[index] = vertices.size()
			vertices.append(original[Mesh.ARRAY_VERTEX][index])
			reference.append(original[Mesh.ARRAY_NORMAL][index])
			uv.append(original[Mesh.ARRAY_TEX_UV][index])
			colors.append(original[Mesh.ARRAY_COLOR][index])
		indices.append(retained_map[index])
	static_vertex_count = vertices.size()
	for side: float in [-1.0,1.0]:
		var arm: Array = sleeve(input,side)
		var offset: int = vertices.size()
		for index: int in arm[Mesh.ARRAY_INDEX]: indices.append(index+offset)
		vertices.append_array(arm[Mesh.ARRAY_VERTEX])
		reference.append_array(arm[Mesh.ARRAY_NORMAL])
		uv.append_array(arm[Mesh.ARRAY_TEX_UV])
		colors.append_array(arm[Mesh.ARRAY_COLOR])
	result[Mesh.ARRAY_VERTEX] = vertices
	result[Mesh.ARRAY_NORMAL] = reference
	result[Mesh.ARRAY_TEX_UV] = uv
	result[Mesh.ARRAY_COLOR] = colors
	result[Mesh.ARRAY_INDEX] = indices
	result[Mesh.ARRAY_TANGENT] = null
	result[Mesh.ARRAY_NORMAL] = welded_normals(result)
	return result

func welded_normals(arrays: Array) -> PackedVector3Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for index: int in range(vertices.size()): indices.append(index)
	var sums: Dictionary = {}
	var keys: Array[Vector3i] = []
	for point: Vector3 in vertices: keys.append(Vector3i((point*100000).round()))
	for corner: int in range(0,indices.size(),3):
		var a: int = indices[corner]
		var b: int = indices[corner+1]
		var c: int = indices[corner+2]
		var normal: Vector3 = (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
		if normal.dot(normals[a]+normals[b]+normals[c]) < 0: normal = -normal
		for index: int in [a,b,c]: sums[keys[index]] = sums.get(keys[index],Vector3.ZERO)+normal
	var result := PackedVector3Array()
	for index: int in range(vertices.size()): result.append(sums.get(keys[index],normals[index]).normalized())
	return result

func run() -> void:
	var evidence_root: String = OUT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): evidence_root = argument.trim_prefix("--evidence-root=")
	var original: ArrayMesh = load(OUT+"/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
	assert(original != null)
	var neutral := ArrayMesh.new()
	var bindings: Dictionary = {}
	var body_vertices := PackedVector3Array()
	var body_normals := PackedVector3Array()
	var points: PackedFloat32Array = FileAccess.get_file_as_bytes("res://../build/kart-driver-polish-2026-11-12/body-vertices.bin").to_float32_array()
	var vectors: PackedFloat32Array = FileAccess.get_file_as_bytes("res://../build/kart-driver-polish-2026-11-12/body-normals.bin").to_float32_array()
	for index: int in range(0,points.size(),3):
		body_vertices.append(Vector3(points[index],points[index+1],points[index+2]))
		body_normals.append(Vector3(vectors[index],vectors[index+1],vectors[index+2]))
	var body_indices: PackedInt32Array = FileAccess.get_file_as_bytes("res://../build/kart-driver-polish-2026-11-12/body-indices.bin").to_int32_array()
	body_source.resize(Mesh.ARRAY_MAX)
	body_source[Mesh.ARRAY_VERTEX] = body_vertices
	body_source[Mesh.ARRAY_NORMAL] = body_normals
	body_source[Mesh.ARRAY_INDEX] = body_indices
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,body_source)
	importer.generate_lods(60,0,[])
	for lod: int in range(importer.get_surface_lod_count(0)):
		if body_indices.size()/3 <= 4200: break
		body_indices = importer.get_surface_lod_indices(0,lod)
	var compact := PackedVector3Array()
	var compact_normals := PackedVector3Array()
	var mapping: Dictionary = {}
	for corner: int in range(body_indices.size()):
		var index: int = body_indices[corner]
		if not mapping.has(index):
			mapping[index] = compact.size()
			compact.append(body_vertices[index])
			compact_normals.append(body_normals[index])
		body_indices[corner] = mapping[index]
	body_vertices = compact
	body_normals = compact_normals
	body_source[Mesh.ARRAY_VERTEX] = body_vertices
	body_source[Mesh.ARRAY_NORMAL] = body_normals
	body_source[Mesh.ARRAY_INDEX] = body_indices
	var body_uv := PackedVector2Array()
	var body_colors := PackedColorArray()
	for point: Vector3 in body_vertices:
		body_uv.append(Vector2(point.x,point.y))
		var color := Color("465861")
		color = color.lerp(Color("61767e"),smoothstep(0.66,0.72,point.y)*0.6)
		if point.y > 0.74: color = Color("26343a")
		if point.z < -0.32 and point.y > 0.42: color = Color("354852")
		body_colors.append(color)
	body_source[Mesh.ARRAY_TEX_UV] = body_uv
	body_source[Mesh.ARRAY_COLOR] = body_colors
	for surface: int in range(original.get_surface_count()):
		var material: StandardMaterial3D = original.surface_get_material(surface)
		if material.resource_name not in ["RT_DriverSuit","RT_Gloves"]: continue
		var arrays: Array = original.surface_get_arrays(surface)
		bindings[neutral.get_surface_count()] = arrays.duplicate(true)
		if material.resource_name == "RT_DriverSuit": arrays = garment(arrays,0)
		else:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for index: int in range(vertices.size()): vertices[index] += STEERING.CENTER-STEERING.SOURCE_CENTER
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_TANGENT] = null
		arrays[Mesh.ARRAY_NORMAL] = welded_normals(arrays)
		# Preserve the measured back, pelvis, boot and pedal surfaces exactly.
		# Reduce the bright zipper contrast, keeping the slate tailoring panels.
		if material.resource_name == "RT_DriverSuit":
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for index: int in range(colors.size()):
				if colors[index].r > 0.50: colors[index] = Color("667b83")
			arrays[Mesh.ARRAY_COLOR] = colors
		material = material.duplicate()
		# A broad diffuse response avoids triangular light bands across cloth.
		# Keep the matte palette and disabled specular of the established suit.
		material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		neutral.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		neutral.surface_set_material(neutral.get_surface_count()-1,material)
	# Replace the 401-triangle printed head with a shaped shell, actual opaque
	# visor, rubber aperture returns, vents and recessed visor hardware.
	var helmet := Node3D.new()
	preload("res://vehicle/kart_geometry.gd").use_baked = false
	HELMET.build(helmet,true)
	var groups: Dictionary = {}
	var materials: Dictionary = {}
	var scale := Vector3(0.69,0.773,0.78)
	var pose := Transform3D(Basis.from_scale(scale),Vector3(0,0.740213-0.765*scale.y,0.388-0.225*scale.z))
	for node: MeshInstance3D in helmet.get_children():
		var material: StandardMaterial3D = node.get_active_material(0)
		var label: String = "HelmetShell" if material.albedo_color.r > 0.7 else "HelmetHardware" if material.metallic > 0.5 else "HelmetVisor" if material.metallic > 0.1 else "HelmetTrim"
		if not groups.has(label):
			groups[label] = SurfaceTool.new()
			materials[label] = material
			material.resource_name = "RT_Helemt" if label == "HelmetShell" else label
		groups[label].append_from(node.mesh,0,pose*node.transform)
	for label: String in groups:
		groups[label].index()
		groups[label].commit(neutral)
		neutral.surface_set_material(neutral.get_surface_count()-1,materials[label])
	helmet.free()
	var result := ArrayMesh.new()
	result.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	for direction: int in [-1,1]:
		for step: int in range(1,STEERING.STEPS+1): result.add_blend_shape("Steer%s%d" % ["Left" if direction < 0 else "Right",step])
	var bounds: AABB = neutral.get_aabb()
	for surface: int in range(neutral.get_surface_count()):
		var arrays: Array = neutral.surface_get_arrays(surface)
		var material: StandardMaterial3D = neutral.surface_get_material(surface)
		var movable: bool = material.resource_name in ["RT_DriverSuit","RT_Gloves"]
		var shapes: Array[Array] = []
		for direction: int in [-1,1]:
			for step: int in range(1,STEERING.STEPS+1):
				var input: float = float(direction*step)/STEERING.STEPS
				var posed: Array = arrays.duplicate()
				if material.resource_name == "RT_DriverSuit": posed = garment(bindings[surface],input)
				elif material.resource_name == "RT_Gloves":
					var vertices: PackedVector3Array = posed[Mesh.ARRAY_VERTEX].duplicate()
					var rotation: Basis = STEERING.wheel_basis(input)*STEERING.REST.inverse()
					var original_points: PackedVector3Array = bindings[surface][Mesh.ARRAY_VERTEX]
					for index: int in range(vertices.size()): vertices[index] = STEERING.CENTER+rotation*(original_points[index]-STEERING.SOURCE_CENTER)
					posed[Mesh.ARRAY_VERTEX] = vertices
				var normals: PackedVector3Array = welded_normals(posed) if movable else arrays[Mesh.ARRAY_NORMAL]
				var shape: Array = []
				shape.resize(Mesh.ARRAY_MAX)
				shape[Mesh.ARRAY_VERTEX] = posed[Mesh.ARRAY_VERTEX]
				shape[Mesh.ARRAY_NORMAL] = normals
				if arrays[Mesh.ARRAY_TANGENT] != null: shape[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
				shapes.append(shape)
				for point: Vector3 in posed[Mesh.ARRAY_VERTEX]: bounds = bounds.expand(point)
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,shapes)
		result.surface_set_material(surface,material)
	result.custom_aabb = bounds.grow(0.002)
	result.set_meta("kart_suit_static_vertices",static_vertex_count)
	assert(ResourceSaver.save(result,DEST,ResourceSaver.FLAG_COMPRESS) == OK)
	FileAccess.open(evidence_root+"/bake.json",FileAccess.WRITE).store_string(JSON.stringify({"triangles":result.get_faces().size()/3,"surfaces":result.get_surface_count(),"steering_shapes":result.get_blend_shape_count(),"bounds":str(bounds),"source":FileAccess.get_sha256(OUT+"/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")},"\t"))
	print("KART_DRIVER_POLISH_BAKE ",result.get_faces().size()/3," triangles; ",result.get_surface_count()," materials; ",result.get_blend_shape_count()," steering poses")
	quit()
