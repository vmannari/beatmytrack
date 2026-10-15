extends SceneTree
var checks: int = 0
var failures: int = 0
var report: Array[Dictionary] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func _initialize() -> void: run.call_deferred()

func area(poly: PackedVector2Array) -> float:
	var result: float = 0.0
	# Translate before multiplying: world-coordinate cancellation otherwise
	# reports area for coincident edges far from the origin.
	for i: int in range(poly.size()): result += (poly[i]-poly[0]).cross(poly[(i+1)%poly.size()]-poly[0])
	return absf(result)*0.5

func overlap_triangles(nodes: Array[MeshInstance3D], height: float) -> Dictionary:
	var triangles: Array[PackedVector2Array] = []
	var bins: Dictionary = {}
	var checked: Dictionary = {}
	var overlaps: int = 0
	var worst: float = 0.0
	for node: MeshInstance3D in nodes:
		var vertices: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for first: int in range(0,vertices.size(),3):
			var polygon := PackedVector2Array()
			var flat: bool = true
			for i: int in range(3):
				var p: Vector3 = node.transform*vertices[first+i]
				flat = flat and absf(p.y-height) < 0.00001
				polygon.append(Vector2(p.x,-p.z))
			if not flat or area(polygon) < 0.0000001: continue
			var index: int = triangles.size()
			triangles.append(polygon)
			var bounds := Rect2(polygon[0],Vector2.ZERO).expand(polygon[1]).expand(polygon[2])
			for y: int in range(floori(bounds.position.y/8.0),floori(bounds.end.y/8.0)+1):
				for x: int in range(floori(bounds.position.x/8.0),floori(bounds.end.x/8.0)+1):
					var cell := Vector2i(x,y)
					for other: int in bins.get(cell,[]):
						var pair := Vector2i(other,index)
						if checked.has(pair): continue
						checked[pair] = true
						for intersection: PackedVector2Array in Geometry2D.intersect_polygons(polygon,triangles[other]):
							var value: float = area(intersection)
							worst = maxf(worst,value)
							if value > 0.0001: overlaps += 1
					if not bins.has(cell): bins[cell] = []
					bins[cell].append(index)
	return {"triangles":triangles.size(),"overlap_pairs":overlaps,"worst_area_m2":worst}

func clone_mesh(arrays: Array, reversed: bool) -> ArrayMesh:
	var values: Array = arrays.duplicate(true)
	var count: int = values[Mesh.ARRAY_VERTEX].size()
	if reversed:
		# Reverse the competing horizontal surfaces. Keep the solid rim in its
		# original slots: top/rim silhouette samples have distinct face normals,
		# so reversing those tests corner rasterisation rather than coplanar ties.
		var flat_triangles: Array[int] = []
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for first: int in range(0,count,3):
			if vertices[first].y == vertices[first+1].y and vertices[first].y == vertices[first+2].y: flat_triangles.append(first)
		for slot: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_COLOR]:
			if values[slot] == null or values[slot].is_empty(): continue
			var source: Variant = arrays[slot]
			for index: int in range(flat_triangles.size()):
				for i: int in range(3): values[slot][flat_triangles[index]+i] = source[flat_triangles[-1-index]+i]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,values)
	return mesh

func settle() -> void:
	for frame: int in range(4): await process_frame
	await RenderingServer.frame_post_draw

func stable_image(label: String) -> Image:
	var previous: Image
	var stable: int = 0
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec()-started < 10000:
		await settle()
		var current: Image = root.get_texture().get_image()
		stable = stable+1 if previous != null and previous.get_data() == current.get_data() else 0
		previous = current
		if stable >= 3: return current
	check(false,label+" native material preparation settles within ten seconds")
	return previous

func run() -> void:
	root.size = Vector2i(960,540)
	for fixture: String in ["ajorata","over_and_under","star_spline_lap"]:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+fixture+".json"))
		doc.theme = "pine"
		var track: NativeTrack = TrackCompiler.compile(doc)
		check(track != null,fixture+" actual track compiles")
		if track == null: continue
		var bridge := BridgePresentation.new(track)
		var world := NativeTrackVisual.new()
		world.cache_road_meshes = false; world.cache_race_world = false
		root.add_child(world)
		await world.build(track,bridge)
		var road: Array[MeshInstance3D] = []
		var fringe: Array[MeshInstance3D] = []
		for child: Node in world.get_children():
			if not child is MeshInstance3D or not child.material_override is ShaderMaterial: continue
			var material: ShaderMaterial = child.material_override
			if material.get_shader_parameter("edge_fringe") == true: fringe.append(child)
			elif material.get_shader_parameter("asphalt_surface") == true: road.append(child)
		var top: Dictionary = overlap_triangles(road,0.062)
		var blend: Dictionary = overlap_triangles(fringe,0.013)
		check(top.triangles > 0 and top.overlap_pairs == 0,fixture+" actual asphalt has one horizontal owner per area")
		check(blend.triangles > 0 and blend.overlap_pairs == 0,fixture+" actual flat blend has one horizontal owner per area")
		var entry: Dictionary = {"fixture":fixture,"asphalt":top,"fringe":blend,"reversed_draw_pixels":[],"max_channel_delta":[]}
		if DisplayServer.get_name() != "headless":
			var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-48,-32,0); world.add_child(sun)
			var env := WorldEnvironment.new(); env.environment = Environment.new()
			env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("8eaaa4")
			env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color("e0e6e8"); env.environment.ambient_light_energy = 0.7
			world.add_child(env)
			var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 28; world.add_child(camera); camera.current = true
			var nodes: Array[MeshInstance3D] = road+fringe
			var arrays: Array[Array] = []
			for node: MeshInstance3D in nodes: arrays.append(node.mesh.surface_get_arrays(0))
			var forwards: Array[ArrayMesh] = []
			var backwards: Array[ArrayMesh] = []
			for data: Array in arrays:
				forwards.append(clone_mesh(data,false)); backwards.append(clone_mesh(data,true))
			var folder: String = "res://../docs/evidence/asphalt-rise-correction-2026-10-14/"+RenderingServer.get_current_rendering_method()+"/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
			# Prime every sampled camera view before comparison. Native prop
			# formats first visible in the second view can otherwise finish Mobile
			# background specialization between the two unchanged scenery images.
			for warm_pose: int in range(6):
				var warm_center: Vector2 = track.route[track.route.size()*warm_pose/6]
				if not track.creator_bridges.is_empty() and warm_pose < 2:
					var warm_span: Dictionary = track.creator_bridges[0]
					warm_center = Vector2(warm_span.position[0],warm_span.position[1])+Vector2(0 if warm_pose == 0 else warm_span.length,0).rotated(deg_to_rad(warm_span.heading))
				camera.position = VisualGeometry.world(warm_center)+Vector3(6.0+warm_pose*0.07,16,17.0+warm_pose*0.13)
				camera.look_at(VisualGeometry.world(warm_center))
				for i: int in range(nodes.size()): nodes[i].mesh = forwards[i]
				await settle()
				for i: int in range(nodes.size()): nodes[i].mesh = backwards[i]
				await settle()
			await create_timer(3.0).timeout
			# Let the first native lighting/material preparation finish before the
			# first comparison, just as subsequent views already have settled.
			for frame: int in range(20): await process_frame
			for pose: int in range(6):
				var center: Vector2 = track.route[track.route.size()*pose/6]
				if not track.creator_bridges.is_empty() and pose < 2:
					var span: Dictionary = track.creator_bridges[0]
					center = Vector2(span.position[0],span.position[1])+Vector2(0 if pose == 0 else span.length,0).rotated(deg_to_rad(span.heading))
				camera.position = VisualGeometry.world(center)+Vector3(6.0+pose*0.07,16,17.0+pose*0.13)
				camera.look_at(VisualGeometry.world(center))
				if pose == 0:
					for i: int in range(nodes.size()): nodes[i].mesh = backwards[i]
					await settle()
					await create_timer(1.0).timeout
				for i: int in range(nodes.size()): nodes[i].mesh = forwards[i]
				await settle()
				if pose == 0: await create_timer(1.0).timeout
				var reference: Image = await stable_image(fixture+" view "+str(pose))
				await settle()
				check(reference.get_data() == root.get_texture().get_image().get_data(),fixture+" fixed view has settled before changing coplanar draw order")
				for i: int in range(nodes.size()): nodes[i].mesh = backwards[i]
				await settle()
				var reversed: Image = root.get_texture().get_image()
				var changed: int = 0
				var max_delta: float = 0.0
				var differences: Array = []
				for y: int in range(reference.get_height()):
					for x: int in range(reference.get_width()):
						if reference.get_pixel(x,y) != reversed.get_pixel(x,y):
							changed += 1
							var before: Color = reference.get_pixel(x,y)
							var after: Color = reversed.get_pixel(x,y)
							for channel: int in range(4): max_delta = maxf(max_delta,absf(before[channel]-after[channel]))
							differences.append([x,y,reference.get_pixel(x,y).to_html(),reversed.get_pixel(x,y).to_html()])
				if changed > 0:
					reference.save_png(folder+fixture+"-reference-%02d.png"%pose)
					print(fixture," ",pose," changed ",changed," max channel delta ",max_delta," samples ",JSON.stringify(differences.slice(0,10)))
				entry.reversed_draw_pixels.append(changed)
				entry.max_channel_delta.append(max_delta)
				# One display-code rounding at a shared raster edge is allowed;
				# competing coplanar artwork produces larger colour differences.
				check(changed <= 1 and max_delta <= 1.0/255.0+0.000001,fixture+" view "+str(pose)+" coplanar draw order is stable within one edge rounding sample")
				check(reversed.save_png(folder+fixture+"-motion-%02d.png"%pose) == OK,"actual moving-view evidence saved")
		report.append(entry)
		world.queue_free(); await process_frame
	var path: String = "res://../docs/evidence/asphalt-rise-correction-2026-10-14/ownership-"+RenderingServer.get_current_rendering_method()+".json"
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scenes":report},"\t")); file.close()
	print("ASPHALT_OWNERSHIP: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
