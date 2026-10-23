extends SceneTree
## Actual road arrays, prepared resources and native reference views.
const OUT: String = "res://../docs/evidence/grass-verge-2026-10-16/"
const PREPARATION = preload("res://editor/road_preparation.gd")
var checks: int = 0
var failures: int = 0
var baseline: bool = false
var report: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func circuit(theme: String) -> NativeTrack:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "grass_verge"; doc.name = "Grass verge"; doc.theme = theme
	var position := Vector2(-32,-16)
	var heading: float = 0.0
	for kind: String in ["straight","bridge","straight","hairpin","straight","hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind,position,heading,10)
		piece.length = 32.0 if kind == "bridge" else 64.0 if doc.pieces.size() == 4 else 16.0 if kind == "straight" else 0.0
		piece.radius = 16.0
		doc.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		position = pose.position; heading = pose.heading
	var routed: Dictionary = RoadPieces.route_from_pieces(doc)
	check(routed.ok,theme+" reference circuit routes")
	return TrackCompiler.compile(routed.document)

func digest(arrays: Array) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(arrays)); return hash.finish().hex_encode()

func surfaces(world: NativeTrackVisual) -> Array:
	var values: Array = []
	for child: Node in world.get_children():
		if not child is MeshInstance3D or not child.mesh is ArrayMesh: continue
		var material: ShaderMaterial = child.material_override as ShaderMaterial
		if material == null: continue
		var role: String = "gravel" if material.get_shader_parameter("gravel") == true else "fringe" if material.get_shader_parameter("edge_fringe") == true else "asphalt" if material.get_shader_parameter("asphalt_surface") == true else "other"
		values.append({"role":role,"hash":digest(child.mesh.surface_get_arrays(0))})
	return values

func run() -> void:
	baseline = "--before" in OS.get_cmdline_user_args()
	if not baseline: await test_profile_clipping()
	if "--profile-only" in OS.get_cmdline_user_args():
		print("GRASS_VERGE_PROFILE: %d checks, %d failures"%[checks,failures]); quit(1 if failures else 0); return
	root.size = Vector2i(1440,810)
	var old: Dictionary = {}
	if not baseline: old = JSON.parse_string(FileAccess.get_file_as_string(OUT+"baseline-headless.json"))
	for theme: String in ["pine","storm","night_city","winter","desert"]:
		var track: NativeTrack = circuit(theme)
		var canonical: String = digest([track.cells,track.route,track.metadata.duplicate(true)])
		var world := NativeTrackVisual.new()
		world.cache_road_meshes = false; world.persist_road_meshes = false; world.cache_race_world = false
		root.add_child(world)
		await world.build(track,BridgePresentation.new(track))
		var data: Array = surfaces(world)
		report[theme] = {"canonical":canonical,"surfaces":data}
		check(canonical == digest([track.cells,track.route,track.metadata.duplicate(true)]),theme+" building leaves canonical data intact")
		if not baseline:
			check(old[theme].canonical == canonical,theme+" canonical source matches original")
			if theme != "pine": check(data == old[theme].surfaces,theme+" every road array stays byte exact")
			else:
				var asphalt: Array = data.filter(func(row: Dictionary) -> bool: return row.role == "asphalt")
				check(asphalt == old[theme].surfaces.filter(func(row: Dictionary) -> bool: return row.role == "asphalt"),"Grass asphalt including bridge stays byte exact")
				inspect_verge(world)
				var direct := NativeTrackVisual.new()
				direct.theme_id = theme; direct.colors = TrackTheme.palette(theme)
				direct.cache_road_meshes = false; direct.persist_road_meshes = false
				direct.prepare_editor_roads = false
				await direct._build_creator_roads(track)
				var packet: Dictionary = PREPARATION.prepare(track,true)
				var prepared := NativeTrackVisual.new()
				prepared.theme_id = theme; prepared.colors = direct.colors
				prepared.cache_road_meshes = false; prepared.persist_road_meshes = false
				prepared.ground_support = preload("res://track/road_surface_height.gd").new(track)
				await prepared._install_prepared_roads(track,packet)
				check(surfaces(direct) == surfaces(prepared),"Grass direct and prepared road arrays match")
				direct.free(); prepared.free()
		if theme == "pine" and DisplayServer.get_name() != "headless": await capture(world,track)
		world.queue_free(); await process_frame
	var renderer: String = "headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method()
	var file := FileAccess.open(OUT+("baseline-" if baseline else "final-")+renderer+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"themes":report},"\t") if not baseline else JSON.stringify(report,"\t"))
	print("GRASS_VERGE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func inspect_verge(world: NativeTrackVisual) -> void:
	var bases: int = 0; var stones: int = 0; var blades: int = 0
	var minimum: float = INF; var maximum: float = -INF
	var sloped: bool = false
	for child: Node in world.get_children():
		if not child is MeshInstance3D or not child.material_override is ShaderMaterial: continue
		if child.material_override.get_shader_parameter("gravel") != true: continue
		check(not child.material_override.shader.code.contains("#define desert_apron"),"Grass grit keeps its actual artwork sampler after material specialization")
		var arrays: Array = child.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for i: int in range(vertices.size()):
			if uv[i].x < -1.5: blades += 1; continue
			if uv[i].x < -0.5: stones += 1; continue
			bases += 1; minimum = minf(minimum,vertices[i].y); maximum = maxf(maximum,vertices[i].y)
			sloped = sloped or arrays[Mesh.ARRAY_NORMAL][i].y < 0.999
	check(bases > 0 and absf(minimum+0.038) < 0.00001 and absf(maximum-0.027) < 0.00001,"shoulder slopes from 3.5 cm below asphalt to the grass skirt")
	check(sloped,"shoulder has real slope normals")
	check(stones > 0 and blades > 0,"actual pebbles and grass blades share the shoulder mesh")
	check(stones+blades <= 2048*15,"natural details stay inside their fixed geometry budget")
	report.pine["detail_vertices"] = stones+blades
	for point: Vector2 in [Vector2.ZERO,Vector2(12,8),Vector2(-38,16)]:
		var width: float = world._shoulder_width(point)-0.365
		check(width >= 0.35-0.00001 and width <= 0.60+0.00001,"visible sandy shoulder stays 35–60 cm")

func test_profile_clipping() -> void:
	var serial: Array
	for cooperative: bool in [true,false]:
		var builder: ShoulderMesh = preload("res://track/grass_road_verge.gd").new()
		# More than 512 source triangles exercises the actual parallel solver.
		for i: int in range(300):
			builder.add_quad(Vector2(i*0.2,0),Vector2((i+1)*0.2,0),Vector2(i*0.2,0.5),Vector2((i+1)*0.2,0.5))
		# Opposing edges overlap: nearest-road ownership must remain a single face.
		builder.add_quad(Vector2(60,0.8),Vector2(0,0.8),Vector2(60,0.3),Vector2(0,0.3))
		var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		await builder.emit(tool,(func() -> bool: return true) if cooperative else Callable())
		var arrays: Array = tool.commit().surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var total_area: float = 0.0; var profile_ok: bool = true; var worst_error: float = 0.0; var worst_point := Vector2.ZERO; var worst_triangle: Array = []
		for i: int in range(0,vertices.size(),3):
			if uv[i].x < -0.5: continue
			var polygon := PackedVector2Array()
			for j: int in range(3):
				var p := Vector2(vertices[i+j].x,-vertices[i+j].z); polygon.append(p)
				var t: float = minf(p.y,0.8-p.y)/0.5
				var error: float = absf(vertices[i+j].y-lerpf(0.027,-0.038,t))
				if error > worst_error:
					worst_error = error; worst_point = p; worst_triangle = [vertices[i],vertices[i+1],vertices[i+2]]
				profile_ok = profile_ok and absf(vertices[i+j].y-lerpf(0.027,-0.038,t)) < 0.00001
			total_area += absf((polygon[1]-polygon[0]).cross(polygon[2]-polygon[0]))*0.5
		check(absf(total_area-48.0) < 0.002,"opposing sloped shoulders retain exact union area")
		check(profile_ok,"overlapping slopes meet at the same nearest-road height")
		if not profile_ok: print("PROFILE_DIAGNOSTIC worst_error=",worst_error," point=",worst_point," triangle=",worst_triangle)
		if cooperative: serial = arrays
		else: check(arrays == serial,"cooperative and parallel shoulder arrays including details are exact")

func capture(world: Node3D, track: NativeTrack) -> void:
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-48,-32,0); sun.shadow_enabled = true; world.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("aab8b8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d9e4eb"); env.environment.ambient_light_energy = 0.7; world.add_child(env)
	var car := CarVisual.new(); world.add_child(car)
	var state := VehicleState.new(); state.position = Vector2(27,-16); state.heading = PI*0.5
	car.present(state.position,state.heading,state,DriveFrame.new())
	car.position.y = BridgePresentation.new(track).height_at(state.position,0,0)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; world.add_child(camera); camera.current = true
	var folder: String = OUT+("before/" if baseline else "final/")+RenderingServer.get_current_rendering_method()+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for view: String in ["corner","edge","bridge"]:
		var target := Vector3(33,0,10) if view == "corner" else Vector3(27,0,21.4) if view == "edge" else Vector3(-16,0,16)
		camera.size = 30.0 if view == "corner" else 4.5 if view == "edge" else 18.0
		camera.position = target+Vector3(-3,25,21) if view != "edge" else target+Vector3(-1,1.7,3)
		camera.look_at(target)
		for frame: int in range(24): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+view+".png") == OK,"actual "+view+" reference capture saved")
