extends SceneTree
## Read-only measurements of prepared kit joins; no production meshes are rebuilt.
var output: String = "res://../docs/evidence/compact-kit-review-2026-10-25/diagnostic"
var manifest: Dictionary
var measurements: Dictionary = {"insert_clearance":[],"arch_clearance":[],"roof_lip_clearance":[]}

func _initialize() -> void: run.call_deferred()

func prepared(key: String, simple: bool) -> ArrayMesh:
	var entry: Dictionary = manifest.meshes[key+("/simple" if simple else "")]
	return load(CompactKits.ASSET_ROOT.path_join("meshes/"+str(entry.file))) as ArrayMesh

func inspect_inserts(simple: bool) -> void:
	for kind: String in ["dome","vented"]:
		var sheet: TriangleMesh = prepared("hood6/"+kind+"/sheet",simple).generate_triangle_mesh()
		var insert_mesh: ArrayMesh = prepared("hood6/"+kind+"/crowninsert",simple)
		var insert: TriangleMesh = insert_mesh.generate_triangle_mesh()
		var bounds: AABB = insert_mesh.get_aabb()
		var lowest: float = INF
		var highest: float = -INF
		var below: int = 0
		var samples: int = 0
		var worst := Vector3.ZERO
		for row: int in range(121):
			for column: int in range(41):
				var origin := Vector3(lerpf(bounds.position.x,bounds.end.x,(column+0.5)/41.0),2.0,lerpf(bounds.position.z,bounds.end.z,(row+0.5)/121.0))
				var overlay_hit: Dictionary = insert.intersect_ray(origin,Vector3.DOWN)
				if overlay_hit.is_empty(): continue
				var sheet_hit: Dictionary = sheet.intersect_ray(origin,Vector3.DOWN)
				if sheet_hit.is_empty(): continue
				var p: Vector3 = overlay_hit.position
				var q: Vector3 = sheet_hit.position
				var clearance: float = p.y-q.y
				samples += 1
				if clearance < -0.00001: below += 1
				if clearance < lowest:
					lowest = clearance
					worst = p
				highest = maxf(highest,clearance)
		var row: Dictionary = {"kind":kind,"simple":simple,"samples":samples,"below_sheet":below,"min_clearance_model_m":lowest,"max_clearance_model_m":highest,"worst_position":[worst.x,worst.y,worst.z]}
		measurements.insert_clearance.append(row)
		print("INSERT_CLEARANCE ",JSON.stringify(row))

func inspect_arches(car: CarVisual, simple: bool) -> void:
	var stock: Array[Dictionary] = []
	for part: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		# Names are not identities: duplicate left/right labels can be assigned
		# automatic node names. Select the immutable prepared mesh resources.
		var selected: bool = false
		for key: String in CompactCoachwork.meshes:
			if key.begins_with("curved_body") or key.begins_with("rolled_wheel_arch") or key.begins_with("arch_rubber_seal"):
				if part.mesh == CompactCoachwork.meshes[key]: selected = true
		if not selected: continue
		var transform: Transform3D = car.body.global_transform.affine_inverse()*part.global_transform
		stock.append({"mesh":part.mesh.generate_triangle_mesh(),"transform":transform,"inverse":transform.affine_inverse()})
	assert(not stock.is_empty())
	for kind: String in ["rally","club","heritage","wide","endurance","gravel"]:
		for axle: float in [-1.28,1.28]:
			var arch: ArrayMesh = prepared("body6/"+kind+"/arch1.0/"+str(axle),simple)
			var points: PackedVector3Array = arch.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var seen: Dictionary = {}
			var minimum: float = INF
			var maximum: float = -INF
			var samples: int = 0
			var no_hit: int = 0
			for point: Vector3 in points:
				if point.y < 0.385: continue
				var key: Vector3i = Vector3i((point*1000000).round())
				if seen.has(key): continue
				seen[key] = true
				var highest: float = -INF
				for surface: Dictionary in stock:
					var inverse: Transform3D = surface.inverse
					# Both directions avoid selecting the opposite body side through
					# a clockwise render surface in the one-sided TriangleMesh API.
					for side: float in [-1,1]:
						var hit: Dictionary = (surface.mesh as TriangleMesh).intersect_ray(inverse*Vector3(side*1.5,point.y,point.z),inverse.basis*Vector3(-side,0,0))
						if not hit.is_empty():
							var original: Vector3 = (surface.transform as Transform3D)*(hit.position as Vector3)
							highest = maxf(highest,original.x)
				if highest == -INF:
					no_hit += 1
					continue
				samples += 1
				minimum = minf(minimum,point.x-highest)
				maximum = maxf(maximum,point.x-highest)
			var row: Dictionary = {"kind":kind,"simple":simple,"axle":axle,"sampled_vertices":samples,"no_stock_ray_hit":no_hit,"min_lateral_gap_model_m":minimum,"max_lateral_gap_model_m":maximum}
			measurements.arch_clearance.append(row)
			print("ARCH_CLEARANCE ",JSON.stringify(row))

func inspect_lip(car: CarVisual, simple: bool) -> void:
	var stock: Array[Dictionary] = []
	for part: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		var transform: Transform3D = car.body.global_transform.affine_inverse()*part.global_transform
		var bounds: AABB = transform*part.mesh.get_aabb()
		if bounds.end.y < 1.35 or bounds.end.z < 0.8: continue
		stock.append({"mesh":part.mesh.generate_triangle_mesh(),"transform":transform,"inverse":transform.affine_inverse()})
	var lip: ArrayMesh = prepared("aero6/lip",simple)
	var points: PackedVector3Array = lip.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var minimum: float = INF
	var maximum: float = -INF
	var samples: int = 0
	var no_hit: int = 0
	for point: Vector3 in points:
		var highest: float = -INF
		for surface: Dictionary in stock:
			var inverse: Transform3D = surface.inverse
			for direction: float in [-1,1]:
				var origin := Vector3(point.x,0 if direction > 0 else 2.0,point.z)
				var hit: Dictionary = (surface.mesh as TriangleMesh).intersect_ray(inverse*origin,inverse.basis*Vector3(0,direction,0))
				if not hit.is_empty():
					var original: Vector3 = (surface.transform as Transform3D)*(hit.position as Vector3)
					highest = maxf(highest,original.y)
		if highest == -INF:
			no_hit += 1
			continue
		samples += 1
		minimum = minf(minimum,point.y-highest)
		maximum = maxf(maximum,point.y-highest)
	var row: Dictionary = {"simple":simple,"sampled_vertices":samples,"no_stock_ray_hit":no_hit,"min_vertical_gap_model_m":minimum,"max_vertical_gap_model_m":maximum}
	measurements.roof_lip_clearance.append(row)
	print("ROOF_LIP_CLEARANCE ",JSON.stringify(row))

func settle() -> void:
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw

func capture(view: CarShowroom, label: String, target: Vector3, direction: Vector3) -> void:
	var at: Vector3 = view.car.body.global_transform*target
	view.camera.look_at_from_position(at+direction,at)
	view.reflections.sync()
	view.invalidate_render()
	await settle()
	assert(view.showroom_viewport.get_texture().get_image().save_png(output.path_join(label+".png")) == OK)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	manifest = JSON.parse_string(FileAccess.get_file_as_string(CompactKits.ASSET_ROOT.path_join("manifest.json")))
	for simple: bool in [false,true]:
		inspect_inserts(simple)
		var car := CarVisual.new()
		car.simple_model = simple
		car.batch_parts = false
		car.editable_kits = true
		root.add_child(car)
		inspect_arches(car,simple)
		inspect_lip(car,simple)
		car.queue_free()
		await process_frame
	root.size = Vector2i(1440,900)
	var host := Control.new()
	root.add_child(host)
	MenuStyle.fill(host)
	var view := CarShowroom.new()
	view.garage_mode = true
	host.add_child(view)
	MenuStyle.fill(view)
	await settle()
	for kind: String in ["dome","vented"]:
		var profile: Dictionary = VehicleCustomisation.defaults()
		profile.hood = kind
		view.apply_customisation(profile)
		await capture(view,kind+"-insert",Vector3(0,1.03,-1.4),Vector3(0.8,1.1,-0.9))
	for kind: String in ["rally","heritage","wide"]:
		var profile: Dictionary = VehicleCustomisation.defaults()
		profile.body = kind
		view.apply_customisation(profile)
		await capture(view,kind+"-arch",Vector3(0.925,0.73,-1.28),Vector3(0.60,0.04,-0.53))
	var roof_profile: Dictionary = VehicleCustomisation.defaults()
	roof_profile.aero = "lip"
	view.apply_customisation(roof_profile)
	await capture(view,"roof-lip-side",Vector3(0.1,1.50,1.15),Vector3(1.65,0.06,0.35))
	# Full/simple combinations use the normal batched CarVisual assembly.
	for simple: bool in [false,true]:
		var current: CarVisual = view.car
		view.car = CarVisual.new()
		view.car.simple_model = simple
		view.car.customisation = {"version":1,"hood":"dome","aero":"biwing","rims":"mesh","body":"wide"}
		view.car.livery = VehicleLivery.defaults("compact")
		current.get_parent().add_child(view.car)
		view.car.transform = current.transform
		current.get_parent().remove_child(current)
		current.queue_free()
		view.reflections.sync()
		var prefix: String = "simple" if simple else "full"
		await capture(view,prefix+"-combined-front",Vector3(0,0.72,0),Vector3(3.5,2.5,-4.8))
		await capture(view,prefix+"-combined-rear",Vector3(0,0.85,0.35),Vector3(3.6,2.0,4.6))
		await capture(view,prefix+"-combined-insert",Vector3(0,1.03,-1.4),Vector3(0.8,1.1,-0.9))
	var file := FileAccess.open(output.path_join("measurements.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements,"\t"))
	file.close()
	host.queue_free()
	await process_frame
	print("COMPACT_KIT_DIAGNOSTIC: prepared full/simple measurements and 12 native views; findings are reported without an acceptance exit gate")
	quit()
